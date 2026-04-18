import 'package:flutter/material.dart';
import 'core/network/api_client.dart';
import 'core/storage/storage_service.dart';
import 'core/services/sync_service.dart';
import 'features/authentication/auth_service.dart';
import 'ui/screens/auth_gate_screen.dart';
import 'ui/screens/welcome_screen.dart';

/// Global navigator key — allows navigation from outside the widget tree
/// (e.g. the 401 session-expiry handler in ApiClient).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Global scaffold messenger key — allows SnackBars from outside the widget tree.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Main Entry Point
///
/// Flow:
/// 1. Welcome Screen (app features + Login/Register button)
/// 2. Login or Register Screen
/// 3. Map Screen (after successful auth)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for offline storage
  await StorageService.initialize();

  // Start listening for connectivity changes so queued reports are automatically
  // synced when the device comes back online.
  SyncService().startListening();

  // Global 401 handler: when any authenticated request is rejected by the server
  // (e.g. after a backend redeploy wipes the token database), clear the local
  // session and navigate the user back to the login screen.
  ApiClient.onUnauthorized = () async {
    await AuthService().clearLocalSessionOnly();
    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Session expired. Please log in again.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 4),
      ),
    );
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  };

  runApp(const EvacuationApp());
}

class EvacuationApp extends StatelessWidget {
  const EvacuationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Evacuation Route System',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 2,
          backgroundColor: Colors.blue[800],
          foregroundColor: Colors.white,
        ),
      ),
      // Restore session from token when possible (avoids login after camera/gallery / process restart)
      home: const AuthGateScreen(),
    );
  }
}
