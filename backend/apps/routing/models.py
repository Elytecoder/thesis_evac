"""
Road network and route logging.
RoadSegment = graph edges; RouteLog = user route history.
"""
from django.conf import settings
from django.db import models


class RoadSegment(models.Model):
    """
    Edge in the road network graph.
    base_distance in meters (or normalized). predicted_risk_score from Random Forest.
    """
    start_lat = models.DecimalField(max_digits=10, decimal_places=7)
    start_lng = models.DecimalField(max_digits=10, decimal_places=7)
    end_lat = models.DecimalField(max_digits=10, decimal_places=7)
    end_lng = models.DecimalField(max_digits=10, decimal_places=7)
    base_distance = models.FloatField(default=0)  # meters or normalized
    predicted_risk_score = models.FloatField(default=0)
    last_updated = models.DateTimeField(auto_now=True)  # Auto-updates when risk score changes

    class Meta:
        db_table = 'routing_roadsegment'

    def __str__(self):
        return f"({self.start_lat},{self.start_lng}) -> ({self.end_lat},{self.end_lng})"


class RouteLog(models.Model):
    """
    Log of a user's selected evacuation route (for analytics/feedback).
    """
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='route_logs',
    )
    evacuation_center = models.ForeignKey(
        'evacuation.EvacuationCenter',
        on_delete=models.CASCADE,
        related_name='route_logs',
    )
    selected_route_risk = models.FloatField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'routing_routelog'

    def __str__(self):
        return f"User {self.user_id} -> {self.evacuation_center} (risk: {self.selected_route_risk})"
