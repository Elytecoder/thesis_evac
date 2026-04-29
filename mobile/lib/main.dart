import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'core/app_keys.dart';
import 'core/network/api_client.dart';
import 'core/storage/storage_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/notification_service.dart';
import 'features/authentication/auth_service.dart';
import 'ui/screens/auth_gate_screen.dart';
import 'ui/screens/welcome_screen.dart';

/// Main Entry Point
///
/// Flow:
/// 1. Welcome Screen (app features + Login/Register button)
/// 2. Login or Register Screen
/// 3. Map Screen (after successful auth)
bool _firebaseEnabled = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for offline storage
  await StorageService.initialize();

  // Initialize Firebase for push notifications.
  // Web requires explicit FirebaseOptions; if missing, run the app without push
  // instead of crashing to a white screen.
  try {
    await Firebase.initializeApp();
    _firebaseEnabled = true;
  } catch (e) {
    _firebaseEnabled = false;
    debugPrint('Firebase init skipped: $e');
    if (!kIsWeb) {
      rethrow;
    }
  }

  // Background handler is only relevant for non-web platforms.
  if (_firebaseEnabled && !kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

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

class EvacuationApp extends StatefulWidget {
  const EvacuationApp({super.key});

  @override
  State<EvacuationApp> createState() => _EvacuationAppState();
}

class _EvacuationAppState extends State<EvacuationApp> {
  @override
  void initState() {
    super.initState();
    // Initialize push notifications after the first frame so the navigator
    // key is attached and navigation from notification taps works correctly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_firebaseEnabled) {
        NotificationService.initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HAZNAV',
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
