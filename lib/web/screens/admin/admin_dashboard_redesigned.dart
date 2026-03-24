import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/admin_service.dart';
import '../../../shared/services/auth_service.dart';
import 'admin_analytics_tab.dart';
import 'admin_users_tab.dart';
import 'admin_products_tab.dart';
import 'admin_orders_tab.dart';
import 'admin_moderation_tab.dart';
import 'admin_farmers_tab.dart';
import 'admin_categories_tab.dart';
import 'admin_logs_tab.dart';
import 'admin_settings_tab.dart';

/// Modern Admin Dashboard with Sidebar Navigation
class AdminDashboardRedesigned extends StatefulWidget {
  final VoidCallback onLogout;

  const AdminDashboardRedesigned({super.key, required this.onLogout});

  @override
  State<AdminDashboardRedesigned> createState() =>
      _AdminDashboardRedesignedState();
}

// Modern plain white theme color scheme
const Color _primary = Color(0xFF10B981);
const Color _primaryLight = Color(0xFF34D399);
const Color _info = Color(0xFF3B82F6);
const Color _warning = Color(0xFFF59E0B);
const Color _danger = Color(0xFFEF4444);
const Color _background = Color(0xFFFAFAFA); // Lighter background
const Color _surface = Colors.white;
const Color _card = Colors.white;
const Color _cardHover = Color(0xFFF1F5F9);
const Color _border = Color(0xFFE2E8F0);
const Color _text = Color(0xFF1E293B); // Darker text for white theme
const Color _textSecondary = Color(0xFF64748B);
const Color _muted = Color(0xFF94A3B8);

class _AdminDashboardRedesignedState extends State<AdminDashboardRedesigned> {
  int _selectedIndex = 0;
  final _adminService = AdminService();
  final _authService = AuthService();
  bool _isSidebarCollapsed = false;
  Map<String, int> _dashboardCounts = {};

