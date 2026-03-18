"""
Service for route calculation: load segments, run Modified Dijkstra, return 3 safest routes.
Uses base risk (Random Forest / mock) plus proximity-based risk from approved hazard reports.
Prioritizes real approved hazards; mock_training_data is fallback for base segment risk only.
"""
from decimal import Decimal

from apps.evacuation.models import EvacuationCenter
from apps.hazards.models import HazardReport
from apps.routing.models import RoadSegment
from apps.routing.services import ModifiedDijkstraService
from apps.risk_prediction.services import RoadRiskPredictor
from core.utils.geo import haversine_meters

# Risk evaluation layer (after Dijkstra): thresholds for warnings and labels
HIGH_RISK_THRESHOLD = 0.7
EXTREME_RISK_THRESHOLD = 0.9  # "Possibly Blocked" tag

# Proximity threshold: hazards within this distance (meters) of a segment add to its risk
HAZARD_PROXIMITY_METERS = 100
# For path-based check: hazards within this distance (m) of any path point count as "on route"
# 300m so hazards slightly off the straight line (e.g. curvy road) still count
PATH_HAZARD_PROXIMITY_METERS = 300
# Additional risk per nearby hazard (capped so total dynamic risk <= 1.0)
HAZARD_RISK_PER_NEARBY = 0.2
HAZARD_RISK_CAP = 1.0
# Path-based: risk added per hazard near the route path (capped)
PATH_HAZARD_RISK_PER_NEARBY = 0.3
PATH_HAZARD_RISK_CAP = 1.0
# Number of points to interpolate from start to end for geographic hazard check (so hazards in user's region count)
GEO_PATH_INTERPOLATION_POINTS = 80


def _float(x):
    if x is None:
        return 0.0
    if isinstance(x, Decimal):
        return float(x)
    return float(x)


def _distance_point_to_segment_meters(
    point_lat: float, point_lng: float,
    seg_start_lat: float, seg_start_lng: float,
    seg_end_lat: float, seg_end_lng: float,
) -> float:
    """Minimum distance in meters from point to the road segment (start, end, or midpoint)."""
    d_start = haversine_meters(point_lat, point_lng, seg_start_lat, seg_start_lng)
    d_end = haversine_meters(point_lat, point_lng, seg_end_lat, seg_end_lng)
    mid_lat = (seg_start_lat + seg_end_lat) / 2
    mid_lng = (seg_start_lng + seg_end_lng) / 2
    d_mid = haversine_meters(point_lat, point_lng, mid_lat, mid_lng)
    return min(d_start, d_end, d_mid)


def calculate_segment_risk(segment, hazards) -> float:
    """
    Effective risk for a road segment: base risk + dynamic risk from approved hazards within 100 m.
    More hazards nearby -> higher risk (capped).
    """
    base = _float(getattr(segment, 'predicted_risk_score', 0))
    risk = base
    nearby_count = 0
    seg_start_lat = _float(segment.start_lat)
    seg_start_lng = _float(segment.start_lng)
    seg_end_lat = _float(segment.end_lat)
    seg_end_lng = _float(segment.end_lng)
    for hazard in hazards:
        h_lat = _float(hazard.latitude)
        h_lng = _float(hazard.longitude)
        dist_m = _distance_point_to_segment_meters(
            h_lat, h_lng, seg_start_lat, seg_start_lng, seg_end_lat, seg_end_lng
        )
        if dist_m <= HAZARD_PROXIMITY_METERS:
            nearby_count += 1
    dynamic = min(nearby_count * HAZARD_RISK_PER_NEARBY, HAZARD_RISK_CAP)
    return risk + dynamic


