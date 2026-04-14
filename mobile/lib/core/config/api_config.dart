/// API configuration for backend communication.
///
/// Exported app (APK) uses Render by default.
/// Change [renderBaseUrl] if your Render service has a different URL.


class ApiConfig {
  /// Use real backend (Render). Set to false only for offline/mock testing.
  static const bool useMockData = false;

  /// Render backend URL (no trailing slash). Replace with your actual URL if different.
  static const String renderBaseUrl = 'https://thesis-evac.onrender.com/api';

  /// Backend base URL. Exported APK and all builds use Render.
  static String get baseUrl => renderBaseUrl;
  
  /// Authentication endpoints
  static const String sendVerificationCodeEndpoint = '/auth/send-verification-code/';
  static const String loginEndpoint = '/auth/login/';
  static const String registerEndpoint = '/auth/register/';
  static const String logoutEndpoint = '/auth/logout/';
  static const String profileEndpoint = '/auth/profile/';
  static const String updateProfileEndpoint = '/auth/profile/update/';
  static const String changePasswordEndpoint = '/auth/change-password/';
  static const String deleteAccountEndpoint = '/auth/delete-account/';
  
  /// Hazard report endpoints (Residents)
  static const String reportHazardEndpoint = '/report-hazard/';
  static const String checkSimilarReportsEndpoint = '/check-similar-reports/';
  static const String confirmHazardReportEndpoint = '/confirm-hazard-report/';
  static const String myReportsEndpoint = '/my-reports/';
  static const String verifiedHazardsEndpoint = '/verified-hazards/';
  
  /// MDRRMO - Dashboard & Report management
  static const String dashboardStatsEndpoint = '/mdrrmo/dashboard-stats/';
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
  
  /// Route calculation
  static const String calculateRouteEndpoint = '/calculate-route/';
  
  /// Bootstrap sync
  static const String bootstrapSyncEndpoint = '/bootstrap-sync/';
  
  /// API timeouts. Render (and similar) free tiers cold-start slowly after idle;
  /// 30s is often too short for the first login/request.
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
