/// API configuration for backend communication.
/// 
/// IMPORTANT: Currently in MOCK MODE.
/// Set useMockData = false when backend is ready.
class ApiConfig {
  /// Toggle between mock data and real API calls
  static const bool useMockData = true;
  
  /// Backend base URL
  /// For Android emulator, use: http://10.0.2.2:8000
  /// For physical device, use your computer's IP: http://192.168.x.x:8000
  static const String baseUrl = 'http://10.0.2.2:8000/api';
  
  /// API endpoints
  static const String evacuationCentersEndpoint = '/evacuation-centers/';
  static const String reportHazardEndpoint = '/report-hazard/';
  static const String calculateRouteEndpoint = '/calculate-route/';
  static const String bootstrapSyncEndpoint = '/bootstrap-sync/';
  static const String pendingReportsEndpoint = '/mdrrmo/pending-reports/';
  static const String approveReportEndpoint = '/mdrrmo/approve-report/';
  
  /// API timeout settings
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  /// Get full URL for an endpoint
  static String getUrl(String endpoint) {
    return '$baseUrl$endpoint';
  }
}
