"""
Random Forest service for road segment risk prediction.
Trains on mock road risk dataset; predicts risk per segment.
Stores result in RoadSegment.predicted_risk_score.

TO REPLACE WITH REAL MDRRMO DATA:
1. Remove mock loader.
2. Use historical MDRRMO hazard data + road network: compute per-segment
   features (nearby hazard count, severity, flood history, etc.).
3. Use MDRRMO-verified incident data as labels (risk_score or binary).
4. Retrain model when new historical data is available.
5. Persist model (joblib) and version it; reload in app startup if needed.
"""
import json
from pathlib import Path
from typing import List, Dict, Any

# Optional: use sklearn if available
try:
    from sklearn.ensemble import RandomForestRegressor
    import numpy as np
    HAS_SKLEARN = True
except ImportError:
    HAS_SKLEARN = False

MOCK_TRAINING_PATH = Path(__file__).resolve().parent.parent.parent.parent / 'mock_data' / 'mock_training_data.json'


class RoadRiskPredictor:
    """
    Predicts risk score for road segments using Random Forest.
    Features: nearby_hazard_count, avg_severity (and optionally segment geometry).
    """

    def __init__(self):
        self._model = None
        self._trained = False
        self._fallback_risk = 0.3  # when no sklearn or no data

    def _load_mock_training(self, path: Path = None) -> List[Dict[str, Any]]:
        """
        Load road_risk_training from mock JSON.
        TO REPLACE: Build features from BaselineHazard + RoadSegment (e.g. count hazards near segment).
        """
        path = path or MOCK_TRAINING_PATH
        if not path.exists():
            return []
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        return data.get('road_risk_training', [])

    def train(self, training_data: List[Dict[str, Any]] = None) -> None:
        """
        Train Random Forest on segment features -> risk_score.
        training_data: list of {segment_id, nearby_hazard_count, avg_severity, risk_score}.
        """
        if training_data is None:
            training_data = self._load_mock_training()
        if not training_data or not HAS_SKLEARN:
            self._trained = False
            return

        X = []
        y = []
        for row in training_data:
            X.append([row.get('nearby_hazard_count', 0), row.get('avg_severity', 0)])
            y.append(row.get('risk_score', 0))
        X = np.array(X)
        y = np.array(y)
        self._model = RandomForestRegressor(n_estimators=10, random_state=42)
        self._model.fit(X, y)
        self._trained = True

    def predict_risk(self, nearby_hazard_count: float, avg_severity: float) -> float:
        """
        Predict risk score for a segment given features.
        Returns value in [0, 1] (clamped).
        """
        if not self._trained and HAS_SKLEARN:
            self.train()
        if self._trained and self._model is not None and HAS_SKLEARN:
            pred = self._model.predict([[nearby_hazard_count, avg_severity]])[0]
            return max(0.0, min(1.0, float(pred)))
        return self._fallback_risk
