import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../core/auth/session_storage.dart';
import '../../features/hazards/hazard_service.dart';
import '../../features/evacuation/evacuation_center_service.dart';
import '../../models/hazard_report.dart';
import '../../models/evacuation_center.dart';
import '../../models/route.dart' as app_route;
import '../widgets/map_marker_style.dart';

/// Map Monitor Screen — Full-screen map for MDRRMO with hazard overlays and
/// road risk layer. Navigated to from the "High Risk Roads" dashboard tile,
/// which sets `map_monitor_show_risk_layer` in SharedPreferences to auto-enable
/// the risk overlay.
class MapMonitorScreen extends StatefulWidget {
  const MapMonitorScreen({super.key});

  @override
  State<MapMonitorScreen> createState() => _MapMonitorScreenState();
}

class _MapMonitorScreenState extends State<MapMonitorScreen> with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final HazardService _hazardService = HazardService();
  final EvacuationCenterService _evacuationCenterService = EvacuationCenterService();

  bool _showEvacuationCenters = true;
  bool _showVerifiedHazards = true;
  bool _showPendingHazards = true;
  bool _showRoadRiskLayer = false;

  List<HazardReport> _reports = [];
  List<EvacuationCenter> _centers = [];
  List<app_route.RoadRiskSegment> _riskSegments = [];

  bool _isLoading = true;
  bool _riskLayerLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _checkAutoShowRiskLayer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called when the app resumes or screen becomes visible again.
  /// Re-checks the SharedPreferences flag so navigating back from a different
  /// tab (after tapping the dashboard tile) still activates the layer.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAutoShowRiskLayer();
    }
  }

  Future<void> _checkAutoShowRiskLayer() async {
    final prefs = await SharedPreferences.getInstance();
    final should = prefs.getBool('map_monitor_show_risk_layer') ?? false;
    if (should) {
      await prefs.remove('map_monitor_show_risk_layer');
      if (mounted && !_showRoadRiskLayer) {
        setState(() => _showRoadRiskLayer = true);
        if (_riskSegments.isEmpty) _loadRoadRiskLayer();
      }
    }
  }

  Future<void> _loadData() async {
    try {
      final pending = await _hazardService.getPendingReports();
      final rejected = await _hazardService.getRejectedReports();
      // Use MDRRMO full-detail approved endpoint; do not use resident public
      // verified endpoint here because it strips technical report fields.
      final approved = await _hazardService.getApprovedReports();
      final reports = <HazardReport>[...pending, ...rejected, ...approved];
      final centers = await _evacuationCenterService.getEvacuationCenters(includeInactive: true);
      if (mounted) {
        setState(() {
          _reports = reports;
          _centers = centers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load map data. Pull down to retry.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadRoadRiskLayer() async {
    if (_riskLayerLoading) return;
    setState(() => _riskLayerLoading = true);
    try {
      final apiClient = ApiClient();
      final token = await SessionStorage.readToken();
      if (token != null) apiClient.setAuthToken(token);
      final response = await apiClient.get(ApiConfig.roadRiskLayerEndpoint);
      final data = response.data as Map<String, dynamic>;
      final raw = data['road_risk_segments'] as List<dynamic>?;
      if (raw != null && mounted) {
        final segs = raw
            .map((e) => app_route.RoadRiskSegment.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList();
        setState(() {
          _riskSegments = segs;
          _riskLayerLoading = false;
        });

        // Zoom to highest-risk segment if any
        final highRisk = segs.where((s) => s.risk >= 0.70).toList();
        if (highRisk.isNotEmpty) {
          final h = highRisk.first;
          _mapController.move(
            LatLng((h.startLat + h.endLat) / 2, (h.startLng + h.endLng) / 2),
            15.5,
          );
        }
      } else if (mounted) {
        setState(() => _riskLayerLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _riskLayerLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load road risk data. Try again.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _toggleRoadRiskLayer() {
    final newVal = !_showRoadRiskLayer;
    setState(() => _showRoadRiskLayer = newVal);
    if (newVal && _riskSegments.isEmpty) {
      _loadRoadRiskLayer();
    }
  }

  Color _riskColor(double risk) {
    if (risk >= 0.70) return Colors.red.withOpacity(0.75);
    if (risk >= 0.30) return Colors.orange.withOpacity(0.70);
    return Colors.green.withOpacity(0.55);
  }

  String _riskLabel(double risk) {
    if (risk >= 0.70) return 'High Risk';
    if (risk >= 0.30) return 'Moderate Risk';
    return 'Low Risk';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Monitor'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          // Road risk layer toggle button
          if (_riskLayerLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(
                Icons.remove_road,
                color: _showRoadRiskLayer ? Colors.yellowAccent : Colors.white,
              ),
              tooltip: _showRoadRiskLayer ? 'Hide Road Risk Layer' : 'Show Road Risk Layer',
              onPressed: _toggleRoadRiskLayer,
            ),
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: _showLayerControls,
            tooltip: 'Layer Controls',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadData();
              if (_showRoadRiskLayer) {
                setState(() => _riskSegments = []);
                _loadRoadRiskLayer();
              }
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(
                    initialCenter: LatLng(12.6699, 123.8758),
                    initialZoom: 14.0,
                    minZoom: 13.0,
                    maxZoom: 18.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.thesis.evacuation.mobile',
                      maxZoom: 19,
                    ),

                    // ── Road Risk Layer ───────────────────────────────────────
                    if (_showRoadRiskLayer && _riskSegments.isNotEmpty)
                      PolylineLayer(
                        polylines: _riskSegments.map((seg) {
                          return Polyline(
                            points: [
                              LatLng(seg.startLat, seg.startLng),
                              LatLng(seg.endLat, seg.endLng),
                            ],
                            color: _riskColor(seg.risk),
                            strokeWidth: 6.0,
                          );
                        }).toList(),
                      ),

                    // ── Evacuation Centers ────────────────────────────────────
                    if (_showEvacuationCenters)
                      MarkerLayer(markers: _buildEvacuationCenterMarkers()),

                    // ── Verified Hazards ──────────────────────────────────────
                    if (_showVerifiedHazards)
                      MarkerLayer(markers: _buildVerifiedHazardMarkers()),

                    // ── Pending Hazards ───────────────────────────────────────
                    if (_showPendingHazards)
                      MarkerLayer(markers: _buildPendingHazardMarkers()),
                  ],
                ),

                // ── No high-risk notice when layer is on but all roads safe ──
                if (_showRoadRiskLayer && !_riskLayerLoading && _riskSegments.isNotEmpty)
                  ..._buildNoHighRiskBanner(),

                // ── Legend ────────────────────────────────────────────────────
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: _buildLegend(),
                ),
              ],
            ),
    );
  }

  List<Widget> _buildNoHighRiskBanner() {
    final anyHighRisk = _riskSegments.any((s) => s.risk >= 0.70);
    if (anyHighRisk) return [];
    return [
      Positioned(
        top: 12,
        left: 16,
        right: 16,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.green.shade700,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'No high-risk roads detected at the moment.',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Marker> _buildEvacuationCenterMarkers() {
    return _centers.map((center) {
      return Marker(
        point: LatLng(center.latitude, center.longitude),
        width: 50,
        height: 50,
        child: GestureDetector(
          onTap: () => _showCenterInfo(center),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: MapMarkerStyle.evacuationCenterColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(MapMarkerStyle.evacuationCenterIcon, color: Colors.white, size: 22),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildVerifiedHazardMarkers() {
    return _reports
        .where((r) => r.status == HazardStatus.approved)
        .map((report) => Marker(
              point: LatLng(report.latitude, report.longitude),
              width: 50,
              height: 50,
              child: GestureDetector(
                onTap: () => _showHazardInfo(report),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MapMarkerStyle.verifiedHazardColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(MapMarkerStyle.verifiedHazardIcon, color: Colors.white, size: 24),
                ),
              ),
            ))
        .toList();
  }

  List<Marker> _buildPendingHazardMarkers() {
    return _reports
        .where((r) => r.status == HazardStatus.pending)
        .map((report) {
          final high = report.confirmationCount >= 3;
          return Marker(
            point: LatLng(report.latitude, report.longitude),
            width: high ? 60 : 50,
            height: high ? 60 : 50,
            child: GestureDetector(
              onTap: () => _showHazardInfo(report),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: MapMarkerStyle.pendingHazardColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: high ? Colors.green : Colors.white,
                        width: high ? 3 : 2,
                      ),
                    ),
                    child: const Icon(MapMarkerStyle.pendingHazardIcon, color: Colors.white, size: 22),
                  ),
                  if (high)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Text(
                          '${report.confirmationCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        })
        .toList();
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
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showHazardInfo(HazardReport report) {
    final isApproved = report.status == HazardStatus.approved;
    final statusColor = isApproved ? Colors.red : Colors.orange;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: statusColor, size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text(_formatType(report.hazardType))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isApproved ? 'Verified' : 'Pending',
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
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
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  String _formatType(String type) =>
      type.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Legend', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _legendDot(MapMarkerStyle.evacuationCenterColor, 'Evacuation Centers'),
          _legendDot(MapMarkerStyle.verifiedHazardColor, 'Verified Hazards'),
          _legendDot(MapMarkerStyle.pendingHazardColor, 'Pending Hazards'),
          if (_showRoadRiskLayer) ...[
            const Divider(height: 10, thickness: 0.8),
            const Text('Road Risk', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54)),
            const SizedBox(height: 4),
            _legendLine(Colors.red.withOpacity(0.75), 'High Risk Road'),
            _legendLine(Colors.orange.withOpacity(0.70), 'Moderate Risk Road'),
            _legendLine(Colors.green.withOpacity(0.55), 'Safe Road'),
          ],
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );

  Widget _legendLine(Color color, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 20, height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );

  void _showLayerControls() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => StatefulBuilder(
        builder: (ctx, setLocalState) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Layer Controls', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Road Risk Layer'),
                subtitle: const Text('Coloured overlay: red = high, yellow = moderate, green = safe'),
                value: _showRoadRiskLayer,
                activeColor: Colors.red,
                onChanged: (v) {
                  setLocalState(() {});
                  Navigator.pop(context);
                  _toggleRoadRiskLayer();
                },
              ),
              SwitchListTile(
                title: const Text('Evacuation Centers'),
                value: _showEvacuationCenters,
                onChanged: (v) {
                  setState(() => _showEvacuationCenters = v);
                  setLocalState(() {});
                },
              ),
              SwitchListTile(
                title: const Text('Verified Hazards'),
                value: _showVerifiedHazards,
                onChanged: (v) {
                  setState(() => _showVerifiedHazards = v);
                  setLocalState(() {});
                },
              ),
              SwitchListTile(
                title: const Text('Pending Hazards'),
                value: _showPendingHazards,
                onChanged: (v) {
                  setState(() => _showPendingHazards = v);
                  setLocalState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
