"""
User authentication URLs.
"""
from django.urls import path
from . import views

urlpatterns = [
    # Email verification
    path('auth/send-verification-code/', views.send_verification_code, name='send_verification_code'),
    
    # Authentication
    path('auth/register/', views.register, name='register'),
    path('auth/login/', views.login, name='login'),
    path('auth/logout/', views.logout, name='logout'),
    
    # Profile management
    path('auth/profile/', views.profile, name='profile'),
    path('auth/profile/update/', views.update_profile, name='update_profile'),
    path('auth/change-password/', views.change_password, name='change_password'),
    path('auth/delete-account/', views.delete_account, name='delete_account'),
]
