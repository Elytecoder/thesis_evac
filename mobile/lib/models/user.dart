/// User model representing both residents and MDRRMO personnel.
class User {
  final int id;
  final String username;
  final String email;
  final String fullName;
  
  // Structured address
  final String province;
  final String municipality;
  final String barangay;
  final String street;
  
  final String? profilePicture;
  final UserRole role;
  final bool isActive;
  final bool isSuspended;
  final bool emailVerified;
  final DateTime dateJoined;
  final String? authToken;
  /// MDRRMO public user reference (API key `user_id`, 6-digit).
  final int? publicUserId;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.fullName = '',
    this.province = '',
    this.municipality = '',
    this.barangay = '',
    this.street = '',
    this.profilePicture,
    required this.role,
    this.isActive = true,
    this.isSuspended = false,
    this.emailVerified = false,
    required this.dateJoined,
    this.authToken,
    this.publicUserId,
  });

  // Legacy getters for backward compatibility
  String get firstName => fullName.split(' ').first;
  String get lastName => fullName.split(' ').length > 1 
      ? fullName.split(' ').sublist(1).join(' ') 
      : '';

  bool get isMdrrmo => role == UserRole.mdrrmo;
  bool get isResident => role == UserRole.resident;

  factory User.fromJson(Map<String, dynamic> json) {
    // Handle both API response formats (with 'user' wrapper and without)
    final userData = json.containsKey('user') ? json['user'] : json;
    
    return User(
      id: _parseInt(userData['id']) ?? 0,
      username: (userData['username'] as String?) ?? '',
      email: userData['email'] as String? ?? '',
      fullName: userData['full_name'] as String? ?? '',
      province: userData['province'] as String? ?? '',
      municipality: userData['municipality'] as String? ?? '',
      barangay: userData['barangay'] as String? ?? '',
      street: userData['street'] as String? ?? '',
      profilePicture: userData['profile_picture'] as String?,
      role: UserRole.fromString(userData['role'] as String? ?? 'resident'),
      isActive: userData['is_active'] as bool? ?? true,
      isSuspended: userData['is_suspended'] as bool? ?? false,
      emailVerified: userData['email_verified'] as bool? ?? false,
      dateJoined: userData['date_joined'] != null
          ? DateTime.tryParse(userData['date_joined'].toString()) ?? DateTime.now()
          : DateTime.now(),
      authToken: json['token'] as String?, // Token is at root level in login response
      publicUserId: _parseOptionalInt(userData['user_id']),
    );
  }

  static int? _parseOptionalInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'full_name': fullName,
      'province': province,
      'municipality': municipality,
      'barangay': barangay,
      'street': street,
      'profile_picture': profilePicture,
      'role': role.value,
      'is_active': isActive,
      'is_suspended': isSuspended,
      'email_verified': emailVerified,
      'date_joined': dateJoined.toIso8601String(),
      'token': authToken,
      if (publicUserId != null) 'user_id': publicUserId,
    };
  }
}

/// User role enum
enum UserRole {
  resident('resident'),
  mdrrmo('mdrrmo');

  final String value;
  const UserRole(this.value);

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (e) => e.value == value,
      orElse: () => UserRole.resident,
    );
  }
}
