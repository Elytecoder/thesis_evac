import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../../models/navigation_route.dart';
import '../../models/route.dart' as app_route;
import '../../models/route_segment.dart';
import '../../models/navigation_step.dart';
import '../../models/evacuation_center.dart';
import 'offline_routing_service.dart';
import 'gps_tracking_service.dart';

/// Risk-Aware Routing Service
///
/// Architecture (after consistency fix):
///   PRIMARY  — backend Modified Dijkstra polyline (via [buildFromBackendRoute])
///   TURN OPS — OSRM turn-instruction extraction (start→end, snapped to roads)
///   FALLBACK — polyline bearing analysis if OSRM is unavailable
///   LAST RES — full OSRM route if no backend route is available at all
class RiskAwareRoutingService {
  final OfflineRoutingService _offlineService = OfflineRoutingService();
  final GPSTrackingService _gpsService = GPSTrackingService();

  // Rerouting debounce
  DateTime? _lastRerouteTime;
  static const Duration REROUTE_COOLDOWN = Duration(seconds: 5);

  // ── PRIMARY: Build NavigationRoute from Django backend Route ──────────────

  /// Convert a backend [app_route.Route] (Modified Dijkstra + RF result) into a
  /// [NavigationRoute] suitable for live navigation.
  ///
  /// Polyline = backend path exactly (hazard-aware, risk-weighted).
  /// Steps    = OSRM turn instructions (best-effort); falls back to bearing
  ///            analysis of the polyline when OSRM is unavailable.
  Future<NavigationRoute> buildFromBackendRoute({
    required app_route.Route backendRoute,
    required LatLng destination,
  }) async {
    final polyline = backendRoute.path
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    // Try OSRM turn instructions (start → destination, road-snapped).
    List<NavigationStep> steps;
    try {
      steps = await _getOsrmStepsOnly(polyline.first, destination);
      print('✅ OSRM turn instructions obtained for backend route');
    } catch (e) {
      print('⚠️ OSRM steps unavailable — generating from polyline bearing: $e');
      steps = _generateStepsFromPolyline(polyline);
    }

    final segments = _buildSegmentsFromBackendRoute(backendRoute, polyline);
    final overallRiskLevel = _riskLevelString(backendRoute.riskLevel);

    // Conservative estimate: ~1.4 m/s walking pace (safe for evacuation).
    final estimatedSeconds = backendRoute.totalDistance > 0
        ? (backendRoute.totalDistance / 1.4).round()
        : 0;

    return NavigationRoute(
      polyline: polyline,
      segments: segments,
      steps: steps,
      totalDistance: backendRoute.totalDistance,
      totalRiskScore: backendRoute.totalRisk.clamp(0.0, 1.0),
      overallRiskLevel: overallRiskLevel,
      estimatedTimeSeconds: estimatedSeconds,
    );
  }

  // ── OSRM: turn instructions only (no route geometry used) ────────────────

  /// Fetch turn-by-turn steps from OSRM for start → destination.
  /// Only the instructions are used; the backend polyline is NOT replaced.
  Future<List<NavigationStep>> _getOsrmStepsOnly(
    LatLng start,
    LatLng destination,
  ) async {
    final url = 'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?alternatives=false&geometries=geojson&overview=false&steps=true';

    final response = await http.get(Uri.parse(url)).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('OSRM request timed out'),
    );

    if (response.statusCode != 200) {
      throw Exception('OSRM API error: ${response.statusCode}');
    }
    final data = json.decode(response.body) as Map<String, dynamic>;
    if (data['code'] != 'Ok') {
      throw Exception('OSRM routing failed: ${data['code']}');
    }

