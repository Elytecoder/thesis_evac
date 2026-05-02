import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/api_config.dart';
import '../../core/auth/session_storage.dart';
import '../../core/storage/storage_service.dart';
import '../../core/map/cached_tile_provider.dart';
import '../../core/network/api_client.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/sync_service.dart';
import '../../models/evacuation_center.dart';
import '../../models/route.dart' as app_route;
import '../../data/mock_evacuation_centers.dart';
import '../../features/routing/routing_service.dart';
import '../../features/residents/resident_hazard_reports_service.dart';
import '../../features/residents/resident_notifications_service.dart';
import '../widgets/offline_banner.dart';
import '../widgets/exit_confirm_scope.dart';
import '../widgets/map_marker_style.dart';
import '../widgets/report_media_preview.dart' show normalizeMediaUrl, buildImageFromUrl;
import 'routes_selection_screen.dart';
import 'report_hazard_screen.dart';
import 'settings_screen.dart';
import 'notifications_screen.dart';

/// Enhanced Map Screen with route calculation and hazard overlays
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final MapController _mapController = MapController();
  // Shared singleton — cache dir is pre-warmed so the first tile requests
  // don't stall on an async file-system call.
  final CachedNetworkTileProvider _tileProvider =
      CachedNetworkTileProvider.shared();
  final RoutingService _routingService = RoutingService();
  final ResidentHazardReportsService _hazardReportsService = ResidentHazardReportsService();
  final ResidentNotificationsService _notificationsService = ResidentNotificationsService();
  final ConnectivityService _connectivity = ConnectivityService();
  final StorageService _storageService = StorageService();
  StreamSubscription<bool>? _reconnectSub;
  StreamSubscription<void>? _syncRefreshSub;
  Timer? _pollTimer;
  StreamSubscription<Position>? _positionSubscription;

  // Default to Bulan, Sorsogon so the map renders instantly.
  // Updated to the real GPS fix as soon as it arrives.
  LatLng _userLocation = const LatLng(12.6699, 123.8758);
  // True once we have a real GPS or last-known position (not the Bulan default).
  // The user location marker is hidden until this is true so we never show a
  // marker at the wrong place.
  bool _locationIsReal = false;
  // True when GPS resolved but failed after timeout — shows "retry" UI.
  bool _gpsFailed = false;
  // True only while the initial GPS fix is still pending (shows a small
  // location-locating indicator instead of blocking the whole map).
  bool _gpsLocating = true;
  static const Duration _lastKnownMaxAge = Duration(minutes: 2);
  bool _lowGpsPrecision = false;
  double? _lastGpsAccuracyMeters;
  static const double _lowPrecisionThresholdMeters = 50.0;
  List<EvacuationCenter> _evacuationCenters = [];
  
  // Selected center and routes
  EvacuationCenter? _selectedCenter;
  app_route.Route? _activeRoute;

  // Double-tap prevention for "Routes" button on each center card.
  bool _isOpeningRoutes = false;
  
  // Show bottom sheet
  bool _showBottomSheet = true;
  // Panel height for draggable 3-snap evacuation center panel.
  static const double _kPanelCollapsed = 72.0;
  static const double _kPanelHalf = 240.0;
  static const double _kPanelExpanded = 380.0;
  double _panelHeight = _kPanelHalf;
  
  // Hazard reports
  List<Map<String, dynamic>> _hazardReports = [];
  // Guard to prevent concurrent duplicate hazard API calls.
  bool _hazardLoadInFlight = false;
  int _unreadNotificationsCount = 0;

  // Road Risk Layer: toggle + segment data loaded with route calculation.
  bool _showRoadRiskLayer = false;
  List<app_route.RoadRiskSegment> _roadRiskSegments = [];

  // Notification highlight: which report is currently highlighted on the map
  String? _highlightedReportId;
  // Guards _checkAndFocusTargetLocation so it only runs once per resume.
  bool _pendingFocusCheck = false;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    // Pulse the searching marker until a real GPS fix arrives.
    _pulseController.repeat(reverse: true);
    // Register for app lifecycle callbacks (resume → refresh data).
    WidgetsBinding.instance.addObserver(this);
    // Kick off GPS and all data loads concurrently.
    // Map renders immediately with the Bulan default centre; each piece of
    // data calls setState independently so content appears progressively
    // rather than all-at-once after a long wait.
    _initializeMap();
    _loadDataInBackground();
    _listenForReconnect();
    _listenForSyncRefresh();
    _startPolling();
  }

  /// Runs all non-GPS data loads in parallel so each one updates the UI
  /// as soon as it finishes, without any blocking serial sequence.
  Future<void> _loadDataInBackground() async {
    await Future.wait([
      _loadEvacuationCenters(),
      _loadHazardReports(),
      _loadNotificationCount(),
    ]);
    _refreshRoadRiskLayerIfVisible();
  }

  /// Reload live data when connectivity is restored so the map stays current.
  void _listenForReconnect() {
    _reconnectSub = _connectivity.onConnectionChange.listen((isOnline) {
      if (isOnline && mounted) {
        _loadEvacuationCenters();
    _loadHazardReports();
        _refreshRoadRiskLayerIfVisible();
      }
    });
  }

  /// After a background sync completes (pending reports uploaded, caches refreshed)
  /// pull fresh hazard and center data into the map UI immediately.
  void _listenForSyncRefresh() {
    _syncRefreshSub = SyncService().mapRefreshStream.listen((_) {
      if (mounted) {
        _loadHazardReports();
        _loadEvacuationCenters();
        _refreshRoadRiskLayerIfVisible();
      }
    });
  }

  /// Load evacuation centers using a cache-first strategy:
  /// 1. Show Hive-cached centers immediately (no network wait).
  /// 2. Fetch fresh data from API in background and update markers.
  Future<void> _loadEvacuationCenters() async {
    if (ApiConfig.useMockData) {
      setState(() { _evacuationCenters = getMockEvacuationCenters(); });
      return;
    }

    final sw = Stopwatch()..start();

    // Step 1: render cached centers right away so the map is never empty.
    final cached = await _storageService.getEvacuationCenters();
    if (cached != null && cached.isNotEmpty && mounted) {
      setState(() {
        _evacuationCenters = cached.map((j) => EvacuationCenter.fromJson(j)).toList();
      });
      debugPrint('[MapPerf] ECs from cache: ${cached.length} in ${sw.elapsedMilliseconds}ms');
    }

    // Step 2: refresh from API; update markers when response arrives.
    try {
      final centers = await _routingService.getEvacuationCenters();
      if (mounted) {
        setState(() { _evacuationCenters = centers; });
        debugPrint('[MapPerf] ECs from API: ${centers.length} in ${sw.elapsedMilliseconds}ms');
      }
    } catch (e) {
      // Cached data is already displayed — only alert if there was nothing to show.
      if ((cached == null || cached.isEmpty) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load evacuation centers. Try again later.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }
  
  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Schedule a focus check but only run it once per resume, not on every
    // setState. _pendingFocusCheck is cleared inside _checkAndFocusTargetLocation.
    _pendingFocusCheck = true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reconnectSub?.cancel();
    _syncRefreshSub?.cancel();
    _positionSubscription?.cancel();
    _pollTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  /// Polls live data every 60 s while the app is foregrounded.
  /// Stops automatically when the app goes to background (see [didChangeAppLifecycleState]).
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) {
        _loadHazardReports();
        _loadEvacuationCenters();
        _refreshRoadRiskLayerIfVisible();
      }
    });
  }

  /// Refresh data immediately when the user brings the app back to the foreground,
  /// and restart the polling timer. Pauses polling while in background to save battery.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadHazardReports();
      _loadEvacuationCenters();
      _loadNotificationCount();
      _refreshRoadRiskLayerIfVisible();
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _pollTimer?.cancel();
    }
  }
  
  /// Check if we should focus on a target location from notification.
  /// Also reads a highlight report_id so the specific hazard marker pulses.
  Future<void> _checkAndFocusTargetLocation() async {
    _pendingFocusCheck = false; // consume the pending flag immediately
    final prefs = await SharedPreferences.getInstance();
    final shouldFocus = prefs.getBool('map_should_focus') ?? false;
    
    if (shouldFocus) {
      final targetLat = prefs.getDouble('map_target_lat');
      final targetLng = prefs.getDouble('map_target_lng');
      final highlightId = prefs.getString('map_highlight_report_id');
      
      if (targetLat != null && targetLng != null && mounted) {
        _mapController.move(LatLng(targetLat, targetLng), 17.0);
        
        // Highlight the specific hazard marker with a pulse animation
        if (highlightId != null && highlightId.isNotEmpty) {
          setState(() => _highlightedReportId = highlightId);
          _pulseController.repeat(reverse: true);

          // Auto-clear the highlight after 6 seconds
          Future.delayed(const Duration(seconds: 6), () {
            if (mounted) {
              setState(() => _highlightedReportId = null);
              _pulseController.stop();
              _pulseController.reset();
            }
          });
          await prefs.remove('map_highlight_report_id');
        }

        await prefs.remove('map_should_focus');
        await prefs.remove('map_target_lat');
        await prefs.remove('map_target_lng');
      }
    }
  }
  
  /// Load hazard reports using a cache-first strategy:
  /// 1. Show Hive-cached verified hazards + offline-queued reports immediately.
  /// 2. Fetch fresh data from API and replace markers when done.
  Future<void> _loadHazardReports() async {
    if (_hazardLoadInFlight) return;
    _hazardLoadInFlight = true;

    final sw = Stopwatch()..start();

    // Step 1: render cached hazards immediately (no network call).
    try {
      final cachedReports = await _hazardReportsService.getCachedMapReports();
      if (cachedReports.isNotEmpty && mounted) {
        setState(() { _hazardReports = cachedReports; });
        debugPrint('[MapPerf] Hazards from cache: ${cachedReports.length} in ${sw.elapsedMilliseconds}ms');
      }
    } catch (_) {}

    // Step 2: fetch fresh verified + my-reports + offline queue from API.
    try {
      final reports = await _hazardReportsService.getMapReports();
      if (mounted) {
        setState(() { _hazardReports = reports; });
        debugPrint('[MapPerf] Hazards from API: ${reports.length} in ${sw.elapsedMilliseconds}ms');
      }
    } catch (e) {
      debugPrint('[MapPerf] Hazard API error: $e');
    } finally {
      _hazardLoadInFlight = false;
    }
  }
  
  Future<void> _loadNotificationCount() async {
    try {
      final count = await _notificationsService.getUnreadCount();
      setState(() {
        _unreadNotificationsCount = count;
      });
    } catch (e) {
      print('Error loading notification count: $e');
    }
  }

  /// Toggle the Road Risk Layer.  Fetches segment data on first enable.
  void _toggleRoadRiskLayer() {
    final newValue = !_showRoadRiskLayer;
    setState(() => _showRoadRiskLayer = newValue);
    if (newValue) {
      _loadRoadRiskLayer();
    }
  }

  void _refreshRoadRiskLayerIfVisible() {
    if (_showRoadRiskLayer) {
      _loadRoadRiskLayer();
    }
  }

  Future<void> _loadRoadRiskLayer() async {
    try {
      final apiClient = ApiClient();
      final token = await SessionStorage.readToken();
      if (token != null) {
        apiClient.setAuthToken(token);
      }
      final response = await apiClient.get(ApiConfig.roadRiskLayerEndpoint);
      final data = response.data as Map<String, dynamic>;
      final raw = data['road_risk_segments'] as List<dynamic>?;
      if (raw != null && mounted) {
        setState(() {
          _roadRiskSegments = raw
              .map((e) => app_route.RoadRiskSegment.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList();
        });
      }
    } catch (e) {
      print('Failed to load road risk layer: $e');
    }
  }

  Future<void> _initializeMap() async {
    // ── STEP 0: Ensure location services are actually ON ─────────────────────
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      setState(() {
        _gpsLocating = false;
        _gpsFailed = true;
      });
      return;
    }

    // ── STEP 1: Optional pre-position from recent cache ─────────────────────
    // We only trust last-known if it is recent enough; stale cached positions
    // are ignored to prevent showing the marker at the wrong place.
    // Not supported on web — skip it there to avoid errors.
    if (!kIsWeb) {
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        final ts = lastKnown?.timestamp;
        final isFresh =
            ts != null && DateTime.now().difference(ts) <= _lastKnownMaxAge;
        if (lastKnown != null && isFresh && mounted) {
          _pulseController.stop();
          setState(() {
            _userLocation = LatLng(lastKnown.latitude, lastKnown.longitude);
            _locationIsReal = true;
          });
          // Move camera on the next frame (map may not be laid out yet).
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _mapController.move(_userLocation, 16.0);
          });
        }
      } catch (_) {}
    }

    // ── STEP 2: Permission check (native only) ───────────────────────────────
    // On web, Geolocator.checkPermission/requestPermission only query the
    // current browser state and NEVER trigger the browser "Allow location?"
    // popup. The popup is only shown when getCurrentPosition() is called.
    // Skipping the pre-check on web so we don't return early with
    // "permission denied" before the user has even been asked.
    if (!kIsWeb) {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() => _gpsLocating = false);
        _showPermissionDeniedDialog();
        return;
      }
    }

    // ── STEP 3: Get position — browser handles its own permission prompt ─────
    // Longer timeout on web (20 s) because network/IP geolocation can be
    // slow and the browser permission dialog is part of this call.
    final timeout =
        kIsWeb ? const Duration(seconds: 20) : const Duration(seconds: 8);
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
      ).timeout(timeout);

      if (mounted) {
        _pulseController.stop();
          setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
          _locationIsReal = true;
          _gpsLocating = false;
          _gpsFailed = false;
          _applyGpsQuality(position.accuracy);
        });
        _mapController.move(_userLocation, 16.0);
      }
    } catch (_) {
      // Timed out or failed. Only show the retry banner if we have no real
      // position at all — if last-known position already placed the marker,
      // just clear the locating indicator silently.
      if (mounted) setState(() {
        _gpsLocating = false;
        _gpsFailed = !_locationIsReal;
      });
    }

    // ── STEP 4: Start continuous GPS updates so marker stays accurate ───────
    _startLocationStream();

    // ── STEP 5: Honour notification deep-link focus ──────────────────────────
            if (mounted) {
              final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('map_should_focus') == true) {
        await _checkAndFocusTargetLocation();
      }
    }
  }

  /// Re-run the GPS acquisition (called from the orange retry pill / FAB).
  Future<void> _retryLocate() async {
    if (_gpsLocating) return; // already in progress
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      setState(() {
        _gpsLocating = false;
        _gpsFailed = true;
      });
      return;
    }

    if (!mounted) return;
        setState(() {
      _gpsLocating = true;
      _gpsFailed = false;
    });
    _pulseController.repeat(reverse: true);

    final timeout =
        kIsWeb ? const Duration(seconds: 20) : const Duration(seconds: 8);
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(timeout);

          if (mounted) {
        _pulseController.stop();
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
          _locationIsReal = true;
          _gpsLocating = false;
          _gpsFailed = false;
          _applyGpsQuality(position.accuracy);
        });
        _mapController.move(_userLocation, 16.0);
      }
      _startLocationStream();
    } catch (_) {
      if (mounted) {
      setState(() {
          _gpsLocating = false;
          _gpsFailed = true;
        });
      }
    }
  }

  Future<void> _recenterToCurrentLocation() async {
    if (!_locationIsReal) {
      await _retryLocate();
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      ).timeout(const Duration(seconds: 6));
      if (!mounted) return;

      final live = LatLng(position.latitude, position.longitude);
      setState(() {
        _userLocation = live;
        _locationIsReal = true;
        _gpsFailed = false;
        _applyGpsQuality(position.accuracy);
      });
      _mapController.move(live, 16.0);
    } catch (_) {
      // Fall back to the latest stream-provided location if one-shot fix fails.
      if (_locationIsReal) {
        _mapController.move(_userLocation, 16.0);
      } else {
        await _retryLocate();
      }
    }
  }

  void _startLocationStream() {
    _positionSubscription?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (position) {
        if (!mounted) return;
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
          _locationIsReal = true;
          _gpsLocating = false;
          _gpsFailed = false;
          _applyGpsQuality(position.accuracy);
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _gpsLocating = false;
          _gpsFailed = !_locationIsReal;
        });
      },
    );
  }

  void _applyGpsQuality(double accuracyMeters) {
    _lastGpsAccuracyMeters = accuracyMeters;
    _lowGpsPrecision = accuracyMeters > _lowPrecisionThresholdMeters;
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'This app needs location permission to show your current position and calculate evacuation routes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Calculate distance between two points
  double _calculateDistance(LatLng from, LatLng to) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, from, to);
  }

  /// Handle evacuation center selection - Show routes
  Future<void> _onSelectCenter(EvacuationCenter center) async {
    if (!_locationIsReal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Waiting for current GPS fix. Please try again.'),
          duration: Duration(seconds: 3),
        ),
      );
      _retryLocate();
      return;
    }

    if (_isOpeningRoutes) return;
    setState(() {
      _isOpeningRoutes = true;
      _selectedCenter = center;
      _showBottomSheet = false;
    });

    // Navigate to routes selection screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoutesSelectionScreen(
          evacuationCenter: center,
          userLocation: _userLocation,
        ),
      ),
    );

    // If user selected a route
    if (result != null && result is app_route.Route) {
      setState(() {
        _activeRoute = result;
        _showBottomSheet = false;
        _isOpeningRoutes = false;
      });
    } else {
      // User canceled, show bottom sheet again
      setState(() {
        _selectedCenter = null;
        _showBottomSheet = true;
        _isOpeningRoutes = false;
      });
    }
  }

  /// Handle long press on map - Report hazard
  void _onLongPress(TapPosition tapPosition, LatLng location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: Colors.orange[700],
              ),
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
                    ).then((_) => _loadHazardReports()); // Reload after reporting
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
      ),
    );
  }
  
  /// Convert raw snake_case hazard type to a human-readable label.
  /// e.g. "fallen_electric_post" → "Fallen Electric Post"
  static String _formatHazardType(String raw) {
    if (raw.trim().isEmpty) return 'Unknown Hazard';
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  /// View hazard report details — privacy-aware.
  /// Own pending reports show full details; other residents' reports show
  /// only public, non-identifying safety information.
  void _viewHazardReport(Map<String, dynamic> report) {
    final isPending = report['status'] == 'pending';
    final isOffline = report['is_offline'] == true;
    final isCurrentUserReport = report['reported_by'] == ResidentHazardReportsService.currentUserId;
    final rawType = (report['type'] as String? ?? '').trim();
    final displayType = _formatHazardType(rawType);
    final locationBarangay = (report['location_barangay'] as String? ?? report['barangay'] as String? ?? '').trim();
    final locationMunicipality = (report['location_municipality'] as String? ?? '').trim();
    final locationLabel = (report['location_label'] as String? ?? '').trim();

    // Offline-queued report: show "pending sync" info
    if (isOffline) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.cloud_off, color: Colors.deepOrange, size: 28),
              const SizedBox(width: 12),
              const Expanded(child: Text('Pending Sync')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hazard Type: $displayType',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 8),
              const Text(
                'This report was saved offline and will be automatically uploaded when you reconnect to the internet.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepOrange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.sync, color: Colors.deepOrange[700], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Waiting for internet connection to sync.',
                        style: TextStyle(fontSize: 13, color: Colors.deepOrange[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (!isCurrentUserReport) {
      // Other resident's report — show safe public view only
      final area = locationBarangay.isNotEmpty
          ? locationBarangay
          : (locationMunicipality.isNotEmpty ? locationMunicipality : locationLabel);
      _showPublicHazardView(displayType, area, isPending);
      return;
    }

    // Own report — show full personal details
    final hasPhoto = report['has_photo'] == true;
    final hasVideo = report['has_video'] == true;
    final hasMedia = hasPhoto || hasVideo;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: isPending ? Colors.orange : Colors.red,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'My Hazard Report',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPending ? Colors.orange[100] : Colors.green[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isPending ? Colors.orange : Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isPending ? 'Pending Review' : 'Verified',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isPending ? Colors.orange[800] : Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Full report details (own report only)
                _buildDetailRow(Icons.dangerous, 'Hazard Type', displayType),
                if ((report['description'] as String? ?? '').isNotEmpty)
                _buildDetailRow(Icons.description, 'Description', report['description']),
                _buildDetailRow(
                  Icons.location_on, 
                  'Location', 
                  '${(report['lat'] as double).toStringAsFixed(4)}, ${(report['lng'] as double).toStringAsFixed(4)}',
                ),
                if (locationLabel.isNotEmpty)
                  _buildDetailRow(Icons.place_outlined, 'Address', locationLabel),
                if ((report['date_submitted'] as String? ?? '').isNotEmpty)
                  _buildDetailRow(Icons.access_time, 'Reported', report['date_submitted']),
                
                // Media Attachments (if any)
                if (hasMedia) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.attach_file, size: 20, color: Colors.grey[600]),
                      const SizedBox(width: 12),
                      const Text(
                        'Attachments',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildMediaGallery(report['media']),
                ],
                
                const SizedBox(height: 24),
                
                // Delete button (only for own pending reports)
                if (isPending)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteHazardReport(report);
                      },
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete Report'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Public-safe view for another resident's hazard report.
  /// Shows only: formatted hazard type, general area, status badge, safety message.
  void _showPublicHazardView(String displayType, String area, bool isPending) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isPending ? Colors.orange[50] : Colors.red[50],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: isPending ? Colors.orange[700] : Colors.red[700],
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Hazard Alert',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isPending ? Colors.orange[100] : Colors.green[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isPending ? Colors.orange : Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isPending ? 'Pending Verification' : 'Verified',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isPending ? Colors.orange[800] : Colors.green[800],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Hazard type
              _buildDetailRow(Icons.dangerous, 'Hazard Type', displayType),

              // General area from hazard coordinates (safe to show)
              if (area.isNotEmpty)
                _buildDetailRow(Icons.location_city, 'Area', area),

              const SizedBox(height: 20),

              // Safety message
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isPending ? Colors.orange[50] : Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPending ? Colors.orange[200]! : Colors.green[200]!,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: isPending ? Colors.orange[700] : Colors.green[700],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isPending
                            ? 'A hazard has been reported in this area and is awaiting review. Please proceed with caution.'
                            : 'Verified hazard reported in this area. Please proceed with caution.',
                        style: TextStyle(
                          fontSize: 14,
                          color: isPending ? Colors.orange[900] : Colors.green[900],
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPending ? Colors.orange[700] : Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Got it', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildMediaGallery(List media) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: media.map<Widget>((item) {
        final isImage = item['type'] == 'image';
        final rawUrl = (item['url'] ?? '').toString();
        final url = normalizeMediaUrl(rawUrl);
        return GestureDetector(
          onTap: isImage && url.isNotEmpty
              ? () => _openFullscreenImage(url)
              : null,
          child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: isImage
                ? Stack(
                    fit: StackFit.expand,
                        children: [
                      buildImageFromUrl(
                        url,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.zoom_in, color: Colors.white, size: 12),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam, color: Colors.grey[600], size: 32),
                      const SizedBox(height: 4),
                      Text('Video', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                    ],
                  ),
                  ),
          ),
        );
      }).toList(),
    );
  }

  void _openFullscreenImage(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Photo'),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: buildImageFromUrl(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// Delete hazard report
  Future<void> _deleteHazardReport(Map<String, dynamic> report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: const Text('Are you sure you want to delete this report?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final success = await _hazardReportsService.deletePendingReport(report['id']);
      if (success) {
        _loadHazardReports(); // Reload markers
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report deleted successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to delete report'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Clear active route and return to center selection
  void _clearRoute() {
    setState(() {
      _activeRoute = null;
      _selectedCenter = null;
      _showBottomSheet = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Only run the focus check when a navigation/notification has set the
    // pending flag — not on every setState rebuild.
    if (_pendingFocusCheck) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pendingFocusCheck) _checkAndFocusTargetLocation();
      });
    }
    return ExitConfirmScope(
      child: Scaffold(
      body: Stack(
              children: [
                // Map
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _userLocation,
                    initialZoom: 16.0,
                    minZoom: 13.5,
                    maxZoom: 18.0,
                    onLongPress: _onLongPress,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.thesis.evacuation.mobile',
                      maxZoom: 19,
                      // Pre-loads 1 tile outside the visible viewport so panning
                      // feels instant rather than waiting for new tiles to fetch.
                      panBuffer: 1,
                      tileProvider: _tileProvider,
                      errorTileCallback: (tile, error, _) {
                        // Silently swallow tile errors — placeholder already shown.
                      },
                    ),
                    
                    // Road Risk Layer — thin coloured overlay showing estimated
                    // road safety based on verified hazards and historical patterns.
                    if (_showRoadRiskLayer && _roadRiskSegments.isNotEmpty)
                      PolylineLayer(
                        polylines: _roadRiskSegments.map((seg) {
                          final Color c;
                          if (seg.risk < 0.30) {
                            c = Colors.green.withOpacity(0.55);
                          } else if (seg.risk < 0.65) {
                            c = Colors.orange.withOpacity(0.60);
                          } else {
                            c = Colors.red.withOpacity(0.65);
                          }
                          return Polyline(
                            points: [
                              LatLng(seg.startLat, seg.startLng),
                              LatLng(seg.endLat,   seg.endLng),
                            ],
                            color: c,
                            strokeWidth: 6.0,
                          );
                        }).toList(),
                    ),
                    
                    // Draw active route if selected
                    if (_activeRoute != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _activeRoute!.path.map((p) => LatLng(p.latitude, p.longitude)).toList(),
                            color: _getRouteColor(_activeRoute!.riskLevel),
                            strokeWidth: 5.0,
                          ),
                        ],
                      ),
                    
                    // Markers
                    MarkerLayer(
                      markers: [
                        // User location marker — only rendered once a real
                        // GPS or last-known position is confirmed.
                        // Never shown at the Bulan hardcoded default.
                        if (_locationIsReal)
                          Marker(
                            point: _userLocation,
                            width: 50,
                            height: 50,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.4),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.my_location,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),

                        // Evacuation centers
                        ..._evacuationCenters.map(
                          (center) => Marker(
                            point: LatLng(center.latitude, center.longitude),
                            width: 100,
                            height: 70,
                            child: GestureDetector(
                              onTap: () => _onSelectCenter(center),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      center.name.split(' ').first,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: MapMarkerStyle.evacuationCenterColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(
                                      MapMarkerStyle.evacuationCenterIcon,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        // Hazard report markers
                        ..._hazardReports.map(
                          (report) {
                            final isPending = report['status'] == 'pending';
                            final isOffline = report['is_offline'] == true;
                            final confirmationCount = report['confirmation_count'] as int? ?? 0;
                            final hasHighConfirmations = confirmationCount >= 3;
                            final isHighlighted =
                                _highlightedReportId != null &&
                                report['id']?.toString() == _highlightedReportId;

                            // Expanded hit area for highlighted marker
                            final markerSize = isHighlighted ? 72.0 : (hasHighConfirmations ? 55.0 : 40.0);

                            return Marker(
                              point: LatLng(report['lat'], report['lng']),
                              width: markerSize,
                              height: markerSize,
                              child: GestureDetector(
                                onTap: () => _viewHazardReport(report),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Pulsing outer ring – only for the highlighted marker
                                    if (isHighlighted)
                                      AnimatedBuilder(
                                        animation: _pulseAnimation,
                                        builder: (_, __) => Transform.scale(
                                          scale: _pulseAnimation.value,
                                child: Container(
                                            width: 56,
                                            height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.orangeAccent.withOpacity(
                                                  1.6 - _pulseAnimation.value,
                                                ),
                                                width: 3,
                                              ),
                                              color: Colors.orangeAccent.withOpacity(
                                                (1.6 - _pulseAnimation.value) * 0.15,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                    // Main hazard marker
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isHighlighted
                                            ? Colors.orange[700]
                                            : isOffline
                                                ? Colors.deepOrange[400]
                                                : (isPending
                                                    ? MapMarkerStyle.pendingHazardColor
                                                    : MapMarkerStyle.verifiedHazardColor),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isHighlighted
                                              ? Colors.white
                                              : (hasHighConfirmations ? Colors.green : Colors.white),
                                          width: isHighlighted ? 3 : (hasHighConfirmations ? 3 : 2),
                                        ),
                                    boxShadow: [
                                      BoxShadow(
                                            color: isHighlighted
                                                ? Colors.orangeAccent.withOpacity(0.6)
                                                : Colors.black.withOpacity(0.3),
                                            blurRadius: isHighlighted ? 10 : 4,
                                            spreadRadius: isHighlighted ? 2 : 0,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                        isOffline
                                            ? Icons.cloud_upload
                                            : (isHighlighted
                                                ? MapMarkerStyle.verifiedHazardIcon
                                                : (isPending
                                                    ? MapMarkerStyle.pendingHazardIcon
                                                    : MapMarkerStyle.verifiedHazardIcon)),
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                    ),

                                    // Confirmation badge (if high confirmations)
                                    if (hasHighConfirmations)
                                      Positioned(
                                        top: isHighlighted ? 8 : 0,
                                        right: isHighlighted ? 8 : 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                          child: Text(
                                            '$confirmationCount',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),

                // Top bar with location and settings
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.blue),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Your Location',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          // Notification bell icon
                          Stack(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.notifications),
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const NotificationsScreen(),
                                    ),
                                  );
                                  _loadNotificationCount(); // Reload count after viewing
                                  _checkAndFocusTargetLocation(); // Check for map focus request
                                },
                              ),
                              if (_unreadNotificationsCount > 0)
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Text(
                                      _unreadNotificationsCount > 9 ? '9+' : '$_unreadNotificationsCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SettingsScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Legend card
                if (!_showBottomSheet && _activeRoute == null)
                  Positioned(
                    top: 100,
                    left: 16,
                    child: Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Map Legend',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildLegendItem(
                              Icons.location_on,
                              'Evacuation Center',
                              Colors.red[600]!,
                            ),
                            _buildLegendItem(
                              Icons.my_location,
                              'Your Location',
                              Colors.blue,
                            ),
                            _buildLegendItem(
                              Icons.warning,
                              'Verified Hazard',
                              Colors.red[600]!,
                            ),
                            _buildLegendItem(
                              Icons.warning,
                              'Your Pending Report',
                              Colors.yellow[700]!,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── Draggable Evacuation Centers Panel ──────────────────
                if (_showBottomSheet)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {}, // absorb taps to prevent map interaction
                      onVerticalDragUpdate: (details) {
                        setState(() {
                          _panelHeight = (_panelHeight - details.delta.dy)
                              .clamp(_kPanelCollapsed, _kPanelExpanded);
                        });
                      },
                      onVerticalDragEnd: (details) {
                        // Snap to nearest of three positions
                        final snaps = [_kPanelCollapsed, _kPanelHalf, _kPanelExpanded];
                        final closest = snaps.reduce((a, b) =>
                            (_panelHeight - a).abs() < (_panelHeight - b).abs() ? a : b);
                        setState(() => _panelHeight = closest);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        height: _panelHeight,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                            // Drag handle bar
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Center(
                                child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                              ),
                            ),
                            // Header row
                          Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Nearby Evacuation Centers',
                                  style: TextStyle(
                                      fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                  Row(
                                    children: [
                                Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_evacuationCenters.length} Available',
                                    style: TextStyle(
                                            fontSize: 11,
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: () => setState(() =>
                                            _panelHeight = _panelHeight > _kPanelCollapsed
                                                ? _kPanelCollapsed
                                                : _kPanelHalf),
                                        child: AnimatedRotation(
                                          turns: _panelHeight > _kPanelCollapsed ? 0 : 0.5,
                                          duration: const Duration(milliseconds: 250),
                                          child: Icon(Icons.expand_less, color: Colors.grey[600]),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Scrollable list fills remaining height
                            Expanded(
                              child: _evacuationCenters.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.location_off_outlined,
                                                size: 48, color: Colors.grey[300]),
                                            const SizedBox(height: 12),
                                            Text(
                                              'No Evacuation Centers Found',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Centers will appear here once the server is reachable.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _evacuationCenters.length,
                              itemBuilder: (context, index) {
                                final center = _evacuationCenters[index];
                                  final distance = _calculateDistance(
                                    _userLocation,
                                        LatLng(center.latitude, center.longitude),
                                  );

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                          width: 44,
                                          height: 44,
                                        decoration: BoxDecoration(
                                          color: Colors.red[50],
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(Icons.emergency, color: Colors.red[700], size: 26),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              center.name,
                                              style: const TextStyle(
                                                  fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                              const SizedBox(height: 3),
                                            Text(
                                                '${distance.toStringAsFixed(1)} km away',
                                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                            ),
                                          ],
                                        ),
                                      ),
                                      TextButton(
                                          onPressed: _isOpeningRoutes
                                              ? null
                                              : () => _onSelectCenter(center),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.blue[700],
                                        ),
                                          child: _isOpeningRoutes &&
                                                  _selectedCenter?.id == center.id
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : const Row(
                                          children: [
                                              Text('Routes'),
                                            SizedBox(width: 4),
                                              Icon(Icons.arrow_forward, size: 14),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            ), // ListView.builder
                            const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  ),
                // Active navigation bar
                if (_activeRoute != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[600],
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.navigation,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Navigating to',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        _selectedCenter?.name ?? '',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${_activeRoute!.totalDistance.toStringAsFixed(1)} km',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _clearRoute,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.green[700],
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: const Text('End Navigation'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Compass/recenter button — repositions with panel height.
                // Road Risk Layer toggle FAB
                Positioned(
                  bottom: _showBottomSheet
                      ? _panelHeight + 80
                      : (_activeRoute != null ? 204 : 144),
                  right: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'riskLayer',
                    onPressed: _toggleRoadRiskLayer,
                    backgroundColor: _showRoadRiskLayer
                        ? Colors.orange.shade700
                        : Colors.white,
                    tooltip: 'Road Risk Layer',
                    child: Icon(
                      Icons.layers_rounded,
                      color: _showRoadRiskLayer ? Colors.white : Colors.grey[700],
                    ),
                  ),
                ),

                // If GPS has not resolved yet, tapping retries the location
                // request instead of centering on the Bulan placeholder.
                Positioned(
                  bottom: _showBottomSheet
                      ? _panelHeight + 16
                      : (_activeRoute != null ? 140 : 80),
                  right: 16,
                  child: FloatingActionButton(
                    heroTag: 'recenter',
                    onPressed: _recenterToCurrentLocation,
                    backgroundColor: Colors.white,
                    child: Icon(
                      _locationIsReal
                          ? Icons.my_location
                          : Icons.location_searching,
                      color: _locationIsReal ? Colors.blue[700] : Colors.orange,
                    ),
                  ),
                ),

                // GPS status pill — three states:
                //   searching  → spinner + "Getting your location…"
                //   failed     → warning icon + "Location unavailable – Tap to retry"
                //   resolved   → hidden
                if (_gpsLocating || _gpsFailed)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 56,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: _gpsFailed ? _retryLocate : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _gpsFailed
                                ? Colors.orange.shade800
                                : Colors.black.withValues(alpha: 0.70),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                ),
              ],
            ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_gpsLocating)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                const Icon(Icons.location_off,
                                    color: Colors.white, size: 14),
                              const SizedBox(width: 8),
                              Text(
                                _gpsFailed
                                    ? 'Location unavailable — Tap to retry'
                                    : kIsWeb
                                        ? 'Allow location in browser — getting your position…'
                                        : 'Getting your location…',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                if (_locationIsReal && _lowGpsPrecision && !_gpsLocating)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 96,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade700,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          'Low GPS precision (~${_lastGpsAccuracyMeters?.toStringAsFixed(0) ?? "?"}m). Enable precise location.',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Offline mode indicator — always on top of all other overlays
                const OfflineBanner(),
              ],
            ),
      ), // Scaffold
    ); // ExitConfirmScope
  }

  Widget _buildLegendItem(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Color _getRouteColor(app_route.RiskLevel riskLevel) {
    switch (riskLevel) {
      case app_route.RiskLevel.green:
        return Colors.green;
      case app_route.RiskLevel.yellow:
        return Colors.orange;
      case app_route.RiskLevel.red:
        return Colors.red;
    }
  }
}
