"""
API views for mobile app. Thin layer; business logic in services.
All responses are JSON only.
"""
from django.conf import settings as django_settings
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response

from apps.hazards import hazard_media
from core.permissions.mdrrmo import IsMDRRMO
from apps.evacuation.models import EvacuationCenter
from apps.evacuation.serializers import (
    EvacuationCenterSerializer,
    EvacuationCenterCreateSerializer,
)
from apps.hazards.models import HazardReport
from apps.hazards.serializers import (
    HazardReportCreateSerializer,
    HazardReportSerializer,
    PendingReportSerializer,
)
from apps.routing.models import RouteLog
from apps.routing.serializers import CalculateRouteRequestSerializer
from apps.mobile_sync.services.report_service import process_new_report
from apps.mobile_sync.services.route_service import calculate_safest_routes
from apps.mobile_sync.services.bootstrap_service import get_bootstrap_data
from apps.notifications.models import Notification


def _report_hazard_json_500(detail: str) -> Response:
    """Return a JSON 500 so the client never gets HTML."""
    return Response(
        {'error': 'Could not process report.', 'detail': detail},
        status=status.HTTP_500_INTERNAL_SERVER_ERROR,
    )


def _optional_form_float(data, key):
    v = data.get(key)
    if v is None or v == '':
        return None
    return v


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def report_hazard(request):
    """
    POST /api/report-hazard/
    JSON: hazard_type, latitude, longitude, description?, photo_url?, video_url?, user_latitude?, user_longitude?
    Multipart: same fields as form + optional files photo (image), video (mp4 when enabled).
    Media saved under MEDIA_ROOT/hazards/; DB stores absolute URLs.
    """
    try:
        video_enabled = django_settings.HAZARD_VIDEO_UPLOAD_ENABLED
        ct = (request.content_type or '').lower()

        if 'multipart/form-data' in ct:
            payload = {
                'hazard_type': request.data.get('hazard_type'),
                'latitude': request.data.get('latitude'),
                'longitude': request.data.get('longitude'),
                'description': request.data.get('description') or '',
                'photo_url': '',
                'video_url': '',
                'user_latitude': _optional_form_float(request.data, 'user_latitude'),
                'user_longitude': _optional_form_float(request.data, 'user_longitude'),
            }
            serializer = HazardReportCreateSerializer(data=payload)
            if not serializer.is_valid():
                return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
            validated = serializer.validated_data

            photo_url = ''
            if 'photo' in request.FILES:
                ok, result = hazard_media.save_uploaded_image(request.FILES['photo'], request)
                if not ok:
                    return Response({'error': result}, status=status.HTTP_400_BAD_REQUEST)
                photo_url = result

            video_url = ''
            if 'video' in request.FILES:
                if not video_enabled:
                    return Response(
                        {'error': hazard_media.INVALID_FILE_ERROR},
                        status=status.HTTP_400_BAD_REQUEST,
                    )
                ok, result = hazard_media.save_uploaded_video(request.FILES['video'], request)
                if not ok:
                    return Response({'error': result}, status=status.HTTP_400_BAD_REQUEST)
                video_url = result
        else:
            serializer = HazardReportCreateSerializer(data=request.data)
            if not serializer.is_valid():
                return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
            validated = serializer.validated_data
            photo_url = validated.get('photo_url') or ''
            video_url = validated.get('video_url') or ''

            if photo_url:
                ok, out = hazard_media.process_data_url_photo(photo_url, request)
                if not ok:
                    return Response({'error': out}, status=status.HTTP_400_BAD_REQUEST)
                photo_url = out
            if video_url:
                if video_url.strip().startswith('data:') and not video_enabled:
                    return Response(
                        {'error': hazard_media.INVALID_FILE_ERROR},
                        status=status.HTTP_400_BAD_REQUEST,
                    )
                ok, out = hazard_media.process_data_url_video(video_url, request)
                if not ok:
                    return Response({'error': out}, status=status.HTTP_400_BAD_REQUEST)
                video_url = out

        report = process_new_report(
            user=request.user,
            hazard_type=validated['hazard_type'],
            latitude=validated['latitude'],
            longitude=validated['longitude'],
            description=validated.get('description', ''),
            photo_url=photo_url,
            video_url=video_url,
            user_latitude=validated.get('user_latitude'),
            user_longitude=validated.get('user_longitude'),
        )
        payload = HazardReportSerializer(report).data
        return Response(payload, status=status.HTTP_201_CREATED)
    except Exception as e:
        import traceback
        traceback.print_exc()
        return _report_hazard_json_500(str(e))


