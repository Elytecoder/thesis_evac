"""
Tests for evacuation center models.
"""
from django.test import TestCase
from apps.evacuation.models import EvacuationCenter


class EvacuationCenterModelTests(TestCase):
    """Test cases for EvacuationCenter model."""

    def test_create_evacuation_center(self):
        """Test creating an evacuation center."""
        center = EvacuationCenter.objects.create(
            name='City Hall Evacuation Center',
            latitude=14.6000,
            longitude=120.9850,
            address='123 Main Street',
            description='Large capacity center with medical facilities',
        )
        self.assertEqual(center.name, 'City Hall Evacuation Center')
        self.assertEqual(float(center.latitude), 14.6000)
        self.assertEqual(float(center.longitude), 120.9850)
        self.assertEqual(center.address, '123 Main Street')
        self.assertIn('medical', center.description)

    def test_evacuation_center_minimal(self):
        """Test creating center with minimal required fields."""
        center = EvacuationCenter.objects.create(
            name='Basic Center',
            latitude=14.5995,
            longitude=120.9842,
        )
        self.assertEqual(center.name, 'Basic Center')
        self.assertEqual(center.address, '')
        self.assertEqual(center.description, '')

    def test_evacuation_center_str(self):
        """Test string representation."""
        center = EvacuationCenter.objects.create(
            name='Test Evacuation Center',
            latitude=14.6000,
            longitude=120.9850,
        )
        self.assertEqual(str(center), 'Test Evacuation Center')

    def test_multiple_evacuation_centers(self):
        """Test creating multiple evacuation centers."""
        center1 = EvacuationCenter.objects.create(
            name='Center 1',
            latitude=14.5995,
            longitude=120.9842,
        )
        center2 = EvacuationCenter.objects.create(
            name='Center 2',
            latitude=14.6010,
            longitude=120.9860,
        )
        self.assertEqual(EvacuationCenter.objects.count(), 2)
        self.assertNotEqual(center1.id, center2.id)
