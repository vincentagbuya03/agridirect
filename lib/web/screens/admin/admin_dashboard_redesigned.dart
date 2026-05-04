import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/admin/admin_service.dart';
import '../../../shared/services/auth/auth_service.dart';

import 'admin_ui.dart';
import 'admin_users_tab.dart';
import 'admin_farmers_tab.dart';
import 'admin_products_tab.dart';
import 'admin_moderation_tab.dart';
import 'admin_content_tab.dart';
import 'admin_logs_tab.dart';
import 'admin_announcements_tab.dart';
import '../../../shared/widgets/brand_logo.dart';

class AdminDashboardRedesigned extends StatefulWidget {
  final VoidCallback onLogout;

  const AdminDashboardRedesigned({super.key, required this.onLogout});

  @override
  State<AdminDashboardRedesigned> createState() =>
      _AdminDashboardRedesignedState();
}

class _AdminDashboardRedesignedState extends State<AdminDashboardRedesigned> {
  int _selectedIndex = 0;
  final AuthService _authService = AuthService();
  final AdminService _adminService = AdminService();

  Map<String, dynamic> _counts = {
    'farmers': 0,
    'users': 0,
    'products': 0,
    'orders': 0,
    'pending': 0,
    'revenue': 0.0,
  };

  List<Map<String, dynamic>> _activity = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text(
          'Are you sure you want to log out of the admin panel?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      widget.onLogout();
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      setState(() => _isLoading = true);

      final counts = await _adminService.getDashboardCounts();
      final activity = await _adminService.getDashboardActivity();

      if (mounted) {
        setState(() {
          _counts = {
            'farmers': counts['total_farmers'] ?? 0,
            'users': counts['total_users'] ?? 0,
            'products': counts['total_products'] ?? 0,
            'orders': counts['total_orders'] ?? 0,
            'pending': counts['pending_verifications'] ?? 0,
            'revenue': counts['total_revenue'] ?? 0.0,
          };
          _activity = activity;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 1100;

    return Scaffold(
      backgroundColor: AdminUi.background,
      drawer: isMobile ? _buildSidebar(width) : null,
      body: Row(
        children: [
          if (!isMobile) _buildSidebar(width),
          Expanded(
            child: Column(
              children: [
                _buildTopHeader(isMobile),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 32,
                    ),
                    child: _buildContent(),
                  ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'The AgriDirect Curator';
      case 1:
        return 'Farmer Management';
      case 2:
        return 'Customer Management';
      case 3:
        return 'Product Catalog';
      case 4:
        return 'The AgriDirect Curator';
      case 5:
        return 'The AgriDirect Curator';
      case 6:
        return 'System Activity Logs';
      case 7:
        return 'Announcements';
      case 8:
        return 'System Settings';
      default:
        return 'The AgriDirect Curator';
    }
  }

  String _getSearchHint() {
    switch (_selectedIndex) {
      case 0:
        return 'Search arboretum data...';
      case 1:
        return 'Search by name or farm...';
      case 4:
        return 'Search curated content...';
      case 5:
        return 'Search moderation logs...';
      case 6:
        return 'Search activity logs...';
      case 7:
        return 'Search announcements...';
      default:
        return 'Search arboretum data...';
    }
  }

  Widget _buildTopHeader(bool isMobile) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      color: Colors.white,
      child: Row(
        children: [
          if (isMobile)
            Builder(
              builder: (context) => IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
          // Contextual page title
          Text(
            _getPageTitle(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AdminUi.textPrimary,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: TextField(
                decoration: AdminUi.inputDecoration(
                  hintText: _getSearchHint(),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: AdminUi.textMuted,
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          Stack(
            children: [
              const Icon(
                Icons.notifications_rounded,
                color: AdminUi.brand,
                size: 24,
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AdminUi.danger,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 32),
          Row(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _authService.userName.isEmpty
                        ? 'Administrator'
                        : _authService.userName,
                    style: AdminUi.label(
                      size: 14,
                      color: AdminUi.textPrimary,
                      weight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'System Curator',
                    style: AdminUi.label(size: 11, color: AdminUi.textMuted),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              const CircleAvatar(
                radius: 20,
                backgroundColor: AdminUi.background,
                child: Icon(Icons.person_outline_rounded, color: AdminUi.brand),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(double width) {
    return Container(
      width: 280,
      color: AdminUi.sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandLogo(size: BrandLogoSize.medium),
                Text(
                  'AgriDirect Admin v1.0',
                  style: AdminUi.label(
                    size: 11,
                    color: AdminUi.textMuted,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _buildNavItem(0, 'Dashboard', Icons.dashboard_rounded),
          _buildNavItem(1, 'Farmers', Icons.agriculture_rounded),
          _buildNavItem(2, 'Customers', Icons.people_rounded),
          _buildNavItem(3, 'Products', Icons.inventory_2_rounded),
          _buildNavItem(4, 'Content', Icons.article_rounded),
          _buildNavItem(5, 'Moderation', Icons.gavel_rounded),
          _buildNavItem(6, 'System Logs', Icons.history_rounded),
          _buildNavItem(7, 'Announcements', Icons.campaign_rounded),
          _buildNavItem(8, 'Settings', Icons.settings_rounded),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AdminUi.brand,
                borderRadius: AdminUi.radiusMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AdminUi.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'SYSTEM STATUS:',
                        style: AdminUi.label(
                          size: 11,
                          color: Colors.white,
                          weight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 22),
                    child: Text(
                      'OPERATIONAL',
                      style: AdminUi.label(
                        size: 13,
                        color: Colors.white,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 22),
                    child: Text(
                      'All platform services are running normally.',
                      style: AdminUi.label(
                        size: 10,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon) {
    final selected = _selectedIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            border: selected
                ? const Border(
                    right: BorderSide(color: AdminUi.brand, width: 4),
                  )
                : null,
            color: selected ? Colors.white : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? AdminUi.brand : AdminUi.textMuted,
                size: 20,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: AdminUi.label(
                  size: 14,
                  color: selected ? AdminUi.textPrimary : AdminUi.textSecondary,
                  weight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardView();
      case 1:
        return AdminFarmersTab(adminService: _adminService);
      case 2:
        return AdminUsersTab(adminService: _adminService);
      case 3:
        return AdminProductsTab(adminService: _adminService);
      case 4:
        return AdminContentTab(adminService: _adminService);
      case 5:
        return AdminModerationTab(adminService: _adminService);
      case 6:
        return AdminLogsTab(adminService: _adminService);
      case 7:
        return AdminAnnouncementsTab(adminService: _adminService);
      case 8:
        return const Center(child: Text('Settings'));
      default:
        return _buildDashboardView();
    }
  }

  Widget _buildDashboardView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminDashboardHeader(
          title: 'Overview',
          subtitle: 'Growth metrics and logistics for the AgriDirect platform.',
          actions: [
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Generating platform report...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              style: AdminUi.secondaryButton,
              child: const Text('Download Report'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _selectedIndex = 4);
              },
              style: AdminUi.primaryButton,
              child: const Text('Manage Assets'),
            ),
          ],
        ),
        _isLoading
            ? const Padding(
                padding: EdgeInsets.all(100),
                child: Center(
                  child: CircularProgressIndicator(color: AdminUi.brand),
                ),
              )
            : Row(
                children: [
                  AdminMetricCard(
                    label: 'Total Revenue',
                    value: '₱${_counts['revenue']?.toStringAsFixed(0)}',
                    icon: Icons.payments_rounded,
                    trend: 'Realtime',
                  ),
                  const SizedBox(width: 24),
                  AdminMetricCard(
                    label: 'Active Farmers',
                    value: '${_counts['farmers']}',
                    icon: Icons.agriculture_rounded,
                    trend: 'Updated',
                  ),
                  const SizedBox(width: 24),
                  AdminMetricCard(
                    label: 'Total Products',
                    value: '${_counts['products']}',
                    icon: Icons.inventory_2_rounded,
                    badge: 'Catalog',
                  ),
                  const SizedBox(width: 24),
                  AdminMetricCard(
                    label: 'Pending Verifications',
                    value: '${_counts['pending']}',
                    icon: Icons.verified_user_rounded,
                    badge: _counts['pending'] > 0 ? 'Urgent' : null,
                  ),
                ],
              ),
        const SizedBox(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _buildChartCard()),
            const SizedBox(width: 24),
            Expanded(flex: 1, child: _buildAdminLogsCard()),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _buildPendingRegistrationsCard()),
            const SizedBox(width: 24),
            Expanded(flex: 1, child: _buildPlatformIntegrityCard()),
          ],
        ),
      ],
    );
  }

  Widget _buildChartCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: AdminUi.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sales Trends', style: AdminUi.title(size: 20)),
                  Text(
                    'Revenue performance across all platform categories.',
                    style: AdminUi.body(size: 13),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AdminUi.background,
                  borderRadius: AdminUi.radiusSm,
                ),
                child: Row(
                  children: ['30D', '90D', '1Y']
                      .map(
                        (t) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: t == '30D' ? Colors.white : null,
                            borderRadius: AdminUi.radiusSm,
                            boxShadow: t == '30D' ? AdminUi.shadowSm : null,
                          ),
                          child: Text(
                            t,
                            style: AdminUi.label(
                              size: 11,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          SizedBox(
            height: 200,
            width: double.infinity,
            child: CustomPaint(painter: WavePainter()),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children:
                [
                      _getShortDate(Duration(days: 28)),
                      _getShortDate(Duration(days: 21)),
                      _getShortDate(Duration(days: 14)),
                      _getShortDate(Duration(days: 7)),
                      'TODAY',
                    ]
                    .map(
                      (d) => Text(
                        d,
                        style: AdminUi.label(
                          size: 10,
                          color: AdminUi.textMuted,
                        ),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }

  String _getShortDate(Duration subtract) {
    final date = DateTime.now().subtract(subtract);
    final months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]}';
  }

  Widget _buildAdminLogsCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: AdminUi.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Admin Logs', style: AdminUi.title(size: 20)),
              InkWell(
                onTap: () => setState(() => _selectedIndex = 6),
                child: Text(
                  'VIEW ALL',
                  style: AdminUi.label(
                    size: 11,
                    color: AdminUi.brand,
                    weight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (_activity.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No recent activity',
                  style: AdminUi.body(color: AdminUi.textMuted),
                ),
              ),
            )
          else
            ..._activity.take(4).map((item) {
              final timeStr = item['time'] != null
                  ? DateTime.parse(
                      item['time'],
                    ).toLocal().toString().substring(11, 16)
                  : 'NOW';
              return _logItem(
                item['title'] ?? 'System Update',
                item['subtitle'] ?? 'No details available',
                '$timeStr TODAY',
                item['color'] ?? AdminUi.info,
              );
            }),
        ],
      ),
    );
  }

  Widget _logItem(String title, String desc, String time, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AdminUi.label(
                    size: 14,
                    color: AdminUi.textPrimary,
                    weight: FontWeight.w700,
                  ),
                ),
                Text(
                  desc,
                  style: AdminUi.body(size: 12, color: AdminUi.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: AdminUi.label(size: 10, color: AdminUi.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRegistrationsCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: AdminUi.cardDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pending Registrations', style: AdminUi.title(size: 20)),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AdminUi.brandSoft,
                  borderRadius: AdminUi.radiusFull,
                ),
                child: Text(
                  '4 New Today',
                  style: AdminUi.label(
                    size: 10,
                    color: AdminUi.brand,
                    weight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _adminService.getPendingFarmerRegistrations(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              final pending = snapshot.data ?? [];
              if (pending.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'All registrations processed',
                      style: AdminUi.body(color: AdminUi.textMuted),
                    ),
                  ),
                );
              }
              return Column(
                children: pending
                    .take(3)
                    .map(
                      (reg) => _registrationItem(
                        reg['full_name'] ?? reg['name'] ?? 'Applicant',
                        '${reg['farm_name'] ?? "New Farm"} • ${reg['specialty'] ?? "General"}',
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _registrationItem(String name, String farm) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminUi.sidebarBg,
        borderRadius: AdminUi.radiusMd,
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: AdminUi.border,
            child: Icon(Icons.person_rounded, color: AdminUi.textMuted),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AdminUi.label(
                    size: 14,
                    color: AdminUi.textPrimary,
                    weight: FontWeight.w700,
                  ),
                ),
                Text(
                  farm,
                  style: AdminUi.body(size: 12, color: AdminUi.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.visibility_outlined, size: 20),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {},
            style: AdminUi.primaryButton.copyWith(
              backgroundColor: WidgetStateProperty.all(AdminUi.brandDark),
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformIntegrityCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AdminUi.brandDark,
        borderRadius: AdminUi.radiusLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Platform Integrity',
            style: AdminUi.title(size: 20, color: Colors.white),
          ),
          Text(
            'Real-time health of the AgriDirect ecosystem nodes.',
            style: AdminUi.body(
              size: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 32),
          _integrityMetric('API UPTIME', '99.98%', true),
          const SizedBox(height: 32),
          _integrityMetric(
            'LOAD BALANCE',
            'Stable',
            false,
            badge: 'Nodes: 12 Active',
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _integrityMetric(
                  'DB QUERY SPEED',
                  '12ms',
                  false,
                  subtext: 'Optimal Range',
                ),
              ),
              Expanded(
                child: _integrityMetric(
                  'SECURITY HEALTH',
                  'No Risk',
                  false,
                  subtext: 'Last scan: 4m ago',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _integrityMetric(
    String label,
    String value,
    bool hasBar, {
    String? badge,
    String? subtext,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AdminUi.label(
            size: 10,
            color: Colors.white.withValues(alpha: 0.6),
            weight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AdminUi.display(
            context,
            size: 28,
            color: Colors.white,
            weight: FontWeight.w800,
          ),
        ),
        if (hasBar) ...[
          const SizedBox(height: 8),
          Container(
            height: 4,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AdminUi.success,
              borderRadius: AdminUi.radiusFull,
            ),
          ),
        ],
        if (badge != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: AdminUi.radiusSm,
            ),
            child: Text(
              badge,
              style: AdminUi.label(
                size: 10,
                color: Colors.white,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
        if (subtext != null) ...[
          const SizedBox(height: 4),
          Text(
            subtext,
            style: AdminUi.label(
              size: 10,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AdminUi.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '© 2024 The AgriDirect Curator. Admin Panel v1.0.42',
            style: AdminUi.label(size: 12, color: AdminUi.textMuted),
          ),
          Row(
            children: [
              Text(
                'DOCUMENTATION',
                style: AdminUi.label(
                  size: 11,
                  color: AdminUi.textSecondary,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 24),
              Text(
                'SUPPORT',
                style: AdminUi.label(
                  size: 11,
                  color: AdminUi.textSecondary,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 24),
              InkWell(
                onTap: _confirmLogout,
                borderRadius: AdminUi.radiusSm,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'LOG OUT',
                    style: AdminUi.label(
                      size: 11,
                      color: AdminUi.danger,
                      weight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AdminUi.brand
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final path = Path();
    path.moveTo(0, size.height * 0.8);
    path.quadraticBezierTo(
      size.width * 0.2,
      size.height * 0.9,
      size.width * 0.35,
      size.height * 0.6,
    );
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.3,
      size.width * 0.65,
      size.height * 0.7,
    );
    path.quadraticBezierTo(
      size.width * 0.8,
      size.height * 1.0,
      size.width,
      size.height * 0.4,
    );

    canvas.drawPath(path, paint);

    // Points
    final pointPaint = Paint()..color = AdminUi.brandDark;
    canvas.drawCircle(
      Offset(size.width * 0.35, size.height * 0.6),
      4,
      pointPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.65, size.height * 0.7),
      4,
      pointPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.4),
      4,
      pointPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
