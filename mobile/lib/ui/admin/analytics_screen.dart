import 'package:flutter/material.dart';
import '../../features/admin/admin_mock_service.dart';

/// Analytics Screen - Statistical analysis and charts for MDRRMO.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AdminMockService _adminService = AdminMockService();
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final analytics = await _adminService.getAnalytics();
      setState(() {
        _analytics = analytics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Remove back button - main tab
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Hazard Type Distribution'),
                    const SizedBox(height: 12),
                    _buildHazardDistributionPieChart(),
                    
                    const SizedBox(height: 24),
                    _buildSectionTitle('Road Risk Distribution'),
                    const SizedBox(height: 12),
                    _buildRoadRiskCard(),
                  ],
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

  Widget _buildDangerousBarangaysCard() {
    final barangays = _analytics?['most_dangerous_barangays'] as List? ?? [];
    
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
        children: barangays.map((b) {
          final riskScore = (b['risk_score'] as double);
          final color = riskScore > 0.7 ? Colors.red : (riskScore > 0.5 ? Colors.orange : Colors.yellow);
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.location_on, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${b['hazard_count']} hazards',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(riskScore * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Build Hazard Distribution Pie Chart
  Widget _buildHazardDistributionPieChart() {
    final distribution = _analytics?['hazard_type_distribution'] as Map<String, dynamic>? ?? {};
    
    if (distribution.isEmpty) {
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
        child: const Center(child: Text('No hazard data available')),
      );
    }
    
    final total = distribution.values.fold<int>(0, (sum, count) => sum + (count as int));
    
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
        children: [
          // Pie chart visualization
          SizedBox(
            height: 250,
            child: CustomPaint(
              size: const Size(250, 250),
              painter: PieChartPainter(
                distribution.map((key, value) => MapEntry(
                  key,
                  (value as int) / total,
                )),
                distribution.map((key, value) => MapEntry(
                  key,
                  _getHazardColor(key),
                )),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: distribution.entries.map((entry) {
              final percentage = ((entry.value as int) / total * 100).toStringAsFixed(1);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _getHazardColor(entry.key),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${entry.key}: ${entry.value} ($percentage%)',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHazardDistributionCard() {
    final distribution = _analytics?['hazard_type_distribution'] as Map<String, dynamic>? ?? {};
    
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
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: distribution.entries.map((entry) {
          return Chip(
            avatar: Icon(
              _getHazardIcon(entry.key),
              size: 16,
              color: _getHazardColor(entry.key),
            ),
            label: Text('${entry.key}: ${entry.value}'),
            backgroundColor: _getHazardColor(entry.key).withOpacity(0.1),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRoadRiskCard() {
    final distribution = _analytics?['road_risk_distribution'] as Map<String, dynamic>? ?? {};
    
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
        children: [
          _buildRiskRow('High Risk', distribution['high_risk'] ?? 0, Colors.red),
          _buildRiskRow('Moderate Risk', distribution['moderate_risk'] ?? 0, Colors.orange),
          _buildRiskRow('Low Risk', distribution['low_risk'] ?? 0, Colors.green),
        ],
      ),
    );
  }

  Widget _buildRiskRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            '$count roads',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelStatsCard() {
    final stats = _analytics?['model_statistics'] as Map<String, dynamic>? ?? {};
    
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
        children: [
          _buildStatRow('Naive Bayes Accuracy', '${((stats['naive_bayes_accuracy'] ?? 0) * 100).toStringAsFixed(1)}%'),
          _buildStatRow('Consensus Accuracy', '${((stats['consensus_accuracy'] ?? 0) * 100).toStringAsFixed(1)}%'),
          _buildStatRow('Random Forest Accuracy', '${((stats['random_forest_accuracy'] ?? 0) * 100).toStringAsFixed(1)}%'),
          const Divider(),
          _buildStatRow('Model Version', stats['model_version'] ?? 'N/A'),
          _buildStatRow('Dataset Version', stats['dataset_version'] ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Color _getHazardColor(String type) {
    switch (type.toLowerCase()) {
      case 'flooded_road':
      case 'flooded road':
        return Colors.blue;
      case 'landslide':
        return Colors.brown;
      case 'fallen_tree':
      case 'fallen tree':
        return Colors.green[700]!;
      case 'road_damage':
      case 'road damage':
        return Colors.grey[700]!;
      case 'fallen_electric_post':
      case 'fallen electric post / wires':
        return Colors.amber[700]!;
      case 'road_blocked':
      case 'road blocked':
        return Colors.red;
      case 'bridge_damage':
      case 'bridge damage':
        return Colors.orange;
      case 'storm_surge':
      case 'storm surge':
        return Colors.purple;
      case 'flood':
        return Colors.blue;
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
      case 'flood': return Icons.water_drop;
      case 'landslide': return Icons.landscape;
      case 'fire': return Icons.local_fire_department;
      case 'storm': return Icons.thunderstorm;
      default: return Icons.warning;
    }
  }
}

/// Custom Pie Chart Painter
class PieChartPainter extends CustomPainter {
  final Map<String, double> data; // percentages
  final Map<String, Color> colors;

  PieChartPainter(this.data, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;
    double startAngle = -90 * (3.14159 / 180); // Start from top

    data.forEach((key, percentage) {
      final sweepAngle = 2 * 3.14159 * percentage;
      final paint = Paint()
        ..color = colors[key] ?? Colors.grey
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Draw white border between segments
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      startAngle += sweepAngle;
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
