import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

/// HTTP client wrapper for API communication.
///
/// Singleton: all services share one Dio instance and one persistent connection pool.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio _dio;

  /// Called when any authenticated request receives a 401 (session expired /
  /// token invalidated on server).  Set this once in main() to clear the local
  /// session and navigate back to the login screen.
  static void Function()? onUnauthorized;

  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      sendTimeout: ApiConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Connection': 'keep-alive',
      },
    ));

    // Intercept 401 / suspension-403 responses and trigger a global session-expiry
    // callback so the user is immediately sent back to login.
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException error, ErrorInterceptorHandler handler) {
          final code = error.response?.statusCode;
          final path = error.requestOptions.path;
          final isAuthEndpoint = path.contains('/auth/login') ||
              path.contains('/auth/register') ||
              path.contains('/auth/send-verification') ||
              path.contains('/auth/logout') ||
              path.contains('/auth/forgot-password') ||
              path.contains('/auth/verify-reset-code') ||
              path.contains('/auth/reset-password') ||
              path.contains('/auth/fcm-token');

          if (!isAuthEndpoint && onUnauthorized != null) {
            if (code == 401) {
              onUnauthorized!();
            } else if (code == 403) {
              // Force logout when the account has been suspended/deactivated.
              final data = error.response?.data;
              final msg = (data is Map ? (data['error'] ?? data['detail'] ?? '') : '').toString().toLowerCase();
              if (msg.contains('suspend') || msg.contains('inactive') || msg.contains('not active')) {
                onUnauthorized!();
              }
            }
          }
          handler.next(error);
        },
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ));
    }
  }

  /// Set authentication token
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Token $token';
  }

  /// Clear authentication token
  void clearAuthToken() {
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

  /// POST multipart (e.g. hazard report with photo/video files).
  Future<Response> postFormData(String endpoint, FormData data) async {
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
        return ApiException(
          'Request timed out. If the backend is on Render, wait and try again — '
          'the first request after idle can take a minute while the service wakes up. '
          'Also check your internet connection.',
        );
      
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final responseData = error.response?.data;
        
        // Try to extract the specific error message from the response
        String message = 'Server error';
        
        if (responseData != null) {
          if (responseData is Map) {
            final map = responseData;
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
          // On login, show credential error. On authenticated requests, the
          // interceptor above already triggered onUnauthorized(); we still
          // return a clear message in case the caller displays it.
          final isCredentialError = message.toLowerCase().contains('invalid') &&
              (message.toLowerCase().contains('password') ||
               message.toLowerCase().contains('credentials'));
          return ApiException(
            isCredentialError ? message : 'Session expired. Please log in again.',
            statusCode: 401,
          );
        } else if (statusCode == 403) {
          return ApiException(message != 'Server error' ? message : 'Access forbidden.', statusCode: 403);
        } else if (statusCode == 404) {
          return ApiException('Resource not found.', statusCode: 404);
        } else if (statusCode == 500) {
          // responseData can be Map (parsed JSON) or String (e.g. if content-type was wrong)
          Map? errMap = responseData is Map ? responseData : null;
          if (errMap == null && responseData is String) {
            try {
              final decoded = _tryDecodeJson(responseData);
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
