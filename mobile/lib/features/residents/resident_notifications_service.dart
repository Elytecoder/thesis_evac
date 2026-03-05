/// Mock Notifications Service for Residents
/// Provides mock data for notification system about report status updates
class ResidentNotificationsService {
  // Mock notifications data
  static List<Map<String, dynamic>> _notifications = [
    {
      'id': 'notif001',
      'message': 'Your hazard report about flooding in Zone 2 has been approved by MDRRMO.',
      'type': 'approved',
      'status': 'unread',
      'date': '2026-03-05 10:30',
      'report_id': 'rep001', // Links to Flooded Road in mock data
      'report_type': 'Flooded Road',
    },
    {
      'id': 'notif002',
      'message': 'Your hazard report about road blockage in Zone 1 was rejected after verification.',
      'type': 'rejected',
      'status': 'unread',
      'date': '2026-03-04 14:15',
      'report_id': 'rep009',
      'report_type': 'Road Blocked',
    },
    {
      'id': 'notif003',
      'message': 'Your hazard report about fallen tree has been approved by MDRRMO.',
      'type': 'approved',
      'status': 'read',
      'date': '2026-03-03 09:45',
      'report_id': 'rep002', // Links to Fallen Tree
      'report_type': 'Fallen Tree',
    },
    {
      'id': 'notif004',
      'message': 'Your hazard report about landslide has been approved by MDRRMO.',
      'type': 'approved',
      'status': 'read',
      'date': '2026-03-02 16:20',
      'report_id': 'rep004', // Links to Landslide
      'report_type': 'Landslide',
    },
  ];

  /// Get all notifications
  Future<List<Map<String, dynamic>>> getAllNotifications() async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Sort by date descending (newest first)
    final sorted = List<Map<String, dynamic>>.from(_notifications);
    sorted.sort((a, b) => b['date'].compareTo(a['date']));
    return sorted;
  }

  /// Get unread notifications
  Future<List<Map<String, dynamic>>> getUnreadNotifications() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _notifications
        .where((notif) => notif['status'] == 'unread')
        .toList();
  }

  /// Get unread count
  Future<int> getUnreadCount() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _notifications
        .where((notif) => notif['status'] == 'unread')
        .length;
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _notifications.indexWhere((n) => n['id'] == notificationId);
    if (index != -1) {
      _notifications[index]['status'] = 'read';
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    await Future.delayed(const Duration(milliseconds: 300));
    for (var notification in _notifications) {
      notification['status'] = 'read';
    }
  }

  /// Add new notification (for testing)
  Future<void> addNotification(Map<String, dynamic> notification) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _notifications.insert(0, notification);
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _notifications.removeWhere((n) => n['id'] == notificationId);
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _notifications.clear();
  }
}
