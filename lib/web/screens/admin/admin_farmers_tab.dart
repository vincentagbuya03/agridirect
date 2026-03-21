import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/admin_service.dart';

/// Admin Farmers Tab - Manage farmer verifications and profiles
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

  // Modern dark theme colors
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
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      color: _dark,
      child: Column(
        children: [
          // Tab Bar
          Container(
            margin: EdgeInsets.fromLTRB(
              isMobile ? 16 : 24,
              24,
              isMobile ? 16 : 24,
              0,
            ),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: _primary,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: _primary,
              unselectedLabelColor: _muted,
              labelStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: _primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pending_actions_rounded, size: 18),
                      const SizedBox(width: 8),
                      const Text('Pending'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded, size: 18),
                      const SizedBox(width: 8),
                      const Text('Verified'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cancel_rounded, size: 18),
                      const SizedBox(width: 8),
                      const Text('Rejected'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _FarmersList(
                  adminService: widget.adminService,
                  status: 'pending',
                  emptyIcon: Icons.pending_actions_rounded,
                  emptyMessage: 'No pending applications',
                ),
                _FarmersList(
                  adminService: widget.adminService,
                  status: 'approved',
                  emptyIcon: Icons.verified_rounded,
                  emptyMessage: 'No verified farmers yet',
                ),
                _FarmersList(
                  adminService: widget.adminService,
                  status: 'rejected',
                  emptyIcon: Icons.cancel_rounded,
                  emptyMessage: 'No rejected applications',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FarmersList extends StatefulWidget {
  final AdminService adminService;
  final String status;
  final IconData emptyIcon;
  final String emptyMessage;

  const _FarmersList({
    required this.adminService,
    required this.status,
    required this.emptyIcon,
    required this.emptyMessage,
  });

  @override
  State<_FarmersList> createState() => _FarmersListState();
}

class _FarmersListState extends State<_FarmersList> {
  late Future<List<Map<String, dynamic>>> _registrationsFuture;
  int _currentPage = 0;

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
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _registrationsFuture = widget.adminService.getAllFarmerRegistrations(
      status: widget.status,
      page: _currentPage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _loadData());
      },
      color: _primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _registrationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: _primary),
                ),
              );
            }

            if (snapshot.hasError) {
              return _buildErrorState();
            }

            final registrations = snapshot.data ?? [];

            if (registrations.isEmpty) {
              return _buildEmptyState();
            }

            return Column(
              children: [
                // Stats Cards
                if (widget.status == 'pending')
                  _buildPendingStats(registrations.length),
                const SizedBox(height: 16),
                // Farmer Cards
                ...registrations.map(
                  (reg) => _FarmerCard(
                    registration: reg,
                    adminService: widget.adminService,
                    onAction: () => setState(() => _loadData()),
                    isPending: widget.status == 'pending',
                  ),
                ),
                // Pagination
                const SizedBox(height: 24),
                _buildPagination(registrations.length),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPendingStats(int count) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_warning.withOpacity(0.1), _warning.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.hourglass_empty_rounded,
              color: _warning,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count Pending Applications',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Farmers awaiting verification review',
                  style: GoogleFonts.inter(fontSize: 13, color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(widget.emptyIcon, color: _muted, size: 56),
            ),
            const SizedBox(height: 24),
            Text(
              widget.emptyMessage,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for updates',
              style: GoogleFonts.inter(fontSize: 13, color: _muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: _danger, size: 48),
            const SizedBox(height: 16),
            Text(
              'Failed to load data',
              style: GoogleFonts.inter(
                color: _danger,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => setState(() => _loadData()),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PaginationButton(
          icon: Icons.chevron_left_rounded,
          onPressed: _currentPage > 0
              ? () {
                  setState(() {
                    _currentPage--;
                    _loadData();
                  });
                }
              : null,
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: Text(
            'Page ${_currentPage + 1}',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: _text,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        _PaginationButton(
          icon: Icons.chevron_right_rounded,
          onPressed: count >= 20
              ? () {
                  setState(() {
                    _currentPage++;
                    _loadData();
                  });
                }
              : null,
        ),
      ],
    );
  }
}

class _PaginationButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _PaginationButton({required this.icon, this.onPressed});

  static const Color _card = Color(0xFF1E293B);
  static const Color _border = Color(0xFF334155);
  static const Color _muted = Color(0xFF64748B);
  static const Color _text = Color(0xFFF1F5F9);

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: enabled ? _card : _card.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: Icon(icon, color: enabled ? _text : _muted, size: 20),
        ),
      ),
    );
  }
}

class _FarmerCard extends StatelessWidget {
  final Map<String, dynamic> registration;
  final AdminService adminService;
  final VoidCallback onAction;
  final bool isPending;

