import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/admin_service.dart';

/// Admin Farmers Tab - Manage farmer verifications and profiles (Modern White)
class AdminFarmersTab extends StatefulWidget {
  final AdminService adminService;

  const AdminFarmersTab({super.key, required this.adminService});

  @override
  State<AdminFarmersTab> createState() => _AdminFarmersTabState();
}

class _AdminFarmersTabState extends State<AdminFarmersTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentPage = 0;
  Map<String, int> _dashboardCounts = {};

  // Modern light theme colors
  static const Color _primary = Color(0xFF10B981);
  static const Color _background = Color(0xFFFAFAFA);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _muted = Color(0xFF64748B);
  static const Color _text = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDashboardCounts();
  }

  Future<void> _loadDashboardCounts() async {
    final counts = await widget.adminService.getDashboardCounts();
    if (mounted) {
      setState(() => _dashboardCounts = counts);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _background,
      child: Column(
        children: [
          // Quick Summary Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildSummaryStat(
                  'Total Farmers',
                  _dashboardCounts['total_farmers']?.toString() ?? '0',
                  _primary,
                  Icons.people_rounded,
                ),
                const SizedBox(width: 16),
                _buildSummaryStat(
                  'Pending',
                  _dashboardCounts['pending_verifications']?.toString() ?? '0',
                  const Color(0xFFF59E0B),
                  Icons.hourglass_empty_rounded,
                ),
                const SizedBox(width: 16),
                _buildSummaryStat(
                  'Verified',
                  _dashboardCounts['verified_farmers']?.toString() ?? '0',
                  _primary,
                  Icons.verified_rounded,
                ),
              ],
            ),
          ),
          // Tab Bar
          Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: _primary,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: _primary,
              unselectedLabelColor: _muted,
              dividerColor: Colors.transparent,
              labelStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              indicator: BoxDecoration(
                color: _primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(4),
              tabs: const [
                Tab(text: 'All Farmers'),
                Tab(text: 'Pending Verification'),
                Tab(text: 'Verified Producers'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _FarmersList(status: 'all', adminService: widget.adminService),
                _FarmersList(
                  status: 'pending',
                  adminService: widget.adminService,
                ),
                _FarmersList(
                  status: 'verified',
                  adminService: widget.adminService,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _text,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FarmersList extends StatefulWidget {
  final String status;
  final AdminService adminService;

  const _FarmersList({required this.status, required this.adminService});

  @override
  State<_FarmersList> createState() => _FarmersListState();
}

class _FarmersListState extends State<_FarmersList> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.adminService.getAllFarmerRegistrations(
        status: widget.status == 'all' ? null : widget.status,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: _AdminFarmersTabState._primary,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading farmers',
              style: GoogleFonts.inter(color: Colors.red),
            ),
          );
        }

        final farmers = snapshot.data ?? [];

        if (farmers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.agriculture_rounded,
                  size: 64,
                  color: _AdminFarmersTabState._muted.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 16),
                Text(
                  'No farmers found in this category',
                  style: GoogleFonts.inter(
                    color: _AdminFarmersTabState._muted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          itemCount: farmers.length,
          itemBuilder: (context, index) => _FarmerCard(farmer: farmers[index]),
        );
      },
    );
  }
}

class _FarmerCard extends StatefulWidget {
  final Map<String, dynamic> farmer;
  const _FarmerCard({required this.farmer});

  @override
  State<_FarmerCard> createState() => _FarmerCardState();
}

class _FarmerCardState extends State<_FarmerCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isVerified = widget.farmer['is_verified'] == true;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isHovered
                ? _AdminFarmersTabState._primary
                : const Color(0xFFE2E8F0),
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: _AdminFarmersTabState._primary.withValues(alpha: 0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _AdminFarmersTabState._primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: _AdminFarmersTabState._primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.farmer['name'] ?? 'Unknown Farmer',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _AdminFarmersTabState._text,
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified_rounded,
                          color: _AdminFarmersTabState._primary,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.farmer['farm_name'] ?? 'Agricultural Producer',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _AdminFarmersTabState._muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (isVerified
                                ? _AdminFarmersTabState._primary
                                : const Color(0xFFF59E0B))
                            .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isVerified ? 'VERIFIED' : 'PENDING REVIEW',
                    style: GoogleFonts.inter(
                      color: isVerified
                          ? _AdminFarmersTabState._primary
                          : const Color(0xFFF59E0B),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _AdminFarmersTabState._background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                color: _AdminFarmersTabState._muted,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
