import 'package:flutter/material.dart';
import 'core/storage/storage_service.dart';
import 'core/services/sync_service.dart';
import 'ui/screens/auth_gate_screen.dart';

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
  
  runApp(const EvacuationApp());
}

class EvacuationApp extends StatelessWidget {
  const EvacuationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Evacuation Route System',
      debugShowCheckedModeBanner: false,
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
