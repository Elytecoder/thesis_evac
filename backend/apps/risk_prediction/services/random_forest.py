"""
Random Forest service for road segment risk prediction.

Primary implementation: sklearn RandomForestRegressor via ml_service.
    One feature per actual hazard type in the system + average severity.

Fallback: formula-based risk (aligned with HAZARD_TYPE_RISK_WEIGHT in route_service).

# Using synthetic training data (temporary)
# Replace with MDRRMO historical data when available

TO REPLACE WITH REAL MDRRMO DATA:
1. Collect historical MDRRMO road incident records with per-segment hazard type counts.
2. Compute risk labels from verified incident severity.
3. Replace ml_data/random_forest_dataset.csv and run:
       python manage.py train_ml_models --rf-only --force
"""
import logging

logger = logging.getLogger(__name__)


class RoadRiskPredictor:
    """
    Predicts risk score for road segments using Random Forest via ml_service.

    Features (one per hazard type + avg_severity):
        flooded_road_count, landslide_count, fallen_tree_count, road_damage_count,
        fallen_electric_post_count, road_blocked_count, bridge_damage_count,
        storm_surge_count, avg_severity

    # Using synthetic training data (temporary)
    # Replace with MDRRMO historical data when available
    """

    def predict_risk(
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
        Predict risk score for a road segment given per-type hazard counts.

        Returns float in [0, 1] (clamped).

        # Using synthetic training data (temporary)
        # Replace with MDRRMO historical data when available
        """
        try:
            from ml_data.ml_service import get_ml_service
            return get_ml_service().predict_road_risk(
                flooded_road_count=flooded_road_count,
                landslide_count=landslide_count,
                fallen_tree_count=fallen_tree_count,
                road_damage_count=road_damage_count,
                fallen_electric_post_count=fallen_electric_post_count,
                road_blocked_count=road_blocked_count,
                bridge_damage_count=bridge_damage_count,
                storm_surge_count=storm_surge_count,
                avg_severity=avg_severity,
            )
        except Exception as e:
            logger.warning('ml_service RF unavailable, using fallback: %s', e)

        # Fallback formula (aligned with HAZARD_TYPE_RISK_WEIGHT in route_service)
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
