"""
Service for route calculation: load segments, run Modified Dijkstra, return 3 safest routes.

Hazard-to-road influence uses GRADUATED proximity, not a binary radius:
  - True perpendicular distance from hazard to road segment centerline.
  - Per-type influence radius: physical blockers (fallen tree, road_blocked) have
    tight radii; spreading hazards (flood, storm_surge) have wider radii.
  - Per-type decay profile: 'sharp' (quadratic) for blockers, 'gradual' (sqrt)
    for fluids, 'moderate' (linear) for everything else.
  - On-segment bonus: hazard projected onto the segment itself (not just near an
    endpoint) receives a 20 % boost.
  - Severity multiplier: final_validation_score (NB + distance + consensus) scales
    each hazard's contribution.

Effective segment risk = (base_RF × 0.6) + (dynamic × 0.4), clamped to [0, 1].
road_blocked within its tight radius forces segment risk to 1.0 (impassable).
"""
import math
from decimal import Decimal

from apps.evacuation.models import EvacuationCenter
from apps.hazards.models import HazardReport
from apps.routing.models import RoadSegment
from apps.routing.services import ModifiedDijkstraService
from apps.risk_prediction.services import RoadRiskPredictor
from apps.validation.services.rule_scoring import combine_validation_scores
from core.utils.geo import haversine_meters

# Risk evaluation layer (after Dijkstra): thresholds for warnings and labels
HIGH_RISK_THRESHOLD = 0.7
EXTREME_RISK_THRESHOLD = 0.9  # "Possibly Blocked" tag

# ── Per-type influence radius (meters from road centerline) ──────────────────
# Physical blockers have tight radii: they must be on/across the road to matter.
# Spreading hazards (flood, storm_surge) have wide radii: water fills the area.
HAZARD_INFLUENCE_RADIUS: dict = {
    'road_blocked':               25,   # must physically block the road
    'road_block':                 25,
    'fallen_tree':                15,   # trunk across the road; small lateral spread
    'road_damage':                20,   # surface damage is on the road
    'bridge_damage':              30,   # bridge is a narrow point
    'flood':                      80,   # water spreads laterally
    'flooded_road':               80,
    'storm_surge':               150,   # large-area inundation
    'landslide':                  60,   # debris field can spread uphill/downhill
    'fallen_electric_post':       20,   # post falls across road; wires trail farther
    'fallen_electric_post_wires': 45,
    'other':                      40,
}
DEFAULT_INFLUENCE_RADIUS = 50

# ── Per-type decay profile ────────────────────────────────────────────────────
# 'sharp'    → quadratic drop  (1 - t²): blockers must be ON the road
# 'moderate' → linear drop     (1 - t):  debris / damage fields
# 'gradual'  → sqrt drop       (1 - √t): fluid / spreading hazards maintain
#              impact across a wide band before fading
HAZARD_DECAY_PROFILE: dict = {
    'road_blocked':               'sharp',
    'road_block':                 'sharp',
    'fallen_tree':                'sharp',
    'road_damage':                'moderate',
    'bridge_damage':              'sharp',
    'flood':                      'gradual',
    'flooded_road':               'gradual',
    'storm_surge':                'gradual',
    'landslide':                  'moderate',
    'fallen_electric_post':       'moderate',
    'fallen_electric_post_wires': 'moderate',
    'other':                      'moderate',
}

# For path-based check: hazards within this distance (m) of any path point count as "on route"
PATH_HAZARD_PROXIMITY_METERS = 300
# Caps for dynamic risk accumulation before normalization
HAZARD_RISK_CAP = 1.0
PATH_HAZARD_RISK_CAP = 1.0
# Weights for normalized effective risk formula: (base × BASE_WEIGHT) + (dynamic × DYNAMIC_WEIGHT)
BASE_RISK_WEIGHT = 0.6
DYNAMIC_RISK_WEIGHT = 0.4
# Number of points to interpolate from start to end for geographic hazard check
GEO_PATH_INTERPOLATION_POINTS = 80

