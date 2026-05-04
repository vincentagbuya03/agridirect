import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/admin/admin_service.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:agridirect/shared/widgets/image_widgets.dart';
import 'admin_ui.dart';

class AdminFarmersTab extends StatefulWidget {
  final AdminService adminService;
  const AdminFarmersTab({super.key, required this.adminService});

  @override
  State<AdminFarmersTab> createState() => _AdminFarmersTabState();
}

class _AdminFarmersTabState extends State<AdminFarmersTab> {
  late Future<List<Map<String, dynamic>>> _farmersFuture;
  late Future<List<Map<String, dynamic>>> _pendingFuture;
  final String _searchQuery = '';
  String _filterStatus = 'all';
  final String _filterSpecialty = 'All';
  int _currentPage = 1;
  static const int _rowsPerPage = 10;
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
      _currentPage = 1;
      _farmersFuture = widget.adminService.getAllFarmerRegistrations(
        status: _filterStatus == 'all' ? null : _filterStatus,
      );
      _pendingFuture = widget.adminService.getPendingFarmerRegistrations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: SingleChildScrollView(
        padding: AdminUi.pagePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Metric Cards Row ──
            _buildMetricsRow(),
            const SizedBox(height: 24),
            // ── Filter Chips + Action Button ──
            _buildFilterRow(),
            const SizedBox(height: 24),
            // ── Main Data Table ──
            _buildDataTable(),
            const SizedBox(height: 24),
            // ── Pagination ──
            _buildPaginationRow(),
            const SizedBox(height: 40),
            // ── Bottom Insight Cards ──
            _buildBottomInsights(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // METRIC CARDS (matches reference: Total Farmers, Pending, Top Specialty, Avg Yield)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMetricsRow() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _farmersFuture,
      builder: (context, snap) {
        final farmers = snap.data ?? [];
        final total = farmers.length;
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _pendingFuture,
          builder: (context, pSnap) {
            final pending = pSnap.data?.length ?? 0;
            return FutureBuilder<Map<String, dynamic>>(
              future: widget.adminService.getFarmerMetrics(),
              builder: (context, mSnap) {
                final metrics = mSnap.data;
                return Row(
                  children: [
                    _metricCard('TOTAL FARMERS', '$total', null, null),
                    const SizedBox(width: 16),
                    _metricCard(
                      'PENDING VERIFICATION',
                      '$pending',
                      null,
                      'Action Req.',
                    ),
                    const SizedBox(width: 16),
                    _metricCard(
                      'TOP SPECIALTY',
                      metrics?['top_specialty'] ?? 'Calculating...',
                      null,
                      null,
                    ),
                    const SizedBox(width: 16),
                    _metricCard(
                      'AVG. YIELD SCORE',
                      metrics?['avg_yield'] ?? '0.0',
                      null,
                      '/10',
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _metricCard(
    String label,
    String value,
    String? trend,
    String? suffix,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: AdminUi.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AdminUi.label(
                size: 10,
                color: AdminUi.textMuted,
                weight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AdminUi.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                if (trend != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    trend,
                    style: AdminUi.label(
                      size: 13,
                      color: AdminUi.success,
                      weight: FontWeight.w700,
                    ),
                  ),
                ],
                if (suffix != null) ...[
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      suffix,
                      style: AdminUi.label(
                        size: 13,
                        color: AdminUi.textMuted,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FILTER ROW (Specialty: All, Status: Pending) + Onboard New Farmer button
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildFilterRow() {
    return Row(
      children: [
        _filterChip(Icons.tune_rounded, 'Specialty: $_filterSpecialty', () {}),
        const SizedBox(width: 12),
        _filterChip(
          Icons.verified_user_outlined,
          'Status: ${_filterStatus == 'all' ? 'All' : _filterStatus.substring(0, 1).toUpperCase() + _filterStatus.substring(1)}',
          () {
            setState(() {
              if (_filterStatus == 'all') {
                _filterStatus = 'pending';
              } else if (_filterStatus == 'pending') {
                _filterStatus = 'verified';
              } else {
                _filterStatus = 'all';
              }
              _loadData();
            });
          },
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: () => _showOnboardingDialog(),
          style: AdminUi.primaryButton,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Onboard New Farmer'),
        ),
      ],
    );
  }

  Widget _filterChip(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: AdminUi.radiusFull,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AdminUi.radiusFull,
          border: Border.all(color: AdminUi.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AdminUi.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: AdminUi.label(
                size: 13,
                color: AdminUi.textPrimary,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DATA TABLE (Farm & Owner, Specialty, Location, Status, Joined Date, Actions)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDataTable() {
    return Container(
      decoration: AdminUi.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: AdminUi.panelAlt,
              border: Border(bottom: BorderSide(color: AdminUi.border)),
            ),
            child: Row(
              children: [
                _headerCell('FARM & OWNER', flex: 3),
                _headerCell('SPECIALTY', flex: 2),
                _headerCell('LOCATION', flex: 2),
                _headerCell('STATUS', flex: 2),
                _headerCell('JOINED DATE', flex: 2),
                _headerCell('ACTIONS', flex: 2, align: TextAlign.right),
              ],
            ),
          ),
          // Table Body
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _farmersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(60),
                  child: Center(child: AppShimmerLoader(color: AdminUi.brand)),
                );
              }

              var farmers = snapshot.data ?? [];
              farmers = _getFilteredFarmers(farmers);

              if (farmers.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(60),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.person_search_rounded,
                          size: 48,
                          color: AdminUi.border,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No farmers found.',
                          style: AdminUi.body(color: AdminUi.textMuted),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final paginatedFarmers = _getPaginatedFarmers(farmers);

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: paginatedFarmers.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: AdminUi.border),
                itemBuilder: (context, index) =>
                    _buildFarmerRow(paginatedFarmers[index]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _headerCell(
    String text, {
    int flex = 1,
    TextAlign align = TextAlign.left,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        style: AdminUi.label(
          size: 11,
          color: AdminUi.textMuted,
          weight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFarmerRow(Map<String, dynamic> farmer) {
    final isVerified = farmer['is_verified'] == true;
    final isPending =
        farmer['status']?.toString().toLowerCase() == 'pending' ||
        (!isVerified && farmer['is_active'] != true);
    final farmName = farmer['farm_name'] ?? 'Unnamed Farm';
    final ownerName =
        farmer['name'] ??
        farmer['applicant_name'] ??
        farmer['farmer_name'] ??
        'Unknown';
    final specialty = farmer['specialty'] ?? 'General';
    final location =
        farmer['location'] ?? farmer['residential_address'] ?? 'N/A';
    final date = farmer['created_at'] != null
        ? DateFormat('MMM d, yyyy').format(DateTime.parse(farmer['created_at']))
        : 'N/A';
    final avatarUrl = farmer['avatar_url'] ?? farmer['users']?['avatar_url'];

    String statusLabel;
    Color statusColor;
    if (isVerified) {
      statusLabel = 'VERIFIED';
      statusColor = AdminUi.success;
    } else if (isPending) {
      statusLabel = 'PENDING';
      statusColor = AdminUi.warning;
    } else {
      statusLabel = 'UNVERIFIED';
      statusColor = AdminUi.danger;
    }

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => _showDetails(farmer),
        hoverColor: AdminUi.panelAlt,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Row(
            children: [
              // Farm & Owner
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    SafeCircleAvatar(
                      radius: 22,
                      backgroundColor: AdminUi.brandSoft,
                      imageUrl: avatarUrl,
                      defaultBucket: 'uploads',
                      child: Icon(
                        Icons.agriculture_rounded,
                        color: AdminUi.brand,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            farmName,
                            style: AdminUi.label(
                              size: 14,
                              color: AdminUi.textPrimary,
                              weight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            ownerName,
                            style: AdminUi.body(
                              size: 12,
                              color: AdminUi.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Specialty badge
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AdminUi.brandSoft,
                        borderRadius: AdminUi.radiusSm,
                        border: Border.all(
                          color: AdminUi.brand.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        specialty,
                        style: AdminUi.label(
                          size: 11,
                          color: AdminUi.brand,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Location
              Expanded(
                flex: 2,
                child: Text(
                  location,
                  style: AdminUi.body(size: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Status
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusLabel,
                      style: AdminUi.label(
                        size: 11,
                        color: statusColor,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              // Date
              Expanded(
                flex: 2,
                child: Text(
                  date,
                  style: AdminUi.body(size: 13, color: AdminUi.textSecondary),
                ),
              ),
              // Actions
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!isVerified)
                      ElevatedButton(
                        onPressed: () => _showDetails(farmer),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminUi.brand,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AdminUi.radiusSm,
                          ),
                          textStyle: AdminUi.label(
                            size: 12,
                            weight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Verify Farmer'),
                      ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: AdminUi.textMuted,
                        size: 20,
                      ),
                      onSelected: (value) {
                        if (value == 'view') {
                          _showDetails(farmer);
                        } else if (value == 'edit') {
                          // TODO: Implement edit profile
                        } else if (value == 'deactivate') {
                          widget.adminService.deactivateUser(farmer['user_id']);
                          _loadData();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'view',
                          child: Text('View Details'),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit Profile'),
                        ),
                        const PopupMenuItem(
                          value: 'deactivate',
                          child: Text('Deactivate Farmer'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete Account'),
                        ),
                      ],
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

  // ═══════════════════════════════════════════════════════════════════════════
  // PAGINATION
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPaginationRow() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _farmersFuture,
      builder: (context, snap) {
        final allFarmers = _getFilteredFarmers(snap.data ?? const []);
        final total = allFarmers.length;
        final totalPages = _getTotalPages(total);
        final safeCurrentPage = _currentPage.clamp(1, totalPages);
        final startIndex = total == 0
            ? 0
            : ((safeCurrentPage - 1) * _rowsPerPage) + 1;
        final endIndex = total == 0
            ? 0
            : (safeCurrentPage * _rowsPerPage > total
                  ? total
                  : safeCurrentPage * _rowsPerPage);

        final pages = _buildVisiblePageItems(totalPages, safeCurrentPage);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Showing $startIndex to $endIndex of $total farmers',
              style: AdminUi.body(size: 13, color: AdminUi.textMuted),
            ),
            Row(
              children: [
                _pageButton(
                  '<',
                  false,
                  enabled: safeCurrentPage > 1,
                  onTap: () => _goToPage(safeCurrentPage - 1, totalPages),
                ),
                if (pages.isNotEmpty) const SizedBox(width: 4),
                for (var i = 0; i < pages.length; i++) ...[
                  if (pages[i] == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '...',
                        style: AdminUi.body(color: AdminUi.textMuted),
                      ),
                    )
                  else
                    _pageButton(
                      pages[i]!.toString(),
                      pages[i] == safeCurrentPage,
                      onTap: () => _goToPage(pages[i]!, totalPages),
                    ),
                  if (i != pages.length - 1) const SizedBox(width: 4),
                ],
                const SizedBox(width: 4),
                _pageButton(
                  '>',
                  false,
                  enabled: safeCurrentPage < totalPages,
                  onTap: () => _goToPage(safeCurrentPage + 1, totalPages),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _pageButton(
    String label,
    bool active, {
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    final canTap = enabled && onTap != null;
    return InkWell(
      onTap: canTap ? onTap : null,
      borderRadius: AdminUi.radiusSm,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: active ? AdminUi.brand : Colors.white,
          borderRadius: AdminUi.radiusSm,
          border: active ? null : Border.all(color: AdminUi.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AdminUi.label(
            size: 12,
            color: active
                ? Colors.white
                : (canTap ? AdminUi.textSecondary : AdminUi.textMuted),
            weight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredFarmers(
    List<Map<String, dynamic>> farmers,
  ) {
    if (_searchQuery.isEmpty) return farmers;

    final query = _searchQuery.toLowerCase();
    return farmers.where((f) {
      final name = (f['farm_name'] ?? '').toString().toLowerCase();
      final owner = (f['name'] ?? f['applicant_name'] ?? '')
          .toString()
          .toLowerCase();
      return name.contains(query) || owner.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> _getPaginatedFarmers(
    List<Map<String, dynamic>> all,
  ) {
    final totalPages = _getTotalPages(all.length);
    final safePage = _currentPage.clamp(1, totalPages);
    final start = (safePage - 1) * _rowsPerPage;
    var end = start + _rowsPerPage;
    if (end > all.length) end = all.length;

    if (start >= all.length) return all.take(_rowsPerPage).toList();
    return all.sublist(start, end);
  }

  int _getTotalPages(int totalItems) {
    if (totalItems <= 0) return 1;
    return ((totalItems - 1) ~/ _rowsPerPage) + 1;
  }

  void _goToPage(int page, int totalPages) {
    final target = page.clamp(1, totalPages);
    if (target == _currentPage) return;
    setState(() => _currentPage = target);
  }

  List<int?> _buildVisiblePageItems(int totalPages, int currentPage) {
    if (totalPages <= 7) {
      return List<int>.generate(totalPages, (index) => index + 1);
    }

    if (currentPage <= 4) {
      return [1, 2, 3, 4, 5, null, totalPages];
    }

    if (currentPage >= totalPages - 3) {
      return [
        1,
        null,
        totalPages - 4,
        totalPages - 3,
        totalPages - 2,
        totalPages - 1,
        totalPages,
      ];
    }

    return [
      1,
      null,
      currentPage - 1,
      currentPage,
      currentPage + 1,
      null,
      totalPages,
    ];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTTOM INSIGHTS (Farmer Onboarding Insights + Verification Queue)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBottomInsights() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Farmer Onboarding Insights Card
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AdminUi.brand, const Color(0xFF0D7C5F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: AdminUi.radiusLg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Farmer Onboarding\nInsights',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Platform verification throughput remains stable. Real-time monitoring of document submission trends is active.',
                    style: AdminUi.body(
                      size: 13,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AdminUi.radiusSm,
                      ),
                    ),
                    child: Text(
                      'REVIEW REPORT',
                      style: AdminUi.label(
                        size: 11,
                        color: Colors.white,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          // Verification Queue Card
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: AdminUi.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Verification Queue',
                        style: AdminUi.title(size: 18),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _filterStatus = 'pending';
                            _loadData();
                          });
                        },
                        borderRadius: AdminUi.radiusSm,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Text(
                            'View All',
                            style: AdminUi.label(
                              size: 12,
                              color: AdminUi.brand,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'High priority requests waiting for approval',
                    style: AdminUi.body(size: 12, color: AdminUi.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _pendingFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: AppShimmerLoader(strokeWidth: 2),
                        );
                      }

                      final pending = snapshot.data ?? const [];
                      if (pending.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AdminUi.panelAlt,
                            borderRadius: AdminUi.radiusMd,
                          ),
                          child: Text(
                            'No pending verification requests.',
                            style: AdminUi.body(
                              size: 12,
                              color: AdminUi.textSecondary,
                            ),
                          ),
                        );
                      }

                      final queueItems = pending.take(3).toList();
                      return Column(
                        children: [
                          for (var i = 0; i < queueItems.length; i++) ...[
                            _queueItem(
                              Icons.verified_user_rounded,
                              AdminUi.warning,
                              (queueItems[i]['full_name'] ??
                                      queueItems[i]['applicant_name'] ??
                                      queueItems[i]['name'] ??
                                      'Pending Applicant')
                                  .toString(),
                              (queueItems[i]['farm_name'] ?? 'Pending Farm')
                                  .toString(),
                              _formatQueueTime(queueItems[i]['created_at']),
                            ),
                            if (i != queueItems.length - 1)
                              const SizedBox(height: 12),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatQueueTime(dynamic createdAt) {
    if (createdAt == null) return 'N/A';

    final raw = createdAt.toString();
    if (raw.isEmpty) return 'N/A';

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return 'N/A';

    final now = DateTime.now().toUtc();
    final date = parsed.toUtc();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(parsed.toLocal());
  }

  Widget _queueItem(
    IconData icon,
    Color color,
    String title,
    String subtitle,
    String time,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminUi.panelAlt,
        borderRadius: AdminUi.radiusMd,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AdminUi.radiusSm,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AdminUi.label(
                    size: 13,
                    color: AdminUi.textPrimary,
                    weight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: AdminUi.body(size: 11, color: AdminUi.textSecondary),
                ),
              ],
            ),
          ),
          Text(time, style: AdminUi.label(size: 11, color: AdminUi.textMuted)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════════════════════
  void _showDetails(Map<String, dynamic> farmer) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 500,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 40,
                    offset: const Offset(-10, 0),
                  ),
                ],
              ),
              child: _buildDetailContent(farmer),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  Widget _buildDetailContent(Map<String, dynamic> farmer) {
    final farmName = farmer['farm_name'] ?? 'Unnamed Farm';
    final ownerName =
        farmer['name'] ??
        farmer['applicant_name'] ??
        farmer['farmer_name'] ??
        'Unknown';
    final isVerified = farmer['is_verified'] == true;
    final status =
        farmer['status']?.toString() ?? (isVerified ? 'verified' : 'pending');
    final email =
        farmer['email'] ?? farmer['users']?['email'] ?? 'Not provided';
    final phone = farmer['phone'] ?? farmer['farmer_phone'] ?? 'Not provided';
    final location =
        farmer['location'] ??
        farmer['residential_address'] ??
        'No address provided';
    final birthDate = farmer['birth_date']?.toString() ?? 'Not provided';
    final experience = farmer['years_of_experience']?.toString() ?? '0';

    final specialty = farmer['specialty'] ?? 'General Agriculture';
    final facePhoto = farmer['face_photo_path'] ?? farmer['face_photo'];
    final validId = farmer['valid_id_path'] ?? farmer['valid_id'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
          decoration: BoxDecoration(
            color: AdminUi.sidebarBg.withValues(alpha: 0.05),
            border: Border(bottom: BorderSide(color: AdminUi.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Registration Detail',
                    style: AdminUi.label(
                      size: 12,
                      color: AdminUi.brand,
                      weight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AdminUi.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  SafeCircleAvatar(
                    radius: 32,
                    backgroundColor: AdminUi.brandSoft,
                    imageUrl: facePhoto,
                    defaultBucket: 'uploads',
                    child: Icon(
                      Icons.agriculture_rounded,
                      color: AdminUi.brand,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          farmName,
                          style: AdminUi.display(
                            context,
                            size: 24,
                            weight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'By $ownerName',
                          style: AdminUi.body(
                            size: 15,
                            color: AdminUi.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailSection('CORE INFORMATION', [
                  _detailItem('Specialty', specialty, Icons.eco_rounded),
                  _detailItem(
                    'Experience',
                    '$experience Years',
                    Icons.history_edu_rounded,
                  ),
                  _detailItem('Birth Date', birthDate, Icons.cake_rounded),
                  _detailItem('Location', location, Icons.location_on_rounded),
                  _detailItem('Email', email, Icons.email_rounded),
                  _detailItem('Phone', phone, Icons.phone_rounded),
                ]),
                const SizedBox(height: 32),
                _detailSection('IDENTITY VERIFICATION', [
                  _detailItem(
                    'ID Type',
                    _formatIdType(farmer['id_type']),
                    Icons.badge_rounded,
                  ),
                  if (farmer['id_type'] == 'national_id')
                    _detailItem(
                      'PhilSys PCN',
                      farmer['pcn'] ?? 'Not provided',
                      Icons.qr_code_scanner_rounded,
                    ),
                  _detailItem(
                    'Full Name',
                    farmer['full_name'] ?? ownerName,
                    Icons.person_rounded,
                  ),
                  _detailItem(
                    'Sex',
                    farmer['sex'] ?? 'Not provided',
                    Icons.wc_rounded,
                  ),
                  _detailItem(
                    'Place of Birth',
                    farmer['place_of_birth'] ?? 'Not provided',
                    Icons.map_rounded,
                  ),
                ]),
                const SizedBox(height: 32),
                _detailSection('VERIFICATION STATUS', [
                  _detailStatusItem(status),
                ]),
                const SizedBox(height: 32),
                _detailSection('SUBMITTED DOCUMENTS', [
                  _documentPlaceholder(
                    'Face Recognition Match',
                    path: facePhoto,
                    icon: Icons.face_retouching_natural_rounded,
                    onTap: () =>
                        _viewDocument('Face Recognition Match', facePhoto),
                  ),
                  _documentPlaceholder(
                    'Valid Government ID (Front)',
                    path: validId,
                    icon: Icons.badge_rounded,
                    onTap: () =>
                        _viewDocument('Valid Government ID (Front)', validId),
                  ),
                  _documentPlaceholder(
                    'Valid Government ID (Back / QR)',
                    path: farmer['valid_id_back_path'],
                    icon: Icons.qr_code_rounded,
                    onTap: () => _viewDocument(
                      'Valid Government ID (Back / QR)',
                      farmer['valid_id_back_path'],
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
        // Footer Actions
        if (status.toLowerCase() == 'pending' ||
            status.toLowerCase() == 'unverified')
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AdminUi.border)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _reject(farmer),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdminUi.danger,
                      side: const BorderSide(color: AdminUi.danger),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: AdminUi.radiusMd,
                      ),
                    ),
                    child: Text(
                      'REJECT APPLICATION',
                      style: AdminUi.label(size: 13, weight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _approve(farmer);
                    },
                    style: AdminUi.primaryButton.copyWith(
                      padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(vertical: 18),
                      ),
                    ),
                    child: const Text('APPROVE FARMER'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _detailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AdminUi.label(
            size: 11,
            color: AdminUi.textMuted,
            weight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _detailItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AdminUi.brand.withValues(alpha: 0.5)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AdminUi.label(
                    size: 11,
                    color: AdminUi.textMuted,
                    weight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: AdminUi.body(
                    size: 14,
                    color: AdminUi.textPrimary,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailStatusItem(String status) {
    final isVerified =
        status.toLowerCase() == 'verified' ||
        status.toLowerCase() == 'approved';
    final isPending = status.toLowerCase() == 'pending';
    final color = isVerified
        ? AdminUi.success
        : (isPending ? AdminUi.warning : AdminUi.danger);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AdminUi.radiusMd,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            isVerified ? Icons.verified_rounded : Icons.pending_actions_rounded,
            color: color,
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status.toUpperCase(),
                style: AdminUi.label(
                  size: 13,
                  color: color,
                  weight: FontWeight.w800,
                ),
              ),
              Text(
                isVerified
                    ? 'All credentials verified'
                    : 'Awaiting admin review',
                style: AdminUi.body(size: 12, color: AdminUi.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _documentPlaceholder(
    String title, {
    String? path,
    IconData icon = Icons.file_present_rounded,
    VoidCallback? onTap,
  }) {
    final hasDoc = path != null && path.isNotEmpty;
    return InkWell(
      onTap: hasDoc ? onTap : null,
      borderRadius: AdminUi.radiusMd,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AdminUi.background,
          borderRadius: AdminUi.radiusMd,
          border: Border.all(color: AdminUi.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: hasDoc ? AdminUi.brand : AdminUi.textMuted),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AdminUi.label(
                      size: 13,
                      color: AdminUi.textPrimary,
                      weight: FontWeight.w600,
                    ),
                  ),
                  if (hasDoc)
                    Text(
                      'Document attached',
                      style: AdminUi.body(
                        size: 11,
                        color: AdminUi.success,
                        weight: FontWeight.w700,
                      ),
                    )
                  else
                    Text(
                      'No document uploaded',
                      style: AdminUi.body(size: 11, color: AdminUi.textMuted),
                    ),
                ],
              ),
            ),
            if (hasDoc)
              Text(
                'VIEW',
                style: AdminUi.label(
                  size: 11,
                  color: AdminUi.brand,
                  weight: FontWeight.w800,
                ),
              )
            else
              const Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: AdminUi.warning,
              ),
          ],
        ),
      ),
    );
  }

  void _viewDocument(String title, String? path) async {
    if (path == null || path.isEmpty) return;

    // Show loading dialog immediately
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final signedUrl = await widget.adminService.getSignedUrl(path);

    if (!mounted) return;
    Navigator.pop(context); // Close loading

    if (signedUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate secure preview URL')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 800),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AdminUi.radiusLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: AdminUi.title(size: 20)),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: ClipRRect(
                    borderRadius: AdminUi.radiusMd,
                    child: Image.network(
                      signedUrl,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const SizedBox(
                          height: 300,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 300,
                          color: AdminUi.background,
                          child: const Center(
                            child: Text(
                              'Failed to load image. Path may be invalid.',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _reject(Map<String, dynamic> farmer) async {
    final registrationId = farmer['registration_id']?.toString();
    if (registrationId == null) return;

    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AdminUi.radiusMd),
        title: Text(
          'Reject Application',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please provide a reason for rejection. This will be sent to the farmer.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: AdminUi.inputDecoration(
                hintText: 'e.g. Incomplete documentation...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminUi.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.isNotEmpty) {
      await widget.adminService.rejectFarmerRegistration(
        registrationId: registrationId,
        reason: controller.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      _loadData();
    }
  }

  Future<void> _approve(Map<String, dynamic> farmer) async {
    final farmerId = farmer['farmer_id']?.toString() ?? '';
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AdminUi.radiusMd),
        title: Text(
          'Verify Farmer',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to verify this farmer? This will allow them to sell products on the platform.',
            ),
            const SizedBox(height: 16),
            Text(
              'OPTIONAL REVIEW NOTES',
              style: AdminUi.label(
                size: 11,
                color: AdminUi.textMuted,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesController,
              maxLines: 2,
              decoration: AdminUi.inputDecoration(
                hintText: 'e.g. Identity verified via PhilSys QR...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: AdminUi.primaryButton.copyWith(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
            child: const Text('Confirm Verification'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final regId = await widget.adminService.resolvePendingRegistrationId(
        farmerId: farmerId,
      );
      if (regId != null) {
        await widget.adminService.approveFarmerRegistration(
          registrationId: regId,
          reviewNotes: notesController.text.trim(),
        );
      } else {
        await widget.adminService.verifyFarmer(farmerId: farmerId);
      }
      if (!mounted) return;
      _loadData();
    }
  }

  String _formatIdType(String? idType) {
    if (idType == null || idType.isEmpty) return 'Not provided';
    switch (idType.toLowerCase()) {
      case 'national_id':
        return 'National ID (PhilSys)';
      case 'drivers_license':
        return "Driver's License";
      case 'passport':
        return 'Passport';
      case 'postal_id':
        return 'Postal ID';
      case 'voters_id':
        return "Voter's ID";
      case 'sss_id':
        return 'SSS ID';
      case 'philhealth_id':
        return 'PhilHealth ID';
      case 'pag_ibig_id':
        return 'Pag-IBIG ID';
      default:
        // Capitalize and replace underscores
        return idType
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (w) =>
                  w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '',
            )
            .join(' ');
    }
  }

  void _showOnboardingDialog() {
    showDialog(
      context: context,
      builder: (context) => _OnboardFarmerDialog(adminService: widget.adminService),
    ).then((_) => _loadData());
  }
}

class _OnboardFarmerDialog extends StatefulWidget {
  final AdminService adminService;
  const _OnboardFarmerDialog({required this.adminService});

  @override
  State<_OnboardFarmerDialog> createState() => _OnboardFarmerDialogState();
}

class _OnboardFarmerDialogState extends State<_OnboardFarmerDialog> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  Map<String, dynamic>? _selectedUser;

  void _search() async {
    if (_searchController.text.length < 3) return;
    setState(() => _searching = true);
    final results = await widget.adminService.getAllUsers(
      searchQuery: _searchController.text,
    );
    if (mounted) {
      setState(() {
        _searchResults = results.where((u) => u['role'] != 'farmer' && u['role'] != 'admin').toList();
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AdminUi.radiusLg),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Onboard New Farmer', style: AdminUi.title(size: 20)),
            const SizedBox(height: 8),
            Text(
              'Search for an existing user to promote them to a verified farmer.',
              style: AdminUi.body(color: AdminUi.textSecondary),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _searchController,
              decoration: AdminUi.inputDecoration(
                hintText: 'Search by email or name...',
                prefixIcon: const Icon(Icons.search_rounded),
              ),
              onChanged: (_) => _search(),
            ),
            const SizedBox(height: 16),
            if (_searching)
              const Center(child: CircularProgressIndicator())
            else if (_searchResults.isNotEmpty)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: AdminUi.border),
                  borderRadius: AdminUi.radiusMd,
                ),
                child: ListView.separated(
                  itemCount: _searchResults.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    final isSelected = _selectedUser?['user_id'] == user['user_id'];
                    return ListTile(
                      title: Text(user['name'] ?? 'Unknown'),
                      subtitle: Text(user['email'] ?? ''),
                      selected: isSelected,
                      onTap: () => setState(() => _selectedUser = user),
                      trailing: isSelected ? const Icon(Icons.check_circle, color: AdminUi.brand) : null,
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _selectedUser == null ? null : () async {
                    await widget.adminService.updateUserRole(
                      userId: _selectedUser!['user_id'],
                      newRole: 'farmer',
                    );
                    if (mounted) Navigator.pop(context);
                  },
                  style: AdminUi.primaryButton,
                  child: const Text('Promote to Farmer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
