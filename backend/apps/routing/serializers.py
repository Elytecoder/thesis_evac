"""Serializers for route calculation and logging."""
from rest_framework import serializers
from .models import RouteLog


class CalculateRouteRequestSerializer(serializers.Serializer):
    """POST /api/calculate-route/ body."""
    start_lat = serializers.DecimalField(max_digits=10, decimal_places=7)
    start_lng = serializers.DecimalField(max_digits=10, decimal_places=7)
    evacuation_center_id = serializers.IntegerField()


class RouteLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = RouteLog
        fields = ('id', 'user', 'evacuation_center', 'selected_route_risk', 'created_at')
