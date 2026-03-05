"""Serializers for hazard reports and baseline hazards."""
from rest_framework import serializers
from .models import HazardReport, BaselineHazard


class HazardReportCreateSerializer(serializers.ModelSerializer):
    """For POST /api/report-hazard/. user_latitude/user_longitude optional (for proximity feature in Naive Bayes)."""
    photo_url = serializers.URLField(required=False, allow_blank=True)
    description = serializers.CharField(required=False, allow_blank=True)
    user_latitude = serializers.DecimalField(max_digits=10, decimal_places=7, required=False, allow_null=True)
    user_longitude = serializers.DecimalField(max_digits=10, decimal_places=7, required=False, allow_null=True)

    class Meta:
        model = HazardReport
        fields = ('hazard_type', 'latitude', 'longitude', 'description', 'photo_url', 'user_latitude', 'user_longitude')


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
