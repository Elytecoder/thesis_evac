import 'package:flutter/material.dart';

import '../../core/auth/session_storage.dart';
import '../../features/authentication/auth_service.dart';
import '../../models/user.dart';
import '../admin/admin_home_screen.dart';
import 'map_screen.dart';
import 'welcome_screen.dart';

/// First screen after app start: restores session from saved token so users are not
/// dropped on Welcome/Login after the OS kills the app (e.g. camera / gallery).
class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  final AuthService _authService = AuthService();
  bool _loading = true;
  Widget? _home;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final token = await _authService.getAuthToken();
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _home = const WelcomeScreen();
        });
      }
      return;
    }

    if (await SessionStorage.isPersistentSessionExpired()) {
      await _authService.clearLocalSessionOnly();
      if (mounted) {
        setState(() {
          _loading = false;
          _home = const WelcomeScreen();
        });
      }
      return;
    }

    try {
      final profile = await _authService.getCurrentUser();
      final roleStr = (profile['role'] as String?)?.toLowerCase() ?? 'resident';
      final isMdrrmo = roleStr == UserRole.mdrrmo.value;

      if (!mounted) return;
      setState(() {
        _loading = false;
        _home = isMdrrmo ? const AdminHomeScreen() : const MapScreen();
      });
    } catch (_) {
      await _authService.clearLocalSessionOnly();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _home = const WelcomeScreen();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _home ?? const WelcomeScreen();
  }
}
