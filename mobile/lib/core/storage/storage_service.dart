import 'package:hive_flutter/hive_flutter.dart';
import '../config/storage_config.dart';

/// Storage service for offline caching using Hive.
/// 
/// Stores:
/// - Evacuation centers
/// - Baseline hazards
/// - Road segments
/// - User data
class StorageService {
  /// Initialize Hive storage.
  /// Call this once at app startup (in main.dart).
  static Future<void> initialize() async {
    await Hive.initFlutter();
    
    // Open boxes for offline storage
    await Hive.openBox(StorageConfig.evacuationCentersBox);
    await Hive.openBox(StorageConfig.baselineHazardsBox);
    await Hive.openBox(StorageConfig.roadSegmentsBox);
    await Hive.openBox(StorageConfig.userBox);
  }

  /// Close all boxes (cleanup).
  static Future<void> close() async {
    await Hive.close();
  }

  // --- Evacuation Centers ---

  /// Save evacuation centers to cache.
  Future<void> saveEvacuationCenters(List<Map<String, dynamic>> centers) async {
    final box = Hive.box(StorageConfig.evacuationCentersBox);
    await box.put('all', centers);
    await box.put('last_updated', DateTime.now().toIso8601String());
  }

  /// Get cached evacuation centers.
  Future<List<Map<String, dynamic>>?> getEvacuationCenters() async {
    final box = Hive.box(StorageConfig.evacuationCentersBox);
    final data = box.get('all');
    if (data == null) return null;
    return List<Map<String, dynamic>>.from(data);
  }

  // --- Baseline Hazards ---

  /// Save baseline hazards to cache.
  Future<void> saveBaselineHazards(List<Map<String, dynamic>> hazards) async {
    final box = Hive.box(StorageConfig.baselineHazardsBox);
    await box.put('all', hazards);
    await box.put('last_updated', DateTime.now().toIso8601String());
  }

  /// Get cached baseline hazards.
  Future<List<Map<String, dynamic>>?> getBaselineHazards() async {
    final box = Hive.box(StorageConfig.baselineHazardsBox);
    final data = box.get('all');
    if (data == null) return null;
    return List<Map<String, dynamic>>.from(data);
  }

  // --- Road Segments ---

  /// Save road segments to cache.
  Future<void> saveRoadSegments(List<Map<String, dynamic>> segments) async {
    final box = Hive.box(StorageConfig.roadSegmentsBox);
    await box.put('all', segments);
    await box.put('last_updated', DateTime.now().toIso8601String());
  }

  /// Get cached road segments.
  Future<List<Map<String, dynamic>>?> getRoadSegments() async {
    final box = Hive.box(StorageConfig.roadSegmentsBox);
    final data = box.get('all');
    if (data == null) return null;
    return List<Map<String, dynamic>>.from(data);
  }

  // --- User Data ---

  /// Save user data to cache.
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    final box = Hive.box(StorageConfig.userBox);
    await box.put('current_user', userData);
  }

  /// Get cached user data.
  Future<Map<String, dynamic>?> getUserData() async {
    final box = Hive.box(StorageConfig.userBox);
    return box.get('current_user');
  }

  /// Clear user data (logout).
  Future<void> clearUserData() async {
    final box = Hive.box(StorageConfig.userBox);
    await box.delete('current_user');
  }

  // --- General ---

  /// Clear all cached data.
  Future<void> clearAllCache() async {
    await Hive.box(StorageConfig.evacuationCentersBox).clear();
    await Hive.box(StorageConfig.baselineHazardsBox).clear();
    await Hive.box(StorageConfig.roadSegmentsBox).clear();
    await Hive.box(StorageConfig.userBox).clear();
  }

  /// Get last sync time for a specific box.
  Future<DateTime?> getLastSyncTime(String boxName) async {
    final box = Hive.box(boxName);
    final timestamp = box.get('last_updated');
    if (timestamp == null) return null;
    return DateTime.parse(timestamp);
  }

  // --- Route Caching (for offline support) ---

  /// Save calculated routes to cache by route key.
  /// Key format: "start_lat,start_lng-end_lat,end_lng"
  Future<void> saveCalculatedRoutes(
    String routeKey,
    List<Map<String, dynamic>> routes,
  ) async {
    final box = Hive.box(StorageConfig.roadSegmentsBox);
    await box.put('route_$routeKey', routes);
    await box.put('route_${routeKey}_cached_at', DateTime.now().toIso8601String());
  }

  /// Get cached routes by route key.
  /// Returns null if not cached or cache is expired.
  Future<List<Map<String, dynamic>>?> getCalculatedRoutes(
    String routeKey, {
    Duration maxAge = const Duration(days: 7),
  }) async {
    final box = Hive.box(StorageConfig.roadSegmentsBox);
    final routes = box.get('route_$routeKey');
    
    if (routes == null) return null;

    // Check if cache is expired
    final cachedAt = box.get('route_${routeKey}_cached_at');
    if (cachedAt != null) {
      final cacheTime = DateTime.parse(cachedAt);
      if (DateTime.now().difference(cacheTime) > maxAge) {
        return null; // Cache expired
      }
    }

    return List<Map<String, dynamic>>.from(routes);
  }

  /// Clear old route caches.
  Future<void> clearOldRouteCaches() async {
    final box = Hive.box(StorageConfig.roadSegmentsBox);
    final keys = box.keys.where((key) => key.toString().startsWith('route_')).toList();
    
    for (var key in keys) {
      await box.delete(key);
    }
  }
}
