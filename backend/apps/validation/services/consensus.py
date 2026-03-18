"""
Nearby-report counting for hazard reports.

Validation is now fully handled by Naive Bayes; consensus is no longer
a separate scoring formula. This module only provides the count of
similar reports within radius and time window, which is passed as a
feature (nearby_similar_report_count_category) to Naive Bayes.
"""
from decimal import Decimal
from typing import Optional
from datetime import timedelta
from django.utils import timezone

from core.utils.geo import within_radius


# Radius in meters for counting nearby reports (same hazard area).
CONSENSUS_RADIUS_METERS = 50.0
# Time window: only count reports within this many hours.
NEARBY_TIME_WINDOW_HOURS = 1


class ConsensusScoringService:
    """
    Counts nearby reports within radius and optional time window.
    Used only to compute nearby_similar_report_count_category for Naive Bayes.
    No combined_score or percentage boost logic.
    """

    def __init__(self, radius_m: float = CONSENSUS_RADIUS_METERS):
        self.radius_m = radius_m

    def count_nearby_reports(
        self,
        lat: float,
        lng: float,
        report_queryset,
        exclude_report_id: Optional[int] = None,
        time_window_hours: Optional[float] = None,
    ) -> int:
        """
        Count reports within self.radius_m of (lat, lng).
        If time_window_hours is set, only count reports created within that window.
        Optionally exclude one report by id.
        """
        lat_f = float(lat) if isinstance(lat, Decimal) else lat
        lng_f = float(lng) if isinstance(lng, Decimal) else lng
        qs = report_queryset
        if time_window_hours is not None:
            since = timezone.now() - timedelta(hours=time_window_hours)
            qs = qs.filter(created_at__gte=since)
        count = 0
        for r in qs:
            if exclude_report_id is not None and r.id == exclude_report_id:
                continue
            r_lat = float(r.latitude)
            r_lng = float(r.longitude)
            if within_radius(lat_f, lng_f, r_lat, r_lng, self.radius_m):
                count += 1
        return count
