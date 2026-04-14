"""
Authentication API views.
"""
import time
import logging
import os

from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from django.contrib.auth import authenticate, get_user_model
from django.conf import settings

from .serializers import (
    UserSerializer,
    UserRegistrationSerializer,
    UserLoginSerializer,
    UserProfileUpdateSerializer,
    PasswordChangeSerializer,
    DeleteAccountSerializer,
)
from .models import EmailVerificationCode
from apps.system_logs.models import SystemLog

logger = logging.getLogger(__name__)

User = get_user_model()


@api_view(['POST'])
@permission_classes([AllowAny])
def send_verification_code(request):
    """
    POST /api/auth/send-verification-code/
    Generate a 6-digit OTP and send it to the user's email via Gmail SMTP.

    Body:   { "email": "user@example.com" }
    Returns { "message": "...", "expires_in": "5 minutes" }

    The code is NEVER included in the response.  In DEBUG mode without SMTP
    credentials configured the code is printed to the server console only.
    """
    try:
        email = request.data.get('email', '').lower().strip()

        if not email:
            return Response(
                {'error': 'Email is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        if User.objects.filter(email=email).exists():
            return Response(
                {'error': 'Email is already registered'},
                status=status.HTTP_400_BAD_REQUEST
            )

        verification = EmailVerificationCode.create_verification(email)

        # ── Send the verification email via Brevo HTTP API ────────────────
        # Uses HTTPS (port 443) instead of SMTP (port 587) so it works on
        # Render's free plan which blocks outbound SMTP connections.
        html_content = (
            f'<div style="font-family:Arial,sans-serif;max-width:480px;margin:auto;'
            f'border:1px solid #e0e0e0;border-radius:12px;padding:32px;">'
            f'<h2 style="color:#1565C0;margin-bottom:8px;">Email Verification</h2>'
            f'<p style="color:#555;margin-bottom:24px;">Use the code below to verify your email address.</p>'
            f'<div style="background:#f5f5f5;border-radius:8px;padding:20px 32px;'
            f'text-align:center;letter-spacing:8px;font-size:32px;font-weight:bold;'
            f'color:#1565C0;">{verification.code}</div>'
            f'<p style="color:#777;font-size:13px;margin-top:20px;">This code expires in <strong>5 minutes</strong>.</p>'
            f'<p style="color:#999;font-size:12px;">If you did not request this, you can safely ignore this email.</p>'
            f'</div>'
        )
        text_content = (
            f'Your verification code is: {verification.code}\n'
            f'It expires in 5 minutes.\n\n'
            f'— Bulan MDRRMO Evacuation System'
        )

        # Send via Brevo HTTP API (HTTPS/443 — not blocked on Render free tier)
        # Called synchronously so it isn't killed by Gunicorn before completing.
        import urllib.request as _urllib_req
        import json as _json
        brevo_api_key = os.environ.get('BREVO_API_KEY', '')
        if brevo_api_key:
            sender_email = os.environ.get('DEFAULT_FROM_EMAIL', 'a8119e001@smtp-brevo.com')
            payload = _json.dumps({
                'sender': {'name': 'Bulan Evac System', 'email': sender_email},
                'to': [{'email': email}],
                'subject': 'Your Evacuation System Verification Code',
                'htmlContent': html_content,
                'textContent': text_content,
            }).encode('utf-8')
            req = _urllib_req.Request(
                'https://api.brevo.com/v3/smtp/email',
                data=payload,
                headers={
                    'accept': 'application/json',
                    'api-key': brevo_api_key,
                    'content-type': 'application/json',
                },
                method='POST',
            )
            try:
                with _urllib_req.urlopen(req, timeout=15) as resp:
                    print(f"[EMAIL] Brevo sent to {email} — HTTP {resp.status}", flush=True)
            except Exception as api_err:
                print(f"[EMAIL] Brevo FAILED for {email}: {api_err}", flush=True)
                logger.exception(f"Brevo API failed for {email}: {api_err}")
        else:
            # Local fallback: Django SMTP (Gmail)
            try:
                from django.core.mail import send_mail
                from django.conf import settings as django_settings
                send_mail(
                    subject='Your Evacuation System Verification Code',
                    message=text_content,
                    from_email=django_settings.DEFAULT_FROM_EMAIL,
                    recipient_list=[email],
                    html_message=html_content,
                    fail_silently=False,
                )
                print(f"[EMAIL] SMTP sent to {email}", flush=True)
            except Exception as smtp_err:
                print(f"[EMAIL] SMTP FAILED for {email}: {smtp_err}", flush=True)
                logger.exception(f"SMTP fallback failed for {email}: {smtp_err}")
        # ─────────────────────────────────────────────────────────────────

        return Response({
            'message': 'Verification code sent to your email',
            'expires_in': '5 minutes',
        })

    except Exception as e:
        logger.exception(f"Failed to send verification code: {e}")
        return Response(
            {'error': f'Failed to send verification code: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([AllowAny])
def register(request):
    """
    POST /api/auth/register/
    Register a new user account with email verification.
    Body: {email, password, password_confirm, verification_code, full_name, phone_number, province, municipality, barangay, street}
    Returns: {user, token}
    """
    t0 = time.monotonic()
    serializer = UserRegistrationSerializer(data=request.data)
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    user = serializer.save()
    token, _ = Token.objects.get_or_create(user=user)
    
    # Log the registration
    SystemLog.log_action(
        action=SystemLog.Action.USER_REGISTER,
        module=SystemLog.Module.AUTHENTICATION,
        user=user,
        description=f'New user registered: {user.username} ({user.email})',
        ip_address=request.META.get('REMOTE_ADDR'),
        user_agent=request.META.get('HTTP_USER_AGENT', ''),
    )

    elapsed_ms = int((time.monotonic() - t0) * 1000)
    logger.info(f"register completed in {elapsed_ms}ms for {user.email}")

    return Response({
        'user': UserSerializer(user).data,
        'token': token.key,
        'message': 'Registration successful! Your email has been verified.',
    }, status=status.HTTP_201_CREATED)


@api_view(['POST'])
@permission_classes([AllowAny])
def login(request):
    """
    POST /api/auth/login/
    Login with email and password.
    Body: {email, password}
    Returns: {user, token}
    """
    t0 = time.monotonic()
    serializer = UserLoginSerializer(data=request.data)
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    email = serializer.validated_data['email'].lower().strip()
    password = serializer.validated_data['password']
    
    user = authenticate(request, email=email, password=password)
    
    if user is None:
        SystemLog.log_action(
            action=SystemLog.Action.USER_LOGIN,
            module=SystemLog.Module.AUTHENTICATION,
            user=None,
            status=SystemLog.Status.FAILED,
            description=f'Failed login attempt for email: {email}',
            ip_address=request.META.get('REMOTE_ADDR'),
            user_agent=request.META.get('HTTP_USER_AGENT', ''),
        )
        return Response(
            {'error': 'Invalid email or password.'},
            status=status.HTTP_401_UNAUTHORIZED
        )
    
    if not getattr(user, 'email_verified', False):
        return Response(
            {'error': 'Please verify your email before logging in.'},
            status=status.HTTP_403_FORBIDDEN
        )
    
    if user.is_suspended:
        return Response(
            {'error': 'Account is suspended'},
            status=status.HTTP_403_FORBIDDEN
        )
    
    if not user.is_active:
        return Response(
            {'error': 'Account is not active'},
            status=status.HTTP_403_FORBIDDEN
        )
    
    token, _ = Token.objects.get_or_create(user=user)
    
    SystemLog.log_action(
        action=SystemLog.Action.USER_LOGIN,
        module=SystemLog.Module.AUTHENTICATION,
        user=user,
        description=f'User logged in: {user.email}',
        ip_address=request.META.get('REMOTE_ADDR'),
        user_agent=request.META.get('HTTP_USER_AGENT', ''),
    )

    elapsed_ms = int((time.monotonic() - t0) * 1000)
    logger.info(f"login completed in {elapsed_ms}ms for {email}")

    return Response({
        'user': UserSerializer(user).data,
        'token': token.key,
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def logout(request):
    """
    POST /api/auth/logout/
    Logout and delete authentication token.
    Headers: {Authorization: Token xxx}
    Returns: {message}
    """
    # Log logout before deleting token
    SystemLog.log_action(
        action=SystemLog.Action.USER_LOGOUT,
        module=SystemLog.Module.AUTHENTICATION,
        user=request.user,
        description=f'User logged out: {request.user.username}',
        ip_address=request.META.get('REMOTE_ADDR'),
    )
    
    try:
        request.user.auth_token.delete()
    except Exception:
        pass
    
    return Response({'message': 'Successfully logged out'})


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def profile(request):
    """
    GET /api/auth/profile/
    Get current user profile.
    Headers: {Authorization: Token xxx}
    Returns: {user}
    """
    return Response(UserSerializer(request.user).data)


@api_view(['PUT', 'PATCH'])
@permission_classes([IsAuthenticated])
def update_profile(request):
    """
    PUT/PATCH /api/auth/profile/update/
    Update current user profile (editable: phone_number, street only).
    Headers: {Authorization: Token xxx}
    Body: {phone_number, street}
    Returns: {user}
    """
    serializer = UserProfileUpdateSerializer(
        request.user,
        data=request.data,
        partial=True
    )
    
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    serializer.save()
    return Response(UserSerializer(request.user).data)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def change_password(request):
    """
    POST /api/auth/change-password/
    Change user password.
    Headers: {Authorization: Token xxx}
    Body: {old_password, new_password, new_password_confirm}
    Returns: {message}
    """
    serializer = PasswordChangeSerializer(data=request.data)
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    user = request.user
    
    # Check old password
    if not user.check_password(serializer.validated_data['old_password']):
        return Response(
            {'error': 'Old password is incorrect'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Set new password
    user.set_password(serializer.validated_data['new_password'])
    user.save()
    
    # Delete old token and create new one
    try:
        request.user.auth_token.delete()
    except Exception:
        pass
    
    token = Token.objects.create(user=user)
    
    return Response({
        'message': 'Password changed successfully',
        'token': token.key,
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def delete_account(request):
    """
    POST /api/auth/delete-account/
    Permanently delete the authenticated user's account (residents only).
    Body: {password} — must match current password.
    """
    serializer = DeleteAccountSerializer(data=request.data)
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    user = request.user
    if user.role == User.Role.MDRRMO:
        return Response(
            {'error': 'MDRRMO accounts cannot be deleted from the app.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if not user.check_password(serializer.validated_data['password']):
        return Response(
            {'error': 'Password is incorrect.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    email = user.email
    user_id_log = user.id
    username = user.username

    SystemLog.log_action(
        action=SystemLog.Action.USER_DELETED,
        module=SystemLog.Module.AUTHENTICATION,
        user=user,
        description=f'User deleted own account: {email}',
        related_object_type='User',
        related_object_id=user_id_log,
        ip_address=request.META.get('REMOTE_ADDR'),
        user_agent=request.META.get('HTTP_USER_AGENT', ''),
    )

    try:
        user.auth_token.delete()
    except Exception:
        pass

    user.delete()

    return Response(
        {'message': 'Account deleted successfully.'},
        status=status.HTTP_200_OK,
    )