def _ensure_segment_risk_scores():
    """
    If all road segments have predicted_risk_score 0, fill from Random Forest / mock training
    so routing uses risk-aware scores.
    """
    segments = list(RoadSegment.objects.all())
    if not segments:
        return
    if any(getattr(s, 'predicted_risk_score', 0) != 0 for s in segments):
        return
    predictor = RoadRiskPredictor()
    predictor.train()
    import json
    from pathlib import Path
    from django.conf import settings
    path = getattr(settings, 'MOCK_DATA_DIR', Path(__file__).resolve().parent.parent.parent.parent / 'mock_data') / 'mock_training_data.json'
    if path.exists():
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        risk_by_id = {r['segment_id']: r['risk_score'] for r in data.get('road_risk_training', [])}
        for i, seg in enumerate(segments, start=1):
            risk = risk_by_id.get(i, predictor.predict_risk(0, 0))
            seg.predicted_risk_score = risk
            seg.save(update_fields=['predicted_risk_score'])


def _get_approved_hazards():
    """Return approved hazard reports used to influence route risk (real data first)."""
    return list(HazardReport.objects.filter(status=HazardReport.Status.APPROVED))


def _geographic_path_for_hazard_check(start_lat: float, start_lng: float, end_lat: float, end_lng: float):
    """
    Build a list of points along the line from start to end (user to evacuation center).
    Used for hazard risk so verified reports in the user's area count even when the
    road graph is in a different region (e.g. mock graph in Manila, user in Bulan).
    """
    points = []
    n = max(2, GEO_PATH_INTERPOLATION_POINTS)
    for i in range(n + 1):
        t = i / n
        lat = start_lat + t * (end_lat - start_lat)
        lng = start_lng + t * (end_lng - start_lng)
        points.append([lat, lng])
    return points


def _path_based_hazard_risk(path_points, hazards) -> float:
    """
    Risk from approved hazards near the route path (not only segment endpoints).
    Ensures routes that pass near verified hazards show non-zero risk and are deprioritized.
    path_points: list of [lat, lng]
    hazards: list of HazardReport with .latitude, .longitude
    """
    if not path_points or not hazards:
        return 0.0
    # Sample path so we don't miss hazards between segment nodes; use every point
    nearby_count = 0
    seen_hazard_ids = set()
    for pt in path_points:
        if len(pt) < 2:
            continue
        pt_lat, pt_lng = _float(pt[0]), _float(pt[1])
        for h in hazards:
            h_id = getattr(h, 'id', id(h))
            if h_id in seen_hazard_ids:
                continue
            dist_m = haversine_meters(pt_lat, pt_lng, _float(h.latitude), _float(h.longitude))
            if dist_m <= PATH_HAZARD_PROXIMITY_METERS:
                seen_hazard_ids.add(h_id)
                nearby_count += 1
    return min(nearby_count * PATH_HAZARD_RISK_PER_NEARBY, PATH_HAZARD_RISK_CAP)


def _risk_level_from_total(total_risk: float) -> str:
    """Classify total_risk into Green / Yellow / Red (same as Dijkstra)."""
    if total_risk < 0.3:
        return 'Green'
    if total_risk < 0.7:
        return 'Yellow'
    return 'Red'


def _path_length_meters(path_points) -> float:
    """Sum of haversine distances between consecutive path points. Returns meters."""
    if not path_points or len(path_points) < 2:
        return 0.0
    total = 0.0
    for i in range(1, len(path_points)):
        pt0 = path_points[i - 1]
        pt1 = path_points[i]
        if len(pt0) >= 2 and len(pt1) >= 2:
            total += haversine_meters(
                _float(pt0[0]), _float(pt0[1]),
                _float(pt1[0]), _float(pt1[1]),
            )
    return total


