"""
API URL configuration. All endpoints return JSON only.
"""
from django.urls import path
from . import views

urlpatterns = [
    # Hazard reporting (Residents)
    path('report-hazard/', views.report_hazard, name='report_hazard'),
    path('check-similar-reports/', views.check_similar_reports, name='check_similar_reports'),
    path('confirm-hazard-report/', views.confirm_hazard_report, name='confirm_hazard_report'),
    path('my-reports/', views.my_reports, name='my_reports'),
    path('my-reports/<int:report_id>/', views.delete_my_report, name='delete_my_report'),
    path('my-reports/<int:report_id>/media/', views.report_media, name='report_media'),
    path('verified-hazards/', views.verified_hazards, name='verified_hazards'),
    
    # MDRRMO - Report management
    path('mdrrmo/dashboard-stats/', views.mdrrmo_dashboard_stats, name='mdrrmo_dashboard_stats'),
    path('mdrrmo/analytics/', views.mdrrmo_analytics, name='mdrrmo_analytics'),
    path('mdrrmo/pending-reports/', views.mdrrmo_pending_reports, name='mdrrmo_pending_reports'),
    path('mdrrmo/approved-reports/', views.mdrrmo_approved_reports, name='mdrrmo_approved_reports'),
    path('mdrrmo/rejected-reports/', views.mdrrmo_rejected_reports, name='mdrrmo_rejected_reports'),
    path('mdrrmo/approve-report/', views.mdrrmo_approve_report, name='mdrrmo_approve_report'),
    path('mdrrmo/restore-report/', views.restore_report, name='restore_report'),
    path('mdrrmo/reports/<int:report_id>/', views.mdrrmo_delete_report, name='mdrrmo_delete_report'),
    path('mdrrmo/reports/<int:report_id>/media/', views.admin_report_media, name='admin_report_media'),
    path('mdrrmo/high-risk-roads/', views.mdrrmo_high_risk_roads, name='mdrrmo_high_risk_roads'),
    
    # Evacuation centers (Public - Read only operational centers)
    path('evacuation-centers/', views.evacuation_centers, name='evacuation_centers'),
    
    # MDRRMO - Evacuation center management (CRUD)
    path('mdrrmo/evacuation-centers/', views.create_evacuation_center, name='create_evacuation_center'),
    path('mdrrmo/evacuation-centers/<int:center_id>/', views.get_evacuation_center, name='get_evacuation_center'),
    path('mdrrmo/evacuation-centers/<int:center_id>/update/', views.update_evacuation_center, name='update_evacuation_center'),
    path('mdrrmo/evacuation-centers/<int:center_id>/delete/', views.delete_evacuation_center, name='delete_evacuation_center'),
    path('mdrrmo/evacuation-centers/<int:center_id>/deactivate/', views.deactivate_evacuation_center, name='deactivate_evacuation_center'),
    path('mdrrmo/evacuation-centers/<int:center_id>/reactivate/', views.reactivate_evacuation_center, name='reactivate_evacuation_center'),
    
    # Routing
    path('calculate-route/', views.calculate_route, name='calculate_route'),
    path('road-risk-layer/', views.road_risk_layer, name='road_risk_layer'),
    path('check-road-data/', views.check_road_data, name='check_road_data'),

    # FCM push notification token registration
    path('auth/fcm-token/', views.update_fcm_token, name='update_fcm_token'),

    # Bootstrap data
    path('bootstrap-sync/', views.bootstrap_sync, name='bootstrap_sync'),

    # MDRRMO: User management
    path('users/', views.list_users, name='list_users'),
    path('users/<int:user_id>/', views.get_user_detail, name='get_user_detail'),
    path('users/<int:user_id>/suspend/', views.suspend_user, name='suspend_user'),
    path('users/<int:user_id>/activate/', views.activate_user, name='activate_user'),
    path('users/<int:user_id>/delete/', views.delete_user_admin, name='delete_user_admin'),
]
