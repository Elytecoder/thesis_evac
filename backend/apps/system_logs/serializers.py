"""
Serializers for system logs.
"""
from rest_framework import serializers
from .models import SystemLog


class SystemLogSerializer(serializers.ModelSerializer):
    """Serializer for system log entries."""
    
    user_id = serializers.IntegerField(source='user.id', read_only=True, allow_null=True)
    
    class Meta:
        model = SystemLog
        fields = (
            'id', 'user_id', 'user_role', 'user_name',
            'action', 'module', 'status',
            'description', 'ip_address', 'user_agent',
            'related_object_type', 'related_object_id',
            'metadata', 'created_at'
        )
        read_only_fields = fields
