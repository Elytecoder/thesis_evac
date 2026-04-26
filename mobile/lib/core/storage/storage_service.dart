import 'package:flutter/foundation.dart';
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
    await Hive.openBox(StorageConfig.pendingReportsBox);
    await Hive.openBox(StorageConfig.verifiedHazardsBox);
    await Hive.openBox(StorageConfig.tripHistoryBox);
    await Hive.openBox(StorageConfig.activeRouteBox);
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
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
    await Hive.box(StorageConfig.verifiedHazardsBox).clear();
    // NOTE: pendingReportsBox is intentionally NOT cleared here — use clearPendingReports().
  }

  // --- Pending Reports Queue (offline submissions) ---

  /// Save the full list of pending reports waiting to be synced.
  Future<void> savePendingReports(List<Map<String, dynamic>> reports) async {
    final box = Hive.box(StorageConfig.pendingReportsBox);
    await box.put('queue', reports);
  }

  /// Get all pending reports in the offline queue.
  Future<List<Map<String, dynamic>>> getPendingReports() async {
    final box = Hive.box(StorageConfig.pendingReportsBox);
    final data = box.get('queue');
    if (data == null) return [];
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Remove all entries from the pending reports queue after a successful sync.
  Future<void> clearPendingReports() async {
    await Hive.box(StorageConfig.pendingReportsBox).clear();
  }

  /// Return the number of reports waiting to be synced.
  int getPendingReportsCount() {
    final box = Hive.box(StorageConfig.pendingReportsBox);
    final data = box.get('queue');
    if (data == null) return 0;
    return (data as List).length;
  }

  // --- Verified Hazards Cache ---

  /// Cache approved hazard reports from the server.
  Future<void> saveVerifiedHazards(List<Map<String, dynamic>> hazards) async {
    final box = Hive.box(StorageConfig.verifiedHazardsBox);
    await box.put('all', hazards);
    await box.put('last_updated', DateTime.now().toIso8601String());
  }

  /// Get cached verified hazard reports.
  Future<List<Map<String, dynamic>>?> getCachedVerifiedHazards() async {
    final box = Hive.box(StorageConfig.verifiedHazardsBox);
    final data = box.get('all');
    if (data == null) return null;
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

    return (routes as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // --- Active Route Cache (keeps last route visible during connectivity outage) ---

  /// Save the currently active navigation route so it survives offline gaps.
  ///
  /// [routeData] should include:
  ///   `polyline`    — List<Map> of {lat, lng} points
  ///   `destination` — Map with center name, lat, lng
  ///   `risk_level`  — String: 'green' | 'yellow' | 'red'
  static Future<void> saveActiveRoute(Map<String, dynamic> routeData) async {
    try {
      await Hive.box(StorageConfig.activeRouteBox).put('current', routeData);
    } catch (e) {
      debugPrint('[ActiveRoute] Failed to save: $e');
    }
  }

  /// Retrieve the last saved active route, or null if none.
  static Map<String, dynamic>? getActiveRoute() {
    try {
      final data = Hive.box(StorageConfig.activeRouteBox).get('current');
      if (data == null) return null;
      return Map<String, dynamic>.from(data as Map);
    } catch (_) {
      return null;
    }
  }

  /// Clear the active route (called on arrival or navigation exit).
  static Future<void> clearActiveRoute() async {
    try {
      await Hive.box(StorageConfig.activeRouteBox).delete('current');
    } catch (_) {}
  }

  // --- Trip History (completed navigation sessions) ---

  /// Save a completed navigation trip record (offline-first).
  ///
  /// [record] keys:
  ///   user_id, destination_id, destination_name, start_time (ISO8601),
  ///   arrival_time (ISO8601), duration_seconds, reroute_count.
  static Future<void> saveTripHistory(Map<String, dynamic> record) async {
    try {
      final box = Hive.box(StorageConfig.tripHistoryBox);
      final existing = List<Map<String, dynamic>>.from(
        (box.get('records') as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      existing.insert(0, record); // most-recent first
      // Keep latest 100 trips to bound storage size
      if (existing.length > 100) existing.removeRange(100, existing.length);
      await box.put('records', existing);
    } catch (e) {
      // Non-fatal: trip history loss is acceptable
      debugPrint('[TripHistory] Failed to save: $e');
    }
  }

  /// Retrieve all saved trip records (most-recent first).
  static List<Map<String, dynamic>> getTripHistory() {
    try {
      final box = Hive.box(StorageConfig.tripHistoryBox);
      final data = box.get('records') as List?;
      if (data == null) return [];
      return List<Map<String, dynamic>>.from(
        data.map((e) => Map<String, dynamic>.from(e as Map)),
      );
    } catch (_) {
      return [];
    }
  }

  /// Clear all trip history records.
  static Future<void> clearTripHistory() async {
    await Hive.box(StorageConfig.tripHistoryBox).clear();
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
