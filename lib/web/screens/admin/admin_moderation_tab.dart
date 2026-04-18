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
  int? _selectedReportIndex;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _reportsFuture = widget.adminService.getReportedContent(status: _filterStatus);
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: Table
        Expanded(
          flex: 3,
          child: Container(
            decoration: AdminUi.cardDecoration(),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Table header
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
                // Table body
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _reportsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(60),
                        child: Center(child: AppShimmerLoader(color: AdminUi.brand)),
                      );
                    }

                    final reports = snapshot.data ?? [];
                    if (reports.isEmpty) {
                      return Padding(
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
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: reports.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: AdminUi.border),
                      itemBuilder: (context, index) => _buildReportRow(reports[index], index),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        // Right: Report Detail Panel
        SizedBox(
          width: 320,
          child: _buildReportDetailPanel(),
        ),
      ],
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

  Widget _buildReportRow(Map<String, dynamic> report, int index) {
    final isSelected = _selectedReportIndex == index;
    final reason = report['reason'] ?? 'No reason';
    final status = report['status'] ?? _filterStatus;
    final isResolved = status.toString().toLowerCase() == 'resolved';
    final date = report['created_at'] != null
        ? DateFormat('MMM d,\nHH:mm').format(DateTime.parse(report['created_at']))
        : 'N/A';

    // Determine content type icon
    IconData typeIcon;
    String typeLabel;
    if (reason.toString().toLowerCase().contains('spam')) {
      typeIcon = Icons.article_rounded;
      typeLabel = 'Post';
    } else if (reason.toString().toLowerCase().contains('harassment')) {
      typeIcon = Icons.comment_rounded;
      typeLabel = 'Comment';
    } else {
      typeIcon = Icons.article_rounded;
      typeLabel = 'Post';
    }

    return Material(
      color: isSelected ? AdminUi.brandSoft : Colors.white,
      child: InkWell(
        onTap: () => setState(() => _selectedReportIndex = index),
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
                child: Text('@user_reporter', style: AdminUi.body(size: 13, color: AdminUi.textSecondary)),
              ),
              Expanded(
                flex: 2,
                child: _statusBadge(isResolved),
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

  Widget _statusBadge(bool resolved) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: resolved ? AdminUi.success.withValues(alpha: 0.1) : AdminUi.danger.withValues(alpha: 0.1),
        borderRadius: AdminUi.radiusSm,
      ),
      child: Text(
        resolved ? 'RESOLVED' : 'PENDING',
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
  Widget _buildReportDetailPanel() {
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
                  color: AdminUi.danger.withValues(alpha: 0.1),
                  borderRadius: AdminUi.radiusSm,
                ),
                child: Text('CRITICAL', style: AdminUi.label(size: 10, color: AdminUi.danger, weight: FontWeight.w800)),
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
                child: Text('GT', style: AdminUi.label(size: 14, color: AdminUi.brand, weight: FontWeight.w800)),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('@green_thumb_22', style: AdminUi.label(size: 14, color: AdminUi.textPrimary, weight: FontWeight.w700)),
                  Text('Reported for: Spam / Promotion', style: AdminUi.body(size: 12, color: AdminUi.textSecondary)),
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
              '"Hey everyone! Looking for cheap fertilizer? Visit our store at [Link Removed] for 50% off all organic nitrogen supplements. Best quality in the region, don\'t miss out on these harvest gains!"',
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
              Expanded(child: _actionButton(Icons.block_rounded, 'Remove Content', AdminUi.brand, () {})),
              const SizedBox(width: 8),
              Expanded(child: _actionButton(Icons.check_circle_outline_rounded, 'Dismiss Report', AdminUi.brand, () {})),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _actionButton(Icons.warning_amber_rounded, 'Warn User', AdminUi.warning, () {})),
              const SizedBox(width: 8),
              Expanded(child: _actionButton(Icons.do_not_disturb_rounded, 'Ban User', AdminUi.danger, () {})),
            ],
          ),
          const SizedBox(height: 24),
          // View User History
          Center(
            child: TextButton(
              onPressed: () {},
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('VIEW USER HISTORY', style: AdminUi.label(size: 11, color: AdminUi.textSecondary, weight: FontWeight.w700, letterSpacing: 0.5)),
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

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: AdminUi.radiusMd,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: AdminUi.radiusMd,
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(label, style: AdminUi.label(size: 11, color: color, weight: FontWeight.w700), textAlign: TextAlign.center),
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
                Icon(Icons.warning_amber_rounded, size: 64, color: AdminUi.warning.withValues(alpha: 0.3)),
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
                      Text('AVERAGE RESOLVE TIME', style: AdminUi.label(size: 11, color: Colors.white.withValues(alpha: 0.7), weight: FontWeight.w700, letterSpacing: 0.5)),
                      const SizedBox(height: 8),
                      Text('14m', style: GoogleFonts.plusJakartaSans(fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white)),
                    ],
                  ),
                ),
                Icon(Icons.speed_rounded, size: 64, color: Colors.white.withValues(alpha: 0.2)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