def _hazards_along_path(path_points, hazards):
    """
    Return list of approved hazards that are within PATH_HAZARD_PROXIMITY_METERS of the path.
    Each item: {hazard_type, latitude, longitude, distance_km_from_start} for UI (e.g. "near Km 2").
    """
    if not path_points or not hazards:
        return []
    path_len_m = _path_length_meters(path_points)
    result = []
    seen_ids = set()
    for h in hazards:
        h_id = getattr(h, 'id', id(h))
        if h_id in seen_ids:
            continue
        h_lat = _float(h.latitude)
        h_lng = _float(h.longitude)
        for pt in path_points:
            if len(pt) < 2:
                continue
            dist_m = haversine_meters(_float(pt[0]), _float(pt[1]), h_lat, h_lng)
            if dist_m <= PATH_HAZARD_PROXIMITY_METERS:
                # Distance from start: approximate by first point of path
                dist_from_start_m = haversine_meters(
                    _float(path_points[0][0]), _float(path_points[0][1]),
                    h_lat, h_lng,
                )
                dist_km = dist_from_start_m / 1000.0
                result.append({
                    'hazard_type': getattr(h, 'hazard_type', 'hazard'),
                    'latitude': h_lat,
                    'longitude': h_lng,
                    'distance_km_from_start': round(dist_km, 2),
                })
                seen_ids.add(h_id)
                break
    return result


def _severity_from_hazard_type(hazard_type: str) -> str:
    """Map hazard type to display severity (High/Medium/Low) for contributing_factors."""
    high = {'storm_surge', 'bridge_damage', 'landslide', 'fallen_electric_post', 'fallen_electric_post_wires'}
    medium = {'flooded_road', 'road_blocked', 'road_damage', 'fallen_tree'}
    ht = (hazard_type or '').lower().replace(' ', '_')
    if ht in high:
        return 'High'
    if ht in medium:
        return 'Medium'
    return 'Low'


def _build_contributing_factors(hazards_along_route: list) -> list:
    """Build contributing_factors for a route from hazards_along_route (for API response)."""
    out = []
    for h in hazards_along_route or []:
        ht = h.get('hazard_type', 'hazard')
        dist_km = h.get('distance_km_from_start')
        location = f"Near Km {dist_km:.1f}" if dist_km is not None else "Along route"
        out.append({
            'hazard_type': ht.replace('_', ' ').title(),
            'severity': _severity_from_hazard_type(ht),
            'location': location,
        })
    return out


def _get_alternative_centers(start_lat: float, start_lng: float, exclude_ec_id: int, limit: int = 5):
    """
    Return list of other evacuation centers with has_safe_route and best_route_risk.
    Used when no_safe_route for the selected center. Does not recurse into alternatives.
    """
    others = list(
        EvacuationCenter.objects.filter(is_operational=True).exclude(pk=exclude_ec_id).order_by('name')[:limit]
    )
    result = []
    for ec in others:
        res = calculate_safest_routes(
            start_lat, start_lng, ec.id, k=1,
            include_alternative_centers=False,
        )
        if not res or not res.get('routes'):
            result.append({
                'center_id': ec.id,
                'center_name': ec.name,
                'has_safe_route': False,
                'best_route_risk': None,
            })
            continue
        best = res['routes'][0]
        risk = _float(best.get('total_risk'))
        result.append({
            'center_id': ec.id,
            'center_name': ec.name,
            'has_safe_route': risk < HIGH_RISK_THRESHOLD,
            'best_route_risk': round(risk, 4),
        })
    return result


