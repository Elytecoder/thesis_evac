"""
API URL configuration. All endpoints return JSON only.
"""
from django.urls import path
from . import views

urlpatterns = [
    path('report-hazard/', views.report_hazard),
    path('evacuation-centers/', views.evacuation_centers),
    path('calculate-route/', views.calculate_route),
    path('mdrrmo/pending-reports/', views.mdrrmo_pending_reports),
    path('mdrrmo/approve-report/', views.mdrrmo_approve_report),
    path('bootstrap-sync/', views.bootstrap_sync),
]
