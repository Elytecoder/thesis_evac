import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// HTTP API client with authentication and error handling
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  late final Dio _dio;
  String? _authToken;

  /// Initialize the API client
  void initialize() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectionTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptors
    _dio.interceptors.add(_AuthInterceptor());
    _dio.interceptors.add(_LoggingInterceptor());
    _dio.interceptors.add(_ErrorInterceptor());
  }

  /// Get Dio instance
  Dio get dio => _dio;

  /// Set authentication token
  Future<void> setAuthToken(String token) async {
    _authToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  /// Get authentication token
  Future<String?> getAuthToken() async {
    if (_authToken != null) return _authToken;
    
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
    return _authToken;
  }

  /// Clear authentication token
  Future<void> clearAuthToken() async {
    _authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }
}

/// Authentication interceptor - adds auth token to requests
class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await ApiClient().getAuthToken();
    if (token != null) {
      options.headers['Authorization'] = 'Token $token';
    }
    handler.next(options);
  }
}

/// Logging interceptor - logs requests and responses
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print('🌐 API REQUEST');
    print('  ${options.method} ${options.path}');
    if (options.data != null) {
      print('  Body: ${options.data}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    print('✅ API RESPONSE');
    print('  ${response.statusCode} ${response.requestOptions.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    print('❌ API ERROR');
    print('  ${err.response?.statusCode} ${err.requestOptions.path}');
    print('  ${err.message}');
    if (err.response?.data != null) {
      print('  Response: ${err.response?.data}');
    }
    handler.next(err);
  }
}

/// Error interceptor - handles common API errors
class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Handle 401 Unauthorized - token expired or invalid
    if (err.response?.statusCode == 401) {
      print('⚠️ Authentication failed - clearing token');
      await ApiClient().clearAuthToken();
    }

    // Handle 403 Forbidden - account suspended
    if (err.response?.statusCode == 403) {
      final data = err.response?.data;
      if (data is Map && data['error']?.toString().contains('suspended') == true) {
        print('⚠️ Account is suspended');
        await ApiClient().clearAuthToken();
      }
    }

    handler.next(err);
  }
}

/// API exception with user-friendly message
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => message;

  /// Create from DioException
  factory ApiException.fromDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          'Connection timeout. Please check your internet connection.',
        );

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final data = error.response?.data;

        // Try to extract error message from response
        String message = 'An error occurred';
        if (data is Map) {
          message = data['error']?.toString() ?? 
                    data['message']?.toString() ??
                    data['detail']?.toString() ??
                    'An error occurred';
        }

        return ApiException(
          message,
          statusCode: statusCode,
          data: data,
        );

      case DioExceptionType.cancel:
        return ApiException('Request was cancelled');

      default:
        return ApiException(
          'Network error. Please check your internet connection.',
        );
    }
  }
}