# ── Improvement 2: Hazard-type aware risk weights ──────────────────────────
# Each type contributes a different increment to dynamic risk per nearby hazard.
# road_blocked is highest because it physically blocks passage.
HAZARD_TYPE_RISK_WEIGHT: dict = {
    'flooded_road':              0.3,
    'flood':                     0.3,
    'fallen_tree':               0.2,
    'road_damage':               0.3,
    'fallen_electric_post':      0.4,
    'fallen_electric_post_wires': 0.4,
    'road_blocked':              0.7,   # also triggers full-block logic below
    'bridge_damage':             0.5,
    'storm_surge':               0.5,
    'landslide':                 0.5,
    'other':                     0.2,
}
DEFAULT_HAZARD_RISK_WEIGHT = 0.2   # fallback for unknown types

# ── Improvement 3: Road-block hazard types that force segment risk to 1.0 ──
BLOCKING_HAZARD_TYPES = {'road_blocked', 'road_block'}


def _hazard_type_weight(hazard_type: str) -> float:
    """Return type-specific risk weight for a hazard, falling back to default."""
    ht = (hazard_type or 'other').lower().replace(' ', '_')
    return HAZARD_TYPE_RISK_WEIGHT.get(ht, DEFAULT_HAZARD_RISK_WEIGHT)


def _is_blocking(hazard_type: str) -> bool:
    """Return True if the hazard type should make the segment fully impassable."""
    return (hazard_type or '').lower().replace(' ', '_') in BLOCKING_HAZARD_TYPES


def _float(x):
    if x is None:
        return 0.0
    if isinstance(x, Decimal):
        return float(x)
    return float(x)


def _hazard_routing_impact(hazard) -> float:
    """
    Scale dynamic risk contribution per approved hazard using final_validation_score
    (NB + distance + consensus rules). Legacy rows: recompute from stored parts or default.
    """
    f = getattr(hazard, 'final_validation_score', None)
    if f is not None:
        return max(0.0, min(1.0, _float(f)))
    nb = getattr(hazard, 'naive_bayes_score', None)
    dw = getattr(hazard, 'distance_weight', None)
    cs = getattr(hazard, 'consensus_score', None)
    if nb is not None or dw is not None or cs is not None:
        return combine_validation_scores(
            nb if nb is not None else 0.5,
            dw if dw is not None else 0.5,
            cs if cs is not None else 0.0,
        )
    return 0.7


def _perpendicular_distance_m(
    p_lat: float, p_lng: float,
    a_lat: float, a_lng: float,
    b_lat: float, b_lng: float,
) -> tuple:
    """
    True minimum distance (meters) from point P to line segment A–B, plus a flag
    indicating whether the closest point lies in the interior of the segment (True)
    or at one of its endpoints (False).

    Uses a flat-earth approximation centred on the segment midpoint.  Valid for
    segment lengths < ~10 km, which covers all road segments in this system.
    """
    cos_lat = math.cos(math.radians((a_lat + b_lat) / 2.0))
    M = 111_319.9  # metres per degree latitude

    # Translate everything so that A is the origin
    bx = (b_lng - a_lng) * cos_lat * M
    by = (b_lat - a_lat) * M
    px = (p_lng - a_lng) * cos_lat * M
    py = (p_lat - a_lat) * M

    ab2 = bx * bx + by * by
    if ab2 < 1e-6:
        # Degenerate segment (start == end): return distance to the point
        return math.sqrt(px * px + py * py), False

    t = (px * bx + py * by) / ab2
    on_segment = 0.0 <= t <= 1.0
    t_clamped = max(0.0, min(1.0, t))

    cx = t_clamped * bx
    cy = t_clamped * by
    dx = px - cx
    dy = py - cy
    return math.sqrt(dx * dx + dy * dy), on_segment


def _decay_factor(distance_m: float, radius_m: float, profile: str) -> float:
    """
    Graduated decay multiplier in [0, 1] based on distance and decay profile.

    sharp    → 1 − t²   quadratic: drops fast; blockers must be on/near the road
    moderate → 1 − t    linear:    steady drop; debris / surface damage
    gradual  → 1 − √t   square-root: drops slowly; fluid hazards maintain wide impact

    t = distance_m / radius_m.  Returns 0 when distance ≥ radius.
    """
    if radius_m <= 0 or distance_m >= radius_m:
        return 0.0
    t = distance_m / radius_m
    if profile == 'sharp':
        return max(0.0, 1.0 - t * t)
    if profile == 'gradual':
        return max(0.0, 1.0 - math.sqrt(t))
    # 'moderate' (default) — linear
    return max(0.0, 1.0 - t)


