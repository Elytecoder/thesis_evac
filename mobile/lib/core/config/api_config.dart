/// API configuration for backend communication.
/// 
/// IMPORTANT: Set useMockData = false to connect to real backend.

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  /// Toggle between mock data and real API calls
  /// Set to false when backend is running and ready
  static const bool useMockData = false; // Changed to false to use real API
  
  /// Backend base URL - automatically detects platform
  /// Web (Chrome): http://localhost:8000/api
  /// Android emulator: http://10.0.2.2:8000/api
  /// Physical device: http://192.168.x.x:8000/api
  static String get baseUrl {
    if (kIsWeb) {
      // Web platform (Chrome, Firefox, etc.)
      return 'http://localhost:8000/api';
    } else {
      // Mobile platform (Android/iOS)
      // For Android emulator
      return 'http://10.0.2.2:8000/api';
      
      // For physical device, uncomment and set your computer's IP:
      // return 'http://192.168.1.100:8000/api';
    }
  }
  
  /// Authentication endpoints
  static const String sendVerificationCodeEndpoint = '/auth/send-verification-code/';
  static const String loginEndpoint = '/auth/login/';
  static const String registerEndpoint = '/auth/register/';
  static const String logoutEndpoint = '/auth/logout/';
  static const String profileEndpoint = '/auth/profile/';
  static const String updateProfileEndpoint = '/auth/profile/update/';
  static const String changePasswordEndpoint = '/auth/change-password/';
  
  /// Hazard report endpoints (Residents)
  static const String reportHazardEndpoint = '/report-hazard/';
  static const String myReportsEndpoint = '/my-reports/';
  static const String verifiedHazardsEndpoint = '/verified-hazards/';
  
  /// MDRRMO - Dashboard & Report management
  static const String dashboardStatsEndpoint = '/mdrrmo/dashboard-stats/';
  static const String pendingReportsEndpoint = '/mdrrmo/pending-reports/';
  static const String rejectedReportsEndpoint = '/mdrrmo/rejected-reports/';
  static const String approveReportEndpoint = '/mdrrmo/approve-report/';
  static const String restoreReportEndpoint = '/mdrrmo/restore-report/';
  static const String mdrrmoDeleteReportEndpoint = '/mdrrmo/reports/';
  
  /// Evacuation center endpoints
  static const String evacuationCentersEndpoint = '/evacuation-centers/';
  
  /// MDRRMO - Evacuation center management (CRUD)
  static const String createEvacuationCenterEndpoint = '/mdrrmo/evacuation-centers/';
  
  /// MDRRMO - User management
  static const String listUsersEndpoint = '/mdrrmo/users/';
  
  /// MDRRMO - System logs
  static const String systemLogsEndpoint = '/mdrrmo/system-logs/';
  static const String clearSystemLogsEndpoint = '/mdrrmo/system-logs/clear/';
  
  /// Notifications
  static const String notificationsEndpoint = '/notifications/';
  static const String unreadCountEndpoint = '/notifications/unread-count/';
  static const String markAllReadEndpoint = '/notifications/mark-all-read/';
  
  /// Route calculation
  static const String calculateRouteEndpoint = '/calculate-route/';
  
  /// Bootstrap sync
  static const String bootstrapSyncEndpoint = '/bootstrap-sync/';
  
  /// API timeout settings
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  /// Get full URL for an endpoint
  static String getUrl(String endpoint) {
    return '$baseUrl$endpoint';
  }
  
  /// Helper to build URL with ID parameter
  static String getUrlWithId(String endpoint, int id) {
    return '$baseUrl$endpoint$id/';
  }
}
