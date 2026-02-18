/// Simple test to verify all services work with mock data.
/// 
/// Run this to confirm infrastructure is working:
/// 1. Copy this code into a new screen or main.dart temporarily
/// 2. Call testAllServices() 
/// 3. Check console for output
/// 
/// Expected output:
/// - Authentication: User logged in successfully
/// - Routing: 3 evacuation centers and 3 routes
/// - Hazards: Baseline hazards and submitted report

import 'package:flutter/material.dart';
import 'package:mobile/features/authentication/auth_service.dart';
import 'package:mobile/features/routing/routing_service.dart';
import 'package:mobile/features/hazards/hazard_service.dart';

/// Test all services with mock data
Future<void> testAllServices() async {
  print('\n🧪 TESTING ALL SERVICES WITH MOCK DATA\n');
  print('=' * 50);
  
  // Test 1: Authentication
  print('\n1️⃣ TESTING AUTHENTICATION SERVICE');
  print('-' * 50);
  try {
    final authService = AuthService();
    final user = await authService.login('test_user', 'password123');
    
    print('✅ Login successful!');
    print('   User: ${user.fullName}');
    print('   Email: ${user.email}');
    print('   Role: ${user.role.value}');
    print('   Token: ${user.authToken?.substring(0, 20)}...');
  } catch (e) {
    print('❌ Authentication test failed: $e');
  }
  
  // Test 2: Routing Service
  print('\n2️⃣ TESTING ROUTING SERVICE');
  print('-' * 50);
  try {
    final routingService = RoutingService();
    
    // Get evacuation centers
    final centers = await routingService.getEvacuationCenters();
    print('✅ Evacuation centers loaded: ${centers.length}');
    for (var center in centers) {
      print('   - ${center.name}');
    }
    
    // Calculate routes
    print('\n   Calculating routes (this takes ~2 seconds)...');
    final routes = await routingService.calculateRoutes(
      startLat: 12.6690,
      startLng: 123.8750,
      evacuationCenterId: centers[0].id,
      evacuationCenter: centers[0],
    );
    
    print('✅ Routes calculated: ${routes.length}');
    for (var i = 0; i < routes.length; i++) {
      print('   Route ${i + 1}:');
      print('     - Distance: ${routes[i].totalDistance.toStringAsFixed(1)}m');
      print('     - Risk: ${routes[i].totalRisk.toStringAsFixed(2)}');
      print('     - Level: ${routes[i].riskLevel.value}');
      print('     - Path points: ${routes[i].path.length}');
    }
  } catch (e) {
    print('❌ Routing test failed: $e');
  }
  
  // Test 3: Hazard Service
  print('\n3️⃣ TESTING HAZARD SERVICE');
  print('-' * 50);
  try {
    final hazardService = HazardService();
    
    // Get baseline hazards
    final baselineHazards = await hazardService.getBaselineHazards();
    print('✅ Baseline hazards loaded: ${baselineHazards.length}');
    for (var hazard in baselineHazards) {
      print('   - ${hazard.hazardType} (severity: ${hazard.severity})');
    }
    
    // Submit hazard report
    print('\n   Submitting hazard report...');
    final report = await hazardService.submitHazardReport(
      hazardType: 'flood',
      latitude: 12.6700,
      longitude: 123.8755,
      description: 'Test report: Heavy flooding observed',
    );
    
    print('✅ Hazard report submitted!');
    print('   Report ID: ${report.id}');
    print('   Status: ${report.status.value}');
    print('   Naive Bayes Score: ${report.naiveBayesScore}');
    print('   Consensus Score: ${report.consensusScore}');
    
    // Get pending reports (MDRRMO feature)
    final pendingReports = await hazardService.getPendingReports();
    print('\n✅ Pending reports (MDRRMO): ${pendingReports.length}');
    for (var report in pendingReports) {
      print('   - ${report.hazardType} by User ${report.userId}');
    }
  } catch (e) {
    print('❌ Hazard service test failed: $e');
  }
  
  // Summary
  print('\n' + '=' * 50);
  print('🎉 ALL TESTS COMPLETED!');
  print('\nIf you see ✅ for all tests:');
  print('  - Services are working correctly');
  print('  - Mock data is being returned');
  print('  - Ready to integrate into UI');
  print('\nTo switch to real API:');
  print('  - Open lib/core/config/api_config.dart');
  print('  - Change useMockData to false');
  print('  - Update baseUrl with your backend IP');
  print('=' * 50 + '\n');
}

/// Widget that tests services on button press
class ServiceTestScreen extends StatelessWidget {
  const ServiceTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Test'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.science, size: 64, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'Test All Services',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'This will test Authentication, Routing, and Hazard services with mock data.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                // Show loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
                
                // Run tests
                await testAllServices();
                
                // Hide loading
                if (context.mounted) {
                  Navigator.pop(context);
                  
                  // Show result
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tests complete! Check console output.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Run Tests'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Check Console'),
                    content: const Text(
                      'After running tests, check your IDE console or terminal for detailed output.\n\n'
                      'You should see:\n'
                      '✅ Login successful\n'
                      '✅ Evacuation centers loaded\n'
                      '✅ Routes calculated\n'
                      '✅ Hazard report submitted',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('How to view results?'),
            ),
          ],
        ),
      ),
    );
  }
}