def _hazard_segment_impact(
    hazard,
    seg_start_lat: float, seg_start_lng: float,
    seg_end_lat: float, seg_end_lng: float,
) -> float:
    """
    Graduated impact [0, 1] of a single hazard on a road segment.

    Replaces the previous binary within-100 m check with five factors:
      1. True perpendicular distance from hazard to segment centerline.
      2. Type-specific influence radius  (tight for blockers, wide for floods).
      3. Type-specific decay profile     (sharp / moderate / gradual).
      4. On-segment bonus: when the hazard projects onto the segment interior
         (not just near an endpoint), impact is multiplied by 1.2 — the hazard
         directly flanks this road, not a neighbouring one.
      5. Severity multiplier via final_validation_score (NB + distance + consensus).

    Returns 0.0 when the hazard is beyond the effective influence radius.
    Does NOT handle road_blocked early-exit (caller does that separately).
    """
    ht = (getattr(hazard, 'hazard_type', '') or 'other').lower().replace(' ', '_')
    h_lat = _float(hazard.latitude)
    h_lng = _float(hazard.longitude)

    dist_m, on_segment = _perpendicular_distance_m(
        h_lat, h_lng,
        seg_start_lat, seg_start_lng,
        seg_end_lat, seg_end_lng,
    )

    radius  = HAZARD_INFLUENCE_RADIUS.get(ht, DEFAULT_INFLUENCE_RADIUS)
    profile = HAZARD_DECAY_PROFILE.get(ht, 'moderate')

    decay = _decay_factor(dist_m, radius, profile)
    if decay <= 0.0:
        return 0.0

    # On-segment bonus: hazard projects directly onto this road stretch
    if on_segment:
        decay = min(1.0, decay * 1.2)

    type_weight = _hazard_type_weight(ht)
    severity    = _hazard_routing_impact(hazard)
    return decay * type_weight * severity


def calculate_segment_risk(segment, hazards) -> float:
    """
    Effective risk for a road segment combining base (Random Forest) and dynamic (approved hazards).

    Formula:  effective_risk = (base × 0.6) + (dynamic × 0.4)   clamped to [0, 1]

    Dynamic risk uses GRADUATED proximity (not binary radius):
      • True perpendicular distance from each hazard to the segment centerline.
      • Per-type influence radius and decay profile (see HAZARD_INFLUENCE_RADIUS /
        HAZARD_DECAY_PROFILE).
      • On-segment bonus when the hazard projects onto the road interior.
      • Severity multiplier from final_validation_score.

    Road-blocked / road-block hazards within their tight radius (≤ 25 m of
    centerline) make the segment fully impassable (risk = 1.0) immediately.
    """
    base = min(1.0, max(0.0, _float(getattr(segment, 'predicted_risk_score', 0))))
    dynamic = 0.0
    seg_start_lat = _float(segment.start_lat)
    seg_start_lng = _float(segment.start_lng)
    seg_end_lat   = _float(segment.end_lat)
    seg_end_lng   = _float(segment.end_lng)

    for hazard in hazards:
        ht = (getattr(hazard, 'hazard_type', '') or 'other').lower().replace(' ', '_')

        # Physical road-blockers: check perpendicular distance against their tight radius.
        # If within that radius they make the segment fully impassable — skip accumulation.
        if _is_blocking(ht):
            h_lat = _float(hazard.latitude)
            h_lng = _float(hazard.longitude)
            block_dist, _ = _perpendicular_distance_m(
                h_lat, h_lng,
                seg_start_lat, seg_start_lng,
                seg_end_lat, seg_end_lng,
            )
            block_radius = HAZARD_INFLUENCE_RADIUS.get(ht, 25)
            if block_dist <= block_radius:
                return 1.0
            # Blocker is too far away — it may still contribute a graduated penalty
            # via the general impact calculation below (e.g. blocks a nearby lane).

        impact = _hazard_segment_impact(
            hazard,
            seg_start_lat, seg_start_lng,
            seg_end_lat, seg_end_lng,
        )
        dynamic += impact

    dynamic = min(dynamic, HAZARD_RISK_CAP)
    return min(1.0, (base * BASE_RISK_WEIGHT) + (dynamic * DYNAMIC_RISK_WEIGHT))


