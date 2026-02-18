/// Local storage configuration for offline support.
class StorageConfig {
  // Hive box names
  static const String evacuationCentersBox = 'evacuation_centers';
  static const String baselineHazardsBox = 'baseline_hazards';
  static const String roadSegmentsBox = 'road_segments';
  static const String userBox = 'user';
  
  // SharedPreferences keys
  static const String authTokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
  static const String userRoleKey = 'user_role';
  static const String lastSyncTimeKey = 'last_sync_time';
}
