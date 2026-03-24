"""
URL configuration for system logs and user management.
"""
from django.urls import path
from . import views

urlpatterns = [
    # User management (MDRRMO) — canonical /api/users/ (+ legacy /api/mdrrmo/users/)
    path('users/', views.list_users, name='list_users'),
    path('users/<int:user_id>/', views.get_user, name='get_user'),
    path('users/<int:user_id>/suspend/', views.suspend_user, name='suspend_user'),
    path('users/<int:user_id>/activate/', views.activate_user, name='activate_user'),
    path('users/<int:user_id>/delete/', views.delete_user, name='delete_user'),
    path('mdrrmo/users/', views.list_users, name='list_users_mdrrmo'),
    path('mdrrmo/users/<int:user_id>/', views.get_user, name='get_user_mdrrmo'),
    path('mdrrmo/users/<int:user_id>/suspend/', views.suspend_user, name='suspend_user_mdrrmo'),
    path('mdrrmo/users/<int:user_id>/activate/', views.activate_user, name='activate_user_mdrrmo'),
    path('mdrrmo/users/<int:user_id>/delete/', views.delete_user, name='delete_user_mdrrmo'),
    
    # System logs (MDRRMO)
    path('mdrrmo/system-logs/', views.list_system_logs, name='list_system_logs'),
    path('mdrrmo/system-logs/clear/', views.clear_system_logs, name='clear_system_logs'),
]
