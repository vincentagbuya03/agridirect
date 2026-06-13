import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/user/user_service.dart';
import 'admin_ui.dart';

class AdminSettingsTab extends StatefulWidget {
  const AdminSettingsTab({super.key});

  @override
  State<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<AdminSettingsTab> {
  final _userService = UserService();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _emailAlerts = true;
  bool _securityAlerts = true;
  bool _compactTables = false;
  String _refreshCadence = 'Manual';
  String _email = '';
  String _role = 'Admin';
  String _accessLabel = 'System Curator';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    final user = await _userService.getCurrentUser();
    final authUser = Supabase.instance.client.auth.currentUser;

    if (!mounted) return;
    setState(() {
      _nameController.text = (user?.name.trim().isNotEmpty ?? false)
          ? user!.name.trim()
          : (authUser?.userMetadata?['name']?.toString() ?? 'Agri Direct');
      _phoneController.text = user?.phone?.trim() ?? '';
      _email = user?.email ?? authUser?.email ?? '';
      _role = _resolveRole(user?.roles);
      _accessLabel = _role == 'Admin' ? 'System Curator' : _role;
      _isLoading = false;
    });
  }

  String _resolveRole(List<String>? roles) {
    final normalized =
        roles
            ?.map((role) => role.trim().toLowerCase())
            .where((role) => role.isNotEmpty)
            .toSet() ??
        <String>{};
    if (normalized.contains('admin')) return 'Admin';
    if (normalized.contains('seller') || normalized.contains('farmer')) {
      return 'Farmer';
    }
    if (normalized.contains('customer') || normalized.contains('consumer')) {
      return 'Customer';
    }
    return 'Admin';
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      _showSnackBar('Admin name is required.');
      return;
    }

    setState(() => _isSaving = true);
    final updated = await _userService.updateProfile(
      name: name,
      phone: phone.isEmpty ? null : phone,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (updated == null) {
      _showSnackBar('Unable to save admin profile. Please try again.');
      return;
    }

    _showSnackBar('Admin settings saved.');
  }

  Future<void> _sendPasswordReset() async {
    if (_email.isEmpty) {
      _showSnackBar('No email address is available for this admin account.');
      return;
    }

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(_email);
      if (!mounted) return;
      _showSnackBar('Password reset email sent to $_email.');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Unable to send password reset email: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AdminUi.brand,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AdminPageFrame(
        child: Center(child: CircularProgressIndicator(color: AdminUi.brand)),
      );
    }

    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminDashboardHeader(
            title: 'Admin Settings',
            subtitle:
                'Manage your admin profile, account security, and workspace preferences.',
            actions: [
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveProfile,
                style: AdminUi.primaryButton,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_isSaving ? 'Saving' : 'Save Changes'),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 980;
              final profile = _profileCard();
              final side = Column(
                children: [
                  _securityCard(),
                  const SizedBox(height: 20),
                  _preferencesCard(),
                ],
              );

              if (stacked) {
                return Column(
                  children: [profile, const SizedBox(height: 20), side],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: profile),
                  const SizedBox(width: 20),
                  Expanded(flex: 5, child: side),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _profileCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: AdminUi.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.admin_panel_settings_rounded,
            title: 'Profile',
            subtitle: 'This information appears in admin audit trails.',
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AdminUi.brandSoft,
                  borderRadius: AdminUi.radiusLg,
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: AdminUi.brand,
                  size: 34,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_nameController.text, style: AdminUi.title(size: 22)),
                    const SizedBox(height: 4),
                    Text(
                      '$_accessLabel • $_email',
                      style: AdminUi.body(color: AdminUi.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _fieldLabel('Display Name'),
          TextField(
            controller: _nameController,
            decoration: AdminUi.inputDecoration(
              hintText: 'Admin display name',
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 18),
          _fieldLabel('Email Address'),
          TextField(
            enabled: false,
            controller: TextEditingController(text: _email),
            decoration: AdminUi.inputDecoration(
              hintText: 'Admin email',
              prefixIcon: const Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 18),
          _fieldLabel('Phone Number'),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: AdminUi.inputDecoration(
              hintText: '09XX XXX XXXX',
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
          ),
        ],
      ),
    );
  }

  Widget _securityCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminUi.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.lock_outline_rounded,
            title: 'Security',
            subtitle: 'Account access and protection controls.',
          ),
          const SizedBox(height: 22),
          _statusRow('Role', _role, Icons.badge_outlined),
          const SizedBox(height: 14),
          _statusRow('Access Level', _accessLabel, Icons.shield_outlined),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _sendPasswordReset,
              icon: const Icon(Icons.password_rounded, size: 18),
              label: const Text('Send Password Reset'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AdminUi.brand,
                side: const BorderSide(color: AdminUi.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: AdminUi.radiusSm),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _preferencesCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminUi.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.tune_rounded,
            title: 'Workspace',
            subtitle: 'Controls for the admin panel experience.',
          ),
          const SizedBox(height: 20),
          _switchTile(
            title: 'Email alerts',
            subtitle: 'Receive summaries for reports, orders, and approvals.',
            value: _emailAlerts,
            onChanged: (value) => setState(() => _emailAlerts = value),
          ),
          _switchTile(
            title: 'Security alerts',
            subtitle: 'Highlight sensitive admin actions and login changes.',
            value: _securityAlerts,
            onChanged: (value) => setState(() => _securityAlerts = value),
          ),
          _switchTile(
            title: 'Compact tables',
            subtitle: 'Use tighter spacing for dense review sessions.',
            value: _compactTables,
            onChanged: (value) => setState(() => _compactTables = value),
          ),
          const SizedBox(height: 16),
          _fieldLabel('Dashboard Refresh'),
          DropdownButtonFormField<String>(
            initialValue: _refreshCadence,
            decoration: AdminUi.inputDecoration(
              prefixIcon: const Icon(Icons.refresh_rounded),
            ),
            items: const [
              DropdownMenuItem(value: 'Manual', child: Text('Manual')),
              DropdownMenuItem(
                value: 'Every 5 minutes',
                child: Text('Every 5 minutes'),
              ),
              DropdownMenuItem(
                value: 'Every 15 minutes',
                child: Text('Every 15 minutes'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _refreshCadence = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AdminUi.brandSoft,
            borderRadius: AdminUi.radiusSm,
          ),
          child: Icon(icon, color: AdminUi.brand, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AdminUi.title(size: 18)),
              const SizedBox(height: 4),
              Text(subtitle, style: AdminUi.body(color: AdminUi.textMuted)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: AdminUi.label(
          size: 11,
          color: AdminUi.textMuted,
          weight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _statusRow(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminUi.panelAlt,
        borderRadius: AdminUi.radiusSm,
        border: Border.all(color: AdminUi.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AdminUi.brand),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AdminUi.body())),
          Text(value, style: AdminUi.label(color: AdminUi.textPrimary)),
        ],
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AdminUi.label(size: 14, color: AdminUi.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AdminUi.body(size: 12, color: AdminUi.textMuted),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AdminUi.brand,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
