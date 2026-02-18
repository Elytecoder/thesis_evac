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
    Flow: submit -> Naive Bayes validation -> Consensus -> MDRRMO verification -> validated score.
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
    latitude = models.DecimalField(max_digits=10, decimal_places=7)
    longitude = models.DecimalField(max_digits=10, decimal_places=7)
    description = models.TextField(blank=True)
    photo_url = models.URLField(blank=True)  # Mock for now; replace with file upload when needed
    video_url = models.URLField(blank=True)  # Mock for now; replace with file upload when needed
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.PENDING,
    )
    naive_bayes_score = models.FloatField(null=True, blank=True)
    consensus_score = models.FloatField(null=True, blank=True)
    admin_comment = models.TextField(blank=True)  # MDRRMO can add notes when approving/rejecting
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'hazards_hazardreport'

    def __str__(self):
        return f"Report {self.id} - {self.hazard_type} ({self.status})"
