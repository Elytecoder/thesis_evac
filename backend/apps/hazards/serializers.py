"""Serializers for hazard reports and baseline hazards."""
from rest_framework import serializers
from .models import HazardReport, BaselineHazard


def _round_coord(value):
    """Round coordinate to 7 decimal places (DB accepts max_digits=10, decimal_places=7)."""
    if value is None:
        return None
    return round(float(value), 7)


class HazardReportCreateSerializer(serializers.ModelSerializer):
    """For POST /api/report-hazard/. Accepts floats for coords; rounds to 7 decimal places for DB."""
    photo_url = serializers.URLField(required=False, allow_blank=True)
    description = serializers.CharField(required=False, allow_blank=True)
    latitude = serializers.FloatField()
    longitude = serializers.FloatField()
    user_latitude = serializers.FloatField(required=False, allow_null=True)
    user_longitude = serializers.FloatField(required=False, allow_null=True)

    class Meta:
        model = HazardReport
        fields = ('hazard_type', 'latitude', 'longitude', 'description', 'photo_url', 'user_latitude', 'user_longitude')

    def validate_latitude(self, value):
        return _round_coord(value)

    def validate_longitude(self, value):
        return _round_coord(value)

    def validate_user_latitude(self, value):
        return _round_coord(value)

    def validate_user_longitude(self, value):
        return _round_coord(value)


class HazardReportSerializer(serializers.ModelSerializer):
    """Full read serializer for reports. validation_breakdown = Naive Bayes technical details only (no Random Forest)."""
    class Meta:
        model = HazardReport
        fields = (
            'id', 'user', 'hazard_type', 'latitude', 'longitude',
            'description', 'photo_url', 'status', 'naive_bayes_score',
            'consensus_score', 'validation_breakdown', 'created_at',
        )


class PendingReportSerializer(serializers.ModelSerializer):
    """For MDRRMO pending list. validation_breakdown used in Report Details → View Technical Details."""
    class Meta:
        model = HazardReport
        fields = (
            'id', 'user', 'hazard_type', 'latitude', 'longitude',
            'description', 'status', 'naive_bayes_score', 'consensus_score',
            'validation_breakdown', 'created_at',
        )
