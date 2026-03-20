import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/admin/admin_service.dart';
import '../../../shared/services/auth/auth_service.dart';
import 'admin_analytics_tab.dart';
import 'admin_users_tab.dart';
import 'admin_products_tab.dart';
import 'admin_orders_tab.dart';
import 'admin_moderation_tab.dart';
import 'admin_farmer_registrations_tab.dart';

/// Redesigned Admin Dashboard with Sidebar Navigation
class AdminDashboardRedesigned extends StatefulWidget {
  final VoidCallback onLogout;

  const AdminDashboardRedesigned({
    super.key,
    required this.onLogout,
  });

  @override
  State<AdminDashboardRedesigned> createState() =>
      _AdminDashboardRedesignedState();
}

class _AdminDashboardRedesignedState extends State<AdminDashboardRedesigned> {
  int _selectedIndex = 0;
  final _adminService = AdminService();
  final _authService = AuthService();

  // Color scheme matching the reference design
  static const Color _primary = Color(0xFF16A34A);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _dark = Color(0xFF1E293B);
  static const Color _darker = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _surface = Color(0xFF334155);

  final List<NavItem> _navItems = [
    NavItem(icon: Icons.dashboard, label: 'Overview', index: 0),
    NavItem(icon: Icons.people, label: 'User Directory', index: 1),
    NavItem(icon: Icons.shield, label: 'Product Moderation', index: 2),
    NavItem(icon: Icons.shopping_cart, label: 'Orders', index: 3),
    NavItem(icon: Icons.bar_chart, label: 'Sales Performance', index: 4),
    NavItem(icon: Icons.analytics, label: 'Governance', index: 5),
    NavItem(icon: Icons.agriculture, label: 'Farmer Applications', index: 6),
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 1024;

    return Scaffold(
      backgroundColor: _dark,
      body: Row(
        children: [
          // Sidebar
          if (!isMobile)
            Container(
              width: 280,
              color: _darker,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo/Header
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.agriculture,
                              color: _darker, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AGRIDIRECT',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                            Text(
                              'ENTERPRISE CONSOLE',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                color: _muted,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: _surface, height: 1),
                  // Navigation Sections
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      children: [
                        _buildNavSection('CORE', [
                          _navItems[0], // Overview
                        ]),
                        _buildNavSection('INVENTORY & USERS', [
                          _navItems[1], // Users
                          _navItems[2], // Products
                        ]),
                        _buildNavSection('ANALYTICS', [
                          _navItems[4], // Sales
                          _navItems[5], // Governance
                        ]),
                        _buildNavSection('APPLICATIONS', [
                          _navItems[6], // Farmer Applications
                        ]),
                      ],
                    ),
                  ),
                  const Divider(color: _surface, height: 1),
                  // User Profile Footer
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: _primary,
                          child: Text(
                            _authService.userName
                                    .substring(0, 1)
                                    .toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              color: _darker,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _authService.userName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Super Administrator',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: _muted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _handleLogout,
                            icon: const Icon(Icons.logout, size: 16),
                            label: Text(
                              'Logout',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _danger,
                              side: const BorderSide(color: _danger),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  color: _dark,
                  child: Row(
                    children: [
                      Text(
                        _getCurrentSectionName(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.notifications_outlined,
                                color: _muted, size: 18),
                            const SizedBox(width: 12),
                            Container(
                              width: 1,
                              height: 20,
                              color: _surface,
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.settings_outlined,
                                color: _muted, size: 18),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavSection(String title, List<NavItem> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _muted,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...items.map((item) => _buildNavItem(item)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildNavItem(NavItem item) {
    final isSelected = _selectedIndex == item.index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedIndex = item.index;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected ? _surface : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: _primary, width: 1)
                  : Border.all(color: Colors.transparent),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 18,
                  color: isSelected ? _primary : _muted,
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? _primary : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0: // Overview/Analytics
        return AdminAnalyticsTab(adminService: _adminService);
      case 1: // Users
        return AdminUsersTab(adminService: _adminService);
      case 2: // Products
        return AdminProductsTab(adminService: _adminService);
      case 3: // Orders
        return AdminOrdersTab(adminService: _adminService);
      case 4: // Sales Performance
        return AdminAnalyticsTab(adminService: _adminService);
      case 5: // Governance
        return AdminModerationTab(adminService: _adminService);
      case 6: // Farmer Applications
        return AdminFarmerRegistrationsTab(adminService: _adminService);
      default:
        return AdminAnalyticsTab(adminService: _adminService);
    }
  }

  String _getCurrentSectionName() {
    return _navItems
            .firstWhere(
              (item) => item.index == _selectedIndex,
              orElse: () => _navItems[0],
            )
            .label;
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _dark,
        title: Text(
          'Logout',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.plusJakartaSans(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                color: _muted,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onLogout();
            },
            child: Text(
              'Logout',
              style: GoogleFonts.plusJakartaSans(color: _danger),
            ),
          ),
        ],
      ),
    );
  }
}

class NavItem {
  final IconData icon;
  final String label;
  final int index;

  NavItem({
    required this.icon,
    required this.label,
    required this.index,
  });
}
