"""
Serializers for notifications.
"""
from rest_framework import serializers
from .models import Notification


class NotificationSerializer(serializers.ModelSerializer):
    """Serializer for notification entries."""
    
    class Meta:
        model = Notification
        fields = (
            'id', 'type', 'title', 'message',
            'related_object_type', 'related_object_id',
            'is_read', 'read_at', 'metadata', 'created_at'
        )
        read_only_fields = ('id', 'created_at', 'read_at')
