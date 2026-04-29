import 'dart:async';

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

class _RoutesSelectionScreenState extends State<RoutesSelectionScreen>
    with SingleTickerProviderStateMixin {
  final RoutingService _routingService = RoutingService();
  List<app_route.Route>? _routes;
  bool _isLoading = true;
  bool _noSafeRouteModalDismissed = false;
  bool _onlyOnePracticalRoute = false;

  // Prevents double-tap: tracks which route card is currently being opened.
  int? _openingRouteIndex;

  // Animated loading text — cycles through steps while calculating routes.
  late AnimationController _loadingTextController;
  int _loadingStep = 0;
  Timer? _loadingTimer;
  static const _loadingSteps = [
    'Fetching road network…',
    'Analysing verified hazards…',
    'Calculating risk scores…',
    'Finding safest routes…',
    'Almost ready…',
  ];

  @override
  void initState() {
    super.initState();
    _loadingTextController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _startLoadingTextCycle();
    _loadRoutes();
  }

  void _startLoadingTextCycle() {
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (!mounted || !_isLoading) return;
      setState(() {
        _loadingStep = (_loadingStep + 1) % _loadingSteps.length;
      });
    });
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _loadingTextController.dispose();
    super.dispose();
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
          _routes = result.routes;
          _isLoading = false;
          _onlyOnePracticalRoute = result.onlyOnePracticalRoute;
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

  void _onRouteSelected(app_route.Route route, int index) {
    // Prevent double-tap: if already opening a card, ignore.
    if (_openingRouteIndex != null) return;
    setState(() => _openingRouteIndex = index);

    Future<void> doNavigate() async {
      if (route.riskLevel == app_route.RiskLevel.green) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveNavigationScreen(
              startLocation: widget.userLocation,
              destination: widget.evacuationCenter,
              selectedRoute: route,
            ),
          ),
        );
      } else {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RouteDangerDetailsScreen(
              route: route,
              evacuationCenter: widget.evacuationCenter,
              safeAlternative: _routes?.first,
            ),
          ),
        );
        if (result != null && mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LiveNavigationScreen(
                startLocation: widget.userLocation,
                destination: widget.evacuationCenter,
                selectedRoute: route,
              ),
            ),
          );
        }
      }
      if (mounted) setState(() => _openingRouteIndex = null);
    }

    doNavigate();
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
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator(
                        color: Color(0xFFD32F2F),
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Finding Safest Route',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.2),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: Text(
                      _loadingSteps[_loadingStep],
                      key: ValueKey(_loadingStep),
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ),
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

                if (_onlyOnePracticalRoute) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Only one practical safe route found. Alternative routes were too long and have been hidden.',
                              style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Routes list – show all returned routes (2–3 when backend provides alternatives)
                Expanded(
                  child: _routes == null || _routes!.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.route_outlined, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              const Text(
                                'No routes available',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 40),
                                child: Text(
                                  'All roads to this center may be blocked or unreachable. Try another evacuation center.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                ),
                              ),
                              const SizedBox(height: 24),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('Choose Another Center'),
                              ),
                            ],
                          ),
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
    final isHighRisk = isRed;
    final possiblyBlocked = route.possiblyBlocked;
    final isRecommended = index == 0 && !isHighRisk;
    final isCurrentlyOpening = _openingRouteIndex == index;

    final distanceKm = _displayDistanceKm(route);
    final riskForDisplay = _displayRisk(route);

    Color bgColor = isGreen
        ? Colors.green[50]!
        : (isYellow ? Colors.yellow[50]! : Colors.red[50]!);
    Color borderColor = isGreen
        ? Colors.green[400]!
        : (isYellow ? Colors.orange[300]! : Colors.red[300]!);
    Color iconColor = isGreen
        ? Colors.green[700]!
        : (isYellow ? Colors.orange[700]! : Colors.red[700]!);

    final String routeName = 'Route ${index + 1}';
    String routeDesc = isGreen
        ? 'Lowest risk — recommended evacuation path'
        : (isYellow
            ? 'Moderate risk — proceed with caution'
            : 'Higher risk — avoid if possible');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isRecommended ? Colors.white : bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRecommended ? Colors.green[500]! : borderColor,
          width: isRecommended ? 2.5 : 1.5,
        ),
        boxShadow: isRecommended
            ? [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: icon + route name + badges
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isGreen
                        ? Icons.check_circle_rounded
                        : (isYellow ? Icons.warning_amber_rounded : Icons.cancel_rounded),
                    color: iconColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Route name + recommended badge
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              routeName,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[900],
                              ),
                            ),
                          ),
                          if (isRecommended) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green[600],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'RECOMMENDED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                          if (possiblyBlocked) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.red[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'MAY BE BLOCKED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[800],
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        routeDesc,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            // Divider
            Divider(height: 1, color: Colors.grey[200]),
            const SizedBox(height: 14),

            // Stats row: Distance | Risk Level
            IntrinsicHeight(
              child: Row(
                children: [
                  _statCell(
                    Icons.straighten_rounded,
                    'Distance',
                    distanceKm >= 1
                        ? '${distanceKm.toStringAsFixed(2)} km'
                        : '${(distanceKm * 1000).toStringAsFixed(0)} m',
                    Colors.blue[700]!,
                  ),
                  VerticalDivider(width: 1, color: Colors.grey[200]),
                  _statCell(
                    Icons.shield_rounded,
                    'Risk Level',
                    isGreen
                        ? 'Safe Route'
                        : (isYellow ? 'Moderate Risk' : 'High Risk'),
                    iconColor,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            // Risk progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: riskForDisplay,
                backgroundColor: Colors.grey[200],
                color: iconColor,
                minHeight: 6,
              ),
            ),

            // Route explanation — shown when the backend provides context.
            // Uses user-friendly language; never mentions model names.
            if (route.explanation.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 15, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        route.explanation,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // CTA button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _openingRouteIndex != null
                    ? null
                    : () => _onRouteSelected(route, index),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCurrentlyOpening
                      ? Colors.grey[400]
                      : (isGreen
                          ? Colors.green[600]
                          : (isYellow ? Colors.orange[600] : Colors.red[600])),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: isRecommended ? 3 : 1,
                ),
                child: isCurrentlyOpening
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(isGreen ? Icons.navigation_rounded : Icons.info_outline),
                          const SizedBox(width: 8),
                          Text(
                            isGreen ? 'Start Navigation' : 'View Details',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCell(IconData icon, String label, String value, Color valueColor) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Icon(icon, size: 16, color: Colors.grey[500]),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
