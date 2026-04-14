"""
Nearby-report counting for hazard reports.

Naive Bayes does not use nearby count. This service only counts reports
within radius and time window; report_service maps the count to
rule_scoring.consensus_rule_score (separate from NB).

Consensus rules:
- Only reports of the SAME hazard_type are counted (different hazard types
  at the same location are unrelated events).
- Only PENDING or APPROVED reports are counted (REJECTED reports are excluded
  as they were deemed invalid by MDRRMO or auto-rejected by the system).
- Reports must be within CONSENSUS_RADIUS_METERS (100 m) to be considered
  part of the same incident area.
"""
from decimal import Decimal
from typing import Optional
from datetime import timedelta
from django.utils import timezone

from core.utils.geo import within_radius


# Radius in meters for counting nearby reports of the same hazard type.
# Updated: Changed from 50 m to 100 m to better capture the same incident area.
CONSENSUS_RADIUS_METERS = 100.0
# Time window: only count reports within this many hours.
NEARBY_TIME_WINDOW_HOURS = 1


class ConsensusScoringService:
    """
    Counts nearby reports of the same hazard type within radius and optional
    time window. Used by report_service for consensus_rule_score (rule layer,
    not NB features).
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
        hazard_type: Optional[str] = None,
    ) -> int:
        """
        Count reports within self.radius_m of (lat, lng) that share the same
        hazard_type and have PENDING or APPROVED status.

        Parameters
        ----------
        lat, lng           : centre of the search area
        report_queryset    : base queryset (e.g. HazardReport.objects.all())
        exclude_report_id  : skip the report being scored (avoid self-count)
        time_window_hours  : if set, only include reports created within this window
        hazard_type        : if set, only include reports with this exact hazard_type
        """
        lat_f = float(lat) if isinstance(lat, Decimal) else lat
        lng_f = float(lng) if isinstance(lng, Decimal) else lng

        qs = report_queryset

        # Only count PENDING or APPROVED reports — rejected reports are invalid.
        qs = qs.filter(status__in=['pending', 'approved'])

        # Only count reports of the same hazard type.
        if hazard_type:
            qs = qs.filter(hazard_type=hazard_type)

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
