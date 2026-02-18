"""
Tests for hazard models.
"""
from django.test import TestCase
from apps.users.models import User
from apps.hazards.models import BaselineHazard, HazardReport


class BaselineHazardModelTests(TestCase):
    """Test cases for BaselineHazard model."""

    def test_create_baseline_hazard(self):
        """Test creating a baseline hazard."""
        hazard = BaselineHazard.objects.create(
            hazard_type='flood',
            latitude=14.5995,
            longitude=120.9842,
            severity=0.8,
            source='MDRRMO',
        )
        self.assertEqual(hazard.hazard_type, 'flood')
        self.assertEqual(float(hazard.latitude), 14.5995)
        self.assertEqual(float(hazard.longitude), 120.9842)
        self.assertEqual(float(hazard.severity), 0.8)
        self.assertEqual(hazard.source, 'MDRRMO')

    def test_baseline_hazard_str(self):
        """Test string representation."""
        hazard = BaselineHazard.objects.create(
            hazard_type='landslide',
            latitude=14.6000,
            longitude=120.9850,
            severity=0.6,
        )
        self.assertIn('landslide', str(hazard))

    def test_baseline_hazard_default_source(self):
        """Test that default source is MDRRMO."""
        hazard = BaselineHazard.objects.create(
            hazard_type='fire',
            latitude=14.5990,
            longitude=120.9840,
            severity=0.5,
        )
        self.assertEqual(hazard.source, 'MDRRMO')


class HazardReportModelTests(TestCase):
    """Test cases for HazardReport model."""

    def setUp(self):
        """Create test user."""
        self.user = User.objects.create_user(
            username='testuser',
            password='testpass123',
            role=User.Role.RESIDENT,
        )

    def test_create_hazard_report(self):
        """Test creating a hazard report."""
        report = HazardReport.objects.create(
            user=self.user,
            hazard_type='flood',
            latitude=14.5995,
            longitude=120.9842,
            description='Heavy flooding on Main St',
            status=HazardReport.Status.PENDING,
        )
        self.assertEqual(report.user, self.user)
        self.assertEqual(report.hazard_type, 'flood')
        self.assertEqual(report.status, HazardReport.Status.PENDING)

    def test_hazard_report_default_status(self):
        """Test that default status is PENDING."""
        report = HazardReport.objects.create(
            user=self.user,
            hazard_type='landslide',
            latitude=14.6000,
            longitude=120.9850,
        )
        self.assertEqual(report.status, HazardReport.Status.PENDING)

    def test_hazard_report_str(self):
        """Test string representation."""
        report = HazardReport.objects.create(
            user=self.user,
            hazard_type='fire',
            latitude=14.5990,
            longitude=120.9840,
            status=HazardReport.Status.APPROVED,
        )
        self.assertIn('fire', str(report))
        self.assertIn('approved', str(report).lower())

    def test_hazard_report_scores(self):
        """Test naive bayes and consensus scores."""
        report = HazardReport.objects.create(
            user=self.user,
            hazard_type='flood',
            latitude=14.5995,
            longitude=120.9842,
            naive_bayes_score=0.85,
            consensus_score=0.75,
        )
        self.assertEqual(report.naive_bayes_score, 0.85)
        self.assertEqual(report.consensus_score, 0.75)

    def test_hazard_report_status_choices(self):
        """Test all status choices work."""
        for status in [HazardReport.Status.PENDING, 
                      HazardReport.Status.APPROVED,
                      HazardReport.Status.REJECTED]:
            report = HazardReport.objects.create(
                user=self.user,
                hazard_type='flood',
                latitude=14.5995,
                longitude=120.9842,
                status=status,
            )
            self.assertEqual(report.status, status)
            report.delete()

    def test_hazard_report_optional_fields(self):
        """Test that optional fields can be blank."""
        report = HazardReport.objects.create(
            user=self.user,
            hazard_type='flood',
            latitude=14.5995,
            longitude=120.9842,
            # description and photo_url are optional
        )
        self.assertEqual(report.description, '')
        self.assertEqual(report.photo_url, '')
