"""
Tests for mobile sync API endpoints.
"""
import io
import tempfile
from decimal import Decimal
from datetime import timedelta
from pathlib import Path

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from django.utils import timezone
from PIL import Image
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient

from apps.evacuation.models import EvacuationCenter
from apps.hazards.models import BaselineHazard, HazardReport
from apps.routing.models import RoadSegment
from apps.users.models import User


class ReportHazardAPITests(TestCase):
    """Test cases for POST /api/report-hazard/"""

    def setUp(self):
        """Set up test client and user."""
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='testuser',
            email='testuser@example.com',
            password='testpass123',
            role=User.Role.RESIDENT,
        )
        self.user.is_active = True
        self.user.save(update_fields=['is_active'])
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

    @override_settings(MEDIA_ROOT=Path(tempfile.mkdtemp()))
    def test_report_hazard_multipart_photo_saved(self):
        """Small PNG as multipart file is stored and URL returned."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.token.key}')
        buf = io.BytesIO()
        Image.new('RGB', (8, 8), color=(200, 100, 50)).save(buf, format='PNG')
        buf.seek(0)
        photo = SimpleUploadedFile('hazard.png', buf.read(), content_type='image/png')
        data = {
            'hazard_type': 'flood',
            'latitude': '14.5995',
            'longitude': '120.9842',
            'description': 'Heavy flooding on Main Street',
            'photo': photo,
        }
        response = self.client.post('/api/report-hazard/', data, format='multipart')
        self.assertEqual(response.status_code, 201, response.data)
        self.assertIn('photo_url', response.data)
        self.assertTrue(str(response.data['photo_url']).startswith('http'))
        self.assertIn('/media/hazards/', response.data['photo_url'])

    def test_report_hazard_multipart_invalid_image_type(self):
        """Corrupt / invalid image rejected with standard error message."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.token.key}')
        bad = SimpleUploadedFile('x.jpg', b'not-a-valid-jpeg', content_type='image/jpeg')
        data = {
            'hazard_type': 'flood',
            'latitude': '14.5995',
            'longitude': '120.9842',
            'description': 'Heavy flooding on Main Street',
            'photo': bad,
        }
        response = self.client.post('/api/report-hazard/', data, format='multipart')
        self.assertEqual(response.status_code, 400)
        self.assertEqual(
            response.data.get('error'),
            'Invalid file. Must be under size limit and correct format.',
        )

    def test_report_hazard_duplicate_cluster_is_blocked(self):
        """Submitting same hazard in same area/time returns 409 and forces confirmation."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.token.key}')
        first = {
            'hazard_type': 'flood',
            'latitude': 14.5995,
            'longitude': 120.9842,
            'description': 'First report',
            'user_latitude': 14.5995,
            'user_longitude': 120.9842,
        }
        response1 = self.client.post('/api/report-hazard/', first, format='json')
        self.assertEqual(response1.status_code, 201, response1.data)

        other = User.objects.create_user(
            username='otheruser',
            email='other@example.com',
            password='testpass123',
            role=User.Role.RESIDENT,
        )
        other.is_active = True
        other.save(update_fields=['is_active'])
        other_token = Token.objects.create(user=other)
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {other_token.key}')
        duplicate = {
            'hazard_type': 'flood',
            'latitude': 14.5995,
            'longitude': 120.9842,
            'description': 'Duplicate report',
            'user_latitude': 14.5995,
            'user_longitude': 120.9842,
        }
        response2 = self.client.post('/api/report-hazard/', duplicate, format='json')
        self.assertEqual(response2.status_code, 409, response2.data)
        self.assertTrue(response2.data.get('requires_confirmation'))
        self.assertIsNotNone(response2.data.get('existing_report_id'))


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
        self.user.is_active = True
        self.user.save(update_fields=['is_active'])
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
        self.assertIsInstance(response.data['routes'], list)
        # With graph that has alternative paths, backend can return multiple routes
        self.assertGreaterEqual(len(response.data['routes']), 1)

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


class CheckSimilarReportsAPITests(TestCase):
    """Test cases for POST /api/check-similar-reports/."""

    def setUp(self):
        self.client = APIClient()
        self.requester = User.objects.create_user(
            username='requester',
            email='requester@example.com',
            password='testpass123',
            role=User.Role.RESIDENT,
        )
        self.requester.is_active = True
        self.requester.save(update_fields=['is_active'])
        self.requester_token = Token.objects.create(user=self.requester)

        self.other = User.objects.create_user(
            username='other',
            email='other2@example.com',
            password='testpass123',
            role=User.Role.RESIDENT,
        )
        self.other.is_active = True
        self.other.save(update_fields=['is_active'])

    def test_check_similar_reports_applies_one_hour_window(self):
        """Only recent nearby reports are returned to match duplicate-block logic."""
        old_report = HazardReport.objects.create(
            user=self.other,
            hazard_type='flood',
            latitude=14.5995,
            longitude=120.9842,
            status=HazardReport.Status.PENDING,
            auto_rejected=False,
            is_deleted=False,
        )
        HazardReport.objects.filter(pk=old_report.id).update(
            created_at=timezone.now() - timedelta(hours=2)
        )

        fresh_report = HazardReport.objects.create(
            user=self.other,
            hazard_type='flood',
            latitude=14.5995,
            longitude=120.9842,
            status=HazardReport.Status.PENDING,
            auto_rejected=False,
            is_deleted=False,
        )

        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.requester_token.key}')
        response = self.client.post(
            '/api/check-similar-reports/',
            {
                'hazard_type': 'flood',
                'latitude': 14.5995,
                'longitude': 120.9842,
                'radius_meters': 150,
            },
            format='json',
        )
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data.get('time_window_hours'), 1)
        self.assertEqual(response.data.get('count'), 1)
        returned_ids = [item.get('id') for item in response.data.get('similar_reports', [])]
        self.assertIn(fresh_report.id, returned_ids)
        self.assertNotIn(old_report.id, returned_ids)
