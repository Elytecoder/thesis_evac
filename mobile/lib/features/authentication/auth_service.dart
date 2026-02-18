import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/api_config.dart';
import '../../core/config/storage_config.dart';
import '../../core/network/api_client.dart';
import '../../models/user.dart';
import '../../data/mock_users.dart';

/// Authentication service for login/logout.
/// 
/// MOCK MODE: Returns mock users without real API calls.
/// FUTURE: Connect to real backend API for authentication.
class AuthService {
  final ApiClient _apiClient = ApiClient();

  /// Login with username and password.
  /// 
  /// MOCK: Returns mock resident user.
  /// REAL: POST to /api/login/ or /api/token/
  Future<User> login(String username, String password) async {
    if (ApiConfig.useMockData) {
      // Mock delay to simulate network
      await Future.delayed(const Duration(seconds: 1));
      
      // Mock validation
      if (username.isEmpty || password.isEmpty) {
        throw Exception('Username and password required');
      }
      
      // Return mock user based on username
      if (username.toLowerCase().contains('mdrrmo') || 
          username.toLowerCase().contains('admin')) {
        return MockUsers.getMdrrmoUser();
      }
      
      return MockUsers.getResidentUser();
    }

    // REAL API CALL (when ApiConfig.useMockData = false):
    try {
      final response = await _apiClient.post(
        '/auth/login/',
        data: {
          'username': username,
          'password': password,
        },
      );

      final user = User.fromJson(response.data);
      
      // Save auth token
      if (user.authToken != null) {
        await saveAuthToken(user.authToken!);
        _apiClient.setAuthToken(user.authToken!);
      }

      return user;
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  /// Register a new user (resident only).
  /// 
  /// MOCK: Creates a mock user.
  /// REAL: POST to /api/register/
  Future<User> register({
    required String username,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(seconds: 1));
      
      return User(
        id: DateTime.now().millisecondsSinceEpoch,
        username: username,
        email: email,
        firstName: firstName,
        lastName: lastName,
        role: UserRole.resident,
        authToken: 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
      );
    }

    // REAL API CALL:
    try {
      final response = await _apiClient.post(
        '/auth/register/',
        data: {
          'username': username,
          'email': email,
          'password': password,
          'first_name': firstName,
          'last_name': lastName,
        },
      );

      final user = User.fromJson(response.data);
      
      if (user.authToken != null) {
        await saveAuthToken(user.authToken!);
        _apiClient.setAuthToken(user.authToken!);
      }

      return user;
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  /// Logout current user.
  Future<void> logout() async {
    await clearAuthToken();
    _apiClient.clearAuthToken();
  }

  /// Save auth token to local storage.
  Future<void> saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageConfig.authTokenKey, token);
  }

  /// Get saved auth token.
  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(StorageConfig.authTokenKey);
  }

  /// Clear auth token from local storage.
  Future<void> clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageConfig.authTokenKey);
  }

  /// Check if user is logged in.
  Future<bool> isLoggedIn() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }

  /// Get current user profile.
  /// 
  /// MOCK: Returns mock user data.
  /// REAL: GET /api/user/profile/
  Future<Map<String, dynamic>> getCurrentUser() async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Return mock profile (you can customize based on actual logged in user)
      return {
        'username': 'mdrrmo_admin',
        'email': 'admin@mdrrmo.bulan.gov.ph',
        'role': 'mdrrmo',
        'full_name': 'MDRRMO Administrator',
      };
    }

    // REAL API CALL:
    try {
      final response = await _apiClient.get('/auth/profile/');
      return response.data;
    } catch (e) {
      throw Exception('Failed to get user profile: $e');
    }
  }
}
