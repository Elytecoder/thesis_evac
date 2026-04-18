import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/hazards/hazard_service.dart';
import '../../models/hazard_report.dart';
import '../widgets/exit_confirm_scope.dart';
import '../widgets/admin_notification_banner.dart';
import 'dashboard_screen.dart';
import 'reports_management_screen.dart';
import 'map_monitor_screen.dart';
import 'evacuation_centers_management_screen.dart';
import 'analytics_screen.dart';
import 'user_management_screen.dart';
import 'admin_settings_screen.dart';
import 'report_detail_screen.dart';

/// MDRRMO Admin Home Screen with bottom navigation.
///
/// Contains 7 tabs: Dashboard, Reports, Map Monitor, Evacuation Centers,
/// Analytics, User Management, Settings.
///
/// Also runs a background poll (every 30 s) to detect newly submitted hazard
/// reports and shows an in-app notification banner when they arrive.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;

  // ── In-app notification state ──────────────────────────────────────────────
  final HazardService _hazardService = HazardService();

  /// IDs of pending reports we have already shown a notification for.
  /// Populated on the first poll so we don't spam on app start.
  Set<int> _knownPendingIds = {};
  bool _initialPollDone = false;

  /// Queue of new reports waiting to be announced.
  final List<HazardReport> _notificationQueue = [];

  /// The report being shown in the banner right now (null = banner hidden).
  HazardReport? _activeNotification;

  Timer? _pollingTimer;
  // ──────────────────────────────────────────────────────────────────────────

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  // ── Polling ────────────────────────────────────────────────────────────────

  void _startPolling() {
    _pollForNewReports(); // immediate first check
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _pollForNewReports(),
    );
  }

  Future<void> _pollForNewReports() async {
    try {
      final reports = await _hazardService.getPendingReports();
      final currentIds = reports
          .where((r) => r.id != null)
          .map((r) => r.id!)
          .toSet();

      if (!_initialPollDone) {
        // First poll: just seed known IDs so we don't flash on startup.
        _knownPendingIds = currentIds;
        _initialPollDone = true;
        return;
      }

      final newIds = currentIds.difference(_knownPendingIds);
      _knownPendingIds = currentIds;

      if (newIds.isEmpty || !mounted) return;

      // Collect new reports, newest first.
      final newReports = reports
          .where((r) => r.id != null && newIds.contains(r.id))
          .toList()
        ..sort((a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

      setState(() {
        _notificationQueue.addAll(newReports);
      });
      _showNextNotification();
    } catch (_) {
      // Silent — polling should never crash the UI.
    }
  }

  /// Pop the first item from the queue and display it.
  /// Called after a notification is dismissed to chain the next one.
  void _showNextNotification() {
    if (_activeNotification != null) return; // already showing one
    if (_notificationQueue.isEmpty) return;

    setState(() {
      _activeNotification = _notificationQueue.removeAt(0);
    });
  }

  void _dismissNotification() {
    setState(() => _activeNotification = null);
    // Give the slide-out animation time to finish before showing the next.
    Future.delayed(const Duration(milliseconds: 400), _showNextNotification);
  }

  Future<void> _openReportFromNotification(HazardReport report) async {
    _dismissNotification();

    // Signal the reports screen to open this specific report.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('admin_open_report_id', report.id!);

    // Navigate to the Reports tab (index 1).
    setState(() => _currentIndex = 1);
  }

  // ── Notification bell ──────────────────────────────────────────────────────

  /// Total new-report badge count (active banner + queued).
  int get _newReportCount =>
      _notificationQueue.length + (_activeNotification != null ? 1 : 0);

  /// Bell icon widget with optional red badge.
  Widget _buildNotificationBell() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: kToolbarHeight,
          height: kToolbarHeight,
          child: IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_rounded,
                color: Colors.white, size: 26),
            onPressed: _showNotificationPanel,
          ),
        ),
        if (_newReportCount > 0)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                _newReportCount > 9 ? '9+' : '$_newReportCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Show a bottom sheet listing all currently pending reports.
  void _showNotificationPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotificationPanel(
        hazardService: _hazardService,
        onViewReport: (report) {
          Navigator.pop(context);
          _openReportFromNotification(report);
        },
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      DashboardScreen(onNavigateToTab: _navigateToTab),
      const ReportsManagementScreen(),
      const MapMonitorScreen(),
      const EvacuationCentersManagementScreen(),
      const AnalyticsScreen(),
      const UserManagementScreen(),
      const AdminSettingsScreen(),
    ];

    return ExitConfirmScope(
      child: Stack(
        children: [
          Scaffold(
            body: screens[_currentIndex],
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Colors.blue[800],
              unselectedItemColor: Colors.grey[600],
              backgroundColor: Colors.white,
              elevation: 8,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.dashboard),
                  label: 'Dashboard',
                  // Show badge when notifications are queued
                  activeIcon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.dashboard),
                      if (_notificationQueue.isNotEmpty ||
                          _activeNotification != null)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.report),
                  label: 'Reports',
                  activeIcon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.report),
                      if (_notificationQueue.isNotEmpty ||
                          _activeNotification != null)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.map),
                  label: 'Map',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.location_city),
                  label: 'Centers',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.analytics),
                  label: 'Analytics',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.people),
                  label: 'Users',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),

          // In-app notification banner (slides in from top)
          if (_activeNotification != null)
            AdminNotificationBanner(
              key: ValueKey(_activeNotification!.id),
              report: _activeNotification!,
              onView: () => _openReportFromNotification(_activeNotification!),
              onDismiss: _dismissNotification,
            ),

          // Persistent notification bell — top-left corner, visible on all tabs
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 4,
            child: _buildNotificationBell(),
          ),
        ],
      ),
    );
  }
}

