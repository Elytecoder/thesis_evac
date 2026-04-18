import 'dart:async';
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../../models/navigation_route.dart';
import '../../models/route_segment.dart';
import '../../models/navigation_step.dart';
import '../../models/evacuation_center.dart';
import 'offline_routing_service.dart';
import 'gps_tracking_service.dart';
import '../../core/config/api_config.dart';
import 'package:dio/dio.dart';

/// Risk-Aware Routing Service
/// Manages online and offline route calculation with safety prioritization
class RiskAwareRoutingService {
  final OfflineRoutingService _offlineService = OfflineRoutingService();
  final GPSTrackingService _gpsService = GPSTrackingService();
  final Dio _dio = Dio();

  // Rerouting debounce
  DateTime? _lastRerouteTime;
  static const Duration REROUTE_COOLDOWN = Duration(seconds: 5);

  /// Calculate safest route with hybrid online/offline support
  /// 
  /// Priority:
  /// 1. Try OSRM for real road-following routes
  /// 2. Fallback to cached/offline routing
  Future<NavigationRoute> calculateSafestRoute({
    required LatLng start,
    required LatLng destination,
    required EvacuationCenter? evacuationCenter,
  }) async {
    print('🧠 Calculating safest route with risk awareness');

    // Try OSRM first for real road-based routing
    try {
      final route = await _getOsrmNavigationRoute(start, destination);
      print('✅ OSRM routing successful');
      return route;
    } catch (e) {
      print('❌ OSRM failed: $e');
      
      // Fallback to offline routing
      print('⚠️ Using offline routing fallback');
      return await _offlineService.calculateSafestRoute(
        start: start,
        destination: destination,
      );
    }
  }

