import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/connectivity_service.dart';
import '../../features/admin/mdrrmo_dashboard_service.dart';

/// Dashboard Screen - Overview of system statistics and recent activity.
/// 
/// Shows clickable summary cards and charts for MDRRMO monitoring.
class DashboardScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const DashboardScreen({super.key, this.onNavigateToTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final MdrrmoDashboardService _dashboardService = MdrrmoDashboardService();
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  bool _isOnline = true; // System status

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _checkConnectivity();
  }

  Future<void> _loadDashboardData() async {
    try {
      final stats = await _dashboardService.getDashboardStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isOnline = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isOnline = false);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkConnectivity() async {
    final online = await ConnectivityService().isOnline;
    if (mounted) setState(() => _isOnline = online);
    ConnectivityService().onConnectionChange.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MDRRMO Dashboard'),
        backgroundColor: const Color(0xFF1E3A8A), // Navy blue
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Remove back button
        actions: [
          // Online/Offline Status Indicator
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isOnline ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  _isOnline ? 'Online' : 'Offline',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Clickable Summary Cards Grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.3,
                      children: [
                        _buildClickableSummaryCard(
                          title: 'Total Reports',
                          count: _stats?['total_reports'] ?? 0,
                          icon: Icons.report,
                          color: const Color(0xFF3B82F6), // Blue
                          trend: 'Tap to view all',
                          onTap: () => _navigateToReports(statusFilter: null),
                        ),
                        _buildClickableSummaryCard(
                          title: 'Pending Reports',
                          count: _stats?['pending_reports'] ?? 0,
                          icon: Icons.pending_actions,
                          color: const Color(0xFFF59E0B), // Orange (Medium Priority)
                          trend: (_stats?['pending_reports'] ?? 0) > 0 ? 'Awaiting review' : 'All clear',
                          onTap: () => _navigateToReports(statusFilter: 'pending'),
                        ),
                        _buildClickableSummaryCard(
                          title: 'Verified Hazards',
                          count: _stats?['verified_hazards'] ?? 0,
                          icon: Icons.verified,
                          color: const Color(0xFF10B981), // Green (Verified/Resolved)
                          trend: (_stats?['verified_hazards'] ?? 0) > 0 ? 'Active on map' : 'No active hazards',
                          onTap: () => _navigateToReports(statusFilter: 'approved'),
                        ),
                        _buildClickableSummaryCard(
                          title: 'High Risk Roads',
                          count: _stats?['high_risk_roads'] ?? 0,
                          icon: Icons.warning_amber,
                          color: const Color(0xFFEF4444), // Red (High Priority)
                          trend: (_stats?['high_risk_roads'] ?? 0) > 0 ? 'Tap to view on map' : 'No high-risk roads',
                          onTap: () => _navigateToMap(),
                        ),
                        _buildClickableSummaryCard(
                          title: 'Evacuation Centers',
                          count: _stats?['total_evacuation_centers'] ?? 0,
                          icon: Icons.location_city,
                          color: const Color(0xFF8B5CF6), // Purple
                          trend: 'Tap to manage',
                          onTap: () => _navigateToEvacuationCenters(),
                        ),
                        _buildClickableSummaryCard(
                          title: 'Non-Operational Centers',
                          count: _stats?['non_operational_centers'] ?? 0,
                          icon: Icons.cancel,
                          color: _getNonOperationalColor(_stats?['non_operational_centers'] ?? 0),
                          trend: (_stats?['non_operational_centers'] ?? 0) > 0 ? 'Needs restoration' : 'All operational',
                          onTap: () => _navigateToEvacuationCenters(filterNonOperational: true),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Charts Section
                    _buildSectionTitle('Reports Overview'),
                    const SizedBox(height: 12),
                    
                    // Hazard Type Distribution Pie Chart
                    _buildChartCard(
                      title: 'Hazard Type Distribution',
                      icon: Icons.pie_chart,
                      child: _buildHazardPieChart(),
                    ),

                    const SizedBox(height: 24),

                    // Recent Activity
                    _buildSectionTitle('Recent Activity'),
                    const SizedBox(height: 12),
                    
                    _buildRecentActivity(),
                  ],
                ),
              ),
            ),
    );
  }

  /// Navigate to Reports tab with optional filter
  Future<void> _navigateToReports({String? statusFilter}) async {
    if (widget.onNavigateToTab != null) {
      // Save filter preference if specified
      if (statusFilter != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('dashboard_reports_filter', statusFilter);
        await prefs.setBool('should_apply_reports_filter', true);
        
        print('🎯 Dashboard: Saving reports filter = $statusFilter'); // Debug log
      }
      widget.onNavigateToTab!(1); // Index 1 = Reports tab
    }
  }

  /// Navigate to Map tab and auto-enable the road risk layer
  Future<void> _navigateToMap() async {
    if (widget.onNavigateToTab != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('map_monitor_show_risk_layer', true);
      widget.onNavigateToTab!(2); // Index 2 = Map tab
    }
  }

  /// Navigate to Evacuation Centers tab with optional filter
  Future<void> _navigateToEvacuationCenters({bool filterNonOperational = false}) async {
    if (widget.onNavigateToTab != null) {
      // Save filter preference if specified
      if (filterNonOperational) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('dashboard_centers_filter_non_operational', true);
      }
      widget.onNavigateToTab!(3); // Index 3 = Evacuation Centers tab
    }
  }

  /// Get color for non-operational centers card based on severity
  Color _getNonOperationalColor(int count) {
    if (count == 0) return Colors.green;
    if (count <= 2) return const Color(0xFFF59E0B); // Orange
    return const Color(0xFFEF4444); // Red (high severity)
  }

  Widget _buildClickableSummaryCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required String trend,
    required VoidCallback onTap,
    String suffix = '',
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              splashColor: color.withOpacity(0.1),
              highlightColor: color.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.grey[400],
                          size: 14,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$count$suffix',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          trend,
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey[500],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1E3A8A),
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF1E3A8A), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildBarangayChart() {
    final raw = _stats?['reports_by_barangay'];
    final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    
    // Find max value with proper type handling
    int maxValue = 1;
    if (data.values.isNotEmpty) {
      for (var value in data.values) {
        final intValue = value is int ? value : (value as num).toInt();
        if (intValue > maxValue) {
          maxValue = intValue;
        }
      }
    }

    return Column(
      children: data.entries.map((entry) {
        final count = entry.value is int ? entry.value : (entry.value as num).toInt();
        final percentage = count / maxValue;
        
        // Color based on priority (Red > Orange > Yellow > Green)
        Color barColor;
        if (percentage > 0.7) {
          barColor = const Color(0xFFEF4444); // Red - High Priority
        } else if (percentage > 0.5) {
          barColor = const Color(0xFFF59E0B); // Orange - Medium Priority
        } else if (percentage > 0.3) {
          barColor = const Color(0xFFEAB308); // Yellow - Low Priority
        } else {
          barColor = const Color(0xFF10B981); // Green - Safe/Low
        }
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$count reports',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation(barColor),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Build Pie Chart for Hazard Type Distribution
  Widget _buildHazardPieChart() {
    final raw = _stats?['hazard_distribution'];
    final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    
    if (data.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'No hazard data available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // Calculate total
    int total = 0;
    for (var value in data.values) {
      total += value is int ? value : (value as num).toInt();
    }

    return Column(
      children: [
        // Pie chart visualization
        SizedBox(
          height: 200,
          child: CustomPaint(
            size: const Size(200, 200),
            painter: PieChartPainter(data: data, total: total),
          ),
        ),
        const SizedBox(height: 16),
        // Legend
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: data.entries.map((entry) {
            final count = entry.value is int ? entry.value : (entry.value as num).toInt();
            final percentage = ((count / total) * 100).toStringAsFixed(1);
            
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _getHazardColor(entry.key).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getHazardColor(entry.key).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getHazardColor(entry.key),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_formatHazardType(entry.key)}: $count ($percentage%)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    final raw = _stats?['recent_activity'];
    final activities = raw is List ? List<dynamic>.from(raw) : <dynamic>[];
    
    if (activities.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.history,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                'No recent activity available',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Take only latest 10 activities
    final recentActivities = activities.take(10).toList();
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: recentActivities.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Colors.grey[200],
        ),
        itemBuilder: (context, index) {
          final activity = recentActivities[index];
          final type = activity['type'];
          final message = activity['message'] ?? 'Activity';
          DateTime timestamp = DateTime.now();
          final ts = activity['timestamp'];
          if (ts is DateTime) {
            timestamp = ts;
          } else if (ts != null) {
            timestamp = DateTime.tryParse(ts.toString()) ?? DateTime.now();
          }
          final timeAgo = _getTimeAgo(timestamp);
          final location = activity['location'] ?? '';

          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getActivityColor(type).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getActivityIcon(type),
                color: _getActivityColor(type),
                size: 20,
              ),
            ),
            title: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              location.isNotEmpty ? '$location • $timeAgo' : timeAgo,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            trailing: Text(
              _getFormattedTime(timestamp),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatHazardType(String type) {
    return type.replaceAll('_', ' ').split(' ').map((word) {
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  Color _getHazardColor(String type) {
    switch (type.toLowerCase()) {
      case 'flooded_road':
        return Colors.blue;
      case 'landslide':
        return Colors.brown;
      case 'fallen_tree':
        return Colors.green[700]!;
      case 'road_damage':
        return Colors.grey[700]!;
      case 'fallen_electric_post':
        return Colors.amber[700]!;
      case 'road_blocked':
        return Colors.red;
      case 'bridge_damage':
        return Colors.orange;
      case 'storm_surge':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'report_submitted':
        return Colors.blue;
      case 'report_approved':
        return const Color(0xFF10B981); // Green
      case 'report_rejected':
        return const Color(0xFFEF4444); // Red
      case 'center_deactivated':
        return Colors.orange;
      case 'center_reactivated':
        return Colors.green;
      case 'report_restored':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'report_submitted':
        return Icons.report;
      case 'report_approved':
        return Icons.check_circle;
      case 'report_rejected':
        return Icons.cancel;
      case 'center_deactivated':
        return Icons.block;
      case 'center_reactivated':
        return Icons.check_circle_outline;
      case 'report_restored':
        return Icons.restore;
      default:
        return Icons.info;
    }
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else {
      return _getFormattedDate(timestamp);
    }
  }

  String _getFormattedTime(DateTime timestamp) {
    final hour = timestamp.hour > 12 ? timestamp.hour - 12 : timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = timestamp.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _getFormattedDate(DateTime timestamp) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[timestamp.month - 1]} ${timestamp.day}';
  }
}

/// Custom Pie Chart Painter
class PieChartPainter extends CustomPainter {
  final Map<String, dynamic> data;
  final int total;

  PieChartPainter({required this.data, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    
    double startAngle = -math.pi / 2; // Start from top
    
    for (var entry in data.entries) {
      final count = entry.value is int ? entry.value : (entry.value as num).toInt();
      final sweepAngle = (count / total) * 2 * math.pi;
      
      final paint = Paint()
        ..color = _getHazardColorForPainter(entry.key)
        ..style = PaintingStyle.fill;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      
      // Draw white separator line
      final separatorPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      canvas.drawLine(
        center,
        Offset(
          center.dx + radius * math.cos(startAngle),
          center.dy + radius * math.sin(startAngle),
        ),
        separatorPaint,
      );
      
      startAngle += sweepAngle;
    }
  }

  Color _getHazardColorForPainter(String type) {
    switch (type.toLowerCase()) {
      case 'flooded_road':
        return Colors.blue;
      case 'landslide':
        return Colors.brown;
      case 'fallen_tree':
        return Colors.green[700]!;
      case 'road_damage':
        return Colors.grey[700]!;
      case 'fallen_electric_post':
        return Colors.amber[700]!;
      case 'road_blocked':
        return Colors.red;
      case 'bridge_damage':
        return Colors.orange;
      case 'storm_surge':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
