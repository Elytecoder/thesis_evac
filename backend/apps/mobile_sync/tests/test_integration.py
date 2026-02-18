"""
Integration tests for the complete evacuation route recommendation flow.
"""
from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework.authtoken.models import Token
from apps.users.models import User
from apps.evacuation.models import EvacuationCenter
from apps.hazards.models import BaselineHazard, HazardReport
from apps.routing.models import RoadSegment, RouteLog


class CompleteFlowIntegrationTests(TestCase):
    """Test the complete system flow from hazard report to route calculation."""

    def setUp(self):
        """Set up complete test environment."""
        self.client = APIClient()
        
        # Create users
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
        
        # Create evacuation center
        self.center = EvacuationCenter.objects.create(
            name='Main Evacuation Center',
            latitude=14.6000,
            longitude=120.9850,
            address='123 Safe St',
        )
        
        # Create baseline hazards
        BaselineHazard.objects.create(
            hazard_type='flood',
            latitude=14.5995,
            longitude=120.9842,
            severity=0.7,
        )
        
        # Create road network
        RoadSegment.objects.create(
            start_lat=14.5990, start_lng=120.9840,
            end_lat=14.5995, end_lng=120.9842,
            base_distance=50.0, predicted_risk_score=0.2,
        )
        RoadSegment.objects.create(
            start_lat=14.5995, start_lng=120.9842,
            end_lat=14.6000, end_lng=120.9850,
            base_distance=80.0, predicted_risk_score=0.3,
        )

    def test_complete_resident_flow(self):
        """Test complete flow: bootstrap -> report hazard -> calculate route."""
        # Step 1: Bootstrap - Get initial data
        response = self.client.get('/api/bootstrap-sync/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data['evacuation_centers']), 1)
        self.assertEqual(len(response.data['baseline_hazards']), 1)
        
        # Step 2: Report a hazard
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.resident_token.key}')
        report_data = {
            'hazard_type': 'landslide',
            'latitude': 14.5998,
            'longitude': 120.9845,
            'description': 'Landslide blocking road',
        }
        response = self.client.post('/api/report-hazard/', report_data, format='json')
        self.assertEqual(response.status_code, 201)
        report_id = response.data['id']
        self.assertIsNotNone(response.data['naive_bayes_score'])
        self.assertIsNotNone(response.data['consensus_score'])
        
        # Step 3: Calculate safest route
        route_data = {
            'start_lat': 14.5990,
            'start_lng': 120.9840,
            'evacuation_center_id': self.center.id,
        }
        response = self.client.post('/api/calculate-route/', route_data, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertIn('routes', response.data)
        
        # Verify route log was created
        self.assertEqual(RouteLog.objects.filter(user=self.resident).count(), 1)

    def test_complete_mdrrmo_flow(self):
        """Test complete MDRRMO flow: view pending -> approve/reject."""
        # Step 1: Resident reports a hazard
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.resident_token.key}')
        report_data = {
            'hazard_type': 'fire',
            'latitude': 14.5997,
            'longitude': 120.9843,
            'description': 'Fire near Main Street',
        }
        response = self.client.post('/api/report-hazard/', report_data, format='json')
        self.assertEqual(response.status_code, 201)
        report_id = response.data['id']
        
        # Step 2: MDRRMO views pending reports
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.mdrrmo_token.key}')
        response = self.client.get('/api/mdrrmo/pending-reports/')
        self.assertEqual(response.status_code, 200)
        self.assertGreaterEqual(len(response.data), 1)
        
        # Step 3: MDRRMO approves the report
        approve_data = {
            'report_id': report_id,
            'action': 'approve',
        }
        response = self.client.post('/api/mdrrmo/approve-report/', approve_data, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['status'], 'approved')
        
        # Step 4: Verify report is no longer in pending list
        response = self.client.get('/api/mdrrmo/pending-reports/')
        self.assertEqual(response.status_code, 200)
        pending_ids = [r['id'] for r in response.data]
        self.assertNotIn(report_id, pending_ids)

    def test_multiple_reports_consensus_scoring(self):
        """Test that consensus scoring works with multiple nearby reports."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.resident_token.key}')
        
        # Create first report
        report1_data = {
            'hazard_type': 'flood',
            'latitude': 14.5995,
            'longitude': 120.9842,
            'description': 'Flooding observed',
        }
        response1 = self.client.post('/api/report-hazard/', report1_data, format='json')
        self.assertEqual(response1.status_code, 201)
        score1 = response1.data['consensus_score']
        
        # Create second report at nearly same location
        report2_data = {
            'hazard_type': 'flood',
            'latitude': 14.5996,  # Very close
            'longitude': 120.9842,
            'description': 'Severe flooding',
        }
        response2 = self.client.post('/api/report-hazard/', report2_data, format='json')
        self.assertEqual(response2.status_code, 201)
        score2 = response2.data['consensus_score']
        
        # Second report should have higher consensus score
        self.assertGreater(score2, score1)

    def test_route_calculation_with_risk_levels(self):
        """Test that route calculation returns proper risk levels."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.resident_token.key}')
        
        route_data = {
            'start_lat': 14.5990,
            'start_lng': 120.9840,
            'evacuation_center_id': self.center.id,
        }
        response = self.client.post('/api/calculate-route/', route_data, format='json')
        self.assertEqual(response.status_code, 200)
        
        if response.data['routes']:
            route = response.data['routes'][0]
            self.assertIn('risk_level', route)
            self.assertIn(route['risk_level'], ['Green', 'Yellow', 'Red'])
            self.assertIn('total_risk', route)
            self.assertIn('total_distance', route)

    def test_system_with_no_road_network(self):
        """Test system behavior when no road network exists."""
        # Delete all road segments
        RoadSegment.objects.all().delete()
        
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.resident_token.key}')
        route_data = {
            'start_lat': 14.5990,
            'start_lng': 120.9840,
            'evacuation_center_id': self.center.id,
        }
        response = self.client.post('/api/calculate-route/', route_data, format='json')
        # Should still return 200 but with empty routes
        self.assertEqual(response.status_code, 200)
        self.assertIn('routes', response.data)
