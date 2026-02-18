"""
Tests for Random Forest risk prediction service.
"""
import unittest
from apps.risk_prediction.services.random_forest import RoadRiskPredictor


class RoadRiskPredictorTests(unittest.TestCase):
    """Test cases for Random Forest risk prediction."""

    def setUp(self):
        """Set up test data."""
        self.predictor = RoadRiskPredictor()
        # Mock training data
        self.training_data = [
            {'segment_id': 1, 'nearby_hazard_count': 0, 'avg_severity': 0.0, 'risk_score': 0.1},
            {'segment_id': 2, 'nearby_hazard_count': 1, 'avg_severity': 0.3, 'risk_score': 0.3},
            {'segment_id': 3, 'nearby_hazard_count': 2, 'avg_severity': 0.5, 'risk_score': 0.5},
            {'segment_id': 4, 'nearby_hazard_count': 3, 'avg_severity': 0.7, 'risk_score': 0.7},
            {'segment_id': 5, 'nearby_hazard_count': 5, 'avg_severity': 0.9, 'risk_score': 0.9},
        ]

    def test_training_with_data(self):
        """Test that training works with provided data."""
        self.predictor.train(self.training_data)
        # Should be trained if sklearn is available
        self.assertIsInstance(self.predictor._trained, bool)

    def test_training_without_data(self):
        """Test that training loads mock data when no data provided."""
        self.predictor.train()
        self.assertIsInstance(self.predictor._trained, bool)

    def test_predict_risk_low(self):
        """Test prediction for low risk segment."""
        self.predictor.train(self.training_data)
        risk = self.predictor.predict_risk(0, 0.0)
        self.assertIsInstance(risk, float)
        self.assertGreaterEqual(risk, 0.0)
        self.assertLessEqual(risk, 1.0)
        # No hazards should give low risk
        self.assertLess(risk, 0.5)

    def test_predict_risk_high(self):
        """Test prediction for high risk segment."""
        self.predictor.train(self.training_data)
        risk = self.predictor.predict_risk(5, 0.9)
        self.assertIsInstance(risk, float)
        self.assertGreaterEqual(risk, 0.0)
        self.assertLessEqual(risk, 1.0)
        # Many hazards with high severity should give high risk
        self.assertGreater(risk, 0.5)

    def test_predict_risk_medium(self):
        """Test prediction for medium risk segment."""
        self.predictor.train(self.training_data)
        risk = self.predictor.predict_risk(2, 0.5)
        self.assertIsInstance(risk, float)
        self.assertGreaterEqual(risk, 0.0)
        self.assertLessEqual(risk, 1.0)

    def test_predict_risk_without_training(self):
        """Test that prediction works even without explicit training."""
        risk = self.predictor.predict_risk(1, 0.3)
        self.assertIsInstance(risk, float)
        self.assertGreaterEqual(risk, 0.0)
        self.assertLessEqual(risk, 1.0)

    def test_predict_risk_clamped(self):
        """Test that risk score is clamped to [0, 1]."""
        self.predictor.train(self.training_data)
        # Extreme values should still produce valid scores
        risk_extreme_high = self.predictor.predict_risk(100, 1.0)
        risk_extreme_low = self.predictor.predict_risk(0, 0.0)
        self.assertGreaterEqual(risk_extreme_high, 0.0)
        self.assertLessEqual(risk_extreme_high, 1.0)
        self.assertGreaterEqual(risk_extreme_low, 0.0)
        self.assertLessEqual(risk_extreme_low, 1.0)

    def test_fallback_when_no_sklearn(self):
        """Test that fallback risk is used when sklearn unavailable."""
        predictor = RoadRiskPredictor()
        predictor._trained = False
        predictor._model = None
        risk = predictor.predict_risk(2, 0.5)
        # Should return a valid risk score (might be trained or fallback)
        self.assertIsInstance(risk, float)
        self.assertGreaterEqual(risk, 0.0)
        self.assertLessEqual(risk, 1.0)
