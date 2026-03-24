import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../../core/config/api_config.dart';
import '../../core/config/storage_config.dart';
import '../../features/authentication/auth_service.dart';
import '../../features/emergency_contacts/emergency_contacts_service.dart';
import '../../utils/input_validators.dart';
import '../../utils/input_formatters.dart';
import 'welcome_screen.dart';

/// Resident Settings Screen - Complete account management
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final EmergencyContactsService _contactsService = EmergencyContactsService();
  
  Map<String, dynamic>? _userProfile;
  List<EmergencyContact> _emergencyContacts = [];
  bool _isLoading = true;
  bool _isEditing = false;
  String? _profileImagePath; // Store profile image path
  bool _voiceNavigationEnabled = true;

  // Controllers for profile editing (only phone and street are editable)
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _streetController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Prefer fresh profile from API so registration data is reflected
      final profile = await _authService.getCurrentUser();
      final contacts = await _contactsService.getAllContacts();
      final prefs = await SharedPreferences.getInstance();
      final savedImagePath = prefs.getString('profile_image_path');
      setState(() {
        _userProfile = profile;
        _emergencyContacts = contacts;
        _profileImagePath = savedImagePath;
        _voiceNavigationEnabled =
            prefs.getBool(StorageConfig.enableVoiceNavigationKey) ?? true;
        _phoneController.text = profile['phone_number']?.toString() ?? profile['phone']?.toString() ?? '';
        _streetController.text = profile['street']?.toString() ?? '';
        _isLoading = false;
      });
    } catch (e) {
      // Fallback to cached profile only when API fails (e.g. offline)
      final prefs = await SharedPreferences.getInstance();
      final savedProfileJson = prefs.getString('user_profile');
      Map<String, dynamic>? fallback;
      if (savedProfileJson != null) {
        try {
          fallback = json.decode(savedProfileJson);
        } catch (_) {}
      }
      setState(() {
        _userProfile = fallback;
        _phoneController.text = fallback?['phone_number']?.toString() ?? fallback?['phone']?.toString() ?? '';
        _streetController.text = fallback?['street']?.toString() ?? '';
        _voiceNavigationEnabled =
            prefs.getBool(StorageConfig.enableVoiceNavigationKey) ?? true;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_validateProfile()) return;

    try {
      final updated = await _authService.updateProfile(
        phoneNumber: _phoneController.text.trim(),
        street: _streetController.text.trim(),
      );
      setState(() {
        _userProfile = updated.isNotEmpty ? updated : _userProfile;
        _isEditing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _validateProfile() {
    final phoneError = InputValidators.validatePhoneNumber(_phoneController.text);
    if (phoneError != null) {
      _showError(phoneError);
      return false;
    }
    return true;
  }
  
  /// Pick profile image
  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _profileImagePath = image.path;
        });
        
        // Save image path to shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image_path', image.path);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _setVoiceNavigationEnabled(bool value) async {
    setState(() => _voiceNavigationEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageConfig.enableVoiceNavigationKey, value);
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
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
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
      }
    }
  }

  void _makePhoneCall(String number, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Call $name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Number: $number'),
            const SizedBox(height: 8),
            const Text('Do you want to call this number?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: number));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$name number copied to clipboard'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Copy Number'),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final TextEditingController currentPwController = TextEditingController();
    final TextEditingController newPwController = TextEditingController();
    final TextEditingController confirmPwController = TextEditingController();
    final scaffoldContext = context;

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPwController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPwController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPwController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final current = currentPwController.text;
              final newPw = newPwController.text;
              final confirm = confirmPwController.text;
              if (current.isEmpty) {
                _showError('Please enter your current password');
                return;
              }
              if (newPw.length < 6) {
                _showError('New password must be at least 6 characters');
                return;
              }
              if (newPw != confirm) {
                _showError('New passwords do not match');
                return;
              }
              try {
                await _authService.changePassword(
                  oldPassword: current,
                  newPassword: newPw,
                  newPasswordConfirm: confirm,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (scaffoldContext.mounted) {
                  ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                    const SnackBar(
                      content: Text('Password changed successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                _showError(e.toString().replaceFirst('Exception: ', ''));
              }
            },
            child: const Text('Change Password'),
          ),
        ],
      ),
    );

    currentPwController.dispose();
    newPwController.dispose();
    confirmPwController.dispose();
  }

  Future<void> _showDeleteAccountDialog() async {
    final passwordController = TextEditingController();
    String? passwordResult;
    try {
      passwordResult = await showDialog<String?>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.red),
              SizedBox(width: 8),
              Expanded(child: Text('Delete Account')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This permanently removes your account from the server. You will not be able to log in again with this email.\n\nEnter your password to confirm.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (ApiConfig.useMockData)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Demo mode: account is cleared locally only.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final pw = passwordController.text.trim();
                if (pw.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Enter your password to confirm')),
                  );
                  return;
                }
                Navigator.pop(dialogContext, pw);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete permanently'),
            ),
          ],
        ),
      );
    } finally {
      passwordController.dispose();
    }

    if (passwordResult == null || passwordResult.isEmpty) return;

    try {
      await _authService.deleteAccount(password: passwordResult);
    } catch (e) {
      if (mounted) {
        _showError(e.toString().replaceFirst('Exception: ', ''));
      }
      return;
    }

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deleted successfully'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // SECTION 1: Profile
                  _buildProfileSection(),

                  const SizedBox(height: 16),

                  // Navigation preferences
                  _buildNavigationSection(),

                  const SizedBox(height: 16),

                  // SECTION 2: Account Management
                  _buildAccountManagementSection(),

                  const SizedBox(height: 16),

                  // SECTION 3: Emergency Contacts (Read-Only)
                  _buildEmergencyContactsSection(),

                  const SizedBox(height: 16),

                  // About Section
                  _buildAboutSection(),

                  const SizedBox(height: 24),

                  // Logout Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _handleLogout,
                        icon: const Icon(Icons.logout),
                        label: const Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildNavigationSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Icon(Icons.navigation, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  const Text(
                    'Navigation',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SwitchListTile(
              secondary: Icon(Icons.record_voice_over, color: Colors.blue[700]),
              title: const Text('Enable Voice Navigation'),
              subtitle: const Text(
                'Spoken turn-by-turn directions during live navigation when you have internet. Without internet, the map still works but voice stays off.',
              ),
              value: _voiceNavigationEnabled,
              onChanged: _setVoiceNavigationEnabled,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 22),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.grey[100],
      ),
      child: Text(
        value.isEmpty ? '-' : value,
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      const Text(
                        'Profile',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (!_isEditing)
                    TextButton.icon(
                      onPressed: () => setState(() => _isEditing = true),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                    ),
                ],
              ),
              const Divider(height: 24),

              // Full Name (read-only)
              _buildReadOnlyField('Full Name', _userProfile?['full_name'] ?? _userProfile?['username'] ?? '-', Icons.person_outline),
              const SizedBox(height: 16),

              // Email (read-only; not editable unless re-verification is implemented)
              _buildReadOnlyField('Email', _userProfile?['email'] ?? '-', Icons.email_outlined),
              const SizedBox(height: 16),

              // Phone Number (editable)
              TextField(
                controller: _phoneController,
                enabled: _isEditing,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  PhoneNumberInputFormatter(),
                ],
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '09XXXXXXXXX',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: !_isEditing,
                  fillColor: !_isEditing ? Colors.grey[100] : null,
                ),
              ),
              const SizedBox(height: 16),

              // Province (read-only)
              _buildReadOnlyField('Province', _userProfile?['province'] ?? '-', Icons.location_city),
              const SizedBox(height: 16),

              // Municipality (read-only)
              _buildReadOnlyField('Municipality', _userProfile?['municipality'] ?? '-', Icons.place),
              const SizedBox(height: 16),

              // Barangay (read-only)
              _buildReadOnlyField('Barangay', _userProfile?['barangay'] ?? '-', Icons.home_work),
              const SizedBox(height: 16),

              // Street Address (editable)
              TextField(
                controller: _streetController,
                enabled: _isEditing,
                decoration: InputDecoration(
                  labelText: 'Street Address',
                  hintText: 'Street, building, or landmark',
                  prefixIcon: const Icon(Icons.streetview),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: !_isEditing,
                  fillColor: !_isEditing ? Colors.grey[100] : null,
                ),
              ),

              if (_isEditing) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _isEditing = false;
                            _phoneController.text = _userProfile?['phone_number'] ?? _userProfile?['phone'] ?? '';
                            _streetController.text = _userProfile?['street'] ?? '';
                          });
                        },
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
                        child: const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountManagementSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.manage_accounts, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  const Text(
                    'Account Management',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              
              _buildAccountAction(
                icon: Icons.lock_outline,
                title: 'Change Password',
                subtitle: 'Update your account password',
                onTap: _showChangePasswordDialog,
              ),
              
              const SizedBox(height: 12),
              
              _buildAccountAction(
                icon: Icons.delete_outline,
                title: 'Delete Account',
                subtitle: 'Permanently delete your account',
                color: Colors.red,
                onTap: _showDeleteAccountDialog,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountAction({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: color ?? Colors.grey[700]),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyContactsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.emergency, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  const Text(
                    'Emergency Contacts',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Managed by MDRRMO • Tap to copy number',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
              const Divider(height: 24),
              
              ..._emergencyContacts.map((contact) => _buildEmergencyContactCard(contact)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyContactCard(EmergencyContact contact) {
    Color color = _getColorForType(contact.type);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _makePhoneCall(contact.number, contact.name),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_getIconForType(contact.type), color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (contact.description.isNotEmpty)
                        Text(
                          contact.description,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      contact.number,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Icon(Icons.phone, size: 14, color: Colors.grey[400]),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'police':
        return Colors.indigo;
      case 'fire':
        return Colors.red;
      case 'medical':
        return Colors.green;
      case 'mdrrmo':
        return Colors.blue;
      case 'coast guard':
        return Colors.cyan;
      case 'emergency':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'police':
        return Icons.local_police;
      case 'fire':
        return Icons.local_fire_department;
      case 'medical':
        return Icons.local_hospital;
      case 'mdrrmo':
        return Icons.shield_outlined;
      case 'coast guard':
        return Icons.sailing;
      case 'emergency':
        return Icons.emergency_outlined;
      default:
        return Icons.phone;
    }
  }


  Widget _buildAboutSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _showAboutDialog,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey[700]),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'App version and information',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue[700]),
            const SizedBox(width: 8),
            const Text('About'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI-Powered Evacuation Routing',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Version 1.0.0',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'An intelligent mobile application for safe evacuation routing in Bulan, Sorsogon, Philippines.',
            ),
            const SizedBox(height: 16),
            Text(
              'Features:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            _buildFeatureItem('• Real-time hazard reporting'),
            _buildFeatureItem('• AI-powered route calculation'),
            _buildFeatureItem('• Offline support'),
            _buildFeatureItem('• Emergency hotlines'),
            const SizedBox(height: 16),
            Text(
              '© 2026 Thesis Project',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
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

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[700],
        ),
      ),
    );
  }
}
