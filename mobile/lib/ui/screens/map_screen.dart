import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/evacuation_center.dart';
import '../../models/route.dart' as app_route;
import '../../data/mock_evacuation_centers.dart';
import '../../features/routing/routing_service.dart';
import '../../features/hazards/hazard_service.dart';
import '../../features/residents/resident_hazard_reports_service.dart';
import '../../features/residents/resident_notifications_service.dart';
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

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final RoutingService _routingService = RoutingService();
  final ResidentHazardReportsService _hazardReportsService = ResidentHazardReportsService();
  final ResidentNotificationsService _notificationsService = ResidentNotificationsService();
  
  LatLng? _userLocation;
  bool _isLoading = true;
  final List<EvacuationCenter> _evacuationCenters = getMockEvacuationCenters();
  
  // Selected center and routes
  EvacuationCenter? _selectedCenter;
  List<app_route.Route>? _calculatedRoutes;
  app_route.Route? _activeRoute;
  
  // Show bottom sheet
  bool _showBottomSheet = true;
  
  // Hazard reports
  List<Map<String, dynamic>> _hazardReports = [];
  int _unreadNotificationsCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _loadHazardReports();
    _loadNotificationCount();
  }
  
  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check for target location when widget updates
    _checkAndFocusTargetLocation();
  }
  
  /// Check if we should focus on a target location from notification
  Future<void> _checkAndFocusTargetLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final shouldFocus = prefs.getBool('map_should_focus') ?? false;
    
    print('🗺️ MAP: Checking for target focus flag: $shouldFocus');
    
    if (shouldFocus) {
      final targetLat = prefs.getDouble('map_target_lat');
      final targetLng = prefs.getDouble('map_target_lng');
      
      print('🗺️ MAP: Target coordinates: $targetLat, $targetLng');
      
      if (targetLat != null && targetLng != null && mounted) {
        // Move to target location
        _mapController.move(LatLng(targetLat, targetLng), 17.0);
        
        // Clear the flags
        await prefs.remove('map_should_focus');
        await prefs.remove('map_target_lat');
        await prefs.remove('map_target_lng');
        
        print('📍 MAP: Focused on target location: $targetLat, $targetLng');
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

          // Check if location is reasonable (within Philippines bounds)
          // Philippines: Lat 4-21, Lng 116-127
          final isInPhilippines = position.latitude >= 4.0 && 
                                   position.latitude <= 21.0 &&
                                   position.longitude >= 116.0 && 
                                   position.longitude <= 127.0;

          setState(() {
            // Use actual location if in Philippines, otherwise default to Bulan
            _userLocation = isInPhilippines
                ? LatLng(position.latitude, position.longitude)
                : LatLng(12.6699, 123.8758); // Default to Bulan, Sorsogon
            _isLoading = false;
          });

          if (!isInPhilippines) {
            print('⚠️ Location outside Philippines (${position.latitude}, ${position.longitude}), using Bulan default');
          }
        } catch (e) {
          // If GPS fails, use Bulan default
          print('⚠️ GPS error: $e, using Bulan default');
          setState(() {
            _userLocation = LatLng(12.6699, 123.8758);
            _isLoading = false;
          });
        }

        // Move map after widget is built - but check for target location first
        if (_userLocation != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (mounted) {
              // Check if we should focus on a specific target location from notification
              final prefs = await SharedPreferences.getInstance();
              final shouldFocus = prefs.getBool('map_should_focus') ?? false;
              
              if (shouldFocus) {
                final targetLat = prefs.getDouble('map_target_lat');
                final targetLng = prefs.getDouble('map_target_lng');
                
                if (targetLat != null && targetLng != null) {
                  // Move to target location instead of user location
                  _mapController.move(LatLng(targetLat, targetLng), 17.0);
                  
                  // Clear the flags
                  await prefs.remove('map_should_focus');
                  await prefs.remove('map_target_lat');
                  await prefs.remove('map_target_lng');
                  
                  print('📍 Map focused on target location: $targetLat, $targetLng');
                } else {
                  // Default: move to user location
                  _mapController.move(_userLocation!, 16.0);
                }
              } else {
                // Default: move to user location
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
        return Container(
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
                ? Image.network(
                    item['url'],
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
        );
      }).toList(),
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
    return Scaffold(
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
                    initialCenter: _userLocation ?? LatLng(12.6699, 123.8758),
                    initialZoom: 16.0,
                    minZoom: 10.0,
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
                            return Marker(
                              point: LatLng(report['lat'], report['lng']),
                              width: 40,
                              height: 40,
                              child: GestureDetector(
                                onTap: () => _viewHazardReport(report),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isPending ? Colors.yellow[700] : Colors.red[600],
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.warning,
                                    color: Colors.white,
                                    size: 24,
                                  ),
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

                // Nearby evacuation centers bottom sheet
                if (_showBottomSheet)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Nearby Evacuation Centers',
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
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_evacuationCenters.length} Available',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 220,
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
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Colors.red[50],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.emergency,
                                          color: Colors.red[700],
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              center.name,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${distance.toStringAsFixed(1)} km',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
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
                                            Text('View Routes'),
                                            SizedBox(width: 4),
                                            Icon(Icons.arrow_forward, size: 16),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
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

                // Compass/recenter button
                Positioned(
                  bottom: _showBottomSheet ? 260 : (_activeRoute != null ? 140 : 80),
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
              ],
            ),
    );
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
