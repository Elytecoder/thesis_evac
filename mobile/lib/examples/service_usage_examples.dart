/// Example: How to use the new services in your UI
/// 
/// This file shows how to integrate the mock services into your UI components.
/// Copy these examples into your screens/widgets as needed.

import 'package:flutter/material.dart';
import 'package:mobile/features/authentication/auth_service.dart';
import 'package:mobile/features/routing/routing_service.dart';
import 'package:mobile/features/hazards/hazard_service.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/models/route.dart' as app_route;

class ServiceUsageExamples {
  // --- AUTHENTICATION EXAMPLE ---
  
  /// Example: Login button handler
  Future<void> handleLogin(BuildContext context, String username, String password) async {
    final authService = AuthService();
    
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      
      // Login (currently returns mock user)
      final User user = await authService.login(username, password);
      
      // Hide loading
      if (context.mounted) Navigator.pop(context);
      
      // Success!
      print('Logged in as: ${user.fullName}');
      print('Role: ${user.role.value}');
      print('Token: ${user.authToken}');
      
      // Navigate to main screen or show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Welcome, ${user.fullName}!')),
        );
      }
      
    } catch (e) {
      // Hide loading
      if (context.mounted) Navigator.pop(context);
      
      // Show error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // --- ROUTING EXAMPLE ---
  
  /// Example: Calculate routes when user selects evacuation center
  Future<void> handleCalculateRoutes(
    BuildContext context,
    double startLat,
    double startLng,
    int evacuationCenterId,
  ) async {
    final routingService = RoutingService();
    
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Calculating safest routes...'),
            ],
          ),
        ),
      );
      
      // Get evacuation center details
      final center = await routingService.getEvacuationCenterById(evacuationCenterId);
      
      if (center == null) {
        throw Exception('Evacuation center not found');
      }
      
      // Calculate routes (returns 3 routes sorted by safety)
      final List<app_route.Route> routes = await routingService.calculateRoutes(
        startLat: startLat,
        startLng: startLng,
        evacuationCenterId: evacuationCenterId,
        evacuationCenter: center,
      );
      
      // Hide loading
      if (context.mounted) Navigator.pop(context);
      
      // Success! Display routes on map
      print('Got ${routes.length} routes:');
      for (var i = 0; i < routes.length; i++) {
        print('Route ${i + 1}: ${routes[i].riskLevel.value} '
              '(${routes[i].totalDistance.toStringAsFixed(0)}m, '
              'risk: ${routes[i].totalRisk.toStringAsFixed(2)})');
      }
      
      // TODO: Draw routes on map with colors
      // - routes[0] = Safest (usually Green)
      // - routes[1] = Alternative (Green/Yellow)
      // - routes[2] = Shorter but riskier (Yellow/Red)
      
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to calculate routes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // --- HAZARD REPORTING EXAMPLE ---
  
  /// Example: Submit hazard report button handler
  Future<void> handleReportHazard(
    BuildContext context,
    String hazardType,
    double latitude,
    double longitude,
    String description,
  ) async {
    final hazardService = HazardService();
    
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      
      // Submit report
      final report = await hazardService.submitHazardReport(
        hazardType: hazardType,
        latitude: latitude,
        longitude: longitude,
        description: description,
        // Optional: photoUrl, videoUrl
      );
      
      if (context.mounted) Navigator.pop(context);
      
      // Success!
      print('Report submitted!');
      print('ID: ${report.id}');
      print('Naive Bayes Score: ${report.naiveBayesScore}');
      print('Consensus Score: ${report.consensusScore}');
      print('Status: ${report.status.value}');
      
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Report Submitted'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your ${report.hazardType} report has been submitted.'),
                const SizedBox(height: 8),
                Text('Validation Score: ${(report.naiveBayesScore! * 100).toStringAsFixed(0)}%'),
                Text('Consensus Score: ${(report.consensusScore! * 100).toStringAsFixed(0)}%'),
                const SizedBox(height: 8),
                const Text('MDRRMO will review your report.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // --- LOAD EVACUATION CENTERS EXAMPLE ---
  
  /// Example: Load evacuation centers on map screen init
  Future<void> loadEvacuationCenters() async {
    final routingService = RoutingService();
    
    try {
      final centers = await routingService.getEvacuationCenters();
      
      print('Loaded ${centers.length} evacuation centers:');
      for (var center in centers) {
        print('- ${center.name} (${center.latitude}, ${center.longitude})');
      }
      
      // TODO: Display as markers on map
      
    } catch (e) {
      print('Failed to load evacuation centers: $e');
    }
  }
  
  // --- BASELINE HAZARDS EXAMPLE ---
  
  /// Example: Load baseline hazards (MDRRMO data) for map overlay
  Future<void> loadBaselineHazards() async {
    final hazardService = HazardService();
    
    try {
      final hazards = await hazardService.getBaselineHazards();
      
      print('Loaded ${hazards.length} baseline hazards:');
      for (var hazard in hazards) {
        print('- ${hazard.hazardType} at (${hazard.latitude}, ${hazard.longitude}) '
              'severity: ${hazard.severity}');
      }
      
      // TODO: Display as semi-transparent circles on map
      // Color by severity: red (high), yellow (medium), green (low)
      
    } catch (e) {
      print('Failed to load baseline hazards: $e');
    }
  }
}
