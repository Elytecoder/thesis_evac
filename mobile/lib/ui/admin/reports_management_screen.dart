import 'package:flutter/material.dart';
import '../../features/admin/admin_mock_service.dart';
import '../../models/hazard_report.dart';
import 'report_detail_screen.dart';

/// Reports Management Screen - View and manage hazard reports.
/// 
/// Allows MDRRMO to filter, view, approve, and reject reports.
class ReportsManagementScreen extends StatefulWidget {
  const ReportsManagementScreen({super.key});

  @override
  State<ReportsManagementScreen> createState() => _ReportsManagementScreenState();
}

class _ReportsManagementScreenState extends State<ReportsManagementScreen> {
  final AdminMockService _adminService = AdminMockService();
  List<HazardReport> _reports = [];
  bool _isLoading = true;
  
  String _selectedStatus = 'all';
  String _selectedBarangay = 'all';
  String _searchQuery = '';

  final List<String> _statusOptions = ['all', 'pending', 'approved', 'rejected'];
  final List<String> _barangayOptions = ['all', 'Zone 1', 'Zone 2', 'Zone 3', 'Zone 4', 'Zone 5', 'Zone 6'];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    
    try {
      final reports = await _adminService.getReports(
        status: _selectedStatus == 'all' ? null : _selectedStatus,
      );
      
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load reports: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<HazardReport> get _filteredReports {
    return _reports.where((report) {
      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!report.hazardType.toLowerCase().contains(query) &&
            !report.description.toLowerCase().contains(query)) {
          return false;
        }
      }
      
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports Management'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters Section
          Container(
            color: Colors.grey[100],
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search reports...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                
                const SizedBox(height: 12),
                
                // Status and Barangay Filters
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          prefixIcon: const Icon(Icons.filter_list, size: 20),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        items: _statusOptions.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(status.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedStatus = value;
                            });
                            _loadReports();
                          }
                        },
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedBarangay,
                        decoration: InputDecoration(
                          labelText: 'Barangay',
                          prefixIcon: const Icon(Icons.location_on, size: 20),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        items: _barangayOptions.map((barangay) {
                          return DropdownMenuItem(
                            value: barangay,
                            child: Text(barangay.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedBarangay = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Results Count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredReports.length} report${_filteredReports.length != 1 ? 's' : ''} found',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_searchQuery.isNotEmpty || _selectedStatus != 'all')
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _selectedStatus = 'all';
                        _selectedBarangay = 'all';
                      });
                      _loadReports();
                    },
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear Filters'),
                  ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Reports List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredReports.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No reports found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try adjusting your filters',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadReports,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredReports.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final report = _filteredReports[index];
                            return _buildReportCard(report);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(HazardReport report) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(report.status).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor(report.status).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getHazardColor(report.hazardType).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getHazardIcon(report.hazardType),
                    color: _getHazardColor(report.hazardType),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.hazardType.toUpperCase().replaceAll('_', ' '),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _getHazardColor(report.hazardType),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Report #${report.id}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(report.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(report.status),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                Text(
                  report.description,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 12),
                
                // Location & Time
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(report.createdAt ?? DateTime.now()),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // AI Scores
                Row(
                  children: [
                    Expanded(
                      child: _buildScoreIndicator(
                        'Naive Bayes',
                        report.naiveBayesScore ?? 0.0,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildScoreIndicator(
                        'Consensus',
                        report.consensusScore ?? 0.0,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // View Details Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReportDetailScreen(report: report),
                        ),
                      );
                      
                      // Reload if report was updated
                      if (result == true) {
                        _loadReports();
                      }
                    },
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View Details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E3A8A),
                      side: const BorderSide(color: Color(0xFF1E3A8A)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreIndicator(String label, double score, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(score * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(HazardStatus status) {
    switch (status) {
      case HazardStatus.pending:
        return Colors.orange;
      case HazardStatus.approved:
        return Colors.green;
      case HazardStatus.rejected:
        return Colors.red;
    }
  }

  String _getStatusText(HazardStatus status) {
    switch (status) {
      case HazardStatus.pending:
        return 'PENDING';
      case HazardStatus.approved:
        return 'APPROVED';
      case HazardStatus.rejected:
        return 'REJECTED';
    }
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
      case 'typhoon':
        return Colors.purple;
      case 'road_damage':
        return Colors.grey;
      case 'fallen_tree':
        return Colors.green;
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
      case 'typhoon':
        return Icons.thunderstorm;
      case 'road_damage':
        return Icons.broken_image;
      case 'fallen_tree':
        return Icons.park;
      default:
        return Icons.warning;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }
}
