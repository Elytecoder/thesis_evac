import 'dart:convert';
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

  static dynamic _tryDecodeJson(String raw) => jsonDecode(raw);

  /// Handle Dio errors and extract meaningful messages
  ApiException _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException('Connection timeout. Please check your internet connection.');
      
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final responseData = error.response?.data;
        
        // Try to extract the specific error message from the response
        String message = 'Server error';
        
        if (responseData != null) {
          if (responseData is Map) {
            final map = responseData as Map;
            // Check for common error field names
            message = map['error'] ?? 
                     map['detail'] ?? 
                     map['message'] ??
                     map['non_field_errors']?.toString() ??
                     message;
            
            // Handle field-specific errors (validation: latitude, longitude, etc.)
            if (message == 'Server error' && map.isNotEmpty) {
              final parts = <String>[];
              for (final entry in map.entries) {
                if (entry.key == 'error' || entry.key == 'detail' || entry.key == 'message') continue;
                final v = entry.value;
                final text = v is List ? (v.isNotEmpty ? v.first.toString() : '') : v.toString();
                if (text.isNotEmpty) parts.add('${entry.key}: $text');
              }
              if (parts.isNotEmpty) message = parts.join(' ');
            } else if (map.containsKey('email')) {
              message = 'Email: ${map['email']}';
            } else if (map.containsKey('password')) {
              message = 'Password: ${map['password']}';
            } else if (map.containsKey('phone_number')) {
              message = 'Phone: ${map['phone_number']}';
            } else if (map.containsKey('verification_code')) {
              message = map['verification_code'].toString();
            }
          } else if (responseData is String) {
            message = responseData;
          }
        }
        
        // Handle specific status codes; use server message when available
        if (statusCode == 400) {
          return ApiException(message, statusCode: statusCode);
        } else if (statusCode == 401) {
          return ApiException(message != 'Server error' ? message : 'Invalid email or password.', statusCode: 401);
        } else if (statusCode == 403) {
          return ApiException(message != 'Server error' ? message : 'Access forbidden.', statusCode: 403);
        } else if (statusCode == 404) {
          return ApiException('Resource not found.', statusCode: 404);
        } else if (statusCode == 500) {
          // responseData can be Map (parsed JSON) or String (e.g. if content-type was wrong)
          Map? errMap = responseData is Map ? responseData as Map : null;
          if (errMap == null && responseData is String) {
            try {
              final decoded = _tryDecodeJson(responseData as String);
              if (decoded is Map) errMap = decoded;
            } catch (_) {}
          }
          final detail = errMap != null && errMap.containsKey('detail')
              ? errMap['detail'].toString()
              : null;
          final err = errMap != null && errMap.containsKey('error')
              ? errMap['error'].toString()
              : null;
          final serverMsg = detail ?? err ?? message;
          return ApiException(
            serverMsg != 'Server error' && serverMsg.isNotEmpty
                ? serverMsg
                : 'Server error. Please try again later.',
            statusCode: 500,
          );
        }
        
        return ApiException(message, statusCode: statusCode);
      
      case DioExceptionType.cancel:
        return ApiException('Request cancelled.');
      
      case DioExceptionType.connectionError:
        return ApiException('Cannot connect to server. Please check your internet connection.');
      
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
