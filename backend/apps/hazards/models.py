"""
Baseline and crowdsourced hazard models.
BaselineHazard = MDRRMO data (cached). HazardReport = resident reports.
"""
from django.conf import settings
from django.db import models


class BaselineHazard(models.Model):
    """
    Official hazard data from MDRRMO (cached).
    TO REPLACE WITH REAL MDRRMO DATA: import from CSV/API, validate coords, normalize hazard_type.
    """
    HAZARD_SOURCE = 'MDRRMO'

    hazard_type = models.CharField(max_length=100)
    latitude = models.DecimalField(max_digits=10, decimal_places=7)
    longitude = models.DecimalField(max_digits=10, decimal_places=7)
    severity = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    source = models.CharField(max_length=50, default=HAZARD_SOURCE)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'hazards_baselinehazard'

    def __str__(self):
        return f"{self.hazard_type} @ ({self.latitude}, {self.longitude})"


class HazardReport(models.Model):
    """
    Crowdsourced hazard report from residents.
    Flow: submit -> distance check (>1 km reject) -> Naive Bayes (single validation
    algorithm with proximity and nearby-count features) -> threshold -> MDRRMO if pending.
    consensus_score is deprecated; validation is Naive Bayes only.
    """
    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        APPROVED = 'approved', 'Approved'
        REJECTED = 'rejected', 'Rejected'

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='hazard_reports',
    )
    hazard_type = models.CharField(max_length=100)
    
    # Hazard location (reported location)
    latitude = models.DecimalField(max_digits=10, decimal_places=7)
    longitude = models.DecimalField(max_digits=10, decimal_places=7)
    
    # User location at time of report (for proximity validation)
    user_latitude = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    user_longitude = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    
    description = models.TextField(blank=True)
    photo_url = models.URLField(blank=True)  # Mock for now; replace with file upload when needed
    video_url = models.URLField(blank=True)  # Mock for now; replace with file upload when needed
    
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.PENDING,
    )
    
    # Auto-rejection flag (set when user location is outside accepted radius)
    auto_rejected = models.BooleanField(default=False)
    
    # AI validation scores (Naive Bayes only for report validation)
    naive_bayes_score = models.FloatField(null=True, blank=True)
    consensus_score = models.FloatField(null=True, blank=True)
    # Optional breakdown for MDRRMO technical details (distance, nearby count, decision, etc.)
    validation_breakdown = models.JSONField(null=True, blank=True)

    # Admin actions
    admin_comment = models.TextField(blank=True)  # MDRRMO can add notes when approving/rejecting
    
    # Restoration feature (for rejected reports)
    restoration_reason = models.TextField(blank=True)  # Reason for restoring a rejected report
    restored_at = models.DateTimeField(null=True, blank=True)  # When report was restored
    
    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    rejected_at = models.DateTimeField(null=True, blank=True)  # When report was rejected
    deletion_scheduled_at = models.DateTimeField(null=True, blank=True)  # For 15-day cleanup

    class Meta:
        db_table = 'hazards_hazardreport'
        ordering = ['-created_at']  # Newest first

    def __str__(self):
        return f"Report {self.id} - {self.hazard_type} ({self.status})"
    
    def mark_rejected(self):
        """Mark report as rejected and schedule for deletion after 15 days."""
        from datetime import timedelta
        from django.utils import timezone
        
        self.status = self.Status.REJECTED
        self.rejected_at = timezone.now()
        # Schedule deletion 15 days from now
        self.deletion_scheduled_at = timezone.now() + timedelta(days=15)
        self.save()
    
    def restore(self, reason):
        """Restore a rejected report back to pending status."""
        from django.utils import timezone
        
        self.status = self.Status.PENDING
        self.restoration_reason = reason
        self.restored_at = timezone.now()
        # Clear deletion schedule
        self.deletion_scheduled_at = None
        self.rejected_at = None
        self.save()