    final routesList = data['routes'] as List?;
    if (routesList == null || routesList.isEmpty) {
      throw Exception('OSRM returned no routes');
    }
    final route = routesList[0];
    final legs = route['legs'] as List;
    return _parseOsrmLegsToSteps(legs);
  }

  /// Parse OSRM legs into [NavigationStep] list (shared by both code paths).
  List<NavigationStep> _parseOsrmLegsToSteps(List<dynamic> legs) {
    final steps = <NavigationStep>[];
    int idx = 0;

    for (final leg in legs) {
      for (final step in leg['steps']) {
        final maneuver = step['maneuver'] as Map<String, dynamic>;
        final maneuverType = maneuver['type'] as String;
        final modifier = maneuver['modifier'] as String?;
        final rawMod = (modifier ?? '').toLowerCase().trim().replaceAll(' ', '-');

        String ourManeuver = 'straight';
        String instruction = step['name'] as String? ?? 'Continue';

        if (maneuverType == 'turn' || maneuverType == 'end of road') {
          switch (rawMod) {
            case 'sharp-left':
              ourManeuver = 'sharp-left';
              instruction = 'Turn sharp left';
            case 'left':
              ourManeuver = 'left';
              instruction = 'Turn left';
            case 'slight-left':
              ourManeuver = 'slight-left';
              instruction = 'Keep left';
            case 'slight-right':
              ourManeuver = 'slight-right';
              instruction = 'Keep right';
            case 'right':
              ourManeuver = 'right';
              instruction = 'Turn right';
            case 'sharp-right':
              ourManeuver = 'sharp-right';
              instruction = 'Turn sharp right';
            case 'uturn':
              ourManeuver = 'u-turn';
              instruction = 'Make a U-turn';
            default:
              ourManeuver = 'straight';
              instruction = 'Continue straight';
          }
        } else if (maneuverType == 'fork') {
          if (rawMod.contains('left')) {
            ourManeuver = 'fork-left';
            instruction = 'Keep left at fork';
          } else if (rawMod.contains('right')) {
            ourManeuver = 'fork-right';
            instruction = 'Keep right at fork';
          }
        } else if (maneuverType == 'merge') {
          if (rawMod.contains('left')) {
            ourManeuver = 'slight-left';
            instruction = 'Merge left';
          } else if (rawMod.contains('right')) {
            ourManeuver = 'slight-right';
            instruction = 'Merge right';
          }
        } else if (maneuverType == 'on ramp' || maneuverType == 'off ramp') {
          ourManeuver = rawMod.contains('left') ? 'slight-left' : 'slight-right';
          instruction = 'Take the ramp';
        } else if (maneuverType == 'roundabout' || maneuverType == 'rotary') {
          ourManeuver = 'roundabout';
          instruction = 'Enter the roundabout';
        } else if (maneuverType == 'exit roundabout' ||
            maneuverType == 'exit rotary') {
          ourManeuver = 'roundabout-exit';
          instruction = 'Exit the roundabout';
        } else if (maneuverType == 'arrive') {
          ourManeuver = 'arrive';
          instruction = 'Arrive at destination';
        } else if (maneuverType == 'depart') {
          ourManeuver = 'straight';
          instruction =
              'Head ${rawMod.isEmpty ? "forward" : rawMod.replaceAll('-', ' ')}';
        } else if (maneuverType == 'new name' ||
            maneuverType == 'continue' ||
            maneuverType == 'use lane' ||
            maneuverType == 'notification') {
          ourManeuver = 'straight';
          instruction = 'Continue straight';
        }

        final streetName = step['name'] as String?;
        if (streetName != null &&
            streetName.isNotEmpty &&
            streetName != instruction) {
          instruction = '$instruction onto $streetName';
        }

        final loc = maneuver['location'] as List;
        final distance = (step['distance'] ?? 0).toDouble();

        steps.add(NavigationStep(
          instruction: instruction,
          maneuver: ourManeuver,
          distanceToNext: distance,
          latitude: (loc[1] as num).toDouble(),
          longitude: (loc[0] as num).toDouble(),
          stepIndex: idx++,
        ));
      }
    }
    return steps;
  }

  // ── Polyline-based step generation (OSRM fallback) ────────────────────────

  /// Generate simplified turn instructions by analysing bearing changes in
  /// [polyline]. Used when OSRM is unavailable.
  List<NavigationStep> _generateStepsFromPolyline(List<LatLng> polyline) {
    if (polyline.length < 2) {
      return [
        NavigationStep(
          instruction: 'Head towards evacuation center',
          maneuver: 'straight',
          distanceToNext: 0,
          latitude: polyline.isEmpty ? 0 : polyline.first.latitude,
          longitude: polyline.isEmpty ? 0 : polyline.first.longitude,
          stepIndex: 0,
        ),
      ];
    }

    final steps = <NavigationStep>[];

    steps.add(NavigationStep(
      instruction: 'Head towards evacuation center',
      maneuver: 'straight',
      distanceToNext: 0,
      latitude: polyline.first.latitude,
      longitude: polyline.first.longitude,
      stepIndex: 0,
    ));

    double prevBearing = _getBearing(polyline[0], polyline[1]);

    for (int i = 1; i < polyline.length - 1; i++) {
      final currBearing = _getBearing(polyline[i], polyline[i + 1]);
      final diff = _bearingDiff(prevBearing, currBearing);

      if (diff.abs() >= 25) {
        final String maneuver;
        final String instruction;

        if (diff <= -120) {
          maneuver = 'sharp-left';
          instruction = 'Turn sharp left';
        } else if (diff <= -25) {
          maneuver = 'left';
          instruction = 'Turn left';
        } else if (diff >= 120) {
          maneuver = 'sharp-right';
          instruction = 'Turn sharp right';
        } else {
          maneuver = 'right';
          instruction = 'Turn right';
        }

        steps.add(NavigationStep(
          instruction: instruction,
          maneuver: maneuver,
          distanceToNext: 0,
          latitude: polyline[i].latitude,
          longitude: polyline[i].longitude,
          stepIndex: steps.length,
        ));

        prevBearing = currBearing;
      }
    }

    steps.add(NavigationStep(
      instruction: 'Arrive at evacuation center',
      maneuver: 'arrive',
      distanceToNext: 0,
      latitude: polyline.last.latitude,
      longitude: polyline.last.longitude,
      stepIndex: steps.length,
    ));

    return steps;
  }

  double _getBearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLng = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  double _bearingDiff(double a, double b) {
    double diff = b - a;
    while (diff > 180) {
      diff -= 360;
    }
    while (diff < -180) {
      diff += 360;
    }
    return diff;
  }

  // ── Segment / risk helpers ────────────────────────────────────────────────

  /// Build [RouteSegment] list from a backend route's polyline using the
  /// backend's overall risk score for all segments.
  List<RouteSegment> _buildSegmentsFromBackendRoute(
    app_route.Route backendRoute,
    List<LatLng> polyline,
  ) {
    if (polyline.length < 2) return [];

    final segments = <RouteSegment>[];
    final distCalc = const Distance();
    final riskScore = backendRoute.totalRisk.clamp(0.0, 1.0);

    for (int i = 0; i < polyline.length - 1; i++) {
      final segDist =
          distCalc.as(LengthUnit.Meter, polyline[i], polyline[i + 1]);
      segments.add(RouteSegment(
        start: polyline[i],
        end: polyline[i + 1],
        distance: segDist,
        riskScore: riskScore,
        riskLevel: RouteSegment.getRiskLevel(riskScore),
      ));
    }
    return segments;
  }

  String _riskLevelString(app_route.RiskLevel level) {
    switch (level) {
      case app_route.RiskLevel.green:
        return 'safe';
      case app_route.RiskLevel.yellow:
        return 'moderate';
      case app_route.RiskLevel.red:
        return 'high';
    }
  }

  // ── OSRM full-route fallback (used when NO backend route is available) ────

  /// Full OSRM route (geometry + steps). Used only as last-resort fallback
  /// when the backend Modified Dijkstra route is unavailable.
  Future<NavigationRoute> calculateSafestRoute({
    required LatLng start,
    required LatLng destination,
    required EvacuationCenter? evacuationCenter,
  }) async {
    print('⚠️ No backend route — falling back to OSRM full route');
    try {
      return await _getOsrmFullRoute(start, destination);
    } catch (e) {
      print('❌ OSRM failed: $e — using offline routing');
      return await _offlineService.calculateSafestRoute(
        start: start,
        destination: destination,
      );
    }
  }

  Future<NavigationRoute> _getOsrmFullRoute(
    LatLng start,
    LatLng destination,
  ) async {
    final url = 'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?alternatives=false&geometries=geojson&overview=full&steps=true';

    print('🌐 OSRM fallback route: $url');

    final response = await http.get(Uri.parse(url)).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('OSRM request timed out'),
    );

    if (response.statusCode != 200) {
      throw Exception('OSRM API error: ${response.statusCode}');
    }
    final data = json.decode(response.body) as Map<String, dynamic>;
    if (data['code'] != 'Ok') {
      throw Exception('OSRM routing failed: ${data['code']}');
    }

    final route = (data['routes'] as List)[0];
    final geometry = route['geometry']['coordinates'] as List;
    final legs = route['legs'] as List;

    final polyline = geometry
        .map((coord) => LatLng(
              (coord[1] as num).toDouble(),
              (coord[0] as num).toDouble(),
            ))
        .toList();

    final steps = _parseOsrmLegsToSteps(legs);

    final segments = <RouteSegment>[];
    final distCalc = const Distance();
    for (int i = 0; i < polyline.length - 1; i++) {
      final d = distCalc.as(LengthUnit.Meter, polyline[i], polyline[i + 1]);
      const riskScore = 0.15; // OSRM provides no risk data
      segments.add(RouteSegment(
        start: polyline[i],
        end: polyline[i + 1],
        distance: d,
        riskScore: riskScore,
        riskLevel: RouteSegment.getRiskLevel(riskScore),
      ));
    }

    final totalDistance = (route['distance'] ?? 0).toDouble();
    final totalDuration = (route['duration'] ?? 0).toDouble().toInt();

    return NavigationRoute(
      polyline: polyline,
      segments: segments,
      steps: steps,
      totalDistance: totalDistance,
      totalRiskScore: 0.15,
      overallRiskLevel: 'safe',
      estimatedTimeSeconds: totalDuration,
    );
  }

  // ── Navigation helpers ────────────────────────────────────────────────────

  bool canReroute() {
    if (_lastRerouteTime == null) return true;
    return DateTime.now().difference(_lastRerouteTime!) > REROUTE_COOLDOWN;
  }

  void markReroute() {
    _lastRerouteTime = DateTime.now();
  }

  /// Returns true if [userLocation] is more than [deviationThresholdM] metres
  /// from the nearest route **segment** (perpendicular distance, not point distance).
  ///
  /// Using perpendicular-to-segment distance prevents false deviation triggers
  /// at corners and sparse polylines.
  bool hasDeviatedFromRoute({
    required LatLng userLocation,
    required NavigationRoute route,
  }) {
    if (route.polyline.isEmpty) return false;

    const deviationThresholdM = 40.0; // tighter than point-based 100 m
    double minDistance = double.infinity;

    final pts = route.polyline;
    for (int i = 0; i < pts.length - 1; i++) {
      final d = _perpendicularDistanceToSegmentM(userLocation, pts[i], pts[i + 1]);
      if (d < minDistance) minDistance = d;
    }
    // Also check the last vertex itself (handles single-point polylines gracefully)
    final lastD = _gpsService.calculateDistance(userLocation, pts.last);
    if (lastD < minDistance) minDistance = lastD;

    final hasDeviated = minDistance > deviationThresholdM;
    if (hasDeviated) {
      print(
          '⚠️ User deviated from route: ${minDistance.toStringAsFixed(0)}m from path');
    }
    return hasDeviated;
  }

  RouteSegment? getCurrentHighRiskSegment({
    required LatLng userLocation,
    required NavigationRoute route,
  }) {
    final nearestSegment = _offlineService.findNearestSegment(
      userLocation: userLocation,
      segments: route.segments,
    );
    if (nearestSegment == null) return null;
    if (nearestSegment.isHighRisk) {
      print(
          '🚨 High-risk segment (risk: ${nearestSegment.riskScore.toStringAsFixed(2)})');
      return nearestSegment;
    }
    return null;
  }

  NavigationStep? getCurrentStep({
    required LatLng userLocation,
    required NavigationRoute route,
  }) {
    if (route.steps.isEmpty) return null;

    NavigationStep? nearest;
    double minDistance = double.infinity;

    for (final step in route.steps) {
      final stepLocation = LatLng(step.latitude, step.longitude);
      final distance = _gpsService.calculateDistance(userLocation, stepLocation);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = step;
      }
    }
    return nearest;
  }

  double getDistanceToNextStep({
    required LatLng userLocation,
    required NavigationStep step,
  }) {
    return _gpsService.calculateDistance(
        userLocation, LatLng(step.latitude, step.longitude));
  }

  bool hasReachedDestination({
    required LatLng userLocation,
    required LatLng destination,
  }) {
    final distance = _gpsService.calculateDistance(userLocation, destination);
    final hasArrived = distance < 30;
    if (hasArrived) print('✅ Arrived at destination');
    return hasArrived;
  }

  /// Perpendicular distance (metres) from [point] to the line segment
  /// [segStart]→[segEnd].  Uses a flat-Earth approximation in degrees scaled
  /// to metres — accurate to ≪1 % for segments shorter than a few kilometres.
  double _perpendicularDistanceToSegmentM(
      LatLng point, LatLng segStart, LatLng segEnd) {
    // Scale factor: 1° lat ≈ 111_320 m; 1° lng ≈ 111_320 × cos(lat) m
    const metersPerDeg = 111320.0;
    final cosLat = math.cos(point.latitude * math.pi / 180.0);

    final px = (point.longitude - segStart.longitude) * metersPerDeg * cosLat;
    final py = (point.latitude - segStart.latitude) * metersPerDeg;

    final dx = (segEnd.longitude - segStart.longitude) * metersPerDeg * cosLat;
    final dy = (segEnd.latitude - segStart.latitude) * metersPerDeg;

    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0) {
      // Degenerate segment (start == end) — return point-to-point distance
      return _gpsService.calculateDistance(point, segStart);
    }

    // Parameter t ∈ [0, 1] of the nearest point on the segment
    final t = ((px * dx + py * dy) / lenSq).clamp(0.0, 1.0);

    final nearestX = t * dx - px;
    final nearestY = t * dy - py;
    return math.sqrt(nearestX * nearestX + nearestY * nearestY);
  }

  void dispose() {}
}
