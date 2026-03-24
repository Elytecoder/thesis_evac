import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/auth/session_storage.dart';
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

  /// Login with email and password.
  /// 
  /// Connects to Django API endpoint: POST /api/auth/login/
  /// Errors: "Invalid email or password." | "Please verify your email before logging in."
  /// [keepLoggedIn]: when true, token is stored securely for up to [SessionStorage.persistentSessionMaxAge].
  /// When false, token is kept in memory only until the app is closed.
  Future<User> login(
    String email,
    String password, {
    bool keepLoggedIn = true,
  }) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(seconds: 1));
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Email and password required');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_email', email);
      final User user;
      if (email.toLowerCase().contains('mdrrmo') || email.toLowerCase().contains('admin')) {
        user = MockUsers.getMdrrmoUser();
      } else {
        user = MockUsers.getResidentUser();
      }
      final token = user.authToken;
      if (token != null && token.isNotEmpty) {
        await SessionStorage.writeSession(
          token: token,
          keepLoggedIn: keepLoggedIn,
          userId: user.id,
        );
        _apiClient.setAuthToken(token);
      }
      return user;
    }

    try {
      final response = await _apiClient.post(
        ApiConfig.loginEndpoint,
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );

      final user = User.fromJson(response.data);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_email', email.trim().toLowerCase());
      if (user.authToken != null) {
        await SessionStorage.writeSession(
          token: user.authToken!,
          keepLoggedIn: keepLoggedIn,
          userId: user.id,
        );
        _apiClient.setAuthToken(user.authToken!);
      }
      return user;
    } on ApiException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Login failed. Please check your credentials and try again.');
    }
  }

  /// Send email verification code.
  /// 
  /// Connects to Django API endpoint: POST /api/auth/send-verification-code/
  Future<Map<String, dynamic>> sendVerificationCode(String email) async {
    try {
      final response = await _apiClient.post(
        ApiConfig.sendVerificationCodeEndpoint,
        data: {'email': email},
      );

      return {
        'message': response.data['message'],
        'dev_code': response.data['dev_code'],
        'code': response.data['code'],
      };
    } on ApiException catch (e) {
      // Pass through the specific error message from the API
      throw Exception(e.message);
    } catch (e) {
      // Fallback for unexpected errors
      throw Exception('Failed to send verification code. Please try again.');
    }
  }

  /// Register a new user (resident only) with email verification.
  /// 
  /// Connects to Django API endpoint: POST /api/auth/register/
  Future<User> register({
    required String email,
    required String password,
    required String passwordConfirm,
    required String fullName,
    required String phoneNumber,
    required String province,
    required String municipality,
    required String barangay,
    required String street,
    required String verificationCode,
    bool keepLoggedIn = true,
  }) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(seconds: 1));

      final user = User(
        id: DateTime.now().millisecondsSinceEpoch,
        username: email.split('@')[0],
        email: email,
        fullName: fullName,
        phoneNumber: phoneNumber,
        province: province,
        municipality: municipality,
        barangay: barangay,
        street: street,
        role: UserRole.resident,
        dateJoined: DateTime.now(),
        authToken: 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (user.authToken != null) {
        await SessionStorage.writeSession(
          token: user.authToken!,
          keepLoggedIn: keepLoggedIn,
          userId: user.id,
        );
        _apiClient.setAuthToken(user.authToken!);
      }
      return user;
    }

    // REAL API CALL:
    try {
      final response = await _apiClient.post(
        ApiConfig.registerEndpoint,
        data: {
          'email': email,
          'password': password,
          'password_confirm': passwordConfirm,
          'verification_code': verificationCode,
          'full_name': fullName,
          'phone_number': phoneNumber,
          'province': province,
          'municipality': municipality,
          'barangay': barangay,
          'street': street,
        },
      );

      final user = User.fromJson(response.data);

      if (user.authToken != null) {
        await SessionStorage.writeSession(
          token: user.authToken!,
          keepLoggedIn: keepLoggedIn,
          userId: user.id,
        );
        _apiClient.setAuthToken(user.authToken!);
      }

      return user;
    } on ApiException catch (e) {
      // Pass through the specific error message from the API
      throw Exception(e.message);
    } catch (e) {
      // Fallback for unexpected errors
      throw Exception('Registration failed. Please try again.');
    }
  }

  /// Permanently delete the current user's account (resident only on server).
  ///
  /// Connects to Django API endpoint: POST /api/auth/delete-account/
  /// Body: {password} — must match current password.
  /// After success, clears local auth (token already invalidated on server).
  Future<void> deleteAccount({required String password}) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 400));
      await clearAuthToken();
      _apiClient.clearAuthToken();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_username');
      await prefs.remove('current_email');
      await prefs.remove('user_profile');
      return;
    }

    await _ensureAuthToken();
    try {
      await _apiClient.post(
        ApiConfig.deleteAccountEndpoint,
        data: {'password': password},
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        throw Exception(
          'This server does not expose account deletion yet. Deploy the latest backend '
          '(POST /api/auth/delete-account/) or contact support.',
        );
      }
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to delete account. Please try again.');
    }

    await clearAuthToken();
    _apiClient.clearAuthToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_username');
    await prefs.remove('current_email');
    await prefs.remove('user_profile');
  }

  /// Logout current user.
  /// 
  /// Connects to Django API endpoint: POST /api/auth/logout/
  Future<void> logout() async {
    if (!ApiConfig.useMockData) {
      try {
        // Call logout endpoint to invalidate token on server
        await _apiClient.post(ApiConfig.logoutEndpoint);
      } catch (e) {
        print('Logout API call failed: $e');
        // Continue with local cleanup even if API call fails
      }
    }
    
    // Clear local auth data
    await clearAuthToken();
    _apiClient.clearAuthToken();
    
    // Clear saved username and profile
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_username');
    await prefs.remove('current_email');
    await prefs.remove('user_profile');
  }

  /// Save auth token using the current persistence mode (e.g. after change-password).
  Future<void> saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final keep = prefs.getBool(StorageConfig.keepLoggedInKey) ?? true;
    final uid = prefs.getInt(StorageConfig.userIdKey);
    await SessionStorage.writeSession(
      token: token,
      keepLoggedIn: keep,
      userId: uid,
    );
    _apiClient.setAuthToken(token);
  }

  /// Get saved auth token (secure storage, legacy prefs, or ephemeral).
  Future<String?> getAuthToken() async {
    return SessionStorage.readToken();
  }

  /// Ensure the ApiClient has the current token (each AuthService has its own
  /// ApiClient; token is only set on the instance used at login). Restore from
  /// storage before authenticated requests so profile/change-password work from
  /// any screen.
  Future<void> _ensureAuthToken() async {
    final token = await getAuthToken();
    if (token != null && token.isNotEmpty) {
      _apiClient.setAuthToken(token);
    }
  }

  /// Clear auth token and session metadata from local storage.
  Future<void> clearAuthToken() async {
    await SessionStorage.clearSession();
  }

  /// Clear local credentials without calling the server (e.g. invalid / expired token on startup).
  Future<void> clearLocalSessionOnly() async {
    await clearAuthToken();
    _apiClient.clearAuthToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_username');
    await prefs.remove('current_email');
    await prefs.remove('user_profile');
  }

  /// Change password (validates current password on backend).
  ///
  /// Connects to Django API endpoint: POST /api/auth/change-password/
  /// Body: old_password, new_password, new_password_confirm
  /// On success, stores the new token returned by the backend.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      throw Exception('Change password is not available in demo mode.');
    }

    await _ensureAuthToken();
    try {
      final response = await _apiClient.post(
        ApiConfig.changePasswordEndpoint,
        data: {
          'old_password': oldPassword,
          'new_password': newPassword,
          'new_password_confirm': newPasswordConfirm,
        },
      );

      final newToken = response.data is Map ? response.data['token'] : null;
      if (newToken != null && newToken.toString().isNotEmpty) {
        await saveAuthToken(newToken.toString());
      }
    } on ApiException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to change password. Please try again.');
    }
  }

  /// Check if user is logged in.
  Future<bool> isLoggedIn() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }

  /// Update profile (editable fields: phone_number, street only).
  /// 
  /// Connects to Django API endpoint: PUT /api/auth/profile/update/
  Future<Map<String, dynamic>> updateProfile({
    required String phoneNumber,
    required String street,
  }) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('user_profile');
      if (saved != null) {
        final map = json.decode(saved) as Map<String, dynamic>;
        map['phone_number'] = phoneNumber;
        map['street'] = street;
        await prefs.setString('user_profile', json.encode(map));
        return map;
      }
      return {};
    }
    await _ensureAuthToken();
    final response = await _apiClient.put(
      ApiConfig.updateProfileEndpoint,
      data: {
        'phone_number': phoneNumber,
        'street': street,
      },
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile', json.encode(response.data));
    return response.data is Map ? Map<String, dynamic>.from(response.data) : {};
  }

  /// Get current user profile.
  /// 
  /// Connects to Django API endpoint: GET /api/auth/profile/
  Future<Map<String, dynamic>> getCurrentUser() async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Check if there's a saved user profile first
      final prefs = await SharedPreferences.getInstance();
      final savedProfileJson = prefs.getString('user_profile');
      
      if (savedProfileJson != null && savedProfileJson.isNotEmpty) {
        try {
          return json.decode(savedProfileJson);
        } catch (e) {
          print('Error parsing saved profile: $e');
        }
      }
      
      final savedUsername = prefs.getString('current_username');
      final savedEmail = prefs.getString('current_email');
      final check = savedEmail ?? savedUsername;
      if (check != null && 
          (check.toLowerCase().contains('mdrrmo') || 
           check.toLowerCase().contains('admin'))) {
        return {
          'username': 'mdrrmo_admin',
          'email': 'admin@mdrrmo.bulan.gov.ph',
          'role': 'mdrrmo',
          'full_name': 'MDRRMO Administrator',
        };
      }
      
      return {
        'username': check?.split('@').first ?? 'resident1',
        'email': savedEmail ?? 'resident1@gmail.com',
        'role': 'resident',
        'full_name': 'Juan Dela Cruz',
        'phone_number': '09171234567',
      };
    }

    // REAL API CALL:
    await _ensureAuthToken();
    try {
      final response = await _apiClient.get(ApiConfig.profileEndpoint);
      
      // Cache the profile locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_profile', json.encode(response.data));
      
      return response.data;
    } catch (e) {
      // If API fails, try to return cached profile
      final prefs = await SharedPreferences.getInstance();
      final savedProfileJson = prefs.getString('user_profile');
      
      if (savedProfileJson != null && savedProfileJson.isNotEmpty) {
        try {
          return json.decode(savedProfileJson);
        } catch (parseError) {
          throw Exception('Failed to get user profile: $e');
        }
      }
      
      throw Exception('Failed to get user profile: $e');
    }
  }
}
