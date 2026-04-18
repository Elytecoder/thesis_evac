import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/api_config.dart';
import '../../core/services/connectivity_service.dart';
import '../../models/evacuation_center.dart';
import '../../models/route.dart' as app_route;
import '../../data/mock_evacuation_centers.dart';
import '../../features/routing/routing_service.dart';
import '../../features/hazards/hazard_service.dart';
import '../../features/residents/resident_hazard_reports_service.dart';
import '../../features/residents/resident_notifications_service.dart';
import '../widgets/offline_banner.dart';
import '../widgets/exit_confirm_scope.dart';
import '../widgets/report_media_preview.dart' show normalizeMediaUrl;
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

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final RoutingService _routingService = RoutingService();
  final ResidentHazardReportsService _hazardReportsService = ResidentHazardReportsService();
  final ResidentNotificationsService _notificationsService = ResidentNotificationsService();
  final ConnectivityService _connectivity = ConnectivityService();
  
  LatLng? _userLocation;
  bool _isLoading = true;
  List<EvacuationCenter> _evacuationCenters = [];
  
  // Selected center and routes
  EvacuationCenter? _selectedCenter;
  List<app_route.Route>? _calculatedRoutes;
  app_route.Route? _activeRoute;
  
  // Show bottom sheet
  bool _showBottomSheet = true;
  // Panel height for draggable 3-snap evacuation center panel.
  static const double _kPanelCollapsed = 72.0;
  static const double _kPanelHalf = 240.0;
  static const double _kPanelExpanded = 380.0;
  double _panelHeight = _kPanelHalf;
  
  // Hazard reports
  List<Map<String, dynamic>> _hazardReports = [];
  int _unreadNotificationsCount = 0;

  // Notification highlight: which report is currently highlighted on the map
  String? _highlightedReportId;
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
    _loadEvacuationCenters();
    _initializeMap();
    _loadHazardReports();
    _loadNotificationCount();
    _listenForReconnect();
  }

  /// Reload live data when connectivity is restored so the map stays current.
  void _listenForReconnect() {
    _connectivity.onConnectionChange.listen((isOnline) {
      if (isOnline && mounted) {
        _loadEvacuationCenters();
        _loadHazardReports();
      }
    });
  }

  /// Load evacuation centers from API (residents see same data as MDRRMO updates).
  Future<void> _loadEvacuationCenters() async {
    if (ApiConfig.useMockData) {
      setState(() {
        _evacuationCenters = getMockEvacuationCenters();
      });
      return;
    }
    try {
      final centers = await _routingService.getEvacuationCenters();
      if (mounted) {
        setState(() {
          _evacuationCenters = centers;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _evacuationCenters = [];
        });
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
    // Check for target location when widget updates
    _checkAndFocusTargetLocation();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
  
  /// Check if we should focus on a target location from notification.
  /// Also reads a highlight report_id so the specific hazard marker pulses.
  Future<void> _checkAndFocusTargetLocation() async {
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
  
  Future<void> _loadHazardReports() async {
    try {
      final reports = await _hazardReportsService.getMapReports();
      setState(() {
        _hazardReports = reports;
      });
    } catch (e) {
      print('Error loading hazard reports: $e');
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

  Future<void> _initializeMap() async {
    try {
      final permissionStatus = await Permission.location.request();

      if (permissionStatus.isGranted) {
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );

          setState(() {
            // Always use actual GPS position when available
            _userLocation = LatLng(position.latitude, position.longitude);
            _isLoading = false;
          });
          print('📍 Current location: ${position.latitude}, ${position.longitude}');
        } catch (e) {
          // Only use Bulan when GPS actually fails (no position available)
          print('⚠️ GPS error: $e, using Bulan default');
          setState(() {
            _userLocation = LatLng(12.6699, 123.8758);
            _isLoading = false;
          });
        }

        // Move map after widget is built - delegate to shared focus helper
        if (_userLocation != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (mounted) {
              final prefs = await SharedPreferences.getInstance();
              final shouldFocus = prefs.getBool('map_should_focus') ?? false;
              if (shouldFocus) {
                await _checkAndFocusTargetLocation();
              } else {
                _mapController.move(_userLocation!, 16.0);
              }
            }
          });
        }
      } else {
        setState(() {
          _userLocation = LatLng(12.6699, 123.8758);
          _isLoading = false;
        });
        
        // Move map after widget is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _mapController.move(_userLocation!, 16.0);
          }
        });
        _showPermissionDeniedDialog();
      }
    } catch (e) {
      print('⚠️ Map initialization error: $e');
      setState(() {
        _userLocation = LatLng(12.6699, 123.8758);
        _isLoading = false;
      });
      
      // Move map after widget is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(_userLocation!, 16.0);
        }
      });
    }
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
              openAppSettings();
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
    if (_userLocation == null) return;

    setState(() {
      _selectedCenter = center;
      _showBottomSheet = false;
    });

    // Navigate to routes selection screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoutesSelectionScreen(
          evacuationCenter: center,
          userLocation: _userLocation!,
        ),
      ),
    );

    // If user selected a route
    if (result != null && result is app_route.Route) {
      setState(() {
        _activeRoute = result;
        _showBottomSheet = false;
      });
    } else {
      // User canceled, show bottom sheet again
      setState(() {
        _selectedCenter = null;
        _showBottomSheet = true;
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
                          userLocation: _userLocation != null
                              ? LatLng(_userLocation!.latitude, _userLocation!.longitude)
                              : null,
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
  
  /// View hazard report details
  void _viewHazardReport(Map<String, dynamic> report) {
    final isPending = report['status'] == 'pending';
    final isCurrentUserReport = report['reported_by'] == ResidentHazardReportsService.currentUserId;
    final hasMedia = report['media'] != null && (report['media'] as List).isNotEmpty;
    
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
                        'Hazard Report',
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
                
                // Report Details
                _buildDetailRow(Icons.dangerous, 'Hazard Type', report['type']),
                _buildDetailRow(Icons.description, 'Description', report['description']),
                _buildDetailRow(
                  Icons.location_on, 
                  'Location', 
                  '${report['lat'].toStringAsFixed(4)}, ${report['lng'].toStringAsFixed(4)}'
                ),
                _buildDetailRow(Icons.calendar_today, 'Date Submitted', report['date_submitted']),
                
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
                
                // Delete button (only for pending reports by current user)
                if (isPending && isCurrentUserReport)
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
                      Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, color: Colors.grey[400]),
                              const SizedBox(height: 4),
                              Text('Image', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                            ],
                          );
                        },
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
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 64),
              ),
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
    // When returning from Notifications "View on Map", focus on report location
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndFocusTargetLocation();
    });
    return ExitConfirmScope(
      child: Scaffold(
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Getting your location...'),
                ],
              ),
            )
          : Stack(
              children: [
                // Map
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _userLocation ?? const LatLng(12.6699, 123.8758),
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
                        // User location
                        if (_userLocation != null)
                          Marker(
                            point: _userLocation!,
                            width: 50,
                            height: 50,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
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
                                      color: Colors.red[600],
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.white,
                                      size: 24,
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
                                            : (isPending ? Colors.yellow[700] : Colors.red[600]),
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
                                        isHighlighted ? Icons.warning_amber_rounded : Icons.warning,
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
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _evacuationCenters.length,
                                itemBuilder: (context, index) {
                                  final center = _evacuationCenters[index];
                                  final distance = _userLocation != null
                                      ? _calculateDistance(
                                          _userLocation!,
                                          LatLng(center.latitude, center.longitude),
                                        )
                                      : 0.0;

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
                                          onPressed: () => _onSelectCenter(center),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.blue[700],
                                          ),
                                          child: const Row(
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
                            ),
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

                // Compass/recenter button — repositions with panel height
                Positioned(
                  bottom: _showBottomSheet
                      ? _panelHeight + 16
                      : (_activeRoute != null ? 140 : 80),
                  right: 16,
                  child: FloatingActionButton(
                    heroTag: 'recenter',
                    onPressed: () {
                      if (_userLocation != null) {
                        _mapController.move(_userLocation!, 16.0);
                      }
                    },
                    backgroundColor: Colors.white,
                    child: Icon(Icons.my_location, color: Colors.blue[700]),
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
