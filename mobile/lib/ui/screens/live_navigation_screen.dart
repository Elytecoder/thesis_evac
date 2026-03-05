import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/evacuation_center.dart';
import '../../models/navigation_route.dart';
import '../../models/navigation_step.dart';
import '../../models/route_segment.dart';
import '../../features/navigation/gps_tracking_service.dart';
import '../../features/navigation/voice_guidance_service.dart';
import '../../features/navigation/risk_aware_routing_service.dart';
import '../widgets/navigation/top_instruction_banner.dart';
import '../widgets/navigation/bottom_eta_panel.dart';
import 'report_hazard_screen.dart';

/// Enhanced Live Turn-by-Turn Navigation Screen
/// Waze/Google Maps style with smooth animations
class LiveNavigationScreen extends StatefulWidget {
  final LatLng startLocation;
  final EvacuationCenter destination;

  const LiveNavigationScreen({
    super.key,
    required this.startLocation,
    required this.destination,
  });

  @override
  State<LiveNavigationScreen> createState() => _LiveNavigationScreenState();
}

class _LiveNavigationScreenState extends State<LiveNavigationScreen>
    with TickerProviderStateMixin {
  // Services
  final GPSTrackingService _gpsService = GPSTrackingService();
  final VoiceGuidanceService _voiceService = VoiceGuidanceService();
  final RiskAwareRoutingService _routingService = RiskAwareRoutingService();
  final MapController _mapController = MapController();

  // State
  NavigationRoute? _currentRoute;
  LatLng? _userLocation;
  NavigationStep? _currentStep;
  RouteSegment? _currentHighRiskSegment;
  bool _isLoading = true;
  bool _hasArrived = false;
  bool _isRerouting = false;
  bool _voiceEnabled = true;

  // Streams
  StreamSubscription<LatLng>? _locationSubscription;

  // Distance tracking
  double _distanceToNextStep = 0.0;

  // Animation controllers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Camera animation
  double _currentBearing = 0.0;
  Timer? _cameraUpdateTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeNavigation();
  }

  /// Initialize animations
  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  /// Initialize navigation system
  Future<void> _initializeNavigation() async {
    try {
      // Initialize voice
      await _voiceService.initialize();

      // Calculate initial route
      await _calculateRoute();

      // Start GPS tracking
      final started = await _gpsService.startTracking();
      if (!started) {
        _showError('Failed to start GPS tracking. Please enable location.');
        return;
      }

      // Listen to location updates
      _locationSubscription = _gpsService.locationStream.listen(_onLocationUpdate);

      setState(() {
        _isLoading = false;
      });

      // Start smooth camera updates
      _startCameraUpdates();

      // Speak initial instruction
      if (_currentStep != null) {
        await _voiceService.speakTurnInstruction(
          _currentStep!.maneuver,
          _currentStep!.distanceToNext,
        );
      }
    } catch (e) {
      print('❌ Navigation initialization failed: $e');
      _showError('Failed to start navigation: $e');
    }
  }

  /// Calculate route
  Future<void> _calculateRoute() async {
    try {
      final destinationLatLng = LatLng(
        widget.destination.latitude,
        widget.destination.longitude,
      );

      final route = await _routingService.calculateSafestRoute(
        start: widget.startLocation,
        destination: destinationLatLng,
        evacuationCenter: widget.destination,
      );

      setState(() {
        _currentRoute = route;
      });

      // Update current step
      if (_userLocation != null) {
        _updateCurrentStep(_userLocation!);
      }

      print('✅ Route calculated: ${route.steps.length} steps, ${route.getFormattedDistance()}');
    } catch (e) {
      print('❌ Route calculation failed: $e');
      throw e;
    }
  }

  /// Handle GPS location updates
  void _onLocationUpdate(LatLng location) async {
    if (_hasArrived || _currentRoute == null) return;

    setState(() {
      _userLocation = location;
    });

    // Check if arrived
    final destinationLatLng = LatLng(
      widget.destination.latitude,
      widget.destination.longitude,
    );
    if (_routingService.hasReachedDestination(
      userLocation: location,
      destination: destinationLatLng,
    )) {
      _onArrival();
      return;
    }

    // Check for high-risk segment
    final highRiskSegment = _routingService.getCurrentHighRiskSegment(
      userLocation: location,
      route: _currentRoute!,
    );
    if (highRiskSegment != null && _currentHighRiskSegment != highRiskSegment) {
      setState(() {
        _currentHighRiskSegment = highRiskSegment;
      });
      await _onHighRiskDetected();
      return;
    }

    // Check for deviation
    if (_routingService.hasDeviatedFromRoute(
      userLocation: location,
      route: _currentRoute!,
    )) {
      await _onDeviationDetected();
      return;
    }

    // Update current step
    _updateCurrentStep(location);
  }

  /// Update current navigation step
  void _updateCurrentStep(LatLng location) {
    if (_currentRoute == null) return;

    final step = _routingService.getCurrentStep(
      userLocation: location,
      route: _currentRoute!,
    );

    if (step == null) return;

    final distanceToStep = _routingService.getDistanceToNextStep(
      userLocation: location,
      step: step,
    );

    // Check if we need to advance to next step
    if (distanceToStep < 20 && step.stepIndex < _currentRoute!.steps.length - 1) {
      // Move to next step
      final nextStep = _currentRoute!.steps[step.stepIndex + 1];
      
      setState(() {
        _currentStep = nextStep;
        _distanceToNextStep = nextStep.distanceToNext;
      });

      // Speak instruction for next step
      _voiceService.speakTurnInstruction(
        nextStep.maneuver,
        nextStep.distanceToNext,
      );
    } else {
      setState(() {
        _currentStep = step;
        _distanceToNextStep = distanceToStep;
      });
    }
  }

  /// Start smooth camera updates
  void _startCameraUpdates() {
    _cameraUpdateTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (_userLocation != null && mounted) {
        _smoothCameraFollow();
      }
    });
  }

  /// Smooth camera follow with rotation simulation
  void _smoothCameraFollow() {
    if (_userLocation == null) return;

    try {
      // Calculate bearing to next point if available
      if (_currentRoute != null && _currentRoute!.polyline.isNotEmpty) {
        // Find closest point on route ahead of user
        final userIdx = _findClosestPointIndex(_userLocation!, _currentRoute!.polyline);
        if (userIdx < _currentRoute!.polyline.length - 1) {
          final nextPoint = _currentRoute!.polyline[userIdx + 1];
          _currentBearing = _gpsService.calculateBearing(_userLocation!, nextPoint);
        }
      }

      // Smooth camera movement with slight zoom in for 3D feel
      _mapController.move(_userLocation!, 17.0);
      
      // Note: flutter_map doesn't support true rotation, but we maintain bearing for future use
    } catch (e) {
      // Map controller not ready
    }
  }

  /// Find closest point index on polyline
  int _findClosestPointIndex(LatLng userLocation, List<LatLng> polyline) {
    double minDistance = double.infinity;
    int closestIndex = 0;

    for (int i = 0; i < polyline.length; i++) {
      final distance = _gpsService.calculateDistance(userLocation, polyline[i]);
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    return closestIndex;
  }

  /// Handle arrival at destination
  void _onArrival() async {
    setState(() {
      _hasArrived = true;
    });

    _cameraUpdateTimer?.cancel();
    await _voiceService.speakArrival();
    
    if (mounted) {
      _showSuccessDialog();
    }
  }

  /// Handle high-risk segment detection
  Future<void> _onHighRiskDetected() async {
    print('🚨 HIGH RISK DETECTED - Triggering reroute');
    
    // Speak warning
    await _voiceService.speakRiskWarning();

    // Vibrate device
    HapticFeedback.heavyImpact();

    // Trigger reroute if allowed
    if (_routingService.canReroute()) {
      await _reroute();
    }
  }

  /// Handle route deviation
  Future<void> _onDeviationDetected() async {
    print('⚠️ DEVIATION DETECTED - Triggering reroute');
    
    // Speak warning
    await _voiceService.speakDeviationWarning();

    // Trigger reroute if allowed
    if (_routingService.canReroute()) {
      await _reroute();
    }
  }

  /// Reroute to destination
  Future<void> _reroute() async {
    if (_isRerouting || _userLocation == null) return;

    setState(() {
      _isRerouting = true;
    });

    _routingService.markReroute();

    try {
      final destinationLatLng = LatLng(
        widget.destination.latitude,
        widget.destination.longitude,
      );

      final newRoute = await _routingService.calculateSafestRoute(
        start: _userLocation!,
        destination: destinationLatLng,
        evacuationCenter: widget.destination,
      );

      setState(() {
        _currentRoute = newRoute;
        _currentHighRiskSegment = null;
        _isRerouting = false;
      });

      // Update current step
      _updateCurrentStep(_userLocation!);

      print('✅ Rerouted successfully');
    } catch (e) {
      print('❌ Reroute failed: $e');
      setState(() {
        _isRerouting = false;
      });
    }
  }

  /// Toggle voice guidance
  void _toggleVoice() {
    setState(() {
      _voiceEnabled = !_voiceEnabled;
      _voiceService.setEnabled(_voiceEnabled);
    });
  }

  /// Handle long press on map - Report hazard during navigation
  void _onLongPressMap(TapPosition tapPosition, LatLng location) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Icon(Icons.warning_amber, size: 48, color: Colors.orange[700]),
            const SizedBox(height: 16),
            const Text(
              'Report Hazard',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Location: ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Navigation will continue in the background while you report.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReportHazardScreen(
                        location: location,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.report),
                label: const Text('Report Hazard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  /// Cancel navigation
  void _cancelNavigation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Navigation'),
        content: const Text('Are you sure you want to stop navigation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close navigation screen
            },
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// Show error message
  void _showError(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// Show success dialog
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Arrived!'),
          ],
        ),
        content: Text(
          'You have arrived at ${widget.destination.name}. Stay safe!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close navigation screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _cameraUpdateTimer?.cancel();
    _pulseController.dispose();
    _gpsService.stopTracking();
    _voiceService.dispose();
    _routingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 24),
              Text(
                'Starting navigation...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map (edge-to-edge)
          _buildMap(),

          // Top instruction banner - positioned at top only
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: TopInstructionBanner(
                currentStep: _currentStep,
                distanceToNext: _distanceToNextStep,
              ),
            ),
          ),

          // High-risk warning banner (animated) - positioned at top
          if (_currentHighRiskSegment != null)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: _buildHighRiskBanner(),
            ),

          // Rerouting indicator (animated) - positioned at top
          if (_isRerouting)
            Positioned(
              top: 150,
              left: 0,
              right: 0,
              child: _buildReroutingIndicator(),
            ),

          // Bottom ETA panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: BottomETAPanel(
                route: _currentRoute,
                voiceEnabled: _voiceEnabled,
                onVoiceToggle: _toggleVoice,
                onCancel: _cancelNavigation,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build full-screen map
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _userLocation ?? widget.startLocation,
        initialZoom: 17.0,
        minZoom: 12.0,
        maxZoom: 19.0,
        onLongPress: _onLongPressMap,
      ),
      children: [
        // Map tiles
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.evacroute.mobile',
        ),

        // Route polyline (thick with white outline)
        if (_currentRoute != null) ...[
          // White outline (bottom layer)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _currentRoute!.polyline,
                color: Colors.white,
                strokeWidth: 12.0,
                borderStrokeWidth: 0,
              ),
            ],
          ),
          // Colored route (top layer)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _currentRoute!.polyline,
                color: _getRouteColor(_currentRoute!.overallRiskLevel),
                strokeWidth: 10.0,
                borderStrokeWidth: 0,
              ),
            ],
          ),
        ],

        // Hazard markers with pulsing animation
        if (_currentRoute != null)
          MarkerLayer(
            markers: _buildHazardMarkers(),
          ),

        // User arrow marker (3D style, positioned in bottom third)
        if (_userLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _userLocation!,
                width: 60,
                height: 60,
                alignment: Alignment.center,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Transform.rotate(
                        angle: _currentBearing * math.pi / 180,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Blue glow
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              // Navigation arrow
                              Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.navigation,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

        // Destination marker
        MarkerLayer(
          markers: [
            Marker(
              point: LatLng(
                widget.destination.latitude,
                widget.destination.longitude,
              ),
              width: 60,
              height: 60,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build hazard markers with pulsing animation
  List<Marker> _buildHazardMarkers() {
    if (_currentRoute == null) return [];

    final markers = <Marker>[];
    final highRiskSegments = _currentRoute!.segments
        .where((s) => s.riskLevel == 'high')
        .toList();

    for (final segment in highRiskSegments) {
      markers.add(
        Marker(
          point: segment.start,
          width: 40,
          height: 40,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 15 * _pulseAnimation.value,
                        spreadRadius: 3 * _pulseAnimation.value,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.warning,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return markers;
  }

  /// Get route color based on risk level
  Color _getRouteColor(String riskLevel) {
    switch (riskLevel) {
      case 'safe':
        return Colors.green;
      case 'moderate':
        return Colors.orange;
      case 'high':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  /// Build high-risk warning banner with smooth animation
  Widget _buildHighRiskBanner() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 0.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -value * 100),
          child: Opacity(
            opacity: 1 - value,
            child: child,
          ),
        );
      },
      child: Positioned(
        top: MediaQuery.of(context).padding.top + 140,
        left: 0,
        right: 0,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HIGH RISK AREA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rerouting to safer path...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build rerouting indicator with animation
  Widget _buildReroutingIndicator() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 140,
      left: 0,
      right: 0,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: 0.0),
        duration: const Duration(milliseconds: 300),
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, -value * 100),
            child: Opacity(
              opacity: 1 - value,
              child: child,
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
              ),
            ],
          ),
          child: const Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Recalculating route...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