def _recency_factor(hazard) -> float:
    """
    Weight a hazard report by how recently it was approved.

    Recent hazards are more dangerous (road conditions change fast).
    Returns a multiplier in [0.2, 1.0]:
        < 6 hours  → 1.0  (very fresh — full weight)
        6-24 hours → 0.8
        1-3 days   → 0.6
        3-7 days   → 0.4
        > 7 days   → 0.2  (still counts, but low weight)
    """
    from django.utils import timezone
    created = getattr(hazard, 'created_at', None) or getattr(hazard, 'updated_at', None)
    if created is None:
        return 0.5  # unknown age → neutral
    try:
        hours = (timezone.now() - created).total_seconds() / 3600.0
    except Exception:
        return 0.5
    if hours < 6:
        return 1.0
    if hours < 24:
        return 0.8
    if hours < 72:
        return 0.6
    if hours < 168:
        return 0.4
    return 0.2


# Normalized type severity (HAZARD_TYPE_RISK_WEIGHT / max_weight 0.7)
# Used to give more dangerous hazard types a higher feature contribution
_TYPE_SEVERITY: dict = {
    'flooded_road':               0.43,
    'flood':                      0.43,
    'landslide':                  0.71,
    'fallen_tree':                0.29,
    'road_damage':                0.43,
    'fallen_electric_post':       0.57,
    'fallen_electric_post_wires': 0.57,
    'road_blocked':               1.00,
    'road_block':                 1.00,
    'bridge_damage':              0.71,
    'storm_surge':                0.71,
    'other':                      0.29,
}


def _compute_segment_rf_features(segment, approved_hazards: list) -> dict:
    """
    Compute Random Forest input features for a single road segment.

    Each nearby approved HazardReport contributes a WEIGHTED value (not a flat +1):
        contribution = recency_factor × type_severity_factor

    recency_factor: 1.0 (< 6 h) down to 0.2 (> 7 days) — recent reports matter more
    type_severity:  normalized HAZARD_TYPE_RISK_WEIGHT — serious types count more

    Result: feature values are floats in [0, N] reflecting both quantity and quality
    of nearby hazard evidence, rather than raw integer counts.

    # Using synthetic training data (temporary)
    # Replace with MDRRMO historical data when available
    """
    SEGMENT_FEATURE_RADIUS_M = 200  # hazards within 200 m of segment midpoint

    TYPE_TO_FEATURE = {
        'flooded_road':               'flooded_road_count',
        'flood':                      'flooded_road_count',
        'landslide':                  'landslide_count',
        'fallen_tree':                'fallen_tree_count',
        'road_damage':                'road_damage_count',
        'fallen_electric_post':       'fallen_electric_post_count',
        'fallen_electric_post_wires': 'fallen_electric_post_count',
        'road_blocked':               'road_blocked_count',
        'road_block':                 'road_blocked_count',
        'bridge_damage':              'bridge_damage_count',
        'storm_surge':                'storm_surge_count',
    }

    mid_lat = (_float(segment.start_lat) + _float(segment.end_lat)) / 2
    mid_lng = (_float(segment.start_lng) + _float(segment.end_lng)) / 2

    counts = {
        'flooded_road_count': 0.0,
        'landslide_count': 0.0,
        'fallen_tree_count': 0.0,
        'road_damage_count': 0.0,
        'fallen_electric_post_count': 0.0,
        'road_blocked_count': 0.0,
        'bridge_damage_count': 0.0,
        'storm_surge_count': 0.0,
    }
    severity_sum = 0.0
    incident_count = 0

    for hazard in approved_hazards:
        dist_m = haversine_meters(
            mid_lat, mid_lng,
            _float(hazard.latitude), _float(hazard.longitude),
        )
        if dist_m <= SEGMENT_FEATURE_RADIUS_M:
            incident_count += 1
            ht = (getattr(hazard, 'hazard_type', '') or '').lower().replace(' ', '_')
            feature_key = TYPE_TO_FEATURE.get(ht)
            if feature_key:
                recency  = _recency_factor(hazard)
                severity = _TYPE_SEVERITY.get(ht, 0.29)
                counts[feature_key] += recency * severity
            sev = (
                _float(getattr(hazard, 'final_validation_score', None))
                or _float(getattr(hazard, 'naive_bayes_score', None))
                or 0.5
            )
            severity_sum += sev

    counts['avg_severity'] = round(severity_sum / incident_count, 4) if incident_count > 0 else 0.0
    return counts


