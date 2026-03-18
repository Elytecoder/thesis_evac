"""
Root URL configuration. API endpoints are under /api/.
"""
from django.contrib import admin
from django.urls import path, include
from .views import api_root

urlpatterns = [
    path('', api_root, name='api_root'),  # Welcome page
    path('admin/', admin.site.urls),
    path('api/', include('apps.users.urls')),  # Auth endpoints
    path('api/', include('apps.mobile_sync.urls')),  # Mobile sync endpoints
    path('api/', include('apps.system_logs.urls')),  # System logs & user management
    path('api/', include('apps.notifications.urls')),  # Notifications
]