// ── Notification panel (bottom sheet) ────────────────────────────────────────

class _NotificationPanel extends StatefulWidget {
  final HazardService hazardService;
  final void Function(HazardReport) onViewReport;

  const _NotificationPanel({
    required this.hazardService,
    required this.onViewReport,
  });

  @override
  State<_NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<_NotificationPanel> {
  List<HazardReport> _pendingReports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final reports = await widget.hazardService.getPendingReports();
      if (mounted) setState(() { _pendingReports = reports; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _hazardLabel(String raw) => raw
      .split('_')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.notifications_rounded,
                      color: Color(0xFF1E3A8A), size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Pending Reports',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                  if (!_loading)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _pendingReports.isEmpty
                            ? Colors.green
                            : Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_pendingReports.length} pending',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Body
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _pendingReports.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline,
                                  size: 48, color: Colors.green[400]),
                              const SizedBox(height: 12),
                              const Text('No pending reports',
                                  style: TextStyle(
                                      fontSize: 15, color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          controller: controller,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _pendingReports.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 16),
                          itemBuilder: (_, i) {
                            final r = _pendingReports[i];
                            final score = r.validationBreakdown != null
                                ? (r.validationBreakdown!['final_validation_score'] as num?)?.toDouble()
                                : r.naiveBayesScore;
                            final scoreText = score != null
                                ? '${(score * 100).toStringAsFixed(0)}%'
                                : '—';
                            final scoreColor = score == null
                                ? Colors.grey
                                : score >= 0.7
                                    ? Colors.green
                                    : score >= 0.4
                                        ? Colors.orange
                                        : Colors.red;
                            return ListTile(
                              leading: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.report_problem_rounded,
                                    color: Colors.orange, size: 22),
                              ),
                              title: Text(
                                _hazardLabel(r.hazardType),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              subtitle: Text(
                                '${r.reporterBarangay ?? 'Unknown'} · AI score: $scoreText',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: scoreColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      scoreText,
                                      style: TextStyle(
                                          color: scoreColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.chevron_right,
                                      color: Colors.grey),
                                ],
                              ),
                              onTap: () => widget.onViewReport(r),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
