import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/map/cached_tile_provider.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/storage/storage_service.dart';
import '../../models/evacuation_center.dart';
import '../../models/hazard_report.dart';
import '../../models/navigation_route.dart';
import '../../models/navigation_step.dart';
import '../../models/route.dart' as app_route;
import '../../models/route_segment.dart';
import '../../features/hazards/hazard_service.dart';
import '../../features/navigation/gps_tracking_service.dart';
import '../../features/navigation/risk_aware_routing_service.dart';
import '../../features/routing/routing_service.dart';
import '../widgets/navigation/top_instruction_banner.dart';
import '../widgets/report_media_preview.dart';
import 'report_hazard_screen.dart';

/// Enhanced Live Turn-by-Turn Navigation Screen
/// Waze/Google Maps style with smooth animations
class LiveNavigationScreen extends StatefulWidget {
  final LatLng startLocation;
  final EvacuationCenter destination;
  /// The backend (Modified Dijkstra + RF) route chosen by the user on the
  /// selection screen.  When provided, this polyline is followed exactly and
  /// OSRM is only used for turn instructions.  When null (e.g. launched
  /// directly), the service falls back to a full OSRM route.
  final app_route.Route? selectedRoute;

  const LiveNavigationScreen({
    super.key,
    required this.startLocation,
    required this.destination,
    this.selectedRoute,
  });

  @override
  State<LiveNavigationScreen> createState() => _LiveNavigationScreenState();
}

