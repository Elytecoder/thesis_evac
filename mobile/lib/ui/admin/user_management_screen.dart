import 'package:flutter/material.dart';
import '../../core/utils/barangay_normalize.dart';
import '../../features/admin/user_management_service.dart';
import '../../models/user.dart';

/// User Management Screen for MDRRMO Admin
/// Displays registered residents from the backend (GET /api/mdrrmo/users/).
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final UserManagementService _userService = UserManagementService();
  
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  List<String> _barangays = ['All'];
  bool _isLoading = true;
  
  final TextEditingController _searchController = TextEditingController();
  String _selectedBarangay = 'All';
  String _selectedStatus = 'All';
  
  final List<String> _statusOptions = [
    'All',
    'Active',
    'Suspended',
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static Map<String, dynamic> _userToMap(User u) {
    final name = (u.fullName.isNotEmpty ? u.fullName : u.email).trim();
    final barangay = (u.barangay).trim();
    return {
      'id': u.id,
      'public_user_id': u.publicUserId,
      'name': name.isEmpty ? (u.email.isNotEmpty ? u.email : 'User #${u.id}') : name,
      'email': u.email,
      'phone_number': u.phoneNumber,
      'province': u.province,
      'municipality': u.municipality,
      'barangay': barangay.isEmpty ? '—' : barangay,
      'status': u.isSuspended ? 'Suspended' : 'Active',
      'date_registered': _formatDate(u.dateJoined),
      'reports_count': 0,
    };
  }

  Future<void> _loadUsers({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      final statusParam = _selectedStatus == 'Active'
          ? 'active'
          : _selectedStatus == 'Suspended'
              ? 'suspended'
              : null;
      final barangayParam = _selectedBarangay == 'All' ? null : _selectedBarangay;
      final searchParam = _searchController.text.trim().isEmpty ? null : _searchController.text.trim();
      final list = await _userService.listUsers(
        status: statusParam,
        barangay: barangayParam,
        search: searchParam,
      );
      final maps = list.map(_userToMap).toList();
      // Build barangay list from data when loading all (no barangay filter)
      List<String> barangays = ['All'];
      if (barangayParam == null) {
        final seen = <String>{};
        for (final m in maps) {
          final b = (m['barangay'] ?? '').toString().trim();
          if (b.isNotEmpty && b != '—' && !seen.contains(b)) {
            seen.add(b);
            barangays.add(b);
          }
        }
        barangays.sort((a, b) => a == 'All' ? -1 : (b == 'All' ? 1 : a.compareTo(b)));
      } else {
        barangays = _barangays;
      }
      setState(() {
        _users = maps;
        _filteredUsers = maps;
        _barangays = barangays;
        if (!_barangays.contains(_selectedBarangay)) _selectedBarangay = 'All';
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredUsers = _users.where((user) {
        final name = user['name']?.toString() ?? '';
        final email = user['email']?.toString() ?? '';
        final matchesSearch = query.isEmpty ||
            name.toLowerCase().contains(query) ||
            email.toLowerCase().contains(query);
        final userBarangay = user['barangay']?.toString() ?? '';
        final bRaw = userBarangay == '—' ? '' : userBarangay;
        final matchesBarangay = _selectedBarangay == 'All' ||
            BarangayNormalize.matches(bRaw, _selectedBarangay);
        final userStatus = user['status']?.toString() ?? '';
        final matchesStatus = _selectedStatus == 'All' ||
            userStatus == _selectedStatus;
        return matchesSearch && matchesBarangay && matchesStatus;
      }).toList();
    });
  }

  Future<void> _suspendUser(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suspend Account'),
        content: Text('Are you sure you want to suspend ${user['name']}\'s account?'),
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
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _userService.suspendUser(user['id'] as int);
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user['name']} has been suspended')),
        );
      }
    }
  }

  Future<void> _activateUser(Map<String, dynamic> user) async {
    await _userService.activateUser(user['id'] as int);
    _loadUsers();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user['name']} has been activated')),
      );
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to permanently delete ${user['name']}? This action cannot be undone.'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _userService.deleteUser(user['id'] as int);
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user['name']} has been deleted')),
        );
      }
    }
  }

  void _viewUserProfile(Map<String, dynamic> user) {
    final phoneRaw = (user['phone_number']?.toString() ?? '').trim();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // User Avatar
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blue[100],
                child: Text(
                  _getInitials(user['name']?.toString() ?? '?'),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Full Name
              Text(
                user['name']?.toString() ?? '—',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              // Status Badge
              _buildStatusBadge(user['status']),
              const SizedBox(height: 24),
              
              // User Details
              _buildDetailRow(Icons.email, 'Email', user['email']?.toString() ?? '—'),
              _buildDetailRow(
                Icons.badge_outlined,
                'User ID',
                user['public_user_id'] != null ? '#${user['public_user_id']}' : '—',
              ),
              _buildDetailRow(Icons.phone, 'Phone', phoneRaw.isEmpty ? '—' : phoneRaw),
              _buildDetailRow(Icons.location_on, 'Barangay', user['barangay']?.toString() ?? '—'),
              _buildDetailRow(Icons.calendar_today, 'Registered', user['date_registered']?.toString() ?? '—'),
              _buildDetailRow(Icons.report, 'Total Reports', '${user['reports_count'] ?? 0}'),
              
              const SizedBox(height: 24),
              
              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final s = (name).trim();
    if (s.isEmpty) return '?';
    final parts = s.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final a = parts[0].isNotEmpty ? parts[0][0] : '';
      final b = parts[1].isNotEmpty ? parts[1][0] : '';
      return (a + b).toUpperCase();
    }
    return s[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadUsers,
            tooltip: 'Reload users',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (_) => _filterUsers(),
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Filter Dropdowns Row
                Row(
                  children: [
                    // Barangay Filter
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 6),
                              Text(
                                'Barangay',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
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
                                value: _selectedBarangay,
                                isExpanded: true,
                                items: _barangays.map((barangay) {
                                  return DropdownMenuItem(
                                    value: barangay,
                                    child: Text(barangay, style: const TextStyle(fontSize: 14)),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() => _selectedBarangay = value!);
                                  _loadUsers();
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Status Filter
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 6),
                              Text(
                                'Status',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
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
                                value: _selectedStatus,
                                isExpanded: true,
                                items: _statusOptions.map((status) {
                                  return DropdownMenuItem(
                                    value: status,
                                    child: Text(status, style: const TextStyle(fontSize: 14)),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedStatus = value!;
                                    _loadUsers();
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Results Count
          if (!_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  Icon(Icons.people, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    '${_filteredUsers.length} user${_filteredUsers.length != 1 ? 's' : ''} found',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  if (_selectedBarangay != 'All' || _selectedStatus != 'All') ...[
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
          
          // User List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => _loadUsers(silent: true),
                    child: _filteredUsers.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                            children: [
                              Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                _users.isEmpty
                                    ? 'No registered users loaded. Pull to refresh or tap ↻.'
                                    : 'No users match your search or filters.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = _filteredUsers[index];
                              return _buildUserCard(user);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    _getInitials(user['name']?.toString() ?? '?'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['name']?.toString() ?? '—',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.email, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            user['email']?.toString() ?? '—',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            user['barangay']?.toString() ?? '—',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Status Badge
                _buildStatusBadge(user['status']?.toString() ?? 'Active'),
              ],
            ),
            const SizedBox(height: 12),
            
            // Date Registered
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Registered: ${user['date_registered']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewUserProfile(user),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('View'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[800],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: user['status'] == 'Active'
                      ? OutlinedButton.icon(
                          onPressed: () => _suspendUser(user),
                          icon: const Icon(Icons.block, size: 18),
                          label: const Text('Suspend'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange[800],
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: () => _activateUser(user),
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: const Text('Activate'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green[800],
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _deleteUser(user),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete User',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isActive = status == 'Active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? Colors.green[100] : Colors.red[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.green[800] : Colors.red[800],
            ),
          ),
        ],
      ),
    );
  }
}
