"""
Notification models for user alerts.
"""
from django.conf import settings
from django.db import models


class Notification(models.Model):
    """
    User notification for important events.
    Sent to residents when their reports are approved/rejected.
    """
    class Type(models.TextChoices):
        REPORT_APPROVED = 'report_approved', 'Report Approved'
        REPORT_REJECTED = 'report_rejected', 'Report Rejected'
        REPORT_RESTORED = 'report_restored', 'Report Restored'
        CENTER_DEACTIVATED = 'center_deactivated', 'Center Deactivated'
        SYSTEM_ALERT = 'system_alert', 'System Alert'
    
    # Who receives the notification
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notifications'
    )
    
    # Notification details
    type = models.CharField(max_length=50, choices=Type.choices)
    title = models.CharField(max_length=255)
    message = models.TextField()
    
    # Related objects (optional)
    related_object_type = models.CharField(max_length=100, blank=True)
    related_object_id = models.IntegerField(null=True, blank=True)
    
    # Status
    is_read = models.BooleanField(default=False)
    read_at = models.DateTimeField(null=True, blank=True)
    
    # Additional data
    metadata = models.JSONField(null=True, blank=True)
    
    # Timestamp
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'notifications_notification'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['-created_at']),
            models.Index(fields=['user', 'is_read']),
        ]
    
    def __str__(self):
        return f"{self.type} for {self.user.username}"
    
    def mark_as_read(self):
        """Mark notification as read."""
        from django.utils import timezone
        self.is_read = True
        self.read_at = timezone.now()
        self.save()
    
    @classmethod
    def create_notification(cls, user, notification_type, title, message,
                           related_object_type='', related_object_id=None, metadata=None):
        """
        Helper method to create a notification.
        
        Usage:
            Notification.create_notification(
                user=resident,
                notification_type=Notification.Type.REPORT_APPROVED,
                title='Report Approved',
                message='Your hazard report has been approved by MDRRMO.',
                related_object_type='HazardReport',
                related_object_id=report.id
            )
        """
        return cls.objects.create(
            user=user,
            type=notification_type,
            title=title,
            message=message,
            related_object_type=related_object_type,
            related_object_id=related_object_id,
            metadata=metadata
        )
