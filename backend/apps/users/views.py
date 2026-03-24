"""
Authentication API views.
"""
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from django.contrib.auth import authenticate, get_user_model
from django.core.mail import send_mail
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

User = get_user_model()


@api_view(['POST'])
@permission_classes([AllowAny])
def send_verification_code(request):
    """
    POST /api/auth/send-verification-code/
    Send email verification code.
    Body: {email}
    Returns: {message, expires_in}
    """
    try:
        print(f"\n=== SEND VERIFICATION CODE REQUEST ===")
        print(f"Request data: {request.data}")
        print(f"Request method: {request.method}")
        print(f"Content-Type: {request.content_type}")
        print(f"=====================================\n")
        
        email = request.data.get('email', '').lower().strip()
        print(f"Extracted email: '{email}'")
        
        if not email:
            print("ERROR: Email is empty")
            return Response(
                {'error': 'Email is required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Check if email already exists
        print(f"Checking if email exists in database...")
        if User.objects.filter(email=email).exists():
            print("ERROR: Email already registered")
            return Response(
                {'error': 'Email is already registered'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Generate and save verification code
        print(f"Creating verification code...")
        verification = EmailVerificationCode.create_verification(email)
        print(f"Verification code created: {verification.code}")
        
        # Print to console (for server logs)
        print(f"\n{'='*50}")
        print(f"EMAIL VERIFICATION CODE")
        print(f"Email: {email}")
        print(f"Code: {verification.code}")
        print(f"Expires in: 5 minutes")
        print(f"{'='*50}\n")
        
        # Return code so app can show it when email is not configured (e.g. Render demo).
        # When you add real email (SMTP/SendGrid), remove 'code' and 'dev_code' from the response.
        response_data = {
            'message': 'Verification code sent to your email',
            'expires_in': '5 minutes',
            'dev_code': verification.code,
            'code': verification.code,
        }
        print(f"Returning success response: {response_data}")
        
        return Response(response_data)
    
    except Exception as e:
        print(f"\n!!! EXCEPTION OCCURRED !!!")
        print(f"Exception type: {type(e).__name__}")
        print(f"Exception message: {str(e)}")
        import traceback
        print(f"Traceback:\n{traceback.format_exc()}")
        print(f"!!! END EXCEPTION !!!\n")
        
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
