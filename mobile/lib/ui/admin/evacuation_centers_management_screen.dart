import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/admin/admin_mock_service.dart';
import '../../models/evacuation_center.dart';
import 'add_evacuation_center_screen.dart';
import 'evacuation_center_detail_screen.dart';
import 'evacuation_center_map_view_screen.dart';

/// Evacuation Centers Management Screen - Manage all evacuation centers.
/// 
/// Allows MDRRMO to add, edit, and view evacuation centers.
class EvacuationCentersManagementScreen extends StatefulWidget {
  const EvacuationCentersManagementScreen({super.key});

  @override
  State<EvacuationCentersManagementScreen> createState() => _EvacuationCentersManagementScreenState();
}

class _EvacuationCentersManagementScreenState extends State<EvacuationCentersManagementScreen> {
  final AdminMockService _adminService = AdminMockService();
  List<EvacuationCenter> _centers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedBarangay = 'all';
  bool _filterOnlyNonOperational = false; // NEW: filter for non-operational centers

  final List<String> _barangayOptions = ['all', 'Zone 1', 'Zone 2', 'Zone 3', 'Zone 4', 'Zone 5', 'Zone 6'];

  @override
  void initState() {
    super.initState();
    _checkDashboardFilter();
    _loadCenters();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check for dashboard filter whenever screen becomes visible
    _checkAndApplyDashboardFilter();
  }
  
  /// Check and apply dashboard filter if present (called on every screen visibility)
  Future<void> _checkAndApplyDashboardFilter() async {
    final prefs = await SharedPreferences.getInstance();
    final filterNonOperational = prefs.getBool('dashboard_centers_filter_non_operational') ?? false;
    
    if (filterNonOperational) {
      print('🎯 Centers filter detected: non-operational only'); // Debug log
      
      setState(() {
        _filterOnlyNonOperational = true;
      });
      
      // Clear the flag after applying
      await prefs.remove('dashboard_centers_filter_non_operational');
    }
  }
  
  /// Check if there's a filter request from the dashboard (for initState only)
  Future<void> _checkDashboardFilter() async {
    final prefs = await SharedPreferences.getInstance();
    final filterNonOperational = prefs.getBool('dashboard_centers_filter_non_operational') ?? false;
    
    if (filterNonOperational) {
      setState(() {
        _filterOnlyNonOperational = true;
      });
      
      // Clear the flag after applying
      await prefs.remove('dashboard_centers_filter_non_operational');
    }
  }

  Future<void> _loadCenters() async {
    setState(() => _isLoading = true);
    
    try {
      final centers = await _adminService.getEvacuationCenters();
      setState(() {
        _centers = centers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<EvacuationCenter> get _filteredCenters {
    return _centers.where((center) {
      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!center.name.toLowerCase().contains(query)) {
          return false;
        }
      }
      
      // Apply non-operational filter if active
      if (_filterOnlyNonOperational) {
        if (center.isOperational) {
          return false; // Exclude operational centers when filter is active
        }
      }
      
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Evacuation Centers'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Remove back button - main tab
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCenters,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter
          Container(
            color: Colors.grey[100],
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search centers...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedBarangay,
                  decoration: InputDecoration(
                    labelText: 'Filter by Barangay',
                    prefixIcon: const Icon(Icons.location_on, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
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
                
                // Non-Operational Filter Chip
                if (_filterOnlyNonOperational) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.filter_alt, size: 18, color: Colors.orange[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Showing Non-Operational Centers Only',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange[900],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          color: Colors.orange[700],
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              _filterOnlyNonOperational = false;
                            });
                          },
                          tooltip: 'Clear filter',
                        ),
                      ],
                    ),
                  ),
                ],
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
                  '${_filteredCenters.length} center${_filteredCenters.length != 1 ? 's' : ''} found',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Centers List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCenters.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_city, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No centers found',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadCenters,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredCenters.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final center = _filteredCenters[index];
                            return _buildCenterCard(center);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEvacuationCenterScreen(),
            ),
          );
          
          if (result == true) {
            _loadCenters();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Center'),
        backgroundColor: const Color(0xFF1E3A8A),
      ),
    );
  }

  Widget _buildCenterCard(EvacuationCenter center) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.location_city,
                    color: Colors.blue,
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
                      // Operational status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: center.isOperational ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              center.isOperational ? Icons.check_circle : Icons.cancel,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              center.isOperational ? 'OPERATIONAL' : 'NOT OPERATIONAL',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            
            _buildInfoRow(Icons.location_on, 'Barangay', center.barangay ?? 'Zone ${center.id}'),
            _buildInfoRow(Icons.home, 'Address', center.fullAddress),
            _buildInfoRow(Icons.gps_fixed, 'Coordinates', '${center.latitude.toStringAsFixed(4)}, ${center.longitude.toStringAsFixed(4)}'),
            _buildInfoRow(Icons.phone, 'Contact', center.contactNumber ?? '0917-123-45${center.id}7'),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EvacuationCenterMapViewScreen(center: center),
                        ),
                      );
                    },
                    icon: const Icon(Icons.map, size: 16),
                    label: const Text('Map'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EvacuationCenterDetailScreen(center: center),
                        ),
                      );
                      
                      if (result == true) {
                        _loadCenters();
                      }
                    },
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
