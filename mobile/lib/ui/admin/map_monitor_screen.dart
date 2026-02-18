import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../features/admin/admin_mock_service.dart';
import '../../models/hazard_report.dart';
import '../../models/evacuation_center.dart';

/// Map Monitor Screen - Full-screen map with hazard and evacuation center overlays.
/// 
/// Allows MDRRMO to monitor hazards and evacuation centers on a map.
class MapMonitorScreen extends StatefulWidget {
  const MapMonitorScreen({super.key});

  @override
  State<MapMonitorScreen> createState() => _MapMonitorScreenState();
}

class _MapMonitorScreenState extends State<MapMonitorScreen> {
  final MapController _mapController = MapController();
  final AdminMockService _adminService = AdminMockService();
  
  bool _showEvacuationCenters = true;
  bool _showVerifiedHazards = true;
  bool _showPendingHazards = true;
  bool _showRiskOverlay = false;
  
  List<HazardReport> _reports = [];
  List<EvacuationCenter> _centers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final reports = await _adminService.getReports();
      final centers = await _adminService.getEvacuationCenters();
      
      setState(() {
        _reports = reports;
        _centers = centers;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading map data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Monitor'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: _showLayerControls,
            tooltip: 'Layer Controls',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Map
                FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(
                    initialCenter: LatLng(12.6699, 123.8758),
                    initialZoom: 14.0,
                    minZoom: 10.0,
                    maxZoom: 18.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.thesis.evacuation.mobile',
                      maxZoom: 19,
                    ),
                    
                    // Evacuation Centers
                    if (_showEvacuationCenters)
                      MarkerLayer(
                        markers: _buildEvacuationCenterMarkers(),
                      ),
                    
                    // Verified Hazards
                    if (_showVerifiedHazards)
                      MarkerLayer(
                        markers: _buildVerifiedHazardMarkers(),
                      ),
                    
                    // Pending Hazards
                    if (_showPendingHazards)
                      MarkerLayer(
                        markers: _buildPendingHazardMarkers(),
                      ),
                  ],
                ),
                
                // Legend
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: _buildLegend(),
                ),
              ],
            ),
    );
  }

  List<Marker> _buildEvacuationCenterMarkers() {
    return _centers.map((center) {
      return Marker(
        point: LatLng(center.latitude, center.longitude),
        width: 50,
        height: 50,
        child: GestureDetector(
          onTap: () => _showCenterInfo(center),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.location_city,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildVerifiedHazardMarkers() {
    // Show only approved hazards
    final verifiedReports = _reports.where((r) => r.status == HazardStatus.approved).toList();
    
    return verifiedReports.map((report) {
      return Marker(
        point: LatLng(report.latitude, report.longitude),
        width: 50,
        height: 50,
        child: GestureDetector(
          onTap: () => _showHazardInfo(report),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.warning,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildPendingHazardMarkers() {
    // Show only pending hazards
    final pendingReports = _reports.where((r) => r.status == HazardStatus.pending).toList();
    
    return pendingReports.map((report) {
      return Marker(
        point: LatLng(report.latitude, report.longitude),
        width: 50,
        height: 50,
        child: GestureDetector(
          onTap: () => _showHazardInfo(report),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.warning_amber,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  void _showCenterInfo(EvacuationCenter center) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(center.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📍 ${center.description}'),
            const SizedBox(height: 8),
            Text('📌 ${center.latitude.toStringAsFixed(4)}, ${center.longitude.toStringAsFixed(4)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showHazardInfo(HazardReport report) {
    final String statusText = report.status == HazardStatus.approved ? 'Verified' : 'Pending';
    final Color statusColor = report.status == HazardStatus.approved ? Colors.red : Colors.orange;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: statusColor, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _formatHazardType(report.hazardType),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(report.description),
            const SizedBox(height: 8),
            Text(
              '📌 ${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            if (report.naiveBayesScore != null) ...[
              const SizedBox(height: 8),
              Text(
                'AI Confidence: ${(report.naiveBayesScore! * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatHazardType(String type) {
    return type
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Legend',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildLegendItem(Colors.blue, 'Evacuation Centers'),
          _buildLegendItem(Colors.red, 'Verified Hazards'),
          _buildLegendItem(Colors.orange, 'Pending Hazards'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showLayerControls() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Layer Controls',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Evacuation Centers'),
              value: _showEvacuationCenters,
              onChanged: (value) {
                setState(() {
                  _showEvacuationCenters = value;
                });
                Navigator.pop(context);
              },
            ),
            SwitchListTile(
              title: const Text('Verified Hazards'),
              value: _showVerifiedHazards,
              onChanged: (value) {
                setState(() {
                  _showVerifiedHazards = value;
                });
                Navigator.pop(context);
              },
            ),
            SwitchListTile(
              title: const Text('Pending Hazards'),
              value: _showPendingHazards,
              onChanged: (value) {
                setState(() {
                  _showPendingHazards = value;
                });
                Navigator.pop(context);
              },
            ),
            SwitchListTile(
              title: const Text('Risk Overlay'),
              value: _showRiskOverlay,
              onChanged: (value) {
                setState(() {
                  _showRiskOverlay = value;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
