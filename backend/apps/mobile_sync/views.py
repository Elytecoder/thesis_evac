"""
API views for mobile app. Thin layer; business logic in services.
All responses are JSON only.
"""
from django.conf import settings as django_settings
from django.db import models
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response

import threading

from apps.hazards import hazard_media
from core.permissions.mdrrmo import IsMDRRMO
from core.utils.geo import haversine_meters as _haversine_meters
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
    PublicHazardSerializer,
    SimilarReportPublicSerializer,
)
from apps.routing.models import RouteLog
from apps.routing.serializers import CalculateRouteRequestSerializer
from apps.mobile_sync.services.report_service import (
    process_new_report,
    DuplicateHazardReportError,
)
from apps.mobile_sync.services.route_service import calculate_safest_routes
from apps.mobile_sync.services.bootstrap_service import get_bootstrap_data
from apps.notifications.models import Notification
from apps.notifications import fcm_service
from apps.users.serializers import MdrrmoUserListSerializer


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


def _sync_recompute_segment_risks():
    """
    Synchronously refresh all road segment risk scores.
    Called inline (before the HTTP response is sent) after any MDRRMO action
    that changes the approved-hazard set, guaranteeing zero stale-score window.
    Fast enough for Bulan's ~600-segment road network (<100 ms typical).
    """
    try:
        from apps.mobile_sync.services.route_service import recompute_all_segment_risks
        recompute_all_segment_risks(force=True)
    except Exception as exc:  # pragma: no cover
        import logging
        logging.getLogger(__name__).warning('Segment recompute failed: %s', exc)


