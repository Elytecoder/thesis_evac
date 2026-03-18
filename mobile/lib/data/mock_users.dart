import '../models/user.dart';

/// Mock user data for testing.
/// 
/// FUTURE: Replace with real authentication via API.
class MockUsers {
  /// Mock resident user
  static User getResidentUser() {
    return User(
      id: 1,
      username: 'john_doe',
      email: 'john@example.com',
      fullName: 'John Doe',
      phoneNumber: '09123456789',
      province: 'Sorsogon',
      municipality: 'Sorsogon City',
      barangay: 'Bibincahan',
      street: 'Sample Street',
      role: UserRole.resident,
      dateJoined: DateTime.now(),
      emailVerified: true,
      authToken: 'mock_resident_token_abc123',
    );
  }

  /// Mock MDRRMO user
  static User getMdrrmoUser() {
    return User(
      id: 2,
      username: 'mdrrmo_admin',
      email: 'admin@mdrrmo.gov.ph',
      fullName: 'MDRRMO Admin',
      phoneNumber: '09987654321',
      province: 'Sorsogon',
      municipality: 'Sorsogon City',
      barangay: 'City Proper',
      street: 'Government Center',
      role: UserRole.mdrrmo,
      dateJoined: DateTime.now(),
      emailVerified: true,
      authToken: 'mock_mdrrmo_token_xyz789',
    );
  }
}
