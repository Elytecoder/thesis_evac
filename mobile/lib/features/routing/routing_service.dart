import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/api_config.dart';
import '../../core/config/storage_config.dart';
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

  /// Round to 7 decimals so backend DecimalField(max_digits=10, decimal_places=7) accepts it.
  static double _roundTo7(double value) {
    const k1e7 = 10000000.0;
    return (value * k1e7).round() / k1e7;
  }

  /// Set auth token on API client so calculate-route (and other protected calls) succeed.
  Future<void> _ensureAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(StorageConfig.authTokenKey);
    if (token != null && token.isNotEmpty) {
      _apiClient.setAuthToken(token);
    }
  }

  /// Get all evacuation centers.
  /// 
  /// IMPORTANT: Only returns OPERATIONAL evacuation centers.
  /// Deactivated centers (is_operational = false) are excluded from routing.
  /// This ensures residents cannot navigate to closed/unavailable centers.
  /// 
  /// MOCK: Returns mock centers (filtered by operational status).
  /// REAL: GET from /api/evacuation-centers/?operational_only=true
  Future<List<EvacuationCenter>> getEvacuationCenters() async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      final allCenters = getMockEvacuationCenters();
      
      // FILTER: Only return operational centers for routing
      final operationalCenters = allCenters.where((center) => center.isOperational).toList();
      
      print('🏢 Loaded ${operationalCenters.length} operational centers (${allCenters.length - operationalCenters.length} deactivated)');
      
      return operationalCenters;
    }

    // REAL API CALL:
    try {
      // Backend should filter by operational status
      final response = await _apiClient.get(ApiConfig.evacuationCentersEndpoint);
      
      final raw = response.data;
      final List<dynamic> centersJson = raw is List ? List<dynamic>.from(raw) : [];
      return centersJson
          .map((json) => EvacuationCenter.fromJson(Map<String, dynamic>.from(json as Map)))
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
  /// - Uses Django backend in production mode (returns RouteCalculationResult with no_safe_route, alternatives)
  /// 
  /// Returns result with routes (3 sorted by safety), noSafeRoute, message, recommendedAction, alternativeCenters.
  Future<RouteCalculationResult> calculateRoutes({
    required double startLat,
    required double startLng,
    required int evacuationCenterId,
    required EvacuationCenter evacuationCenter,
  }) async {
    // Use the provided start location (from map GPS); no override so routing uses your real position
    final validStartLat = startLat;
    final validStartLng = startLng;
    
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
        
        return RouteCalculationResult(routes: routes);
      } catch (e) {
        print('❌ OSRM failed: $e');
        
        // Try cached routes
        final cachedRoutes = await _getCachedRoutes(routeKey);
        if (cachedRoutes != null) {
          print('✅ Using cached routes (offline mode)');
          return RouteCalculationResult(routes: cachedRoutes);
        }
        
        // Last resort: Show error, don't use geometric fallback
        print('❌ No cached routes available');
        throw Exception('Unable to calculate routes. Please check your internet connection and try again.');
      }
    }

    // REAL API CALL (Django backend with Modified Dijkstra) - requires auth
    // Backend accepts max_digits=10, decimal_places=7 — round coords to 7 decimals
    try {
      await _ensureAuthToken();
      final startLatRounded = _roundTo7(validStartLat);
      final startLngRounded = _roundTo7(validStartLng);
      final response = await _apiClient.post(
        ApiConfig.calculateRouteEndpoint,
        data: {
          'start_lat': startLatRounded,
          'start_lng': startLngRounded,
          'evacuation_center_id': evacuationCenterId,
        },
      );

      final data = response.data is Map ? Map<String, dynamic>.from(response.data as Map) : <String, dynamic>{};
      final dynamic routesRaw = data['routes'];
      final List<dynamic> routesJson = routesRaw is List ? List<dynamic>.from(routesRaw) : [];
      final routes = routesJson.map((json) => Route.fromJson(json)).toList();

      final noSafeRoute = (data['no_safe_route'] as bool?) ?? false;
      final message = data['message'] as String?;
      final recommendedAction = data['recommended_action'] as String?;
      final altRaw = data['alternative_centers'];
      final List<AlternativeCenter> alternativeCenters = altRaw is List
          ? (altRaw as List).map((e) => AlternativeCenter.fromJson(Map<String, dynamic>.from(e as Map))).toList()
          : [];
      
      // Cache routes for offline use
      await _cacheRoutes(routeKey, routes);
      
      return RouteCalculationResult(
        routes: routes,
        noSafeRoute: noSafeRoute,
        message: message,
        recommendedAction: recommendedAction,
        alternativeCenters: alternativeCenters,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Please log in to calculate routes.');
      }
      print('Backend failed, trying cache: $e');
      final cachedRoutes = await _getCachedRoutes(routeKey);
      if (cachedRoutes != null) {
        print('Using cached routes (offline mode)');
        return RouteCalculationResult(routes: cachedRoutes);
      }
      throw Exception('Failed to calculate routes and no cache available: $e');
    } catch (e) {
      print('Backend failed, trying cache: $e');
      final cachedRoutes = await _getCachedRoutes(routeKey);
      if (cachedRoutes != null) {
        print('Using cached routes (offline mode)');
        return RouteCalculationResult(routes: cachedRoutes);
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
