import '../../core/auth/session_storage.dart';
import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../models/system_log.dart';

/// Service for system logs (MDRRMO only).
class SystemLogService {
  final ApiClient _apiClient = ApiClient();

  Future<void> _ensureAuthToken() async {
    final token = await SessionStorage.readToken();
    if (token != null && token.isNotEmpty) {
      _apiClient.setAuthToken(token);
    }
  }

  /// Get system logs with optional filters.
  /// 
  /// Query params: user_role, module, action, status, search, limit, offset
  /// REAL: GET /api/mdrrmo/system-logs/
  Future<Map<String, dynamic>> listSystemLogs({
    String? userRole,
    String? module,
    String? action,
    String? status,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    await _ensureAuthToken();
    try {
      final params = <String, dynamic>{
        'limit': limit,
        'offset': offset,
      };
      if (userRole != null) params['user_role'] = userRole;
      if (module != null) params['module'] = module;
      if (action != null) params['action'] = action;
      if (status != null) params['status'] = status;
      if (search != null) params['search'] = search;
      
      final response = await _apiClient.get(
        ApiConfig.systemLogsEndpoint,
        params: params,
      );
      
      final count = response.data['count'] as int;
      final List<dynamic> logsJson = response.data['results'];
      final logs = logsJson.map((json) => SystemLog.fromJson(json)).toList();
      
      return {
        'count': count,
        'results': logs,
      };
    } catch (e) {
      throw Exception('Failed to fetch system logs: $e');
    }
  }

  /// Clear all system logs (dangerous operation, MDRRMO only).
  /// 
  /// REAL: POST /api/mdrrmo/system-logs/clear/
  Future<String> clearSystemLogs() async {
    await _ensureAuthToken();
    try {
      final response = await _apiClient.post(
        ApiConfig.clearSystemLogsEndpoint,
      );
      
      return response.data['message'] as String;
    } catch (e) {
      throw Exception('Failed to clear system logs: $e');
    }
  }
}
