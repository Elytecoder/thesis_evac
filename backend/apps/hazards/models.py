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

    Validation architecture (separate roles):
    1) Naive Bayes: text/classification only (hazard_type + description features).
    2) Rule scoring: distance_weight (reporter proximity), consensus_score (nearby count rule).
    3) final_validation_score: combined NB + rules (see validation.rule_scoring).
    4) MDRRMO approves/rejects; only APPROVED reports affect routing risk (see route_service).
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
    # TextField: supports long public URLs and data: URLs (base64) until file storage is added
    photo_url = models.TextField(blank=True)
    video_url = models.TextField(blank=True)
    
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.PENDING,
    )
    
    # Auto-rejection flag (set when user location is outside accepted radius)
    auto_rejected = models.BooleanField(default=False)
    
    # Validation: NB = text-only probability; consensus_score = rule from nearby reports;
    # distance_weight = rule from reporter–hazard proximity; final_validation_score = combined.
    naive_bayes_score = models.FloatField(null=True, blank=True)
    consensus_score = models.FloatField(null=True, blank=True)
    distance_weight = models.FloatField(null=True, blank=True)
    final_validation_score = models.FloatField(null=True, blank=True)
    # Optional breakdown for MDRRMO technical details (distance, nearby count, decision, etc.)
    validation_breakdown = models.JSONField(null=True, blank=True)

    # Admin actions
    admin_comment = models.TextField(blank=True)  # MDRRMO can add notes when approving/rejecting
    
    # Restoration feature (for rejected reports)
    restoration_reason = models.TextField(blank=True)  # Reason for restoring a rejected report
    restored_at = models.DateTimeField(null=True, blank=True)  # When report was restored
    
    # Soft-delete: MDRRMO can mark reports as deleted without losing history.
    # All operational queries MUST filter is_deleted=False.
    is_deleted = models.BooleanField(default=False)
    deleted_at = models.DateTimeField(null=True, blank=True)

    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    rejected_at = models.DateTimeField(null=True, blank=True)  # When report was rejected
    deletion_scheduled_at = models.DateTimeField(null=True, blank=True)  # For 15-day cleanup

    # Non-sequential public reference for MDRRMO display (6 digits, unique). DB pk unchanged.
    public_reference = models.PositiveIntegerField(unique=True)

    # Offline deduplication: mobile client sets this UUID before queuing.
    # Backend rejects duplicate IDs so re-sync never creates double reports.
    client_submission_id = models.CharField(
        max_length=64, blank=True, null=True, db_index=True
    )

    class Meta:
        db_table = 'hazards_hazardreport'
        ordering = ['-created_at']  # Newest first

    def __str__(self):
        return f"Report {self.id} - {self.hazard_type} ({self.status})"

    def save(self, *args, **kwargs):
        if self.public_reference is None:
            from apps.users.utils_codes import allocate_unique_six_digit

            self.public_reference = allocate_unique_six_digit(
                self.__class__,
                'public_reference',
            )
        super().save(*args, **kwargs)
    
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
    
    @property
    def confirmation_count(self):
        """Get the number of confirmations for this report."""
        return self.confirmations.count()
    
    def add_confirmation(self, user):
        """Add a user confirmation to this report. Returns True if added, False if already confirmed."""
        from django.db import IntegrityError
        
        try:
            HazardConfirmation.objects.create(report=self, user=user)
            return True
        except IntegrityError:
            # User already confirmed this report
            return False
    
    def has_user_confirmed(self, user):
        """Check if a specific user has already confirmed this report."""
        return self.confirmations.filter(user=user).exists()


class HazardConfirmation(models.Model):
    """
    Track user confirmations of existing hazard reports.
    Used to reduce duplicate submissions and strengthen validation.
    """
    report = models.ForeignKey(
        HazardReport,
        on_delete=models.CASCADE,
        related_name='confirmations',
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='hazard_confirmations',
    )
    confirmed_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'hazards_confirmation'
        unique_together = ('report', 'user')  # One user can only confirm once per report
        ordering = ['-confirmed_at']
    
    def __str__(self):
        return f"{self.user.username} confirmed Report #{self.report.id}"
