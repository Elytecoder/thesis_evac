"""
ML Service — loads trained sklearn models and provides predictions.

# Using synthetic training data (temporary)
# Replace with MDRRMO historical data when available

Models:
    naive_bayes_model.pkl  — MultinomialNB for report credibility scoring
    vectorizer.pkl         — CountVectorizer fitted on training text
    random_forest_model.pkl — RandomForestRegressor for road segment risk

Usage:
    from ml_data.ml_service import get_ml_service
    ml = get_ml_service()
    score = ml.predict_naive_bayes('flooded_road', 'deep flood blocking road')
    risk  = ml.predict_road_risk(flood_count=2, landslide_count=0,
                                  avg_severity=0.6, incident_count=5)
"""
import pickle
import logging
from pathlib import Path

logger = logging.getLogger(__name__)

MODELS_DIR = Path(__file__).parent / 'models'
ML_DATA_DIR = Path(__file__).parent

try:
    import numpy as np
    from sklearn.naive_bayes import MultinomialNB
    from sklearn.feature_extraction.text import CountVectorizer
    from sklearn.ensemble import RandomForestRegressor
    HAS_SKLEARN = True
except ImportError:
    HAS_SKLEARN = False
    logger.warning('scikit-learn not available — ml_service will return fallback values.')


class MLService:
    """
    Singleton service that loads and caches trained ML models.
    Falls back gracefully if models are not yet trained.
    """

    def __init__(self):
        self._nb_model = None
        self._vectorizer = None
        self._rf_model = None
        self._nb_ready = False
        self._rf_ready = False

    # ─── Naive Bayes ─────────────────────────────────────────────────────────

    def _load_nb(self) -> bool:
        """Load NB model and vectorizer from disk. Returns True if successful."""
        if not HAS_SKLEARN:
            return False
        nb_path = MODELS_DIR / 'naive_bayes_model.pkl'
        vec_path = MODELS_DIR / 'vectorizer.pkl'
        if not (nb_path.exists() and vec_path.exists()):
            logger.info('NB models not found — attempting auto-train.')
            return self._auto_train_nb()
        try:
            with open(nb_path, 'rb') as f:
                self._nb_model = pickle.load(f)
            with open(vec_path, 'rb') as f:
                self._vectorizer = pickle.load(f)
            self._nb_ready = True
            logger.info('NB model loaded from %s', MODELS_DIR)
            return True
        except Exception as e:
            logger.error('Failed to load NB model: %s', e)
            return False

    def _auto_train_nb(self) -> bool:
        """Auto-train NB from CSV if models are missing."""
        try:
            from ml_data.train_naive_bayes import train_and_save
            train_and_save()
            nb_path = MODELS_DIR / 'naive_bayes_model.pkl'
            vec_path = MODELS_DIR / 'vectorizer.pkl'
            if nb_path.exists() and vec_path.exists():
                with open(nb_path, 'rb') as f:
                    self._nb_model = pickle.load(f)
                with open(vec_path, 'rb') as f:
                    self._vectorizer = pickle.load(f)
                self._nb_ready = True
                return True
        except Exception as e:
            logger.error('NB auto-train failed: %s', e)
        return False

    def predict_naive_bayes(self, hazard_type: str, description: str) -> float:
        """
        Predict P(valid | hazard_type, description) using trained MultinomialNB.

        Input text = hazard_type + ' ' + description (combined for vectorizer).
        Returns float in [0, 1]. Falls back to 0.5 if model unavailable.

        # Using synthetic training data (temporary)
        # Replace with MDRRMO historical data when available
        """
        if not self._nb_ready:
            self._load_nb()
        if not self._nb_ready or self._nb_model is None or self._vectorizer is None:
            return 0.5  # neutral fallback
        try:
            text = f"{hazard_type or 'other'} {description or ''}"
            X = self._vectorizer.transform([text])
            proba = self._nb_model.predict_proba(X)[0]
            # classes_ order: [0=invalid, 1=valid]
            classes = list(self._nb_model.classes_)
            valid_idx = classes.index(1) if 1 in classes else 1
            return float(max(0.0, min(1.0, proba[valid_idx])))
        except Exception as e:
            logger.error('NB prediction error: %s', e)
            return 0.5

    # ─── Random Forest ───────────────────────────────────────────────────────

    def _load_rf(self) -> bool:
        """Load RF model from disk. Returns True if successful."""
        if not HAS_SKLEARN:
            return False
        rf_path = MODELS_DIR / 'random_forest_model.pkl'
        if not rf_path.exists():
            logger.info('RF model not found — attempting auto-train.')
            return self._auto_train_rf()
        try:
            with open(rf_path, 'rb') as f:
                self._rf_model = pickle.load(f)
            self._rf_ready = True
            logger.info('RF model loaded from %s', MODELS_DIR)
            return True
        except Exception as e:
            logger.error('Failed to load RF model: %s', e)
            return False

    def _auto_train_rf(self) -> bool:
        """Auto-train RF from CSV if model is missing."""
        try:
            from ml_data.train_random_forest import train_and_save
            train_and_save()
            rf_path = MODELS_DIR / 'random_forest_model.pkl'
            if rf_path.exists():
                with open(rf_path, 'rb') as f:
                    self._rf_model = pickle.load(f)
                self._rf_ready = True
                return True
        except Exception as e:
            logger.error('RF auto-train failed: %s', e)
        return False

    def predict_road_risk(
        self,
        flooded_road_count: int = 0,
        landslide_count: int = 0,
        fallen_tree_count: int = 0,
        road_damage_count: int = 0,
        fallen_electric_post_count: int = 0,
        road_blocked_count: int = 0,
        bridge_damage_count: int = 0,
        storm_surge_count: int = 0,
        avg_severity: float = 0.0,
    ) -> float:
        """
        Predict road segment risk score using trained RandomForestRegressor.

        One count per actual hazard type in the system:
            flooded_road_count         — nearby approved flooded_road reports
            landslide_count            — nearby approved landslide reports
            fallen_tree_count          — nearby approved fallen_tree reports
            road_damage_count          — nearby approved road_damage reports
            fallen_electric_post_count — nearby approved fallen_electric_post reports
            road_blocked_count         — nearby approved road_blocked reports
            bridge_damage_count        — nearby approved bridge_damage reports
            storm_surge_count          — nearby approved storm_surge reports
            avg_severity               — average final_validation_score of nearby reports

        Returns float in [0, 1]. Falls back to weighted formula if model unavailable.

        # Using synthetic training data (temporary)
        # Replace with MDRRMO historical data when available
        """
        if not self._rf_ready:
            self._load_rf()
        if self._rf_ready and self._rf_model is not None and HAS_SKLEARN:
            try:
                X = np.array([[
                    float(flooded_road_count),
                    float(landslide_count),
                    float(fallen_tree_count),
                    float(road_damage_count),
                    float(fallen_electric_post_count),
                    float(road_blocked_count),
                    float(bridge_damage_count),
                    float(storm_surge_count),
                    float(avg_severity),
                ]])
                pred = self._rf_model.predict(X)[0]
                return float(max(0.0, min(1.0, pred)))
            except Exception as e:
                logger.error('RF prediction error: %s', e)
        # Fallback: formula-based risk (aligned with HAZARD_TYPE_RISK_WEIGHT in route_service)
        risk = (
            flooded_road_count         * 0.04
            + landslide_count          * 0.07
            + fallen_tree_count        * 0.03
            + road_damage_count        * 0.04
            + fallen_electric_post_count * 0.05
            + road_blocked_count       * 0.09
            + bridge_damage_count      * 0.07
            + storm_surge_count        * 0.07
            + avg_severity             * 0.50
        )
        return max(0.0, min(1.0, risk))


# Singleton instance
_ml_service: MLService | None = None


def get_ml_service() -> MLService:
    """Return the shared MLService singleton."""
    global _ml_service
    if _ml_service is None:
        _ml_service = MLService()
    return _ml_service
