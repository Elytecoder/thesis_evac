/// API configuration for backend communication.
///
/// Two environments:
///   - LOCAL  : Django dev server on your machine (http://10.0.2.2:8000/api on Android emulator,
///              http://127.0.0.1:8000/api on web / iOS simulator).
///              Uses the local db.sqlite3 file. Start with: `python manage.py runserver`.
///   - RENDER : Live deployment at thesis-evac.onrender.com.
///              Uses Render's own SQLite (separate from local db). Cold-start can take ~30 s.
///
/// To switch environments, change [_useLocalBackend] below.
/// IMPORTANT: Set [_useLocalBackend] = false before building a release APK.

class ApiConfig {
  /// Set to true to point the app at the LOCAL Django dev server.
  /// Set to false (default) to use the Render deployment.
  static const bool _useLocalBackend = false;

  /// Use real backend. Set to false only for offline/mock testing.
  static const bool useMockData = false;

  /// Render backend URL (no trailing slash).
  static const String renderBaseUrl = 'https://thesis-evac.onrender.com/api';

  /// Local dev server URL.
  /// Android emulator: use 10.0.2.2 (maps to host machine's localhost).
  /// Physical device: replace with your machine's LAN IP, e.g. 192.168.1.x:8000.
  /// Web / iOS simulator: 127.0.0.1 works directly.
  static const String localBaseUrl = 'http://10.0.2.2:8000/api';

  /// Active backend URL.
  static String get baseUrl => _useLocalBackend ? localBaseUrl : renderBaseUrl;
  
  /// Authentication endpoints
  static const String sendVerificationCodeEndpoint = '/auth/send-verification-code/';
  static const String loginEndpoint = '/auth/login/';
  static const String registerEndpoint = '/auth/register/';
  static const String logoutEndpoint = '/auth/logout/';
  static const String profileEndpoint = '/auth/profile/';
  static const String updateProfileEndpoint = '/auth/profile/update/';
  static const String changePasswordEndpoint = '/auth/change-password/';
  static const String deleteAccountEndpoint = '/auth/delete-account/';
  static const String forgotPasswordEndpoint = '/auth/forgot-password/';
  static const String verifyResetCodeEndpoint = '/auth/verify-reset-code/';
  static const String resetPasswordEndpoint = '/auth/reset-password/';
  
  /// Hazard report endpoints (Residents)
  static const String reportHazardEndpoint = '/report-hazard/';
  static const String checkSimilarReportsEndpoint = '/check-similar-reports/';
  static const String confirmHazardReportEndpoint = '/confirm-hazard-report/';
  static const String myReportsEndpoint = '/my-reports/';
  static const String verifiedHazardsEndpoint = '/verified-hazards/';
  
  /// MDRRMO - Analytics
  static const String dashboardStatsEndpoint = '/mdrrmo/dashboard-stats/';
  static const String analyticsEndpoint = '/mdrrmo/analytics/';
  static const String pendingReportsEndpoint = '/mdrrmo/pending-reports/';
  static const String rejectedReportsEndpoint = '/mdrrmo/rejected-reports/';
  static const String approveReportEndpoint = '/mdrrmo/approve-report/';
  static const String restoreReportEndpoint = '/mdrrmo/restore-report/';
  static const String mdrrmoDeleteReportEndpoint = '/mdrrmo/reports/';
  
  /// Evacuation center endpoints
  static const String evacuationCentersEndpoint = '/evacuation-centers/';
  
  /// MDRRMO - Evacuation center management (CRUD)
  static const String createEvacuationCenterEndpoint = '/mdrrmo/evacuation-centers/';
  
  /// MDRRMO - User management (all registered users; DB-backed)
  static const String listUsersEndpoint = '/users/';
  /// Legacy path (same handler as [listUsersEndpoint]) if older deploy has no `/users/`.
  static const String mdrrmoUsersListEndpoint = '/mdrrmo/users/';
  
  /// MDRRMO - System logs
  static const String systemLogsEndpoint = '/mdrrmo/system-logs/';
  static const String clearSystemLogsEndpoint = '/mdrrmo/system-logs/clear/';
  
  /// Notifications
  static const String notificationsEndpoint = '/notifications/';
  static const String unreadCountEndpoint = '/notifications/unread-count/';
  static const String markAllReadEndpoint = '/notifications/mark-all-read/';

  /// FCM push notification device token registration
  static const String fcmTokenEndpoint = '/auth/fcm-token/';
  
  /// Route calculation
  static const String calculateRouteEndpoint = '/calculate-route/';
  static const String roadRiskLayerEndpoint  = '/road-risk-layer/';
  
  /// Bootstrap sync
  static const String bootstrapSyncEndpoint = '/bootstrap-sync/';
  
  /// API timeouts.
  /// Render free-tier cold-starts slowly after idle; 120 s is required for the first request.
  /// Local dev server responds in milliseconds so 120 s is just a safe upper bound.
  static const Duration connectTimeout = Duration(seconds: 120);
  static const Duration receiveTimeout = Duration(seconds: 120);
  
  /// Get full URL for an endpoint
  static String getUrl(String endpoint) {
    return '$baseUrl$endpoint';
  }
  
  /// Helper to build URL with ID parameter
  static String getUrlWithId(String endpoint, int id) {
    return '$baseUrl$endpoint$id/';
  }
}