  final List<_NavSection> _navSections = [
    _NavSection(
      title: 'OVERVIEW',
      items: [
        _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', index: 0),
        _NavItem(icon: Icons.analytics_rounded, label: 'Analytics', index: 1),
      ],
    ),
    _NavSection(
      title: 'MANAGEMENT',
      items: [
        _NavItem(
          icon: Icons.people_rounded,
          label: 'Users',
          index: 2,
          badgeKey: 'total_users',
        ),
        _NavItem(
          icon: Icons.agriculture_rounded,
          label: 'Farmers',
          index: 3,
          badgeKey: 'pending_verifications',
          badgeColor: _warning,
        ),
        _NavItem(icon: Icons.inventory_2_rounded, label: 'Products', index: 4),
        _NavItem(icon: Icons.shopping_bag_rounded, label: 'Orders', index: 5),
      ],
    ),
    _NavSection(
      title: 'CONFIGURATION',
      items: [
        _NavItem(icon: Icons.category_rounded, label: 'Categories', index: 6),
        _NavItem(
          icon: Icons.report_rounded,
          label: 'Reports',
          index: 7,
          badgeKey: 'pending_reports',
          badgeColor: _danger,
        ),
      ],
    ),
    _NavSection(
      title: 'SYSTEM',
      items: [
        _NavItem(icon: Icons.history_rounded, label: 'Activity Logs', index: 8),
        _NavItem(icon: Icons.settings_rounded, label: 'Settings', index: 9),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboardCounts();
  }

  Future<void> _loadDashboardCounts() async {
    final counts = await _adminService.getDashboardCounts();
    if (mounted) {
      setState(() => _dashboardCounts = counts);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 1024;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;

    return Scaffold(
      backgroundColor: _background,
      drawer: isMobile ? _buildDrawer() : null,
      body: Row(
        children: [
          // Sidebar - Desktop only
          if (!isMobile) _buildSidebar(isTablet),
          // Main Content
          Expanded(
            child: Column(
              children: [
                _buildTopBar(isMobile),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _surface,
      child: _buildSidebarContent(false),
    );
  }

  Widget _buildSidebar(bool isTablet) {
    final sidebarWidth = _isSidebarCollapsed
        ? 80.0
        : (isTablet ? 240.0 : 280.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: _surface,
        border: Border(right: BorderSide(color: _border)),
      ),
      child: _buildSidebarContent(isTablet),
    );
  }

  Widget _buildSidebarContent(bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo/Header
        _buildSidebarHeader(),
        Container(height: 1, color: _border),
        // Navigation
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              for (final section in _navSections) ...[
                if (!_isSidebarCollapsed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
                    child: Text(
                      section.title,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                for (final item in section.items) _buildNavItem(item),
              ],
            ],
          ),
        ),
        Container(height: 1, color: _border.withValues(alpha: 0.1)),
        // User Profile Footer
        _buildUserProfile(),
      ],
    );
  }

  Widget _buildSidebarHeader() {
    return Padding(
      padding: EdgeInsets.all(_isSidebarCollapsed ? 16 : 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primary, _primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _primary.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.eco_rounded, color: Colors.white, size: 24),
          ),
          if (!_isSidebarCollapsed) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AgriDirect',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _text,
                    ),
                  ),
                  Text(
                    'Admin Console',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: _muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () =>
                  setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
              icon: Icon(
                _isSidebarCollapsed
                    ? Icons.chevron_right_rounded
                    : Icons.chevron_left_rounded,
                color: _muted,
                size: 20,
              ),
              tooltip: _isSidebarCollapsed ? 'Expand' : 'Collapse',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavItem(_NavItem item) {
    final isSelected = _selectedIndex == item.index;
    final badge = item.badgeKey != null
        ? _dashboardCounts[item.badgeKey]
        : null;
    final showBadge = badge != null && badge > 0;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _isSidebarCollapsed ? 12 : 16,
        vertical: 2,
      ),
      child: Tooltip(
        message: _isSidebarCollapsed ? item.label : '',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _selectedIndex = item.index),
            borderRadius: BorderRadius.circular(12),
            hoverColor: _cardHover.withValues(alpha: 0.1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: _isSidebarCollapsed ? 12 : 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? _primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? _primary.withValues(alpha: 0.1)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    size: 22,
                    color: isSelected ? _primary : _muted,
                  ),
                  if (!_isSidebarCollapsed) ...[
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        item.label,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected ? _primary : _textSecondary,
                        ),
                      ),
                    ),
                    if (showBadge)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (item.badgeColor ?? _primary).withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$badge',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: item.badgeColor ?? _primary,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserProfile() {
    return Padding(
      padding: EdgeInsets.all(_isSidebarCollapsed ? 12 : 16),
      child: _isSidebarCollapsed
          ? Center(child: _buildAvatar())
          : Row(
              children: [
                _buildAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _authService.userName,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Administrator',
                        style: GoogleFonts.inter(fontSize: 11, color: _muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  color: _danger,
                  tooltip: 'Logout',
                ),
              ],
            ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, _primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          _authService.userName.isNotEmpty
              ? _authService.userName[0].toUpperCase()
              : 'A',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            children: [
              if (isMobile)
                IconButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu_rounded, color: _text),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getCurrentSectionName(),
                      style: GoogleFonts.inter(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: _text,
                      ),
                    ),
                    Text(
                      _getCurrentSectionDescription(),
                      style: GoogleFonts.inter(fontSize: 13, color: _muted),
                    ),
                  ],
                ),
              ),
              if (!isMobile) ...[
                // Search Bar
                Container(
                  width: 300,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Icon(Icons.search_rounded, color: _muted, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          style: GoogleFonts.inter(color: _text, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search...',
                            hintStyle: GoogleFonts.inter(
                              color: _muted,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: _border,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '/',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
              ],
              // Notification Bell
              _buildIconButton(
                Icons.notifications_outlined,
                badge: _dashboardCounts['pending_reports'] ?? 0,
              ),
              const SizedBox(width: 8),
              // Refresh Button
              _buildIconButton(
                Icons.refresh_rounded,
                onTap: _loadDashboardCounts,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, {int badge = 0, VoidCallback? onTap}) {
    return Stack(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Icon(icon, color: _muted, size: 20),
            ),
          ),
        ),
        if (badge > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: _danger,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: _surface, width: 2),
              ),
              child: Center(
                child: Text(
                  badge > 9 ? '9+' : '$badge',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0: // Dashboard Overview
        return _buildDashboardOverview();
      case 1: // Analytics
        return AdminAnalyticsTab(adminService: _adminService);
      case 2: // Users
        return AdminUsersTab(adminService: _adminService);
      case 3: // Farmers
        return AdminFarmersTab(adminService: _adminService);
      case 4: // Products
        return AdminProductsTab(adminService: _adminService);
      case 5: // Orders
        return AdminOrdersTab(adminService: _adminService);
      case 6: // Categories
        return AdminCategoriesTab(adminService: _adminService);
      case 7: // Reports/Moderation
        return AdminModerationTab(adminService: _adminService);
      case 8: // Activity Logs
        return AdminLogsTab(adminService: _adminService);
      case 9: // Settings
        return AdminSettingsTab(adminService: _adminService);
      default:
        return AdminAnalyticsTab(adminService: _adminService);
    }
  }

  /// Dashboard Overview - Quick summary view
  Widget _buildDashboardOverview() {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      color: _background,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Banner
            _buildWelcomeBanner(),
            const SizedBox(height: 24),
            // Quick Stats Grid
            GridView.count(
              crossAxisCount: isMobile ? 2 : 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.2,
              children: [
                _buildStatCard(
                  label: 'Total Users',
                  value: _dashboardCounts['total_users']?.toString() ?? '0',
                  icon: Icons.people_rounded,
                  color: _info,
                  trend: '+12%',
                ),
                _buildStatCard(
                  label: 'Active Farmers',
                  value: _dashboardCounts['active_farmers']?.toString() ?? '0',
                  icon: Icons.agriculture_rounded,
                  color: _primary,
                  trend: '+5%',
                ),
                _buildStatCard(
                  label: 'Product Listings',
                  value: _dashboardCounts['total_products']?.toString() ?? '0',
                  icon: Icons.inventory_2_rounded,
                  color: _warning,
                  trend: '+18%',
                ),
                _buildStatCard(
                  label: 'Total Orders',
                  value: _dashboardCounts['total_orders']?.toString() ?? '0',
                  icon: Icons.shopping_bag_rounded,
                  color: _danger,
                  trend: '-2%',
                ),
              ],
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending Actions',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _text,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildAlertCard(
                        title: 'Farmer Verifications',
                        subtitle:
                            'Review internal applications for certification',
                        count: _dashboardCounts['pending_verifications'] ?? 0,
                        color: _warning,
                        icon: Icons.verified_user_rounded,
                        onTap: () => setState(() => _selectedIndex = 3),
                      ),
                      const SizedBox(height: 12),
                      _buildAlertCard(
                        title: 'System Reports',
                        subtitle: 'Moderate reported content and violations',
                        count: _dashboardCounts['pending_reports'] ?? 0,
                        color: _danger,
                        icon: Icons.bug_report_rounded,
                        onTap: () => setState(() => _selectedIndex = 7),
                      ),
                    ],
                  ),
                ),
                if (!isMobile) const SizedBox(width: 24),
                if (!isMobile) Expanded(child: _buildPlatformHealth()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _text.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.eco_rounded,
              size: 140,
              color: _primary.withValues(alpha: 0.05),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good ${_getTimeGreeting()}, ${_authService.userName}!',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Welcome back to the AgriDirect administrative console. Here\'s what\'s happening with your marketplace today.',
                style: GoogleFonts.inter(fontSize: 14, color: _textSecondary),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _buildBannerStat(
                    'Server Status',
                    'Operational',
                    Icons.dns_rounded,
                  ),
                  const SizedBox(width: 24),
                  _buildBannerStat(
                    'Database',
                    'Optimized',
                    Icons.storage_rounded,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBannerStat(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _border),
          ),
          child: Icon(icon, size: 16, color: _primary),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, color: _textSecondary),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _text,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  Widget _buildPlatformHealth() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'System Health',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _text,
                ),
              ),
              const Icon(Icons.bolt_rounded, color: Colors.amber, size: 20),
            ],
          ),
          const SizedBox(height: 20),
          _buildHealthNode('Network Latency', '24ms', 0.95, _primary),
          const SizedBox(height: 16),
          _buildHealthNode('Error Rate', '0.01%', 0.05, _danger),
          const SizedBox(height: 16),
          _buildHealthNode('CPU Usage', '12%', 0.12, _info),
        ],
      ),
    );
  }

  Widget _buildHealthNode(
    String label,
    String value,
    double progress,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: _background,
            color: color,
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    String? trend,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _text.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (trend != null)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: (trend.startsWith('+') ? _primary : _danger)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  trend,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: trend.startsWith('+') ? _primary : _danger,
                  ),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: _textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard({
    required String title,
    required String subtitle,
    required int count,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  count.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: _muted),
            ],
          ),
        ),
      ),
    );
  }

  String _getCurrentSectionName() {
    for (final section in _navSections) {
      for (final item in section.items) {
        if (item.index == _selectedIndex) return item.label;
      }
    }
    return 'Dashboard';
  }

  String _getCurrentSectionDescription() {
    switch (_selectedIndex) {
      case 0:
        return 'Overview of your marketplace performance';
      case 1:
        return 'Detailed analytics and reports';
      case 2:
        return 'Manage all platform users';
      case 3:
        return 'Review and verify farmer applications';
      case 4:
        return 'Moderate and manage product listings';
      case 5:
        return 'Track and manage customer orders';
      case 6:
        return 'Manage product categories and units';
      case 7:
        return 'Handle reported content and violations';
      case 8:
        return 'View all administrative actions';
      case 9:
        return 'Configure system settings';
      default:
        return 'Manage your marketplace';
    }
  }

  void _handleLogout() {
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
                color: _danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout_rounded, color: _danger, size: 24),
            ),
            const SizedBox(width: 16),
            Text(
              'Logout',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: _text,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to logout from the admin console?',
          style: GoogleFonts.inter(color: _textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: _muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavSection {
  final String title;
  final List<_NavItem> items;

  _NavSection({required this.title, required this.items});
}

class _NavItem {
  final IconData icon;
  final String label;
  final int index;
  final String? badgeKey;
  final Color? badgeColor;

  _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    this.badgeKey,
    this.badgeColor,
  });
}
