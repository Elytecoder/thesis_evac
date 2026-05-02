"""Serializers for hazard reports and baseline hazards."""
from rest_framework import serializers

from .models import HazardReport
from .location_resolver import resolve_hazard_location


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


def _coord_fallback_label(obj):
    try:
        return f"{float(obj.latitude):.5f}, {float(obj.longitude):.5f}"
    except Exception:
        return ''


def _location_label_for_report(obj):
    """
    Human-readable location text from hazard coordinates.
    Priority: full reverse-geocoded address -> barangay/municipality -> coordinates.
    """
    resolved = _resolved_location_fields(obj)
    addr = (resolved.get('location_address') or '').strip()
    if addr:
        return addr
    brgy = (resolved.get('location_barangay') or '').strip()
    muni = (resolved.get('location_municipality') or '').strip()
    if brgy and muni:
        return f'{brgy}, {muni}'
    if brgy:
        return brgy
    if muni:
        return muni
    return _coord_fallback_label(obj)


def _resolved_location_fields(obj):
    """
    Return location_address/barangay/municipality for a report.
    Uses stored fields first; falls back to reverse geocoding when missing.
    """
    address = (getattr(obj, 'location_address', '') or '').strip()
    barangay = (getattr(obj, 'location_barangay', '') or '').strip()
    municipality = (getattr(obj, 'location_municipality', '') or '').strip()
    if address or barangay or municipality:
        return {
            'location_address': address,
            'location_barangay': barangay,
            'location_municipality': municipality,
        }
    try:
        return resolve_hazard_location(float(obj.latitude), float(obj.longitude))
    except Exception:
        return {
            'location_address': '',
            'location_barangay': '',
            'location_municipality': '',
        }


class HazardReportSerializer(serializers.ModelSerializer):
    """Full read serializer: NB + rule scores + breakdown (no Random Forest in validation)."""

    reporter_full_name = serializers.SerializerMethodField()
    reporter_display_id = serializers.SerializerMethodField()
    display_report_id = serializers.SerializerMethodField()
    reporter_barangay = serializers.SerializerMethodField()
    confirmation_count = serializers.SerializerMethodField()
    photo_url = serializers.SerializerMethodField()
    video_url = serializers.SerializerMethodField()
    location_address = serializers.SerializerMethodField()
    location_barangay = serializers.SerializerMethodField()
    location_municipality = serializers.SerializerMethodField()
    location_label = serializers.SerializerMethodField()

    class Meta:
        model = HazardReport
        fields = (
            'id',
            'user',
            'hazard_type',
            'latitude',
            'longitude',
            'location_address',
            'location_barangay',
            'location_municipality',
            'location_label',
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
        """Return full photo URL (including base64) for user's own reports."""
        return obj.photo_url or ''

    def get_video_url(self, obj):
        """Return full video URL (including base64) for user's own reports."""
        return obj.video_url or ''

    def get_location_address(self, obj):
        return _resolved_location_fields(obj)['location_address']

    def get_location_barangay(self, obj):
        return _resolved_location_fields(obj)['location_barangay']

    def get_location_municipality(self, obj):
        return _resolved_location_fields(obj)['location_municipality']

    def get_location_label(self, obj):
        return _location_label_for_report(obj)

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['has_photo'] = bool((instance.photo_url or '').strip())
        data['has_video'] = bool((instance.video_url or '').strip())
        return data

class PublicHazardSerializer(serializers.ModelSerializer):
    """
    Minimal public view of an approved hazard for resident map display.
    Only exposes safe, non-identifying information — no description, no reporter
    identity, no AI scores, no timestamps.
    """
    confirmation_count = serializers.SerializerMethodField()
    location_barangay = serializers.SerializerMethodField()
    location_municipality = serializers.SerializerMethodField()
    location_label = serializers.SerializerMethodField()

    class Meta:
        model = HazardReport
        fields = (
            'id',
            'hazard_type',
            'latitude',
            'longitude',
            'status',
            'confirmation_count',
            'location_barangay',
            'location_municipality',
            'location_label',
        )

    def get_confirmation_count(self, obj):
        return obj.confirmation_count

    def get_location_barangay(self, obj):
        return _resolved_location_fields(obj)['location_barangay']

    def get_location_municipality(self, obj):
        return _resolved_location_fields(obj)['location_municipality']

    def get_location_label(self, obj):
        return _location_label_for_report(obj)


class SimilarReportPublicSerializer(serializers.ModelSerializer):
    """
    Minimal public view of a similar report for the confirmation modal.
    Does NOT expose description, reporter identity, media, or AI scores.
    Only provides enough data for a resident to decide whether to confirm.
    """
    confirmation_count = serializers.SerializerMethodField()

    class Meta:
        model = HazardReport
        fields = (
            'id',
            'hazard_type',
            'latitude',
            'longitude',
            'status',
            'confirmation_count',
        )

    def get_confirmation_count(self, obj):
        return obj.confirmation_count


class PendingReportSerializer(serializers.ModelSerializer):
    """For MDRRMO pending list. validation_breakdown used in Report Details → View Technical Details."""

    reporter_full_name = serializers.SerializerMethodField()
    reporter_display_id = serializers.SerializerMethodField()
    display_report_id = serializers.SerializerMethodField()
    reporter_barangay = serializers.SerializerMethodField()
    confirmation_count = serializers.SerializerMethodField()
    photo_url = serializers.SerializerMethodField()
    video_url = serializers.SerializerMethodField()
    location_address = serializers.SerializerMethodField()
    location_barangay = serializers.SerializerMethodField()
    location_municipality = serializers.SerializerMethodField()
    location_label = serializers.SerializerMethodField()

    class Meta:
        model = HazardReport
        fields = (
            'id',
            'user',
            'hazard_type',
            'latitude',
            'longitude',
            'location_address',
            'location_barangay',
            'location_municipality',
            'location_label',
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
        """Return full photo URL (including base64) for MDRRMO and report owners."""
        return obj.photo_url or ''

    def get_video_url(self, obj):
        """Return full video URL (including base64) for MDRRMO and report owners."""
        return obj.video_url or ''

    def get_location_address(self, obj):
        return _resolved_location_fields(obj)['location_address']

    def get_location_barangay(self, obj):
        return _resolved_location_fields(obj)['location_barangay']

    def get_location_municipality(self, obj):
        return _resolved_location_fields(obj)['location_municipality']

    def get_location_label(self, obj):
        return _location_label_for_report(obj)

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['has_photo'] = bool((instance.photo_url or '').strip())
        data['has_video'] = bool((instance.video_url or '').strip())
        return data
