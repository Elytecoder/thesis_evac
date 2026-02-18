"""
Tests for routing models.
"""
from django.test import TestCase
from apps.users.models import User
from apps.evacuation.models import EvacuationCenter
from apps.routing.models import RoadSegment, RouteLog


class RoadSegmentModelTests(TestCase):
    """Test cases for RoadSegment model."""

    def test_create_road_segment(self):
        """Test creating a road segment."""
        segment = RoadSegment.objects.create(
            start_lat=14.5995,
            start_lng=120.9842,
            end_lat=14.6000,
            end_lng=120.9842,
            base_distance=100.0,
            predicted_risk_score=0.3,
        )
        self.assertEqual(float(segment.start_lat), 14.5995)
        self.assertEqual(float(segment.start_lng), 120.9842)
        self.assertEqual(float(segment.end_lat), 14.6000)
        self.assertEqual(float(segment.end_lng), 120.9842)
        self.assertEqual(segment.base_distance, 100.0)
        self.assertEqual(segment.predicted_risk_score, 0.3)

    def test_road_segment_default_values(self):
        """Test default values for road segment."""
        segment = RoadSegment.objects.create(
            start_lat=14.5995,
            start_lng=120.9842,
            end_lat=14.6000,
            end_lng=120.9842,
        )
        self.assertEqual(segment.base_distance, 0)
        self.assertEqual(segment.predicted_risk_score, 0)

    def test_road_segment_str(self):
        """Test string representation."""
        segment = RoadSegment.objects.create(
            start_lat=14.5995,
            start_lng=120.9842,
            end_lat=14.6000,
            end_lng=120.9842,
            base_distance=100.0,
        )
        str_repr = str(segment)
        self.assertIn('14.5995', str_repr)
        self.assertIn('120.9842', str_repr)


class RouteLogModelTests(TestCase):
    """Test cases for RouteLog model."""

    def setUp(self):
        """Create test user and evacuation center."""
        self.user = User.objects.create_user(
            username='testuser',
            password='testpass123',
            role=User.Role.RESIDENT,
        )
        self.center = EvacuationCenter.objects.create(
            name='Test Center',
            latitude=14.6000,
            longitude=120.9850,
            address='123 Test St',
        )

    def test_create_route_log(self):
        """Test creating a route log."""
        log = RouteLog.objects.create(
            user=self.user,
            evacuation_center=self.center,
            selected_route_risk=0.25,
        )
        self.assertEqual(log.user, self.user)
        self.assertEqual(log.evacuation_center, self.center)
        self.assertEqual(log.selected_route_risk, 0.25)

    def test_route_log_str(self):
        """Test string representation."""
        log = RouteLog.objects.create(
            user=self.user,
            evacuation_center=self.center,
            selected_route_risk=0.35,
        )
        str_repr = str(log)
        self.assertIn('0.35', str_repr)

    def test_route_log_timestamps(self):
        """Test that created_at is automatically set."""
        log = RouteLog.objects.create(
            user=self.user,
            evacuation_center=self.center,
            selected_route_risk=0.15,
        )
        self.assertIsNotNone(log.created_at)

    def test_route_log_relationship(self):
        """Test that relationships work correctly."""
        log = RouteLog.objects.create(
            user=self.user,
            evacuation_center=self.center,
            selected_route_risk=0.20,
        )
        # Test reverse relationships
        self.assertIn(log, self.user.route_logs.all())
        self.assertIn(log, self.center.route_logs.all())