  const _FarmerCard({
    required this.registration,
    required this.adminService,
    required this.onAction,
    required this.isPending,
  });

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
    final farmer = registration['farmers'] as Map<String, dynamic>?;
    final user = farmer?['users'] as Map<String, dynamic>?;
    final status = registration['status'] ?? 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primary.withOpacity(0.8), _primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      (user?['name'] ?? 'F')[0].toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user?['name'] ?? 'Unknown Farmer',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _text,
                              ),
                            ),
                          ),
                          _StatusBadge(status: status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        farmer?['farm_name'] ?? 'Farm Name',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.email_outlined, size: 14, color: _muted),
                          const SizedBox(width: 6),
                          Text(
                            user?['email'] ?? 'No email',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _muted,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.phone_outlined, size: 14, color: _muted),
                          const SizedBox(width: 6),
                          Text(
                            user?['phone'] ?? 'No phone',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Details Grid
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _dark.withOpacity(0.5),
              border: Border(top: BorderSide(color: _border)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _DetailItem(
                      icon: Icons.location_on_outlined,
                      label: 'Location',
                      value: farmer?['location'] ?? 'Not specified',
                    ),
                    _DetailItem(
                      icon: Icons.grass_outlined,
                      label: 'Specialty',
                      value: farmer?['specialty'] ?? 'Not specified',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _DetailItem(
                      icon: Icons.calendar_today_outlined,
                      label: 'Experience',
                      value:
                          '${registration['years_of_experience'] ?? 0} years',
                    ),
                    _DetailItem(
                      icon: Icons.access_time_outlined,
                      label: 'Applied',
                      value: _formatDate(registration['created_at']),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Actions
          if (isPending)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: _border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRejectDialog(context),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _danger,
                        side: BorderSide(color: _danger.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _showApproveDialog(context),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Review Notes (for rejected/approved)
          if (!isPending && registration['review_notes'] != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: status == 'rejected'
                    ? _danger.withOpacity(0.05)
                    : _primary.withOpacity(0.05),
                border: Border(top: BorderSide(color: _border)),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notes_rounded,
                    size: 18,
                    color: status == 'rejected' ? _danger : _primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Review Notes',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: status == 'rejected' ? _danger : _primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          registration['review_notes'] ?? '',
                          style: GoogleFonts.inter(fontSize: 13, color: _text),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) {
        return 'Today';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} days ago';
      } else {
        return '${date.month}/${date.day}/${date.year}';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  void _showApproveDialog(BuildContext context) {
    final notesController = TextEditingController();
    final farmer = registration['farmers'] as Map<String, dynamic>?;

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
                color: _primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: _primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'Approve Farmer',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: _text,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to approve this farmer application?',
              style: GoogleFonts.inter(color: _muted, fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: notesController,
              style: GoogleFonts.inter(color: _text, fontSize: 14),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                labelStyle: GoogleFonts.inter(color: _muted, fontSize: 13),
                hintText: 'Add any notes about this approval...',
                hintStyle: GoogleFonts.inter(
                  color: _muted.withOpacity(0.5),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: _dark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _primary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: _muted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await adminService.approveFarmerRegistration(
                registrationId: registration['registration_id'],
                farmerId: farmer?['farmer_id'] ?? '',
                reviewNotes: notesController.text.isEmpty
                    ? null
                    : notesController.text,
              );
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: success ? _primary : _danger,
                    content: Text(
                      success
                          ? 'Farmer approved successfully'
                          : 'Failed to approve farmer',
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                  ),
                );
                onAction();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Approve',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    final reasonController = TextEditingController();

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
              child: const Icon(Icons.cancel_rounded, color: _danger, size: 24),
            ),
            const SizedBox(width: 16),
            Text(
              'Reject Application',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: _text,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please provide a reason for rejecting this application.',
              style: GoogleFonts.inter(color: _muted, fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: reasonController,
              style: GoogleFonts.inter(color: _text, fontSize: 14),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Reason for rejection',
                labelStyle: GoogleFonts.inter(color: _muted, fontSize: 13),
                hintText: 'Explain why this application is being rejected...',
                hintStyle: GoogleFonts.inter(
                  color: _muted.withOpacity(0.5),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: _dark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _danger),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: _muted)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: _warning,
                    content: Text(
                      'Please provide a reason',
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                  ),
                );
                return;
              }

              final success = await adminService.rejectFarmerRegistration(
                registrationId: registration['registration_id'],
                reason: reasonController.text,
              );
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: success ? _primary : _danger,
                    content: Text(
                      success
                          ? 'Application rejected'
                          : 'Failed to reject application',
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                  ),
                );
                onAction();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Reject',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  static const Color _primary = Color(0xFF10B981);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _danger = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'approved':
        color = _primary;
        label = 'Verified';
        icon = Icons.verified_rounded;
        break;
      case 'rejected':
        color = _danger;
        label = 'Rejected';
        icon = Icons.cancel_rounded;
        break;
      default:
        color = _warning;
        label = 'Pending';
        icon = Icons.pending_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  static const Color _muted = Color(0xFF64748B);
  static const Color _text = Color(0xFFF1F5F9);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: _muted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 10, color: _muted),
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
