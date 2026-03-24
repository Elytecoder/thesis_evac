import '../../core/auth/session_storage.dart';
import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../models/user.dart';

/// Service for user management operations (MDRRMO only).
class UserManagementService {
  final ApiClient _apiClient = ApiClient();

  Future<void> _ensureAuthToken() async {
    final token = await SessionStorage.readToken();
    if (token != null && token.isNotEmpty) {
      _apiClient.setAuthToken(token);
    }
  }

  /// JSON array, or `results` / `data` wrapper (DRF-style).
  static List<dynamic> _extractUserListOrThrow(dynamic raw) {
    if (raw is List) return List<dynamic>.from(raw);
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      if (m['results'] is List) return List<dynamic>.from(m['results'] as List);
      if (m['data'] is List) return List<dynamic>.from(m['data'] as List);
    }
    throw FormatException(
      'Users API must return a JSON array (or results/data). Got ${raw.runtimeType}. '
      'If you use an older backend, deploy latest routes or check /api/users/ vs /api/mdrrmo/users/.',
    );
  }

  /// Get all users with optional filters.
  ///
  /// GET `/api/users/` (falls back to `/api/mdrrmo/users/` on 404 for older servers).
  Future<List<User>> listUsers({
    String? status,
    String? barangay,
    String? search,
  }) async {
    await _ensureAuthToken();
    final token = await SessionStorage.readToken();
    if (token == null || token.isEmpty) {
      throw Exception(
        'No auth token. Sign out and log in again (MDRRMO account required for User Management).',
      );
    }

    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    if (barangay != null) params['barangay'] = barangay;
    if (search != null) params['search'] = search;

    try {
      dynamic response;
      try {
        response = await _apiClient.get(ApiConfig.listUsersEndpoint, params: params);
      } on ApiException catch (e) {
        if (e.statusCode == 404) {
          response = await _apiClient.get(ApiConfig.mdrrmoUsersListEndpoint, params: params);
        } else {
          rethrow;
        }
      }

      final rows = _extractUserListOrThrow(response.data);
      return rows.map((json) {
        if (json is! Map) {
          throw FormatException('Each user must be a JSON object, got ${json.runtimeType}');
        }
        return User.fromJson(Map<String, dynamic>.from(json));
      }).toList();
    } on ApiException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to fetch users: $e');
    }
  }

  /// Get details of a specific user with stats.
  /// 
  /// REAL: GET /api/mdrrmo/users/{id}/
  Future<Map<String, dynamic>> getUser(int userId) async {
    await _ensureAuthToken();
    try {
      final response = await _apiClient.get(
        '${ApiConfig.listUsersEndpoint}$userId/',
      );
      
      return response.data;
    } catch (e) {
      throw Exception('Failed to fetch user details: $e');
    }
  }

  /// Suspend a user account (MDRRMO only).
  /// 
  /// REAL: POST /api/mdrrmo/users/{id}/suspend/
  Future<User> suspendUser(int userId) async {
    await _ensureAuthToken();
    try {
      final response = await _apiClient.post(
        '${ApiConfig.listUsersEndpoint}$userId/suspend/',
      );
      
      return User.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to suspend user: $e');
    }
  }

  /// Activate a suspended user account (MDRRMO only).
  /// 
  /// REAL: POST /api/mdrrmo/users/{id}/activate/
  Future<User> activateUser(int userId) async {
    await _ensureAuthToken();
    try {
      final response = await _apiClient.post(
        '${ApiConfig.listUsersEndpoint}$userId/activate/',
      );
      
      return User.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to activate user: $e');
    }
  }

  /// Delete a user account (MDRRMO only).
  /// 
  /// REAL: DELETE /api/mdrrmo/users/{id}/delete/
  Future<void> deleteUser(int userId) async {
    await _ensureAuthToken();
    try {
      await _apiClient.delete(
        '${ApiConfig.listUsersEndpoint}$userId/delete/',
      );
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }
}
