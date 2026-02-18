"""Serializers for hazard reports and baseline hazards."""
from rest_framework import serializers
from .models import HazardReport, BaselineHazard


class HazardReportCreateSerializer(serializers.ModelSerializer):
    """For POST /api/report-hazard/"""
    photo_url = serializers.URLField(required=False, allow_blank=True)
    description = serializers.CharField(required=False, allow_blank=True)

    class Meta:
        model = HazardReport
        fields = ('hazard_type', 'latitude', 'longitude', 'description', 'photo_url')


class HazardReportSerializer(serializers.ModelSerializer):
    """Full read serializer for reports."""
    class Meta:
        model = HazardReport
        fields = (
            'id', 'user', 'hazard_type', 'latitude', 'longitude',
            'description', 'photo_url', 'status', 'naive_bayes_score',
            'consensus_score', 'created_at',
        )


class PendingReportSerializer(serializers.ModelSerializer):
    """For MDRRMO pending list (minimal)."""
    class Meta:
        model = HazardReport
        fields = (
            'id', 'user', 'hazard_type', 'latitude', 'longitude',
            'description', 'status', 'naive_bayes_score', 'consensus_score', 'created_at',
        )
