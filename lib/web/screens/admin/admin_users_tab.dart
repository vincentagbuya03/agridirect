import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/admin/admin_service.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'admin_ui.dart';

class AdminUsersTab extends StatefulWidget {
  final AdminService adminService;
  const AdminUsersTab({super.key, required this.adminService});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  late Future<List<Map<String, dynamic>>> _usersFuture;

  String _searchQuery = '';
  String _filterSegment = 'all'; // all, vip, active, new, dormant, suspended
  String _sortBy = 'spend'; // spend, orders, newest, oldest, name
  bool _piiMasked = false; // default false for admin operations
  late VoidCallback _dataRefreshListener;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dataRefreshListener = () {
      if (!mounted) return;
      _loadData();
    };
    widget.adminService.dataVersionListenable.addListener(_dataRefreshListener);
    _loadData();
  }

  @override
  void dispose() {
    widget.adminService.dataVersionListenable.removeListener(_dataRefreshListener);
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _usersFuture = widget.adminService.getEnhancedCustomersList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeroAndMetrics(),
        const SizedBox(height: 20),
        _buildMainDataContainer(),
        const SizedBox(height: 24),
        _buildBottomAnalytics(),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. HERO HEADER & 2x2 BUYER METRIC CARDS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHeroAndMetrics() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _usersFuture,
      builder: (context, snapshot) {
        final allUsers = snapshot.data ?? [];
        final buyers = allUsers.where((u) {
          final r = (u['role'] ?? u['role_name'] ?? 'customer').toString().toLowerCase();
          return r == 'customer';
        }).toList();

        final totalBuyers = buyers.length;
        double totalGmv = 0.0;
        int totalOrders = 0;
        int vipCount = 0;
        int new30d = 0;

        final now = DateTime.now();
        final last30d = now.subtract(const Duration(days: 30));

        for (var b in buyers) {
          final spent = ((b['total_spent'] as num?)?.toDouble() ?? 0.0);
          final orders = (b['orders_count'] as num? ?? 0).toInt();
          totalGmv += spent;
          totalOrders += orders;

          if (spent >= 1000 || orders >= 2) {
            vipCount++;
          }

          final createdStr = b['created_at']?.toString();
          if (createdStr != null) {
            final dt = DateTime.tryParse(createdStr);
            if (dt != null && dt.isAfter(last30d)) {
              new30d++;
            }
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminDashboardHeader(
              title: 'Buyer & Consumer Management',
              subtitle: 'Monitor registered shoppers, purchasing volume, lifetime value, and order history.',
              actions: [
                // Privacy Mode Toggle Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _piiMasked ? AdminUi.brandSoft : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _piiMasked ? AdminUi.brand.withValues(alpha: 0.3) : const Color(0xFFD3DFD7),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _piiMasked ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        size: 14,
                        color: _piiMasked ? AdminUi.brand : AdminUi.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Privacy Mode',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _piiMasked ? AdminUi.brand : AdminUi.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Transform.scale(
                        scale: 0.75,
                        child: Switch(
                          value: _piiMasked,
                          onChanged: (v) => setState(() => _piiMasked = v),
                          activeThumbColor: AdminUi.brand,
                          activeTrackColor: AdminUi.brandSecondary.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _loadData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminUi.brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: Text('Sync Data', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isMobile = width < 640;
                final isTablet = width >= 640 && width < 1100;
                final double metricWidth;
                if (isMobile) {
                  metricWidth = (width - 12) / 2;
                } else if (isTablet) {
                  metricWidth = (width - 16) / 2;
                } else {
                  metricWidth = (width - 48) / 4;
                }

                return Wrap(
                  spacing: isMobile ? 12 : 16,
                  runSpacing: isMobile ? 12 : 16,
                  children: [
                    SizedBox(
                      width: metricWidth,
                      child: _metricCard(
                        'TOTAL CONSUMERS',
                        '$totalBuyers',
                        Icons.shopping_bag_rounded,
                        '+$new30d (30d)',
                        null,
                        AdminUi.brand,
                      ),
                    ),
                    SizedBox(
                      width: metricWidth,
                      child: _metricCard(
                        'LIFETIME SPEND',
                        '₱${totalGmv.toStringAsFixed(0)}',
                        Icons.payments_rounded,
                        'Total GMV',
                        null,
                        AdminUi.brandSecondary,
                      ),
                    ),
                    SizedBox(
                      width: metricWidth,
                      child: _metricCard(
                        'COMPLETED ORDERS',
                        '$totalOrders',
                        Icons.receipt_long_rounded,
                        'Placed',
                        null,
                        AdminUi.info,
                      ),
                    ),
                    SizedBox(
                      width: metricWidth,
                      child: _metricCard(
                        'VIP SHOPPERS',
                        '$vipCount',
                        Icons.stars_rounded,
                        'Top Spenders',
                        null,
                        AdminUi.warning,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _metricCard(
    String label,
    String value,
    IconData icon,
    String? badgeText,
    String? suffix,
    Color accentColor,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 240;

        return Container(
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
                    width: isCompact ? 32 : 36,
                    height: isCompact ? 32 : 36,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: isCompact ? 18 : 20, color: accentColor),
                  ),
                  if (badgeText != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isCompact ? 9 : 10,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: isCompact ? 10 : 14),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: isCompact ? (value.length > 10 ? 15 : 20) : (value.length > 10 ? 18 : 26),
                            fontWeight: FontWeight.w800,
                            color: AdminUi.textPrimary,
                          ),
                        ),
                      ),
                      if (suffix != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          suffix,
                          style: GoogleFonts.inter(
                            fontSize: isCompact ? 10 : 12,
                            fontWeight: FontWeight.w600,
                            color: AdminUi.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. MAIN DATA CONTAINER (TABLE / CARDS)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMainDataContainer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AdminUi.radiusLg,
            border: Border.all(color: AdminUi.border),
            boxShadow: AdminUi.shadowSm,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildToolbar(isMobile),
              const Divider(height: 1, color: AdminUi.border),
              if (isMobile)
                _buildMobileCardList()
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: constraints.maxWidth < 960 ? 960.0 : constraints.maxWidth,
                    child: Column(
                      children: [
                        _buildTableHeader(),
                        const Divider(height: 1, color: AdminUi.border),
                        _buildTableBody(),
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

  Widget _buildToolbar(bool isMobile) {
    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Full-width Search Box
            TextField(
              controller: _searchController,
              decoration: AdminUi.inputDecoration(
                hintText: 'Search buyer by name, email, phone, ID...',
                prefixIcon: const Icon(Icons.search_rounded, color: AdminUi.textMuted, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 12),
            // Segment Filter, Sort and Refresh
            Row(
              children: [
                // Buyer Segment Dropdown
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: AdminUi.radiusMd,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _filterSegment,
                        isExpanded: true,
                        icon: const Icon(Icons.filter_list_rounded, size: 16, color: AdminUi.textSecondary),
                        style: AdminUi.label(size: 12, color: AdminUi.textPrimary, weight: FontWeight.w700),
                        onChanged: (v) => setState(() => _filterSegment = v ?? 'all'),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Buyers', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'vip', child: Text('VIP Shoppers', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'active', child: Text('Active (1+ Orders)', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'new', child: Text('New Signups', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'dormant', child: Text('0 Orders', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'suspended', child: Text('Suspended', overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Sort filter
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: AdminUi.radiusMd,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sortBy,
                        isExpanded: true,
                        icon: const Icon(Icons.sort_rounded, size: 16, color: AdminUi.textSecondary),
                        style: AdminUi.label(size: 12, color: AdminUi.textPrimary, weight: FontWeight.w700),
                        onChanged: (v) => setState(() => _sortBy = v ?? 'spend'),
                        items: const [
                          DropdownMenuItem(value: 'spend', child: Text('Spend ₱ (High)', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'orders', child: Text('Orders (High)', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'newest', child: Text('Newest Joined', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'oldest', child: Text('Oldest Joined', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'name', child: Text('Name (A-Z)', overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Refresh Button
                Container(
                  decoration: BoxDecoration(
                    color: AdminUi.brandSoft,
                    borderRadius: AdminUi.radiusMd,
                  ),
                  child: IconButton(
                    tooltip: 'Refresh Buyer Data',
                    padding: const EdgeInsets.all(10),
                    constraints: const BoxConstraints(),
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh_rounded, color: AdminUi.brand, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search Box
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380, minWidth: 260),
            child: TextField(
              controller: _searchController,
              decoration: AdminUi.inputDecoration(
                hintText: 'Search buyer by name, email, phone, ID...',
                prefixIcon: const Icon(Icons.search_rounded, color: AdminUi.textMuted, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            ),
          ),

          // Buyer Segment Filter Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: AdminUi.radiusMd,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterSegment,
                icon: const Icon(Icons.filter_list_rounded, size: 18, color: AdminUi.textSecondary),
                style: AdminUi.label(size: 13, color: AdminUi.textPrimary, weight: FontWeight.w700),
                onChanged: (v) => setState(() => _filterSegment = v ?? 'all'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Buyers')),
                  DropdownMenuItem(value: 'vip', child: Text('VIP Shoppers (₱1,000+)')),
                  DropdownMenuItem(value: 'active', child: Text('Active Buyers (1+ Orders)')),
                  DropdownMenuItem(value: 'new', child: Text('New Signups (< 30 Days)')),
                  DropdownMenuItem(value: 'dormant', child: Text('Dormant (0 Orders)')),
                  DropdownMenuItem(value: 'suspended', child: Text('Suspended Accounts')),
                ],
              ),
            ),
          ),

          // Sort By Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: AdminUi.radiusMd,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortBy,
                icon: const Icon(Icons.sort_rounded, size: 18, color: AdminUi.textSecondary),
                style: AdminUi.label(size: 13, color: AdminUi.textPrimary, weight: FontWeight.w700),
                onChanged: (v) => setState(() => _sortBy = v ?? 'spend'),
                items: const [
                  DropdownMenuItem(value: 'spend', child: Text('Sort: Highest Spend (₱)')),
                  DropdownMenuItem(value: 'orders', child: Text('Sort: Most Orders')),
                  DropdownMenuItem(value: 'newest', child: Text('Sort: Recently Joined')),
                  DropdownMenuItem(value: 'oldest', child: Text('Sort: Oldest Accounts')),
                  DropdownMenuItem(value: 'name', child: Text('Sort: Name (A-Z)')),
                ],
              ),
            ),
          ),

          // Refresh Button
          IconButton(
            tooltip: 'Refresh Buyer Data',
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, color: AdminUi.brand),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: AdminUi.panelAlt,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          _headerCell('BUYER / CUSTOMER', flex: 3),
          _headerCell('CONTACT DETAILS', flex: 3),
          _headerCell('TIER & STATUS', flex: 2),
          _headerCell('LIFETIME SPEND', flex: 2),
          _headerCell('MEMBER SINCE', flex: 2),
          _headerCell('ACTIONS', flex: 2, align: TextAlign.right),
        ],
      ),
    );
  }

  Widget _headerCell(String text, {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AdminUi.textMuted,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterAndSortUsers(List<Map<String, dynamic>> rawUsers) {
    // Filter only consumers / retail buyers
    var users = rawUsers.where((u) {
      final r = (u['role'] ?? u['role_name'] ?? 'customer').toString().toLowerCase();
      return r == 'customer';
    }).toList();

    // 1. Search Query Filter
    if (_searchQuery.isNotEmpty) {
      users = users.where((u) {
        final name = (u['name'] ?? '').toString().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        final phone = (u['phone'] ?? '').toString().toLowerCase();
        final id = (u['user_id'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery) ||
            email.contains(_searchQuery) ||
            phone.contains(_searchQuery) ||
            id.contains(_searchQuery);
      }).toList();
    }

    // 2. Buyer Segment Filter
    final now = DateTime.now();
    final last30d = now.subtract(const Duration(days: 30));

    if (_filterSegment == 'vip') {
      users = users.where((u) {
        final spent = ((u['total_spent'] as num?)?.toDouble() ?? 0.0);
        final orders = (u['orders_count'] as num? ?? 0).toInt();
        return spent >= 1000 || orders >= 2;
      }).toList();
    } else if (_filterSegment == 'active') {
      users = users.where((u) {
        final orders = (u['orders_count'] as num? ?? 0).toInt();
        return orders > 0;
      }).toList();
    } else if (_filterSegment == 'new') {
      users = users.where((u) {
        final createdStr = u['created_at']?.toString();
        if (createdStr == null) return false;
        final dt = DateTime.tryParse(createdStr);
        return dt != null && dt.isAfter(last30d);
      }).toList();
    } else if (_filterSegment == 'dormant') {
      users = users.where((u) {
        final orders = (u['orders_count'] as num? ?? 0).toInt();
        return orders == 0;
      }).toList();
    } else if (_filterSegment == 'suspended') {
      users = users.where((u) => u['is_active'] == false).toList();
    }

    // 3. Sorting
    if (_sortBy == 'spend') {
      users.sort((a, b) => ((b['total_spent'] as num?) ?? 0).compareTo((a['total_spent'] as num?) ?? 0));
    } else if (_sortBy == 'orders') {
      users.sort((a, b) => ((b['orders_count'] as num?) ?? 0).compareTo((a['orders_count'] as num?) ?? 0));
    } else if (_sortBy == 'newest') {
      users.sort((a, b) => (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));
    } else if (_sortBy == 'oldest') {
      users.sort((a, b) => (a['created_at'] ?? '').toString().compareTo((b['created_at'] ?? '').toString()));
    } else if (_sortBy == 'name') {
      users.sort((a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo((b['name'] ?? '').toString().toLowerCase()));
    }

    return users;
  }

  Widget _buildTableBody() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _usersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(60),
            child: Center(child: AppShimmerLoader(color: AdminUi.brand)),
          );
        }

        final users = _filterAndSortUsers(snapshot.data ?? []);

        if (users.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: users.length,
          separatorBuilder: (context, index) => const Divider(height: 1, color: AdminUi.border),
          itemBuilder: (context, index) => _buildRow(users[index]),
        );
      },
    );
  }

  Widget _buildMobileCardList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _usersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: AppShimmerLoader(color: AdminUi.brand)),
          );
        }

        final users = _filterAndSortUsers(snapshot.data ?? []);

        if (users.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          itemCount: users.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _buildMobileUserCard(users[index]),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_search_rounded, size: 40, color: AdminUi.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              'No buyers match the current filter criteria.',
              style: AdminUi.title(size: 15, color: AdminUi.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Try clearing your search query or selecting "All Buyers".',
              style: AdminUi.body(size: 12, color: AdminUi.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileUserCard(Map<String, dynamic> user) {
    final name = (user['name'] ?? 'Registered Buyer').toString();
    final rawEmail = (user['email'] ?? 'No email').toString();
    final rawPhone = (user['phone'] ?? 'No phone').toString();
    final rawUserId = (user['user_id'] ?? '').toString();
    final shortId = rawUserId.length >= 8 ? rawUserId.substring(0, 8) : rawUserId;

    final email = _piiMasked ? _maskString(rawEmail) : rawEmail;
    final phone = _piiMasked ? _maskPhone(rawPhone) : rawPhone;

    final ordersCount = (user['orders_count'] as num? ?? 0).toInt();
    final totalSpent = ((user['total_spent'] as num?)?.toDouble() ?? 0.0);
    final isActive = user['is_active'] != false;
    final isVip = totalSpent >= 1000 || ordersCount >= 2;

    final rawDate = user['created_at']?.toString();
    String formattedJoined = 'Recently';
    String relativeJoined = '';
    if (rawDate != null) {
      final dt = DateTime.tryParse(rawDate);
      if (dt != null) {
        formattedJoined = DateFormat('MMM d, yyyy').format(dt.toLocal());
        final diff = DateTime.now().difference(dt);
        if (diff.inDays < 30) {
          relativeJoined = '${diff.inDays}d ago';
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AdminUi.radiusMd,
        border: Border.all(color: AdminUi.border),
        boxShadow: AdminUi.shadowSm,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openCustomerInspector(user),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Avatar + Name + Badges + Popup Menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AdminUi.brandSoft,
                    backgroundImage: user['avatar_url'] != null && user['avatar_url'].toString().isNotEmpty
                        ? NetworkImage(user['avatar_url'])
                        : null,
                    child: (user['avatar_url'] == null || user['avatar_url'].toString().isEmpty)
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'B',
                            style: AdminUi.label(color: AdminUi.brand, weight: FontWeight.w800, size: 14),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: AdminUi.label(size: 14, color: AdminUi.textPrimary, weight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!isActive) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AdminUi.danger.withValues(alpha: 0.1),
                                  borderRadius: AdminUi.radiusSm,
                                ),
                                child: Text(
                                  'SUSPENDED',
                                  style: AdminUi.label(size: 9, color: AdminUi.danger, weight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (isVip)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: AdminUi.warning.withValues(alpha: 0.15),
                                  borderRadius: AdminUi.radiusSm,
                                  border: Border.all(color: AdminUi.warning.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, size: 10, color: Color(0xFFB45309)),
                                    const SizedBox(width: 2),
                                    Text(
                                      'VIP GOLD',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9,
                                        color: const Color(0xFFB45309),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: AdminUi.brand.withValues(alpha: 0.08),
                                  borderRadius: AdminUi.radiusSm,
                                ),
                                child: Text(
                                  ordersCount > 0 ? 'ACTIVE BUYER' : 'NEW SHOPPER',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    color: AdminUi.brand,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: rawUserId));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('✅ Buyer ID copied to clipboard')),
                                );
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '#$shortId',
                                    style: GoogleFonts.robotoMono(fontSize: 10, color: AdminUi.textMuted),
                                  ),
                                  const SizedBox(width: 3),
                                  const Icon(Icons.copy_rounded, size: 10, color: AdminUi.textMuted),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Buyer Actions',
                    icon: const Icon(Icons.more_vert_rounded, size: 18, color: AdminUi.textSecondary),
                    shape: RoundedRectangleBorder(borderRadius: AdminUi.radiusMd),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'inspect',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.person_search_rounded, size: 18, color: AdminUi.brand),
                          title: Text('View Full Profile & Orders'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'copy_id',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.copy_rounded, size: 18, color: AdminUi.info),
                          title: Text('Copy Buyer ID'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'status',
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                            size: 18,
                            color: isActive ? AdminUi.danger : AdminUi.success,
                          ),
                          title: Text(isActive ? 'Suspend Account' : 'Reactivate Account'),
                        ),
                      ),
                    ],
                    onSelected: (action) => _handleUserAction(action, user, rawUserId, isActive),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Contact details box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: AdminUi.radiusSm,
                  border: Border.all(color: AdminUi.border.withValues(alpha: 0.6)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.email_outlined, size: 13, color: AdminUi.textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            email,
                            style: AdminUi.body(size: 12, color: AdminUi.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (phone.isNotEmpty && phone != 'No phone') ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 13, color: AdminUi.textMuted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              phone,
                              style: AdminUi.body(size: 12, color: AdminUi.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Bottom metrics strip: Spend, Orders, Joined
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₱${totalSpent.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AdminUi.brand,
                        ),
                      ),
                      Text(
                        ordersCount == 1 ? '1 completed order' : '$ordersCount orders placed',
                        style: AdminUi.body(size: 10, color: AdminUi.textMuted),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formattedJoined,
                        style: AdminUi.body(size: 11, color: AdminUi.textPrimary),
                      ),
                      if (relativeJoined.isNotEmpty)
                        Text(
                          relativeJoined,
                          style: AdminUi.body(size: 10, color: AdminUi.brandSecondary),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(Map<String, dynamic> user) {
    final name = (user['name'] ?? 'Registered Buyer').toString();
    final rawEmail = (user['email'] ?? 'No email').toString();
    final rawPhone = (user['phone'] ?? 'No phone').toString();
    final rawUserId = (user['user_id'] ?? '').toString();
    final shortId = rawUserId.length >= 8 ? rawUserId.substring(0, 8) : rawUserId;

    final email = _piiMasked ? _maskString(rawEmail) : rawEmail;
    final phone = _piiMasked ? _maskPhone(rawPhone) : rawPhone;

    final ordersCount = (user['orders_count'] as num? ?? 0).toInt();
    final totalSpent = ((user['total_spent'] as num?)?.toDouble() ?? 0.0);
    final isActive = user['is_active'] != false;
    final isVip = totalSpent >= 1000 || ordersCount >= 2;

    final rawDate = user['created_at']?.toString();
    String formattedJoined = 'Recently';
    String relativeJoined = '';
    if (rawDate != null) {
      final dt = DateTime.tryParse(rawDate);
      if (dt != null) {
        formattedJoined = DateFormat('MMM d, yyyy').format(dt.toLocal());
        final diff = DateTime.now().difference(dt);
        if (diff.inDays < 30) {
          relativeJoined = '${diff.inDays}d ago';
        }
      }
    }

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => _openCustomerInspector(user),
        hoverColor: AdminUi.panelAlt,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              // 1. Customer Name + Avatar + ID
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AdminUi.brandSoft,
                      backgroundImage: user['avatar_url'] != null && user['avatar_url'].toString().isNotEmpty
                          ? NetworkImage(user['avatar_url'])
                          : null,
                      child: (user['avatar_url'] == null || user['avatar_url'].toString().isEmpty)
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'B',
                              style: AdminUi.label(color: AdminUi.brand, weight: FontWeight.w800, size: 14),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: AdminUi.label(size: 14, color: AdminUi.textPrimary, weight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!isActive) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AdminUi.danger.withValues(alpha: 0.1),
                                    borderRadius: AdminUi.radiusSm,
                                  ),
                                  child: Text(
                                    'SUSPENDED',
                                    style: AdminUi.label(size: 9, color: AdminUi.danger, weight: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '#$shortId',
                            style: GoogleFonts.robotoMono(fontSize: 11, color: AdminUi.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Contact Info
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.email_outlined, size: 13, color: AdminUi.textMuted),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            email,
                            style: AdminUi.body(size: 13, color: AdminUi.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 13, color: AdminUi.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          phone,
                          style: AdminUi.body(size: 12, color: AdminUi.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 3. Tier & Status Badge
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: isVip
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AdminUi.warning.withValues(alpha: 0.15),
                            borderRadius: AdminUi.radiusSm,
                            border: Border.all(color: AdminUi.warning.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 12, color: Color(0xFFB45309)),
                              const SizedBox(width: 4),
                              Text(
                                'VIP GOLD',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  color: const Color(0xFFB45309),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AdminUi.brand.withValues(alpha: 0.08),
                            borderRadius: AdminUi.radiusSm,
                          ),
                          child: Text(
                            ordersCount > 0 ? 'ACTIVE BUYER' : 'NEW SHOPPER',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              color: AdminUi.brand,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                ),
              ),

              // 4. Lifetime Spend
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₱${totalSpent.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AdminUi.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ordersCount == 1 ? '1 Completed Order' : '$ordersCount Orders Placed',
                      style: AdminUi.body(size: 11, color: AdminUi.textMuted),
                    ),
                  ],
                ),
              ),

              // 5. Joined Date
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formattedJoined, style: AdminUi.body(size: 13, color: AdminUi.textPrimary)),
                    if (relativeJoined.isNotEmpty)
                      Text(relativeJoined, style: AdminUi.body(size: 11, color: AdminUi.brandSecondary)),
                  ],
                ),
              ),

              // 6. Action Menu
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Inspect Profile',
                      icon: const Icon(Icons.visibility_outlined, size: 18, color: AdminUi.brand),
                      onPressed: () => _openCustomerInspector(user),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Buyer Actions',
                      icon: const Icon(Icons.more_vert_rounded, size: 18, color: AdminUi.textSecondary),
                      shape: RoundedRectangleBorder(borderRadius: AdminUi.radiusMd),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'inspect',
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.person_search_rounded, size: 18, color: AdminUi.brand),
                            title: Text('View Full Profile & Orders'),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'copy_id',
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.copy_rounded, size: 18, color: AdminUi.info),
                            title: Text('Copy Buyer ID'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'status',
                          child: ListTile(
                            dense: true,
                            leading: Icon(
                              isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                              size: 18,
                              color: isActive ? AdminUi.danger : AdminUi.success,
                            ),
                            title: Text(isActive ? 'Suspend Account' : 'Reactivate Account'),
                          ),
                        ),
                      ],
                      onSelected: (action) => _handleUserAction(action, user, rawUserId, isActive),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleUserAction(String action, Map<String, dynamic> user, String rawUserId, bool isActive) async {
    if (action == 'inspect') {
      _openCustomerInspector(user);
    } else if (action == 'copy_id') {
      Clipboard.setData(ClipboardData(text: rawUserId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Buyer ID copied to clipboard')),
      );
    } else if (action == 'status') {
      final success = await widget.adminService.updateUserAccountStatus(
        userId: rawUserId,
        isActive: !isActive,
      );
      if (success && mounted) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AdminUi.brand,
            content: Text(
              !isActive
                  ? '✅ Buyer account reactivated!'
                  : '⚠️ Buyer account suspended!',
            ),
          ),
        );
      }
    }
  }

  void _openCustomerInspector(Map<String, dynamic> user) {
    final userId = (user['user_id'] ?? '').toString();
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: AdminUi.radiusLg),
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 40,
          vertical: isMobile ? 24 : 40,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 720,
            maxHeight: screenSize.height * 0.85,
          ),
          child: FutureBuilder<Map<String, dynamic>>(
            future: widget.adminService.getCustomerProfileDetails(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(60),
                  child: Center(child: CircularProgressIndicator(color: AdminUi.brand)),
                );
              }

              final data = snapshot.data ?? {};
              final profile = data['profile'] as Map<String, dynamic>? ?? user;
              final orders = List<Map<String, dynamic>>.from(data['orders'] as List? ?? []);
              final addresses = List<Map<String, dynamic>>.from(data['addresses'] as List? ?? []);
              final totalSpend = ((data['total_spent'] as num?)?.toDouble() ?? 0.0);
              final isVip = totalSpend >= 1000 || orders.length >= 2;

              final name = profile['name'] ?? 'Buyer';
              final rawEmail = profile['email'] ?? 'No email';
              final rawPhone = profile['phone'] ?? 'No phone';
              final email = _piiMasked ? _maskString(rawEmail) : rawEmail;
              final phone = _piiMasked ? _maskPhone(rawPhone) : rawPhone;

              return Padding(
                padding: EdgeInsets.all(isMobile ? 18 : 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: isMobile ? 22 : 28,
                          backgroundColor: AdminUi.brandSoft,
                          backgroundImage: profile['avatar_url'] != null && profile['avatar_url'].toString().isNotEmpty
                              ? NetworkImage(profile['avatar_url'])
                              : null,
                          child: (profile['avatar_url'] == null || profile['avatar_url'].toString().isEmpty)
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'B',
                                  style: AdminUi.title(size: isMobile ? 18 : 22, color: AdminUi.brand),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      style: AdminUi.title(size: isMobile ? 16 : 20),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isVip ? AdminUi.warning.withValues(alpha: 0.15) : AdminUi.brand.withValues(alpha: 0.1),
                                      borderRadius: AdminUi.radiusSm,
                                      border: isVip ? Border.all(color: AdminUi.warning.withValues(alpha: 0.3)) : null,
                                    ),
                                    child: Text(
                                      isVip ? 'VIP GOLD' : 'RETAIL BUYER',
                                      style: AdminUi.label(
                                        size: 9,
                                        color: isVip ? const Color(0xFFB45309) : AdminUi.brand,
                                        weight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$email • $phone',
                                style: AdminUi.body(size: 11, color: AdminUi.textMuted),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AdminUi.border),
                    const SizedBox(height: 16),

                    // Lifetime Stats Cards
                    if (isMobile)
                      Row(
                        children: [
                          Expanded(child: _buildStatBox('TOTAL SPEND', '₱${totalSpend.toStringAsFixed(0)}', AdminUi.brand)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildStatBox('ORDERS', '${orders.length}', AdminUi.info)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildStatBox('SAVED LOC', '${addresses.length}', AdminUi.warning)),
                        ],
                      )
                    else
                      Row(
                        children: [
                          _buildStatBox('TOTAL SPEND', '₱${totalSpend.toStringAsFixed(2)}', AdminUi.brand),
                          const SizedBox(width: 14),
                          _buildStatBox('ORDERS PLACED', '${orders.length} Completed', AdminUi.info),
                          const SizedBox(width: 14),
                          _buildStatBox('SAVED ADDRESSES', '${addresses.length} Locations', AdminUi.warning),
                        ],
                      ),
                    const SizedBox(height: 18),

                    // Order History Sub-table
                    Text('Order & Purchase History', style: AdminUi.title(size: 15)),
                    const SizedBox(height: 8),
                    Flexible(
                      child: orders.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  'No purchase history found for this buyer.',
                                  style: AdminUi.body(color: AdminUi.textMuted),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: orders.length,
                              separatorBuilder: (context, index) => const Divider(height: 1, color: AdminUi.border),
                              itemBuilder: (context, index) {
                                final o = orders[index];
                                final id = (o['order_id'] ?? '').toString();
                                final shortRef = id.length >= 8 ? 'ORD-${id.substring(0, 8).toUpperCase()}' : 'ORD-$id';
                                final amt = ((o['total_amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2);
                                final date = o['created_at'] != null
                                    ? DateFormat('MMM d, yyyy HH:mm').format(DateTime.parse(o['created_at']))
                                    : 'Recent';

                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.receipt_long_rounded, color: AdminUi.brand, size: 20),
                                  title: Text(shortRef, style: AdminUi.label(size: 12, weight: FontWeight.w700)),
                                  subtitle: Text(date, style: AdminUi.body(size: 10, color: AdminUi.textMuted)),
                                  trailing: Text(
                                    '₱$amt',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AdminUi.textPrimary,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: AdminUi.primaryButton,
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: AdminUi.radiusMd,
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AdminUi.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. BOTTOM CONSUMER RETENTION & GOVERNANCE ANALYTICS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBottomAnalytics() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _usersFuture,
      builder: (context, snapshot) {
        final allUsers = snapshot.data ?? [];
        final buyers = allUsers.where((u) {
          final r = (u['role'] ?? u['role_name'] ?? 'customer').toString().toLowerCase();
          return r == 'customer';
        }).toList();

        final totalBuyers = buyers.isEmpty ? 1 : buyers.length;
        int vipCount = 0;
        int activeCount = 0;
        int dormantCount = 0;

        for (var b in buyers) {
          final spent = ((b['total_spent'] as num?)?.toDouble() ?? 0.0);
          final orders = (b['orders_count'] as num? ?? 0).toInt();

          if (spent >= 1000 || orders >= 2) {
            vipCount++;
          } else if (orders > 0) {
            activeCount++;
          } else {
            dormantCount++;
          }
        }

        final vipPct = ((vipCount / totalBuyers) * 100).toStringAsFixed(0);
        final activePct = ((activeCount / totalBuyers) * 100).toStringAsFixed(0);
        final dormantPct = ((dormantCount / totalBuyers) * 100).toStringAsFixed(0);

        return LayoutBuilder(
          builder: (context, constraints) {
            final isStacked = constraints.maxWidth < 1050;

            final leftCard = Container(
              padding: const EdgeInsets.all(20),
              decoration: AdminUi.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Buyer Spending & Retention', style: AdminUi.title(size: 16)),
                  const SizedBox(height: 4),
                  Text(
                    'Customer loyalty tiers and lifetime purchasing frequency.',
                    style: AdminUi.body(size: 12, color: AdminUi.textMuted),
                  ),
                  const SizedBox(height: 16),
                  _compositionBar('VIP Gold Shoppers (₱1k+ spend)', '$vipCount ($vipPct%)', (vipCount / totalBuyers), AdminUi.warning),
                  const SizedBox(height: 12),
                  _compositionBar('Active Repeat Buyers (1+ orders)', '$activeCount ($activePct%)', (activeCount / totalBuyers), AdminUi.brand),
                  const SizedBox(height: 12),
                  _compositionBar('New Browsers / 0 Orders', '$dormantCount ($dormantPct%)', (dormantCount / totalBuyers), AdminUi.info),
                ],
              ),
            );

            final rightCard = Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AdminUi.brandDark,
                borderRadius: AdminUi.radiusLg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Consumer Privacy & Governance', style: AdminUi.title(size: 16, color: Colors.white)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AdminUi.success.withValues(alpha: 0.2),
                          borderRadius: AdminUi.radiusFull,
                        ),
                        child: Text(
                          'ENCRYPTED',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AdminUi.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'PII masking, masked email delivery, and encrypted payment tokens active.',
                    style: AdminUi.body(size: 12, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 20),
                  _governanceItem('PII MASKING CONTROLS', 'Standard Active', 'Phone numbers and emails anonymized on toggle'),
                  const Divider(height: 16, color: Colors.white12),
                  _governanceItem('ORDER ESCROW & REFUNDS', 'Protected', 'Automated transaction protection on customer disputes'),
                ],
              ),
            );

            if (isStacked) {
              return Column(
                children: [
                  leftCard,
                  const SizedBox(height: 16),
                  rightCard,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: leftCard),
                const SizedBox(width: 20),
                Expanded(child: rightCard),
              ],
            );
          },
        );
      },
    );
  }

  Widget _compositionBar(String label, String countText, double ratio, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(label, style: AdminUi.label(size: 12, color: AdminUi.textPrimary, weight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Text(countText, style: AdminUi.label(size: 12, color: AdminUi.textMuted)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            backgroundColor: const Color(0xFFF3F4F6),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _governanceItem(String title, String status, String desc) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(desc, style: AdminUi.body(size: 11, color: Colors.white.withValues(alpha: 0.8)), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          status,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AdminUi.success,
          ),
        ),
      ],
    );
  }

  String _maskString(String str) {
    if (str.isEmpty || str == 'No email') return str;
    final parts = str.split('@');
    if (parts.length != 2) return '***';
    final user = parts[0];
    final domain = parts[1];
    final maskedUser = user.length > 2 ? '${user.substring(0, 2)}***' : '***';
    return '$maskedUser@$domain';
  }

  String _maskPhone(String phone) {
    if (phone.isEmpty || phone == 'No phone') return phone;
    if (phone.length <= 4) return '***-****';
    return '${phone.substring(0, 3)}-***-${phone.substring(phone.length - 4)}';
  }
}
