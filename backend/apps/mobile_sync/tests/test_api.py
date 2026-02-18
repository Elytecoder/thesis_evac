"""
Tests for mobile sync API endpoints.
"""
from decimal import Decimal
from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework.authtoken.models import Token
from apps.users.models import User
from apps.evacuation.models import EvacuationCenter
from apps.hazards.models import HazardReport, BaselineHazard
from apps.routing.models import RoadSegment


class ReportHazardAPITests(TestCase):
    """Test cases for POST /api/report-hazard/"""

    def setUp(self):
        """Set up test client and user."""
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='testuser',
            password='testpass123',
            role=User.Role.RESIDENT,
        )
        self.token = Token.objects.create(user=self.user)

    def test_report_hazard_success(self):
        """Test successful hazard report submission."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.token.key}')
        data = {
            'hazard_type': 'flood',
            'latitude': 14.5995,
            'longitude': 120.9842,
            'description': 'Heavy flooding on Main Street',
        }
        response = self.client.post('/api/report-hazard/', data, format='json')
        self.assertEqual(response.status_code, 201)
        self.assertIn('id', response.data)
        self.assertEqual(response.data['hazard_type'], 'flood')
        self.assertIn('naive_bayes_score', response.data)
        self.assertIn('consensus_score', response.data)

    def test_report_hazard_without_auth(self):
        """Test that authentication is required."""
        data = {
            'hazard_type': 'flood',
            'latitude': 14.5995,
            'longitude': 120.9842,
        }
        response = self.client.post('/api/report-hazard/', data, format='json')
        self.assertEqual(response.status_code, 401)

    def test_report_hazard_invalid_data(self):
        """Test validation of required fields."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.token.key}')
        data = {
            'hazard_type': 'flood',
            # Missing latitude and longitude
        }
        response = self.client.post('/api/report-hazard/', data, format='json')
        self.assertEqual(response.status_code, 400)

    def test_report_hazard_optional_fields(self):
        """Test that optional fields work."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.token.key}')
        data = {
            'hazard_type': 'fire',
            'latitude': 14.6000,
            'longitude': 120.9850,
            'description': 'Fire on 2nd floor',
            'photo_url': 'https://example.com/photo.jpg',
        }
        response = self.client.post('/api/report-hazard/', data, format='json')
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data['description'], 'Fire on 2nd floor')


class EvacuationCentersAPITests(TestCase):
    """Test cases for GET /api/evacuation-centers/"""

    def setUp(self):
        """Set up test client and data."""
        self.client = APIClient()
        EvacuationCenter.objects.create(
            name='Center 1',
            latitude=14.5995,
            longitude=120.9842,
            address='123 Main St',
        )
        EvacuationCenter.objects.create(
            name='Center 2',
            latitude=14.6010,
            longitude=120.9860,
            address='456 Oak St',
        )

    def test_list_evacuation_centers(self):
        """Test listing all evacuation centers."""
        response = self.client.get('/api/evacuation-centers/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data), 2)
        self.assertIn('name', response.data[0])
        self.assertIn('latitude', response.data[0])
        self.assertIn('longitude', response.data[0])

    def test_list_evacuation_centers_no_auth_required(self):
        """Test that no authentication is required."""
        response = self.client.get('/api/evacuation-centers/')
        self.assertEqual(response.status_code, 200)


class CalculateRouteAPITests(TestCase):
    """Test cases for POST /api/calculate-route/"""

    def setUp(self):
        """Set up test client, user, and data."""
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='testuser',
            password='testpass123',
            role=User.Role.RESIDENT,
        )
        self.token = Token.objects.create(user=self.user)
        self.center = EvacuationCenter.objects.create(
            name='Test Center',
            latitude=14.6000,
            longitude=120.9850,
            address='123 Test St',
        )
        # Create some road segments
        RoadSegment.objects.create(
            start_lat=14.5995, start_lng=120.9842,
            end_lat=14.6000, end_lng=120.9850,
            base_distance=100.0, predicted_risk_score=0.2,
        )

    def test_calculate_route_success(self):
        """Test successful route calculation."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.token.key}')
        data = {
            'start_lat': 14.5995,
            'start_lng': 120.9842,
            'evacuation_center_id': self.center.id,
        }
        response = self.client.post('/api/calculate-route/', data, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertIn('routes', response.data)

    def test_calculate_route_without_auth(self):
        """Test that authentication is required."""
        data = {
            'start_lat': 14.5995,
            'start_lng': 120.9842,
            'evacuation_center_id': self.center.id,
        }
        response = self.client.post('/api/calculate-route/', data, format='json')
        self.assertEqual(response.status_code, 401)

    def test_calculate_route_invalid_center(self):
        """Test with non-existent evacuation center."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.token.key}')
        data = {
            'start_lat': 14.5995,
            'start_lng': 120.9842,
            'evacuation_center_id': 99999,
        }
        response = self.client.post('/api/calculate-route/', data, format='json')
        self.assertEqual(response.status_code, 404)

    def test_calculate_route_missing_fields(self):
        """Test validation of required fields."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.token.key}')
        data = {
            'start_lat': 14.5995,
            # Missing start_lng and evacuation_center_id
        }
        response = self.client.post('/api/calculate-route/', data, format='json')
        self.assertEqual(response.status_code, 400)


class MDRRMOPendingReportsAPITests(TestCase):
    """Test cases for GET /api/mdrrmo/pending-reports/"""

    def setUp(self):
        """Set up test client, users, and reports."""
        self.client = APIClient()
        self.resident = User.objects.create_user(
            username='resident',
            password='testpass123',
            role=User.Role.RESIDENT,
        )
        self.mdrrmo = User.objects.create_user(
            username='mdrrmo',
            password='testpass123',
            role=User.Role.MDRRMO,
        )
        self.resident_token = Token.objects.create(user=self.resident)
        self.mdrrmo_token = Token.objects.create(user=self.mdrrmo)
        
        # Create reports
        HazardReport.objects.create(
            user=self.resident,
            hazard_type='flood',
            latitude=14.5995,
            longitude=120.9842,
            status=HazardReport.Status.PENDING,
        )
        HazardReport.objects.create(
            user=self.resident,
            hazard_type='fire',
            latitude=14.6000,
            longitude=120.9850,
            status=HazardReport.Status.APPROVED,
        )

    def test_mdrrmo_can_view_pending_reports(self):
        """Test that MDRRMO can view pending reports."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.mdrrmo_token.key}')
        response = self.client.get('/api/mdrrmo/pending-reports/')
        self.assertEqual(response.status_code, 200)
        # Only pending reports should be returned
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['status'], 'pending')

    def test_resident_cannot_view_pending_reports(self):
        """Test that residents cannot access MDRRMO endpoint."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.resident_token.key}')
        response = self.client.get('/api/mdrrmo/pending-reports/')
        self.assertEqual(response.status_code, 403)

    def test_unauthenticated_cannot_view(self):
        """Test that authentication is required."""
        response = self.client.get('/api/mdrrmo/pending-reports/')
        self.assertEqual(response.status_code, 401)


class MDRRMOApproveReportAPITests(TestCase):
    """Test cases for POST /api/mdrrmo/approve-report/"""

    def setUp(self):
        """Set up test client, users, and reports."""
        self.client = APIClient()
        self.resident = User.objects.create_user(
            username='resident',
            password='testpass123',
            role=User.Role.RESIDENT,
        )
        self.mdrrmo = User.objects.create_user(
            username='mdrrmo',
            password='testpass123',
            role=User.Role.MDRRMO,
        )
        self.mdrrmo_token = Token.objects.create(user=self.mdrrmo)
        self.report = HazardReport.objects.create(
            user=self.resident,
            hazard_type='flood',
            latitude=14.5995,
            longitude=120.9842,
            status=HazardReport.Status.PENDING,
        )

    def test_mdrrmo_approve_report(self):
        """Test approving a report."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.mdrrmo_token.key}')
        data = {
            'report_id': self.report.id,
            'action': 'approve',
        }
        response = self.client.post('/api/mdrrmo/approve-report/', data, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['status'], 'approved')
        # Verify in database
        self.report.refresh_from_db()
        self.assertEqual(self.report.status, HazardReport.Status.APPROVED)

    def test_mdrrmo_reject_report(self):
        """Test rejecting a report."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.mdrrmo_token.key}')
        data = {
            'report_id': self.report.id,
            'action': 'reject',
        }
        response = self.client.post('/api/mdrrmo/approve-report/', data, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['status'], 'rejected')
        self.report.refresh_from_db()
        self.assertEqual(self.report.status, HazardReport.Status.REJECTED)

    def test_invalid_action(self):
        """Test with invalid action."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.mdrrmo_token.key}')
        data = {
            'report_id': self.report.id,
            'action': 'invalid',
        }
        response = self.client.post('/api/mdrrmo/approve-report/', data, format='json')
        self.assertEqual(response.status_code, 400)

    def test_nonexistent_report(self):
        """Test with non-existent report ID."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.mdrrmo_token.key}')
        data = {
            'report_id': 99999,
            'action': 'approve',
        }
        response = self.client.post('/api/mdrrmo/approve-report/', data, format='json')
        self.assertEqual(response.status_code, 404)


class BootstrapSyncAPITests(TestCase):
    """Test cases for GET /api/bootstrap-sync/"""

    def setUp(self):
        """Set up test client and data."""
        self.client = APIClient()
        EvacuationCenter.objects.create(
            name='Center 1',
            latitude=14.5995,
            longitude=120.9842,
        )
        BaselineHazard.objects.create(
            hazard_type='flood',
            latitude=14.6000,
            longitude=120.9850,
            severity=0.8,
        )

    def test_bootstrap_sync_success(self):
        """Test successful bootstrap data retrieval."""
        response = self.client.get('/api/bootstrap-sync/')
        self.assertEqual(response.status_code, 200)
        self.assertIn('evacuation_centers', response.data)
        self.assertIn('baseline_hazards', response.data)

    def test_bootstrap_sync_no_auth_required(self):
        """Test that no authentication is required."""
        response = self.client.get('/api/bootstrap-sync/')
        self.assertEqual(response.status_code, 200)

    def test_bootstrap_sync_data_structure(self):
        """Test the structure of returned data."""
        response = self.client.get('/api/bootstrap-sync/')
        self.assertEqual(response.status_code, 200)
        self.assertIsInstance(response.data['evacuation_centers'], list)
        self.assertIsInstance(response.data['baseline_hazards'], list)
        self.assertEqual(len(response.data['evacuation_centers']), 1)
        self.assertEqual(len(response.data['baseline_hazards']), 1)
