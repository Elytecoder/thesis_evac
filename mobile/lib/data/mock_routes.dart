import '../models/route.dart';

/// Mock route data for testing with realistic road-following paths.
/// 
/// FUTURE: Replace with real API call to /api/calculate-route/
/// which will use real road network data and Modified Dijkstra algorithm.
List<Route> getMockRoutes(
  double startLat,
  double startLng,
  double endLat,
  double endLng,
) {
  // Calculate deltas
  final latDiff = endLat - startLat;
  final lngDiff = endLng - startLng;
  
  // Create 3 mock routes with realistic road-following paths
  return [
    // Route 1: Green (Safest - Northern Bypass)
    // Follows main roads, avoids flood zones
    Route(
      path: _generateNorthernBypassPath(startLat, startLng, endLat, endLng, latDiff, lngDiff),
      totalDistance: 3.8,
      totalRisk: 0.20,
      weight: 280.0,
      riskLevel: RiskLevel.green,
    ),
    
    // Route 2: Green (Alternative - Eastern Route)
    // Slightly longer but also safe
    Route(
      path: _generateEasternRoutePath(startLat, startLng, endLat, endLng, latDiff, lngDiff),
      totalDistance: 4.2,
      totalRisk: 0.25,
      weight: 325.0,
      riskLevel: RiskLevel.green,
    ),
    
    // Route 3: Yellow (Moderate risk - Central Avenue)
    // Shorter but passes through some risky areas
    Route(
      path: _generateCentralAvenuePath(startLat, startLng, endLat, endLng, latDiff, lngDiff),
      totalDistance: 3.5,
      totalRisk: 0.50,
      weight: 425.0,
      riskLevel: RiskLevel.yellow,
    ),
  ];
}

/// Generate Northern Bypass path (safest, follows main roads)
List<RoutePoint> _generateNorthernBypassPath(
  double startLat, double startLng, 
  double endLat, double endLng,
  double latDiff, double lngDiff,
) {
  List<RoutePoint> path = [];
  
  // Start point
  path.add(RoutePoint(latitude: startLat, longitude: startLng));
  
  // Head north first (bypass)
  path.add(RoutePoint(latitude: startLat + latDiff * 0.15, longitude: startLng + lngDiff * 0.05));
  path.add(RoutePoint(latitude: startLat + latDiff * 0.25, longitude: startLng + lngDiff * 0.10));
  
  // Turn east along main road
  path.add(RoutePoint(latitude: startLat + latDiff * 0.30, longitude: startLng + lngDiff * 0.25));
  path.add(RoutePoint(latitude: startLat + latDiff * 0.35, longitude: startLng + lngDiff * 0.40));
  
  // Continue northeast
  path.add(RoutePoint(latitude: startLat + latDiff * 0.50, longitude: startLng + lngDiff * 0.55));
  path.add(RoutePoint(latitude: startLat + latDiff * 0.65, longitude: startLng + lngDiff * 0.70));
  
  // Final approach
  path.add(RoutePoint(latitude: startLat + latDiff * 0.80, longitude: startLng + lngDiff * 0.85));
  path.add(RoutePoint(latitude: startLat + latDiff * 0.92, longitude: startLng + lngDiff * 0.95));
  
  // Destination
  path.add(RoutePoint(latitude: endLat, longitude: endLng));
  
  return path;
}

/// Generate Eastern Route path (alternative safe route)
List<RoutePoint> _generateEasternRoutePath(
  double startLat, double startLng, 
  double endLat, double endLng,
  double latDiff, double lngDiff,
) {
  List<RoutePoint> path = [];
  
  // Start point
  path.add(RoutePoint(latitude: startLat, longitude: startLng));
  
  // Head east first
  path.add(RoutePoint(latitude: startLat + latDiff * 0.08, longitude: startLng + lngDiff * 0.20));
  path.add(RoutePoint(latitude: startLat + latDiff * 0.15, longitude: startLng + lngDiff * 0.35));
  
  // Turn north along eastern road
  path.add(RoutePoint(latitude: startLat + latDiff * 0.30, longitude: startLng + lngDiff * 0.50));
  path.add(RoutePoint(latitude: startLat + latDiff * 0.45, longitude: startLng + lngDiff * 0.60));
  
  // Continue north
  path.add(RoutePoint(latitude: startLat + latDiff * 0.60, longitude: startLng + lngDiff * 0.72));
  path.add(RoutePoint(latitude: startLat + latDiff * 0.75, longitude: startLng + lngDiff * 0.83));
  
  // Final approach
  path.add(RoutePoint(latitude: startLat + latDiff * 0.88, longitude: startLng + lngDiff * 0.92));
  
  // Destination
  path.add(RoutePoint(latitude: endLat, longitude: endLng));
  
  return path;
}

/// Generate Central Avenue path (moderate risk, more direct)
List<RoutePoint> _generateCentralAvenuePath(
  double startLat, double startLng, 
  double endLat, double endLng,
  double latDiff, double lngDiff,
) {
  List<RoutePoint> path = [];
  
  // Start point
  path.add(RoutePoint(latitude: startLat, longitude: startLng));
  
  // More direct path through central area
  path.add(RoutePoint(latitude: startLat + latDiff * 0.20, longitude: startLng + lngDiff * 0.20));
  path.add(RoutePoint(latitude: startLat + latDiff * 0.35, longitude: startLng + lngDiff * 0.35));
  
  // Slight detour around obstacle
  path.add(RoutePoint(latitude: startLat + latDiff * 0.45, longitude: startLng + lngDiff * 0.42));
  path.add(RoutePoint(latitude: startLat + latDiff * 0.55, longitude: startLng + lngDiff * 0.55));
  
  // Continue direct
  path.add(RoutePoint(latitude: startLat + latDiff * 0.70, longitude: startLng + lngDiff * 0.70));
  path.add(RoutePoint(latitude: startLat + latDiff * 0.85, longitude: startLng + lngDiff * 0.85));
  
  // Destination
  path.add(RoutePoint(latitude: endLat, longitude: endLng));
  
  return path;
}
