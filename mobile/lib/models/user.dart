/// User model representing both residents and MDRRMO personnel.
class User {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final UserRole role;
  final String? authToken;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.authToken,
  });

  String get fullName => '$firstName $lastName';

  bool get isMdrrmo => role == UserRole.mdrrmo;
  bool get isResident => role == UserRole.resident;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      role: UserRole.fromString(json['role'] as String),
      authToken: json['auth_token'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'role': role.value,
      'auth_token': authToken,
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
