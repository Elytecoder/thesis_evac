import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../models/user_notification.dart';

/// Service for managing user notifications.
class NotificationService {
  final ApiClient _apiClient = ApiClient();

  /// Get user's notifications.
  /// 
  /// Query params: unreadOnly (default: false)
  /// REAL: GET /api/notifications/
  Future<Map<String, dynamic>> getNotifications({
    bool unreadOnly = false,
  }) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      return {
        'unread_count': 0,
        'notifications': [],
      };
    }

    // REAL API CALL:
    try {
      final params = <String, dynamic>{};
      if (unreadOnly) params['unread_only'] = 'true';
      
      final response = await _apiClient.get(
        ApiConfig.notificationsEndpoint,
        params: params,
      );
      
      final unreadCount = response.data['unread_count'] as int;
      final List<dynamic> notificationsJson = response.data['notifications'];
      final notifications = notificationsJson
          .map((json) => UserNotification.fromJson(json))
          .toList();
      
      return {
        'unread_count': unreadCount,
        'notifications': notifications,
      };
    } catch (e) {
      throw Exception('Failed to fetch notifications: $e');
    }
  }

  /// Get a specific notification.
  /// 
  /// REAL: GET /api/notifications/{id}/
  Future<UserNotification> getNotification(int notificationId) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      return UserNotification(
        id: notificationId,
        type: NotificationType.reportApproved,
        title: 'Report Approved',
        message: 'Your report has been approved.',
        isRead: false,
        createdAt: DateTime.now(),
      );
    }

    // REAL API CALL:
    try {
      final response = await _apiClient.get(
        '${ApiConfig.notificationsEndpoint}$notificationId/',
      );
      
      return UserNotification.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to fetch notification: $e');
    }
  }

  /// Mark a notification as read.
  /// 
  /// REAL: POST /api/notifications/{id}/mark-read/
  Future<UserNotification> markAsRead(int notificationId) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      return UserNotification(
        id: notificationId,
        type: NotificationType.reportApproved,
        title: 'Report Approved',
        message: 'Your report has been approved.',
        isRead: true,
        readAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
    }

    // REAL API CALL:
    try {
      final response = await _apiClient.post(
        '${ApiConfig.notificationsEndpoint}$notificationId/mark-read/',
      );
      
      return UserNotification.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  /// Mark all notifications as read.
  /// 
  /// REAL: POST /api/notifications/mark-all-read/
  Future<String> markAllAsRead() async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      return 'Marked 0 notifications as read';
    }

    // REAL API CALL:
    try {
      final response = await _apiClient.post(
        ApiConfig.markAllReadEndpoint,
      );
      
      return response.data['message'] as String;
    } catch (e) {
      throw Exception('Failed to mark all as read: $e');
    }
  }

  /// Delete a notification.
  /// 
  /// REAL: DELETE /api/notifications/{id}/delete/
  Future<void> deleteNotification(int notificationId) async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }

    // REAL API CALL:
    try {
      await _apiClient.delete(
        '${ApiConfig.notificationsEndpoint}$notificationId/delete/',
      );
    } catch (e) {
      throw Exception('Failed to delete notification: $e');
    }
  }

  /// Get unread notification count.
  /// 
  /// REAL: GET /api/notifications/unread-count/
  Future<int> getUnreadCount() async {
    if (ApiConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      return 0;
    }

    // REAL API CALL:
    try {
      final response = await _apiClient.get(
        ApiConfig.unreadCountEndpoint,
      );
      
      return response.data['unread_count'] as int;
    } catch (e) {
      throw Exception('Failed to fetch unread count: $e');
    }
  }
}
