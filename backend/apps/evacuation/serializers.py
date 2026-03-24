"""Serializers for evacuation centers."""
from rest_framework import serializers
from .models import EvacuationCenter


class EvacuationCenterSerializer(serializers.ModelSerializer):
    """Serializer for evacuation center read operations."""
    
    class Meta:
        model = EvacuationCenter
        fields = (
            'id', 'name', 'latitude', 'longitude', 
            'province', 'municipality', 'barangay', 'street', 'address',
            'contact_number', 'contact_person',
            'is_operational', 'deactivated_at',
            'description', 'created_at', 'updated_at'
        )
        read_only_fields = ('id', 'created_at', 'updated_at', 'deactivated_at')


class EvacuationCenterCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating/updating evacuation centers."""

    class Meta:
        model = EvacuationCenter
        fields = (
            'name', 'latitude', 'longitude',
            'province', 'municipality', 'barangay', 'street', 'address',
            'contact_number', 'contact_person',
            'description'
        )

    def validate_barangay(self, value):
        if value is None or not str(value).strip():
            return ''
        from apps.users.barangay_utils import normalize_barangay_label

        return normalize_barangay_label(str(value).strip())
