import '../../core/auth/session_storage.dart';
import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';

/// Fetches MDRRMO dashboard statistics from the Django backend.
class MdrrmoDashboardService {
  final ApiClient _apiClient = ApiClient();

  Future<void> _ensureAuthToken() async {
    final token = await SessionStorage.readToken();
    if (token != null && token.isNotEmpty) {
      _apiClient.setAuthToken(token);
    }
  }

  /// GET /api/mdrrmo/dashboard-stats/
  /// Returns: total_reports, pending_reports, verified_hazards, high_risk_roads,
  /// total_evacuation_centers, non_operational_centers.
  Future<Map<String, dynamic>> getDashboardStats() async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return {
        'total_reports': 0,
        'pending_reports': 0,
        'verified_hazards': 0,
        'high_risk_roads': 0,
        'total_evacuation_centers': 0,
        'non_operational_centers': 0,
      };
    }
    await _ensureAuthToken();
    final response = await _apiClient.get(ApiConfig.dashboardStatsEndpoint);
    final data = response.data is Map ? Map<String, dynamic>.from(response.data) : <String, dynamic>{};
    // Ensure chart keys exist and convert nested maps so type is Map<String, dynamic> (not LinkedMap<dynamic, dynamic>)
    data['reports_by_barangay'] = data['reports_by_barangay'] != null && data['reports_by_barangay'] is Map
        ? Map<String, dynamic>.from(data['reports_by_barangay'] as Map)
        : <String, dynamic>{};
    data['hazard_distribution'] = data['hazard_distribution'] != null && data['hazard_distribution'] is Map
        ? Map<String, dynamic>.from(data['hazard_distribution'] as Map)
        : <String, dynamic>{};
    data['recent_activity'] = data['recent_activity'] != null && data['recent_activity'] is List
        ? List<dynamic>.from(data['recent_activity'] as List)
        : <dynamic>[];
    return data;
  }
}