def _notify_mdrrmo_new_report_async(report):
    """Send FCM push to all MDRRMO users in a background thread (non-blocking)."""
    def _send():
        hazard_label = report.hazard_type.replace('_', ' ').title()
        barangay = getattr(report.user, 'barangay', '') or 'Unknown Location'
        fcm_service.send_to_role(
            role='mdrrmo',
            title='New Hazard Report Submitted',
            body=f'{hazard_label} reported near Barangay {barangay}',
            data={
                'type': 'new_report',
                'target': 'mdrrmo_reports',   # Flutter uses this to navigate to reports screen
                'report_id': str(report.id),
                'hazard_type': report.hazard_type,
            },
        )
    threading.Thread(target=_send, daemon=True).start()


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

        user_lat = validated.get('user_latitude')
        user_lng = validated.get('user_longitude')
        if user_lat is None or user_lng is None:
            return Response(
                {'error': 'Your current GPS location is required to submit a hazard report.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Idempotency: if the client resends an offline-queued report that the
        # server already accepted, return the existing report instead of duplicating.
        client_submission_id = request.data.get('client_submission_id') or None
        if client_submission_id:
            existing = HazardReport.objects.filter(
                client_submission_id=client_submission_id,
                user=request.user,
            ).first()
            if existing:
                return Response(HazardReportSerializer(existing).data, status=status.HTTP_200_OK)

        try:
            report = process_new_report(
                user=request.user,
                hazard_type=validated['hazard_type'],
                latitude=validated['latitude'],
                longitude=validated['longitude'],
                description=validated.get('description', ''),
                photo_url=photo_url,
                video_url=video_url,
                user_latitude=user_lat,
                user_longitude=user_lng,
                client_submission_id=client_submission_id,
            )
        except DuplicateHazardReportError as dup_exc:
            existing = dup_exc.existing_report
            return Response(
                {
                    'error': str(dup_exc),
                    'requires_confirmation': True,
                    'existing_report_id': existing.id if existing else None,
                    'distance_meters': round(float(dup_exc.distance_meters), 2) if dup_exc.distance_meters is not None else None,
                    'already_reported_by_user': dup_exc.already_reported_by_user,
                    'has_user_confirmed': dup_exc.has_user_confirmed,
                },
                status=status.HTTP_409_CONFLICT,
            )

        # Notify MDRRMO staff via push notification (non-blocking thread)
        if not report.auto_rejected:
            _notify_mdrrmo_new_report_async(report)

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

    The response includes a 'snap_info' object with diagnostic details:
      user_lat/lng       - coordinates received from the client
      user_snap_node     - nearest road-graph node to user
      user_snap_distance_m - metres between user and snapped start node
      ec_lat/lng         - coordinates of the selected evacuation centre
      ec_snap_node       - nearest road-graph node to the EC
      ec_snap_distance_m - metres between EC and snapped destination node
      ec_in_road_bounds  - whether EC is inside the road-network bounding box
    Large snap distances (> 500 m) indicate wrong EC coordinates or that the
    user/EC is far from the road network — the route will look unrealistically long.
    """
    serializer = CalculateRouteRequestSerializer(data=request.data)
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    data = serializer.validated_data
    ec_id = data['evacuation_center_id']
    try:
        result = calculate_safest_routes(
            data['start_lat'], data['start_lng'],
            ec_id,
            k=3,
        )
    except Exception as exc:
        import traceback
        return Response(
            {'error': 'Route calculation failed.', 'detail': str(exc), 'trace': traceback.format_exc()},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )
    if result is None:
        return Response(
            {'error': 'Evacuation center not found'},
            status=status.HTTP_404_NOT_FOUND,
        )

    # ── Snap-distance diagnostics (helps detect wrong EC coordinates) ──────────
    try:
        from apps.routing.models import RoadSegment
        from core.utils.geo import haversine_meters
        from apps.evacuation.models import EvacuationCenter as _EC

        start_lat_f = float(data['start_lat'])
        start_lng_f = float(data['start_lng'])
        ec_obj = _EC.objects.filter(pk=ec_id).first()

        # Road-graph bounding box from the 3 247 stored segments
        # (computed once; values match mock_road_network.json bounds)
        GRAPH_MIN_LAT, GRAPH_MAX_LAT = 12.6407702, 12.7225778
        GRAPH_MIN_LNG, GRAPH_MAX_LNG = 123.8578030, 123.9422168

        snap_info = {
            'user_lat': start_lat_f,
            'user_lng': start_lng_f,
            'user_snap_node': None,
            'user_snap_distance_m': None,
            'ec_lat': float(ec_obj.latitude) if ec_obj else None,
            'ec_lng': float(ec_obj.longitude) if ec_obj else None,
            'ec_snap_node': None,
            'ec_snap_distance_m': None,
            'ec_in_road_bounds': (
                GRAPH_MIN_LAT <= float(ec_obj.latitude) <= GRAPH_MAX_LAT and
                GRAPH_MIN_LNG <= float(ec_obj.longitude) <= GRAPH_MAX_LNG
            ) if ec_obj else False,
        }

        # Find nearest road node for user and EC
        segs = RoadSegment.objects.values_list(
            'start_lat', 'start_lng', 'end_lat', 'end_lng'
        )[:3000]  # sample – enough to find nearest node
        best_user_d = best_ec_d = float('inf')
        best_user_node = best_ec_node = None
        for sla, slng, ela, elng in segs:
            for nla, nlng in ((float(sla), float(slng)), (float(ela), float(elng))):
                du = haversine_meters(start_lat_f, start_lng_f, nla, nlng)
                if du < best_user_d:
                    best_user_d = du
                    best_user_node = [nla, nlng]
                if ec_obj:
                    de = haversine_meters(float(ec_obj.latitude), float(ec_obj.longitude), nla, nlng)
                    if de < best_ec_d:
                        best_ec_d = de
                        best_ec_node = [nla, nlng]

        snap_info['user_snap_node'] = best_user_node
        snap_info['user_snap_distance_m'] = round(best_user_d, 1) if best_user_d < float('inf') else None
        snap_info['ec_snap_node'] = best_ec_node
        snap_info['ec_snap_distance_m'] = round(best_ec_d, 1) if best_ec_d < float('inf') else None

        # Flag when EC is potentially misplaced
        if ec_obj and not snap_info['ec_in_road_bounds']:
            snap_info['ec_warning'] = (
                f'EC coordinates ({snap_info["ec_lat"]:.6f}, {snap_info["ec_lng"]:.6f}) are OUTSIDE '
                f'the road network bounds (lat {GRAPH_MIN_LAT}–{GRAPH_MAX_LAT}, '
                f'lng {GRAPH_MIN_LNG}–{GRAPH_MAX_LNG}). Routes will be unrealistically long. '
                'Please update EC coordinates in the MDRRMO admin panel.'
            )
        elif snap_info['ec_snap_distance_m'] and snap_info['ec_snap_distance_m'] > 500:
            snap_info['ec_warning'] = (
                f'EC snapped {snap_info["ec_snap_distance_m"]:.0f} m from the nearest road node. '
                'This is unusually large and may cause incorrect routing. '
                'Please verify EC coordinates in the MDRRMO admin panel.'
            )

        result['snap_info'] = snap_info

        # Print to server log for debugging
        print(
            f'[ROUTE] user=({start_lat_f:.6f},{start_lng_f:.6f}) '
            f'snap={best_user_d:.1f}m | '
            f'ec=({snap_info["ec_lat"]},{snap_info["ec_lng"]}) '
            f'ec_snap={best_ec_d:.1f}m '
            f'in_bounds={snap_info["ec_in_road_bounds"]} '
            f'routes={len(result.get("routes", []))}'
        )
    except Exception as diag_exc:
        # Never let diagnostics break routing
        result['snap_info'] = {'error': str(diag_exc)}
        print(f'[ROUTE] snap diagnostic failed: {diag_exc}')
    # Log selected route for analytics in background (non-blocking)
    first_route = result['routes'][0] if result['routes'] else None
    if first_route:
        import threading
        _user_id = request.user.pk
        _risk = first_route.get('total_risk', 0)
        def _log_route():
            try:
                RouteLog.objects.create(
                    user_id=_user_id,
                    evacuation_center_id=ec_id,
                    selected_route_risk=_risk,
                )
            except Exception:
                pass
        threading.Thread(target=_log_route, daemon=True).start()
    return Response(result)


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def mdrrmo_high_risk_roads(request):
    """
    GET /api/mdrrmo/high-risk-roads/
    Returns road segments with elevated effective risk (>= 0.3) for MDRRMO monitoring.
    Includes id, coordinates, risk_score, risk_level, and nearby hazard info.
    """
    try:
        from apps.routing.models import RoadSegment
        from apps.mobile_sync.services.route_service import (
            calculate_segment_risk,
            _get_approved_hazards,
            HAZARD_INFLUENCE_RADIUS,
        )
        from math import radians, cos, sin, asin, sqrt

        def _haversine_m(lat1, lng1, lat2, lng2):
            r = 6_371_000
            dlat = radians(lat2 - lat1)
            dlng = radians(lng2 - lng1)
            a = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlng / 2) ** 2
            return 2 * r * asin(sqrt(a))

        segments = list(RoadSegment.objects.all())
        approved_hazards = _get_approved_hazards()
        result = []

        for seg in segments:
            risk = calculate_segment_risk(seg, approved_hazards)
            if risk < 0.30:
                continue
            mid_lat = (float(seg.start_lat) + float(seg.end_lat)) / 2
            mid_lng = (float(seg.start_lng) + float(seg.end_lng)) / 2

            # Find nearest approved hazard causing this elevation
            nearest = None
            nearest_dist = float('inf')
            for h in approved_hazards:
                d = _haversine_m(mid_lat, mid_lng, float(h.latitude), float(h.longitude))
                if d < nearest_dist:
                    nearest_dist = d
                    nearest = h

            level = 'high' if risk >= 0.70 else 'moderate'
            entry = {
                'id': seg.id,
                'start_lat': float(seg.start_lat),
                'start_lng': float(seg.start_lng),
                'end_lat': float(seg.end_lat),
                'end_lng': float(seg.end_lng),
                'risk_score': round(risk, 3),
                'risk_level': level,
            }
            if nearest:
                entry['nearest_hazard'] = {
                    'type': nearest.hazard_type,
                    'distance_m': round(nearest_dist),
                    'barangay': nearest.user.barangay if nearest.user else '',
                }
            result.append(entry)

        result.sort(key=lambda x: x['risk_score'], reverse=True)
        return Response({'count': len(result), 'segments': result})

    except Exception as exc:
        import traceback
        return Response({'error': str(exc), 'detail': traceback.format_exc()},
                        status=status.HTTP_500_INTERNAL_SERVER_ERROR)


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
    total_reports = HazardReport.objects.filter(auto_rejected=False, is_deleted=False).count()
    pending_reports = HazardReport.objects.filter(
        status=HazardReport.Status.PENDING,
        auto_rejected=False,
        is_deleted=False,
    ).count()
    verified_hazards = HazardReport.objects.filter(
        status=HazardReport.Status.APPROVED,
        is_deleted=False,
    ).count()
    total_evacuation_centers = EvacuationCenter.objects.count()
    non_operational_centers = EvacuationCenter.objects.filter(is_operational=False).count()
    # Count road segments whose predicted risk score exceeds the high-risk threshold
    try:
        from apps.routing.models import RoadSegment
        high_risk_roads = RoadSegment.objects.filter(predicted_risk_score__gte=0.7).count()
    except Exception:
        high_risk_roads = 0

    # Hazard type distribution from verified (approved) reports only
    hazard_distribution = dict(
        HazardReport.objects.filter(status=HazardReport.Status.APPROVED, is_deleted=False)
        .values('hazard_type')
        .annotate(count=Count('id'))
        .values_list('hazard_type', 'count')
    )

    # Recent activity: last 10 report-related events (submitted / approved / rejected)
    recent_reports = (
        HazardReport.objects.filter(auto_rejected=False, is_deleted=False)
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
        'high_risk_roads': high_risk_roads,
        'total_evacuation_centers': total_evacuation_centers,
        'non_operational_centers': non_operational_centers,
        'hazard_distribution': hazard_distribution,
        'recent_activity': recent_activity,
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def mdrrmo_analytics(request):
    """
    GET /api/mdrrmo/analytics/
    Returns hazard_type_distribution and road_risk_distribution from live DB data.
    Used by the analytics dashboard.  MDRRMO only.
    """
    from django.db.models import Count
    from apps.routing.models import RoadSegment

    # Road risk distribution from EFFECTIVE risk scores (base RF + dynamic hazards)
    # This matches the risk calculation used by the map/routing layer
    try:
        from apps.mobile_sync.services.route_service import (
            calculate_segment_risk,
            _get_approved_hazards,
        )
        all_segs = list(RoadSegment.objects.all())
        approved_hazards = _get_approved_hazards()

        high_risk = 0
        moderate_risk = 0
        low_risk = 0

        for seg in all_segs:
            effective_risk = calculate_segment_risk(seg, approved_hazards)
            if effective_risk >= 0.7:
                high_risk += 1
            elif effective_risk >= 0.3:
                moderate_risk += 1
            else:
                low_risk += 1
    except Exception:
        high_risk = moderate_risk = low_risk = 0

    # Hazard type distribution from approved, non-deleted reports
    hazard_type_distribution = dict(
        HazardReport.objects.filter(
            status=HazardReport.Status.APPROVED, is_deleted=False
        )
        .values('hazard_type')
        .annotate(count=Count('id'))
        .values_list('hazard_type', 'count')
    )

    return Response({
        'road_risk_distribution': {
            'high_risk': high_risk,
            'moderate_risk': moderate_risk,
            'low_risk': low_risk,
        },
        'hazard_type_distribution': hazard_type_distribution,
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def mdrrmo_pending_reports(request):
    """
    GET /api/mdrrmo/pending-reports/
    MDRRMO only.
    """
    qs = (
        HazardReport.objects.filter(status=HazardReport.Status.PENDING, is_deleted=False)
        .select_related('user')
        .order_by('-created_at')
    )
    serializer = PendingReportSerializer(qs, many=True)
    return Response(serializer.data)


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def mdrrmo_approved_reports(request):
    """
    GET /api/mdrrmo/approved-reports/
    Returns approved reports for MDRRMO report management with full detail fields
    (description, scores, validation breakdown, media flags, etc.).
    """
    qs = (
        HazardReport.objects.filter(status=HazardReport.Status.APPROVED, is_deleted=False)
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
        # Push to resident device
        if report.user.fcm_token:
            hazard_label = report.hazard_type.replace('_', ' ').title()
            fcm_service.send_push(
                token=report.user.fcm_token,
                title='Report Approved',
                body='Your reported hazard has been verified and approved.',
                data={
                    'type': 'report_approved',
                    'target': 'resident_notifications',
                    'report_id': str(report.id),
                },
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
        # Push to resident device
        if report.user.fcm_token:
            hazard_label = report.hazard_type.replace('_', ' ').title()
            fcm_service.send_push(
                token=report.user.fcm_token,
                title='Report Rejected',
                body='Your reported hazard was reviewed and rejected.',
                data={
                    'type': 'report_rejected',
                    'target': 'resident_notifications',
                    'report_id': str(report.id),
                },
            )
    
    if admin_comment:
        report.admin_comment = admin_comment
    
    report.save()

    # Synchronously refresh segment risks BEFORE returning the response so
    # the very next route request sees up-to-date risk scores (zero stale window).
    _sync_recompute_segment_risks()

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
            auto_rejected=False,
            is_deleted=False,
        )
        .select_related('user')
        .order_by('-created_at')
    )
    serializer = HazardReportSerializer(qs, many=True)
    return Response(serializer.data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def report_media(request, report_id):
    """
    GET /api/my-reports/<report_id>/media/
    Returns the full photo_url and video_url (including base64 blobs) for a
    specific report owned by the requesting user. Used by the media viewer so
    large base64 payloads are only downloaded when the user explicitly opens a report.
    """
    try:
        report = HazardReport.objects.get(pk=report_id, user=request.user)
    except HazardReport.DoesNotExist:
        return Response({'error': 'Report not found or access denied'}, status=status.HTTP_404_NOT_FOUND)
    return Response({
        'id': report.id,
        'photo_url': report.photo_url or '',
        'video_url': report.video_url or '',
    })


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
    Only public, non-identifying fields are returned (PublicHazardSerializer).
    """
    qs = HazardReport.objects.filter(status=HazardReport.Status.APPROVED, is_deleted=False).select_related('user')
    serializer = PublicHazardSerializer(qs, many=True)
    return Response(serializer.data)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def check_similar_reports(request):
    """
    POST /api/check-similar-reports/
    Check for similar pending reports near a location.
    Body: {hazard_type, latitude, longitude, radius_meters}
    Returns: List of similar pending reports
    """
    hazard_type = request.data.get('hazard_type')
    latitude = request.data.get('latitude')
    longitude = request.data.get('longitude')
    radius_meters = request.data.get('radius_meters', 150)  # Default 150 m — matches auto-reject proximity limit
    
    if not all([hazard_type, latitude, longitude]):
        return Response(
            {'error': 'hazard_type, latitude, and longitude required'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    try:
        latitude = float(latitude)
        longitude = float(longitude)
        radius_meters = float(radius_meters)
    except (ValueError, TypeError):
        return Response(
            {'error': 'Invalid coordinates'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # "other" is a catch-all — it may represent any unclassified hazard.
    # Skip strict type matching and let location proximity decide instead.
    is_other_type = str(hazard_type).lower() == 'other'

    if is_other_type:
        # Match ANY nearby hazard regardless of category.
        base_qs = HazardReport.objects.filter(
            auto_rejected=False,
            is_deleted=False,
        ).exclude(user=request.user).select_related('user')
    else:
        # Normal path: strict same-type matching.
        base_qs = HazardReport.objects.filter(
            hazard_type=hazard_type,
            auto_rejected=False,
            is_deleted=False,
        ).exclude(user=request.user).select_related('user')

    # Keep UX aligned with server-side duplicate blocking: only consider reports
    # from the same recent incident window.
    from datetime import timedelta
    from django.utils import timezone
    from apps.validation.services.consensus import NEARBY_TIME_WINDOW_HOURS

    since = timezone.now() - timedelta(hours=NEARBY_TIME_WINDOW_HOURS)

    # Search both PENDING (confirmable) and APPROVED (already verified) reports.
    candidate_qs = base_qs.filter(
        status__in=[HazardReport.Status.PENDING, HazardReport.Status.APPROVED],
        created_at__gte=since,
    )

    similar_reports = []
    for report in candidate_qs:
        distance = _haversine_meters(
            latitude, longitude,
            float(report.latitude), float(report.longitude)
        )

        if distance <= radius_meters:
            report_data = SimilarReportPublicSerializer(report).data
            report_data['distance_meters'] = round(distance, 2)
            report_data['confirmation_count'] = report.confirmation_count
            report_data['has_user_confirmed'] = report.has_user_confirmed(request.user)
            # Let the client know whether this report is already verified.
            report_data['is_approved'] = (report.status == HazardReport.Status.APPROVED)
            similar_reports.append(report_data)

    # Sort: approved first (already verified carries more weight), then by confirmation count.
    similar_reports.sort(key=lambda x: (not x['is_approved'], -x['confirmation_count']))

    return Response({
        'similar_reports': similar_reports,
        'count': len(similar_reports),
        'is_other_type_search': is_other_type,
        'time_window_hours': NEARBY_TIME_WINDOW_HOURS,
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def confirm_hazard_report(request):
    """
    POST /api/confirm-hazard-report/
    Confirm an existing hazard report instead of submitting a duplicate.
    Body: {report_id}
    Returns: Updated report with confirmation count
    """
    report_id = request.data.get('report_id')
    
    if not report_id:
        return Response(
            {'error': 'report_id is required'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    try:
        report = HazardReport.objects.get(pk=report_id)
    except HazardReport.DoesNotExist:
        return Response(
            {'error': 'Report not found'},
            status=status.HTTP_404_NOT_FOUND
        )
    
    # Only allow confirming active (pending or approved) reports — not deleted/rejected ones
    if report.is_deleted or report.status == HazardReport.Status.REJECTED:
        return Response(
            {'error': 'Cannot confirm a deleted or rejected report'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Cannot confirm your own report
    if report.user == request.user:
        return Response(
            {'error': 'Cannot confirm your own report'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Add confirmation
    added = report.add_confirmation(request.user)
    
    if not added:
        return Response(
            {'error': 'You have already confirmed this report'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Recalculate validation scores with new confirmation count
    # Read count once, outside try/except so it is always defined for the
    # log and response message below even if score re-calculation fails.
    confirmation_count = report.confirmation_count

    # Only recalculate AI scores for PENDING reports. APPROVED reports have
    # already been reviewed by MDRRMO — updating their score would be meaningless.
    if report.status == HazardReport.Status.PENDING:
        try:
            from apps.validation.services.consensus import ConsensusScoringService
            from apps.validation.services.rule_scoring import consensus_rule_score, combine_validation_scores

            consensus = ConsensusScoringService()
            support = consensus.get_support_summary(
                float(report.latitude), float(report.longitude),
                HazardReport.objects.exclude(id=report.id).filter(is_deleted=False),
                exclude_report_id=report.id,
                time_window_hours=1,
                hazard_type=report.hazard_type,
            )
            nearby = support.nearby_cluster_count

            consensus_score_val = consensus_rule_score(nearby, confirmation_count)
            final_score = combine_validation_scores(
                report.naive_bayes_score or 0.5,
                report.distance_weight or 0.5,
                consensus_score_val
            )

            report.consensus_score = consensus_score_val
            report.final_validation_score = final_score

            if report.validation_breakdown:
                report.validation_breakdown['confirmation_count'] = confirmation_count
                report.validation_breakdown['nearby_count'] = nearby
                report.validation_breakdown['nearby_raw_reports'] = support.nearby_raw_reports
                report.validation_breakdown['nearby_unique_user_count'] = support.nearby_unique_user_count
                report.validation_breakdown['nearby_cluster_count'] = support.nearby_cluster_count
                report.validation_breakdown['consensus_score'] = round(consensus_score_val, 4)
                report.validation_breakdown['final_validation_score'] = round(final_score, 4)

            report.save(update_fields=['consensus_score', 'final_validation_score', 'validation_breakdown'])
        except Exception as e:
            print(f"Warning: Could not recalculate scores: {e}")
    
    # Log the confirmation
    from apps.system_logs.models import SystemLog
    SystemLog.log_action(
        action=SystemLog.Action.REPORT_SUBMITTED,
        module=SystemLog.Module.HAZARD_REPORTS,
        user=request.user,
        description=f'User confirmed hazard report #{report.id} (total confirmations: {confirmation_count})',
        related_object_type='HazardReport',
        related_object_id=report.id,
    )
    
    # Return updated report with confirmation count
    report_data = HazardReportSerializer(report).data
    report_data['confirmation_count'] = report.confirmation_count
    report_data['message'] = f'Hazard confirmation recorded successfully! {confirmation_count} users have confirmed this hazard.'
    
    return Response(report_data, status=status.HTTP_201_CREATED)


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
    restoration_reason = request.data.get('restoration_reason', '').strip() or 'Restored by MDRRMO'
    
    if not report_id:
        return Response(
            {'error': 'report_id required'},
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
    _sync_recompute_segment_risks()
    return Response(PendingReportSerializer(report).data)


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def admin_report_media(request, report_id: int):
    """
    GET /api/mdrrmo/reports/<report_id>/media/
    Returns the full photo_url and video_url (including base64) for a report.
    Only accessible by MDRRMO admins.
    """
    try:
        report = HazardReport.objects.get(pk=report_id)
    except HazardReport.DoesNotExist:
        return Response({'error': 'Report not found'}, status=status.HTTP_404_NOT_FOUND)
    return Response({
        'id': report.id,
        'photo_url': report.photo_url or '',
        'video_url': report.video_url or '',
    })


@api_view(['DELETE'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def mdrrmo_delete_report(request, report_id: int):
    """
    DELETE /api/mdrrmo/reports/<report_id>/
    Soft-deletes the report so notifications remain valid and algorithms stay clean.
    Returns 404 if already deleted.
    """
    from django.utils import timezone as tz
    try:
        report = HazardReport.objects.get(pk=report_id, is_deleted=False)
    except HazardReport.DoesNotExist:
        return Response({'error': 'Report not found'}, status=status.HTTP_404_NOT_FOUND)
    if report.status == HazardReport.Status.PENDING:
        return Response(
            {'error': 'Cannot delete pending reports. Approve or reject them first.'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    report.is_deleted = True
    report.deleted_at = tz.now()
    report.save(update_fields=['is_deleted', 'deleted_at'])
    _sync_recompute_segment_risks()
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
            auto_rejected=False,
            is_deleted=False,
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


# ── MDRRMO: User Management ──────────────────────────────────────────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def list_users(request):
    """
    GET /api/users/
    List all resident users. MDRRMO only.
    Query params: status (active/suspended), barangay, search (email/name).
    """
    from django.contrib.auth import get_user_model
    User = get_user_model()
    qs = User.objects.filter(role=User.Role.RESIDENT).order_by('-date_joined')

    status_filter = request.GET.get('status')
    if status_filter == 'suspended':
        qs = qs.filter(is_suspended=True)
    elif status_filter == 'active':
        qs = qs.filter(is_suspended=False, is_active=True)

    barangay = request.GET.get('barangay')
    if barangay:
        qs = qs.filter(barangay__icontains=barangay)

    search = request.GET.get('search')
    if search:
        qs = qs.filter(
            models.Q(email__icontains=search) |
            models.Q(full_name__icontains=search)
        )

    serializer = MdrrmoUserListSerializer(qs, many=True)
    return Response(serializer.data)


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def get_user_detail(request, user_id):
    """
    GET /api/users/<user_id>/
    Get a specific resident's details with report stats. MDRRMO only.
    """
    from django.contrib.auth import get_user_model
    User = get_user_model()
    try:
        user = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)

    report_count = HazardReport.objects.filter(user=user, auto_rejected=False).count()
    approved_count = HazardReport.objects.filter(
        user=user, status=HazardReport.Status.APPROVED
    ).count()

    data = MdrrmoUserListSerializer(user).data
    data['report_count'] = report_count
    data['approved_report_count'] = approved_count
    return Response(data)


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def suspend_user(request, user_id):
    """
    POST /api/users/<user_id>/suspend/
    Suspend a resident account. MDRRMO only.
    """
    from django.contrib.auth import get_user_model
    User = get_user_model()
    try:
        user = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)

    if user.role == User.Role.MDRRMO:
        return Response(
            {'error': 'Cannot suspend an MDRRMO account.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    user.is_suspended = True
    user.is_active = False
    user.save(update_fields=['is_suspended', 'is_active'])

    # Invalidate the existing auth token so the resident is forced out
    # immediately on their next request (DRF TokenAuth checks is_active, but
    # deleting the token provides a hard guarantee regardless of that check).
    try:
        from rest_framework.authtoken.models import Token
        Token.objects.filter(user=user).delete()
    except Exception:
        pass

    return Response(MdrrmoUserListSerializer(user).data)


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def activate_user(request, user_id):
    """
    POST /api/users/<user_id>/activate/
    Reactivate a suspended resident account. MDRRMO only.
    """
    from django.contrib.auth import get_user_model
    User = get_user_model()
    try:
        user = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)

    user.is_suspended = False
    user.is_active = True
    user.save(update_fields=['is_suspended', 'is_active'])
    return Response(MdrrmoUserListSerializer(user).data)


@api_view(['DELETE'])
@permission_classes([IsAuthenticated, IsMDRRMO])
def delete_user_admin(request, user_id):
    """
    DELETE /api/users/<user_id>/delete/
    Permanently delete a resident account. MDRRMO only.
    Cannot delete MDRRMO accounts or self.
    """
    from django.contrib.auth import get_user_model
    User = get_user_model()
    try:
        user = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)

    if user.role == User.Role.MDRRMO:
        return Response(
            {'error': 'Cannot delete an MDRRMO account.'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if user == request.user:
        return Response(
            {'error': 'You cannot delete your own account from this endpoint.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    user.delete()
    return Response({'message': 'User deleted successfully.'}, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([AllowAny])
def check_road_data(request):
    """
    GET /api/check-road-data/
    Diagnostic: returns road segment count and seeding status.
    """
    from apps.routing.models import RoadSegment
    count = RoadSegment.objects.count()
    return Response({
        'segment_count': count,
        'seeded': count > 0,
        'note': 'Routing requires segments to be seeded via the 0004_seed_road_segments migration.',
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def road_risk_layer(request):
    """
    GET /api/road-risk-layer/
    Returns all road segments with their current effective risk score for the
    Road Risk Layer overlay in the mobile app.

    Computes effective_risk = base × 0.20 (no live hazards) or
    (base × 0.30) + (dynamic × 0.70) (live hazards present) for every segment,
    then returns only segments with effective_risk > 0.05 to keep payload lean.
    """
    from apps.routing.models import RoadSegment
    from apps.mobile_sync.services.route_service import (
        calculate_segment_risk,
        _get_approved_hazards,
    )
    # Scores are pre-computed at deploy time; skip auto-train to keep this endpoint fast.
    segments = list(RoadSegment.objects.all())
    if not segments:
        return Response({'road_risk_segments': [], 'segment_count': 0})

    approved_hazards = _get_approved_hazards()
    result = []
    for seg in segments:
        risk = calculate_segment_risk(seg, approved_hazards)
        # Include ALL segments so the road network is always visible when the layer
        # is toggled on. Segments with risk=0 will appear green (safe) on the map.
        # Use a small baseline of 0.04 so roads are distinguishable from background.
        display_risk = max(risk, 0.04)
        result.append({
            's': [float(seg.start_lat), float(seg.start_lng)],
            'e': [float(seg.end_lat),   float(seg.end_lng)],
            'r': round(display_risk, 3),
        })

    return Response({
        'road_risk_segments': result,
        'segment_count': len(segments),
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_fcm_token(request):
    """
    POST /api/auth/fcm-token/
    Body: { "fcm_token": "<device FCM token>" }

    Saves or clears the caller's FCM device token.
    Called by the Flutter app on login and whenever the token refreshes.
    Sending an empty string clears the token (e.g. on logout).
    """
    token = (request.data.get('fcm_token') or '').strip()
    request.user.fcm_token = token
    request.user.save(update_fields=['fcm_token'])
    return Response({'status': 'ok'})
