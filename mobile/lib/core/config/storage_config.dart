/// Local storage configuration for offline support.
class StorageConfig {
  // Hive box names
  static const String evacuationCentersBox = 'evacuation_centers';
  static const String baselineHazardsBox = 'baseline_hazards';
  static const String roadSegmentsBox = 'road_segments';
  static const String userBox = 'user';

  /// Separate queue box for reports submitted while offline (pending sync).
  static const String pendingReportsBox = 'pending_reports';

  /// Cache of approved/verified hazards fetched from the server.
  static const String verifiedHazardsBox = 'verified_hazards';
  
  // SharedPreferences keys
  /// Legacy plain-text token (migrated to secure storage on read).
  static const String authTokenKey = 'auth_token';
  static const String authTokenSecureKey = 'auth_token_secure';
  static const String keepLoggedInKey = 'keep_logged_in';
  static const String loginTimestampKey = 'login_timestamp_ms';
  static const String userIdKey = 'user_id';
  static const String userRoleKey = 'user_role';
  static const String lastSyncTimeKey = 'last_sync_time';
  /// Resident: spoken turn-by-turn during live navigation (requires internet when enabled).
  static const String enableVoiceNavigationKey = 'enable_voice_navigation';
}
