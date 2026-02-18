import 'package:flutter/material.dart';
import '../../features/admin/admin_mock_service.dart';

/// Dashboard Screen - Overview of system statistics and recent activity.
/// 
/// Shows summary cards and charts for MDRRMO monitoring.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AdminMockService _adminService = AdminMockService();
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final stats = await _adminService.getDashboardStats();
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MDRRMO Dashboard'),
        backgroundColor: const Color(0xFF1E3A8A), // Navy blue
        foregroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'System Active',
                  style: TextStyle(
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
                    // Summary Cards Grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.3,
                      children: [
                        _buildSummaryCard(
                          title: 'Total Reports',
                          count: _stats?['total_reports'] ?? 0,
                          icon: Icons.report,
                          color: const Color(0xFF3B82F6), // Blue
                          trend: '↗ +12 this week',
                        ),
                        _buildSummaryCard(
                          title: 'Pending Reports',
                          count: _stats?['pending_reports'] ?? 0,
                          icon: Icons.pending_actions,
                          color: const Color(0xFFF59E0B), // Orange
                          trend: 'Needs attention',
                        ),
                        _buildSummaryCard(
                          title: 'Verified Hazards',
                          count: _stats?['verified_hazards'] ?? 0,
                          icon: Icons.verified,
                          color: const Color(0xFF10B981), // Green
                          trend: 'Active monitoring',
                        ),
                        _buildSummaryCard(
                          title: 'High Risk Roads',
                          count: _stats?['high_risk_roads'] ?? 0,
                          icon: Icons.warning_amber,
                          color: const Color(0xFFEF4444), // Red
                          trend: 'Critical attention',
                        ),
                        _buildSummaryCard(
                          title: 'Evacuation Centers',
                          count: _stats?['total_evacuation_centers'] ?? 0,
                          icon: Icons.location_city,
                          color: const Color(0xFF8B5CF6), // Purple
                          trend: 'All operational',
                        ),
                        _buildSummaryCard(
                          title: 'Response Time',
                          count: 24,
                          icon: Icons.timer,
                          color: const Color(0xFF06B6D4), // Cyan
                          trend: 'minutes avg',
                          suffix: 'min',
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Charts Section
                    _buildSectionTitle('Reports Overview'),
                    const SizedBox(height: 12),
                    
                    _buildChartCard(
                      title: 'Reports by Barangay',
                      icon: Icons.bar_chart,
                      child: _buildBarangayChart(),
                    ),

                    const SizedBox(height: 16),

                    _buildChartCard(
                      title: 'Hazard Type Distribution',
                      icon: Icons.pie_chart,
                      child: _buildHazardDistributionChart(),
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

  Widget _buildSummaryCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required String trend,
    String suffix = '',
  }) {
    return Container(
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
                Icons.trending_up,
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
    final data = _stats?['reports_by_barangay'] as Map<String, dynamic>? ?? {};
    
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
        final percentage = (entry.value as int) / maxValue;
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
                    '${entry.value} reports',
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
                  valueColor: AlwaysStoppedAnimation(
                    percentage > 0.7 ? Colors.red : (percentage > 0.5 ? Colors.orange : Colors.blue),
                  ),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHazardDistributionChart() {
    final data = _stats?['hazard_distribution'] as Map<String, dynamic>? ?? {};
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: data.entries.map((entry) {
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
              Icon(
                _getHazardIcon(entry.key),
                size: 16,
                color: _getHazardColor(entry.key),
              ),
              const SizedBox(width: 6),
              Text(
                '${entry.key}: ${entry.value}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _getHazardColor(entry.key),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentActivity() {
    final activities = _stats?['recent_activity'] as List? ?? [];
    
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
        itemCount: activities.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Colors.grey[200],
        ),
        itemBuilder: (context, index) {
          final activity = activities[index];
          final type = activity['type'];
          final timestamp = activity['timestamp'] as DateTime;
          final timeAgo = _getTimeAgo(timestamp);

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
              activity['message'],
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              timeAgo,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getHazardColor(String type) {
    switch (type) {
      case 'flood':
        return Colors.blue;
      case 'landslide':
        return Colors.brown;
      case 'fire':
        return Colors.red;
      case 'storm':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getHazardIcon(String type) {
    switch (type) {
      case 'flood':
        return Icons.water_drop;
      case 'landslide':
        return Icons.landscape;
      case 'fire':
        return Icons.local_fire_department;
      case 'storm':
        return Icons.thunderstorm;
      default:
        return Icons.warning;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'report_submitted':
        return Colors.blue;
      case 'report_approved':
        return Colors.green;
      case 'center_updated':
        return Colors.orange;
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
      case 'center_updated':
        return Icons.update;
      default:
        return Icons.info;
    }
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    }
  }
}
