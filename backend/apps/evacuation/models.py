"""
Evacuation center model for safe destinations during evacuation.
"""
from django.db import models


class EvacuationCenter(models.Model):
    """
    Designated evacuation center with location and metadata.
    Used as route destination in pathfinding.
    """
    # Basic information
    name = models.CharField(max_length=255)
    latitude = models.DecimalField(max_digits=10, decimal_places=7)
    longitude = models.DecimalField(max_digits=10, decimal_places=7)
    
    # Structured address fields
    province = models.CharField(max_length=100, blank=True)
    municipality = models.CharField(max_length=100, blank=True)
    barangay = models.CharField(max_length=100, blank=True)
    street = models.CharField(max_length=255, blank=True)
    address = models.TextField(blank=True)  # Full address (backward compatibility)
    
    # Contact information
    contact_number = models.CharField(max_length=20, blank=True)
    contact_person = models.CharField(max_length=255, blank=True)
    
    # Operational status
    is_operational = models.BooleanField(default=True)
    deactivated_at = models.DateTimeField(null=True, blank=True)
    
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True, null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'evacuation_evacuationcenter'

    def __str__(self):
        return self.name

    def save(self, *args, **kwargs):
        if self.barangay:
            from apps.users.barangay_utils import normalize_barangay_label

            self.barangay = normalize_barangay_label(self.barangay)
        super().save(*args, **kwargs)
    
    def deactivate(self):
        """Mark center as non-operational."""
        from django.utils import timezone
        self.is_operational = False
        self.deactivated_at = timezone.now()
        self.save(update_fields=['is_operational', 'deactivated_at', 'updated_at'])
    
    def reactivate(self):
        """Mark center as operational again."""
        self.is_operational = True
        self.deactivated_at = None
        self.save(update_fields=['is_operational', 'deactivated_at', 'updated_at'])
