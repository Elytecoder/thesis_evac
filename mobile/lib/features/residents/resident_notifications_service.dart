import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/api_config.dart';
import '../../core/config/storage_config.dart';
import '../../core/network/api_client.dart';
import '../../models/user_notification.dart';

/// Notifications service for residents.
/// When not in mock mode, uses real API: GET /api/notifications/, mark-read, etc.
class ResidentNotificationsService {
  final ApiClient _apiClient = ApiClient();

  // Mock data (used only when ApiConfig.useMockData is true)
  static List<Map<String, dynamic>> _notifications = [
    {'id': 'notif001', 'message': 'Your hazard report has been approved.', 'type': 'approved', 'status': 'unread', 'date': '2026-03-05 10:30', 'report_id': 'rep001', 'report_type': 'Flooded Road'},
    {'id': 'notif002', 'message': 'Your hazard report was rejected after verification.', 'type': 'rejected', 'status': 'unread', 'date': '2026-03-04 14:15', 'report_id': 'rep009', 'report_type': 'Road Blocked'},
    {'id': 'notif003', 'message': 'Your hazard report has been approved.', 'type': 'approved', 'status': 'read', 'date': '2026-03-03 09:45', 'report_id': 'rep002', 'report_type': 'Fallen Tree'},
  ];

  Future<void> _ensureAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(StorageConfig.authTokenKey);
    if (token != null && token.isNotEmpty) {
      _apiClient.setAuthToken(token);
    }
  }

  /// Convert API notification to map format expected by notifications screen.
  static Map<String, dynamic> _toMap(UserNotification n) {
    final type = n.type == 'report_approved' ? 'approved' : (n.type == 'report_rejected' ? 'rejected' : n.type);
    final date = n.createdAt.toIso8601String().replaceFirst('T', ' ').substring(0, 16);
    final reportId = n.relatedObjectId?.toString() ?? '';
    final reportType = n.metadata?['hazard_type']?.toString() ?? n.title;
    final meta = n.metadata;
    double? lat;
    double? lng;
    if (meta != null) {
      if (meta['latitude'] != null) lat = double.tryParse(meta['latitude'].toString());
      if (meta['longitude'] != null) lng = double.tryParse(meta['longitude'].toString());
    }
    return {
      'id': n.id.toString(),
      'message': n.message,
      'type': type,
      'status': n.isRead ? 'read' : 'unread',
      'date': date,
      'report_id': reportId,
      'report_type': reportType,
      if (lat != null) 'latitude': lat,
      if (lng != null) 'longitude': lng,
    };
  }

  /// Get all notifications (from API when not mock).
  Future<List<Map<String, dynamic>>> getAllNotifications() async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      final sorted = List<Map<String, dynamic>>.from(_notifications);
      sorted.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
      return sorted;
    }
    try {
      await _ensureAuthToken();
      final response = await _apiClient.get(ApiConfig.notificationsEndpoint);
      final raw = response.data;
      if (raw is! Map) return [];
      final list = raw['notifications'] is List ? List<dynamic>.from(raw['notifications'] as List) : [];
      final notifications = <Map<String, dynamic>>[];
      for (final item in list) {
        try {
          if (item is! Map) continue;
          final n = UserNotification.fromJson(Map<String, dynamic>.from(item as Map));
          notifications.add(_toMap(n));
        } catch (_) {}
      }
      notifications.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
      return notifications;
    } catch (_) {
      return [];
    }
  }

  /// Get unread notifications
  Future<List<Map<String, dynamic>>> getUnreadNotifications() async {
    final all = await getAllNotifications();
    return all.where((n) => n['status'] == 'unread').toList();
  }

  /// Get unread count (from API when not mock).
  Future<int> getUnreadCount() async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 200));
      return _notifications.where((n) => n['status'] == 'unread').length;
    }
    try {
      await _ensureAuthToken();
      final response = await _apiClient.get(ApiConfig.unreadCountEndpoint);
      final raw = response.data;
      if (raw is Map && raw['unread_count'] != null) {
        return (raw['unread_count'] as num).toInt();
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 200));
      final index = _notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) _notifications[index]['status'] = 'read';
      return;
    }
    try {
      await _ensureAuthToken();
      final id = int.tryParse(notificationId);
      if (id == null) return;
      await _apiClient.post('${ApiConfig.notificationsEndpoint}$id/mark-read/');
    } catch (_) {}
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      for (var n in _notifications) {
        n['status'] = 'read';
      }
      return;
    }
    try {
      await _ensureAuthToken();
      await _apiClient.post(ApiConfig.markAllReadEndpoint);
    } catch (_) {}
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 200));
      _notifications.removeWhere((n) => n['id'] == notificationId);
      return;
    }
    try {
      await _ensureAuthToken();
      final id = int.tryParse(notificationId);
      if (id == null) return;
      await _apiClient.delete('${ApiConfig.notificationsEndpoint}$id/delete/');
    } catch (_) {}
  }
}
