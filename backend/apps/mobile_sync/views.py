"""
API views for mobile app. Thin layer; business logic in services.
All responses are JSON only.
"""
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response

from core.permissions.mdrrmo import IsMDRRMO
from apps.evacuation.models import EvacuationCenter
from apps.evacuation.serializers import EvacuationCenterSerializer
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


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def report_hazard(request):
    """
    POST /api/report-hazard/
    Body: hazard_type, latitude, longitude, description?, photo_url?
    """
    serializer = HazardReportCreateSerializer(data=request.data)
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    data = serializer.validated_data
    report = process_new_report(
        user=request.user,
        hazard_type=data['hazard_type'],
        latitude=data['latitude'],
        longitude=data['longitude'],
        description=data.get('description', ''),
        photo_url=data.get('photo_url', ''),
    )
    return Response(
        HazardReportSerializer(report).data,
        status=status.HTTP_201_CREATED,
    )


@api_view(['GET'])
@permission_classes([AllowAny])
def evacuation_centers(request):
    """
    GET /api/evacuation-centers/
    """
    qs = EvacuationCenter.objects.all()
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
def mdrrmo_pending_reports(request):
    """
    GET /api/mdrrmo/pending-reports/
    MDRRMO only.
    """
    qs = HazardReport.objects.filter(status=HazardReport.Status.PENDING).order_by('-created_at')
    serializer = PendingReportSerializer(qs, many=True)
    return Response(serializer.data)


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def mdrrmo_approve_report(request):
    """
    POST /api/mdrrmo/approve-report/
    Body: report_id, action ('approve' | 'reject')
    MDRRMO only.
    """
    report_id = request.data.get('report_id')
    action = request.data.get('action')
    if not report_id or action not in ('approve', 'reject'):
        return Response(
            {'error': 'report_id and action (approve|reject) required'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    try:
        report = HazardReport.objects.get(pk=report_id)
    except HazardReport.DoesNotExist:
        return Response({'error': 'Report not found'}, status=status.HTTP_404_NOT_FOUND)
    report.status = HazardReport.Status.APPROVED if action == 'approve' else HazardReport.Status.REJECTED
    report.save(update_fields=['status'])
    return Response(PendingReportSerializer(report).data)


@api_view(['GET'])
@permission_classes([AllowAny])
def bootstrap_sync(request):
    """
    GET /api/bootstrap-sync/
    Returns evacuation centers and baseline hazards for mobile cache.
    """
    data = get_bootstrap_data()
    return Response(data)
