"""
URL configuration for notifications.
"""
from django.urls import path
from . import views

urlpatterns = [
    path('notifications/', views.list_notifications, name='list_notifications'),
    path('notifications/unread-count/', views.unread_count, name='unread_count'),
    path('notifications/mark-all-read/', views.mark_all_read, name='mark_all_read'),
    path('notifications/<int:notification_id>/', views.get_notification, name='get_notification'),
    path('notifications/<int:notification_id>/mark-read/', views.mark_notification_read, name='mark_notification_read'),
    path('notifications/<int:notification_id>/delete/', views.delete_notification, name='delete_notification'),
]
