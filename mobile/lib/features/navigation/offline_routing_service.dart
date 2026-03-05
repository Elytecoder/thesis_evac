import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../../models/navigation_route.dart';
import '../../models/route_segment.dart';
import '../../models/navigation_step.dart';

/// Offline Routing Service
/// Implements Modified Dijkstra's Algorithm with risk-weighting
/// Uses cached road graph and hazard data from Hive
class OfflineRoutingService {
  // Risk weight factor (higher = prioritize safety over distance)
  static const double RISK_WEIGHT = 5000.0; // 5km equivalent penalty per 1.0 risk

  /// Calculate safest route using Modified Dijkstra
  /// 
  /// MOCK IMPLEMENTATION - In production, this would:
  /// 1. Load road graph from Hive cache
  /// 2. Load validated hazards from Hive
  /// 3. Calculate risk scores for road segments
  /// 4. Run Modified Dijkstra with risk-weighted costs
  /// 5. Generate turn-by-turn instructions
  Future<NavigationRoute> calculateSafestRoute({
    required LatLng start,
    required LatLng destination,
  }) async {
    print('🗺️ OFFLINE MODE: Calculating safest route');
    print('   From: ${start.latitude.toStringAsFixed(6)}, ${start.longitude.toStringAsFixed(6)}');
    print('   To: ${destination.latitude.toStringAsFixed(6)}, ${destination.longitude.toStringAsFixed(6)}');

    // TODO: Load from Hive cache:
    // - Road graph (nodes + edges)
    // - Validated hazards
    // - Pre-calculated risk scores
    
    // TODO: Run Modified Dijkstra:
    // cost = distance + (riskScore × RISK_WEIGHT)
    
    // MOCK: Generate sample offline route
    // In production, replace with actual algorithm
    return _generateMockOfflineRoute(start, destination);
  }

  /// Calculate risk-weighted cost for route segment
  double calculateSegmentCost({
    required double distance,
    required double riskScore,
  }) {
    // Modified Dijkstra cost formula
    return distance + (riskScore * RISK_WEIGHT);
  }

  /// Find nearest road segment to given point
  /// Used for deviation detection
  RouteSegment? findNearestSegment({
    required LatLng userLocation,
    required List<RouteSegment> segments,
  }) {
    if (segments.isEmpty) return null;

    RouteSegment? nearest;
    double minDistance = double.infinity;

    for (final segment in segments) {
      // Calculate distance to segment line
      final distToSegment = _distanceToSegment(
        userLocation,
        segment.start,
        segment.end,
      );

      if (distToSegment < minDistance) {
        minDistance = distToSegment;
        nearest = segment;
      }
    }

    return nearest;
  }

  /// Calculate distance from point to line segment
  double _distanceToSegment(LatLng point, LatLng lineStart, LatLng lineEnd) {
    final Distance distance = const Distance();
    
    // Distance from point to line start
    final distToStart = distance.as(
      LengthUnit.Meter,
      point,
      lineStart,
    );
    
    // Distance from point to line end
    final distToEnd = distance.as(
      LengthUnit.Meter,
      point,
      lineEnd,
    );
    
    // For simplicity, return minimum distance to endpoints
    // In production, calculate perpendicular distance to line
    return min(distToStart, distToEnd);
  }

  /// MOCK: Generate sample offline route
  /// Replace with actual Modified Dijkstra implementation
  Future<NavigationRoute> _generateMockOfflineRoute(
    LatLng start,
    LatLng destination,
  ) async {
    // Simulate processing time
    await Future.delayed(const Duration(milliseconds: 500));

    final Distance distance = const Distance();
    final totalDist = distance.as(LengthUnit.Meter, start, destination);

    // Generate intermediate points (simulating road network)
    final List<LatLng> polyline = _generateIntermediatePoints(start, destination, 5);

    // Create segments with mock risk scores
    final List<RouteSegment> segments = [];
    for (int i = 0; i < polyline.length - 1; i++) {
      final segStart = polyline[i];
      final segEnd = polyline[i + 1];
      final segDist = distance.as(LengthUnit.Meter, segStart, segEnd);
      
      // Mock risk score (low risk for offline safety)
      final riskScore = 0.1 + (i % 3) * 0.1; // 0.1, 0.2, 0.3 pattern
      
      segments.add(RouteSegment(
        start: segStart,
        end: segEnd,
        distance: segDist,
        riskScore: riskScore,
        riskLevel: RouteSegment.getRiskLevel(riskScore),
      ));
    }

    // Generate turn-by-turn steps
    final List<NavigationStep> steps = _generateNavigationSteps(polyline);

    // Calculate ETA (assuming 30 km/h average speed)
    final estimatedTimeSeconds = (totalDist / (30 * 1000 / 3600)).round();

    return NavigationRoute(
      polyline: polyline,
      segments: segments,
      steps: steps,
      totalDistance: totalDist,
      totalRiskScore: 0.2, // Low risk
      overallRiskLevel: 'safe',
      estimatedTimeSeconds: estimatedTimeSeconds,
    );
  }

  /// Generate intermediate points between start and end
  List<LatLng> _generateIntermediatePoints(LatLng start, LatLng end, int count) {
    final points = <LatLng>[start];
    
    for (int i = 1; i < count; i++) {
      final t = i / count;
      final lat = start.latitude + (end.latitude - start.latitude) * t;
      final lng = start.longitude + (end.longitude - start.longitude) * t;
      points.add(LatLng(lat, lng));
    }
    
    points.add(end);
    return points;
  }

  /// Generate mock navigation steps
  List<NavigationStep> _generateNavigationSteps(List<LatLng> polyline) {
    final steps = <NavigationStep>[];
    final Distance distance = const Distance();

    for (int i = 0; i < polyline.length - 1; i++) {
      final current = polyline[i];
      final next = polyline[i + 1];
      final distToNext = distance.as(LengthUnit.Meter, current, next);

      String maneuver;
      String instruction;

      if (i == 0) {
        maneuver = 'straight';
        instruction = 'Head toward destination';
      } else if (i == polyline.length - 2) {
        maneuver = 'arrive';
        instruction = 'Arrive at evacuation center';
      } else {
        // Alternate turns for realism
        maneuver = (i % 2 == 0) ? 'straight' : ((i % 3 == 0) ? 'left' : 'right');
        instruction = maneuver == 'straight' 
            ? 'Continue straight'
            : 'Turn $maneuver';
      }

      steps.add(NavigationStep(
        instruction: instruction,
        maneuver: maneuver,
        distanceToNext: distToNext,
        latitude: current.latitude,
        longitude: current.longitude,
        stepIndex: i,
      ));
    }

    return steps;
  }
}
