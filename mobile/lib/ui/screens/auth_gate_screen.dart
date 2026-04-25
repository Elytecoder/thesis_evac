import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    // Use cached profile to avoid a network call on every startup.
    // If no cache exists (or it fails to parse), fall back to the API.
    final cachedRole = await _getCachedRole();
    if (cachedRole != null) {
      final isMdrrmo = cachedRole == UserRole.mdrrmo.value;
      // Set auth token on shared client so subsequent API calls work.
      _authService.restoreTokenOnClient(token);
      if (mounted) {
        setState(() {
          _loading = false;
          _home = isMdrrmo ? const AdminHomeScreen() : const MapScreen();
        });
      }
      return;
    }

    // Cache miss — fetch from API and cache the result.
    // Hard 6-second timeout: if the backend is cold-starting on Render, treat
    // it as a network error and show the map with cached data rather than
    // leaving the user staring at a spinner for 30-90 s.
    try {
      final profile = await _authService.getCurrentUser()
          .timeout(const Duration(seconds: 6));
      final roleStr = (profile['role'] as String?)?.toLowerCase() ?? 'resident';
      final isMdrrmo = roleStr == UserRole.mdrrmo.value;

      if (!mounted) return;
      setState(() {
        _loading = false;
        _home = isMdrrmo ? const AdminHomeScreen() : const MapScreen();
      });
    } catch (e) {
      // Only clear the session on auth failures (401/403). A network error while
      // offline should NOT log the user out — default to the resident map screen
      // so they can still use the app with cached data.
      final isAuthError = e.toString().contains('401') || e.toString().contains('403');
      if (isAuthError) {
        await _authService.clearLocalSessionOnly();
        if (!mounted) return;
        setState(() {
          _loading = false;
          _home = const WelcomeScreen();
        });
      } else {
        // Network / server error — keep the session, restore token, and show map.
        _authService.restoreTokenOnClient(token);
        if (!mounted) return;
        setState(() {
          _loading = false;
          _home = const MapScreen();
        });
      }
    }
  }

  /// Returns the role string from the cached profile, or null if unavailable.
  Future<String?> _getCachedRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('user_profile');
      if (json == null || json.isEmpty) return null;
      final map = jsonDecode(json) as Map<String, dynamic>;
      final role = map['role'] as String?;
      return role?.toLowerCase();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D47A1),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Image.asset(
                  'assets/images/haznav_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.shield_outlined,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'HAZNAV',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 5,
                ),
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: Colors.white54,
                  strokeWidth: 2.5,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return _home ?? const WelcomeScreen();
  }
}
