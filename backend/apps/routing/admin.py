from django.contrib import admin
from .models import RoadSegment, RouteLog


@admin.register(RoadSegment)
class RoadSegmentAdmin(admin.ModelAdmin):
    list_display = ('id', 'start_lat', 'start_lng', 'end_lat', 'end_lng', 'base_distance', 'predicted_risk_score')


@admin.register(RouteLog)
class RouteLogAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'evacuation_center', 'selected_route_risk', 'created_at')
