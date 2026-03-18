"""
Views for user management and system logs (MDRRMO only).
"""
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.contrib.auth import get_user_model
from django.db.models import Q

from core.permissions.mdrrmo import IsMDRRMO
from apps.users.serializers import UserSerializer
from apps.system_logs.models import SystemLog
from apps.system_logs.serializers import SystemLogSerializer

User = get_user_model()


# ==================== User Management (MDRRMO) ====================

@api_view(['GET'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def list_users(request):
    """
    GET /api/mdrrmo/users/
    List all users with optional filters.
    Query params: ?status=active|suspended, ?barangay=..., ?search=...
    MDRRMO only.
    """
    qs = User.objects.all()
    
    # Filter by status
    status_filter = request.GET.get('status', '').lower()
    if status_filter == 'active':
        qs = qs.filter(is_suspended=False, is_active=True)
    elif status_filter == 'suspended':
        qs = qs.filter(is_suspended=True)
    
    # Filter by barangay
    barangay = request.GET.get('barangay', '').strip()
    if barangay:
        qs = qs.filter(barangay__icontains=barangay)
    
    # Search by name, username, or email
    search = request.GET.get('search', '').strip()
    if search:
        qs = qs.filter(
            Q(username__icontains=search) |
            Q(full_name__icontains=search) |
            Q(email__icontains=search)
        )
    
    # Order by date joined (newest first)
    qs = qs.order_by('-date_joined')
    
    serializer = UserSerializer(qs, many=True)
    return Response(serializer.data)


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def get_user(request, user_id):
    """
    GET /api/mdrrmo/users/<user_id>/
    Get details of a specific user.
    MDRRMO only.
    """
    try:
        user = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        return Response(
            {'error': 'User not found'},
            status=status.HTTP_404_NOT_FOUND
        )
    
    serializer = UserSerializer(user)
    
    # Add additional stats
    data = serializer.data
    data['total_reports'] = user.hazard_reports.count()
    data['approved_reports'] = user.hazard_reports.filter(status='approved').count()
    data['pending_reports'] = user.hazard_reports.filter(status='pending').count()
    
    return Response(data)


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def suspend_user(request, user_id):
    """
    POST /api/mdrrmo/users/<user_id>/suspend/
    Suspend a user account.
    MDRRMO only.
    """
    try:
        user = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        return Response(
            {'error': 'User not found'},
            status=status.HTTP_404_NOT_FOUND
        )
    
    if user.role == User.Role.MDRRMO:
        return Response(
            {'error': 'Cannot suspend MDRRMO accounts'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    if user.is_suspended:
        return Response(
            {'error': 'User is already suspended'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    user.suspend()
    
    # Log the action
    SystemLog.log_action(
        action=SystemLog.Action.USER_SUSPENDED,
        module=SystemLog.Module.USER_MANAGEMENT,
        user=request.user,
        description=f'Suspended user: {user.username}',
        related_object_type='User',
        related_object_id=user.id,
        ip_address=request.META.get('REMOTE_ADDR'),
    )
    
    return Response(UserSerializer(user).data)


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def activate_user(request, user_id):
    """
    POST /api/mdrrmo/users/<user_id>/activate/
    Activate a suspended user account.
    MDRRMO only.
    """
    try:
        user = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        return Response(
            {'error': 'User not found'},
            status=status.HTTP_404_NOT_FOUND
        )
    
    if not user.is_suspended:
        return Response(
            {'error': 'User is not suspended'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    user.activate()
    
    # Log the action
    SystemLog.log_action(
        action=SystemLog.Action.USER_ACTIVATED,
        module=SystemLog.Module.USER_MANAGEMENT,
        user=request.user,
        description=f'Activated user: {user.username}',
        related_object_type='User',
        related_object_id=user.id,
        ip_address=request.META.get('REMOTE_ADDR'),
    )
    
    return Response(UserSerializer(user).data)


@api_view(['DELETE'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def delete_user(request, user_id):
    """
    DELETE /api/mdrrmo/users/<user_id>/delete/
    Delete a user account.
    MDRRMO only.
    """
    try:
        user = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        return Response(
            {'error': 'User not found'},
            status=status.HTTP_404_NOT_FOUND
        )
    
    if user.role == User.Role.MDRRMO:
        return Response(
            {'error': 'Cannot delete MDRRMO accounts'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    username = user.username
    user_id_log = user.id
    user.delete()
    
    # Log the action
    SystemLog.log_action(
        action=SystemLog.Action.USER_DELETED,
        module=SystemLog.Module.USER_MANAGEMENT,
        user=request.user,
        description=f'Deleted user: {username}',
        related_object_type='User',
        related_object_id=user_id_log,
        ip_address=request.META.get('REMOTE_ADDR'),
    )
    
    return Response({'message': 'User deleted successfully'})


# ==================== System Logs (MDRRMO) ====================

@api_view(['GET'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def list_system_logs(request):
    """
    GET /api/mdrrmo/system-logs/
    List system logs with optional filters.
    Query params: ?user_role=..., ?module=..., ?action=..., ?status=..., ?search=...
    MDRRMO only.
    """
    qs = SystemLog.objects.all()
    
    # Filter by user role
    user_role = request.GET.get('user_role', '').strip()
    if user_role:
        qs = qs.filter(user_role__iexact=user_role)
    
    # Filter by module
    module = request.GET.get('module', '').strip()
    if module:
        qs = qs.filter(module=module)
    
    # Filter by action
    action = request.GET.get('action', '').strip()
    if action:
        qs = qs.filter(action=action)
    
    # Filter by status
    log_status = request.GET.get('status', '').strip()
    if log_status:
        qs = qs.filter(status=log_status)
    
    # Search in description
    search = request.GET.get('search', '').strip()
    if search:
        qs = qs.filter(
            Q(description__icontains=search) |
            Q(user_name__icontains=search)
        )
    
    # Pagination
    limit = int(request.GET.get('limit', 50))
    offset = int(request.GET.get('offset', 0))
    
    total_count = qs.count()
    qs = qs[offset:offset + limit]
    
    serializer = SystemLogSerializer(qs, many=True)
    
    return Response({
        'count': total_count,
        'results': serializer.data
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def clear_system_logs(request):
    """
    POST /api/mdrrmo/system-logs/clear/
    Clear all system logs (dangerous operation).
    MDRRMO only.
    """
    count = SystemLog.objects.count()
    SystemLog.objects.all().delete()
    
    # Log the clear action
    SystemLog.log_action(
        action=SystemLog.Action.SYSTEM_STARTUP,
        module=SystemLog.Module.SYSTEM,
        user=request.user,
        description=f'Cleared {count} system logs',
        ip_address=request.META.get('REMOTE_ADDR'),
    )
    
    return Response({
        'message': f'Successfully cleared {count} system logs'
    })
