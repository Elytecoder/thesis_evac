import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../models/evacuation_center.dart';
import '../../models/route.dart' as app_route;
import '../../features/routing/routing_service.dart';
import 'route_danger_details_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    try {
      final routes = await _routingService.calculateRoutes(
        startLat: widget.userLocation.latitude,
        startLng: widget.userLocation.longitude,
        evacuationCenterId: widget.evacuationCenter.id,
        evacuationCenter: widget.evacuationCenter,
      );

      if (mounted) {
        setState(() {
          _routes = routes;
          _isLoading = false;
        });
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

  void _onRouteSelected(app_route.Route route) {
    if (route.riskLevel == app_route.RiskLevel.green) {
      // Safe route - start navigation
      Navigator.pop(context, route);
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
          Navigator.pop(context, result);
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

                // Routes list
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

  Widget _buildRouteCard(app_route.Route route, int index) {
    final isGreen = route.riskLevel == app_route.RiskLevel.green;
    final isYellow = route.riskLevel == app_route.RiskLevel.yellow;
    final isRed = route.riskLevel == app_route.RiskLevel.red;

    Color bgColor = isGreen
        ? Colors.green[50]!
        : (isYellow ? Colors.yellow[50]! : Colors.red[50]!);
    Color borderColor = isGreen
        ? Colors.green[200]!
        : (isYellow ? Colors.yellow[200]! : Colors.red[200]!);
    Color iconColor = isGreen
        ? Colors.green[700]!
        : (isYellow ? Colors.orange[700]! : Colors.red[700]!);

    String routeName = isGreen
        ? 'Northern Bypass'
        : (isYellow ? 'Central Avenue' : 'River Road');
    String routeDesc = isGreen
        ? 'Safest route - Elevated roads, no flood zones'
        : (isYellow
            ? 'Some flooding reported, proceed with caution'
            : 'High flood risk - Avoid if possible');

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
                    Text(
                      routeName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: iconColor,
                      ),
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
                      '${route.totalDistance.toStringAsFixed(1)} km',
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
                      '${(route.totalRisk * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: iconColor,
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
              value: route.totalRisk,
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
