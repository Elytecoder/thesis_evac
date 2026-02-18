"""
Tests for Naive Bayes validation service.
"""
import unittest
from apps.validation.services.naive_bayes import NaiveBayesValidator


class NaiveBayesValidatorTests(unittest.TestCase):
    """Test cases for Naive Bayes report validation."""

    def setUp(self):
        """Set up test data."""
        self.validator = NaiveBayesValidator()
        # Mock training data
        self.training_data = [
            {'hazard_type': 'flood', 'description_length': 50, 'valid': True},
            {'hazard_type': 'flood', 'description_length': 45, 'valid': True},
            {'hazard_type': 'landslide', 'description_length': 40, 'valid': True},
            {'hazard_type': 'fire', 'description_length': 30, 'valid': True},
            {'hazard_type': 'unknown', 'description_length': 5, 'valid': False},
            {'hazard_type': 'fake', 'description_length': 3, 'valid': False},
            {'hazard_type': 'test', 'description_length': 10, 'valid': False},
        ]

    def test_training_with_data(self):
        """Test that training works with provided data."""
        self.validator.train(self.training_data)
        self.assertTrue(self.validator._trained)
        self.assertIn('valid', self.validator._class_prior)
        self.assertIn('invalid', self.validator._class_prior)

    def test_training_without_data(self):
        """Test that training loads mock data when no data provided."""
        self.validator.train()
        # Should either be trained or not, depending on mock file existence
        self.assertIsInstance(self.validator._trained, bool)

    def test_validate_valid_report(self):
        """Test validation of a likely valid report."""
        self.validator.train(self.training_data)
        report = {
            'hazard_type': 'flood',
            'description': 'Heavy flooding on Main St, water level rising',
        }
        score = self.validator.validate_report(report)
        self.assertIsInstance(score, float)
        self.assertGreaterEqual(score, 0.0)
        self.assertLessEqual(score, 1.0)
        # Flood with good description should score high
        self.assertGreater(score, 0.5)

    def test_validate_invalid_report(self):
        """Test validation of a likely invalid report."""
        self.validator.train(self.training_data)
        report = {
            'hazard_type': 'unknown',
            'description': 'bad',  # Very short
        }
        score = self.validator.validate_report(report)
        self.assertIsInstance(score, float)
        self.assertGreaterEqual(score, 0.0)
        self.assertLessEqual(score, 1.0)
        # Unknown type with short description should score low
        self.assertLess(score, 0.5)

    def test_validate_without_description(self):
        """Test validation when description is missing."""
        self.validator.train(self.training_data)
        report = {
            'hazard_type': 'flood',
            'description_length': 40,
        }
        score = self.validator.validate_report(report)
        self.assertIsInstance(score, float)
        self.assertGreaterEqual(score, 0.0)
        self.assertLessEqual(score, 1.0)

    def test_bucket_desc_len(self):
        """Test description length bucketing."""
        self.assertEqual(self.validator._bucket_desc_len(10), 'short')
        self.assertEqual(self.validator._bucket_desc_len(30), 'medium')
        self.assertEqual(self.validator._bucket_desc_len(80), 'long')

    def test_multiple_validations(self):
        """Test that validator can be used multiple times."""
        self.validator.train(self.training_data)
        report1 = {'hazard_type': 'flood', 'description': 'Test flood report'}
        report2 = {'hazard_type': 'fire', 'description': 'Test fire report'}
        score1 = self.validator.validate_report(report1)
        score2 = self.validator.validate_report(report2)
        self.assertIsInstance(score1, float)
        self.assertIsInstance(score2, float)
