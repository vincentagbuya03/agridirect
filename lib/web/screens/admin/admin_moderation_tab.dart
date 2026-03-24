import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/admin_service.dart';
import '../../../shared/services/auth_service.dart';

/// Admin Moderation Tab - Manage reported content and community moderation (Modern White)
class AdminModerationTab extends StatefulWidget {
  final AdminService adminService;

  const AdminModerationTab({super.key, required this.adminService});

  @override
  State<AdminModerationTab> createState() => _AdminModerationTabState();
}

class _AdminModerationTabState extends State<AdminModerationTab>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<Map<String, dynamic>>> _pendingReportsFuture;
  late Future<List<Map<String, dynamic>>> _resolvedReportsFuture;

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
    _tabController = TabController(length: 2, vsync: this);
    _loadReports();
  }

  void _loadReports() {
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
      color: _background,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Content Moderation',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _text,
                      ),
                    ),
                    Text(
                      'Review and resolve reported platform content',
                      style: GoogleFonts.inter(fontSize: 13, color: _muted),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _loadReports()),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _text,
                    elevation: 0,
                    side: const BorderSide(color: _border),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          // Tab Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: _primary,
              labelColor: _primary,
              unselectedLabelColor: _muted,
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: _primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(4),
              tabs: const [
                Tab(text: 'Pending Reports'),
                Tab(text: 'History'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ReportsListView(
                  future: _pendingReportsFuture,
                  adminService: widget.adminService,
                  onReload: () => setState(() {
                    _pendingReportsFuture = widget.adminService.getReportedContent(status: 'pending');
                  }),
                ),
                _ReportsListView(
                  future: _resolvedReportsFuture,
                  adminService: widget.adminService,
                  onReload: () => setState(() {
                    _resolvedReportsFuture = widget.adminService.getReportedContent(status: 'resolved');
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

  const _ReportsListView({
    required this.future,
    required this.adminService,
    required this.onReload,
  });

  static const Color _primary = Color(0xFF10B981);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _muted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: _primary)));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Failed to load reports', style: GoogleFonts.inter(color: _danger)));
          }

          final reports = snapshot.data ?? [];

          if (reports.isEmpty) {
            return Center(
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  Icon(Icons.verified_user_outlined, color: _muted.withOpacity(0.2), size: 64),
                  const SizedBox(height: 16),
                  Text('All clear! No reports found', style: GoogleFonts.inter(color: _muted, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          return Column(
            children: reports.map((report) => _ReportCard(
              report: report,
              adminService: adminService,
              onReload: onReload,
            )).toList(),
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

  const _ReportCard({required this.report, required this.adminService, required this.onReload});

  @override
  Widget build(BuildContext context) {
    final status = report['status'] ?? 'pending';
    final isResolved = status == 'resolved';
    final type = report['content_type'] ?? 'Content';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Badge(text: type.toUpperCase(), color: _getTypeColor(type)),
              _Badge(text: status.toUpperCase(), color: isResolved ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Reason for Report', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text(report['reason'] ?? 'Violation of community guidelines', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
          const SizedBox(height: 12),
          Text(report['description'] ?? '', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569))),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 12, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text(_formatDate(report['created_at']), style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
              const Spacer(),
              if (!isResolved)
                ElevatedButton(
                  onPressed: () => _showResolveDialog(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Take Action'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'user': return const Color(0xFFEF4444);
      case 'product': return const Color(0xFF10B981);
      case 'comment': return const Color(0xFF3B82F6);
      default: return const Color(0xFF64748B);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}/${date.day}/${date.year}';
    } catch (_) { return '-'; }
  }

  void _showResolveDialog(BuildContext context) {
    final notesController = TextEditingController();
    final authService = AuthService();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Resolve Report', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Please provide resolution notes for this moderation action.', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. Content removed, User warned...',
                hintStyle: GoogleFonts.inter(fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                fillColor: const Color(0xFFFAFAFA),
                filled: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await adminService.resolveReport(
                reportId: report['report_id'] ?? '',
                adminId: authService.userId,
                resolutionNotes: notesController.text.isEmpty ? 'Action taken by admin' : notesController.text,
              );
              if (context.mounted) {
                Navigator.pop(context);
                onReload();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
