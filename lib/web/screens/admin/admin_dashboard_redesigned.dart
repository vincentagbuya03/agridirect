import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../shared/services/admin/admin_service.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/utils/js_helper.dart';

import 'admin_ui.dart';
import 'admin_users_tab.dart';
import 'admin_farmers_tab.dart';
import 'admin_products_tab.dart';
import 'admin_moderation_tab.dart';
import 'admin_content_tab.dart';
import 'admin_logs_tab.dart';
import 'admin_announcements_tab.dart';
import 'admin_settings_tab.dart';
import 'admin_support_tab.dart';
import 'package:agridirect/shared/widgets/premium_confirm_dialog.dart';

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

  Map<String, dynamic> _metrics = {};
  List<Map<String, dynamic>> _activity = [];
  bool _isLoading = true;

  // Sales chart state
  String _selectedRange = '30D';
  List<FlSpot> _chartSpots = [];
  List<String> _chartDates = [];
  Map<String, dynamic> _salesSummary = {};
  bool _isChartLoading = false;
  int _dbLatency = 12;

  // Universal Search
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;
  Map<String, List<Map<String, dynamic>>> _searchResults = {
    'farmers': [],
    'users': [],
    'products': [],
    'orders': [],
  };
  OverlayEntry? _searchOverlayEntry;
  final LayerLink _searchLayerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _removeSearchOverlay();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _removeSearchOverlay();
      setState(() {
        _searchResults = {'farmers': [], 'users': [], 'products': [], 'orders': []};
      });
      return;
    }

    _performSearch(query);
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    try {
      final results = await _adminService.searchPlatformUniversal(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
      _showSearchOverlay();
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _showSearchOverlay() {
    _removeSearchOverlay();
    _searchOverlayEntry = _createSearchOverlay();
    Overlay.of(context).insert(_searchOverlayEntry!);
  }

  void _removeSearchOverlay() {
    _searchOverlayEntry?.remove();
    _searchOverlayEntry = null;
  }

  OverlayEntry _createSearchOverlay() {
    final screenWidth = MediaQuery.of(context).size.width;
    final overlayWidth = (screenWidth - 32).clamp(280.0, 520.0);

    return OverlayEntry(
      builder: (context) => Positioned(
        width: overlayWidth,
        child: CompositedTransformFollower(
          link: _searchLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 48),
          child: Material(
            elevation: 12,
            borderRadius: AdminUi.radiusMd,
            color: Colors.white,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 400),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AdminUi.radiusMd,
                border: Border.all(color: AdminUi.border),
                boxShadow: AdminUi.shadowMd,
              ),
              child: _buildSearchResultsList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultsList() {
    final farmers = _searchResults['farmers'] ?? [];
    final users = _searchResults['users'] ?? [];
    final products = _searchResults['products'] ?? [];
    final orders = _searchResults['orders'] ?? [];

    final hasResults = farmers.isNotEmpty || users.isNotEmpty || products.isNotEmpty || orders.isNotEmpty;

    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AdminUi.brand),
        ),
      );
    }

    if (!hasResults) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No matching records found for "${_searchController.text.trim()}"',
            style: AdminUi.body(color: AdminUi.textMuted),
          ),
        ),
      );
    }

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (farmers.isNotEmpty) ...[
          _searchSectionHeader('FARMERS', Icons.agriculture_rounded),
          ...farmers.map((f) => _searchItem(
                title: f['farm_name'] ?? 'Farm',
                subtitle: f['specialty'] ?? 'General Crops',
                icon: Icons.agriculture_rounded,
                color: AdminUi.brand,
                onTap: () {
                  _removeSearchOverlay();
                  setState(() => _selectedIndex = 1);
                },
              )),
        ],
        if (products.isNotEmpty) ...[
          _searchSectionHeader('PRODUCTS', Icons.inventory_2_rounded),
          ...products.map((p) => _searchItem(
                title: p['title'] ?? 'Product',
                subtitle: '₱${p['price'] ?? 0} • ${p['category_name'] ?? "Produce"}',
                icon: Icons.inventory_2_rounded,
                color: AdminUi.brandSecondary,
                onTap: () {
                  _removeSearchOverlay();
                  setState(() => _selectedIndex = 3);
                },
              )),
        ],
        if (orders.isNotEmpty) ...[
          _searchSectionHeader('ORDERS', Icons.receipt_long_rounded),
          ...orders.map((o) => _searchItem(
                title: 'Order #${o['order_id']}',
                subtitle: '₱${o['total_amount'] ?? 0} • ${(o['status'] ?? "PENDING").toString().toUpperCase()}',
                icon: Icons.receipt_long_rounded,
                color: AdminUi.info,
                onTap: () {
                  _removeSearchOverlay();
                  setState(() => _selectedIndex = 6);
                },
              )),
        ],
        if (users.isNotEmpty) ...[
          _searchSectionHeader('CUSTOMERS', Icons.people_rounded),
          ...users.map((u) => _searchItem(
                title: u['name'] ?? 'User',
                subtitle: u['email'] ?? u['phone'] ?? 'Customer',
                icon: Icons.person_rounded,
                color: AdminUi.warning,
                onTap: () {
                  _removeSearchOverlay();
                  setState(() => _selectedIndex = 2);
                },
              )),
        ],
      ],
    );
  }

  Widget _searchSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: AdminUi.textMuted),
          const SizedBox(width: 6),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AdminUi.textMuted,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
      title: Text(title, style: AdminUi.label(size: 13, weight: FontWeight.w700)),
      subtitle: Text(subtitle, style: AdminUi.body(size: 11, color: AdminUi.textMuted)),
      onTap: onTap,
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => const PremiumConfirmDialog(
        title: 'Confirm Logout',
        content: 'Are you sure you want to log out of the admin panel?',
      ),
    );

    if (shouldLogout == true) {
      widget.onLogout();
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      setState(() => _isLoading = true);

      final stopwatch = Stopwatch()..start();
      final metrics = await _adminService.getExecutiveDashboardMetrics();
      final activity = await _adminService.getDashboardActivity();
      stopwatch.stop();
      final latency = stopwatch.elapsedMilliseconds;

      if (mounted) {
        setState(() {
          _metrics = metrics;
          _activity = activity;
          _dbLatency = latency > 0 ? (latency ~/ 2) : 14;
          _isLoading = false;
        });
      }
      await _loadChartData();
    } catch (e) {
      debugPrint('Error loading executive dashboard data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadChartData() async {
    try {
      setState(() => _isChartLoading = true);
      final analytics = await _adminService.getEnhancedSalesAnalytics(_selectedRange);

      final timeline = (analytics['timeline'] as List? ?? []);
      final List<FlSpot> spots = [];
      final List<String> dates = [];

      for (int i = 0; i < timeline.length; i++) {
        final entry = timeline[i];
        final amount = (entry['revenue'] as num?)?.toDouble() ?? 0.0;
        spots.add(FlSpot(i.toDouble(), amount));
        dates.add(entry['date']?.toString() ?? '');
      }

      if (mounted) {
        setState(() {
          _chartSpots = spots;
          _chartDates = dates;
          _salesSummary = analytics;
          _isChartLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading sales chart: $e');
      if (mounted) setState(() => _isChartLoading = false);
    }
  }

  void _triggerCsvDownload(String filename, String csvString) {
    if (kIsWeb) {
      final bytes = utf8.encode(csvString);
      final base64Content = base64Encode(bytes);
      evalJs('''
        (function() {
          const link = document.createElement('a');
          link.href = 'data:text/csv;base64,$base64Content';
          link.download = '$filename';
          document.body.appendChild(link);
          link.click();
          document.body.removeChild(link);
        })();
      ''');
    }
  }

  Future<void> _showExportDialog() async {
    final dateSlug = DateTime.now().toIso8601String().substring(0, 10);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AdminUi.radiusMd),
        title: Row(
          children: [
            const Icon(Icons.file_download_rounded, color: AdminUi.brand),
            const SizedBox(width: 10),
            Text('Export Platform Data', style: AdminUi.title(size: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select the export format and dataset to download cleanly formatted CSV tables:',
              style: AdminUi.body(size: 13, color: AdminUi.textSecondary),
            ),
            const SizedBox(height: 16),

            // 1. All-in-One Comprehensive Report
            _buildExportOptionTile(
              title: 'Comprehensive Executive Report',
              desc: '5-column aligned KPIs, Recent Orders, Farmer Directory, and Product Summary.',
              icon: Icons.analytics_rounded,
              color: AdminUi.brand,
              onTap: () async {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Generating Comprehensive Report...'), duration: Duration(seconds: 1)),
                );
                final csv = await _adminService.generatePlatformCsvReport();
                _triggerCsvDownload('agridirect_executive_report_$dateSlug.csv', csv);
              },
            ),
            const SizedBox(height: 10),

            // 2. Orders Only
            _buildExportOptionTile(
              title: 'Orders Transaction Ledger',
              desc: 'Pure tabular order transactions with formatted dates, amounts, and reference codes.',
              icon: Icons.receipt_long_rounded,
              color: AdminUi.info,
              onTap: () async {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Generating Orders Ledger...'), duration: Duration(seconds: 1)),
                );
                final csv = await _adminService.generateOrdersOnlyCsv();
                _triggerCsvDownload('agridirect_orders_ledger_$dateSlug.csv', csv);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AdminUi.body(color: AdminUi.textMuted)),
          ),
        ],
      ),
    );
  }

  Widget _buildExportOptionTile({
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AdminUi.radiusSm,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AdminUi.background,
          borderRadius: AdminUi.radiusSm,
          border: Border.all(color: AdminUi.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AdminUi.label(size: 13, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(desc, style: AdminUi.body(size: 11, color: AdminUi.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AdminUi.textMuted),
          ],
        ),
      ),
    );
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
                    padding: EdgeInsets.symmetric(
                      horizontal: width < 768 ? 16 : (width < 1100 ? 24 : 40),
                      vertical: width < 768 ? 20 : 32,
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
        return 'Executive Command';
      case 1:
        return 'Farmer Management';
      case 2:
        return 'Customer Management';
      case 3:
        return 'Product Catalog';
      case 4:
        return 'Content Management';
      case 5:
        return 'Community Moderation';
      case 6:
        return 'System Activity Logs';
      case 7:
        return 'Push Studio & Weather Hub';
      case 8:
        return 'Support Tickets';
      case 9:
        return 'System Settings';
      default:
        return 'Executive Command';
    }
  }

  String _getSearchHint() {
    switch (_selectedIndex) {
      case 0:
        return 'Search platform, farmers, products, orders...';
      case 1:
        return 'Search by farmer name or farm...';
      case 4:
        return 'Search curated articles & guides...';
      case 5:
        return 'Search moderation flags & reports...';
      case 6:
        return 'Search system audit logs...';
      case 7:
        return 'Search campaigns & weather alerts...';
      case 8:
        return 'Search support tickets...';
      default:
        return 'Search platform, farmers, products, orders...';
    }
  }

  Widget _buildTopHeader(bool isMobile) {
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 860;
    final isVeryNarrow = width < 660;

    final pendingCount = (_metrics['pending_verifications'] as num? ?? 0) +
        (_metrics['pending_reports'] as num? ?? 0);

    return Container(
      height: 80,
      padding: EdgeInsets.symmetric(horizontal: width < 768 ? 16 : (width < 1100 ? 24 : 40)),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AdminUi.border)),
      ),
      child: Row(
        children: [
          if (isMobile)
            Builder(
              builder: (context) => IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
          if (!isVeryNarrow) ...[
            Text(
              _getPageTitle(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AdminUi.textPrimary,
              ),
            ),
            const SizedBox(width: 16),
          ],

          // Universal Search Bar
          Expanded(
            child: CompositedTransformTarget(
              link: _searchLayerLink,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: AdminUi.inputDecoration(
                    hintText: isVeryNarrow ? 'Search platform...' : _getSearchHint(),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: AdminUi.textMuted,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              _removeSearchOverlay();
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Notification Center Bell (Interactive)
          PopupMenuButton<String>(
            tooltip: 'Admin Alerts & Notifications',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(borderRadius: AdminUi.radiusMd),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AdminUi.background,
                    borderRadius: AdminUi.radiusSm,
                  ),
                  child: const Icon(
                    Icons.notifications_rounded,
                    color: AdminUi.brand,
                    size: 20,
                  ),
                ),
                if (pendingCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AdminUi.danger,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Action Items', style: AdminUi.title(size: 14)),
                    Text('$pendingCount Pending', style: AdminUi.label(size: 11, color: AdminUi.textMuted)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'farmers',
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.verified_user_rounded, color: AdminUi.warning),
                  title: Text('${_metrics["pending_verifications"] ?? 0} Farmer Verifications'),
                  subtitle: const Text('Tap to review applications'),
                ),
              ),
              PopupMenuItem(
                value: 'moderation',
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.gavel_rounded, color: AdminUi.danger),
                  title: Text('${_metrics["pending_reports"] ?? 0} Reported Items'),
                  subtitle: const Text('Tap to moderate reported content'),
                ),
              ),
              PopupMenuItem(
                value: 'weather',
                child: const ListTile(
                  dense: true,
                  leading: Icon(Icons.cloud_sync_rounded, color: AdminUi.brandSecondary),
                  title: Text('Weather Engine Active'),
                  subtitle: Text('pg_cron running 24/7 background scans'),
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'farmers') setState(() => _selectedIndex = 1);
              if (value == 'moderation') setState(() => _selectedIndex = 5);
              if (value == 'weather') setState(() => _selectedIndex = 7);
            },
          ),
          SizedBox(width: isNarrow ? 12 : 20),

          // Admin Profile Pill
          Row(
            children: [
              if (!isNarrow) ...[
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _authService.userName.isEmpty
                          ? 'Administrator'
                          : _authService.userName,
                      style: AdminUi.label(
                        size: 13,
                        weight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Executive Operations',
                      style: AdminUi.label(
                        size: 10,
                        color: AdminUi.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
              ],
              CircleAvatar(
                radius: 18,
                backgroundColor: AdminUi.brandSoft,
                backgroundImage: _authService.userAvatarUrl.isNotEmpty
                    ? NetworkImage(_authService.userAvatarUrl)
                    : null,
                child: _authService.userAvatarUrl.isEmpty
                    ? const Icon(Icons.admin_panel_settings_rounded, color: AdminUi.brand, size: 18)
                    : null,
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
      decoration: const BoxDecoration(
        color: AdminUi.sidebarBg,
        border: Border(right: BorderSide(color: AdminUi.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AdminUi.brand,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.eco_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AgriDirect',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AdminUi.brandDark,
                      ),
                    ),
                    Text(
                      'Executive Console',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AdminUi.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AdminUi.border),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  _buildNavItem(0, 'Dashboard', Icons.dashboard_rounded),
                  _buildNavItem(1, 'Farmers', Icons.agriculture_rounded),
                  _buildNavItem(2, 'Customers', Icons.people_rounded),
                  _buildNavItem(3, 'Products', Icons.inventory_2_rounded),
                  _buildNavItem(4, 'Content', Icons.article_rounded),
                  _buildNavItem(5, 'Moderation', Icons.gavel_rounded),
                  _buildNavItem(6, 'System Logs', Icons.history_rounded),
                  _buildNavItem(7, 'Push & Weather', Icons.campaign_rounded),
                  _buildNavItem(8, 'Support Tickets', Icons.support_agent_rounded),
                  _buildNavItem(9, 'Settings', Icons.settings_rounded),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AdminUi.border),
                  const SizedBox(height: 8),
                  // Log Out Navigation Item
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _confirmLogout,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.logout_rounded,
                              color: AdminUi.danger,
                              size: 20,
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Log Out',
                              style: AdminUi.label(
                                size: 13,
                                color: AdminUi.danger,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(16),
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
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AdminUi.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'SYSTEM STATUS: ACTIVE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'All platform services & weather engines online.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.8),
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
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
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
                  size: 13,
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
        return AdminSupportTab(adminService: _adminService);
      case 9:
        return const AdminSettingsTab();
      default:
        return _buildDashboardView();
    }
  }

  Widget _buildDashboardView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 640;
        final isTablet = width >= 640 && width < 1260;
        
        final double metricWidth;
        if (isMobile) {
          metricWidth = (width - 12) / 2;
        } else if (isTablet) {
          metricWidth = (width - 20) / 2;
        } else {
          metricWidth = (width - 48) / 4;
        }
        final stackPanels = width < 1160;

        final revenue = (_metrics['total_revenue'] as num? ?? 0.0).toDouble();
        final revenueGrowth = (_metrics['revenue_growth_pct'] as num? ?? 0.0).toDouble();
        final verifiedFarmers = _metrics['verified_farmers'] ?? 0;
        final totalFarmers = _metrics['total_farmers'] ?? 0;
        final activeProducts = _metrics['active_products'] ?? 0;
        final totalProducts = _metrics['total_products'] ?? 0;
        final outOfStock = _metrics['out_of_stock_products'] ?? 0;
        final pendingVerifications = _metrics['pending_verifications'] ?? 0;
        final completedOrders = _metrics['completed_orders'] ?? 0;
        final aov = (_metrics['avg_order_value'] as num? ?? 0.0).toDouble();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminDashboardHeader(
              title: 'Platform Overview',
              subtitle: 'Real-time transaction volume, logistics, and automated systems.',
              actions: [
                OutlinedButton.icon(
                  onPressed: _showExportDialog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdminUi.brand,
                    side: const BorderSide(color: Color(0xFFD3DFD7)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.file_download_outlined, size: 16),
                  label: Text('Export CSV', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _selectedIndex = 7),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminUi.brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.campaign_rounded, size: 16),
                  label: Text('Push & Weather Hub', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(80),
                child: Center(
                  child: CircularProgressIndicator(color: AdminUi.brand),
                ),
              )
            else
              Wrap(
                spacing: isMobile ? 12 : 16,
                runSpacing: isMobile ? 12 : 16,
                children: [
                  // 1. Gross Revenue
                  SizedBox(
                    width: metricWidth,
                    child: _buildClickableMetricCard(
                      label: 'GROSS REVENUE',
                      value: '₱${revenue.toStringAsFixed(0)}',
                      subtitle: '$completedOrders orders • ₱${aov.toStringAsFixed(0)} AOV',
                      icon: Icons.payments_rounded,
                      badgeText: revenueGrowth >= 0
                          ? '+${revenueGrowth.toStringAsFixed(1)}% 30d'
                          : '${revenueGrowth.toStringAsFixed(1)}% 30d',
                      badgeColor: revenueGrowth >= 0 ? AdminUi.success : AdminUi.danger,
                      onTap: () {},
                    ),
                  ),

                  // 2. Active Farmers
                  SizedBox(
                    width: metricWidth,
                    child: _buildClickableMetricCard(
                      label: 'FARMERS',
                      value: '$verifiedFarmers',
                      subtitle: '$verifiedFarmers Verified • $totalFarmers Total',
                      icon: Icons.agriculture_rounded,
                      badgeText: 'View Roster →',
                      badgeColor: AdminUi.brandSecondary,
                      onTap: () => setState(() => _selectedIndex = 1),
                    ),
                  ),

                  // 3. Marketplace Catalog
                  SizedBox(
                    width: metricWidth,
                    child: _buildClickableMetricCard(
                      label: 'CATALOG',
                      value: '$activeProducts',
                      subtitle: outOfStock > 0 ? '$outOfStock Restock alert' : '$totalProducts Total Listed',
                      icon: Icons.inventory_2_rounded,
                      badgeText: outOfStock > 0 ? '$outOfStock Restock' : 'Live',
                      badgeColor: outOfStock > 0 ? AdminUi.warning : AdminUi.info,
                      onTap: () => setState(() => _selectedIndex = 3),
                    ),
                  ),

                  // 4. Pending Actions Queue
                  SizedBox(
                    width: metricWidth,
                    child: _buildClickableMetricCard(
                      label: 'ACTION QUEUE',
                      value: '$pendingVerifications',
                      subtitle: '${_metrics["pending_reports"] ?? 0} Reported items',
                      icon: Icons.verified_user_rounded,
                      badgeText: pendingVerifications > 0 ? 'Review Now' : 'All Clear',
                      badgeColor: pendingVerifications > 0 ? AdminUi.danger : AdminUi.success,
                      onTap: () => setState(() => _selectedIndex = 1),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 24),

            // Middle Section: Sales Analytics + Admin Activity Stream
            stackPanels
                ? Column(
                    children: [
                      _buildEnhancedChartCard(),
                      const SizedBox(height: 20),
                      _buildAdminLogsCard(),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: _buildEnhancedChartCard()),
                      const SizedBox(width: 20),
                      Expanded(flex: 3, child: _buildAdminLogsCard()),
                    ],
                  ),

            const SizedBox(height: 24),

            // Lower Section: Pending Farmer Registrations + Real Operational Telemetry
            stackPanels
                ? Column(
                    children: [
                      _buildPendingRegistrationsCard(),
                      const SizedBox(height: 20),
                      _buildRealPlatformTelemetryCard(),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: _buildPendingRegistrationsCard()),
                      const SizedBox(width: 20),
                      Expanded(flex: 3, child: _buildRealPlatformTelemetryCard()),
                    ],
                  ),
          ],
        );
      },
    );
  }

  Widget _buildClickableMetricCard({
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 250;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.all(isCompact ? 14 : 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E9E4), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: isCompact ? 32 : 38,
                        height: isCompact ? 32 : 38,
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          icon,
                          size: isCompact ? 18 : 20,
                          color: badgeColor == AdminUi.brandSecondary ? AdminUi.brand : badgeColor,
                        ),
                      ),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: isCompact ? 9 : 11,
                              fontWeight: FontWeight.w800,
                              color: badgeColor == AdminUi.brandSecondary ? AdminUi.brandDark : badgeColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isCompact ? 12 : 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isCompact ? 9 : 10,
                          fontWeight: FontWeight.w800,
                          color: AdminUi.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isCompact ? 19 : 24,
                          fontWeight: FontWeight.w800,
                          color: AdminUi.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: isCompact ? 10 : 11,
                          color: AdminUi.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnhancedChartCard() {
    final periodRev = (_salesSummary['period_revenue'] as num? ?? 0.0).toDouble();
    final periodOrders = _salesSummary['period_orders'] ?? 0;
    final peakDate = _salesSummary['peak_date']?.toString() ?? '';
    final peakAmount = (_salesSummary['peak_amount'] as num? ?? 0.0).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 500;

        return Container(
          padding: EdgeInsets.all(isCompact ? 16 : 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E9E4), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Sales & Revenue Analytics', style: AdminUi.title(size: isCompact ? 16 : 18)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AdminUi.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'REAL-TIME',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AdminUi.success,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Transaction volume across agricultural produce categories.',
                        style: AdminUi.body(size: 11, color: AdminUi.textMuted),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AdminUi.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8E4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: ['7D', '30D', '90D', '1Y']
                          .map(
                            (t) => InkWell(
                              onTap: _isChartLoading
                                  ? null
                                  : () {
                                      setState(() => _selectedRange = t);
                                      _loadChartData();
                                    },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: t == _selectedRange ? Colors.white : null,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: t == _selectedRange
                                      ? const [
                                          BoxShadow(
                                            color: Color(0x0C000000),
                                            blurRadius: 4,
                                            offset: Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  t,
                                  style: AdminUi.label(
                                    size: 10,
                                    weight: FontWeight.w700,
                                    color: t == _selectedRange ? AdminUi.brand : AdminUi.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Period Highlights Row (Symmetrical 3-column row)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAF8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE6EDE8)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSummaryPill('PERIOD SALES', '₱${periodRev.toStringAsFixed(0)}'),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildSummaryPill('TOTAL ORDERS', '$periodOrders Orders'),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildSummaryPill(
                        'PEAK DAY',
                        peakAmount > 0 ? '₱${peakAmount.toStringAsFixed(0)} ($peakDate)' : 'None',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Chart Display
              SizedBox(
                height: isCompact ? 180 : 220,
                width: double.infinity,
                child: _isChartLoading
                    ? const Center(child: CircularProgressIndicator(color: AdminUi.brand))
                    : _chartSpots.isEmpty
                        ? Center(
                            child: Text(
                              'No completed transactions found for this time window.',
                              style: AdminUi.body(color: AdminUi.textMuted),
                            ),
                          )
                        : LineChart(
                            LineChartData(
                              minY: 0,
                              maxY: peakAmount > 0 ? peakAmount * 1.2 : 100,
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: peakAmount > 0 ? peakAmount / 3 : 25,
                                getDrawingHorizontalLine: (value) => FlLine(
                                  color: AdminUi.border.withValues(alpha: 0.4),
                                  strokeWidth: 1,
                                  dashArray: [4, 4],
                                ),
                              ),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: !isCompact,
                                    reservedSize: 36,
                                    interval: peakAmount > 0 ? peakAmount / 3 : 25,
                                    getTitlesWidget: (val, meta) {
                                      if (val == 0) return const SizedBox.shrink();
                                      final str = val >= 1000 ? '₱${(val / 1000).toStringAsFixed(0)}k' : '₱${val.toInt()}';
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: Text(
                                          str,
                                          style: GoogleFonts.inter(fontSize: 9, color: AdminUi.textMuted, fontWeight: FontWeight.w600),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 22,
                                    interval: (_chartSpots.length / (isCompact ? 3 : 5)).clamp(1, 10).toDouble(),
                                    getTitlesWidget: (val, meta) {
                                      final idx = val.toInt();
                                      if (idx >= 0 && idx < _chartDates.length) {
                                        final rawDate = _chartDates[idx];
                                        // Shorten e.g. "2026-07-28" to "7/28"
                                        final parts = rawDate.split('-');
                                        final display = parts.length >= 3 ? '${int.tryParse(parts[1]) ?? parts[1]}/${int.tryParse(parts[2]) ?? parts[2]}' : rawDate;
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Text(
                                            display,
                                            style: GoogleFonts.inter(fontSize: 9, color: AdminUi.textMuted, fontWeight: FontWeight.w600),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineTouchData: LineTouchData(
                                touchTooltipData: LineTouchTooltipData(
                                  getTooltipColor: (_) => AdminUi.brandDark,
                                  getTooltipItems: (touchedSpots) {
                                    return touchedSpots.map((spot) {
                                      final idx = spot.x.toInt();
                                      final date = idx < _chartDates.length ? _chartDates[idx] : '';
                                      return LineTooltipItem(
                                        '₱${spot.y.toStringAsFixed(0)}\n$date',
                                        GoogleFonts.plusJakartaSans(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      );
                                    }).toList();
                                  },
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: _chartSpots,
                                  isCurved: true,
                                  curveSmoothness: 0.18,
                                  preventCurveOverShooting: true,
                                  color: AdminUi.brand,
                                  barWidth: 3.0,
                                  isStrokeCapRound: true,
                                  dotData: FlDotData(
                                    show: true,
                                    checkToShowDot: (spot, barData) => spot.y == peakAmount && peakAmount > 0,
                                    getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                      radius: 4,
                                      color: Colors.white,
                                      strokeColor: AdminUi.brand,
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        AdminUi.brand.withValues(alpha: 0.22),
                                        AdminUi.brand.withValues(alpha: 0.0),
                                      ],
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
      },
    );
  }

  Widget _buildSummaryPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8E4)),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: AdminUi.textMuted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AdminUi.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminLogsCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E9E4), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Live Activity Stream', style: AdminUi.title(size: 16)),
              InkWell(
                onTap: () => setState(() => _selectedIndex = 6),
                child: Text(
                  'AUDIT LOGS →',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AdminUi.brand,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_activity.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Text(
                  'No recent activity recorded',
                  style: AdminUi.body(color: AdminUi.textMuted),
                ),
              ),
            )
          else
            ..._activity.take(4).map((item) {
              final timeStr = item['time'] != null
                  ? _formatRelativeTime(item['time'].toString())
                  : 'Just now';
              return _logItem(
                item['title'] ?? 'System Event',
                item['subtitle'] ?? 'Action executed',
                timeStr,
                item['color'] ?? AdminUi.info,
              );
            }),
        ],
      ),
    );
  }

  String _formatRelativeTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return 'Recent';
    }
  }

  Widget _logItem(String title, String desc, String time, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.bolt_rounded, color: color, size: 15),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AdminUi.label(
                    size: 12,
                    color: AdminUi.textPrimary,
                    weight: FontWeight.w700,
                  ),
                ),
                Text(
                  desc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminUi.body(size: 11, color: AdminUi.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style: GoogleFonts.inter(fontSize: 10, color: AdminUi.textMuted, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRegistrationsCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E9E4), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text('Pending Farmer Registrations', style: AdminUi.title(size: 16)),
              InkWell(
                onTap: () => setState(() => _selectedIndex = 1),
                child: Text(
                  'ALL APPLICANTS →',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AdminUi.brand,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _adminService.getPendingFarmerRegistrations(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(strokeWidth: 2, color: AdminUi.brand),
                  ),
                );
              }
              final pending = snapshot.data ?? [];
              if (pending.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAF8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE6EDE8)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, color: AdminUi.success, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'All farmer applications have been reviewed and approved.',
                          style: GoogleFonts.inter(fontSize: 12, color: AdminUi.textSecondary),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: pending.take(3).map((reg) => _registrationItem(reg)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _registrationItem(Map<String, dynamic> reg) {
    final name = reg['name'] ?? reg['full_name'] ?? 'Farmer Applicant';
    final farm = '${reg['farm_name'] ?? "New Farm"} • ${reg['specialty'] ?? "Organic Produce"}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 460;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAF8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE6EDE8)),
          ),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AdminUi.brandSoft,
                          child: const Icon(Icons.person_rounded, color: AdminUi.brand, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: AdminUi.label(size: 13, color: AdminUi.textPrimary, weight: FontWeight.w700),
                              ),
                              Text(
                                farm,
                                style: AdminUi.body(size: 11, color: AdminUi.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => setState(() => _selectedIndex = 1),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            side: const BorderSide(color: Color(0xFFD3DFD7)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Inspect', style: TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final regId = reg['registration_id']?.toString() ?? '';
                            if (regId.isEmpty) return;

                            final success = await _adminService.approveFarmerRegistration(registrationId: regId);
                            if (!mounted || !context.mounted) return;
                            if (success) {
                              _loadDashboardData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AdminUi.brand,
                                  content: Text('✅ Approved $name successfully!'),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminUi.brand,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Approve', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AdminUi.brandSoft,
                      child: const Icon(Icons.person_rounded, color: AdminUi.brand, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: AdminUi.label(size: 13, color: AdminUi.textPrimary, weight: FontWeight.w700),
                          ),
                          Text(
                            farm,
                            style: AdminUi.body(size: 11, color: AdminUi.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => setState(() => _selectedIndex = 1),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: const BorderSide(color: Color(0xFFD3DFD7)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Inspect', style: TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final regId = reg['registration_id']?.toString() ?? '';
                        if (regId.isEmpty) return;

                        final success = await _adminService.approveFarmerRegistration(registrationId: regId);
                        if (!mounted || !context.mounted) return;
                        if (success) {
                          _loadDashboardData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AdminUi.brand,
                              content: Text('✅ Approved $name successfully!'),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminUi.brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Approve', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildRealPlatformTelemetryCard() {
    final activeDevices = _metrics['active_devices_count'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF092B1D), Color(0xFF0E3D2A)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E523A), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Platform Telemetry',
                style: AdminUi.title(size: 16, color: Colors.white),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AdminUi.success.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AdminUi.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'HEALTHY',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AdminUi.success,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Live telemetry and cloud engine health status.',
            style: AdminUi.body(size: 11, color: Colors.white.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 20),
          _telemetryItem('DATABASE LATENCY', '${_dbLatency}ms', 'Supabase PostgreSQL round-trip'),
          const Divider(height: 20, color: Colors.white12),
          _telemetryItem('ACTIVE FCM DEVICES', '$activeDevices Devices', 'Push notification tokens'),
          const Divider(height: 20, color: Colors.white12),
          _telemetryItem('WEATHER CRON ENGINE', 'Active (6h)', 'OpenWeather real-time farm scans'),
        ],
      ),
    );
  }

  Widget _telemetryItem(String label, String value, String desc) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.5),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 768;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 20 : 40, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AdminUi.border)),
      ),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    InkWell(
                      onTap: _showDocumentationDialog,
                      child: Text('DOCUMENTATION', style: AdminUi.label(size: 11, color: AdminUi.textSecondary, weight: FontWeight.w700)),
                    ),
                    InkWell(
                      onTap: () => setState(() => _selectedIndex = 8),
                      child: Text('SUPPORT', style: AdminUi.label(size: 11, color: AdminUi.textSecondary, weight: FontWeight.w700)),
                    ),
                    InkWell(
                      onTap: _confirmLogout,
                      child: Text('LOG OUT', style: AdminUi.label(size: 11, color: AdminUi.danger, weight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '© 2026 AgriDirect Inc. Enterprise Administration Console',
                  textAlign: TextAlign.center,
                  style: AdminUi.label(size: 10, color: AdminUi.textMuted),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '© 2026 AgriDirect Inc. Enterprise Administration Console',
                  style: AdminUi.label(size: 11, color: AdminUi.textMuted),
                ),
                Row(
                  children: [
                    InkWell(
                      onTap: _showDocumentationDialog,
                      child: Text('DOCUMENTATION', style: AdminUi.label(size: 11, color: AdminUi.textSecondary, weight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 24),
                    InkWell(
                      onTap: () => setState(() => _selectedIndex = 8),
                      child: Text('SUPPORT', style: AdminUi.label(size: 11, color: AdminUi.textSecondary, weight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 24),
                    InkWell(
                      onTap: _confirmLogout,
                      child: Text('LOG OUT', style: AdminUi.label(size: 11, color: AdminUi.danger, weight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  void _showDocumentationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AdminUi.radiusMd),
        title: Text('AgriDirect Admin Documentation', style: AdminUi.title(size: 18)),
        content: Text(
          'AgriDirect Enterprise Console Documentation:\n\n'
          '• Push & Weather Hub: Run manual or scheduled weather-based push notifications.\n'
          '• Farmers & Verification: Review and approve farmer KYC and farm profiles.\n'
          '• Customers & Moderation: Manage accounts, permissions, and moderation reports.\n'
          '• Data Reports: Export live revenue and transaction data to CSV format.',
          style: AdminUi.body(size: 13),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: AdminUi.primaryButton,
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
