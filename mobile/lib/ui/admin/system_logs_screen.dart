import 'package:flutter/material.dart';
import '../../features/system_logger/system_logger_service.dart';

/// System Logs Screen - Displays and manages system logs
/// 
/// Accessible only by MDRRMO Admin from Settings section
class SystemLogsScreen extends StatefulWidget {
  const SystemLogsScreen({super.key});

  @override
  State<SystemLogsScreen> createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends State<SystemLogsScreen> {
  List<SystemLog> _logs = [];
  List<SystemLog> _filteredLogs = [];
  bool _isLoading = true;

  // Filters
  final TextEditingController _searchController = TextEditingController();
  String _selectedUserRole = 'All';
  String _selectedModule = 'All';
  String _selectedStatus = 'All';
  
  // Pagination
  int _currentPage = 0;
  final int _logsPerPage = 10;

  final List<String> _userRoleOptions = ['All', 'Resident', 'MDRRMO', 'System'];
  final List<String> _moduleOptions = [
    'All',
    'Reports',
    'Evacuation Centers',
    'User Management',
    'Navigation',
    'Settings',
    'Authentication',
    'System',
  ];
  final List<String> _statusOptions = ['All', 'Success', 'Warning', 'Failed'];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);

    try {
      final logs = await SystemLogger.getAllLogs();
      setState(() {
        _logs = logs;
        _filteredLogs = logs;
        _isLoading = false;
        _currentPage = 0;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading logs: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _filterLogs() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredLogs = _logs.where((log) {
        // Search filter
        final matchesSearch = query.isEmpty ||
            log.userName.toLowerCase().contains(query) ||
            log.action.toLowerCase().contains(query) ||
            log.module.toLowerCase().contains(query);

        // Role filter
        final matchesRole = _selectedUserRole == 'All' || log.userRole == _selectedUserRole;

        // Module filter
        final matchesModule = _selectedModule == 'All' || log.module == _selectedModule;

        // Status filter
        final matchesStatus = _selectedStatus == 'All' ||
            log.status.name.toLowerCase() == _selectedStatus.toLowerCase();

        return matchesSearch && matchesRole && matchesModule && matchesStatus;
      }).toList();

      _currentPage = 0; // Reset to first page when filtering
    });
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange[700], size: 28),
            const SizedBox(width: 12),
            const Text('Clear All Logs'),
          ],
        ),
        content: const Text(
          'Are you sure you want to clear all system logs? This action cannot be undone.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear Logs'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SystemLogger.clearAllLogs();
      await _loadLogs();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All system logs have been cleared'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _exportLogs() async {
    try {
      final jsonData = await SystemLogger.exportLogsAsJson();
      
      // In a real app, you'd use a file picker or share plugin here
      // For now, we'll just show a success message
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 12),
                Text('Logs Ready'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('System logs have been exported as JSON.'),
                const SizedBox(height: 16),
                Text(
                  'Total logs: ${_logs.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Size: ${(jsonData.length / 1024).toStringAsFixed(2)} KB',
                  style: TextStyle(color: Colors.grey[700]),
                ),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting logs: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<SystemLog> get _paginatedLogs {
    final startIndex = _currentPage * _logsPerPage;
    final endIndex = (startIndex + _logsPerPage).clamp(0, _filteredLogs.length);
    
    if (startIndex >= _filteredLogs.length) {
      return [];
    }
    
    return _filteredLogs.sublist(startIndex, endIndex);
  }

  int get _totalPages {
    return (_filteredLogs.length / _logsPerPage).ceil();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Logs'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportLogs,
            tooltip: 'Export Logs',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearLogs,
            tooltip: 'Clear Logs',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (_) => _filterLogs(),
                  decoration: InputDecoration(
                    hintText: 'Search by user, action, or module...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Filter Dropdowns
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterDropdown(
                        'Role',
                        _selectedUserRole,
                        _userRoleOptions,
                        (value) {
                          setState(() {
                            _selectedUserRole = value!;
                            _filterLogs();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterDropdown(
                        'Module',
                        _selectedModule,
                        _moduleOptions,
                        (value) {
                          setState(() {
                            _selectedModule = value!;
                            _filterLogs();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterDropdown(
                        'Status',
                        _selectedStatus,
                        _statusOptions,
                        (value) {
                          setState(() {
                            _selectedStatus = value!;
                            _filterLogs();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Results Info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                Icon(Icons.list_alt, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '${_filteredLogs.length} log${_filteredLogs.length != 1 ? 's' : ''} found',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                if (_selectedUserRole != 'All' ||
                    _selectedModule != 'All' ||
                    _selectedStatus != 'All' ||
                    _searchController.text.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Filtered',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 1),

          // Logs Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No logs found',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            ..._paginatedLogs.map((log) => _buildLogCard(log)),
                            
                            // Pagination
                            if (_totalPages > 1)
                              Container(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.chevron_left),
                                      onPressed: _currentPage > 0
                                          ? () {
                                              setState(() {
                                                _currentPage--;
                                              });
                                            }
                                          : null,
                                    ),
                                    Text(
                                      'Page ${_currentPage + 1} of $_totalPages',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.chevron_right),
                                      onPressed: _currentPage < _totalPages - 1
                                          ? () {
                                              setState(() {
                                                _currentPage++;
                                              });
                                            }
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: options.map((option) {
                return DropdownMenuItem(
                  value: option,
                  child: Text(option, style: const TextStyle(fontSize: 13)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogCard(SystemLog log) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getStatusColor(log.status).withOpacity(0.3)),
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
          // Header Row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getStatusColor(log.status).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                _buildStatusBadge(log.status),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    log.action,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  log.getFormattedTimestamp(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildInfoRow(Icons.person, 'User', '${log.userName} (${log.userRole})'),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.category, 'Module', log.module),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.access_time, 'Timestamp', log.getFullTimestamp()),
                if (log.details != null && log.details!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.info_outline, 'Details', log.details!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(LogStatus status) {
    final color = _getStatusColor(status);
    final icon = _getStatusIcon(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            status.name.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(LogStatus status) {
    switch (status) {
      case LogStatus.success:
        return Colors.green;
      case LogStatus.warning:
        return Colors.orange;
      case LogStatus.failed:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(LogStatus status) {
    switch (status) {
      case LogStatus.success:
        return Icons.check_circle;
      case LogStatus.warning:
        return Icons.warning;
      case LogStatus.failed:
        return Icons.error;
    }
  }
}
