from django.contrib import admin
from .models import BaselineHazard, HazardReport


@admin.register(BaselineHazard)
class BaselineHazardAdmin(admin.ModelAdmin):
    list_display = ('hazard_type', 'latitude', 'longitude', 'severity', 'source', 'created_at')


@admin.register(HazardReport)
class HazardReportAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'hazard_type', 'latitude', 'longitude', 'status', 'naive_bayes_score', 'consensus_score', 'created_at')
    list_filter = ('status', 'hazard_type')
