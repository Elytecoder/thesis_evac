"""
Consensus scoring: increase confidence when multiple reports exist within radius.
Combines with Naive Bayes score for final validated hazard score.
"""
from decimal import Decimal
from typing import Optional

from core.utils.geo import within_radius


# Default radius in meters for counting nearby reports
CONSENSUS_RADIUS_METERS = 50.0


class ConsensusScoringService:
    """
    Computes consensus score by counting reports within radius and boosting
    the Naive Bayes score when multiple users report the same area.
    """

    def __init__(self, radius_m: float = CONSENSUS_RADIUS_METERS):
        self.radius_m = radius_m

    def count_nearby_reports(
        self,
        lat: float,
        lng: float,
        report_queryset,
        exclude_report_id: Optional[int] = None,
    ) -> int:
        """
        Count reports (from queryset) within self.radius_m of (lat, lng).
        Optionally exclude one report by id (e.g. the current report).
        """
        lat_f = float(lat) if isinstance(lat, Decimal) else lat
        lng_f = float(lng) if isinstance(lng, Decimal) else lng
        count = 0
        for r in report_queryset:
            if exclude_report_id is not None and r.id == exclude_report_id:
                continue
            r_lat = float(r.latitude)
            r_lng = float(r.longitude)
            if within_radius(lat_f, lng_f, r_lat, r_lng, self.radius_m):
                count += 1
        return count

    def combined_score(
        self,
        naive_bayes_score: float,
        nearby_count: int,
        alpha: float = 0.7,
    ) -> float:
        """
        Combine Naive Bayes score with consensus boost.
        consensus_boost: higher when nearby_count is higher (capped).
        final = alpha * nb_score + (1 - alpha) * consensus_boost
        """
        # Simple boost: 0.1 per nearby report, max 0.3
        consensus_boost = min(0.3, nearby_count * 0.1)
        return alpha * naive_bayes_score + (1 - alpha) * (0.5 + consensus_boost)
