"""
Evacuation center model for safe destinations during evacuation.
"""
from django.db import models


class EvacuationCenter(models.Model):
    """
    Designated evacuation center with location and metadata.
    Used as route destination in pathfinding.
    """
    name = models.CharField(max_length=255)
    latitude = models.DecimalField(max_digits=10, decimal_places=7)
    longitude = models.DecimalField(max_digits=10, decimal_places=7)
    address = models.TextField(blank=True)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True, null=True, blank=True)

    class Meta:
        db_table = 'evacuation_evacuationcenter'

    def __str__(self):
        return self.name
