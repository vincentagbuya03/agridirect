import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/admin_service.dart';
import '../../../shared/services/auth_service.dart';

/// Admin Settings Tab - System configuration and preferences
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
  bool _lowStockAlerts = false;
  bool _maintenanceMode = false;
  bool _newUserRegistration = true;
  bool _farmerRegistration = true;

  static const Color _primary = Color(0xFF10B981);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _info = Color(0xFF3B82F6);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _card = Color(0xFF1E293B);
  static const Color _border = Color(0xFF334155);
  static const Color _muted = Color(0xFF64748B);
  static const Color _text = Color(0xFFF1F5F9);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      color: _dark,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            borderRadius: BorderRadius.circular(16),
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
          icon: Icons.email_rounded,
          value: _emailNotifications,
          onChanged: (v) => setState(() => _emailNotifications = v),
        ),
        const SizedBox(height: 16),
        _buildToggleRow(
          title: 'Push Notifications',
          subtitle: 'Get instant notifications in browser',
          icon: Icons.notifications_active_rounded,
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
          icon: Icons.shopping_bag_rounded,
          value: _orderAlerts,
          onChanged: (v) => setState(() => _orderAlerts = v),
        ),
        const SizedBox(height: 16),
        _buildToggleRow(
          title: 'Farmer Registration Alerts',
          subtitle: 'Notify when farmers apply for verification',
          icon: Icons.agriculture_rounded,
          value: _farmerRegistrationAlerts,
          onChanged: (v) => setState(() => _farmerRegistrationAlerts = v),
        ),
        const SizedBox(height: 16),
        _buildToggleRow(
          title: 'Content Report Alerts',
          subtitle: 'Alert when content is reported',
          icon: Icons.flag_rounded,
          value: _reportAlerts,
          onChanged: (v) => setState(() => _reportAlerts = v),
        ),
        const SizedBox(height: 16),
        _buildToggleRow(
          title: 'Low Stock Alerts',
          subtitle: 'Notify when products are running low',
          icon: Icons.inventory_rounded,
          value: _lowStockAlerts,
          onChanged: (v) => setState(() => _lowStockAlerts = v),
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
          icon: Icons.person_add_rounded,
          value: _newUserRegistration,
          onChanged: (v) => setState(() => _newUserRegistration = v),
          activeColor: _info,
        ),
        const SizedBox(height: 16),
        _buildToggleRow(
          title: 'Allow Farmer Registration',
          subtitle: 'Enable/disable new farmer applications',
          icon: Icons.eco_rounded,
          value: _farmerRegistration,
          onChanged: (v) => setState(() => _farmerRegistration = v),
          activeColor: _info,
        ),
      ],
    );
  }

  Widget _buildDangerZone() {
    return Column(
      children: [
        _buildToggleRow(
          title: 'Maintenance Mode',
          subtitle: 'Temporarily disable platform access for users',
          icon: Icons.build_rounded,
          value: _maintenanceMode,
          onChanged: (v) => _confirmMaintenanceMode(v),
          activeColor: _danger,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showClearCacheDialog(),
                icon: const Icon(Icons.cleaning_services_rounded, size: 18),
                label: const Text('Clear Cache'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _warning,
                  side: BorderSide(color: _warning.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showExportDataDialog(),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Export Data'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _info,
                  side: BorderSide(color: _info.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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
            color: _dark,
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
          inactiveThumbColor: _muted,
          inactiveTrackColor: _border,
        ),
      ],
    );
  }

  void _confirmMaintenanceMode(bool enable) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.warning_rounded, color: _danger, size: 24),
            ),
            const SizedBox(width: 16),
            Text(
              enable ? 'Enable Maintenance?' : 'Disable Maintenance?',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: _text,
              ),
            ),
          ],
        ),
        content: Text(
          enable
              ? 'This will prevent all users from accessing the platform. Only administrators will have access.'
              : 'This will restore normal access for all users.',
          style: GoogleFonts.inter(color: _muted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: _muted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _maintenanceMode = enable);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: enable ? _danger : _primary,
                  content: Text(
                    enable
                        ? 'Maintenance mode enabled'
                        : 'Maintenance mode disabled',
                    style: GoogleFonts.inter(color: Colors.white),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: enable ? _danger : _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              enable ? 'Enable' : 'Disable',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear Cache?',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _text),
        ),
        content: Text(
          'This will clear all cached data. The system will reload fresh data from the server.',
          style: GoogleFonts.inter(color: _muted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: _muted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: _primary,
                  content: Text(
                    'Cache cleared successfully',
                    style: GoogleFonts.inter(color: Colors.white),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _warning,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Clear',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showExportDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Export Data',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _text),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select data to export:',
              style: GoogleFonts.inter(color: _muted, fontSize: 14),
            ),
            const SizedBox(height: 16),
            _ExportOption(title: 'Users', icon: Icons.people_rounded),
            _ExportOption(title: 'Orders', icon: Icons.shopping_bag_rounded),
            _ExportOption(title: 'Products', icon: Icons.inventory_2_rounded),
            _ExportOption(title: 'Farmers', icon: Icons.agriculture_rounded),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: _muted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: _primary,
                  content: Text(
                    'Export started. You will be notified when ready.',
                    style: GoogleFonts.inter(color: Colors.white),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _info,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Export',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportOption extends StatefulWidget {
  final String title;
  final IconData icon;

  const _ExportOption({required this.title, required this.icon});

  @override
  State<_ExportOption> createState() => _ExportOptionState();
}

class _ExportOptionState extends State<_ExportOption> {
  bool _selected = true;

  static const Color _primary = Color(0xFF10B981);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _border = Color(0xFF334155);
  static const Color _muted = Color(0xFF64748B);
  static const Color _text = Color(0xFFF1F5F9);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _selected = !_selected),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _selected ? _primary.withOpacity(0.1) : _dark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _selected ? _primary.withOpacity(0.3) : _border,
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: _selected ? _primary : _muted, size: 20),
              const SizedBox(width: 12),
              Text(
                widget.title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _selected ? _text : _muted,
                ),
              ),
              const Spacer(),
              Icon(
                _selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: _selected ? _primary : _muted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