def recompute_all_segment_risks():
    """
    Force-recompute predicted_risk_score for every road segment using the RF model.

    Called by the update_segment_risks management command and after model retraining.
    Features per segment are derived from nearby approved HazardReports.

    # Using synthetic training data (temporary)
    # Replace with MDRRMO historical data when available
    """
    _ensure_segment_risk_scores(force=True)


def _ensure_segment_risk_scores(force: bool = False):
    """
    Fill predicted_risk_score for all road segments using Random Forest (ml_service).

    Features per segment are derived from nearby approved HazardReports.

    force=False (default): only runs when ALL segments have risk score 0 (first boot).
    force=True           : always recomputes — used by update_segment_risks command.

    # Using synthetic training data (temporary)
    # Replace with MDRRMO historical data when available
    """
    segments = list(RoadSegment.objects.all())
    if not segments:
        return
    if not force and any(getattr(s, 'predicted_risk_score', 0) != 0 for s in segments):
        return

    predictor = RoadRiskPredictor()
    approved_hazards = list(HazardReport.objects.filter(
        status=HazardReport.Status.APPROVED
    ).only('latitude', 'longitude', 'hazard_type',
           'final_validation_score', 'naive_bayes_score'))

    bulk_update = []
    for seg in segments:
        f = _compute_segment_rf_features(seg, approved_hazards)
        risk = predictor.predict_risk(
            flooded_road_count=f['flooded_road_count'],
            landslide_count=f['landslide_count'],
            fallen_tree_count=f['fallen_tree_count'],
            road_damage_count=f['road_damage_count'],
            fallen_electric_post_count=f['fallen_electric_post_count'],
            road_blocked_count=f['road_blocked_count'],
            bridge_damage_count=f['bridge_damage_count'],
            storm_surge_count=f['storm_surge_count'],
            avg_severity=f['avg_severity'],
        )
        seg.predicted_risk_score = risk
        bulk_update.append(seg)

    if bulk_update:
        RoadSegment.objects.bulk_update(bulk_update, ['predicted_risk_score'])


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
    total = 0.0
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
                # Improvement 2: use type-aware weight for path-based risk too
                type_weight = _hazard_type_weight(getattr(h, 'hazard_type', ''))
                total += type_weight * _hazard_routing_impact(h)
    return min(total, PATH_HAZARD_RISK_CAP)


def _risk_level_from_total(total_risk: float) -> str:
    """Classify total_risk into Green / Yellow / Red (matches Dijkstra classification)."""
    if total_risk < 0.3:
        return 'Green'
    if total_risk < 0.7:
        return 'Yellow'
    return 'Red'


def _route_label_from_hazard_count(hazard_count: int, total_risk: float) -> str:
    """
    Improvement 4: descriptive route label based on number of hazards along the route.
    Falls back to risk-based label when hazard count is unavailable.
    """
    if hazard_count == 0:
        return 'Safe route (no nearby hazards)'
    if hazard_count <= 2:
        return 'Moderate risk (1\u20132 hazards nearby)'
    return 'High risk (multiple hazards detected)'


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


