import 'package:flutter/material.dart';
import '../../core/config/api_config.dart';
import '../../features/authentication/auth_service.dart';
import '../../features/emergency_contacts/emergency_contacts_service.dart';
import '../../features/notifications/notification_service.dart';
import '../../utils/input_validators.dart';
import '../../utils/input_formatters.dart';
import '../screens/welcome_screen.dart';
import 'system_logs_screen.dart';

/// MDRRMO Admin Settings Screen
/// Contains only fully-functional, production-ready options.
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final AuthService _authService = AuthService();
  final EmergencyContactsService _contactsService = EmergencyContactsService();
  final NotificationService _notifService = NotificationService();

  Map<String, dynamic>? _userProfile;
  List<EmergencyContact> _emergencyContacts = [];
  bool _isLoading = true;
  bool _isRefreshing = false;

  // ── Palette ────────────────────────────────────────────────────────────────
  static const Color _navy = Color(0xFF1E3A8A);
  static const Color _navyLight = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    try {
      final profile = await _authService.getCurrentUser();
      final contacts = await _contactsService.getAllContacts();
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _emergencyContacts = contacts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final profile = await _authService.getCurrentUser();
      final contacts = await _contactsService.getAllContacts();
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _emergencyContacts = contacts;
        });
        _showSnack('Data refreshed successfully.', Colors.green);
      }
    } catch (e) {
      if (mounted) _showSnack('Failed to refresh. Check your connection.', Colors.red);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _handleLogout() async {
    final confirm = await _showConfirmDialog(
      icon: Icons.logout,
      iconColor: Colors.red,
      title: 'Logout',
      message: 'Are you sure you want to log out of your MDRRMO account?',
      confirmLabel: 'Logout',
      confirmColor: Colors.red,
    );
    if (confirm != true) return;

    await _authService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _handleMarkAllRead() async {
    final confirm = await _showConfirmDialog(
      icon: Icons.mark_email_read_outlined,
      iconColor: Colors.teal,
      title: 'Mark All Notifications Read',
      message: 'This will mark all pending notifications as read. Continue?',
      confirmLabel: 'Mark All Read',
      confirmColor: Colors.teal,
    );
    if (confirm != true) return;

    try {
      final msg = await _notifService.markAllAsRead();
      if (mounted) _showSnack(msg, Colors.green);
    } catch (e) {
      if (mounted) _showSnack('Failed to mark notifications: $e', Colors.red);
    }
  }

  Future<void> _handleChangePassword() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _navy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lock_outline, color: _navy, size: 22),
              ),
              const SizedBox(width: 12),
              const Text('Change Password',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPasswordField(
                  controller: currentCtrl,
                  label: 'Current Password',
                  obscure: obscureCurrent,
                  onToggle: () =>
                      setDialogState(() => obscureCurrent = !obscureCurrent),
                ),
                const SizedBox(height: 12),
                _buildPasswordField(
                  controller: newCtrl,
                  label: 'New Password',
                  obscure: obscureNew,
                  onToggle: () =>
                      setDialogState(() => obscureNew = !obscureNew),
                ),
                const SizedBox(height: 12),
                _buildPasswordField(
                  controller: confirmCtrl,
                  label: 'Confirm New Password',
                  obscure: obscureConfirm,
                  onToggle: () =>
                      setDialogState(() => obscureConfirm = !obscureConfirm),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (currentCtrl.text.isEmpty ||
                    newCtrl.text.isEmpty ||
                    confirmCtrl.text.isEmpty) {
                  _showSnack('All fields are required.', Colors.red);
                  return;
                }
                if (newCtrl.text.length < 6) {
                  _showSnack(
                      'New password must be at least 6 characters.', Colors.red);
                  return;
                }
                if (newCtrl.text != confirmCtrl.text) {
                  _showSnack('Passwords do not match.', Colors.red);
                  return;
                }
                Navigator.pop(context);
                try {
                  await _authService.changePassword(
                    oldPassword: currentCtrl.text,
                    newPassword: newCtrl.text,
                    newPasswordConfirm: confirmCtrl.text,
                  );
                  if (mounted) {
                    _showSnack('Password changed successfully.', Colors.green);
                  }
                } catch (e) {
                  if (mounted) _showSnack(e.toString(), Colors.red);
                }
              },
              child: const Text('Change Password'),
            ),
          ],
        ),
      ),
    );

    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
  }

  // ── Emergency Contacts ─────────────────────────────────────────────────────

  Future<void> _showAddContactDialog() async {
    final nameCtrl = TextEditingController();
    final numberCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedType = EmergencyContactsService.getContactTypes()[0];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setDS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_circle_outline,
                  color: Colors.green, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Add Emergency Contact',
                style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  inputFormatters: [NameInputFormatter()],
                  decoration: _inputDeco('Contact Name *', Icons.person_outline),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: numberCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [PhoneNumberInputFormatter()],
                  decoration: _inputDeco(
                      'Contact Number * (09XXXXXXXXX)', Icons.phone_outlined),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: _inputDeco('Contact Type *', Icons.category_outlined),
                  items: EmergencyContactsService.getContactTypes()
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDS(() => selectedType = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration:
                      _inputDeco('Description (optional)', Icons.description_outlined),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () {
                final nameErr = InputValidators.validateName(nameCtrl.text,
                    fieldName: 'Contact name');
                if (nameErr != null) {
                  _showSnack(nameErr, Colors.red);
                  return;
                }
                final phoneErr =
                    InputValidators.validatePhoneNumber(numberCtrl.text);
                if (phoneErr != null) {
                  _showSnack(phoneErr, Colors.red);
                  return;
                }
                final contact = EmergencyContact(
                  id: _contactsService.generateId(),
                  name: nameCtrl.text,
                  number: numberCtrl.text,
                  type: selectedType,
                  description: descCtrl.text,
                );
                _contactsService.addContact(contact).then((_) async {
                  await _loadData();
                  if (!mounted) return;
                  Navigator.pop(context);
                  _showSnack('Contact added successfully.', Colors.green);
                });
              },
              child: const Text('Add Contact'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    numberCtrl.dispose();
    descCtrl.dispose();
  }

  Future<void> _showEditContactDialog(EmergencyContact contact) async {
    final nameCtrl = TextEditingController(text: contact.name);
    final numberCtrl = TextEditingController(text: contact.number);
    final descCtrl = TextEditingController(text: contact.description);
    String selectedType = contact.type;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setDS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit_outlined,
                  color: Colors.orange, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Edit Contact',
                style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  inputFormatters: [NameInputFormatter()],
                  decoration: _inputDeco('Contact Name *', Icons.person_outline),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: numberCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [PhoneNumberInputFormatter()],
                  decoration: _inputDeco('Contact Number *', Icons.phone_outlined),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: _inputDeco('Contact Type *', Icons.category_outlined),
                  items: EmergencyContactsService.getContactTypes()
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDS(() => selectedType = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration:
                      _inputDeco('Description (optional)', Icons.description_outlined),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange, foregroundColor: Colors.white),
              onPressed: () {
                final nameErr = InputValidators.validateName(nameCtrl.text,
                    fieldName: 'Contact name');
                if (nameErr != null) {
                  _showSnack(nameErr, Colors.red);
                  return;
                }
                final phoneErr =
                    InputValidators.validatePhoneNumber(numberCtrl.text);
                if (phoneErr != null) {
                  _showSnack(phoneErr, Colors.red);
                  return;
                }
                final updated = contact.copyWith(
                  name: nameCtrl.text,
                  number: numberCtrl.text,
                  type: selectedType,
                  description: descCtrl.text,
                );
                _contactsService.updateContact(updated).then((_) async {
                  await _loadData();
                  if (!mounted) return;
                  Navigator.pop(context);
                  _showSnack('Contact updated.', Colors.green);
                });
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    numberCtrl.dispose();
    descCtrl.dispose();
  }

  Future<void> _showDeleteContactDialog(EmergencyContact contact) async {
    final confirm = await _showConfirmDialog(
      icon: Icons.delete_outline,
      iconColor: Colors.red,
      title: 'Delete Contact',
      message:
          'Remove "${contact.name}" from the emergency contacts list?\n\nResidents will no longer see this contact.',
      confirmLabel: 'Delete',
      confirmColor: Colors.red,
    );
    if (confirm != true) return;
    await _contactsService.deleteContact(contact.id);
    _loadData();
    if (mounted) _showSnack('Contact deleted.', Colors.orange);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<bool?> _showConfirmDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ]),
          content: Text(message,
              style: TextStyle(color: Colors.grey[700], fontSize: 14,
                  height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      );

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) =>
      TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
            onPressed: onToggle,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Admin profile header ───────────────────────────────────────
            _buildProfileHeader(),

            const SizedBox(height: 24),

            // ── Account section ────────────────────────────────────────────
            _buildSectionHeader(Icons.manage_accounts_outlined, 'Account'),
            const SizedBox(height: 10),
            _buildCard(children: [
              _buildTile(
                icon: Icons.lock_outline,
                iconColor: _navy,
                title: 'Change Password',
                subtitle: 'Update your MDRRMO admin password',
                onTap: _handleChangePassword,
              ),
              _buildDivider(),
              _buildTile(
                icon: Icons.logout,
                iconColor: Colors.red,
                title: 'Logout',
                subtitle: 'Sign out of this admin account',
                onTap: _handleLogout,
                trailingColor: Colors.red,
              ),
            ]),

            const SizedBox(height: 24),

            // ── Data & Sync section ────────────────────────────────────────
            _buildSectionHeader(Icons.sync_outlined, 'Data & Sync'),
            const SizedBox(height: 10),
            _buildCard(children: [
              _buildTile(
                icon: Icons.refresh,
                iconColor: _navyLight,
                title: 'Refresh Latest Data',
                subtitle: 'Reload your profile and contacts from server',
                trailing: _isRefreshing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _refreshData,
              ),
              _buildDivider(),
              _buildTile(
                icon: Icons.mark_email_read_outlined,
                iconColor: Colors.teal,
                title: 'Mark All Notifications as Read',
                subtitle: 'Clear all unread notification badges',
                onTap: _handleMarkAllRead,
              ),
            ]),

            const SizedBox(height: 24),

            // ── Admin Tools section ────────────────────────────────────────
            _buildSectionHeader(Icons.admin_panel_settings_outlined, 'Admin Tools'),
            const SizedBox(height: 10),
            _buildCard(children: [
              _buildTile(
                icon: Icons.list_alt_outlined,
                iconColor: Colors.indigo,
                title: 'System Logs',
                subtitle: 'View all system activity and events',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SystemLogsScreen()),
                ),
              ),
              _buildDivider(),
              _buildTile(
                icon: Icons.emergency_outlined,
                iconColor: Colors.red,
                title: 'Emergency Contacts',
                subtitle: 'Manage contacts visible to all residents',
                onTap: _scrollToContacts,
              ),
            ]),

            const SizedBox(height: 24),

            // ── Emergency Contacts section ─────────────────────────────────
            _buildEmergencyContactsSection(),

            const SizedBox(height: 24),

            // ── System Information section ─────────────────────────────────
            _buildSectionHeader(Icons.info_outline, 'System Information'),
            const SizedBox(height: 10),
            _buildCard(children: [
              _buildInfoRow(Icons.computer_outlined, 'App Version', '1.0.0'),
              _buildDivider(),
              _buildInfoRow(Icons.cloud_outlined, 'Environment',
                  ApiConfig.baseUrl.contains('localhost') || ApiConfig.baseUrl.contains('10.0.2.2')
                      ? 'Local Development'
                      : 'Production (Render)'),
              _buildDivider(),
              _buildInfoRow(Icons.location_city_outlined, 'Coverage Area',
                  'Bulan, Sorsogon'),
              _buildDivider(),
              _buildInfoRow(Icons.psychology_outlined, 'AI Models',
                  'Naive Bayes v1 · Random Forest v1'),
            ]),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Section widgets ────────────────────────────────────────────────────────

  Widget _buildProfileHeader() {
    final name = _userProfile?['full_name'] ??
        _userProfile?['username'] ??
        'MDRRMO Admin';
    final email = _userProfile?['email'] ?? '';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_navy, _navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
            ),
            child: const Icon(Icons.admin_panel_settings,
                size: 34, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    )),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(email,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.8))),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'MDRRMO ADMINISTRATOR',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String label) => Row(
        children: [
          Icon(icon, size: 18, color: _navy),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _navy,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: Colors.blue.shade100)),
        ],
      );

  Widget _buildCard({required List<Widget> children}) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(children: children),
      );

  Widget _buildTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    Color? trailingColor,
  }) =>
      Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                trailing ??
                    Icon(Icons.chevron_right,
                        color: trailingColor ?? Colors.grey[400]),
              ],
            ),
          ),
        ),
      );

  Widget _buildDivider() => Divider(
      height: 1, thickness: 1, color: Colors.grey[100], indent: 72);

  Widget _buildInfoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.grey[600], size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700])),
            ),
            Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _buildEmergencyContactsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              const Icon(Icons.emergency, color: Colors.red, size: 18),
              const SizedBox(width: 8),
              const Text(
                'EMERGENCY CONTACTS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 10),
              Container(height: 1, width: 40, color: Colors.red.shade100),
            ]),
            TextButton.icon(
              onPressed: _showAddContactDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
              style: TextButton.styleFrom(
                foregroundColor: _navy,
                textStyle: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Visible to all residents in the app',
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 10),
        _buildCard(
          children: _emergencyContacts.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.contacts_outlined,
                            size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text('No emergency contacts added yet',
                            style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  ),
                ]
              : _emergencyContacts
                  .asMap()
                  .entries
                  .map((e) => Column(children: [
                        _buildContactRow(e.value),
                        if (e.key < _emergencyContacts.length - 1)
                          _buildDivider(),
                      ]))
                  .toList(),
        ),
      ],
    );
  }

  Widget _buildContactRow(EmergencyContact contact) {
    final color = _colorForType(contact.type);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_iconForType(contact.type), color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                Text(contact.number,
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey[600])),
                if (contact.description.isNotEmpty)
                  Text(contact.description,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(contact.type,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            color: Colors.orange,
            onPressed: () => _showEditContactDialog(contact),
            tooltip: 'Edit',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: Colors.red,
            onPressed: () => _showDeleteContactDialog(contact),
            tooltip: 'Delete',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  // Placeholder so the "Emergency Contacts" quick-link feels responsive.
  // In a real multi-screen setup this would scroll to the contacts section.
  void _scrollToContacts() => _showSnack(
        'Scroll down to manage Emergency Contacts.',
        Colors.blue,
      );

  Color _colorForType(String type) {
    switch (type.toLowerCase()) {
      case 'police': return Colors.indigo;
      case 'fire': return Colors.red;
      case 'medical': return Colors.green;
      case 'mdrrmo': return _navy;
      case 'coast guard': return Colors.cyan;
      default: return Colors.orange;
    }
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'police': return Icons.local_police;
      case 'fire': return Icons.local_fire_department;
      case 'medical': return Icons.local_hospital;
      case 'mdrrmo': return Icons.shield_outlined;
      case 'coast guard': return Icons.sailing;
      default: return Icons.emergency_outlined;
    }
  }
}

