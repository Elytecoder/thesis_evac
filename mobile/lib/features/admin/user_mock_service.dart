/// Mock User Service for User Management
/// Provides mock data for resident users until database is connected
class UserMockService {
  // Mock user data
  static List<Map<String, dynamic>> _users = [
    {
      'user_id': 'usr001',
      'name': 'Juan Dela Cruz',
      'email': 'juan@example.com',
      'barangay': 'Zone 1',
      'status': 'Active',
      'date_registered': '2024-01-15',
      'reports_count': 5,
    },
    {
      'user_id': 'usr002',
      'name': 'Maria Santos',
      'email': 'maria@example.com',
      'barangay': 'Zone 3',
      'status': 'Active',
      'date_registered': '2024-01-20',
      'reports_count': 3,
    },
    {
      'user_id': 'usr003',
      'name': 'Pedro Reyes',
      'email': 'pedro@example.com',
      'barangay': 'Zone 2',
      'status': 'Suspended',
      'date_registered': '2024-02-01',
      'reports_count': 1,
    },
    {
      'user_id': 'usr004',
      'name': 'Ana Garcia',
      'email': 'ana@example.com',
      'barangay': 'Zone 1',
      'status': 'Active',
      'date_registered': '2024-02-05',
      'reports_count': 8,
    },
    {
      'user_id': 'usr005',
      'name': 'Roberto Cruz',
      'email': 'roberto@example.com',
      'barangay': 'San Juan',
      'status': 'Active',
      'date_registered': '2024-02-10',
      'reports_count': 2,
    },
    {
      'user_id': 'usr006',
      'name': 'Linda Bautista',
      'email': 'linda@example.com',
      'barangay': 'Zone 2',
      'status': 'Active',
      'date_registered': '2024-02-15',
      'reports_count': 4,
    },
    {
      'user_id': 'usr007',
      'name': 'Carlos Mendoza',
      'email': 'carlos@example.com',
      'barangay': 'Zone 3',
      'status': 'Suspended',
      'date_registered': '2024-01-28',
      'reports_count': 0,
    },
    {
      'user_id': 'usr008',
      'name': 'Sofia Ramos',
      'email': 'sofia@example.com',
      'barangay': 'San Pedro',
      'status': 'Active',
      'date_registered': '2024-02-08',
      'reports_count': 6,
    },
    {
      'user_id': 'usr009',
      'name': 'Miguel Torres',
      'email': 'miguel@example.com',
      'barangay': 'Zone 4',
      'status': 'Active',
      'date_registered': '2024-01-25',
      'reports_count': 7,
    },
    {
      'user_id': 'usr010',
      'name': 'Elena Villanueva',
      'email': 'elena@example.com',
      'barangay': 'Zone 1',
      'status': 'Active',
      'date_registered': '2024-02-12',
      'reports_count': 3,
    },
  ];

  /// Get all users
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    return List<Map<String, dynamic>>.from(_users);
  }

  /// Get user by ID
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      return _users.firstWhere((user) => user['user_id'] == userId);
    } catch (e) {
      return null;
    }
  }

  /// Update user status (Active/Suspended)
  Future<void> updateUserStatus(String userId, String newStatus) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    final index = _users.indexWhere((user) => user['user_id'] == userId);
    if (index != -1) {
      _users[index]['status'] = newStatus;
    }
  }

  /// Delete user
  Future<void> deleteUser(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _users.removeWhere((user) => user['user_id'] == userId);
  }

  /// Search users by name or email
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    final lowercaseQuery = query.toLowerCase();
    return _users.where((user) {
      final name = user['name'].toString().toLowerCase();
      final email = user['email'].toString().toLowerCase();
      return name.contains(lowercaseQuery) || email.contains(lowercaseQuery);
    }).toList();
  }

  /// Filter users by barangay
  Future<List<Map<String, dynamic>>> filterByBarangay(String barangay) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (barangay == 'All') {
      return List<Map<String, dynamic>>.from(_users);
    }
    
    return _users.where((user) => user['barangay'] == barangay).toList();
  }

  /// Get users by status
  Future<List<Map<String, dynamic>>> getUsersByStatus(String status) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _users.where((user) => user['status'] == status).toList();
  }

  /// Get total user count
  Future<int> getTotalUserCount() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _users.length;
  }

  /// Get active user count
  Future<int> getActiveUserCount() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _users.where((user) => user['status'] == 'Active').length;
  }

  /// Get suspended user count
  Future<int> getSuspendedUserCount() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _users.where((user) => user['status'] == 'Suspended').length;
  }
}
