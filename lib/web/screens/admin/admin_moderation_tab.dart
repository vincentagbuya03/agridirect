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
  late Future<List<Map<String, dynamic>>> _reportsFuture;
  String _filterStatus = 'pending';
  final String _filterReason = 'Any Reason';
  String? _selectedReportId;
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
      _reportsFuture = widget.adminService.getReportedContent(status: _filterStatus);
    });
  }

  Future<String?> _promptForNotes({
    required String title,
    required String hintText,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Continue'),
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
      title: 'Dismiss report',
      hintText: 'Optional note explaining why this report was dismissed.',
    );
    if (!mounted || notes == null) return;

    final success = await widget.adminService.dismissReport(
      reportId: report['report_id'].toString(),
      adminId: adminId,
      resolutionNotes: notes.isEmpty ? 'Dismissed by moderator' : notes,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Report dismissed.' : (widget.adminService.errorMessage ?? 'Failed to dismiss report.'),
        ),
      ),
    );
  }

  Future<void> _removeContent(Map<String, dynamic> report) async {
    final adminId = await widget.adminService.getCurrentAdminId();
    if (adminId == null) return;

    final notes = await _promptForNotes(
      title: 'Remove reported content',
      hintText: 'Add a note for the moderation log.',
    );
    if (!mounted || notes == null) return;

    final reportId = report['report_id'].toString();
    final contentId = report['content_id']?.toString() ?? '';
    final contentType = report['content_type_code']?.toString();

    bool contentRemoved = false;
    if (contentType == 'post') {
      contentRemoved = await widget.adminService.deleteCommunityPost(contentId);
    } else if (contentType == 'article') {
      contentRemoved = await widget.adminService.deleteArticle(contentId);
    }

    if (!contentRemoved) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.adminService.errorMessage ?? 'Failed to remove content.'),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: SingleChildScrollView(
        padding: AdminUi.pagePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title + Filter Row ──
            _buildHeader(),
            const SizedBox(height: 24),
            // ── Main Content (Table + Detail Panel) ──
            _buildMainContent(),
            const SizedBox(height: 32),
            // ── Bottom Stats Row ──
            _buildBottomStats(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEADER: Title + Filter Pills
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Moderation Queue', style: AdminUi.display(context, size: 28)),
              const SizedBox(height: 4),
              Text(
                'Review flagged content and maintain the community standard.',
                style: AdminUi.body(size: 15, color: AdminUi.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Filter Status Pill
        _filterPill('FILTER STATUS:', _filterStatus == 'pending' ? 'All Reports' : 'Resolved', () {
          setState(() {
            _filterStatus = _filterStatus == 'pending' ? 'resolved' : 'pending';
            _loadData();
          });
        }),
        const SizedBox(width: 12),
        // Reason Pill
        _filterPill('REASON:', _filterReason, () {}),
      ],
    );
  }

  Widget _filterPill(String label, String value, VoidCallback onTap) {
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
            Text(label, style: AdminUi.label(size: 11, color: AdminUi.textMuted, weight: FontWeight.w600)),
            const SizedBox(width: 6),
            Text(value, style: AdminUi.label(size: 12, color: AdminUi.textPrimary, weight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MAIN CONTENT: Table (left) + Report Detail Panel (right)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMainContent() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _reportsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            decoration: AdminUi.cardDecoration(),
            padding: const EdgeInsets.all(60),
            child: const Center(child: AppShimmerLoader(color: AdminUi.brand)),
          );
        }

        final reports = snapshot.data ?? [];
        final effectiveSelectedReportId =
            reports.any((report) => report['report_id']?.toString() == _selectedReportId)
                ? _selectedReportId
                : reports.isNotEmpty
                    ? reports.first['report_id']?.toString()
                    : null;

        final selectedReport = reports.cast<Map<String, dynamic>?>().firstWhere(
              (report) => report?['report_id']?.toString() == effectiveSelectedReportId,
              orElse: () => reports.isNotEmpty ? reports.first : null,
            );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: AdminUi.cardDecoration(),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: AdminUi.panelAlt,
                        border: Border(bottom: BorderSide(color: AdminUi.border)),
                      ),
                      child: Row(
                        children: [
                          _headerCell('CONTENT TYPE', flex: 2),
                          _headerCell('REASON', flex: 2),
                          _headerCell('REPORTED BY', flex: 2),
                          _headerCell('STATUS', flex: 2),
                          _headerCell('DATE', flex: 1),
                        ],
                      ),
                    ),
                    if (reports.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(60),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.assignment_turned_in_rounded, size: 48, color: AdminUi.border),
                              const SizedBox(height: 16),
                              Text('No $_filterStatus reports found.', style: AdminUi.body(color: AdminUi.textMuted)),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: reports.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, color: AdminUi.border),
                        itemBuilder: (context, index) => _buildReportRow(reports[index]),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            SizedBox(
              width: 320,
              child: _buildReportDetailPanel(selectedReport),
            ),
          ],
        );
      },
    );
  }

  Widget _headerCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: AdminUi.label(size: 11, color: AdminUi.textMuted, weight: FontWeight.w700, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildReportRow(Map<String, dynamic> report) {
    final isSelected = _selectedReportId == report['report_id']?.toString();
    final reason = report['reason'] ?? 'No reason';
    final status = report['status'] ?? _filterStatus;
    final normalizedStatus = status.toString().toLowerCase();
    final isResolved = normalizedStatus == 'resolved' || normalizedStatus == 'dismissed';
    final date = report['created_at'] != null
        ? DateFormat('MMM d,\nHH:mm').format(DateTime.parse(report['created_at']))
        : 'N/A';
    final typeCode = report['content_type_code']?.toString() ?? 'unknown';
    final typeLabel = report['content_type_label']?.toString() ?? 'Content';
    final typeIcon = switch (typeCode) {
      'post' => Icons.forum_rounded,
      'article' => Icons.article_rounded,
      'product' => Icons.inventory_2_rounded,
      'review' => Icons.reviews_rounded,
      'comment' => Icons.comment_rounded,
      _ => Icons.flag_rounded,
    };

    return Material(
      color: isSelected ? AdminUi.brandSoft : Colors.white,
      child: InkWell(
        onTap: () => setState(() => _selectedReportId = report['report_id']?.toString()),
        hoverColor: AdminUi.panelAlt,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Icon(typeIcon, size: 18, color: AdminUi.textSecondary),
                    const SizedBox(width: 12),
                    Text(typeLabel, style: AdminUi.label(size: 14, color: AdminUi.textPrimary, weight: FontWeight.w700)),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  reason,
                  style: AdminUi.body(size: 13, color: AdminUi.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  report['reporter_name']?.toString() ?? 'Unknown user',
                  style: AdminUi.body(size: 13, color: AdminUi.textSecondary),
                ),
              ),
              Expanded(
                flex: 2,
                child: _statusBadge(normalizedStatus, isResolved),
              ),
              Expanded(
                flex: 1,
                child: Text(date, style: AdminUi.body(size: 12, color: AdminUi.textMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status, bool resolved) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: resolved ? AdminUi.success.withValues(alpha: 0.1) : AdminUi.danger.withValues(alpha: 0.1),
        borderRadius: AdminUi.radiusSm,
      ),
      child: Text(
        status.toUpperCase(),
        style: AdminUi.label(
          size: 10,
          color: resolved ? AdminUi.success : AdminUi.danger,
          weight: FontWeight.w800,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REPORT DETAIL PANEL (right sidebar)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildReportDetailPanel(Map<String, dynamic>? report) {
    if (report == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: AdminUi.cardDecoration(),
        child: Center(
          child: Text(
            'Select a report to review its details.',
            style: AdminUi.body(color: AdminUi.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final status = report['status']?.toString().toLowerCase() ?? 'pending';
    final isResolved = status == 'resolved' || status == 'dismissed';
    final severityLabel = report['reason']?.toString().toLowerCase().contains('harass') == true
        ? 'HIGH'
        : report['reason']?.toString().toLowerCase().contains('spam') == true
            ? 'MEDIUM'
            : 'REVIEW';
    final ownerName = report['content_owner_name']?.toString() ?? 'Unknown';
    final title = report['content_title']?.toString() ?? 'Reported content';
    final preview = report['content_preview']?.toString() ?? 'No preview available.';
    final canRemove = !isResolved &&
        (report['content_type_code'] == 'post' || report['content_type_code'] == 'article');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminUi.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Report Detail', style: AdminUi.title(size: 18)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (severityLabel == 'HIGH' ? AdminUi.danger : AdminUi.warning).withValues(alpha: 0.1),
                  borderRadius: AdminUi.radiusSm,
                ),
                child: Text(
                  severityLabel,
                  style: AdminUi.label(
                    size: 10,
                    color: severityLabel == 'HIGH' ? AdminUi.danger : AdminUi.warning,
                    weight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // User info
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AdminUi.brandSoft,
                child: Text(
                  ownerName.isNotEmpty ? ownerName.substring(0, 1).toUpperCase() : '?',
                  style: AdminUi.label(size: 14, color: AdminUi.brand, weight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ownerName, style: AdminUi.label(size: 14, color: AdminUi.textPrimary, weight: FontWeight.w700)),
                  Text(
                    'Reported for: ${report['reason'] ?? 'Unknown'}',
                    style: AdminUi.body(size: 12, color: AdminUi.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Content Preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AdminUi.panelAlt,
              borderRadius: AdminUi.radiusMd,
              border: Border.all(color: AdminUi.border),
            ),
            child: Text(
              '"${preview.isEmpty ? title : preview}"',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AdminUi.textSecondary,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Immediate Actions label
          Text('IMMEDIATE ACTIONS', style: AdminUi.label(size: 11, color: AdminUi.textMuted, weight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: 16),
          // Action Buttons Grid (2x2)
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  Icons.block_rounded,
                  'Remove Content',
                  canRemove ? AdminUi.brand : AdminUi.textMuted,
                  canRemove ? () => _removeContent(report) : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  Icons.check_circle_outline_rounded,
                  'Dismiss Report',
                  isResolved ? AdminUi.textMuted : AdminUi.brand,
                  isResolved ? null : () => _dismissReport(report),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  Icons.info_outline_rounded,
                  'Reporter',
                  AdminUi.warning,
                  null,
                  subtitle: report['reporter_name']?.toString() ?? 'Unknown user',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  Icons.flag_rounded,
                  'Status',
                  AdminUi.danger,
                  null,
                  subtitle: status.toUpperCase(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // View User History
          Center(
            child: TextButton(
              onPressed: null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('REPORT ID ${report['report_id']?.toString().substring(0, 8).toUpperCase() ?? ''}', style: AdminUi.label(size: 11, color: AdminUi.textSecondary, weight: FontWeight.w700, letterSpacing: 0.5)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 14, color: AdminUi.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback? onTap, {
    String? subtitle,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AdminUi.radiusMd,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AdminUi.radiusMd,
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(label, style: AdminUi.label(size: 11, color: color, weight: FontWeight.w700), textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  subtitle,
                  style: AdminUi.body(size: 11, color: AdminUi.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTTOM STATS (Unresolved Reports + Average Resolve Time)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBottomStats() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 140,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED), // warm background
              borderRadius: AdminUi.radiusLg,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('UNRESOLVED REPORTS', style: AdminUi.label(size: 11, color: AdminUi.textMuted, weight: FontWeight.w700, letterSpacing: 0.5)),
                      const SizedBox(height: 8),
                      FutureBuilder<Map<String, dynamic>>(
                        future: widget.adminService.getDashboardCounts(),
                        builder: (context, snapshot) {
                          return Text(
                            '${snapshot.data?['pending_reports'] ?? "..."}', 
                            style: GoogleFonts.plusJakartaSans(fontSize: 40, fontWeight: FontWeight.w800, color: AdminUi.textPrimary)
                          );
                        }
                      ),
                    ],
                  ),
                ),
                Icon(Icons.warning_amber_rounded, size: 64, color: AdminUi.warning.withValues(alpha: 0.2)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Container(
            height: 140,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AdminUi.brand,
              borderRadius: AdminUi.radiusLg,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('AVERAGE RESOLVE TIME', style: AdminUi.label(size: 11, color: Colors.white.withValues(alpha: 0.8), weight: FontWeight.w700, letterSpacing: 0.5)),
                      const SizedBox(height: 8),
                      Text('14m', style: GoogleFonts.plusJakartaSans(fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white)),
                    ],
                  ),
                ),
                Icon(Icons.speed_rounded, size: 64, color: Colors.white.withValues(alpha: 0.3)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
