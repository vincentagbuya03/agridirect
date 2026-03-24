import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/admin_service.dart';
import '../../../shared/services/auth_service.dart';

/// Admin Settings Tab - System configuration and preferences (Modern White)
class AdminSettingsTab extends StatefulWidget {
  final AdminService adminService;

  const AdminSettingsTab({super.key, required this.adminService});

  @override
  State<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<AdminSettingsTab> {
  final _authService = AuthService();

  // Settings state
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _orderAlerts = true;
  bool _farmerRegistrationAlerts = true;
  bool _reportAlerts = true;
  bool _maintenanceMode = false;
  bool _newUserRegistration = true;
  bool _farmerRegistration = true;

  // Modern light theme colors
  static const Color _primary = Color(0xFF10B981);
  static const Color _secondary = Color(0xFF3B82F6);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _background = Color(0xFFFAFAFA);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _muted = Color(0xFF64748B);
  static const Color _text = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      color: _background,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text(
              'Settings',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _text,
              ),
            ),
            Text(
              'Manage your profile and platform configurations',
              style: GoogleFonts.inter(fontSize: 13, color: _muted),
            ),
            const SizedBox(height: 32),
            // Profile Section
            _buildSection(
              title: 'Admin Profile',
              icon: Icons.person_rounded,
              child: _buildProfileCard(),
            ),
            const SizedBox(height: 24),
            // Notification Settings
            _buildSection(
              title: 'Notifications',
              icon: Icons.notifications_rounded,
              child: _buildNotificationSettings(),
            ),
            const SizedBox(height: 24),
            // Alert Settings
            _buildSection(
              title: 'Alert Preferences',
              icon: Icons.warning_rounded,
              child: _buildAlertSettings(),
            ),
            const SizedBox(height: 24),
            // Platform Settings
            _buildSection(
              title: 'Platform Settings',
              icon: Icons.settings_rounded,
              child: _buildPlatformSettings(),
            ),
            const SizedBox(height: 24),
            // Danger Zone
            _buildSection(
              title: 'Danger Zone',
              icon: Icons.dangerous_rounded,
              iconColor: _danger,
              child: _buildDangerZone(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    Color? iconColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (iconColor ?? _primary).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor ?? _primary, size: 22),
                ),
                const SizedBox(width: 14),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _text,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: _border, height: 1),
          // Content
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primary, Color(0xFF34D399)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              _authService.userName.isNotEmpty
                  ? _authService.userName[0].toUpperCase()
                  : 'A',
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _authService.userName,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _authService.userEmail,
                style: GoogleFonts.inter(fontSize: 14, color: _muted),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 16,
                      color: _primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Super Administrator',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationSettings() {
    return Column(
      children: [
        _buildToggleRow(
          title: 'Email Notifications',
          subtitle: 'Receive important updates via email',
          icon: Icons.email_outlined,
          value: _emailNotifications,
          onChanged: (v) => setState(() => _emailNotifications = v),
        ),
        const Divider(height: 32),
        _buildToggleRow(
          title: 'Push Notifications',
          subtitle: 'Get instant notifications in browser',
          icon: Icons.notifications_active_outlined,
          value: _pushNotifications,
          onChanged: (v) => setState(() => _pushNotifications = v),
        ),
      ],
    );
  }

  Widget _buildAlertSettings() {
    return Column(
      children: [
        _buildToggleRow(
          title: 'New Order Alerts',
          subtitle: 'Get notified when new orders are placed',
          icon: Icons.shopping_bag_outlined,
          value: _orderAlerts,
          onChanged: (v) => setState(() => _orderAlerts = v),
        ),
        const Divider(height: 32),
        _buildToggleRow(
          title: 'Farmer Registration Alerts',
          subtitle: 'Notify when farmers apply for verification',
          icon: Icons.agriculture_outlined,
          value: _farmerRegistrationAlerts,
          onChanged: (v) => setState(() => _farmerRegistrationAlerts = v),
        ),
        const Divider(height: 32),
        _buildToggleRow(
          title: 'Content Report Alerts',
          subtitle: 'Alert when content is reported',
          icon: Icons.flag_outlined,
          value: _reportAlerts,
          onChanged: (v) => setState(() => _reportAlerts = v),
        ),
      ],
    );
  }

  Widget _buildPlatformSettings() {
    return Column(
      children: [
        _buildToggleRow(
          title: 'Allow New User Registration',
          subtitle: 'Enable/disable new customer sign-ups',
          icon: Icons.person_add_outlined,
          value: _newUserRegistration,
          onChanged: (v) => setState(() => _newUserRegistration = v),
          activeColor: _secondary,
        ),
        const Divider(height: 32),
        _buildToggleRow(
          title: 'Allow Farmer Registration',
          subtitle: 'Enable/disable new farmer applications',
          icon: Icons.eco_outlined,
          value: _farmerRegistration,
          onChanged: (v) => setState(() => _farmerRegistration = v),
          activeColor: _secondary,
        )
      ],
    );
  }

  Widget _buildDangerZone() {
    return Column(
      children: [
        _buildToggleRow(
          title: 'Maintenance Mode',
          subtitle: 'Temporarily disable platform access for users',
          icon: Icons.build_circle_outlined,
          value: _maintenanceMode,
          onChanged: (v) => _confirmMaintenanceMode(v),
          activeColor: _danger,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.cleaning_services_rounded, size: 18),
                label: const Text('Clear Cache'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _warning,
                  side: BorderSide(color: _warning.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Export System Data'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _secondary,
                  side: BorderSide(color: _secondary.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? activeColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _muted, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _text,
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
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: activeColor ?? _primary,
          activeTrackColor: (activeColor ?? _primary).withOpacity(0.3),
        ),
      ],
    );
  }

  void _confirmMaintenanceMode(bool enable) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(enable ? 'Enable Maintenance Mode?' : 'Disable Maintenance Mode?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
          enable ? 'This will prevent all users from accessing the platform until disabled.' : 'This will restore normal platform access for everyone.',
          style: GoogleFonts.inter(fontSize: 14, color: _muted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() => _maintenanceMode = enable);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: enable ? _danger : _primary, foregroundColor: Colors.white),
            child: Text(enable ? 'Enable' : 'Disable'),
          ),
        ],
      ),
    );
  }
}
