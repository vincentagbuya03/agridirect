import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/admin/admin_service.dart';
import '../../../shared/services/auth/auth_service.dart';

/// Admin Moderation Tab - Manage reported content and community moderation
class AdminModerationTab extends StatefulWidget {
  final AdminService adminService;

  const AdminModerationTab({
    super.key,
    required this.adminService,
  });

  @override
  State<AdminModerationTab> createState() => _AdminModerationTabState();
}

class _AdminModerationTabState extends State<AdminModerationTab>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<Map<String, dynamic>>> _pendingReportsFuture;
  late Future<List<Map<String, dynamic>>> _resolvedReportsFuture;

  static const Color _primary = Color(0xFF16A34A);
  static const Color _darker = Color(0xFF111827);
  static const Color _cardBg = Color(0xFF1E293B);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFF334155);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _pendingReportsFuture = widget.adminService.getReportedContent(status: 'pending');
    _resolvedReportsFuture = widget.adminService.getReportedContent(status: 'resolved');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _darker,
      child: Column(
        children: [
          // Custom dark tab bar
          Container(
            margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: _primary,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: _primary,
              unselectedLabelColor: _muted,
              labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 13),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Pending Reports'),
                Tab(text: 'Resolved Reports'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ReportsListView(
                  future: _pendingReportsFuture,
                  adminService: widget.adminService,
                  onReload: () => setState(() {
                    _pendingReportsFuture =
                        widget.adminService.getReportedContent(status: 'pending');
                  }),
                ),
                _ReportsListView(
                  future: _resolvedReportsFuture,
                  adminService: widget.adminService,
                  onReload: () => setState(() {
                    _resolvedReportsFuture =
                        widget.adminService.getReportedContent(status: 'resolved');
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportsListView extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> future;
  final AdminService adminService;
  final VoidCallback onReload;

  static const Color _primary = Color(0xFF16A34A);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _muted = Color(0xFF6B7280);

  const _ReportsListView({
    required this.future,
    required this.adminService,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _primary));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load reports',
                  style: GoogleFonts.plusJakartaSans(color: _danger)),
            );
          }

          final reports = snapshot.data ?? [];

          if (reports.isEmpty) {
            return Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Icon(Icons.check_circle_outline, color: _muted, size: 48),
                  const SizedBox(height: 12),
                  Text('No reports found',
                      style: GoogleFonts.plusJakartaSans(color: _muted, fontSize: 14)),
                ],
              ),
            );
          }

          return Column(
            children: [
              for (final report in reports)
                _ReportCard(
                  report: report,
                  adminService: adminService,
                  onReload: onReload,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final AdminService adminService;
  final VoidCallback onReload;

  static const Color _primary = Color(0xFF16A34A);
  static const Color _secondary = Color(0xFF06B6D4);
  static const Color _warning = Color(0xFFFFA500);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _cardBg = Color(0xFF1E293B);
  static const Color _darker = Color(0xFF111827);
  static const Color _border = Color(0xFF334155);
  static const Color _muted = Color(0xFF6B7280);

  const _ReportCard({
    required this.report,
    required this.adminService,
    required this.onReload,
  });

  Color _getTypeColor(String type) {
    switch (type) {
      case 'forum_post':
        return _warning;
      case 'comment':
        return _secondary;
      case 'product':
        return _primary;
      case 'user':
        return _danger;
      default:
        return _muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = report['status'] ?? 'pending';
    final isResolved = status == 'resolved';
    final typeColor = _getTypeColor(report['content_type'] ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: typeColor.withOpacity(0.3)),
                ),
                child: Text(
                  report['content_type'] ?? 'unknown',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: typeColor),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isResolved ? _secondary : _danger).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: (isResolved ? _secondary : _danger).withOpacity(0.3)),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isResolved ? _secondary : _danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Reason
          Text('Reason',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: _muted)),
          const SizedBox(height: 4),
          Text(report['reason'] ?? 'No reason provided',
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
          const SizedBox(height: 12),

          // Description
          if (report['description'] != null && (report['description'] as String).isNotEmpty) ...[
            Text('Description',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: _muted)),
            const SizedBox(height: 4),
            Text(
              report['description'] ?? '',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _muted),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
          ],

          // Resolution notes (if resolved)
          if (isResolved && report['resolution_notes'] != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _darker,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Resolution',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: _muted)),
                  const SizedBox(height: 4),
                  Text(report['resolution_notes'] ?? '',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Dates
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Reported: ${_formatDate(report['created_at'])}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _muted)),
              if (report['resolved_at'] != null)
                Text('Resolved: ${_formatDate(report['resolved_at'])}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _muted)),
            ],
          ),
          const SizedBox(height: 16),

          // Actions
          if (!isResolved)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showResolveDialog(context),
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: Text('Resolve', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: _darker,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: _muted,
                          content: Text('Report dismissed', style: GoogleFonts.plusJakartaSans(color: Colors.white)),
                        ),
                      );
                      onReload();
                    },
                    icon: const Icon(Icons.close, size: 18),
                    label: Text('Dismiss', style: GoogleFonts.plusJakartaSans(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _muted,
                      side: const BorderSide(color: Color(0xFF334155)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '-';
    try {
      final date = DateTime.parse(dateString);
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return '-';
    }
  }

  void _showResolveDialog(BuildContext context) {
    final notesController = TextEditingController();
    final authService = AuthService();
    String selectedAction = 'dismiss';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Resolve Report',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Resolution Action',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: _muted)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _darker,
                  border: Border.all(color: _border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildRadioTile(
                      context, setDialogState,
                      title: 'Dismiss Report',
                      value: 'dismiss',
                      groupValue: selectedAction,
                      onChanged: (v) => setDialogState(() => selectedAction = v!),
                    ),
                    _buildRadioTile(
                      context, setDialogState,
                      title: 'Delete Content',
                      value: 'delete',
                      groupValue: selectedAction,
                      onChanged: (v) => setDialogState(() => selectedAction = v!),
                    ),
                    _buildRadioTile(
                      context, setDialogState,
                      title: 'Suspend User',
                      value: 'suspend',
                      groupValue: selectedAction,
                      onChanged: (v) => setDialogState(() => selectedAction = v!),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Resolution notes',
                  labelStyle: GoogleFonts.plusJakartaSans(color: _muted, fontSize: 13),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF16A34A)),
                  ),
                  filled: true,
                  fillColor: _darker,
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: _muted)),
            ),
            ElevatedButton(
              onPressed: () {
                adminService.resolveReport(
                  reportId: report['report_id'] ?? '',
                  adminId: authService.userId,
                  resolutionNotes: notesController.text.isEmpty
                      ? 'Report resolved by admin'
                      : notesController.text,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: _primary,
                    content: Text('Report resolved',
                        style: GoogleFonts.plusJakartaSans(color: _darker)),
                  ),
                );
                onReload();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: _darker,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Resolve', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioTile(
    BuildContext context,
    void Function(void Function()) setDialogState, {
    required String title,
    required String value,
    required String groupValue,
    required void Function(String?) onChanged,
  }) {
    return RadioListTile<String>(
      title: Text(title, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13)),
      value: value,
      groupValue: groupValue,
      activeColor: _primary,
      onChanged: onChanged,
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}
