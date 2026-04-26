import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/residents/resident_notifications_service.dart';
import '../../features/residents/resident_hazard_reports_service.dart';
import 'map_screen.dart';

/// Notifications Screen for Residents
/// Shows notifications about report approval/rejection status
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ResidentNotificationsService _notificationsService =
      ResidentNotificationsService();
  final ResidentHazardReportsService _hazardReportsService =
      ResidentHazardReportsService();

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);

    try {
      final notifications = await _notificationsService.getAllNotifications();
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    await _notificationsService.markAsRead(notificationId);
    _loadNotifications();
  }
  
  /// Get report location for approved notification.
  /// ALWAYS verifies against the backend when a report_id is present so that
  /// soft-deleted reports return null (triggering the graceful dialog) instead
  /// of using stale lat/lng stored inside the notification.
  Future<Map<String, dynamic>?> _getReportLocationForApproved(Map<String, dynamic> notification) async {
    final reportId = notification['report_id']?.toString();

    // If we have a report_id, verify the report still exists on the backend first.
    // Soft-deleted reports won't appear in my-reports or verified-hazards, so
    // getReportById returns null → we return null → graceful dialog is shown.
    if (reportId != null && reportId.isNotEmpty) {
      final backendReport = await _hazardReportsService.getReportById(reportId);
      if (backendReport != null) {
        // Use backend lat/lng (most up-to-date), fall back to notification data.
        final lat = backendReport['lat'] ?? notification['latitude'];
        final lng = backendReport['lng'] ?? notification['longitude'];
        final la = lat is double ? lat : double.tryParse(lat.toString());
        final ln = lng is double ? lng : double.tryParse(lng.toString());
        if (la != null && ln != null) return {'lat': la, 'lng': ln};
      }
      // Report not found on backend → deleted/unavailable
      return null;
    }

    // No report_id: fall back to coordinates embedded in the notification.
    final lat = notification['latitude'];
    final lng = notification['longitude'];
    if (lat != null && lng != null) {
      final la = lat is double ? lat : double.tryParse(lat.toString());
      final ln = lng is double ? lng : double.tryParse(lng.toString());
      if (la != null && ln != null) return {'lat': la, 'lng': ln};
    }
    return null;
  }

  /// Handle notification click
  Future<void> _handleNotificationClick(Map<String, dynamic> notification) async {
    if (notification['status'] == 'unread') {
      await _markAsRead(notification['id']);
    }
    final isApproved = notification['type'] == 'approved';
    if (isApproved) {
      final report = await _getReportLocationForApproved(notification);
      if (!mounted) return;
      if (report == null) {
        // Report was deleted by MDRRMO after the notification was created
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey),
                SizedBox(width: 12),
                Text('Report Unavailable'),
              ],
            ),
            content: const Text(
              'This hazard report is no longer available. '
              'It may have been removed by MDRRMO.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
      final lat = report['lat'] as num?;
      final lng = report['lng'] as num?;
      if (lat != null && lng != null) {
        showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700], size: 28),
                  const SizedBox(width: 12),
                  const Text('Report Approved'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification['report_type']?.toString() ?? 'Hazard Report',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(Icons.check_circle, 'Status', 'Approved'),
                  _buildInfoRow(Icons.calendar_today, 'Date', notification['date']?.toString() ?? ''),
                  _buildInfoRow(
                    Icons.location_on,
                    'Location',
                    'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}',
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.green[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your report has been approved and is now visible on the map.',
                            style: TextStyle(fontSize: 13, color: Colors.green[900]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setDouble('map_target_lat', lat.toDouble());
                    await prefs.setDouble('map_target_lng', lng.toDouble());
                    await prefs.setBool('map_should_focus', true);
                    // Store report_id so map can highlight the specific marker
                    final reportId = notification['report_id']?.toString() ?? '';
                    if (reportId.isNotEmpty) {
                      await prefs.setString('map_highlight_report_id', reportId);
                    }
                    if (mounted) {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.map),
                  label: const Text('View on Map'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }
    } else {
      // For rejected reports, show popup with rejection info
      _showRejectionDetailsDialog(notification);
    }
  }
  
  /// Show rejection details dialog
  void _showRejectionDetailsDialog(Map<String, dynamic> notification) {
    final reason = notification['reason']?.toString() ?? '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cancel, color: Colors.red[700], size: 28),
            const SizedBox(width: 12),
            const Text('Report Rejected'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification['report_type']?.toString() ?? 'Hazard Report',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.warning_amber, 'Status', 'Rejected'),
            _buildInfoRow(Icons.calendar_today, 'Date', notification['date']?.toString() ?? ''),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.red[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your report was reviewed and rejected by MDRRMO.',
                          style: TextStyle(fontSize: 13, color: Colors.red[900]),
                        ),
                        if (reason.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Reason: $reason',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red[800],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markAllAsRead() async {
    await _notificationsService.markAllAsRead();
    _loadNotifications();
  }

  Future<void> _deleteNotification(String notificationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification'),
        content: const Text('Are you sure you want to delete this notification?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _notificationsService.deleteNotification(notificationId);
      _loadNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          if (_notifications.any((n) => n['status'] == 'unread'))
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, color: Colors.white, size: 20),
              label: const Text(
                'Mark all read',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none,
                          size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    return _buildNotificationCard(notification);
                  },
                ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isUnread = notification['status'] == 'unread';
    final isApproved = notification['type'] == 'approved';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      elevation: isUnread ? 4 : 1,
      color: isUnread ? Colors.blue[50] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isUnread ? Colors.blue[200]! : Colors.grey[300]!,
          width: isUnread ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _handleNotificationClick(notification),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isApproved ? Colors.green[100] : Colors.red[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isApproved ? Icons.check_circle : Icons.cancel,
                  color: isApproved ? Colors.green[700] : Colors.red[700],
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isApproved ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isApproved ? 'APPROVED' : 'REJECTED',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Message
                    Text(
                      notification['message'],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Report type
                    Row(
                      children: [
                        Icon(Icons.warning_amber,
                            size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          notification['report_type'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Timestamp
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          notification['date'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Delete button
              IconButton(
                onPressed: () => _deleteNotification(notification['id']),
                icon: Icon(Icons.close, color: Colors.grey[600], size: 20),
                tooltip: 'Delete',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
