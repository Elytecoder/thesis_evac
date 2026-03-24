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

  /// Get all users with optional filters.
  /// 
  /// Query params: status (active/suspended), barangay, search
  /// REAL: GET /api/mdrrmo/users/
  Future<List<User>> listUsers({
    String? status,
    String? barangay,
    String? search,
  }) async {
    // All registered users come from the database (no mock list).
    await _ensureAuthToken();
    try {
      final params = <String, dynamic>{};
      if (status != null) params['status'] = status;
      if (barangay != null) params['barangay'] = barangay;
      if (search != null) params['search'] = search;
      
      final response = await _apiClient.get(
        ApiConfig.listUsersEndpoint,
        params: params,
      );
      
      final List<dynamic> usersJson = response.data is List ? List<dynamic>.from(response.data as List) : [];
      return usersJson.map((json) => User.fromJson(Map<String, dynamic>.from(json as Map))).toList();
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
