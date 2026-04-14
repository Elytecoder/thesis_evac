"""
System logging models for audit trail and activity tracking.

RETENTION: Logs are kept until:
- MDRRMO clears them manually (POST /api/mdrrmo/system-logs/clear/), or
- They are older than SYSTEM_LOG_RETENTION_DAYS and cleanup_old_system_logs is run.
See settings.SYSTEM_LOG_RETENTION_DAYS (default 90). Run: python manage.py cleanup_old_system_logs
"""
from django.conf import settings
from django.db import models


class SystemLog(models.Model):
    """
    System activity log for tracking important actions.
    Used for audit trail and monitoring.
    """
    class Action(models.TextChoices):
        # User actions
        USER_LOGIN = 'user_login', 'User Login'
        USER_LOGOUT = 'user_logout', 'User Logout'
        USER_REGISTER = 'user_register', 'User Register'
        USER_SUSPENDED = 'user_suspended', 'User Suspended'
        USER_ACTIVATED = 'user_activated', 'User Activated'
        USER_DELETED = 'user_deleted', 'User Deleted'
        
        # Report actions
        REPORT_SUBMITTED = 'report_submitted', 'Report Submitted'
        REPORT_APPROVED = 'report_approved', 'Report Approved'
        REPORT_REJECTED = 'report_rejected', 'Report Rejected'
        REPORT_RESTORED = 'report_restored', 'Report Restored'
        REPORT_DELETED = 'report_deleted', 'Report Deleted'
        
        # Evacuation center actions
        CENTER_CREATED = 'center_created', 'Center Created'
        CENTER_UPDATED = 'center_updated', 'Center Updated'
        CENTER_DELETED = 'center_deleted', 'Center Deleted'
        CENTER_DEACTIVATED = 'center_deactivated', 'Center Deactivated'
        CENTER_REACTIVATED = 'center_reactivated', 'Center Reactivated'
        
        # Navigation actions
        ROUTE_CALCULATED = 'route_calculated', 'Route Calculated'
        NAVIGATION_STARTED = 'navigation_started', 'Navigation Started'
        NAVIGATION_COMPLETED = 'navigation_completed', 'Navigation Completed'
        
        # System actions
        SYSTEM_STARTUP = 'system_startup', 'System Startup'
        SYSTEM_ERROR = 'system_error', 'System Error'
    
    class Module(models.TextChoices):
        AUTHENTICATION = 'authentication', 'Authentication'
        USER_MANAGEMENT = 'user_management', 'User Management'
        HAZARD_REPORTS = 'hazard_reports', 'Hazard Reports'
        EVACUATION_CENTERS = 'evacuation_centers', 'Evacuation Centers'
        NAVIGATION = 'navigation', 'Navigation'
        SYSTEM = 'system', 'System'
    
    class Status(models.TextChoices):
        SUCCESS = 'success', 'Success'
        FAILED = 'failed', 'Failed'
        WARNING = 'warning', 'Warning'
    
    # Who performed the action
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='system_logs'
    )
    user_role = models.CharField(max_length=20, blank=True)  # Cached role
    user_name = models.CharField(max_length=255, blank=True)  # Cached name
    
    # What action was performed
    action = models.CharField(max_length=50, choices=Action.choices)
    module = models.CharField(max_length=50, choices=Module.choices)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.SUCCESS)
    
    # Details
    description = models.TextField(blank=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.TextField(blank=True)
    
    # Related objects (optional)
    related_object_type = models.CharField(max_length=100, blank=True)
    related_object_id = models.IntegerField(null=True, blank=True)
    
    # Additional data (JSON)
    metadata = models.JSONField(null=True, blank=True)
    
    # Timestamp
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'system_systemlog'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['-created_at']),
            models.Index(fields=['user']),
            models.Index(fields=['action']),
            models.Index(fields=['module']),
            models.Index(fields=['status']),
        ]
    
    def __str__(self):
        return f"{self.action} by {self.user_name or 'System'} at {self.created_at}"
    
    @classmethod
    def log_action(cls, action, module, user=None, status=Status.SUCCESS,
                   description='', ip_address=None, user_agent='',
                   related_object_type='', related_object_id=None, metadata=None):
        """
        Create a log entry asynchronously in a background thread so it never
        blocks the HTTP response. Failures are silently swallowed to prevent
        a logging error from breaking the main request.
        """
        import threading

        user_id = getattr(user, 'pk', None)
        user_role = getattr(user, 'role', '') if user else ''
        user_name = ''
        if user:
            user_name = (getattr(user, 'full_name', None) or '').strip() or getattr(user, 'username', '')

        def _write():
            try:
                cls.objects.create(
                    user_id=user_id,
                    user_role=user_role,
                    user_name=user_name,
                    action=action,
                    module=module,
                    status=status,
                    description=description,
                    ip_address=ip_address,
                    user_agent=user_agent,
                    related_object_type=related_object_type,
                    related_object_id=related_object_id,
                    metadata=metadata,
                )
            except Exception:
                pass  # Never let logging failures bubble up

        thread = threading.Thread(target=_write, daemon=True)
        thread.start()
