import 'dart:convert';
import 'package:flutter/material.dart';
import '../../features/admin/system_log_service.dart';
import '../../models/system_log.dart';

/// System Logs Screen - Displays and manages system logs from the backend database.
/// Accessible only by MDRRMO Admin from Settings section.
class SystemLogsScreen extends StatefulWidget {
  const SystemLogsScreen({super.key});

  @override
  State<SystemLogsScreen> createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends State<SystemLogsScreen> {
  final SystemLogService _logService = SystemLogService();
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
    'Authentication',
    'User Management',
    'Hazard Reports',
    'Evacuation Centers',
    'Navigation',
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
      final result = await _logService.listSystemLogs(limit: 500);
      final logs = result['results'] as List<SystemLog>;
      setState(() {
        _logs = logs;
        _filteredLogs = logs;
        _isLoading = false;
        _currentPage = 0;
      });
      _filterLogs();
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
        final matchesSearch = query.isEmpty ||
            log.userName.toLowerCase().contains(query) ||
            log.action.toLowerCase().contains(query) ||
            log.module.toLowerCase().contains(query) ||
            log.description.toLowerCase().contains(query);

        final matchesRole = _selectedUserRole == 'All' ||
            log.userRole.toLowerCase() == _selectedUserRole.toLowerCase();

        final matchesModule = _selectedModule == 'All' || log.moduleDisplay == _selectedModule;

        final matchesStatus = _selectedStatus == 'All' ||
            log.status.toLowerCase() == _selectedStatus.toLowerCase();

        return matchesSearch && matchesRole && matchesModule && matchesStatus;
      }).toList();

      _currentPage = 0;
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
      try {
        final message = await _logService.clearSystemLogs();
        await _loadLogs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to clear logs: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _exportLogs() async {
    try {
      final jsonData = _logs.map((log) => log.toJson()).toList();
      final jsonString = jsonEncode(jsonData);
      final sizeKb = (jsonString.length / 1024).toStringAsFixed(2);

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
                  'Size: $sizeKb KB',
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
        border: Border.all(color: _getStatusColorFromString(log.status).withOpacity(0.3)),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getStatusColorFromString(log.status).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                _buildStatusBadgeFromString(log.status),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _actionDisplay(log.action),
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
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildInfoRow(Icons.person, 'User', '${log.userName} (${log.userRole.isNotEmpty ? log.userRole : 'System'})'),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.category, 'Module', log.moduleDisplay),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.access_time, 'Timestamp', log.getFullTimestamp()),
                if (log.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.info_outline, 'Details', log.description),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _actionDisplay(String action) {
    return action.replaceAll('_', ' ').split(' ').map((e) => e.isEmpty ? e : '${e[0].toUpperCase()}${e.substring(1)}').join(' ');
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

  Widget _buildStatusBadgeFromString(String status) {
    final color = _getStatusColorFromString(status);
    final icon = _getStatusIconFromString(status);
    final label = status.toUpperCase();

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
            label,
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

  Color _getStatusColorFromString(String status) {
    switch (status.toLowerCase()) {
      case 'success':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIconFromString(String status) {
    switch (status.toLowerCase()) {
      case 'success':
        return Icons.check_circle;
      case 'warning':
        return Icons.warning;
      case 'failed':
        return Icons.error;
      default:
        return Icons.info;
    }
  }
}
