/// API configuration constants
class ApiConfig {
  // Base URL - Update this when deploying
  static const String baseUrl = 'http://10.0.2.2:8000/api'; // Android emulator
  // For physical device on same network, use: 'http://192.168.x.x:8000/api'
  // For production: 'https://your-domain.com/api'
  
  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  // Auth endpoints
  static const String login = '/auth/login/';
  static const String register = '/auth/register/';
  static const String logout = '/auth/logout/';
  static const String profile = '/auth/profile/';
  static const String updateProfile = '/auth/profile/update/';
  static const String changePassword = '/auth/change-password/';
  
  // Hazard report endpoints
  static const String submitReport = '/report-hazard/';
  static const String pendingReports = '/mdrrmo/pending-reports/';
  static const String approveReport = '/mdrrmo/approve-report/';
  static const String rejectReport = '/mdrrmo/reject-report/';
  
  // Evacuation center endpoints
  static const String evacuationCenters = '/evacuation-centers/';
  
  // Route calculation
  static const String calculateRoute = '/calculate-route/';
  
  // Bootstrap sync
  static const String bootstrapSync = '/bootstrap-sync/';
  
  /// Get full URL for endpoint
  static String getUrl(String endpoint) {
    return '$baseUrl$endpoint';
  }
}
