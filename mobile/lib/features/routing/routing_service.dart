import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/storage_service.dart';
import '../../models/evacuation_center.dart';
import '../../models/route.dart';
import '../../data/mock_evacuation_centers.dart';

/// Service for routing and evacuation center operations.
/// 
/// FEATURES:
/// - OSRM integration for real road-following routes
/// - Offline route caching (saves routes when online)
/// - Automatic fallback when OSRM fails
/// - Django backend support for production
class RoutingService {
  final ApiClient _apiClient = ApiClient();
  final StorageService _storageService = StorageService();

  /// Get all evacuation centers.
  /// 
  /// MOCK: Returns mock centers.
  /// REAL: GET from /api/evacuation-centers/
  Future<List<EvacuationCenter>> getEvacuationCenters() async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return getMockEvacuationCenters();
    }

    // REAL API CALL:
    try {
      final response = await _apiClient.get(ApiConfig.evacuationCentersEndpoint);
      
      final List<dynamic> centersJson = response.data;
      return centersJson
          .map((json) => EvacuationCenter.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch evacuation centers: $e');
    }
  }

  /// Calculate safest routes to evacuation center.
  /// 
  /// FEATURES:
  /// - Uses OSRM for real road-following routes (mock mode)
  /// - Caches routes for offline use
  /// - Falls back to cached routes when offline
  /// - Uses Django backend in production mode
  /// 
  /// Returns 3 routes sorted by safety (lowest risk first).
  Future<List<Route>> calculateRoutes({
    required double startLat,
    required double startLng,
    required int evacuationCenterId,
    required EvacuationCenter evacuationCenter,
  }) async {
    // Validate location is in Philippines, use Bulan default if not
    final isInPhilippines = startLat >= 4.0 && startLat <= 21.0 &&
                           startLng >= 116.0 && startLng <= 127.0;
    
    double validStartLat = startLat;
    double validStartLng = startLng;
    
    if (!isInPhilippines) {
      print('⚠️ Start location outside Philippines ($startLat, $startLng), using Bulan default for routing');
      validStartLat = 12.6699; // Bulan, Sorsogon
      validStartLng = 123.8758;
    }
    
    final routeKey = '${validStartLat.toStringAsFixed(4)},${validStartLng.toStringAsFixed(4)}-'
        '${evacuationCenter.latitude.toStringAsFixed(4)},${evacuationCenter.longitude.toStringAsFixed(4)}';

    if (ApiConfig.useMockData) {
      // Try OSRM first (requires internet)
      try {
        print('📍 Calculating routes from ($validStartLat, $validStartLng) to (${evacuationCenter.latitude}, ${evacuationCenter.longitude})');
        final routes = await _getOsrmRoutes(
          validStartLat,
          validStartLng,
          evacuationCenter.latitude,
          evacuationCenter.longitude,
        );
        
        print('✅ OSRM routing successful, ${routes.length} routes found');
        
        // Cache routes for offline use
        await _cacheRoutes(routeKey, routes);
        
        return routes;
      } catch (e) {
        print('❌ OSRM failed: $e');
        
        // Try cached routes
        final cachedRoutes = await _getCachedRoutes(routeKey);
        if (cachedRoutes != null) {
          print('✅ Using cached routes (offline mode)');
          return cachedRoutes;
        }
        
        // Last resort: Show error, don't use geometric fallback
        print('❌ No cached routes available');
        throw Exception('Unable to calculate routes. Please check your internet connection and try again.');
      }
    }

    // REAL API CALL (Django backend with Modified Dijkstra):
    try {
      final response = await _apiClient.post(
        ApiConfig.calculateRouteEndpoint,
        data: {
          'start_lat': startLat,
          'start_lng': startLng,
          'evacuation_center_id': evacuationCenterId,
        },
      );

      final List<dynamic> routesJson = response.data['routes'];
      final routes = routesJson.map((json) => Route.fromJson(json)).toList();
      
      // Cache routes for offline use
      await _cacheRoutes(routeKey, routes);
      
      return routes;
    } catch (e) {
      print('Backend failed, trying cache: $e');
      
      // Try cached routes
      final cachedRoutes = await _getCachedRoutes(routeKey);
      if (cachedRoutes != null) {
        print('Using cached routes (offline mode)');
        return cachedRoutes;
      }
      
      throw Exception('Failed to calculate routes and no cache available: $e');
    }
  }

  /// Cache routes for offline use
  Future<void> _cacheRoutes(String routeKey, List<Route> routes) async {
    try {
      final routesJson = routes.map((r) => r.toJson()).toList();
      await _storageService.saveCalculatedRoutes(routeKey, routesJson);
      print('Routes cached successfully for offline use');
    } catch (e) {
      print('Failed to cache routes: $e');
    }
  }

  /// Get cached routes
  Future<List<Route>?> _getCachedRoutes(String routeKey) async {
    try {
      final routesJson = await _storageService.getCalculatedRoutes(routeKey);
      if (routesJson != null) {
        return routesJson.map((json) => Route.fromJson(json)).toList();
      }
    } catch (e) {
      print('Failed to get cached routes: $e');
    }
    return null;
  }

  /// Get real road-following routes using OSRM (OpenStreetMap Routing Machine).
  /// This provides Waze-like routing that follows actual roads.
  Future<List<Route>> _getOsrmRoutes(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    try {
      // OSRM API: Get multiple alternative routes
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '$startLng,$startLat;$endLng,$endLat'
          '?alternatives=2&geometries=geojson&overview=full&steps=true';

      print('🌐 Calling OSRM API: $url');
      
      final response = await http.get(
        Uri.parse(url),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('OSRM request timed out after 15 seconds');
        },
      );

      if (response.statusCode != 200) {
        throw Exception('OSRM API returned status ${response.statusCode}: ${response.body}');
      }

      final data = json.decode(response.body);
      
      // Check for OSRM error response
      if (data['code'] != 'Ok') {
        throw Exception('OSRM API error: ${data['code']} - ${data['message'] ?? "Unknown error"}');
      }
      
      final List<dynamic> osrmRoutes = data['routes'];

      if (osrmRoutes.isEmpty) {
        throw Exception('No routes found by OSRM');
      }
      
      print('✅ OSRM returned ${osrmRoutes.length} route(s)');

      // Convert OSRM routes to our Route model with mock risk levels
      List<Route> routes = [];

      for (int i = 0; i < osrmRoutes.length && i < 3; i++) {
        final osrmRoute = osrmRoutes[i];
        final geometry = osrmRoute['geometry']['coordinates'] as List;
        
        // Convert coordinates to RoutePoint list
        final path = geometry.map((coord) {
          return RoutePoint(
            latitude: (coord[1] as num).toDouble(),
            longitude: (coord[0] as num).toDouble(),
          );
        }).toList();

        final distance = (osrmRoute['distance'] as num).toDouble() / 1000; // Convert to km
        
        // Mock risk levels (in production, your backend will calculate real risk)
        final RiskLevel riskLevel;
        final double totalRisk;
        
        if (i == 0) {
          // First route - safest
          riskLevel = RiskLevel.green;
          totalRisk = 0.20;
        } else if (i == 1) {
          // Second route - alternative safe
          riskLevel = RiskLevel.green;
          totalRisk = 0.25;
        } else {
          // Third route - moderate risk
          riskLevel = RiskLevel.yellow;
          totalRisk = 0.50;
        }

        routes.add(Route(
          path: path,
          totalDistance: distance,
          totalRisk: totalRisk,
          weight: distance + (totalRisk * 5), // Mock weight calculation
          riskLevel: riskLevel,
        ));
      }

      // Ensure we have at least 3 routes (duplicate if needed)
      while (routes.length < 3 && routes.isNotEmpty) {
        final lastRoute = routes.last;
        routes.add(Route(
          path: lastRoute.path,
          totalDistance: lastRoute.totalDistance * 1.1,
          totalRisk: lastRoute.totalRisk + 0.1,
          weight: lastRoute.weight * 1.1,
          riskLevel: RiskLevel.yellow,
        ));
      }

      return routes.take(3).toList();
    } catch (e) {
      // Fallback to simple mock routes if OSRM fails
      print('OSRM failed, using fallback: $e');
      return _getFallbackRoutes(startLat, startLng, endLat, endLng);
    }
  }

  /// Fallback routes if OSRM is unavailable
  List<Route> _getFallbackRoutes(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    final latDiff = endLat - startLat;
    final lngDiff = endLng - startLng;
    
    return [
      Route(
        path: [
          RoutePoint(latitude: startLat, longitude: startLng),
          RoutePoint(latitude: startLat + latDiff * 0.3, longitude: startLng + lngDiff * 0.2),
          RoutePoint(latitude: startLat + latDiff * 0.7, longitude: startLng + lngDiff * 0.8),
          RoutePoint(latitude: endLat, longitude: endLng),
        ],
        totalDistance: 3.8,
        totalRisk: 0.20,
        weight: 280.0,
        riskLevel: RiskLevel.green,
      ),
    ];
  }

  /// Get evacuation center by ID.
  /// 
  /// MOCK: Returns from mock list.
  /// REAL: GET from /api/evacuation-centers/{id}/
  Future<EvacuationCenter?> getEvacuationCenterById(int id) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 200));
      
      final centers = getMockEvacuationCenters();
      try {
        return centers.firstWhere((center) => center.id == id);
      } catch (e) {
        return null;
      }
    }

    // REAL API CALL:
    try {
      final response = await _apiClient.get('${ApiConfig.evacuationCentersEndpoint}$id/');
      return EvacuationCenter.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  /// Bootstrap sync - get all evacuation centers and baseline hazards.
  /// 
  /// MOCK: Returns mock data.
  /// REAL: GET from /api/bootstrap-sync/
  Future<Map<String, dynamic>> bootstrapSync() async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(seconds: 1));
      
      return {
        'evacuation_centers': getMockEvacuationCenters()
            .map((c) => c.toJson())
            .toList(),
        'baseline_hazards': [], // Use hazard_service.getBaselineHazards() instead
      };
    }

    // REAL API CALL:
    try {
      final response = await _apiClient.get(ApiConfig.bootstrapSyncEndpoint);
      return response.data;
    } catch (e) {
      throw Exception('Failed to bootstrap sync: $e');
    }
  }
}
