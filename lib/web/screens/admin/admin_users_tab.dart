import 'package:flutter/material.dart';
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
  String _filterRole = 'all'; // all, buyer, farmer, admin
  bool _piiMasked = true;
  late VoidCallback _dataRefreshListener;

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
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _usersFuture = widget.adminService.getAllUsers();
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
            AdminHeroCard(
              useGradient: true,
              eyebrow: 'System Overview',
              title: 'User Management',
              description: 'Manage accounts, permissions, and security across the AgriDirect platform.',
              metrics: [
                FutureBuilder<Map<String, dynamic>>(
                  future: widget.adminService.getDashboardCounts(),
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    return Row(
                      children: [
                        AdminMiniMetric(
                          label: 'Total Users', 
                          value: '${data?['total_users'] ?? "..."}', 
                          icon: Icons.people_rounded, 
                          light: true
                        ),
                        const SizedBox(width: 24),
                        AdminMiniMetric(
                          label: 'Active Now', 
                          value: (data?['total_users'] ?? 0) > 0 ? "Live" : "0", 
                          icon: Icons.bolt_rounded, 
                          light: true
                        ),
                        const SizedBox(width: 24),
                        AdminMiniMetric(
                          label: 'New Today', 
                          value: '+${data?['new_users_today'] ?? 0}', 
                          icon: Icons.person_add_rounded, 
                          light: true
                        ),
                      ],
                    );
                  }
                ),
              ],
              actions: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: AdminUi.radiusMd,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 12),
                      Text(
                        'Mask PII',
                        style: AdminUi.label(size: 11, color: Colors.white, weight: FontWeight.w700),
                      ),
                      const SizedBox(width: 4),
                      Switch(
                        value: _piiMasked,
                        onChanged: (v) => setState(() => _piiMasked = v),
                        activeThumbColor: Colors.white,
                        activeTrackColor: Colors.white.withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AdminUi.radiusLg,
                border: Border.all(color: AdminUi.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _buildToolbar(),
                  const Divider(height: 1, color: AdminUi.border),
                  _buildTableHeader(),
                  const Divider(height: 1, color: AdminUi.border),
                  _buildTableBody(),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildBottomInsights(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomInsights() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            height: 180,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AdminUi.brandDark,
              borderRadius: AdminUi.radiusLg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User Security Audit', style: AdminUi.title(size: 20, color: Colors.white)),
                const SizedBox(height: 8),
                Text(
                  'System security protocols are active. Platform-wide security audits are performed regularly to ensure data integrity.',
                  style: AdminUi.body(size: 14, color: Colors.white.withValues(alpha: 0.7)),
                ),
                const Spacer(),
                Text('RUN SECURITY SCAN', style: AdminUi.label(size: 12, color: Colors.white, weight: FontWeight.w800)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Container(
            height: 180,
            padding: const EdgeInsets.all(32),
            decoration: AdminUi.cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Activity Snapshot', style: AdminUi.title(size: 20)),
                const SizedBox(height: 16),
                _activityStat('Successful Logins', '98.4%', AdminUi.success),
                const SizedBox(height: 12),
                _activityStat('Failed Attempts', '1.6%', AdminUi.danger),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _activityStat(String label, String value, Color color) {
    return Row(
      children: [
        Text(label, style: AdminUi.label(size: 14, color: AdminUi.textSecondary)),
        const Spacer(),
        Text(value, style: AdminUi.label(size: 14, color: color, weight: FontWeight.w800)),
      ],
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AdminUi.background,
                borderRadius: AdminUi.radiusMd,
              ),
              child: TextField(
                decoration: AdminUi.inputDecoration(
                  hintText: 'Search by name or email...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AdminUi.textMuted, size: 20),
                ).copyWith(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AdminUi.background,
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
                DropdownMenuItem(value: 'buyer', child: Text('Buyers')),
                DropdownMenuItem(value: 'farmer', child: Text('Farmers')),
                DropdownMenuItem(value: 'admin', child: Text('Admins')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: AdminUi.panelAlt,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          _headerCell('User', flex: 2),
          _headerCell('Contact', flex: 2),
          _headerCell('Role', flex: 1),
          _headerCell('Joined', flex: 1),
          _headerCell('Actions', flex: 1, align: TextAlign.right),
        ],
      ),
    );
  }

  Widget _headerCell(String text, {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        text.toUpperCase(),
        textAlign: align,
        style: AdminUi.label(size: 11, color: AdminUi.textMuted, weight: FontWeight.w700),
      ),
    );
  }

  Widget _buildTableBody() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _usersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: AppShimmerLoader(color: AdminUi.brand)),
          );
        }

        var users = snapshot.data ?? [];
        
        // Filtering
        if (_searchQuery.isNotEmpty) {
          users = users.where((u) {
            final name = (u['name'] ?? '').toString().toLowerCase();
            final email = (u['email'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery) || email.contains(_searchQuery);
          }).toList();
        }
        if (_filterRole != 'all') {
          users = users.where((u) => u['role'] == _filterRole).toList();
        }

        if (users.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text('No users found.', style: AdminUi.body(color: AdminUi.textMuted)),
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
    final role = user['role'] ?? 'buyer';
    final name = user['name'] ?? 'Unknown';
    final email = _piiMasked ? '***@***.com' : (user['email'] ?? 'No email');
    final phone = _piiMasked ? '***-***-****' : (user['phone'] ?? 'No phone');
    final joined = user['created_at'] != null 
        ? DateFormat('MMM d, yyyy').format(DateTime.parse(user['created_at']))
        : 'Unknown';

    Color roleColor;
    if (role == 'admin') {
      roleColor = AdminUi.danger;
    } else if (role == 'farmer') {
      roleColor = AdminUi.success;
    } else {
      roleColor = AdminUi.brand;
    }

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () {},
        hoverColor: AdminUi.panelAlt,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AdminUi.brandSoft,
                        borderRadius: AdminUi.radiusMd,
                        border: Border.all(color: AdminUi.brand.withValues(alpha: 0.2)),
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: AdminUi.label(color: AdminUi.brand, weight: FontWeight.w800, size: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: AdminUi.label(size: 14, color: AdminUi.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(email, style: AdminUi.body(size: 13)),
                    const SizedBox(height: 2),
                    Text(phone, style: AdminUi.body(size: 12, color: AdminUi.textMuted)),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.1),
                      borderRadius: AdminUi.radiusSm,
                      border: Border.all(color: roleColor.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      role.toUpperCase(),
                      style: AdminUi.label(size: 10, color: roleColor, weight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(joined, style: AdminUi.body(size: 13, color: AdminUi.textSecondary)),
              ),
              Expanded(
                flex: 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.more_horiz_rounded),
                      color: AdminUi.textSecondary,
                      onPressed: () {},
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
}
