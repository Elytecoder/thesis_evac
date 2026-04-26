"""Serializers for hazard reports and baseline hazards."""
from rest_framework import serializers

from .models import HazardReport


def _round_coord(value):
    """Round coordinate to 7 decimal places (DB accepts max_digits=10, decimal_places=7)."""
    if value is None:
        return None
    return round(float(value), 7)


class HazardReportCreateSerializer(serializers.ModelSerializer):
    """For POST /api/report-hazard/. Accepts floats for coords; rounds to 7 decimal places for DB."""
    photo_url = serializers.CharField(required=False, allow_blank=True)
    video_url = serializers.CharField(required=False, allow_blank=True)
    description = serializers.CharField(required=False, allow_blank=True)
    latitude = serializers.FloatField()
    longitude = serializers.FloatField()
    user_latitude = serializers.FloatField(required=False, allow_null=True)
    user_longitude = serializers.FloatField(required=False, allow_null=True)

    class Meta:
        model = HazardReport
        fields = (
            'hazard_type', 'latitude', 'longitude', 'description',
            'photo_url', 'video_url', 'user_latitude', 'user_longitude',
        )

    def validate_latitude(self, value):
        return _round_coord(value)

    def validate_longitude(self, value):
        return _round_coord(value)

    def validate_user_latitude(self, value):
        return _round_coord(value)

    def validate_user_longitude(self, value):
        return _round_coord(value)


def _reporter_full_name_for_report(obj):
    u = getattr(obj, 'user', None)
    if u is None:
        return ''
    fn = (getattr(u, 'full_name', None) or '').strip()
    if fn:
        return fn
    gn = (u.get_full_name() or '').strip()
    if gn:
        return gn
    return (getattr(u, 'username', None) or '').strip() or ''


def _reporter_display_id_for_report(obj):
    u = getattr(obj, 'user', None)
    if u is None:
        return None
    return getattr(u, 'public_display_id', None)


def _reporter_barangay_for_report(obj):
    u = getattr(obj, 'user', None)
    if u is None:
        return ''
    from apps.users.barangay_utils import normalize_barangay_label

    return normalize_barangay_label(getattr(u, 'barangay', '') or '')


class HazardReportSerializer(serializers.ModelSerializer):
    """Full read serializer: NB + rule scores + breakdown (no Random Forest in validation)."""

    reporter_full_name = serializers.SerializerMethodField()
    reporter_display_id = serializers.SerializerMethodField()
    display_report_id = serializers.SerializerMethodField()
    reporter_barangay = serializers.SerializerMethodField()
    confirmation_count = serializers.SerializerMethodField()
    photo_url = serializers.SerializerMethodField()
    video_url = serializers.SerializerMethodField()

    class Meta:
        model = HazardReport
        fields = (
            'id',
            'user',
            'hazard_type',
            'latitude',
            'longitude',
            'description',
            'photo_url',
            'video_url',
            'status',
            'auto_rejected',
            'naive_bayes_score',
            'consensus_score',
            'distance_weight',
            'final_validation_score',
            'validation_breakdown',
            'created_at',
            'reporter_full_name',
            'reporter_display_id',
            'display_report_id',
            'reporter_barangay',
            'confirmation_count',
        )

    def get_reporter_full_name(self, obj):
        return _reporter_full_name_for_report(obj)

    def get_reporter_display_id(self, obj):
        return _reporter_display_id_for_report(obj)

    def get_display_report_id(self, obj):
        return getattr(obj, 'public_reference', None)

    def get_reporter_barangay(self, obj):
        return _reporter_barangay_for_report(obj)

    def get_confirmation_count(self, obj):
        return obj.confirmation_count

    def get_photo_url(self, obj):
        """Strip base64 blobs from list responses — return URL or empty string."""
        url = obj.photo_url or ''
        return '' if url.startswith('data:') else url

    def get_video_url(self, obj):
        """Strip base64 blobs from list responses — return URL or empty string."""
        url = obj.video_url or ''
        return '' if url.startswith('data:') else url

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['has_photo'] = bool((instance.photo_url or '').strip())
        data['has_video'] = bool((instance.video_url or '').strip())
        return data

class PendingReportSerializer(serializers.ModelSerializer):
    """For MDRRMO pending list. validation_breakdown used in Report Details → View Technical Details."""

    reporter_full_name = serializers.SerializerMethodField()
    reporter_display_id = serializers.SerializerMethodField()
    display_report_id = serializers.SerializerMethodField()
    reporter_barangay = serializers.SerializerMethodField()
    confirmation_count = serializers.SerializerMethodField()
    photo_url = serializers.SerializerMethodField()
    video_url = serializers.SerializerMethodField()

    class Meta:
        model = HazardReport
        fields = (
            'id',
            'user',
            'hazard_type',
            'latitude',
            'longitude',
            'description',
            'photo_url',
            'video_url',
            'status',
            'naive_bayes_score',
            'consensus_score',
            'distance_weight',
            'final_validation_score',
            'validation_breakdown',
            'created_at',
            'auto_rejected',
            'admin_comment',
            'user_latitude',
            'user_longitude',
            'rejected_at',
            'restoration_reason',
            'restored_at',
            'deletion_scheduled_at',
            'reporter_full_name',
            'reporter_display_id',
            'display_report_id',
            'reporter_barangay',
            'confirmation_count',  # Added
        )

    def get_reporter_full_name(self, obj):
        return _reporter_full_name_for_report(obj)

    def get_reporter_display_id(self, obj):
        return _reporter_display_id_for_report(obj)

    def get_display_report_id(self, obj):
        return getattr(obj, 'public_reference', None)

    def get_reporter_barangay(self, obj):
        return _reporter_barangay_for_report(obj)

    def get_confirmation_count(self, obj):
        return obj.confirmation_count

    def get_photo_url(self, obj):
        url = obj.photo_url or ''
        return '' if url.startswith('data:') else url

    def get_video_url(self, obj):
        url = obj.video_url or ''
        return '' if url.startswith('data:') else url

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['has_photo'] = bool((instance.photo_url or '').strip())
        data['has_video'] = bool((instance.video_url or '').strip())
        return data
