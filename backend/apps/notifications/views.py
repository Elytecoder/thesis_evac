"""
Views for notifications.
"""
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import Notification
from .serializers import NotificationSerializer


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_notifications(request):
    """
    GET /api/notifications/
    List current user's notifications.
    Query params: ?unread_only=true
    """
    qs = Notification.objects.filter(user=request.user)
    
    # Filter unread only
    unread_only = request.GET.get('unread_only', 'false').lower() == 'true'
    if unread_only:
        qs = qs.filter(is_read=False)
    
    serializer = NotificationSerializer(qs, many=True)
    
    # Count unread
    unread_count = Notification.objects.filter(user=request.user, is_read=False).count()
    
    return Response({
        'unread_count': unread_count,
        'notifications': serializer.data
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_notification(request, notification_id):
    """
    GET /api/notifications/<notification_id>/
    Get a specific notification.
    """
    try:
        notification = Notification.objects.get(pk=notification_id, user=request.user)
    except Notification.DoesNotExist:
        return Response(
            {'error': 'Notification not found'},
            status=status.HTTP_404_NOT_FOUND
        )
    
    serializer = NotificationSerializer(notification)
    return Response(serializer.data)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_notification_read(request, notification_id):
    """
    POST /api/notifications/<notification_id>/mark-read/
    Mark a notification as read.
    """
    try:
        notification = Notification.objects.get(pk=notification_id, user=request.user)
    except Notification.DoesNotExist:
        return Response(
            {'error': 'Notification not found'},
            status=status.HTTP_404_NOT_FOUND
        )
    
    notification.mark_as_read()
    
    serializer = NotificationSerializer(notification)
    return Response(serializer.data)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_all_read(request):
    """
    POST /api/notifications/mark-all-read/
    Mark all user's notifications as read.
    """
    from django.utils import timezone
    
    count = Notification.objects.filter(
        user=request.user,
        is_read=False
    ).update(
        is_read=True,
        read_at=timezone.now()
    )
    
    return Response({
        'message': f'Marked {count} notifications as read'
    })


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_notification(request, notification_id):
    """
    DELETE /api/notifications/<notification_id>/
    Delete a notification.
    """
    try:
        notification = Notification.objects.get(pk=notification_id, user=request.user)
    except Notification.DoesNotExist:
        return Response(
            {'error': 'Notification not found'},
            status=status.HTTP_404_NOT_FOUND
        )
    
    notification.delete()
    return Response({'message': 'Notification deleted successfully'})


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def unread_count(request):
    """
    GET /api/notifications/unread-count/
    Get count of unread notifications.
    """
    count = Notification.objects.filter(user=request.user, is_read=False).count()
    return Response({'unread_count': count})
