import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final _bioController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isResettingPassword = false;
  bool _emailAlerts = true;
  bool _securityAlerts = true;
  bool _compactTables = false;
  String _refreshCadence = 'Manual';
  String _email = '';
  String _role = 'Admin';
  String _accessLabel = 'System Curator';

  static const Color _primary = Color(0xFF059669);
  static const Color _primaryDark = Color(0xFF047857);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    final user = await _userService.getCurrentUser();
    final authUser = Supabase.instance.client.auth.currentUser;

    // Load persisted workspace preferences
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('admin_pref_name');
    final savedPhone = prefs.getString('admin_pref_phone');
    final savedEmailAlerts = prefs.getBool('admin_pref_email_alerts') ?? true;
    final savedSecurityAlerts = prefs.getBool('admin_pref_security_alerts') ?? true;
    final savedCompactTables = prefs.getBool('admin_pref_compact_tables') ?? false;
    final savedCadence = prefs.getString('admin_pref_refresh_cadence') ?? 'Manual';
    final savedBio = prefs.getString('admin_pref_bio') ?? 'Super Administrator & Operations Curator';

    if (!mounted) return;
    setState(() {
      _nameController.text = (user?.name.trim().isNotEmpty ?? false)
          ? user!.name.trim()
          : (savedName ?? (authUser?.userMetadata?['name']?.toString() ?? 'Agri Direct'));
      _phoneController.text = (user?.phone?.trim().isNotEmpty ?? false)
          ? user!.phone!.trim()
          : (savedPhone ?? '');
      _bioController.text = savedBio;
      _emailAlerts = savedEmailAlerts;
      _securityAlerts = savedSecurityAlerts;
      _compactTables = savedCompactTables;
      _refreshCadence = savedCadence;
      _email = user?.email ?? authUser?.email ?? 'noreplyagridirect@gmail.com';
      _role = _resolveRole(user?.roles);
      _accessLabel = _role == 'Admin' ? 'System Curator' : _role;
      _isLoading = false;
    });
  }

  String _resolveRole(List<String>? roles) {
    final normalized = roles
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

  Future<void> _savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final bio = _bioController.text.trim();

    if (name.isEmpty) {
      _showSnackBar('Admin name is required.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    // Save preferences to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('admin_pref_email_alerts', _emailAlerts);
    await prefs.setBool('admin_pref_security_alerts', _securityAlerts);
    await prefs.setBool('admin_pref_compact_tables', _compactTables);
    await prefs.setString('admin_pref_refresh_cadence', _refreshCadence);
    await prefs.setString('admin_pref_bio', bio);
    await prefs.setString('admin_pref_name', name);
    await prefs.setString('admin_pref_phone', phone);

    await _userService.updateProfile(
      name: name,
      phone: phone.isEmpty ? null : phone,
      bio: bio.isEmpty ? null : bio,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    _showSnackBar('Admin settings & workspace preferences saved successfully.');
  }

  Future<void> _sendPasswordReset() async {
    if (_email.isEmpty) {
      _showSnackBar('No email address is available for this account.', isError: true);
      return;
    }

    setState(() => _isResettingPassword = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(_email);
      if (!mounted) return;
      _showSnackBar('Password reset email dispatched to $_email.');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Unable to send password reset email: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isResettingPassword = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red : _primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AdminPageFrame(
        child: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildExecutiveHeader(context),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 980;
              final profile = _buildProfileCard();
              final side = Column(
                children: [
                  _buildSecurityCard(),
                  const SizedBox(height: 20),
                  _buildPreferencesCard(),
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
                  Expanded(flex: 58, child: profile),
                  const SizedBox(width: 24),
                  Expanded(flex: 42, child: side),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Executive Header ──────────────────────────────────────────────────────
  Widget _buildExecutiveHeader(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_rounded, size: 13, color: _primary),
                      const SizedBox(width: 5),
                      Text(
                        'LIVE EXECUTIVE CONTROL',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _primaryDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Admin Settings & Governance',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isMobile ? 20 : 26,
                    fontWeight: FontWeight.w900,
                    color: _dark,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage your admin profile, account security, and workspace preferences.',
                  style: GoogleFonts.inter(
                    fontSize: isMobile ? 12 : 13.5,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveProfile,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_rounded, size: 16),
            label: Text(
              _isSaving ? 'Saving...' : 'Save Changes',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 20,
                vertical: 13,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Left Column: Profile Card ─────────────────────────────────────────────
  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.admin_panel_settings_rounded,
            title: 'Administrative Identity',
            subtitle: 'This information appears in system audit logs and email resolutions.',
          ),
          const SizedBox(height: 22),

          // User Profile Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_primary, _primaryDark],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _primary.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : 'A',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _nameController.text,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _dark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'VERIFIED',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: _primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$_accessLabel • $_email',
                        style: GoogleFonts.inter(fontSize: 12.5, color: _muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Fields
          _buildFieldLabel('Display Name'),
          TextField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.inter(fontSize: 14, color: _dark),
            decoration: _inputDecoration(
              hintText: 'Admin display name',
              prefixIcon: Icons.person_outline_rounded,
            ),
          ),
          const SizedBox(height: 18),

          _buildFieldLabel('Email Address (Primary Login)'),
          TextField(
            enabled: false,
            controller: TextEditingController(text: _email),
            style: GoogleFonts.inter(fontSize: 14, color: _muted),
            decoration: _inputDecoration(
              hintText: 'Admin email',
              prefixIcon: Icons.email_outlined,
              suffixIcon: Icons.lock_outline_rounded,
            ),
          ),
          const SizedBox(height: 18),

          _buildFieldLabel('Contact Phone Number'),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.inter(fontSize: 14, color: _dark),
            decoration: _inputDecoration(
              hintText: '09XX XXX XXXX',
              prefixIcon: Icons.phone_outlined,
            ),
          ),
          const SizedBox(height: 18),

          _buildFieldLabel('Admin Signature / Audit Role Note'),
          TextField(
            controller: _bioController,
            style: GoogleFonts.inter(fontSize: 14, color: _dark),
            decoration: _inputDecoration(
              hintText: 'e.g. Super Administrator & Operations Curator',
              prefixIcon: Icons.badge_outlined,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Right Column: Security Card ───────────────────────────────────────────
  Widget _buildSecurityCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.security_rounded,
            title: 'Security & Access Control',
            subtitle: 'Account access and protection controls.',
          ),
          const SizedBox(height: 18),

          // Role & Access Info Rows
          _buildStatusRow('Assigned Role', _role, Icons.badge_outlined, const Color(0xFF0284C7)),
          const SizedBox(height: 10),
          _buildStatusRow('Privilege Scope', _accessLabel, Icons.shield_outlined, _primary),
          const SizedBox(height: 18),

          // Password Reset Trigger
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isResettingPassword ? null : _sendPasswordReset,
              icon: _isResettingPassword
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
                    )
                  : const Icon(Icons.password_rounded, size: 16),
              label: Text(
                _isResettingPassword ? 'Dispatching Email...' : 'Send Password Reset Email',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryDark,
                side: const BorderSide(color: _border),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Right Column: Workspace Preferences Card ──────────────────────────────
  Widget _buildPreferencesCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.tune_rounded,
            title: 'Workspace Preferences',
            subtitle: 'Controls for the admin console experience.',
          ),
          const SizedBox(height: 18),

          _buildSwitchTile(
            title: 'Email alerts & digests',
            subtitle: 'Receive summaries for reports, orders, and farmer approvals.',
            value: _emailAlerts,
            onChanged: (val) {
              setState(() => _emailAlerts = val);
              _savePreference('admin_pref_email_alerts', val);
            },
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),

          _buildSwitchTile(
            title: 'Security incident alerts',
            subtitle: 'Highlight sensitive admin actions and login changes.',
            value: _securityAlerts,
            onChanged: (val) {
              setState(() => _securityAlerts = val);
              _savePreference('admin_pref_security_alerts', val);
            },
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),

          _buildSwitchTile(
            title: 'Compact review tables',
            subtitle: 'Use tighter spacing for high-density audit sessions.',
            value: _compactTables,
            onChanged: (val) {
              setState(() => _compactTables = val);
              _savePreference('admin_pref_compact_tables', val);
            },
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),

          _buildFieldLabel('Console Auto-Refresh Cadence'),
          const SizedBox(height: 6),
          Row(
            children: ['Manual', '5 min', '15 min'].map((cadence) {
              final isSelected = _refreshCadence == cadence;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _refreshCadence = cadence);
                        _savePreference('admin_pref_refresh_cadence', cadence);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: isSelected ? _primary : _surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? _primary : _border,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            cadence,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 12, color: _muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          color: _muted,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    IconData? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.inter(fontSize: 13, color: _muted),
      prefixIcon: Icon(prefixIcon, color: _muted, size: 18),
      suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: _muted, size: 18) : null,
      filled: true,
      fillColor: _surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 12.5, color: _muted, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _dark),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 11.5, color: _muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: value,
          activeThumbColor: _primary,
          activeTrackColor: const Color(0xFFA7F3D0),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