class _LiveNavigationScreenState extends State<LiveNavigationScreen>
    with TickerProviderStateMixin {
  // Services
  final GPSTrackingService _gpsService = GPSTrackingService();
  final RiskAwareRoutingService _routingService = RiskAwareRoutingService();
  final HazardService _hazardService = HazardService();
  final MapController _mapController = MapController();

  // ── Navigation state ─────────────────────────────────────────────────────
  NavigationRoute? _currentRoute;
  LatLng? _userLocation;
  NavigationStep? _currentStep;
  RouteSegment? _currentHighRiskSegment;
  List<HazardReport> _verifiedHazards = [];
  List<HazardReport> _pendingHazards = [];
  bool _isLoading = true;
  bool _hasArrived = false;
  bool _isRerouting = false;
  /// When true, camera follows user; when false, user can pan/explore freely.
  bool _followUserLocation = true;

  // Tile provider — caches OSM tiles to disk so the map renders offline.
  final CachedNetworkTileProvider _tileProvider = CachedNetworkTileProvider();

  // ── Streams ──────────────────────────────────────────────────────────────
  StreamSubscription<LatLng>? _locationSubscription;
  StreamSubscription<double>? _headingSubscription;

  // ── Distance tracking ────────────────────────────────────────────────────
  double _distanceToNextStep = 0.0;

  // ── Animation controllers ────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  /// Smoothly interpolates the marker between GPS fixes so it glides rather
  /// than jumping.  Updated via [_animateToLocation].
  late AnimationController _positionController;
  LatLng? _displayLocation; // rendered position (interpolated)
  LatLng? _animFromLocation; // position at animation start

  // ── Camera ───────────────────────────────────────────────────────────────
  double _currentBearing = 0.0;
  Timer? _cameraUpdateTimer;

  // ── Grace period: suppress deviation checks right after navigation starts.
  // GPS accuracy at cold start can be ±50–100 m, causing false reroutes.
  DateTime? _navigationStartTime;
  int _locationUpdateCount = 0;
  static const int _minUpdatesBeforeDeviationCheck = 5;
  static const Duration _deviationGracePeriod = Duration(seconds: 20);

  // ── Stable arrival detection ─────────────────────────────────────────────
  /// Radius (m) within which user is considered to have arrived.
  static const double _arrivalRadiusM = 30.0;
  /// How long user must stay inside the radius before arrival is confirmed.
  /// Prevents GPS jitter false-triggering the arrival modal.
  static const Duration _arrivalConfirmDuration = Duration(seconds: 3);
  /// Timestamp when user first entered the arrival radius (null if outside).
  DateTime? _arrivalEnteredAt;

  // ── Post-arrival state ───────────────────────────────────────────────────
  /// Prevents the arrival modal from appearing more than once per session.
  bool _hasShownArrivalModal = false;
  /// Route polyline opacity — fades to 0.35 after arrival.
  double _routeOpacity = 1.0;
  /// Radius (m) beyond which "you have left the destination" prompt appears.
  static const double _leftDestinationRadiusM = 150.0;
  /// Prevents the "left destination" prompt from appearing repeatedly.
  bool _hasShownLeftDestination = false;

  // ── Trip analytics ───────────────────────────────────────────────────────
  /// Number of reroutes triggered during this session.
  int _rerouteCount = 0;

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

    // Position interpolation controller: 250 ms linear glide between GPS fixes.
    _positionController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    )..addListener(() {
        if (!mounted) return;
        final from = _animFromLocation;
        final to = _userLocation;
        if (from == null || to == null) return;
        final t = _positionController.value;
        setState(() {
          _displayLocation = LatLng(
            from.latitude + (to.latitude - from.latitude) * t,
            from.longitude + (to.longitude - from.longitude) * t,
          );
        });
      });
  }

  /// Smoothly animate the map marker from [_displayLocation] to [target].
  void _animateToLocation(LatLng target) {
    _animFromLocation = _displayLocation ?? target;
    _positionController.forward(from: 0);
  }

  /// Initialize navigation system
  Future<void> _initializeNavigation() async {
    try {
      // Load verified hazards and calculate route in parallel
      await Future.wait([
        _calculateRoute(),
        _loadVerifiedHazards(),
        _loadPendingHazards(),
      ]);

      // Start GPS tracking
      final started = await _gpsService.startTracking();
      if (!started) {
        _showError('Failed to start GPS tracking. Please enable location.');
        return;
      }

      // Listen to location updates
      _locationSubscription = _gpsService.locationStream.listen(_onLocationUpdate);

      // Listen to heading updates for real-time arrow rotation
      _headingSubscription = _gpsService.headingStream.listen((heading) {
        if (mounted) setState(() => _currentBearing = heading);
      });

      setState(() {
        _isLoading = false;
      });

      _navigationStartTime = DateTime.now();

      // Start smooth camera updates
      _startCameraUpdates();
    } catch (e) {
      debugPrint('Navigation initialization failed: $e');
      _showError('Failed to start navigation: $e');
    }
  }

  /// Load approved/verified hazards to show on the map during navigation
  Future<void> _loadVerifiedHazards() async {
    try {
      final list = await _hazardService.getVerifiedHazards();
      if (mounted) setState(() => _verifiedHazards = list);
    } catch (e) {
      print('Could not load verified hazards: $e');
    }
  }

  /// Load pending hazards: uses the resident's own reports filtered by pending
  /// status, because /mdrrmo/pending-reports/ is MDRRMO-only (403 for residents).
  /// This ensures a just-submitted report appears on the map immediately.
  Future<void> _loadPendingHazards() async {
    try {
      final all = await _hazardService.getMyReports();
      final pending = all.where((r) => r.status == HazardStatus.pending).toList();
      if (mounted) setState(() => _pendingHazards = pending);
    } catch (e) {
      print('Could not load pending hazards: $e');
    }
  }

  /// Calculate route — uses backend Modified Dijkstra route when available.
  Future<void> _calculateRoute() async {
    try {
      final destinationLatLng = LatLng(
        widget.destination.latitude,
        widget.destination.longitude,
      );

      final NavigationRoute route;

      if (widget.selectedRoute != null) {
        // PRIMARY: Use the exact polyline from Django Modified Dijkstra.
        // OSRM is only used for turn-instruction hints (start → destination).
        print('✅ Navigation using backend Modified Dijkstra route');
        route = await _routingService.buildFromBackendRoute(
          backendRoute: widget.selectedRoute!,
          destination: destinationLatLng,
        );
      } else {
        // FALLBACK: No backend route passed — use OSRM as last resort.
        print('⚠️ No backend route provided — falling back to OSRM');
        route = await _routingService.calculateSafestRoute(
          start: widget.startLocation,
          destination: destinationLatLng,
          evacuationCenter: widget.destination,
        );
      }

      setState(() {
        _currentRoute = route;
      });

      // Update current step
      if (_userLocation != null) {
        _updateCurrentStep(_userLocation!);
      }

      print('✅ Route ready: ${route.steps.length} steps, ${route.getFormattedDistance()}');
    } catch (e) {
      print('❌ Route calculation failed: $e');
      rethrow;
    }
  }

  /// Returns false while GPS is still settling after navigation start.
  /// Prevents false reroutes caused by GPS cold-start inaccuracy (±50–100 m).
  bool _canCheckDeviation() {
    if (_navigationStartTime == null) return false;
    if (_locationUpdateCount < _minUpdatesBeforeDeviationCheck) return false;
    return DateTime.now().difference(_navigationStartTime!) > _deviationGracePeriod;
  }

  /// Handle GPS location updates.
  void _onLocationUpdate(LatLng location) async {
    if (!mounted) return;

    // Update the true GPS fix (used for navigation logic) then animate the
    // rendered marker smoothly to the new position so it glides, not jumps.
    _userLocation = location;
    _animateToLocation(location);

    // ── Post-arrival mode: only GPS movement check for "left destination" ──
    if (_hasArrived) {
      _checkLeftDestination(location);
      return;
    }

    if (_currentRoute == null) return;
    _locationUpdateCount++;

    final destinationLatLng = LatLng(
      widget.destination.latitude,
      widget.destination.longitude,
    );

    // ── Stable arrival detection (dwell-based, prevents jitter false-fires) ──
    final distToDest = _gpsService.calculateDistance(location, destinationLatLng);
    if (distToDest <= _arrivalRadiusM) {
      _arrivalEnteredAt ??= DateTime.now();
      if (DateTime.now().difference(_arrivalEnteredAt!) >= _arrivalConfirmDuration) {
        if (!_hasShownArrivalModal) _onArrival();
        return;
      }
      // Inside radius but not yet long enough — update step and wait
      _updateCurrentStep(location);
      return;
    } else {
      // Drifted back outside radius — reset the dwell timer
      _arrivalEnteredAt = null;
    }

    // ── Deviation / high-risk checks (gated by grace period) ─────────────
    if (_canCheckDeviation()) {
      final highRiskSegment = _routingService.getCurrentHighRiskSegment(
        userLocation: location,
        route: _currentRoute!,
      );
      if (highRiskSegment != null && _currentHighRiskSegment != highRiskSegment) {
        setState(() => _currentHighRiskSegment = highRiskSegment);
        await _onHighRiskDetected();
        return;
      }
      if (_routingService.hasDeviatedFromRoute(
        userLocation: location,
        route: _currentRoute!,
      )) {
        await _onDeviationDetected();
        return;
      }
    }

    _updateCurrentStep(location);
  }

  /// After arrival: if user moves beyond [_leftDestinationRadiusM], show
  /// a once-per-session prompt asking if they want to navigate again.
  void _checkLeftDestination(LatLng location) {
    if (_hasShownLeftDestination) return;
    final dest = LatLng(widget.destination.latitude, widget.destination.longitude);
    final dist = _gpsService.calculateDistance(location, dest);
    if (dist > _leftDestinationRadiusM) {
      _hasShownLeftDestination = true;
      _showLeftDestinationBanner();
    }
  }

  /// Shows a persistent snackbar when the user moves away after arriving.
  void _showLeftDestinationBanner() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('You have left the destination area.'),
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.orange[800],
        action: SnackBarAction(
          label: 'Close',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            if (mounted) Navigator.pop(context);
          },
        ),
      ),
    );
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
      final nextStep = _currentRoute!.steps[step.stepIndex + 1];
      setState(() {
        _currentStep = nextStep;
        _distanceToNextStep = nextStep.distanceToNext;
      });
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

  /// Smooth camera follow: keep user centred on screen; map stays north-up.
  /// Only the arrow marker rotates — the map itself never rotates.
  void _smoothCameraFollow() {
    if (_userLocation == null || !_followUserLocation) return;
    try {
      _mapController.move(_userLocation!, 17.0);
    } catch (e) {
      // Map controller not ready yet
    }
  }

  /// Handle arrival at destination — stops active navigation and shows modal.
  void _onArrival() async {
    if (_hasShownArrivalModal) return;

    setState(() {
      _hasArrived = true;
      _hasShownArrivalModal = true;
      _routeOpacity = 0.35; // fade route line after arrival
      _followUserLocation = true;
    });

    // ── Stop active navigation listeners ─────────────────────────────────
    _cameraUpdateTimer?.cancel();
    // Stop compass / heading updates — no longer needed after arrival.
    await _headingSubscription?.cancel();
    _headingSubscription = null;
    // Keep pulse animation running — repurposed to animate destination marker.

    // ── Smooth camera pan to destination ──────────────────────────────────
    try {
      _mapController.move(
        LatLng(widget.destination.latitude, widget.destination.longitude),
        16.5,
      );
    } catch (_) {}

    // ── Save trip history (offline-first) ──────────────────────────────────
    await _saveTripHistory();

    // ── Show arrival modal ─────────────────────────────────────────────────
    if (mounted) _showArrivalModal(_currentRoute?.totalDistance ?? 0.0);
  }

  /// Persist the completed trip to local Hive storage for analytics.
  Future<void> _saveTripHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id') ?? 0;
      final now = DateTime.now();
      await StorageService.saveTripHistory({
        'user_id': userId,
        'destination_id': widget.destination.id,
        'destination_name': widget.destination.name,
        'start_time': _navigationStartTime?.toIso8601String() ?? now.toIso8601String(),
        'arrival_time': now.toIso8601String(),
        'duration_seconds': _navigationStartTime != null
            ? now.difference(_navigationStartTime!).inSeconds
            : 0,
        'total_distance_m': _currentRoute?.totalDistance ?? 0.0,
        'reroute_count': _rerouteCount,
      });
      print('✅ Trip history saved (reroutes: $_rerouteCount)');
    } catch (e) {
      print('⚠️ Could not save trip history: $e');
    }
  }

  /// Polished arrival bottom sheet — non-dismissible, one action per button.
  void _showArrivalModal(double totalDistanceM) {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: Colors.white,
      builder: (modalCtx) => _ArrivalModalContent(
        destination: widget.destination,
        durationSeconds: _navigationStartTime != null
            ? DateTime.now().difference(_navigationStartTime!).inSeconds
            : 0,
        totalDistanceM: totalDistanceM,
        rerouteCount: _rerouteCount,
        onDone: () {
          Navigator.pop(modalCtx);
          if (mounted) Navigator.pop(context);
        },
        onViewDetails: () {
          Navigator.pop(modalCtx);
          if (mounted) _showCenterDetailsSheet();
        },
        onReportHazard: () {
          Navigator.pop(modalCtx);
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReportHazardScreen(
                location: LatLng(
                  widget.destination.latitude,
                  widget.destination.longitude,
                ),
                userLocation: _userLocation,
              ),
            ),
          ).then((_) => _loadPendingHazards());
        },
      ),
    );
  }

  /// Simple info sheet showing evacuation center details after arrival.
  void _showCenterDetailsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final ec = widget.destination;
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.location_city, color: Colors.green.shade700, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ec.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (ec.barangay?.isNotEmpty == true)
                          Text(
                            ec.barangay!,
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (ec.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  ec.description,
                  style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                ),
              ],
              const SizedBox(height: 20),
              _detailRow(Icons.place, 'Coordinates',
                  '${ec.latitude.toStringAsFixed(5)}, ${ec.longitude.toStringAsFixed(5)}'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              children: [
                TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Handle high-risk segment detection
  Future<void> _onHighRiskDetected() async {
    print('🚨 HIGH RISK DETECTED - Triggering reroute');
    
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
    
    // Trigger reroute if allowed
    if (_routingService.canReroute()) {
      await _reroute();
    }
  }

  /// Reroute to destination.
  /// PRIMARY: backend Modified Dijkstra (preserves hazard-aware routing).
  /// FALLBACK: OSRM if backend is unreachable.
  /// OFFLINE: shows a snackbar and keeps the current route visible.
  Future<void> _reroute() async {
    if (_isRerouting || _userLocation == null || _hasArrived) return;

    // Check connectivity before attempting any network call.
    final isOnline = await ConnectivityService().isOnline;
    if (!isOnline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.wifi_off, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Offline mode — Rerouting unavailable until connection returns. '
                  'Current route is still shown.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ]),
            backgroundColor: Color(0xFFB71C1C),
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return; // Keep existing route; do not increment reroute count.
    }

    _rerouteCount++;

    setState(() {
      _isRerouting = true;
    });

    _routingService.markReroute();

    try {
      final destinationLatLng = LatLng(
        widget.destination.latitude,
        widget.destination.longitude,
      );

      NavigationRoute newRoute;

      // PRIMARY: ask Django backend for the safest reroute from current position.
      try {
        final backendService = RoutingService();
        final result = await backendService.calculateRoutes(
          startLat: _userLocation!.latitude,
          startLng: _userLocation!.longitude,
          evacuationCenterId: widget.destination.id,
          evacuationCenter: widget.destination,
        );

        if (result.routes.isNotEmpty) {
          newRoute = await _routingService.buildFromBackendRoute(
            backendRoute: result.routes.first,
            destination: destinationLatLng,
          );
          debugPrint('✅ Rerouted via backend Modified Dijkstra');
        } else {
          throw Exception('Backend returned no routes');
        }
      } catch (e) {
        // FALLBACK: OSRM if backend is unavailable
        debugPrint('⚠️ Backend reroute failed — falling back to OSRM: $e');
        newRoute = await _routingService.calculateSafestRoute(
          start: _userLocation!,
          destination: destinationLatLng,
          evacuationCenter: widget.destination,
        );
      }

      setState(() {
        _currentRoute = newRoute;
        _currentHighRiskSegment = null;
        _isRerouting = false;
      });

      _updateCurrentStep(_userLocation!);
      debugPrint('Rerouted successfully');
    } catch (e) {
      debugPrint('❌ Reroute failed: $e');
      setState(() {
        _isRerouting = false;
      });
    }
  }

  /// Remaining road distance in km.
  /// Sums: distance to the current step waypoint + distanceToNext for all
  /// subsequent steps.  Falls back to straight-line when no route is active.
  double get _distanceRemainingKm {
    if (_userLocation == null) return 0;

    final route = _currentRoute;
    final step = _currentStep;
    if (route == null || route.steps.isEmpty || step == null) {
      // No route data — use straight-line as fallback
      return _gpsService.calculateDistance(
            _userLocation!,
            LatLng(widget.destination.latitude, widget.destination.longitude),
          ) /
          1000;
    }

    // Distance from current GPS position to the next step waypoint
    double totalM = _distanceToNextStep;

    // Add distanceToNext for every step after the current one
    for (int i = step.stepIndex + 1; i < route.steps.length; i++) {
      totalM += route.steps[i].distanceToNext;
    }

    return totalM / 1000;
  }

  /// Maximum distance (m) from user to hazard location to allow reporting. Matches backend 1 km rule.
  /// Max distance (meters) from user to report location during navigation.
  /// Updated: Changed from 1000m to 150m for more accurate reporting.
  static const double _reportMaxDistanceM = 150;

  /// Handle long press on map - Report hazard during navigation (only if user is within 1 km)
  void _onLongPressMap(TapPosition tapPosition, LatLng location) {
    if (_userLocation == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wait for GPS location before reporting a hazard.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    final distanceM = _gpsService.calculateDistance(_userLocation!, location);
    if (distanceM > _reportMaxDistanceM) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Your location must be within 150 meters of the reported hazard. You are ${distanceM.toStringAsFixed(0)} meters away.',
            ),
            backgroundColor: Colors.orange[800],
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

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
                        userLocation: _userLocation,
                      ),
                    ),
                  ).then((_) {
                    // Inject newly submitted report into the map immediately
                    _loadPendingHazards();
                  });
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


  @override
  void dispose() {
    _locationSubscription?.cancel();
    _headingSubscription?.cancel();
    _cameraUpdateTimer?.cancel();
    _pulseController.dispose();
    _positionController.dispose();
    _gpsService.stopTracking();
    _routingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1117),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Preparing Navigation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Loading route and hazard data…',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmExitNavigation();
      },
      child: Scaffold(
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

            // High-risk warning banner
            if (_currentHighRiskSegment != null)
              Positioned(
                top: 100,
                left: 0,
                right: 0,
                child: _buildHighRiskBanner(),
              ),

            // Rerouting indicator — _buildReroutingIndicator() returns a
            // Positioned directly, so it must be a direct Stack child.
            if (_isRerouting) _buildReroutingIndicator(),

            // Destination info banner — always visible at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildDestinationBanner(),
            ),

            // Re-center on user button (when user has panned the map)
            Positioned(
              right: 16,
              bottom: 100,
              child: SafeArea(
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(28),
                  color: _followUserLocation
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white,
                  child: IconButton(
                    onPressed: _recenterOnUser,
                    icon: Icon(
                      Icons.my_location,
                      color: _followUserLocation
                          ? Colors.white
                          : Theme.of(context).colorScheme.primary,
                    ),
                    tooltip: 'Center on my location',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Confirm exit navigation (Android back button)
  void _confirmExitNavigation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Navigation?'),
        content: const Text('Do you want to stop navigating to the evacuation center?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Navigation'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Exit navigation screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Exit Navigation'),
          ),
        ],
      ),
    );
  }

  /// Small risk level badge shown in the destination banner.
  Widget _buildRiskBadge(String riskLevel) {
    final Color color;
    final String label;
    final IconData icon;
    switch (riskLevel) {
      case 'high':
        color = Colors.red.shade400;
        label = 'High Risk Route';
        icon = Icons.warning_amber_rounded;
        break;
      case 'moderate':
        color = Colors.orange.shade400;
        label = 'Moderate Risk Route';
        icon = Icons.warning_amber_outlined;
        break;
      default:
        color = Colors.green.shade400;
        label = 'Safe Route';
        icon = Icons.check_circle_outline;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// Destination info panel pinned at the bottom of the screen
  Widget _buildDestinationBanner() {
    final distKm = _distanceRemainingKm;
    final distText = distKm >= 1
        ? '${distKm.toStringAsFixed(1)} km remaining'
        : '${(distKm * 1000).toStringAsFixed(0)} m remaining';
    final barangay = widget.destination.barangay?.isNotEmpty == true
        ? widget.destination.barangay!
        : widget.destination.description;
    final riskLevel = _currentRoute?.overallRiskLevel ?? 'safe';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A8A),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_city, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.destination.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (barangay.isNotEmpty)
                  Text(
                    barangay,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (_currentRoute != null) ...[
                  const SizedBox(height: 4),
                  _buildRiskBadge(riskLevel),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                distText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: _confirmExitNavigation,
                child: Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'End',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Re-center map on user and resume follow mode
  void _recenterOnUser() {
    if (_userLocation != null) {
      setState(() => _followUserLocation = true);
      _mapController.move(_userLocation!, 17.0);
    }
  }

  /// Build full-screen map (user can pan/scroll; re-center via FAB)
  Widget _buildMap() {
    return Listener(
      onPointerDown: (_) {
        // User touched the map — stop auto-follow so they can pan/explore
        if (_followUserLocation && mounted) {
          setState(() => _followUserLocation = false);
        }
      },
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _userLocation ?? widget.startLocation,
          initialZoom: 17.0,
          minZoom: 12.0,
          maxZoom: 19.0,
          onLongPress: _onLongPressMap,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all,
          ),
        ),
      children: [
        // Map tiles — uses disk cache so tiles render even when offline.
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.evacroute.mobile',
          tileProvider: _tileProvider,
          errorTileCallback: (tile, error, _) {
            // Silently swallow tile errors — placeholder already shown by provider.
          },
        ),

        // Dashed connector: user GPS position → first point of the route.
        // Shown when the user is off-road (e.g. inside a building). Disappears
        // once the user is within 15 m of the route start.
        if (_userLocation != null &&
            _currentRoute != null &&
            _currentRoute!.polyline.isNotEmpty)
          () {
            final renderLoc = _displayLocation ?? _userLocation!;
            final routeStart = _currentRoute!.polyline.first;
            final gapM = _gpsService.calculateDistance(_userLocation!, routeStart);
            if (gapM > 15) {
              return PolylineLayer(
                polylines: [
                  Polyline(
                    points: [renderLoc, routeStart],
                    color: Colors.blue.withValues(alpha: 0.55),
                    strokeWidth: 3.0,
                    borderStrokeWidth: 0,
                    pattern: StrokePattern.dashed(segments: const [8, 6]),
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          }(),

        // Route polyline — white border + colored fill.
        // Color encodes risk level: green (safe) / orange (moderate) / red (high).
        // Fades to 35 % opacity after arrival.
        if (_currentRoute != null) ...[
          // Shadow layer (dark, slightly wider)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _currentRoute!.polyline,
                color: Colors.black.withValues(alpha: 0.18 * _routeOpacity),
                strokeWidth: 16.0,
                borderStrokeWidth: 0,
              ),
            ],
          ),
          // White border
          PolylineLayer(
            polylines: [
              Polyline(
                points: _currentRoute!.polyline,
                color: Colors.white.withValues(alpha: _routeOpacity),
                strokeWidth: 13.0,
                borderStrokeWidth: 0,
              ),
            ],
          ),
          // Colored route fill
          PolylineLayer(
            polylines: [
              Polyline(
                points: _currentRoute!.polyline,
                color: _getRouteColor(_currentRoute!.overallRiskLevel)
                    .withValues(alpha: _routeOpacity),
                strokeWidth: 9.0,
                borderStrokeWidth: 0,
              ),
            ],
          ),
        ],

        // Verified/approved hazard markers (identified hazards visible during navigation)
        MarkerLayer(
          markers: _buildVerifiedHazardMarkers(),
        ),

        // Pending hazard markers (community-reported, not yet approved)
        MarkerLayer(
          markers: _buildPendingHazardMarkers(),
        ),

        // User arrow marker (3D style, positioned in bottom third).
        // Uses _displayLocation (interpolated) for smooth gliding between GPS fixes.
        if (_userLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _displayLocation ?? _userLocation!,
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
                                color: Colors.blue.withValues(alpha: 0.4),
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
                                  color: Colors.blue.withValues(alpha: 0.3),
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

        // Destination marker — pulses and enlarges on arrival.
        MarkerLayer(
          markers: [
            Marker(
              point: LatLng(
                widget.destination.latitude,
                widget.destination.longitude,
              ),
              width: _hasArrived ? 80 : 60,
              height: _hasArrived ? 80 : 60,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _hasArrived ? _pulseAnimation.value : 1.0,
                    child: child,
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: _hasArrived ? Colors.green.shade400 : Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: _hasArrived ? 5 : 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_hasArrived ? Colors.green : Colors.black).withValues(alpha: 0.35),
                        blurRadius: _hasArrived ? 24 : 12,
                        spreadRadius: _hasArrived ? 4 : 0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _hasArrived ? Icons.check_circle : Icons.location_on,
                    color: Colors.white,
                    size: _hasArrived ? 40 : 32,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
    );
  }

  /// Show a concise detail sheet for a hazard report tapped during navigation.
  void _showHazardDetail(HazardReport report) {
    final isPending = report.status == HazardStatus.pending;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.45,
          maxChildSize: 0.85,
          minChildSize: 0.3,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPending ? Colors.orange[100] : Colors.green[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPending ? Icons.schedule : Icons.verified,
                              size: 14,
                              color: isPending ? Colors.orange[800] : Colors.green[800],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isPending ? 'Pending' : 'Verified',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isPending ? Colors.orange[800] : Colors.green[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          report.hazardType.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (report.description.isNotEmpty) ...[
                    Text(
                      report.description,
                      style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 6),
                      Text(
                        report.createdAt != null
                            ? () {
                                final l = report.createdAt!.toLocal();
                                return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
                              }()
                            : 'Unknown date',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Media (photo/video)
                  if (reportHasMedia(report)) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    ReportMediaSection(report: report),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Build markers for pending (not yet approved) hazard reports
  List<Marker> _buildPendingHazardMarkers() {
    return _pendingHazards.map((report) {
      return Marker(
        point: LatLng(report.latitude, report.longitude),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showHazardDetail(report),
          child: Container(
          decoration: BoxDecoration(
            color: Colors.orange.shade600,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
        ),
        ),
      );
    }).toList();
  }

  /// Build markers for verified/approved hazards (identified hazards on the map)
  List<Marker> _buildVerifiedHazardMarkers() {
    return _verifiedHazards.map((report) {
      return Marker(
        point: LatLng(report.latitude, report.longitude),
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => _showHazardDetail(report),
          child: Container(
          decoration: BoxDecoration(
            color: Colors.red.shade700,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.warning_rounded, color: Colors.white, size: 24),
        ),
        ),
      );
    }).toList();
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
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
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
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build rerouting indicator — returns a Positioned (direct Stack child).
  Widget _buildReroutingIndicator() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 150,
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
                color: Colors.black.withValues(alpha: 0.3),
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
                'You are off route. Recalculating safer path...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
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

// ─────────────────────────────────────────────────────────────────────────────
// Arrival modal — separate StatefulWidget so the entry animation works cleanly
// even though it is rendered inside a ModalBottomSheet.
// ─────────────────────────────────────────────────────────────────────────────
class _ArrivalModalContent extends StatefulWidget {
  final EvacuationCenter destination;
  final int durationSeconds;
  final double totalDistanceM;
  final int rerouteCount;
  final VoidCallback onDone;
  final VoidCallback onViewDetails;
  final VoidCallback onReportHazard;

  const _ArrivalModalContent({
    required this.destination,
    required this.durationSeconds,
    required this.totalDistanceM,
    required this.rerouteCount,
    required this.onDone,
    required this.onViewDetails,
    required this.onReportHazard,
  });

  @override
  State<_ArrivalModalContent> createState() => _ArrivalModalContentState();
}

class _ArrivalModalContentState extends State<_ArrivalModalContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _checkController;
  late final Animation<double> _checkScale;
  late final Animation<double> _checkOpacity;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _checkScale = CurvedAnimation(parent: _checkController, curve: Curves.elasticOut);
    _checkOpacity = CurvedAnimation(parent: _checkController, curve: Curves.easeIn);
    // Trigger animation after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkController.forward());
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '—';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final ec = widget.destination;
    final barangay = ec.barangay?.isNotEmpty == true ? ec.barangay! : '';

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Animated checkmark
          FadeTransition(
            opacity: _checkOpacity,
            child: ScaleTransition(
              scale: _checkScale,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green.shade300, width: 3),
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 52,
                  color: Colors.green.shade600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Headline
          const Text(
            'You have arrived safely.',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),

          // Destination label
          Text(
            'Destination:',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
          const SizedBox(height: 2),
          Text(
            ec.name,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          if (barangay.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              barangay,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),

          // Trip summary chip row
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              _tripChip(Icons.timer_outlined, _formatDuration(widget.durationSeconds)),
              if (widget.totalDistanceM > 0)
                _tripChip(
                  Icons.straighten,
                  widget.totalDistanceM >= 1000
                      ? '${(widget.totalDistanceM / 1000).toStringAsFixed(1)} km'
                      : '${widget.totalDistanceM.toStringAsFixed(0)} m',
                ),
              _tripChip(
                Icons.route,
                widget.rerouteCount == 0
                    ? 'No reroutes'
                    : '${widget.rerouteCount} reroute${widget.rerouteCount == 1 ? '' : 's'}',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Primary: Done button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onDone,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Secondary buttons row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onViewDetails,
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('Center Details', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue[700],
                    side: BorderSide(color: Colors.blue.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onReportHazard,
                  icon: const Icon(Icons.warning_amber_outlined, size: 18),
                  label: const Text('Report Hazard', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange[700],
                    side: BorderSide(color: Colors.orange.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tripChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }
}

