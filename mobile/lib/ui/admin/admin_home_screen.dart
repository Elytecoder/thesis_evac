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
        ],
      ),
    );
  }
}
