"""
Rule-based scoring for hazard reports — separate from Naive Bayes.

NB handles text/classification only (hazard_type + description features).
This module applies:
- distance_weight: reporter proximity to reported hazard (credibility proxy
  for "at scene"). Formula: 1 - (distance_m / 150), clamped to [0, 1].
- consensus_score: strength from deduplicated nearby incident clusters
  + unique confirmations. Formula: min((nearby_clusters + confirmations) / 5, 1.0).

final_validation_score is a weighted blend of all three components:
  (NB × 0.5) + (distance × 0.3) + (consensus × 0.2)
"""
from reports.utils import PROXIMITY_REJECT_KM

# Maximum distance in meters — mirrors PROXIMITY_REJECT_KM.
_MAX_DISTANCE_M = PROXIMITY_REJECT_KM * 1000  # 150 m


def reporter_proximity_weight(distance_km: float) -> float:
    """
    Map user-to-reported-hazard distance to [0, 1].
    Closer = higher weight (more credible that reporter is at the scene).

    Formula: 1 - (distance_m / 150), clamped to [0, 1].
    Equivalent to: 1 - (distance_km / 0.15).

    Examples:
        0 m   → 1.00  (exactly at hazard)
        75 m  → 0.50  (halfway to limit)
        150 m → 0.00  (at the reject boundary)
    """
    if distance_km is None or distance_km < 0:
        return 0.0
    distance_m = float(distance_km) * 1000
    weight = 1.0 - (distance_m / _MAX_DISTANCE_M)
    return max(0.0, min(1.0, weight))


def consensus_rule_score(nearby_similar_count: int, confirmation_count: int = 0) -> float:
    """
    Map deduplicated nearby-cluster support + user confirmations to [0, 1].

    Formula: min((nearby_clusters + confirmations) / 5, 1.0)

    Nearby support must already be deduplicated (cluster-based) to avoid
    duplicate-report inflation.

    Examples:
        0 total → 0.00
        1 total → 0.20
        2 total → 0.40
        3 total → 0.60
        4 total → 0.80
        5+      → 1.00
    """
    nearby = max(0, int(nearby_similar_count))
    confirmations = max(0, int(confirmation_count))
    total_support = nearby + confirmations
    return min(total_support / 5.0, 1.0)


def combine_validation_scores(
    naive_bayes_probability: float,
    distance_weight: float,
    consensus_score: float,
) -> float:
    """
    Final report validation score in [0, 1] using a weighted blend.

    Weights reflect each component's relative importance:
      - Naive Bayes (text credibility)  : 50%
      - Distance weight (proximity)     : 30%
      - Consensus score (corroboration) : 20%

    Formula:
        final = (NB × 0.5) + (distance × 0.3) + (consensus × 0.2)
    """
    nb = max(0.0, min(1.0, float(naive_bayes_probability)))
    dw = max(0.0, min(1.0, float(distance_weight)))
    cs = max(0.0, min(1.0, float(consensus_score)))
    combined = (nb * 0.5) + (dw * 0.3) + (cs * 0.2)
    return max(0.0, min(1.0, combined))


def distance_weight_from_user_hazard_km(distance_km: float) -> float:
    """Convenience: haversine km -> proximity weight (no NB)."""
    return reporter_proximity_weight(distance_km)
