"""
Tests for deduplicated nearby support (ConsensusScoringService)
and rule_scoring consensus_rule_score.
"""
from decimal import Decimal
from django.test import TestCase
from apps.users.models import User
from apps.hazards.models import HazardReport
from apps.validation.services.consensus import ConsensusScoringService
from apps.validation.services.rule_scoring import consensus_rule_score, combine_validation_scores


class ConsensusScoringServiceTests(TestCase):
    """Test cases for anti-duplicate nearby support and consensus mapping."""

    def setUp(self):
        """Set up test data."""
        self.service = ConsensusScoringService(radius_m=50.0)
        self.user = User.objects.create_user(
            username='testuser',
            email='testuser@example.com',
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
        """Multiple duplicate reports in one area count as one support cluster."""
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
        self.assertEqual(count, 1)

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
        lat2, lng2 = Decimal('14.6995'), Decimal('121.0842')

        HazardReport.objects.create(
            user=self.user, hazard_type='flood',
            latitude=lat2, longitude=lng2, description='Far report',
        )

        count = self.service.count_nearby_reports(
            float(lat1), float(lng1),
            HazardReport.objects.all(),
        )
        self.assertEqual(count, 0)

    def test_get_support_summary_tracks_unique_users(self):
        """Support summary deduplicates clusters and reports unique nearby users."""
        user_b = User.objects.create_user(
            username='testuser_b',
            email='testuser_b@example.com',
            password='testpass123',
            role=User.Role.RESIDENT,
        )
        lat, lng = Decimal('14.5995'), Decimal('120.9842')
        HazardReport.objects.create(
            user=self.user, hazard_type='flood',
            latitude=lat, longitude=lng, description='A1',
        )
        HazardReport.objects.create(
            user=self.user, hazard_type='flood',
            latitude=lat, longitude=lng, description='A2 duplicate',
        )
        HazardReport.objects.create(
            user=user_b, hazard_type='flood',
            latitude=lat, longitude=lng, description='B1',
        )

        summary = self.service.get_support_summary(
            float(lat), float(lng),
            HazardReport.objects.all(),
            hazard_type='flood',
            time_window_hours=1,
        )
        self.assertEqual(summary.nearby_raw_reports, 3)
        self.assertEqual(summary.nearby_cluster_count, 1)
        self.assertEqual(summary.nearby_unique_user_count, 2)

    def test_consensus_rule_score_steps(self):
        """Consensus rule uses smooth formula min((nearby+confirmations)/5, 1.0)."""
        self.assertEqual(consensus_rule_score(0), 0.0)
        self.assertAlmostEqual(consensus_rule_score(1), 0.2)
        self.assertAlmostEqual(consensus_rule_score(2), 0.4)
        self.assertAlmostEqual(consensus_rule_score(3), 0.6)
        self.assertAlmostEqual(consensus_rule_score(4), 0.8)
        self.assertEqual(consensus_rule_score(5), 1.0)
        # Capped at 1.0 for 5+
        self.assertEqual(consensus_rule_score(10), 1.0)

    def test_combine_validation_scores_range(self):
        """Combined NB + rules stays in [0, 1]."""
        s = combine_validation_scores(0.9, 0.8, 1.0)
        self.assertGreaterEqual(s, 0.0)
        self.assertLessEqual(s, 1.0)

    def test_combine_higher_consensus_raises_final(self):
        """Higher consensus rule raises combined score when NB and distance fixed."""
        low = combine_validation_scores(0.6, 0.5, 0.0)
        high = combine_validation_scores(0.6, 0.5, 1.0)
        self.assertGreater(high, low)
