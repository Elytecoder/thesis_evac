"""
Authentication API views.
"""
import re
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
from .models import EmailVerificationCode, PasswordResetCode
from apps.system_logs.models import SystemLog

logger = logging.getLogger(__name__)

User = get_user_model()


# ── Shared email helper ────────────────────────────────────────────────────────

def _send_brevo_email(to_email: str, subject: str, html_content: str, text_content: str):
    """
    Send a transactional email via Brevo HTTP API (port 443 — not blocked on Render).
    Falls back to Django SMTP if BREVO_API_KEY is not configured.
    Errors are logged but never propagate — callers should not fail because of email issues.
    """
    import urllib.request as _req
    import json as _json

    brevo_api_key = os.environ.get('BREVO_API_KEY', '')
    if brevo_api_key:
        sender_email = os.environ.get('DEFAULT_FROM_EMAIL', 'a8119e001@smtp-brevo.com')
        payload = _json.dumps({
            'sender': {'name': 'Bulan Evac System', 'email': sender_email},
            'to': [{'email': to_email}],
            'subject': subject,
            'htmlContent': html_content,
            'textContent': text_content,
        }).encode('utf-8')
        request = _req.Request(
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
            with _req.urlopen(request, timeout=15) as resp:
                print(f"[EMAIL] Brevo sent to {to_email} — HTTP {resp.status}", flush=True)
        except Exception as err:
            print(f"[EMAIL] Brevo FAILED for {to_email}: {err}", flush=True)
            logger.exception(f"Brevo API failed for {to_email}: {err}")
    else:
        try:
            from django.core.mail import send_mail
            from django.conf import settings as _s
            send_mail(
                subject=subject,
                message=text_content,
                from_email=_s.DEFAULT_FROM_EMAIL,
                recipient_list=[to_email],
                html_message=html_content,
                fail_silently=False,
            )
            print(f"[EMAIL] SMTP sent to {to_email}", flush=True)
        except Exception as smtp_err:
            print(f"[EMAIL] SMTP FAILED for {to_email}: {smtp_err}", flush=True)
            logger.exception(f"SMTP fallback failed for {to_email}: {smtp_err}")


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

        # ── Send the verification email ────────────────────────────────────
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
        _send_brevo_email(email, 'Your Evacuation System Verification Code', html_content, text_content)
        # ──────────────────────────────────────────────────────────────────

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


# ── Password Reset Flow ────────────────────────────────────────────────────────

_GENERIC_RESET_SENT = {
    'message': 'If that email is registered, a password reset code has been sent.',
    'expires_in': '10 minutes',
}


@api_view(['POST'])
@permission_classes([AllowAny])
def forgot_password(request):
    """
    POST /api/auth/forgot-password/
    Step 1 — Request a password-reset OTP.

    Body:   { "email": "user@example.com" }
    Returns generic message regardless of whether the email exists (prevents enumeration).
    Rate-limited: max 3 requests per 15 minutes per email.
    """
    email = request.data.get('email', '').lower().strip()
    if not email:
        return Response({'error': 'Email is required.'}, status=status.HTTP_400_BAD_REQUEST)

    # Rate-limit check before touching the DB user record
    if PasswordResetCode.is_rate_limited(email):
        return Response(
            {'error': 'Too many reset requests. Please wait 15 minutes and try again.'},
            status=status.HTTP_429_TOO_MANY_REQUESTS,
        )

    # Only send if the account actually exists — but use the same response either way
    try:
        User.objects.get(email=email)
    except User.DoesNotExist:
        return Response(_GENERIC_RESET_SENT)

    try:
        reset = PasswordResetCode.create_reset(email)
    except ValueError:
        # rate_limited (shouldn't reach here but guard anyway)
        return Response(
            {'error': 'Too many reset requests. Please wait 15 minutes and try again.'},
            status=status.HTTP_429_TOO_MANY_REQUESTS,
        )

    html_content = (
        f'<div style="font-family:Arial,sans-serif;max-width:480px;margin:auto;'
        f'border:1px solid #e0e0e0;border-radius:12px;padding:32px;">'
        f'<h2 style="color:#1565C0;margin-bottom:8px;">Password Reset</h2>'
        f'<p style="color:#555;margin-bottom:24px;">Use the code below to reset your password.</p>'
        f'<div style="background:#f5f5f5;border-radius:8px;padding:20px 32px;'
        f'text-align:center;letter-spacing:8px;font-size:32px;font-weight:bold;'
        f'color:#1565C0;">{reset.code}</div>'
        f'<p style="color:#777;font-size:13px;margin-top:20px;">This code expires in <strong>10 minutes</strong>.</p>'
        f'<p style="color:#999;font-size:12px;">If you did not request a password reset, you can safely ignore this email.</p>'
        f'</div>'
    )
    text_content = (
        f'Your password reset code is: {reset.code}\n'
        f'It expires in 10 minutes.\n\n'
        f'If you did not request this, ignore this email.\n\n'
        f'— Bulan MDRRMO Evacuation System'
    )
    _send_brevo_email(email, 'Password Reset Code — Bulan Evac System', html_content, text_content)

    return Response(_GENERIC_RESET_SENT)


@api_view(['POST'])
@permission_classes([AllowAny])
def verify_reset_code(request):
    """
    POST /api/auth/verify-reset-code/
    Step 2 — Verify the OTP without consuming it.

    Body:   { "email": "...", "code": "123456" }
    Returns { "valid": true } on success.
    Tracks attempts; code is invalidated after 5 wrong guesses.
    """
    email = request.data.get('email', '').lower().strip()
    code = request.data.get('code', '').strip()

    if not email or not code:
        return Response({'error': 'Email and code are required.'}, status=status.HTTP_400_BAD_REQUEST)

    result = PasswordResetCode.check_code(email, code)

    if result == 'valid':
        return Response({'valid': True, 'message': 'Code verified. You may now set a new password.'})
    if result == 'expired':
        return Response(
            {'error': 'The reset code has expired. Please request a new one.'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if result == 'attempts_exceeded':
        return Response(
            {'error': 'Too many incorrect attempts. Please request a new reset code.'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    return Response(
        {'error': 'Invalid or already-used code.'},
        status=status.HTTP_400_BAD_REQUEST,
    )


@api_view(['POST'])
@permission_classes([AllowAny])
def reset_password(request):
    """
    POST /api/auth/reset-password/
    Step 3 — Set a new password using a verified OTP.

    Body:   { "email": "...", "code": "123456", "new_password": "...", "confirm_password": "..." }
    On success: marks the code as used, updates the password, revokes all sessions.
    """
    email = request.data.get('email', '').lower().strip()
    code = request.data.get('code', '').strip()
    new_password = request.data.get('new_password', '')
    confirm_password = request.data.get('confirm_password', '')

    if not all([email, code, new_password, confirm_password]):
        return Response({'error': 'All fields are required.'}, status=status.HTTP_400_BAD_REQUEST)

    if new_password != confirm_password:
        return Response({'error': 'Passwords do not match.'}, status=status.HTTP_400_BAD_REQUEST)

    # Password strength validation (mirrors registration rules)
    if len(new_password) < 8:
        return Response(
            {'error': 'Password must be at least 8 characters.'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if not re.search(r'[A-Z]', new_password):
        return Response(
            {'error': 'Password must contain at least one uppercase letter.'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if not re.search(r'[a-z]', new_password):
        return Response(
            {'error': 'Password must contain at least one lowercase letter.'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if not re.search(r'\d', new_password):
        return Response(
            {'error': 'Password must contain at least one number.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    # Consume the code (verify + mark used in one atomic step)
    result, _ = PasswordResetCode.consume_code(email, code)
    if result == 'expired':
        return Response(
            {'error': 'The reset code has expired. Please request a new one.'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if result != 'valid':
        return Response(
            {'error': 'Invalid or already-used code.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        user = User.objects.get(email=email)
    except User.DoesNotExist:
        return Response({'error': 'No account found with this email.'}, status=status.HTTP_400_BAD_REQUEST)

    # Update password (Django hashes it securely)
    user.set_password(new_password)
    user.save(update_fields=['password'])

    # Revoke all existing sessions so old tokens no longer work
    Token.objects.filter(user=user).delete()

    SystemLog.log_action(
        action=SystemLog.Action.USER_LOGIN,
        module=SystemLog.Module.AUTHENTICATION,
        user=user,
        description=f'Password reset completed for: {user.email}',
        ip_address=request.META.get('REMOTE_ADDR'),
        user_agent=request.META.get('HTTP_USER_AGENT', ''),
    )

    return Response({'message': 'Password reset successfully. Please log in with your new password.'})
