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
  late Future<Map<String, dynamic>> _metricsFuture;
  
  String _searchQuery = '';
  String _filterRole = 'all'; // all, customer, farmer, admin
  String _sortBy = 'newest'; // newest, oldest, spend, orders, name
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
      _metricsFuture = widget.adminService.getCustomerSummaryMetrics();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: SingleChildScrollView(
        padding: AdminUi.pagePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeroCard(),
            const SizedBox(height: 24),
            _buildMainTableContainer(),
            const SizedBox(height: 32),
            _buildBottomAnalytics(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _metricsFuture,
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};
        final totalUsers = data['total_users'] ?? 0;
        final buyers = data['buyers'] ?? 0;
        final farmers = data['farmers'] ?? 0;
        final admins = data['admins'] ?? 0;
        final new30d = data['new_last_30d'] ?? 0;

        return AdminHeroCard(
          useGradient: true,
          eyebrow: 'USER DIRECTORY & IDENTITY',
          title: 'Customer & Account Management',
          description:
              'Monitor registered consumers, farmer partnerships, access privileges, and lifetime purchasing analytics.',
          metrics: [
            AdminMiniMetric(
              label: 'Total Users',
              value: '$totalUsers',
              icon: Icons.people_rounded,
              light: true,
            ),
            const SizedBox(width: 20),
            AdminMiniMetric(
              label: 'Buyers',
              value: '$buyers',
              icon: Icons.shopping_bag_rounded,
              light: true,
            ),
            const SizedBox(width: 20),
            AdminMiniMetric(
              label: 'Farmers',
              value: '$farmers',
              icon: Icons.agriculture_rounded,
              light: true,
            ),
            const SizedBox(width: 20),
            AdminMiniMetric(
              label: 'Admins',
              value: '$admins',
              icon: Icons.shield_rounded,
              light: true,
            ),
            const SizedBox(width: 20),
            AdminMiniMetric(
              label: 'New (30D)',
              value: '+$new30d',
              icon: Icons.person_add_rounded,
              light: true,
            ),
          ],
          actions: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: AdminUi.radiusMd,
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _piiMasked ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Privacy Mode',
                    style: AdminUi.label(size: 12, color: Colors.white, weight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _piiMasked,
                    onChanged: (v) => setState(() => _piiMasked = v),
                    activeThumbColor: Colors.white,
                    activeTrackColor: AdminUi.brandSecondary,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMainTableContainer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth < 960 ? 960.0 : constraints.maxWidth;

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
              _buildToolbar(),
              const Divider(height: 1, color: AdminUi.border),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
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

  Widget _buildToolbar() {
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
                hintText: 'Search by name, email, or phone...',
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

          // Role Filter Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: AdminUi.radiusMd,
            ),
            child: DropdownButton<String>(
              value: _filterRole,
              underline: const SizedBox(),
              icon: const Icon(Icons.tune_rounded, size: 18, color: AdminUi.textSecondary),
              style: AdminUi.label(size: 13, color: AdminUi.textPrimary, weight: FontWeight.w700),
              onChanged: (v) => setState(() => _filterRole = v ?? 'all'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All User Roles')),
                DropdownMenuItem(value: 'customer', child: Text('Retail Buyers')),
                DropdownMenuItem(value: 'farmer', child: Text('Registered Farmers')),
                DropdownMenuItem(value: 'admin', child: Text('Administrators')),
              ],
            ),
          ),

          // Sort By Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: AdminUi.radiusMd,
            ),
            child: DropdownButton<String>(
              value: _sortBy,
              underline: const SizedBox(),
              icon: const Icon(Icons.sort_rounded, size: 18, color: AdminUi.textSecondary),
              style: AdminUi.label(size: 13, color: AdminUi.textPrimary, weight: FontWeight.w700),
              onChanged: (v) => setState(() => _sortBy = v ?? 'newest'),
              items: const [
                DropdownMenuItem(value: 'newest', child: Text('Sort: Recently Joined')),
                DropdownMenuItem(value: 'oldest', child: Text('Sort: Oldest Accounts')),
                DropdownMenuItem(value: 'spend', child: Text('Sort: Highest Spend (₱)')),
                DropdownMenuItem(value: 'orders', child: Text('Sort: Most Orders')),
                DropdownMenuItem(value: 'name', child: Text('Sort: Name (A-Z)')),
              ],
            ),
          ),

          // Refresh Button
          IconButton(
            tooltip: 'Refresh Customer Data',
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
          _headerCell('CUSTOMER / ACCOUNT', flex: 3),
          _headerCell('CONTACT INFO', flex: 3),
          _headerCell('ROLE', flex: 2),
          _headerCell('ORDERS & SPEND', flex: 2),
          _headerCell('JOINED DATE', flex: 2),
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

        var users = List<Map<String, dynamic>>.from(snapshot.data ?? []);

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

        // 2. Role Filter
        if (_filterRole != 'all') {
          users = users.where((u) {
            final r = (u['role'] ?? u['role_name'] ?? 'customer').toString().toLowerCase();
            return r == _filterRole;
          }).toList();
        }

        // 3. Sorting
        if (_sortBy == 'newest') {
          users.sort((a, b) => (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));
        } else if (_sortBy == 'oldest') {
          users.sort((a, b) => (a['created_at'] ?? '').toString().compareTo((b['created_at'] ?? '').toString()));
        } else if (_sortBy == 'spend') {
          users.sort((a, b) => ((b['total_spent'] as num?) ?? 0).compareTo((a['total_spent'] as num?) ?? 0));
        } else if (_sortBy == 'orders') {
          users.sort((a, b) => ((b['orders_count'] as num?) ?? 0).compareTo((a['orders_count'] as num?) ?? 0));
        } else if (_sortBy == 'name') {
          users.sort((a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo((b['name'] ?? '').toString().toLowerCase()));
        }

        if (users.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(60),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.person_search_rounded, size: 48, color: AdminUi.textMuted),
                  const SizedBox(height: 12),
                  Text(
                    'No customers match the current filter criteria.',
                    style: AdminUi.body(size: 14, color: AdminUi.textMuted),
                  ),
                ],
              ),
            ),
          );
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

  Widget _buildRow(Map<String, dynamic> user) {
    final rawRole = (user['role'] ?? user['role_name'] ?? 'customer').toString().toLowerCase();
    final name = (user['name'] ?? 'Registered User').toString();
    final rawEmail = (user['email'] ?? 'No email').toString();
    final rawPhone = (user['phone'] ?? 'No phone').toString();
    final rawUserId = (user['user_id'] ?? '').toString();
    final shortId = rawUserId.length >= 8 ? rawUserId.substring(0, 8) : rawUserId;

    final email = _piiMasked ? _maskString(rawEmail) : rawEmail;
    final phone = _piiMasked ? _maskPhone(rawPhone) : rawPhone;

    final ordersCount = (user['orders_count'] as num? ?? 0).toInt();
    final totalSpent = ((user['total_spent'] as num?)?.toDouble() ?? 0.0);
    final isActive = user['is_active'] != false;

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

    Color roleBg;
    Color roleTextColor;
    String roleDisplay;

    if (rawRole == 'admin') {
      roleBg = AdminUi.danger.withValues(alpha: 0.1);
      roleTextColor = AdminUi.danger;
      roleDisplay = 'ADMIN';
    } else if (rawRole == 'farmer') {
      roleBg = AdminUi.warning.withValues(alpha: 0.12);
      roleTextColor = const Color(0xFFB45309);
      roleDisplay = 'FARMER';
    } else {
      roleBg = AdminUi.brand.withValues(alpha: 0.1);
      roleTextColor = AdminUi.brand;
      roleDisplay = 'BUYER';
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
                              name.isNotEmpty ? name[0].toUpperCase() : 'U',
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

              // 3. Role Badge
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: roleBg,
                      borderRadius: AdminUi.radiusSm,
                      border: Border.all(color: roleTextColor.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      roleDisplay,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: roleTextColor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Orders & Spend
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
                      tooltip: 'Account Actions',
                      icon: const Icon(Icons.more_vert_rounded, size: 18, color: AdminUi.textSecondary),
                      shape: RoundedRectangleBorder(borderRadius: AdminUi.radiusMd),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'inspect',
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.person_search_rounded, size: 18, color: AdminUi.brand),
                            title: Text('View Full Profile'),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'copy_id',
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.copy_rounded, size: 18, color: AdminUi.info),
                            title: Text('Copy User ID'),
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
                      onSelected: (action) async {
                        if (action == 'inspect') {
                          _openCustomerInspector(user);
                        } else if (action == 'copy_id') {
                          Clipboard.setData(ClipboardData(text: rawUserId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✅ User ID copied to clipboard')),
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
                                      ? '✅ User account reactivated!'
                                      : '⚠️ User account suspended!',
                                ),
                              ),
                            );
                          }
                        }
                      },
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

  void _openCustomerInspector(Map<String, dynamic> user) {
    final userId = (user['user_id'] ?? '').toString();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: AdminUi.radiusLg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
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

              final name = profile['name'] ?? 'User';
              final email = profile['email'] ?? 'No email';
              final phone = profile['phone'] ?? 'No phone';
              final role = (profile['role'] ?? profile['role_name'] ?? 'Customer').toString().toUpperCase();

              return Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AdminUi.brandSoft,
                          backgroundImage: profile['avatar_url'] != null && profile['avatar_url'].toString().isNotEmpty
                              ? NetworkImage(profile['avatar_url'])
                              : null,
                          child: (profile['avatar_url'] == null || profile['avatar_url'].toString().isEmpty)
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                  style: AdminUi.title(size: 22, color: AdminUi.brand),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(name, style: AdminUi.title(size: 20)),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AdminUi.brand.withValues(alpha: 0.1),
                                      borderRadius: AdminUi.radiusSm,
                                    ),
                                    child: Text(
                                      role,
                                      style: AdminUi.label(size: 10, color: AdminUi.brand, weight: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('$email • $phone', style: AdminUi.body(size: 13, color: AdminUi.textMuted)),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(height: 1, color: AdminUi.border),
                    const SizedBox(height: 20),

                    // Lifetime Stats
                    Row(
                      children: [
                        _buildStatBox('TOTAL SPEND', '₱${totalSpend.toStringAsFixed(2)}', AdminUi.brand),
                        const SizedBox(width: 16),
                        _buildStatBox('ORDERS PLACED', '${orders.length} Completed', AdminUi.info),
                        const SizedBox(width: 16),
                        _buildStatBox('SAVED ADDRESSES', '${addresses.length} Locations', AdminUi.warning),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Order History Sub-table
                    Text('Recent Orders', style: AdminUi.title(size: 16)),
                    const SizedBox(height: 10),
                    Expanded(
                      child: orders.isEmpty
                          ? Center(
                              child: Text(
                                'No purchase history found for this account.',
                                style: AdminUi.body(color: AdminUi.textMuted),
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
                                  leading: const Icon(Icons.receipt_long_rounded, color: AdminUi.brand),
                                  title: Text(shortRef, style: AdminUi.label(size: 13, weight: FontWeight.w700)),
                                  subtitle: Text(date, style: AdminUi.body(size: 11, color: AdminUi.textMuted)),
                                  trailing: Text(
                                    '₱$amt',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AdminUi.textPrimary,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: AdminUi.primaryButton,
                          child: const Text('Done'),
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
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
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AdminUi.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAnalytics() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _metricsFuture,
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};
        final totalUsers = (data['total_users'] as num? ?? 1).toDouble();
        final buyers = (data['buyers'] as num? ?? 0).toDouble();
        final farmers = (data['farmers'] as num? ?? 0).toDouble();
        final admins = (data['admins'] as num? ?? 0).toDouble();

        final buyersPct = totalUsers > 0 ? ((buyers / totalUsers) * 100).toStringAsFixed(0) : '0';
        final farmersPct = totalUsers > 0 ? ((farmers / totalUsers) * 100).toStringAsFixed(0) : '0';
        final adminsPct = totalUsers > 0 ? ((admins / totalUsers) * 100).toStringAsFixed(0) : '0';

        return LayoutBuilder(
          builder: (context, constraints) {
            final isStacked = constraints.maxWidth < 1050;

            final leftCard = Container(
              padding: const EdgeInsets.all(28),
              decoration: AdminUi.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('User Role Composition', style: AdminUi.title(size: 18)),
                  const SizedBox(height: 4),
                  Text(
                    'Distribution of retail consumers, producers, and administrative staff.',
                    style: AdminUi.body(size: 12, color: AdminUi.textMuted),
                  ),
                  const SizedBox(height: 20),
                  _compositionBar('Retail Shoppers (Buyers)', '$buyers ($buyersPct%)', (buyers / (totalUsers == 0 ? 1 : totalUsers)), AdminUi.brand),
                  const SizedBox(height: 12),
                  _compositionBar('Agricultural Producers (Farmers)', '$farmers ($farmersPct%)', (farmers / (totalUsers == 0 ? 1 : totalUsers)), AdminUi.warning),
                  const SizedBox(height: 12),
                  _compositionBar('Console Administrators (Staff)', '$admins ($adminsPct%)', (admins / (totalUsers == 0 ? 1 : totalUsers)), AdminUi.danger),
                ],
              ),
            );

            final rightCard = Container(
              padding: const EdgeInsets.all(28),
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
                      Text('Identity Governance', style: AdminUi.title(size: 18, color: Colors.white)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AdminUi.success.withValues(alpha: 0.2),
                          borderRadius: AdminUi.radiusFull,
                        ),
                        child: Text(
                          'PROTECTED',
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
                    'Row-level security, Supabase Auth encryption, and session governance are active.',
                    style: AdminUi.body(size: 12, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 24),
                  _governanceItem('PASSWORD AUTHENTICATION', 'Active', 'OAuth2 / Email encryption standard'),
                  const Divider(height: 20, color: Colors.white12),
                  _governanceItem('DEVICE NOTIFICATION LINK', 'Active', 'Firebase Cloud Messaging integration'),
                ],
              ),
            );

            if (isStacked) {
              return Column(
                children: [
                  leftCard,
                  const SizedBox(height: 24),
                  rightCard,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: leftCard),
                const SizedBox(width: 24),
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
            Text(label, style: AdminUi.label(size: 12, color: AdminUi.textPrimary, weight: FontWeight.w700)),
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
        Column(
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
            Text(desc, style: AdminUi.body(size: 11, color: Colors.white.withValues(alpha: 0.8))),
          ],
        ),
        Text(
          status,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
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
