import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/admin/admin_service.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'admin_ui.dart';

class AdminModerationTab extends StatefulWidget {
  final AdminService adminService;
  const AdminModerationTab({super.key, required this.adminService});

  @override
  State<AdminModerationTab> createState() => _AdminModerationTabState();
}

class _AdminModerationTabState extends State<AdminModerationTab> {
  // Navigation, Search & Filters
  String _filterStatus = 'pending'; // 'pending', 'resolved', 'dismissed', 'all'
  String _selectedContentType = 'ALL'; // 'ALL', 'post', 'comment', 'product', 'review', 'article'
  String _selectedReason = 'ALL'; // 'ALL' or specific reason keyword
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedReportId;

  // Cached Reports & KPI Stats
  List<Map<String, dynamic>> _pendingReports = [];
  List<Map<String, dynamic>> _resolvedReports = [];
  List<Map<String, dynamic>> _dismissedReports = [];
  bool _isLoading = true;
  String _avgResolveTime = 'Under 2h';
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
    _searchController.dispose();
    widget.adminService.dataVersionListenable.removeListener(_dataRefreshListener);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        widget.adminService.getReportedContent(status: 'pending'),
        widget.adminService.getReportedContent(status: 'resolved'),
        widget.adminService.getReportedContent(status: 'dismissed'),
        widget.adminService.getDashboardCounts(),
      ]);

      if (mounted) {
        setState(() {
          _pendingReports = List<Map<String, dynamic>>.from(results[0] as List);
          _resolvedReports = List<Map<String, dynamic>>.from(results[1] as List);
          _dismissedReports = List<Map<String, dynamic>>.from(results[2] as List);
          
          final counts = results[3] as Map<String, dynamic>;
          _avgResolveTime = counts['avg_resolve_time']?.toString() ?? 'Under 2h';
          _isLoading = false;

          // Maintain selection or select first
          final currentList = _getCurrentReportList();
          if (_selectedReportId == null || !currentList.any((r) => r['report_id']?.toString() == _selectedReportId)) {
            _selectedReportId = currentList.isNotEmpty ? currentList.first['report_id']?.toString() : null;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getCurrentReportList() {
    List<Map<String, dynamic>> baseList;
    if (_filterStatus == 'pending') {
      baseList = _pendingReports;
    } else if (_filterStatus == 'resolved') {
      baseList = _resolvedReports;
    } else if (_filterStatus == 'dismissed') {
      baseList = _dismissedReports;
    } else {
      baseList = [..._pendingReports, ..._resolvedReports, ..._dismissedReports];
    }

    // Filter by content type
    if (_selectedContentType != 'ALL') {
      baseList = baseList.where((r) => r['content_type_code']?.toString() == _selectedContentType).toList();
    }

    // Filter by reason
    if (_selectedReason != 'ALL') {
      baseList = baseList.where((r) {
        final reason = (r['reason'] ?? '').toString().toLowerCase();
        return reason.contains(_selectedReason.toLowerCase());
      }).toList();
    }

    // Filter by search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      baseList = baseList.where((r) {
        final title = (r['content_title'] ?? '').toString().toLowerCase();
        final preview = (r['content_preview'] ?? '').toString().toLowerCase();
        final reason = (r['reason'] ?? '').toString().toLowerCase();
        final reporter = (r['reporter_name'] ?? '').toString().toLowerCase();
        final owner = (r['content_owner_name'] ?? '').toString().toLowerCase();
        return title.contains(q) || preview.contains(q) || reason.contains(q) || reporter.contains(q) || owner.contains(q);
      }).toList();
    }

    return baseList;
  }

  Future<String?> _promptForNotes({
    required String title,
    required String hintText,
    required String actionLabel,
    Color actionColor = AdminUi.brand,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add an optional resolution note for the permanent audit trail:', style: GoogleFonts.inter(fontSize: 13, color: AdminUi.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: GoogleFonts.inter(fontSize: 13, color: AdminUi.textMuted),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: actionColor, width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _dismissReport(Map<String, dynamic> report) async {
    final adminId = await widget.adminService.getCurrentAdminId();
    if (adminId == null) return;

    final notes = await _promptForNotes(
      title: 'Dismiss Report as False Flag',
      hintText: 'e.g., Reviewed content; adheres to community guidelines.',
      actionLabel: 'Dismiss Report',
      actionColor: const Color(0xFF3B82F6),
    );
    if (!mounted || notes == null) return;

    final success = await widget.adminService.dismissReport(
      reportId: report['report_id'].toString(),
      adminId: adminId,
      resolutionNotes: notes.isEmpty ? 'Dismissed by moderator as non-violation' : notes,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Report dismissed and marked non-violation.' : (widget.adminService.errorMessage ?? 'Failed to dismiss report.'),
        ),
        backgroundColor: success ? const Color(0xFF059669) : AdminUi.danger,
      ),
    );
    if (success) _loadData();
  }

  Future<void> _removeContent(Map<String, dynamic> report) async {
    final adminId = await widget.adminService.getCurrentAdminId();
    if (adminId == null) return;

    final notes = await _promptForNotes(
      title: 'Remove Content & Resolve Violation',
      hintText: 'e.g., Removed for abusive language and scam violation.',
      actionLabel: 'Remove & Resolve',
      actionColor: AdminUi.danger,
    );
    if (!mounted || notes == null) return;

    final reportId = report['report_id'].toString();
    final contentId = report['content_id']?.toString() ?? '';
    final contentType = report['content_type_code']?.toString();

    bool contentRemoved = false;
    if (contentType == 'post') {
      contentRemoved = await widget.adminService.deleteCommunityPost(contentId);
    } else if (contentType == 'comment') {
      contentRemoved = await widget.adminService.deleteForumComment(contentId);
    } else if (contentType == 'product') {
      contentRemoved = await widget.adminService.suspendProduct(
        contentId,
        notes.isEmpty ? 'Reported product removed by moderator' : notes,
      );
    } else if (contentType == 'review') {
      contentRemoved = await widget.adminService.deleteProductReview(contentId);
    } else if (contentType == 'article') {
      contentRemoved = await widget.adminService.deleteArticle(contentId);
    }

    if (!contentRemoved) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.adminService.errorMessage ?? 'Failed to remove content.'),
          backgroundColor: AdminUi.danger,
        ),
      );
      return;
    }

    final success = await widget.adminService.resolveReport(
      reportId: reportId,
      adminId: adminId,
      resolutionNotes: notes.isEmpty ? 'Content removed by moderator' : notes,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Content removed and report resolved.' : (widget.adminService.errorMessage ?? 'Failed to resolve report.'),
        ),
        backgroundColor: success ? const Color(0xFF059669) : AdminUi.danger,
      ),
    );
    if (success) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final reports = _getCurrentReportList();
    final selectedReport = reports.cast<Map<String, dynamic>?>().firstWhere(
          (report) => report?['report_id']?.toString() == _selectedReportId,
          orElse: () => reports.isNotEmpty ? reports.first : null,
        );

    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 1080;

    return AdminPageFrame(
      child: SingleChildScrollView(
        padding: AdminUi.pagePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildExecutiveHeader(context),
            const SizedBox(height: 24),
            _buildKpiMetricsGrid(context),
            const SizedBox(height: 28),
            _buildControlToolbar(context),
            const SizedBox(height: 20),
            if (_isLoading)
              _buildLoadingState()
            else if (reports.isEmpty)
              _buildEmptyQueueState()
            else if (isDesktop)
              _buildDesktopMasterDetail(reports, selectedReport)
            else
              _buildMobileStackedView(reports),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. EXECUTIVE HEADER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildExecutiveHeader(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderBadge(),
                const SizedBox(height: 10),
                Text('Trust & Moderation Console', style: AdminUi.display(context, size: 20)),
                const SizedBox(height: 4),
                Text(
                  'Review flagged content, enforce community trust, and take rapid moderation actions.',
                  style: AdminUi.body(size: 12, color: AdminUi.textSecondary),
                ),
                const SizedBox(height: 14),
                _buildHeaderActions(isMobile: true),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderBadge(),
                      const SizedBox(height: 8),
                      Text('Trust & Moderation Console', style: AdminUi.display(context, size: 28)),
                      const SizedBox(height: 4),
                      Text(
                        'Review flagged content, enforce community trust, and take rapid moderation actions.',
                        style: AdminUi.body(size: 14, color: AdminUi.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                _buildHeaderActions(isMobile: false),
              ],
            ),
    );
  }

  Widget _buildHeaderBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _pendingReports.isNotEmpty ? const Color(0xFFFEF2F2) : AdminUi.brandSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: _pendingReports.isNotEmpty ? AdminUi.danger : AdminUi.brand,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _pendingReports.isNotEmpty
                ? 'LIVE TRIAGE QUEUE (${_pendingReports.length} PENDING)'
                : 'TRUST SYSTEM ALL CLEAR',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: _pendingReports.isNotEmpty ? AdminUi.danger : AdminUi.brand,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  void _showPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Community Moderation Policy', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('1. Prohibited Items: Chemicals without certification, counterfeit seeds, unregistered livestock medications.', style: GoogleFonts.inter(fontSize: 13, height: 1.5)),
              const SizedBox(height: 8),
              Text('2. Forum Standards: Respectful discussion only. Zero tolerance for harassment, price manipulation, or hate speech.', style: GoogleFonts.inter(fontSize: 13, height: 1.5)),
              const SizedBox(height: 8),
              Text('3. SLA Expectation: All reported violations should be reviewed within 2 hours of submission.', style: GoogleFonts.inter(fontSize: 13, height: 1.5)),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: AdminUi.primaryButton,
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActions({bool isMobile = false}) {
    if (isMobile) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _loadData,
              style: OutlinedButton.styleFrom(
                foregroundColor: AdminUi.textPrimary,
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text('Refresh', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _showPolicyDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminUi.brand,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.shield_outlined, size: 16),
              label: Text('Policy Rules', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _loadData,
          style: OutlinedButton.styleFrom(
            foregroundColor: AdminUi.textPrimary,
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Refresh Queue'),
        ),
        ElevatedButton.icon(
          onPressed: _showPolicyDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminUi.brand,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.shield_outlined, size: 18),
          label: Text('Policy Rules', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. TOP KPI TRIAGE GRID (4 Cards)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildKpiMetricsGrid(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;
    final isTablet = width >= 768 && width < 1100;

    final metrics = [
      _kpiCard(
        title: 'PENDING FLAGS',
        value: '${_pendingReports.length}',
        subtitle: _pendingReports.isNotEmpty ? 'Requires action' : 'Queue all clear',
        icon: Icons.warning_amber_rounded,
        color: _pendingReports.isNotEmpty ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        badge: _pendingReports.isNotEmpty ? 'Priority' : 'Clean',
        isMobile: isMobile,
      ),
      _kpiCard(
        title: 'RESOLVED ACTIONS',
        value: '${_resolvedReports.length}',
        subtitle: 'Violations removed',
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF10B981),
        badge: 'Enforced',
        isMobile: isMobile,
      ),
      _kpiCard(
        title: 'DISMISSED FLAGS',
        value: '${_dismissedReports.length}',
        subtitle: 'Cleared false alarms',
        icon: Icons.shield_outlined,
        color: const Color(0xFF3B82F6),
        badge: 'Clean',
        isMobile: isMobile,
      ),
      _kpiCard(
        title: 'RESPONSE SLA',
        value: _avgResolveTime,
        subtitle: 'Avg. resolution time',
        icon: Icons.speed_rounded,
        color: const Color(0xFF8B5CF6),
        badge: '< 2h Target',
        isMobile: isMobile,
      ),
    ];

    if (isMobile) {
      return SizedBox(
        height: 120,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: metrics.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (ctx, i) => SizedBox(width: 220, child: metrics[i]),
        ),
      );
    }

    if (isTablet) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: metrics[0]),
              const SizedBox(width: 14),
              Expanded(child: metrics[1]),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: metrics[2]),
              const SizedBox(width: 14),
              Expanded(child: metrics[3]),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: metrics[0]),
        const SizedBox(width: 16),
        Expanded(child: metrics[1]),
        const SizedBox(width: 16),
        Expanded(child: metrics[2]),
        const SizedBox(width: 16),
        Expanded(child: metrics[3]),
      ],
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String badge,
    bool isMobile = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 10,
            offset: Offset(0, 2),
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
                padding: EdgeInsets.all(isMobile ? 6 : 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: isMobile ? 16 : 18, color: color),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 8, vertical: isMobile ? 2 : 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isMobile ? 9 : 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 6 : 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isMobile ? 9 : 10,
                  fontWeight: FontWeight.w700,
                  color: AdminUi.textMuted,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isMobile ? 18 : 20,
                  fontWeight: FontWeight.w800,
                  color: AdminUi.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: isMobile ? 10 : 11,
                  color: AdminUi.textSecondary,
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

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. ADVANCED TRIAGE TOOLBAR (Tabs + Search + Filters)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildControlToolbar(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 980;
    final isMobile = width < 640;

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Status Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _statusTab(
                  label: 'Pending',
                  count: '${_pendingReports.length}',
                  isActive: _filterStatus == 'pending',
                  badgeColor: const Color(0xFFEF4444),
                  onTap: () => setState(() => _filterStatus = 'pending'),
                ),
                const SizedBox(width: 8),
                _statusTab(
                  label: 'Resolved',
                  count: '${_resolvedReports.length}',
                  isActive: _filterStatus == 'resolved',
                  badgeColor: const Color(0xFF10B981),
                  onTap: () => setState(() => _filterStatus = 'resolved'),
                ),
                const SizedBox(width: 8),
                _statusTab(
                  label: 'Dismissed',
                  count: '${_dismissedReports.length}',
                  isActive: _filterStatus == 'dismissed',
                  badgeColor: const Color(0xFF3B82F6),
                  onTap: () => setState(() => _filterStatus = 'dismissed'),
                ),
                const SizedBox(width: 8),
                _statusTab(
                  label: 'All Reports',
                  count: '${_pendingReports.length + _resolvedReports.length + _dismissedReports.length}',
                  isActive: _filterStatus == 'all',
                  onTap: () => setState(() => _filterStatus = 'all'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Row 2: Search + Content Type Filter + Reason Filter
          isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSearchField(),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildContentTypeDropdown(isMobile: isMobile)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildReasonDropdown(isMobile: isMobile)),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildSearchField(),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(width: 170, child: _buildContentTypeDropdown(isMobile: false)),
                    const SizedBox(width: 12),
                    SizedBox(width: 180, child: _buildReasonDropdown(isMobile: false)),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _statusTab({
    required String label,
    required String count,
    required bool isActive,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    final activeColor = badgeColor ?? AdminUi.brand;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? activeColor : const Color(0xFFE2E8F0),
            width: isActive ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? activeColor : AdminUi.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? activeColor : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : AdminUi.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (val) => setState(() => _searchQuery = val),
      decoration: InputDecoration(
        hintText: 'Search title, text, author, reporter...',
        hintStyle: GoogleFonts.inter(fontSize: 12, color: AdminUi.textMuted),
        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AdminUi.textMuted),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 16, color: AdminUi.textMuted),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminUi.brand, width: 1.5)),
      ),
    );
  }

  Widget _buildContentTypeDropdown({bool isMobile = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedContentType,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AdminUi.textMuted),
          style: GoogleFonts.plusJakartaSans(fontSize: isMobile ? 11 : 12, fontWeight: FontWeight.w600, color: AdminUi.textPrimary),
          items: const [
            DropdownMenuItem(value: 'ALL', child: Text('All Types', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'post', child: Text('Forum Posts', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'comment', child: Text('Comments', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'product', child: Text('Products', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'review', child: Text('Reviews', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'article', child: Text('Articles', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _selectedContentType = val);
          },
        ),
      ),
    );
  }

  Widget _buildReasonDropdown({bool isMobile = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedReason,
          isExpanded: true,
          icon: const Icon(Icons.filter_list_rounded, size: 16, color: AdminUi.textMuted),
          style: GoogleFonts.plusJakartaSans(fontSize: isMobile ? 11 : 12, fontWeight: FontWeight.w600, color: AdminUi.textPrimary),
          items: const [
            DropdownMenuItem(value: 'ALL', child: Text('All Reasons', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'spam', child: Text('Spam / Scams', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'harass', child: Text('Harassment', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'inappropriate', child: Text('Inappropriate', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'price', child: Text('Price / Fraud', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _selectedReason = val);
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. DESKTOP MASTER-DETAIL WORKSPACE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktopMasterDetail(List<Map<String, dynamic>> reports, Map<String, dynamic>? selectedReport) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Report Queue Stream
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(color: Color(0x04000000), blurRadius: 12, offset: Offset(0, 2)),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reports.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final report = reports[index];
                final isSelected = report['report_id']?.toString() == _selectedReportId;
                return _buildReportQueueCard(report, isSelected: isSelected, onSelect: () {
                  setState(() => _selectedReportId = report['report_id']?.toString());
                });
              },
            ),
          ),
        ),
        const SizedBox(width: 20),
        // Right Column: Investigation & Action Console
        Expanded(
          flex: 2,
          child: _buildInvestigationConsole(selectedReport),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. MOBILE STACKED VIEW
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMobileStackedView(List<Map<String, dynamic>> reports) {
    return Column(
      children: reports.map((report) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(color: Color(0x04000000), blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildReportQueueCard(
            report,
            isSelected: false,
            onSelect: () => _showMobileReportModal(report),
          ),
        );
      }).toList(),
    );
  }

  void _showMobileReportModal(Map<String, dynamic> report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Report Investigation',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AdminUi.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: AdminUi.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: _buildInvestigationConsole(report, isModal: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. REPORT QUEUE ITEM CARD
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildReportQueueCard(
    Map<String, dynamic> report, {
    required bool isSelected,
    required VoidCallback onSelect,
  }) {
    final reason = report['reason'] ?? 'Unspecified issue';
    final status = (report['status'] ?? 'pending').toString().toLowerCase();
    final isResolved = status == 'resolved' || status == 'dismissed';
    final typeCode = report['content_type_code']?.toString() ?? 'unknown';
    final typeLabel = report['content_type_label']?.toString() ?? 'Content';
    final title = report['content_title']?.toString() ?? 'Reported Item';
    final preview = report['content_preview']?.toString() ?? 'No text available';
    final reporterName = report['reporter_name']?.toString() ?? 'Anonymous';
    final ownerName = report['content_owner_name']?.toString() ?? 'Unknown User';

    // Severity Color Coding
    final isCritical = reason.toLowerCase().contains('harass') || reason.toLowerCase().contains('abuse') || reason.toLowerCase().contains('inappropriate');
    final stripeColor = isResolved
        ? const Color(0xFF10B981)
        : (isCritical ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));

    final typeIcon = switch (typeCode) {
      'post' => Icons.forum_rounded,
      'article' => Icons.article_rounded,
      'product' => Icons.inventory_2_rounded,
      'review' => Icons.reviews_rounded,
      'comment' => Icons.comment_rounded,
      _ => Icons.flag_rounded,
    };

    final dateStr = report['created_at'] != null
        ? DateFormat('MMM d, HH:mm').format(DateTime.parse(report['created_at']))
        : 'N/A';

    return Material(
      color: isSelected ? AdminUi.brandSoft : Colors.white,
      child: InkWell(
        onTap: onSelect,
        hoverColor: const Color(0xFFF8FAFC),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: stripeColor, width: isSelected ? 4.5 : 3.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Content Type + Reason Tag + Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(typeIcon, size: 15, color: AdminUi.brand),
                            const SizedBox(width: 4),
                            Text(
                              typeLabel.toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AdminUi.brand,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: stripeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            reason,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: stripeColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _statusBadge(status),
                ],
              ),
              const SizedBox(height: 8),

              // Title & Content Preview Snippet
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AdminUi.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                '"$preview"',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: AdminUi.textSecondary,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),

              // Footer Meta: Reporter & Author + Date
              Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'By: $ownerName',
                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: AdminUi.textPrimary),
                      ),
                      Text('•', style: TextStyle(color: AdminUi.textMuted, fontSize: 9)),
                      Text(
                        'Flagged by $reporterName',
                        style: GoogleFonts.inter(fontSize: 10.5, color: AdminUi.textMuted),
                      ),
                    ],
                  ),
                  Text(
                    dateStr,
                    style: GoogleFonts.inter(fontSize: 10.5, color: AdminUi.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. INVESTIGATION & ACTION CONSOLE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildInvestigationConsole(Map<String, dynamic>? report, {bool isModal = false}) {
    if (report == null) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app_outlined, size: 40, color: AdminUi.textMuted),
              const SizedBox(height: 12),
              Text('Select a report to inspect details and take action.', style: AdminUi.body(color: AdminUi.textSecondary)),
            ],
          ),
        ),
      );
    }

    final status = (report['status'] ?? 'pending').toString().toLowerCase();
    final isResolved = status == 'resolved' || status == 'dismissed';
    final reason = report['reason'] ?? 'Unspecified violation';
    final description = report['description'] ?? 'No additional reporter description provided.';
    final ownerName = report['content_owner_name']?.toString() ?? 'Unknown Author';
    final reporterName = report['reporter_name']?.toString() ?? 'Anonymous Reporter';
    final title = report['content_title']?.toString() ?? 'Reported Item';
    final preview = report['content_preview']?.toString() ?? 'No text available';
    final canRemove = !isResolved;

    return Container(
      padding: EdgeInsets.all(isModal ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isModal ? null : Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: isModal
            ? null
            : const [
                BoxShadow(color: Color(0x04000000), blurRadius: 12, offset: Offset(0, 2)),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Console Header (Only when not modal, as modal has its own header)
          if (!isModal) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Investigation Console', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AdminUi.textPrimary)),
                _statusBadge(status),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 16),
          ],

          // Author / Violator Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AdminUi.brandSoft,
                  child: Text(
                    ownerName.isNotEmpty ? ownerName[0].toUpperCase() : 'U',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AdminUi.brand),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CONTENT AUTHOR', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: AdminUi.textMuted)),
                      Text(ownerName, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AdminUi.textPrimary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AdminUi.brandSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Active Member', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w700, color: AdminUi.brand)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Target Content Snippet Box
          Text('REPORTED CONTENT', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: AdminUi.textMuted, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AdminUi.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  '"$preview"',
                  style: GoogleFonts.inter(fontSize: 12, color: AdminUi.textSecondary, fontStyle: FontStyle.italic, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Reporter Details
          Text('REPORTER RATIONALE', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: AdminUi.textMuted, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flag_rounded, size: 14, color: Color(0xFFD97706)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('Reported for: $reason', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF92400E))),
                    ),
                  ],
                ),
                if (description.isNotEmpty && description != 'No description') ...[
                  const SizedBox(height: 4),
                  Text(description, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFB45309))),
                ],
                const SizedBox(height: 4),
                Text('Submitted by: $reporterName', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF92400E).withValues(alpha: 0.7))),
              ],
            ),
          ),

          if (isResolved) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF059669)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Resolution: ${report['resolution_notes'] ?? 'Action completed by moderator.'}',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF065F46), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          // Immediate Moderation Decision Suite
          Text('MODERATION DECISION', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: AdminUi.textMuted, letterSpacing: 0.5)),
          const SizedBox(height: 10),

          // Primary Red Action: Remove Content
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canRemove ? () async {
                if (isModal) Navigator.of(context).pop();
                await _removeContent(report);
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminUi.danger,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFF1F5F9),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.delete_forever_rounded, size: 18),
              label: Text(
                'Remove Content & Resolve',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Secondary Action: Dismiss False Flag
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isResolved ? null : () async {
                if (isModal) Navigator.of(context).pop();
                await _dismissReport(report);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF3B82F6),
                side: BorderSide(color: isResolved ? const Color(0xFFE2E8F0) : const Color(0xFF93C5FD)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.shield_outlined, size: 18),
              label: Text(
                'Dismiss Flag (No Violation)',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. HELPERS & BADGES
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _statusBadge(String status) {
    Color bg;
    Color fg;
    String label = status.toUpperCase();

    switch (status) {
      case 'resolved':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF059669);
        break;
      case 'dismissed':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        break;
      default:
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFDC2626);
        label = 'PENDING';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(40),
      child: const Center(child: AppShimmerLoader(color: AdminUi.brand)),
    );
  }

  Widget _buildEmptyQueueState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_user_rounded, size: 36, color: Color(0xFF059669)),
            ),
            const SizedBox(height: 14),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No reports matching "$_searchQuery"'
                  : 'No $_filterStatus reports in the queue',
              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: AdminUi.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try changing your search keywords or clearing active filters.'
                  : 'Great job! Community reports have been completely triaged.',
              style: GoogleFonts.inter(fontSize: 12, color: AdminUi.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