  /// Get navigation route from OSRM with turn-by-turn instructions
  Future<NavigationRoute> _getOsrmNavigationRoute(
    LatLng start,
    LatLng destination,
  ) async {
    // Use actual start position (from map/navigation)

    // OSRM API: Get route with steps and geometry
    final url = 'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?alternatives=false&geometries=geojson&overview=full&steps=true';

    print('🌐 Calling OSRM: $url');

    final response = await http.get(Uri.parse(url)).timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        throw Exception('OSRM request timed out');
      },
    );

    if (response.statusCode != 200) {
      throw Exception('OSRM API error: ${response.statusCode}');
    }

    final data = json.decode(response.body);

    if (data['code'] != 'Ok') {
      throw Exception('OSRM routing failed: ${data['code']}');
    }

    final route = data['routes'][0];
    final geometry = route['geometry']['coordinates'] as List;
    final legs = route['legs'] as List;

    // Convert geometry to polyline
    final polyline = geometry
        .map((coord) => LatLng(coord[1], coord[0]))
        .toList();

    // Extract turn-by-turn steps
    final steps = <NavigationStep>[];
    int stepIndex = 0;

    for (final leg in legs) {
      for (final step in leg['steps']) {
        final maneuver = step['maneuver'];
        final maneuverType = maneuver['type'] as String;
        final modifier = maneuver['modifier'] as String?;
        
        // Map OSRM maneuver to our format
        String ourManeuver = 'straight';
        String instruction = step['name'] ?? 'Continue';

        // Normalise modifier: "slight left" → "slight-left", "sharp right" → "sharp-right", etc.
        final rawMod = (modifier ?? '').toLowerCase().trim().replaceAll(' ', '-');

        if (maneuverType == 'turn' || maneuverType == 'end of road') {
          switch (rawMod) {
            case 'sharp-left':
              ourManeuver = 'sharp-left';
              instruction = 'Turn sharp left';
              break;
            case 'left':
              ourManeuver = 'left';
              instruction = 'Turn left';
              break;
            case 'slight-left':
              ourManeuver = 'slight-left';
              instruction = 'Keep left';
              break;
            case 'slight-right':
              ourManeuver = 'slight-right';
              instruction = 'Keep right';
              break;
            case 'right':
              ourManeuver = 'right';
              instruction = 'Turn right';
              break;
            case 'sharp-right':
              ourManeuver = 'sharp-right';
              instruction = 'Turn sharp right';
              break;
            case 'uturn':
              ourManeuver = 'u-turn';
              instruction = 'Make a U-turn';
              break;
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
          } else {
            ourManeuver = 'straight';
            instruction = 'Continue at fork';
          }
        } else if (maneuverType == 'merge') {
          if (rawMod.contains('left')) {
            ourManeuver = 'slight-left';
            instruction = 'Merge left';
          } else if (rawMod.contains('right')) {
            ourManeuver = 'slight-right';
            instruction = 'Merge right';
          } else {
            ourManeuver = 'straight';
            instruction = 'Merge onto road';
          }
        } else if (maneuverType == 'on ramp' || maneuverType == 'off ramp') {
          if (rawMod.contains('left')) {
            ourManeuver = 'slight-left';
            instruction = 'Take the ramp on the left';
          } else if (rawMod.contains('right')) {
            ourManeuver = 'slight-right';
            instruction = 'Take the ramp on the right';
          } else {
            ourManeuver = 'straight';
            instruction = 'Take the ramp';
          }
        } else if (maneuverType == 'roundabout' || maneuverType == 'rotary') {
          ourManeuver = 'roundabout';
          instruction = 'Enter the roundabout';
        } else if (maneuverType == 'exit roundabout' || maneuverType == 'exit rotary') {
          ourManeuver = 'roundabout-exit';
          instruction = 'Exit the roundabout';
        } else if (maneuverType == 'arrive') {
          ourManeuver = 'arrive';
          instruction = 'Arrive at destination';
        } else if (maneuverType == 'depart') {
          ourManeuver = 'straight';
          instruction = 'Head ${rawMod.isEmpty ? "forward" : rawMod.replaceAll('-', ' ')}';
        } else if (maneuverType == 'new name' || maneuverType == 'continue' || maneuverType == 'use lane') {
          ourManeuver = 'straight';
          instruction = 'Continue straight';
        } else if (maneuverType == 'notification') {
          ourManeuver = 'straight';
          instruction = 'Continue';
        }

        // Add street name if available
        final streetName = step['name'] as String?;
        if (streetName != null && streetName.isNotEmpty && streetName != instruction) {
          instruction = '$instruction onto $streetName';
        }

        final location = maneuver['location'] as List;
        final distance = (step['distance'] ?? 0).toDouble();

        steps.add(NavigationStep(
          instruction: instruction,
          maneuver: ourManeuver,
          distanceToNext: distance,
          latitude: location[1],
          longitude: location[0],
          stepIndex: stepIndex++,
        ));
      }
    }

    // Create segments from polyline with mock risk scores
    final segments = <RouteSegment>[];
    final Distance distCalc = const Distance();

    for (int i = 0; i < polyline.length - 1; i++) {
      final segStart = polyline[i];
      final segEnd = polyline[i + 1];
      final segDist = distCalc.as(LengthUnit.Meter, segStart, segEnd);
      
      // Mock low risk for all segments (in production, get from backend)
      final riskScore = 0.1 + (i % 5) * 0.05; // 0.1 to 0.3 range
      
      segments.add(RouteSegment(
        start: segStart,
        end: segEnd,
        distance: segDist,
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
      totalRiskScore: 0.15, // Mock average risk
      overallRiskLevel: 'safe',
      estimatedTimeSeconds: totalDuration,
    );
  }

  /// Check if rerouting is allowed (debounce)
  bool canReroute() {
    if (_lastRerouteTime == null) return true;

    final timeSinceLastReroute = DateTime.now().difference(_lastRerouteTime!);
    return timeSinceLastReroute > REROUTE_COOLDOWN;
  }

  /// Mark that a reroute occurred
  void markReroute() {
    _lastRerouteTime = DateTime.now();
  }

  /// Check if user has deviated from route
  /// Returns true if user is more than 50 meters from route
  bool hasDeviatedFromRoute({
    required LatLng userLocation,
    required NavigationRoute route,
  }) {
    // Find nearest segment
    final nearestSegment = _offlineService.findNearestSegment(
      userLocation: userLocation,
      segments: route.segments,
    );

    if (nearestSegment == null) return true;

    // Calculate distance to nearest segment
    final distanceToRoute = _gpsService.calculateDistance(
      userLocation,
      nearestSegment.start,
    );

    // Deviation threshold: 50 meters
    final hasDeviated = distanceToRoute > 50;

    if (hasDeviated) {
      print('⚠️ User deviated from route: ${distanceToRoute.toStringAsFixed(0)}m from path');
    }

    return hasDeviated;
  }

  /// Check if user is on a high-risk segment
  /// Returns the high-risk segment if found, null otherwise
  RouteSegment? getCurrentHighRiskSegment({
    required LatLng userLocation,
    required NavigationRoute route,
  }) {
    // Find nearest segment
    final nearestSegment = _offlineService.findNearestSegment(
      userLocation: userLocation,
      segments: route.segments,
    );

    if (nearestSegment == null) return null;

    // Check if segment is high risk
    if (nearestSegment.isHighRisk) {
      print('🚨 User entering high-risk segment (risk: ${nearestSegment.riskScore.toStringAsFixed(2)})');
      return nearestSegment;
    }

    return null;
  }

  /// Get current navigation step based on user location
  NavigationStep? getCurrentStep({
    required LatLng userLocation,
    required NavigationRoute route,
  }) {
    if (route.steps.isEmpty) return null;

    // Find nearest step
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

  /// Calculate distance to next step
  double getDistanceToNextStep({
    required LatLng userLocation,
    required NavigationStep step,
  }) {
    final stepLocation = LatLng(step.latitude, step.longitude);
    return _gpsService.calculateDistance(userLocation, stepLocation);
  }

  /// Check if user has reached destination
  bool hasReachedDestination({
    required LatLng userLocation,
    required LatLng destination,
  }) {
    final distance = _gpsService.calculateDistance(userLocation, destination);
    
    // Arrival threshold: 30 meters
    final hasArrived = distance < 30;

    if (hasArrived) {
      print('✅ User has arrived at destination');
    }

    return hasArrived;
  }

  /// Dispose resources
  void dispose() {
    // Cleanup if needed
  }
}
