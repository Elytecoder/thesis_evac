"""
Nearby-report support logic for hazard consensus scoring.

Naive Bayes does not use nearby count. This service computes corroboration
signals used by rule_scoring.consensus_rule_score.

Consensus rules:
- only SAME hazard_type reports are considered
- only PENDING / APPROVED reports are considered
- only reports within 150 m and within the configured time window are considered
- duplicate reports in the same area/time are clustered to prevent inflation
"""
from dataclasses import dataclass
from datetime import timedelta
from decimal import Decimal
from typing import Optional

from django.utils import timezone

from core.utils.geo import haversine_meters, within_radius


CONSENSUS_RADIUS_METERS = 150.0
NEARBY_TIME_WINDOW_HOURS = 1


class ConsensusScoringService:
    def __init__(self, radius_m: float = CONSENSUS_RADIUS_METERS):
        self.radius_m = radius_m

    @dataclass
    class SupportSummary:
        nearby_raw_reports: int
        nearby_cluster_count: int
        nearby_unique_user_count: int

    def _filtered_queryset(
        self,
        report_queryset,
        hazard_type: Optional[str],
        time_window_hours: Optional[float],
    ):
        qs = report_queryset.filter(status__in=['pending', 'approved'])
        if hazard_type:
            qs = qs.filter(hazard_type=hazard_type)
        if time_window_hours is not None:
            since = timezone.now() - timedelta(hours=time_window_hours)
            qs = qs.filter(created_at__gte=since)
        return qs

    def get_support_summary(
        self,
        lat: float,
        lng: float,
        report_queryset,
        exclude_report_id: Optional[int] = None,
        time_window_hours: Optional[float] = None,
        hazard_type: Optional[str] = None,
    ) -> "ConsensusScoringService.SupportSummary":
        lat_f = float(lat) if isinstance(lat, Decimal) else float(lat)
        lng_f = float(lng) if isinstance(lng, Decimal) else float(lng)
        qs = self._filtered_queryset(report_queryset, hazard_type, time_window_hours)

        nearby_reports = []
        for report in qs:
            if exclude_report_id is not None and report.id == exclude_report_id:
                continue
            report_lat = float(report.latitude)
            report_lng = float(report.longitude)
            if within_radius(lat_f, lng_f, report_lat, report_lng, self.radius_m):
                nearby_reports.append(report)

        if not nearby_reports:
            return self.SupportSummary(0, 0, 0)

        # Cluster nearby reports by proximity + time overlap (anti-duplicate logic).
        clusters = []
        time_window_seconds = (time_window_hours or NEARBY_TIME_WINDOW_HOURS) * 3600.0
        for report in nearby_reports:
            report_lat = float(report.latitude)
            report_lng = float(report.longitude)
            report_ts = report.created_at.timestamp() if report.created_at else 0.0
            placed = False

            for cluster in clusters:
                if (
                    haversine_meters(report_lat, report_lng, cluster['rep_lat'], cluster['rep_lng']) <= self.radius_m
                    and abs(report_ts - cluster['rep_ts']) <= time_window_seconds
                ):
                    cluster['user_ids'].add(report.user_id)
                    placed = True
                    break

            if not placed:
                clusters.append({
                    'rep_lat': report_lat,
                    'rep_lng': report_lng,
                    'rep_ts': report_ts,
                    'user_ids': {report.user_id},
                })

        unique_user_ids = {report.user_id for report in nearby_reports}
        return self.SupportSummary(
            nearby_raw_reports=len(nearby_reports),
            nearby_cluster_count=len(clusters),
            nearby_unique_user_count=len(unique_user_ids),
        )

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
        Backward-compatible helper returning deduplicated cluster count.
        """
        summary = self.get_support_summary(
            lat=lat,
            lng=lng,
            report_queryset=report_queryset,
            exclude_report_id=exclude_report_id,
            time_window_hours=time_window_hours,
            hazard_type=hazard_type,
        )
        return summary.nearby_cluster_count

    def find_similar_existing_report(
        self,
        lat: float,
        lng: float,
        report_queryset,
        hazard_type: Optional[str] = None,
        time_window_hours: Optional[float] = NEARBY_TIME_WINDOW_HOURS,
        exclude_report_id: Optional[int] = None,
    ):
        """
        Return nearest existing active report within radius/type/window, if any.
        Used to block duplicate submissions and force confirmation flow.
        """
        lat_f = float(lat) if isinstance(lat, Decimal) else float(lat)
        lng_f = float(lng) if isinstance(lng, Decimal) else float(lng)
        qs = self._filtered_queryset(report_queryset, hazard_type, time_window_hours)

        best_report = None
        best_distance = float('inf')
        for report in qs:
            if exclude_report_id is not None and report.id == exclude_report_id:
                continue
            report_lat = float(report.latitude)
            report_lng = float(report.longitude)
            distance = haversine_meters(lat_f, lng_f, report_lat, report_lng)
            if distance <= self.radius_m and distance < best_distance:
                best_distance = distance
                best_report = report
        return best_report
