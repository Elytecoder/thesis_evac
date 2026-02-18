import 'package:flutter/material.dart';
import 'core/storage/storage_service.dart';
import 'ui/screens/welcome_screen.dart';

/// Main Entry Point
///
/// CURRENT: Shows welcome screen with login/register
///
/// Flow:
/// 1. Welcome Screen (app features + Login/Register button)
/// 2. Login or Register Screen
/// 3. Map Screen (after successful auth)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive for offline storage
  await StorageService.initialize();
  
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
      // Start with welcome screen
      home: const WelcomeScreen(),
    );
  }
}
