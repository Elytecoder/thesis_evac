import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../models/evacuation_center.dart';
import '../../models/route.dart' as app_route;
import '../../features/routing/routing_service.dart';
import 'route_danger_details_screen.dart';
import 'live_navigation_screen.dart';

/// Screen showing 3 calculated routes with risk levels
class RoutesSelectionScreen extends StatefulWidget {
  final EvacuationCenter evacuationCenter;
  final LatLng userLocation;

  const RoutesSelectionScreen({
    super.key,
    required this.evacuationCenter,
    required this.userLocation,
  });

  @override
  State<RoutesSelectionScreen> createState() => _RoutesSelectionScreenState();
}

class _RoutesSelectionScreenState extends State<RoutesSelectionScreen> {
  final RoutingService _routingService = RoutingService();
  List<app_route.Route>? _routes;
  bool _isLoading = true;
  app_route.RouteCalculationResult? _routeResult;
  bool _noSafeRouteModalDismissed = false;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    try {
      final result = await _routingService.calculateRoutes(
        startLat: widget.userLocation.latitude,
        startLng: widget.userLocation.longitude,
        evacuationCenterId: widget.evacuationCenter.id,
        evacuationCenter: widget.evacuationCenter,
      );

      if (mounted) {
        setState(() {
          _routeResult = result;
          _routes = result.routes;
          _isLoading = false;
        });
        if (result.noSafeRoute && !_noSafeRouteModalDismissed) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _showNoSafeRouteModal(result));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to calculate routes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showNoSafeRouteModal(app_route.RouteCalculationResult result) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange[700]),
        title: const Text('No Safe Route Available'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.message ?? 'All routes to this evacuation center are currently high-risk.'),
              if (result.recommendedAction != null) ...[
                const SizedBox(height: 12),
                Text(
                  result.recommendedAction!,
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800]),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _noSafeRouteModalDismissed = true);
              Navigator.of(ctx).pop();
            },
            child: const Text('View Routes Anyway'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _noSafeRouteModalDismissed = true);
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(); // Back to evacuation center list
            },
            child: const Text('Try Other Evacuation Centers'),
          ),
        ],
      ),
    );
  }

  void _onRouteSelected(app_route.Route route) {
    if (route.riskLevel == app_route.RiskLevel.green) {
      // Safe route - launch live navigation with the backend route
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LiveNavigationScreen(
            startLocation: widget.userLocation,
            destination: widget.evacuationCenter,
            selectedRoute: route,
          ),
        ),
      );
    } else {
      // Dangerous route - show warning
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RouteDangerDetailsScreen(
            route: route,
            evacuationCenter: widget.evacuationCenter,
            safeAlternative: _routes?.first,
          ),
        ),
      ).then((result) {
        if (result != null) {
          // If user accepts the risky route, start navigation with that route
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LiveNavigationScreen(
                startLocation: widget.userLocation,
                destination: widget.evacuationCenter,
                selectedRoute: route,
              ),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Routes to Evacuation Center'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Calculating safest routes...'),
                ],
              ),
            )
          : Column(
              children: [
                // Destination header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  color: Colors.red[600],
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Destination',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                widget.evacuationCenter.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Available routes header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Available Routes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_routes?.length ?? 0} Routes',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Routes list – show all returned routes (2–3 when backend provides alternatives)
                Expanded(
                  child: _routes == null || _routes!.isEmpty
                      ? const Center(
                          child: Text('No routes available'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _routes!.length,
                          itemBuilder: (context, index) {
                            final route = _routes![index];
                            return _buildRouteCard(route, index);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  /// Backend sends total_distance in meters. Return km for display; if 0, compute from path.
  double _displayDistanceKm(app_route.Route route) {
    if (route.totalDistance > 0) {
      return route.totalDistance / 1000;
    }
    if (route.path.length < 2) return 0;
    double meters = 0;
    for (int i = 1; i < route.path.length; i++) {
      meters += Geolocator.distanceBetween(
        route.path[i - 1].latitude,
        route.path[i - 1].longitude,
        route.path[i].latitude,
        route.path[i].longitude,
      );
    }
    return meters / 1000;
  }

  /// Backend total_risk is sum of segment risks (can exceed 1). Cap at 1 for display (0–100%).
  double _displayRisk(app_route.Route route) {
    return route.totalRisk.clamp(0.0, 1.0);
  }

  Widget _buildRouteCard(app_route.Route route, int index) {
    final isGreen = route.riskLevel == app_route.RiskLevel.green;
    final isYellow = route.riskLevel == app_route.RiskLevel.yellow;
    final isRed = route.riskLevel == app_route.RiskLevel.red;
    final isHighRisk = route.riskLabel == 'High Risk';
    final possiblyBlocked = route.possiblyBlocked;

    final distanceKm = _displayDistanceKm(route);
    final riskForDisplay = _displayRisk(route);

    Color bgColor = isGreen
        ? Colors.green[50]!
        : (isYellow ? Colors.yellow[50]! : Colors.red[50]!);
    Color borderColor = isGreen
        ? Colors.green[200]!
        : (isYellow ? Colors.yellow[200]! : Colors.red[200]!);
    Color iconColor = isGreen
        ? Colors.green[700]!
        : (isYellow ? Colors.orange[700]! : Colors.red[700]!);

    String routeName = 'Route ${index + 1}';
    if (index == 0 && !isHighRisk) routeName += ' (Safest)';
    else if (isHighRisk) routeName += ' (${route.riskLabel})';
    else routeName += ' (${route.riskLabel})';
    String routeDesc = isGreen
        ? 'Lowest risk – recommended'
        : (isYellow
            ? 'Moderate risk – proceed with caution'
            : 'Higher risk – avoid if possible');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isGreen
                    ? Icons.check_circle
                    : (isYellow ? Icons.warning_amber : Icons.error),
                color: iconColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            routeName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: iconColor,
                            ),
                          ),
                        ),
                        if (possiblyBlocked) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Possibly Blocked',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.red[800],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      routeDesc,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.straighten, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        const Text(
                          'Distance',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${distanceKm.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        const Text(
                          'Risk',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(riskForDisplay * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Verified hazards & road risk',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: riskForDisplay,
              backgroundColor: Colors.grey[200],
              color: iconColor,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _onRouteSelected(route),
              style: ElevatedButton.styleFrom(
                backgroundColor: isGreen ? Colors.green[600] : (isYellow ? Colors.orange[600] : Colors.red[600]),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isGreen ? Icons.navigation : Icons.info_outline),
                  const SizedBox(width: 8),
                  Text(
                    isGreen ? 'Start Navigation' : 'View Details',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