def _build_route_explanation(hazards_along_route: list, total_risk: float) -> str:
    """
    Generate a plain-English explanation of what hazards affect this route.

    Instead of showing only a risk score or generic "Flood Risk" label, this gives
    the resident (and MDRRMO) a specific, readable summary:
        "2 flood hazards and 1 landslide detected nearby. High risk — consider an alternative."

    Used as the 'explanation' field in the route API response.
    """
    HAZARD_LABELS = {
        'flooded_road':           ('flood hazard',         'flood hazards'),
        'flood':                  ('flood hazard',         'flood hazards'),
        'landslide':              ('landslide',            'landslides'),
        'fallen_tree':            ('fallen tree',          'fallen trees'),
        'road_damage':            ('road damage',          'road damage areas'),
        'fallen_electric_post':   ('fallen electric post', 'fallen electric posts'),
        'fallen_electric_post_wires': ('fallen electric post', 'fallen electric posts'),
        'road_blocked':           ('road blockage',        'road blockages'),
        'road_block':             ('road blockage',        'road blockages'),
        'bridge_damage':          ('bridge damage',        'bridge damages'),
        'storm_surge':            ('storm surge',          'storm surges'),
        'other':                  ('unidentified hazard',  'unidentified hazards'),
    }
    # Severity order: most dangerous type listed first
    SEVERITY_ORDER = [
        'road_blocked', 'road_block', 'bridge_damage', 'storm_surge', 'landslide',
        'fallen_electric_post', 'fallen_electric_post_wires',
        'flooded_road', 'flood', 'road_damage', 'fallen_tree', 'other',
    ]

    if not hazards_along_route:
        if total_risk < 0.3:
            return 'No hazards detected along this route. This appears to be a safe path.'
        return 'Route appears safe. No verified hazards detected nearby.'

    # Count by type
    type_counts: dict = {}
    for h in hazards_along_route:
        ht = (h.get('hazard_type') or 'other').lower().replace(' ', '_')
        type_counts[ht] = type_counts.get(ht, 0) + 1

    # Build parts in severity order
    parts = []
    seen = set()
    for ht in SEVERITY_ORDER:
        if ht in type_counts and ht not in seen:
            seen.add(ht)
            count = type_counts[ht]
            singular, plural = HAZARD_LABELS.get(ht, (ht, ht + 's'))
            label = plural if count > 1 else singular
            parts.append(f'{count} {label}')

    if len(parts) == 0:
        detected = 'hazard(s) detected'
    elif len(parts) == 1:
        detected = parts[0]
    elif len(parts) == 2:
        detected = f'{parts[0]} and {parts[1]}'
    else:
        detected = ', '.join(parts[:-1]) + f', and {parts[-1]}'

    if total_risk >= EXTREME_RISK_THRESHOLD:
        return (
            f'Warning: Route may be blocked. Detected nearby: {detected}. '
            'Exercise extreme caution or choose an alternative route.'
        )
    if total_risk >= HIGH_RISK_THRESHOLD:
        return (
            f'High risk route. Detected nearby: {detected}. '
            'Consider choosing an alternative route if possible.'
        )
    return f'Detected nearby: {detected}. Proceed with caution.'


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
    if not ec.is_operational:
        return None  # Deactivated centers are never used for routing
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
        # Include geographic risk so hazard presence between user and EC raises risk
        path_risk = max(path_risk, path_risk_from_geo)
        total = r.get('total_risk') or 0.0
        total += path_risk
        r['total_risk'] = min(1.0, max(0.0, total))  # always clamped to [0, 1]
        r['risk_level'] = _risk_level_from_total(total)
        r['hazards_along_route'] = _hazards_along_path(path, approved_hazards) or hazards_along_geo

    # Safest first (lowest total_risk)
    routes.sort(key=lambda x: x.get('total_risk') or 0.0)

    # —— Risk evaluation layer (after Dijkstra): no algorithm changes, only evaluation and metadata ——
    for r in routes:
        tr = _float(r.get('total_risk'))
        hazards_on_route = r.get('hazards_along_route') or []
        hazard_count = len(hazards_on_route)
        r['risk_label'] = _route_label_from_hazard_count(hazard_count, tr)
        r['possibly_blocked'] = tr > EXTREME_RISK_THRESHOLD
        r['contributing_factors'] = _build_contributing_factors(hazards_on_route)
        r['explanation'] = _build_route_explanation(hazards_on_route, tr)

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
