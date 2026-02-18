import 'package:dio/dio.dart';
import '../config/api_config.dart';

/// HTTP client wrapper for API communication.
/// 
/// Handles authentication, headers, and error handling.
/// When ApiConfig.useMockData = true, this won't be used.
class ApiClient {
  late final Dio _dio;
  String? _authToken;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add interceptor for logging (helpful for debugging)
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ));
  }

  /// Set authentication token
  void setAuthToken(String token) {
    _authToken = token;
    _dio.options.headers['Authorization'] = 'Token $token';
  }

  /// Clear authentication token
  void clearAuthToken() {
    _authToken = null;
    _dio.options.headers.remove('Authorization');
  }

  /// GET request
  Future<Response> get(String endpoint, {Map<String, dynamic>? params}) async {
    try {
      return await _dio.get(endpoint, queryParameters: params);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// POST request
  Future<Response> post(String endpoint, {dynamic data}) async {
    try {
      return await _dio.post(endpoint, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// PUT request
  Future<Response> put(String endpoint, {dynamic data}) async {
    try {
      return await _dio.put(endpoint, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// DELETE request
  Future<Response> delete(String endpoint) async {
    try {
      return await _dio.delete(endpoint);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Handle Dio errors
  ApiException _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException('Connection timeout. Please check your internet connection.');
      
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final message = error.response?.data?['detail'] ?? 
                        error.response?.data?['message'] ?? 
                        'Server error';
        
        if (statusCode == 401) {
          return ApiException('Unauthorized. Please login again.', statusCode: 401);
        } else if (statusCode == 403) {
          return ApiException('Access forbidden.', statusCode: 403);
        } else if (statusCode == 404) {
          return ApiException('Resource not found.', statusCode: 404);
        }
        return ApiException(message, statusCode: statusCode);
      
      case DioExceptionType.cancel:
        return ApiException('Request cancelled.');
      
      default:
        return ApiException('Network error. Please try again.');
    }
  }
}

/// Custom exception for API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