@api_view(['GET'])
@permission_classes([AllowAny])
def evacuation_centers(request):
    """
    GET /api/evacuation-centers/
    Returns all operational evacuation centers by default.
    Query params: ?include_inactive=true to include non-operational centers.
    """
    include_inactive = request.GET.get('include_inactive', 'false').lower() == 'true'
    
    if include_inactive:
        qs = EvacuationCenter.objects.all()
    else:
        # Only return operational centers for routing
        qs = EvacuationCenter.objects.filter(is_operational=True)
    
    serializer = EvacuationCenterSerializer(qs, many=True)
    return Response(serializer.data)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def calculate_route(request):
    """
    POST /api/calculate-route/
    Body: start_lat, start_lng, evacuation_center_id
    Returns 3 safest routes with risk level (Green/Yellow/Red).
    """
    serializer = CalculateRouteRequestSerializer(data=request.data)
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    data = serializer.validated_data
    ec_id = data['evacuation_center_id']
    result = calculate_safest_routes(
        data['start_lat'], data['start_lng'],
        ec_id,
        k=3,
    )
    if result is None:
        return Response(
            {'error': 'Evacuation center not found'},
            status=status.HTTP_404_NOT_FOUND,
        )
    # Optionally log the selected route (e.g. first one) for analytics
    first_route = result['routes'][0] if result['routes'] else None
    if first_route:
        RouteLog.objects.create(
            user=request.user,
            evacuation_center_id=ec_id,
            selected_route_risk=first_route.get('total_risk', 0),
        )
    return Response(result)


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def mdrrmo_dashboard_stats(request):
    """
    GET /api/mdrrmo/dashboard-stats/
    Returns counts for dashboard cards, hazard_distribution (verified only), and recent_activity.
    MDRRMO only.
    """
    from django.db.models import Count
    from django.utils import timezone
    total_reports = HazardReport.objects.filter(auto_rejected=False).count()
    pending_reports = HazardReport.objects.filter(
        status=HazardReport.Status.PENDING,
        auto_rejected=False,
    ).count()
    verified_hazards = HazardReport.objects.filter(
        status=HazardReport.Status.APPROVED,
    ).count()
    total_evacuation_centers = EvacuationCenter.objects.count()
    non_operational_centers = EvacuationCenter.objects.filter(is_operational=False).count()

    # Hazard type distribution from verified (approved) reports only
    hazard_distribution = dict(
        HazardReport.objects.filter(status=HazardReport.Status.APPROVED)
        .values('hazard_type')
        .annotate(count=Count('id'))
        .values_list('hazard_type', 'count')
    )

    # Recent activity: last 10 report-related events (submitted / approved / rejected)
    recent_reports = (
        HazardReport.objects.filter(auto_rejected=False)
        .order_by('-created_at')[:10]
        .select_related('user')
    )
    recent_activity = []
    for r in recent_reports:
        if r.status == HazardReport.Status.APPROVED:
            activity_type = 'report_approved'
            message = f'Report #{r.id} ({r.hazard_type.replace("_", " ")}) approved'
        elif r.status == HazardReport.Status.REJECTED:
            activity_type = 'report_rejected'
            message = f'Report #{r.id} ({r.hazard_type.replace("_", " ")}) rejected'
        else:
            activity_type = 'report_submitted'
            message = f'Report #{r.id} ({r.hazard_type.replace("_", " ")}) submitted'
        location = f'{float(r.latitude):.4f}, {float(r.longitude):.4f}'
        recent_activity.append({
            'type': activity_type,
            'message': message,
            'timestamp': r.created_at.isoformat() if r.created_at else timezone.now().isoformat(),
            'location': location,
        })

    return Response({
        'total_reports': total_reports,
        'pending_reports': pending_reports,
        'verified_hazards': verified_hazards,
        'high_risk_roads': 0,
        'total_evacuation_centers': total_evacuation_centers,
        'non_operational_centers': non_operational_centers,
        'hazard_distribution': hazard_distribution,
        'recent_activity': recent_activity,
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def mdrrmo_pending_reports(request):
    """
    GET /api/mdrrmo/pending-reports/
    MDRRMO only.
    """
    qs = (
        HazardReport.objects.filter(status=HazardReport.Status.PENDING)
        .select_related('user')
        .order_by('-created_at')
    )
    serializer = PendingReportSerializer(qs, many=True)
    return Response(serializer.data)


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def mdrrmo_approve_report(request):
    """
    POST /api/mdrrmo/approve-report/
    Body: report_id, action ('approve' | 'reject'), admin_comment (optional)
    MDRRMO only.
    """
    report_id = request.data.get('report_id')
    action = request.data.get('action')
    admin_comment = request.data.get('admin_comment', '')
    
    if not report_id or action not in ('approve', 'reject'):
        return Response(
            {'error': 'report_id and action (approve|reject) required'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    try:
        report = HazardReport.objects.select_related('user').get(pk=report_id)
    except HazardReport.DoesNotExist:
        return Response({'error': 'Report not found'}, status=status.HTTP_404_NOT_FOUND)
    
    if action == 'approve':
        report.status = HazardReport.Status.APPROVED
        
        # Create notification for resident
        Notification.create_notification(
            user=report.user,
            notification_type=Notification.Type.REPORT_APPROVED,
            title='Report Approved',
            message=f'Your hazard report about {report.hazard_type} has been approved by MDRRMO.',
            related_object_type='HazardReport',
            related_object_id=report.id,
            metadata={
                'hazard_type': report.hazard_type,
                'latitude': str(report.latitude),
                'longitude': str(report.longitude),
            }
        )
    else:
        report.mark_rejected()
        
        # Create notification for resident
        Notification.create_notification(
            user=report.user,
            notification_type=Notification.Type.REPORT_REJECTED,
            title='Report Rejected',
            message=f'Your hazard report about {report.hazard_type} was rejected after verification.',
            related_object_type='HazardReport',
            related_object_id=report.id,
            metadata={
                'hazard_type': report.hazard_type,
                'reason': admin_comment if admin_comment else 'Did not meet validation criteria',
            }
        )
    
    if admin_comment:
        report.admin_comment = admin_comment
    
    report.save()
    return Response(PendingReportSerializer(report).data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def my_reports(request):
    """
    GET /api/my-reports/
    Returns all reports submitted by the current user.
    """
    qs = (
        HazardReport.objects.filter(
            user=request.user,
            auto_rejected=False,  # Don't show auto-rejected reports
        )
        .select_related('user')
        .order_by('-created_at')
    )
    serializer = HazardReportSerializer(qs, many=True)
    return Response(serializer.data)


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_my_report(request, report_id):
    """
    DELETE /api/my-reports/<report_id>/
    Allows user to delete their own pending report.
    """
    try:
        report = HazardReport.objects.get(pk=report_id, user=request.user)
    except HazardReport.DoesNotExist:
        return Response(
            {'error': 'Report not found or access denied'},
            status=status.HTTP_404_NOT_FOUND
        )
    
    # Only allow deletion of pending reports
    if report.status != HazardReport.Status.PENDING:
        return Response(
            {'error': 'Can only delete pending reports'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    report.delete()
    return Response({'message': 'Report deleted successfully'})


@api_view(['GET'])
@permission_classes([AllowAny])
def verified_hazards(request):
    """
    GET /api/verified-hazards/
    Returns all approved hazard reports for map display.
    """
    qs = HazardReport.objects.filter(status=HazardReport.Status.APPROVED).select_related('user')
    serializer = HazardReportSerializer(qs, many=True)
    return Response(serializer.data)


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def restore_report(request):
    """
    POST /api/mdrrmo/restore-report/
    Body: report_id, restoration_reason
    Restores a rejected report back to pending status.
    MDRRMO only.
    """
    report_id = request.data.get('report_id')
    restoration_reason = request.data.get('restoration_reason', '')
    
    if not report_id or not restoration_reason:
        return Response(
            {'error': 'report_id and restoration_reason required'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    try:
        report = HazardReport.objects.select_related('user').get(pk=report_id)
    except HazardReport.DoesNotExist:
        return Response({'error': 'Report not found'}, status=status.HTTP_404_NOT_FOUND)
    
    if report.status != HazardReport.Status.REJECTED:
        return Response(
            {'error': 'Can only restore rejected reports'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    report.restore(restoration_reason)
    return Response(PendingReportSerializer(report).data)


@api_view(['DELETE'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def mdrrmo_delete_report(request, report_id: int):
    """
    DELETE /api/mdrrmo/reports/<report_id>/
    MDRRMO can delete an approved or rejected report. Removes it from the system.
    """
    try:
        report = HazardReport.objects.get(pk=report_id)
    except HazardReport.DoesNotExist:
        return Response({'error': 'Report not found'}, status=status.HTTP_404_NOT_FOUND)
    if report.status == HazardReport.Status.PENDING:
        return Response(
            {'error': 'Cannot delete pending reports. Approve or reject them first.'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    report.delete()
    return Response({'message': 'Report deleted successfully'}, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def mdrrmo_rejected_reports(request):
    """
    GET /api/mdrrmo/rejected-reports/
    Returns all rejected reports for MDRRMO dashboard.
    MDRRMO only.
    """
    qs = (
        HazardReport.objects.filter(
            status=HazardReport.Status.REJECTED,
            auto_rejected=False,  # Don't show auto-rejected reports
        )
        .select_related('user')
        .order_by('-rejected_at')
    )
    serializer = PendingReportSerializer(qs, many=True)
    return Response(serializer.data)


@api_view(['GET'])
@permission_classes([AllowAny])
def bootstrap_sync(request):
    """
    GET /api/bootstrap-sync/
    Returns evacuation centers and baseline hazards for mobile cache.
    """
    data = get_bootstrap_data()
    return Response(data)


# ==================== Evacuation Center CRUD (MDRRMO) ====================

@api_view(['POST'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def create_evacuation_center(request):
    """
    POST /api/mdrrmo/evacuation-centers/
    Create a new evacuation center.
    MDRRMO only.
    """
    serializer = EvacuationCenterCreateSerializer(data=request.data)
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    center = serializer.save()
    return Response(
        EvacuationCenterSerializer(center).data,
        status=status.HTTP_201_CREATED
    )


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def get_evacuation_center(request, center_id):
    """
    GET /api/mdrrmo/evacuation-centers/<center_id>/
    Get details of a specific evacuation center.
    MDRRMO only.
    """
    try:
        center = EvacuationCenter.objects.get(pk=center_id)
    except EvacuationCenter.DoesNotExist:
        return Response(
            {'error': 'Evacuation center not found'},
            status=status.HTTP_404_NOT_FOUND
        )
    
    serializer = EvacuationCenterSerializer(center)
    return Response(serializer.data)


@api_view(['PUT'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def update_evacuation_center(request, center_id):
    """
    PUT /api/mdrrmo/evacuation-centers/<center_id>/
    Update an evacuation center.
    MDRRMO only.
    """
    try:
        center = EvacuationCenter.objects.get(pk=center_id)
    except EvacuationCenter.DoesNotExist:
        return Response(
            {'error': 'Evacuation center not found'},
            status=status.HTTP_404_NOT_FOUND
        )
    
    serializer = EvacuationCenterCreateSerializer(
        center,
        data=request.data,
        partial=True
    )
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    updated = serializer.save()
    return Response(EvacuationCenterSerializer(updated).data)


@api_view(['DELETE'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def delete_evacuation_center(request, center_id):
    """
    DELETE /api/mdrrmo/evacuation-centers/<center_id>/
    Delete an evacuation center.
    MDRRMO only.
    """
    try:
        center = EvacuationCenter.objects.get(pk=center_id)
    except EvacuationCenter.DoesNotExist:
        return Response(
            {'error': 'Evacuation center not found'},
            status=status.HTTP_404_NOT_FOUND
        )
    
    center.delete()
    return Response({'message': 'Evacuation center deleted successfully'})


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def deactivate_evacuation_center(request, center_id):
    """
    POST /api/mdrrmo/evacuation-centers/<center_id>/deactivate/
    Deactivate an evacuation center.
    MDRRMO only.
    """
    try:
        center = EvacuationCenter.objects.get(pk=center_id)
    except EvacuationCenter.DoesNotExist:
        return Response(
            {'error': 'Evacuation center not found'},
            status=status.HTTP_404_NOT_FOUND
        )
    
    center.deactivate()
    return Response(EvacuationCenterSerializer(center).data)


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def reactivate_evacuation_center(request, center_id):
    """
    POST /api/mdrrmo/evacuation-centers/<center_id>/reactivate/
    Reactivate an evacuation center.
    MDRRMO only.
    """
    try:
        center = EvacuationCenter.objects.get(pk=center_id)
    except EvacuationCenter.DoesNotExist:
        return Response(
            {'error': 'Evacuation center not found'},
            status=status.HTTP_404_NOT_FOUND
        )
    
    center.reactivate()
    return Response(EvacuationCenterSerializer(center).data)
