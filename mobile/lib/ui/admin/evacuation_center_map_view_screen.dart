import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/evacuation_center.dart';

/// Full-screen map view for a specific evacuation center
/// Shows the center's location with detailed information overlay
class EvacuationCenterMapViewScreen extends StatefulWidget {
  final EvacuationCenter center;

  const EvacuationCenterMapViewScreen({
    super.key,
    required this.center,
  });

  @override
  State<EvacuationCenterMapViewScreen> createState() => _EvacuationCenterMapViewScreenState();
}

class _EvacuationCenterMapViewScreenState extends State<EvacuationCenterMapViewScreen> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final centerLocation = LatLng(widget.center.latitude, widget.center.longitude);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.center.name),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Full-screen map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: centerLocation,
              initialZoom: 16.0,
              minZoom: 12.0,
              maxZoom: 18.0,
            ),
            children: [
              // OpenStreetMap tiles
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.evacroute.mobile',
              ),

              // Evacuation center marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: centerLocation,
                    width: 100,
                    height: 100,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Label above marker
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A8A),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            widget.center.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Icon marker
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.location_city,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Information card at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title with status badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.center.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: widget.center.isOperational ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.center.isOperational ? Icons.check_circle : Icons.cancel,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.center.isOperational ? 'OPERATIONAL' : 'NOT OPERATIONAL',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Information rows
                  _buildInfoRow(
                    Icons.location_on,
                    'Barangay',
                    widget.center.barangay ?? 'Zone ${widget.center.id}',
                    Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.home,
                    'Address',
                    widget.center.fullAddress,
                    Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.phone,
                    'Contact',
                    widget.center.contactNumber ?? '0917-123-45${widget.center.id}7',
                    Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.gps_fixed,
                    'Coordinates',
                    '${widget.center.latitude.toStringAsFixed(6)}, ${widget.center.longitude.toStringAsFixed(6)}',
                    Colors.purple,
                  ),
                ],
              ),
            ),
          ),

          // Zoom controls (top right)
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(
                      centerLocation,
                      (currentZoom + 1).clamp(12.0, 18.0),
                    );
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.add, color: Color(0xFF1E3A8A)),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(
                      centerLocation,
                      (currentZoom - 1).clamp(12.0, 18.0),
                    );
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.remove, color: Color(0xFF1E3A8A)),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  onPressed: () {
                    _mapController.move(centerLocation, 16.0);
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.my_location, color: Color(0xFF1E3A8A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
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
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