def calculate_safest_routes(start_lat, start_lng, evacuation_center_id: int, k: int = 3, include_alternative_centers: bool = True):
    """
    Return list of up to k safest routes from (start_lat, start_lng) to the evacuation center.
    Each route has path, total_risk, total_distance, risk_level, risk_label, possibly_blocked, contributing_factors.
    Response includes no_safe_route, message, recommended_action, alternative_centers when applicable.
    Uses base segment risk (RF) + proximity-based risk from approved hazard reports; safety layer applied after.
    """
    try:
        ec = EvacuationCenter.objects.get(pk=evacuation_center_id)
    except EvacuationCenter.DoesNotExist:
        return None
    _ensure_segment_risk_scores()
    segments = list(RoadSegment.objects.all())
    approved_hazards = _get_approved_hazards()
    for seg in segments:
        seg.effective_risk = calculate_segment_risk(seg, approved_hazards)
    # 1–4) Up to 3 routes by reusing Dijkstra: run once → penalize used edges → run again (no new algorithm).
    dijkstra_safe = ModifiedDijkstraService(risk_multiplier=500.0)
    safest_routes = dijkstra_safe.get_safest_routes(
        segments,
        float(start_lat), float(start_lng),
        float(ec.latitude), float(ec.longitude),
        k=3,
    )
    # Optional: add shortest (distance-only) if it is a different path.
    dijkstra_short = ModifiedDijkstraService(risk_multiplier=0.0)
    shortest_routes = dijkstra_short.get_safest_routes(
        segments,
        float(start_lat), float(start_lng),
        float(ec.latitude), float(ec.longitude),
        k=1,
    )
    # 6–8) Unique routes only; do not duplicate; return only available routes.
    seen_path_keys = set()
    routes = []
    for r in safest_routes:
        key = tuple(r.get('path_keys', []))
        if key and key not in seen_path_keys:
            seen_path_keys.add(key)
            routes.append(r)
    for r in shortest_routes:
        key = tuple(r.get('path_keys', []))
        if key and key not in seen_path_keys:
            seen_path_keys.add(key)
            routes.append(r)

    start_lat_f = float(start_lat)
    start_lng_f = float(start_lng)
    end_lat_f = float(ec.latitude)
    end_lng_f = float(ec.longitude)
    geographic_path = _geographic_path_for_hazard_check(start_lat_f, start_lng_f, end_lat_f, end_lng_f)
    path_risk_from_geo = _path_based_hazard_risk(geographic_path, approved_hazards)
    hazards_along_geo = _hazards_along_path(geographic_path, approved_hazards)

    # Per-route: path risk from this path + geographic hazard risk so routes reflect hazards in user's area
    # (Geographic risk ensures we don't recommend as "safe" when verified hazards exist between user and EC)
    for r in routes:
        path = r.get('path') or []
        total_dist = r.get('total_distance') or 0.0
        if total_dist <= 0 and path:
            total_dist = _path_length_meters(path)
        if total_dist <= 0 and geographic_path:
            total_dist = _path_length_meters(geographic_path)
        r['total_distance'] = total_dist

        path_risk = _path_based_hazard_risk(path, approved_hazards)
        # Include geographic risk so hazard presence between user and EC raises risk (avoids recommending hazardous route as safe)
        path_risk = max(path_risk, path_risk_from_geo)
        total = r.get('total_risk') or 0.0
        total += path_risk
        r['total_risk'] = total
        r['risk_level'] = _risk_level_from_total(total)
        r['hazards_along_route'] = _hazards_along_path(path, approved_hazards) or hazards_along_geo

    # Safest first (lowest total_risk)
    routes.sort(key=lambda x: x.get('total_risk') or 0.0)

    # —— Risk evaluation layer (after Dijkstra): no algorithm changes, only evaluation and metadata ——
    for r in routes:
        tr = _float(r.get('total_risk'))
        r['risk_label'] = 'High Risk' if tr >= HIGH_RISK_THRESHOLD else 'Safer Route'
        r['possibly_blocked'] = tr > EXTREME_RISK_THRESHOLD
        r['contributing_factors'] = _build_contributing_factors(r.get('hazards_along_route') or [])

    high_risk_routes = [r for r in routes if _float(r.get('total_risk')) >= HIGH_RISK_THRESHOLD]
    no_safe_route = len(routes) > 0 and len(high_risk_routes) == len(routes)
    message = 'All routes are high risk' if no_safe_route else None
    recommended_action = 'Try another evacuation center or wait' if no_safe_route else None
    alternative_centers = []
    if no_safe_route and include_alternative_centers:
        alternative_centers = _get_alternative_centers(
            start_lat_f, start_lng_f, ec.id, limit=5,
        )

    return {
        'evacuation_center_id': ec.id,
        'evacuation_center_name': ec.name,
        'routes': routes,
        'no_safe_route': no_safe_route,
        'message': message,
        'recommended_action': recommended_action,
        'alternative_centers': alternative_centers,
    }
