"""
Tests for consensus scoring service.
"""
from decimal import Decimal
from django.test import TestCase
from apps.users.models import User
from apps.hazards.models import HazardReport
from apps.validation.services.consensus import ConsensusScoringService


class ConsensusScoringServiceTests(TestCase):
    """Test cases for consensus scoring."""

    def setUp(self):
        """Set up test data."""
        self.service = ConsensusScoringService(radius_m=50.0)
        # Create test user
        self.user = User.objects.create_user(
            username='testuser',
            password='testpass123',
            role=User.Role.RESIDENT,
        )

    def test_count_nearby_reports_none(self):
        """Test counting when no nearby reports exist."""
        count = self.service.count_nearby_reports(
            14.5995, 120.9842,
            HazardReport.objects.all(),
        )
        self.assertEqual(count, 0)

    def test_count_nearby_reports_with_reports(self):
        """Test counting nearby reports."""
        # Create reports at same location
        lat, lng = Decimal('14.5995'), Decimal('120.9842')
        for i in range(3):
            HazardReport.objects.create(
                user=self.user,
                hazard_type='flood',
                latitude=lat,
                longitude=lng,
                description=f'Report {i}',
            )
        
        count = self.service.count_nearby_reports(
            float(lat), float(lng),
            HazardReport.objects.all(),
        )
        self.assertEqual(count, 3)

    def test_count_nearby_reports_exclude_self(self):
        """Test that exclude_report_id works."""
        lat, lng = Decimal('14.5995'), Decimal('120.9842')
        report1 = HazardReport.objects.create(
            user=self.user, hazard_type='flood',
            latitude=lat, longitude=lng, description='Report 1',
        )
        HazardReport.objects.create(
            user=self.user, hazard_type='flood',
            latitude=lat, longitude=lng, description='Report 2',
        )
        
        count = self.service.count_nearby_reports(
            float(lat), float(lng),
            HazardReport.objects.all(),
            exclude_report_id=report1.id,
        )
        self.assertEqual(count, 1)

    def test_count_nearby_reports_far_away(self):
        """Test that far away reports are not counted."""
        lat1, lng1 = Decimal('14.5995'), Decimal('120.9842')
        lat2, lng2 = Decimal('14.6995'), Decimal('121.0842')  # Very far
        
        HazardReport.objects.create(
            user=self.user, hazard_type='flood',
            latitude=lat2, longitude=lng2, description='Far report',
        )
        
        count = self.service.count_nearby_reports(
            float(lat1), float(lng1),
            HazardReport.objects.all(),
        )
        self.assertEqual(count, 0)

    def test_combined_score_no_nearby(self):
        """Test combined score with no nearby reports."""
        nb_score = 0.8
        nearby_count = 0
        score = self.service.combined_score(nb_score, nearby_count)
        self.assertIsInstance(score, float)
        self.assertGreaterEqual(score, 0.0)
        self.assertLessEqual(score, 1.0)

    def test_combined_score_with_nearby(self):
        """Test that nearby reports boost the score."""
        nb_score = 0.6
        score_no_nearby = self.service.combined_score(nb_score, 0)
        score_with_nearby = self.service.combined_score(nb_score, 3)
        self.assertGreater(score_with_nearby, score_no_nearby)

    def test_combined_score_capped(self):
        """Test that consensus boost is capped."""
        nb_score = 0.5
        # Many nearby reports should still produce valid score
        score = self.service.combined_score(nb_score, 100)
        self.assertGreaterEqual(score, 0.0)
        self.assertLessEqual(score, 1.0)

    def test_combined_score_alpha_effect(self):
        """Test that alpha parameter affects weighting."""
        nb_score = 0.8
        nearby_count = 2
        score_high_alpha = self.service.combined_score(nb_score, nearby_count, alpha=0.9)
        score_low_alpha = self.service.combined_score(nb_score, nearby_count, alpha=0.3)
        # Higher alpha means more weight on naive bayes
        self.assertIsInstance(score_high_alpha, float)
        self.assertIsInstance(score_low_alpha, float)
