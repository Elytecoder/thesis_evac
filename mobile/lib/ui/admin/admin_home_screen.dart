import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'reports_management_screen.dart';
import 'map_monitor_screen.dart';
import 'evacuation_centers_management_screen.dart';
import 'analytics_screen.dart';
import 'user_management_screen.dart';
import 'admin_settings_screen.dart';

/// MDRRMO Admin Home Screen with bottom navigation.
/// 
/// This is the main screen for MDRRMO admin users after login.
/// Contains 7 tabs: Dashboard, Reports, Map Monitor, Evacuation Centers, Analytics, User Management, Settings.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      DashboardScreen(onNavigateToTab: _navigateToTab),
      const ReportsManagementScreen(),
      const MapMonitorScreen(),
      const EvacuationCentersManagementScreen(),
      const AnalyticsScreen(),
      const UserManagementScreen(),
      const AdminSettingsScreen(),
    ];

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue[800],
        unselectedItemColor: Colors.grey[600],
        backgroundColor: Colors.white,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.report),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_city),
            label: 'Centers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
