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
      firstName: 'John',
      lastName: 'Doe',
      role: UserRole.resident,
      authToken: 'mock_resident_token_abc123',
    );
  }

  /// Mock MDRRMO user
  static User getMdrrmoUser() {
    return User(
      id: 2,
      username: 'mdrrmo_admin',
      email: 'admin@mdrrmo.gov.ph',
      firstName: 'MDRRMO',
      lastName: 'Admin',
      role: UserRole.mdrrmo,
      authToken: 'mock_mdrrmo_token_xyz789',
    );
  }
}
