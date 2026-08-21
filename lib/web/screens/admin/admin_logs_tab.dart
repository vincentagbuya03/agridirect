import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/admin/admin_service.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'admin_ui.dart';

enum _LogSeverity { critical, warning, info }

class _ActionMeta {
  final String label;
  final String domain;
  final _LogSeverity severity;
  final IconData icon;

  const _ActionMeta({
    required this.label,
    required this.domain,
    required this.severity,
    required this.icon,
  });
}

class AdminLogsTab extends StatefulWidget {
  final AdminService adminService;
  const AdminLogsTab({super.key, required this.adminService});

  @override
  State<AdminLogsTab> createState() => _AdminLogsTabState();
}

class _AdminLogsTabState extends State<AdminLogsTab> {
  // Navigation, Search & Filters
  String _severityFilter = 'all'; // 'all', 'critical', 'warning', 'info'
  String _selectedDomain = 'ALL'; // 'ALL', 'Security', 'Users', 'Products', 'Orders', 'Content'
  String _selectedRole = 'ALL'; // 'ALL', 'admin', 'farmer', 'customer', 'system'
  bool _isTableView = false; // Timeline vs Table
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Data & State
  late Future<List<Map<String, dynamic>>> _logsFuture;
  List<Map<String, dynamic>> _rawLogs = [];
  bool _isLoading = true;
  late VoidCallback _dataRefreshListener;

  // Pagination
  int _currentPage = 0;
  final int _pageSize = 15;

  // Action dictionary mapping raw database codes to rich metadata
  static const Map<String, _ActionMeta> _actionMap = {
    // Security & Roles
    'grant_admin_role': _ActionMeta(
      label: 'Admin Privilege Granted',
      domain: 'Security',
      severity: _LogSeverity.critical,
      icon: Icons.shield_rounded,
    ),
    'remove_admin_role': _ActionMeta(
      label: 'Admin Privilege Revoked',
      domain: 'Security',
      severity: _LogSeverity.critical,
      icon: Icons.shield_outlined,
    ),
    'update_user_role': _ActionMeta(
      label: 'User Role Modified',
      domain: 'Security',
      severity: _LogSeverity.warning,
      icon: Icons.admin_panel_settings_rounded,
    ),

    // User Accounts & Moderation
    'delete_user': _ActionMeta(
      label: 'User Account Deleted',
      domain: 'Users',
      severity: _LogSeverity.critical,
      icon: Icons.person_remove_rounded,
    ),
    'suspend_user': _ActionMeta(
      label: 'User Account Suspended',
      domain: 'Users',
      severity: _LogSeverity.critical,
      icon: Icons.block_rounded,
    ),
    'unsuspend_user': _ActionMeta(
      label: 'User Account Restored',
      domain: 'Users',
      severity: _LogSeverity.info,
      icon: Icons.check_circle_outline_rounded,
    ),
    'verify_user': _ActionMeta(
      label: 'Identity Verified',
      domain: 'Users',
      severity: _LogSeverity.info,
      icon: Icons.verified_user_rounded,
    ),
    'approve_farmer': _ActionMeta(
      label: 'Farmer Approved',
      domain: 'Users',
      severity: _LogSeverity.info,
      icon: Icons.agriculture_rounded,
    ),
    'reject_farmer': _ActionMeta(
      label: 'Farmer Application Rejected',
      domain: 'Users',
      severity: _LogSeverity.warning,
      icon: Icons.cancel_outlined,
    ),

    // Products & Catalog
    'approve_product': _ActionMeta(
      label: 'Product Approved & Live',
      domain: 'Products',
      severity: _LogSeverity.info,
      icon: Icons.check_circle_rounded,
    ),
    'reject_product': _ActionMeta(
      label: 'Product Listing Rejected',
      domain: 'Products',
      severity: _LogSeverity.warning,
      icon: Icons.cancel_outlined,
    ),
    'product_created': _ActionMeta(
      label: 'Product Listed',
      domain: 'Products',
      severity: _LogSeverity.info,
      icon: Icons.add_box_rounded,
    ),
    'product_updated': _ActionMeta(
      label: 'Product Details Updated',
      domain: 'Products',
      severity: _LogSeverity.info,
      icon: Icons.edit_rounded,
    ),
    'product_archived': _ActionMeta(
      label: 'Product Archived',
      domain: 'Products',
      severity: _LogSeverity.warning,
      icon: Icons.archive_rounded,
    ),
    'delete_product': _ActionMeta(
      label: 'Product Deleted',
      domain: 'Products',
      severity: _LogSeverity.warning,
      icon: Icons.inventory_2_outlined,
    ),
    'create_category': _ActionMeta(
      label: 'Category Created',
      domain: 'Products',
      severity: _LogSeverity.info,
      icon: Icons.category_rounded,
    ),
    'update_category': _ActionMeta(
      label: 'Category Modified',
      domain: 'Products',
      severity: _LogSeverity.info,
      icon: Icons.edit_rounded,
    ),
    'delete_category': _ActionMeta(
      label: 'Category Deleted',
      domain: 'Products',
      severity: _LogSeverity.warning,
      icon: Icons.delete_outline_rounded,
    ),
    'create_unit': _ActionMeta(
      label: 'Unit Created',
      domain: 'Products',
      severity: _LogSeverity.info,
      icon: Icons.straighten_rounded,
    ),
    'update_unit': _ActionMeta(
      label: 'Unit Updated',
      domain: 'Products',
      severity: _LogSeverity.info,
      icon: Icons.edit_rounded,
    ),
    'delete_unit': _ActionMeta(
      label: 'Unit Deleted',
      domain: 'Products',
      severity: _LogSeverity.warning,
      icon: Icons.delete_outline_rounded,
    ),

    // Orders & Commerce
    'order_created': _ActionMeta(
      label: 'Order Placed',
      domain: 'Orders',
      severity: _LogSeverity.info,
      icon: Icons.shopping_bag_rounded,
    ),
    'preorder_created': _ActionMeta(
      label: 'Pre-order Placed',
      domain: 'Orders',
      severity: _LogSeverity.info,
      icon: Icons.event_available_rounded,
    ),
    'order_status_updated': _ActionMeta(
      label: 'Order Status Changed',
      domain: 'Orders',
      severity: _LogSeverity.info,
      icon: Icons.local_shipping_rounded,
    ),
    'order_cancelled': _ActionMeta(
      label: 'Order Cancelled',
      domain: 'Orders',
      severity: _LogSeverity.warning,
      icon: Icons.cancel_outlined,
    ),

    // Content & Forum
    'create_article': _ActionMeta(
      label: 'Publication Created',
      domain: 'Content',
      severity: _LogSeverity.info,
      icon: Icons.article_rounded,
    ),
    'update_article': _ActionMeta(
      label: 'Publication Updated',
      domain: 'Content',
      severity: _LogSeverity.info,
      icon: Icons.edit_note_rounded,
    ),
    'update_article_audience': _ActionMeta(
      label: 'Target Audience Changed',
      domain: 'Content',
      severity: _LogSeverity.info,
      icon: Icons.people_alt_rounded,
    ),
    'update_article_status': _ActionMeta(
      label: 'Article Status Changed',
      domain: 'Content',
      severity: _LogSeverity.info,
      icon: Icons.toggle_on_rounded,
    ),
    'delete_article': _ActionMeta(
      label: 'Publication Deleted',
      domain: 'Content',
      severity: _LogSeverity.warning,
      icon: Icons.delete_outline_rounded,
    ),
    'delete_forum_post': _ActionMeta(
      label: 'Forum Post Removed',
      domain: 'Content',
      severity: _LogSeverity.warning,
      icon: Icons.delete_sweep_rounded,
    ),
    'pin_forum_post': _ActionMeta(
      label: 'Forum Post Pinned',
      domain: 'Content',
      severity: _LogSeverity.info,
      icon: Icons.push_pin_rounded,
    ),
    'resolve_report': _ActionMeta(
      label: 'Moderation Report Resolved',
      domain: 'Content',
      severity: _LogSeverity.info,
      icon: Icons.flag_rounded,
    ),
    'send_announcement': _ActionMeta(
      label: 'Broadcast Announcement Sent',
      domain: 'Content',
      severity: _LogSeverity.info,
      icon: Icons.campaign_rounded,
    ),

    // Sessions & Traffic
    'user_session_start': _ActionMeta(
      label: 'User Authentication',
      domain: 'Sessions',
      severity: _LogSeverity.info,
      icon: Icons.person_outline_rounded,
    ),
    'farmer_session_start': _ActionMeta(
      label: 'Farmer Activity',
      domain: 'Sessions',
      severity: _LogSeverity.info,
      icon: Icons.agriculture_rounded,
    ),
    'customer_session_start': _ActionMeta(
      label: 'Customer Activity',
      domain: 'Sessions',
      severity: _LogSeverity.info,
      icon: Icons.shopping_bag_outlined,
    ),
  };

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
    _logsFuture = widget.adminService.getSystemActivityLogs(pageSize: 150);

    try {
      final logs = await _logsFuture;
      if (mounted) {
        setState(() {
          _rawLogs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  _ActionMeta _getMeta(String action) {
    return _actionMap[action] ??
        _ActionMeta(
          label: action.replaceAll('_', ' ').toUpperCase(),
          domain: 'System',
          severity: _LogSeverity.info,
          icon: Icons.event_note_rounded,
        );
  }

  Color _severityColor(_LogSeverity s) {
    switch (s) {
      case _LogSeverity.critical:
        return AdminUi.danger;
      case _LogSeverity.warning:
        return const Color(0xFFF59E0B);
      case _LogSeverity.info:
        return const Color(0xFF10B981);
    }
  }

  List<Map<String, dynamic>> _getFilteredLogs() {
    var filtered = List<Map<String, dynamic>>.from(_rawLogs);

    // Filter by Severity Tab
    if (_severityFilter != 'all') {
      filtered = filtered.where((l) {
        final meta = _getMeta(l['action'] ?? '');
        if (_severityFilter == 'critical') return meta.severity == _LogSeverity.critical;
        if (_severityFilter == 'warning') return meta.severity == _LogSeverity.warning;
        if (_severityFilter == 'info') return meta.severity == _LogSeverity.info;
        return true;
      }).toList();
    }

    // Filter by Domain
    if (_selectedDomain != 'ALL') {
      filtered = filtered.where((l) {
        final meta = _getMeta(l['action'] ?? '');
        return meta.domain.toLowerCase() == _selectedDomain.toLowerCase();
      }).toList();
    }

    // Filter by Actor Role
    if (_selectedRole != 'ALL') {
      filtered = filtered.where((l) {
        final role = (l['actor_role'] ?? '').toString().toLowerCase();
        final name = (l['actor_name'] ?? l['admin_name'] ?? '').toString().toLowerCase();
        if (_selectedRole == 'admin') return role.contains('admin') || name.contains('admin');
        if (_selectedRole == 'farmer') return role.contains('farmer');
        if (_selectedRole == 'customer') return role.contains('customer') || role.contains('buyer');
        if (_selectedRole == 'system') return role.contains('system') || name.contains('system');
        return true;
      }).toList();
    }

    // Filter by Search Query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      filtered = filtered.where((l) {
        final action = (l['action'] ?? '').toString().toLowerCase();
        final details = (l['details'] ?? '').toString().toLowerCase();
        final adminName = (l['admin_name'] ?? '').toString().toLowerCase();
        final actorName = (l['actor_name'] ?? '').toString().toLowerCase();
        final actorRole = (l['actor_role'] ?? '').toString().toLowerCase();
        final meta = _getMeta(l['action'] ?? '');
        return action.contains(q) ||
            details.contains(q) ||
            adminName.contains(q) ||
            actorName.contains(q) ||
            actorRole.contains(q) ||
            meta.label.toLowerCase().contains(q) ||
            meta.domain.toLowerCase().contains(q);
      }).toList();
    }

    return filtered;
  }

  void _inspectLogPayload(Map<String, dynamic> log) {
    final action = (log['action'] ?? 'system_event').toString();
    final details = (log['details'] ?? 'No detail text provided').toString();
    final actorName = (log['actor_name'] ?? log['admin_name'] ?? 'System Engine').toString();
    final actorRole = (log['actor_role'] ?? 'Platform Automated').toString();
    final meta = _getMeta(action);
    final color = _severityColor(meta.severity);
    final dateStr = log['created_at'] != null
        ? DateFormat('EEEE, MMMM d, yyyy • h:mm:ss a').format(DateTime.parse(log['created_at']).toLocal())
        : 'Unknown Timestamp';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(meta.icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          meta.severity.name.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: color),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(meta.domain.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: AdminUi.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(meta.label, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AdminUi.textPrimary)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 20, color: Color(0xFFF1F5F9)),

                // Timestamp & Actor Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _inspectorField('OCCURRED ON', dateStr),
                      const SizedBox(height: 8),
                      _inspectorField('ACTOR / INITIATOR', '$actorName ($actorRole)'),
                      if (log['admin_id'] != null || log['actor_id'] != null) ...[
                        const SizedBox(height: 8),
                        _inspectorField('USER / ACTOR ID', '${log['admin_id'] ?? log['actor_id']}'),
                      ],
                      const SizedBox(height: 8),
                      _inspectorField('RAW ACTION CODE', action),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Event Description Box
                Text('EVENT DETAILS & SUMMARY', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: AdminUi.textMuted, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    details,
                    style: GoogleFonts.inter(fontSize: 13, color: AdminUi.textPrimary, height: 1.5),
                  ),
                ),
                const SizedBox(height: 16),

                // Raw JSON Payload Inspector
                Text('FULL LOG PAYLOAD', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: AdminUi.textMuted, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert(log),
                    style: GoogleFonts.firaCode(fontSize: 11, color: const Color(0xFF38BDF8), height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(log)));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Log JSON payload copied to clipboard.'), backgroundColor: Color(0xFF059669)),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy JSON'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: AdminUi.primaryButton,
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _inspectorField(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: AdminUi.textMuted, letterSpacing: 0.5)),
        ),
        Expanded(
          child: SelectableText(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AdminUi.textPrimary)),
        ),
      ],
    );
  }

  void _showExportDialog() {
    final filtered = _getFilteredLogs();
    final jsonString = const JsonEncoder.withIndent('  ').convert(filtered);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Export Audit Log Stream', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 540,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ready to export ${filtered.length} filtered activity records for compliance and offline analysis.',
                style: GoogleFonts.inter(fontSize: 13, color: AdminUi.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  'Format: JSON Dataset\nRecords: ${filtered.length}\nDate Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                  style: GoogleFonts.firaCode(fontSize: 11, color: AdminUi.textSecondary),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonString));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${filtered.length} log records copied to clipboard as JSON!'), backgroundColor: const Color(0xFF059669)),
              );
            },
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Copy JSON Export'),
            style: AdminUi.primaryButton,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _getFilteredLogs();
    final totalCount = filteredLogs.length;
    final startIndex = _currentPage * _pageSize;
    final endIndex = (startIndex + _pageSize) > totalCount ? totalCount : (startIndex + _pageSize);
    final pagedLogs = totalCount == 0 ? <Map<String, dynamic>>[] : filteredLogs.sublist(startIndex, endIndex);

    return AdminPageFrame(
      child: SingleChildScrollView(
        padding: AdminUi.pagePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildExecutiveHeader(context),
            const SizedBox(height: 24),
            _buildSecurityKpiMatrix(context),
            const SizedBox(height: 28),
            _buildAuditToolbar(context),
            const SizedBox(height: 20),
            if (_isLoading)
              _buildLoadingState()
            else if (filteredLogs.isEmpty)
              _buildEmptyState()
            else ...[
              if (_isTableView)
                _buildCompactTableView(pagedLogs)
              else
                _buildTimelineFeed(pagedLogs),
              const SizedBox(height: 16),
              _buildPaginationBar(context, totalCount, startIndex, endIndex),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. EXECUTIVE SECURITY HEADER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildExecutiveHeader(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 28),
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
                _buildHeaderPulseBadge(),
                const SizedBox(height: 12),
                Text('System Audit & Security Logs', style: AdminUi.display(context, size: 24)),
                const SizedBox(height: 6),
                Text(
                  'Chronological, tamper-evident audit trail of administrative modifications, security events, and platform activity.',
                  style: AdminUi.body(size: 13, color: AdminUi.textSecondary),
                ),
                const SizedBox(height: 18),
                _buildHeaderActions(),
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
                      _buildHeaderPulseBadge(),
                      const SizedBox(height: 8),
                      Text('System Audit & Security Logs', style: AdminUi.display(context, size: 28)),
                      const SizedBox(height: 4),
                      Text(
                        'Chronological, tamper-evident audit trail of administrative modifications, security events, and platform activity.',
                        style: AdminUi.body(size: 14, color: AdminUi.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                _buildHeaderActions(),
              ],
            ),
    );
  }

  Widget _buildHeaderPulseBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AdminUi.brandSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AdminUi.brand,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'AUDIT TRAIL RECORDING ACTIVE',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AdminUi.brand,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActions() {
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
          label: const Text('Refresh Stream'),
        ),
        ElevatedButton.icon(
          onPressed: _showExportDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminUi.brand,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: Text('Export Logs', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. SECURITY KPI MATRIX (4 Cards)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSecurityKpiMatrix(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final int crossAxisCount = width > 1200 ? 4 : (width > 700 ? 2 : 1);

    int criticalCount = 0;
    int warningCount = 0;
    int infoCount = 0;

    for (final l in _rawLogs) {
      final meta = _getMeta(l['action'] ?? '');
      if (meta.severity == _LogSeverity.critical) {
        criticalCount++;
      } else if (meta.severity == _LogSeverity.warning) {
        warningCount++;
      } else {
        infoCount++;
      }
    }

    final metrics = [
      _kpiCard(
        title: 'TOTAL EVENTS LOGGED',
        value: '${_rawLogs.length}',
        subtitle: 'Activity stream count',
        icon: Icons.list_alt_rounded,
        color: AdminUi.brand,
        badge: 'Audit Stream',
      ),
      _kpiCard(
        title: 'CRITICAL SECURITY',
        value: '$criticalCount',
        subtitle: 'Role changes & suspensions',
        icon: Icons.shield_rounded,
        color: const Color(0xFFEF4444),
        badge: criticalCount > 0 ? 'High Priority' : 'Zero Threats',
      ),
      _kpiCard(
        title: 'OPERATIONAL WARNINGS',
        value: '$warningCount',
        subtitle: 'Cancellations & rejections',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFF59E0B),
        badge: 'Moderation',
      ),
      _kpiCard(
        title: 'STANDARD OPERATIONS',
        value: '$infoCount',
        subtitle: 'Routine system events',
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF10B981),
        badge: 'Normal Flow',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (crossAxisCount == 1) {
          return Column(
            children: metrics.map((m) => Padding(padding: const EdgeInsets.only(bottom: 12), child: m)).toList(),
          );
        }

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          mainAxisExtent: 144,
          children: metrics,
        );
      },
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AdminUi.textMuted,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
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
                  fontSize: 11,
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
  // 3. AUDIT COMMAND TOOLBAR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAuditToolbar(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 980;

    int critical = _rawLogs.where((l) => _getMeta(l['action'] ?? '').severity == _LogSeverity.critical).length;
    int warning = _rawLogs.where((l) => _getMeta(l['action'] ?? '').severity == _LogSeverity.warning).length;
    int info = _rawLogs.where((l) => _getMeta(l['action'] ?? '').severity == _LogSeverity.info).length;

    return Container(
      padding: const EdgeInsets.all(18),
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
          // Row 1: Severity Tabs + View Switcher
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _severityTab(
                      label: 'All Events',
                      count: '${_rawLogs.length}',
                      isActive: _severityFilter == 'all',
                      onTap: () => setState(() {
                        _severityFilter = 'all';
                        _currentPage = 0;
                      }),
                    ),
                    const SizedBox(width: 8),
                    _severityTab(
                      label: 'Critical',
                      count: '$critical',
                      isActive: _severityFilter == 'critical',
                      badgeColor: const Color(0xFFEF4444),
                      onTap: () => setState(() {
                        _severityFilter = 'critical';
                        _currentPage = 0;
                      }),
                    ),
                    const SizedBox(width: 8),
                    _severityTab(
                      label: 'Warnings',
                      count: '$warning',
                      isActive: _severityFilter == 'warning',
                      badgeColor: const Color(0xFFF59E0B),
                      onTap: () => setState(() {
                        _severityFilter = 'warning';
                        _currentPage = 0;
                      }),
                    ),
                    const SizedBox(width: 8),
                    _severityTab(
                      label: 'Info / Operations',
                      count: '$info',
                      isActive: _severityFilter == 'info',
                      badgeColor: const Color(0xFF10B981),
                      onTap: () => setState(() {
                        _severityFilter = 'info';
                        _currentPage = 0;
                      }),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                // View Mode Toggle (Timeline vs Table)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _viewSwitchButton(
                        icon: Icons.timeline_rounded,
                        tooltip: 'Timeline Stream',
                        isActive: !_isTableView,
                        onTap: () => setState(() => _isTableView = false),
                      ),
                      _viewSwitchButton(
                        icon: Icons.table_chart_rounded,
                        tooltip: 'Compact Audit Table',
                        isActive: _isTableView,
                        onTap: () => setState(() => _isTableView = true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),

          // Row 2: Search Box + Domain Filter + Role Filter
          isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSearchField(),
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildDomainDropdown(),
                          const SizedBox(width: 12),
                          _buildRoleDropdown(),
                        ],
                      ),
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
                    _buildDomainDropdown(),
                    const SizedBox(width: 12),
                    _buildRoleDropdown(),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _severityTab({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? activeColor : AdminUi.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
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

  Widget _viewSwitchButton({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isActive
                ? const [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))]
                : null,
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive ? AdminUi.brand : AdminUi.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (val) => setState(() {
        _searchQuery = val;
        _currentPage = 0;
      }),
      decoration: InputDecoration(
        hintText: 'Search by action, details, admin/actor name, or target ID...',
        hintStyle: GoogleFonts.inter(fontSize: 13, color: AdminUi.textMuted),
        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AdminUi.textMuted),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 16, color: AdminUi.textMuted),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _currentPage = 0;
                  });
                },
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminUi.brand, width: 1.5)),
      ),
    );
  }

  Widget _buildDomainDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedDomain,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AdminUi.textMuted),
          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AdminUi.textPrimary),
          items: const [
            DropdownMenuItem(value: 'ALL', child: Text('All Action Domains')),
            DropdownMenuItem(value: 'Security', child: Text('Security & Roles')),
            DropdownMenuItem(value: 'Users', child: Text('User Accounts')),
            DropdownMenuItem(value: 'Products', child: Text('Products & Catalog')),
            DropdownMenuItem(value: 'Orders', child: Text('Orders & Commerce')),
            DropdownMenuItem(value: 'Content', child: Text('Content & Forum')),
            DropdownMenuItem(value: 'Sessions', child: Text('Traffic Sessions')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedDomain = val;
                _currentPage = 0;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRole,
          icon: const Icon(Icons.person_search_rounded, size: 16, color: AdminUi.textMuted),
          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AdminUi.textPrimary),
          items: const [
            DropdownMenuItem(value: 'ALL', child: Text('All Actor Roles')),
            DropdownMenuItem(value: 'admin', child: Text('Administrators')),
            DropdownMenuItem(value: 'farmer', child: Text('Farmers')),
            DropdownMenuItem(value: 'customer', child: Text('Customers')),
            DropdownMenuItem(value: 'system', child: Text('System Engine')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedRole = val;
                _currentPage = 0;
              });
            }
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. TIMELINE AUDIT FEED
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTimelineFeed(List<Map<String, dynamic>> logs) {
    // Group logs by date
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final log in logs) {
      final dateStr = log['created_at'] != null
          ? DateFormat('EEEE, MMMM d, yyyy').format(DateTime.parse(log['created_at']).toLocal())
          : 'Historical Events';
      grouped.putIfAbsent(dateStr, () => []).add(log);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: grouped.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sticky-Style Date Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: AdminUi.brand),
                    const SizedBox(width: 8),
                    Text(
                      entry.key,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AdminUi.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AdminUi.brandSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${entry.value.length} events',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AdminUi.brand,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              // Timeline Entries for this date
              ...entry.value.asMap().entries.map((e) {
                final isLast = e.key == entry.value.length - 1;
                return _buildTimelineRow(e.value, isLast: isLast);
              }),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimelineRow(Map<String, dynamic> log, {bool isLast = false}) {
    final action = (log['action'] ?? 'system_event').toString();
    final details = (log['details'] ?? 'No detail text provided').toString();
    final actorName = (log['actor_name'] ?? log['admin_name'] ?? 'System Engine').toString();
    final actorRole = (log['actor_role'] ?? 'Platform').toString();
    final createdAt = log['created_at'] != null
        ? DateFormat('h:mm a').format(DateTime.parse(log['created_at']).toLocal())
        : '';
    final meta = _getMeta(action);
    final color = _severityColor(meta.severity);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline line + pulse dot
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 20),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(width: 1.5, color: const Color(0xFFE2E8F0)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Interactive Event Card
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _inspectLogPayload(log),
                    borderRadius: BorderRadius.circular(10),
                    hoverColor: const Color(0xFFF8FAFC),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Action Label + Domain Pill + Timestamp
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(meta.icon, size: 14, color: color),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    meta.label,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AdminUi.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      meta.domain.toUpperCase(),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: AdminUi.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    createdAt,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AdminUi.textMuted,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.chevron_right_rounded, size: 16, color: AdminUi.textMuted),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Details Description
                          Text(
                            details,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AdminUi.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Footer: Actor info
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: AdminUi.brandSoft,
                                child: Text(
                                  actorName.isNotEmpty ? actorName[0].toUpperCase() : 'S',
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AdminUi.brand),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                actorName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AdminUi.textPrimary,
                                ),
                              ),
                              if (actorRole.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text('•', style: TextStyle(color: AdminUi.textMuted, fontSize: 10)),
                                const SizedBox(width: 6),
                                Text(
                                  actorRole,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AdminUi.textMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. COMPACT AUDIT TABLE VIEW
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCompactTableView(List<Map<String, dynamic>> logs) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 900,
          child: Column(
            children: [
              // Table Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  children: [
                    _tableHeaderCell('SEVERITY', flex: 2),
                    _tableHeaderCell('ACTION / DOMAIN', flex: 3),
                    _tableHeaderCell('EVENT DETAILS', flex: 4),
                    _tableHeaderCell('ACTOR / ROLE', flex: 3),
                    _tableHeaderCell('TIME', flex: 2),
                    _tableHeaderCell('INSPECT', flex: 1),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              // Table Rows
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: logs.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final action = (log['action'] ?? 'system_event').toString();
                  final details = (log['details'] ?? 'No detail text').toString();
                  final actorName = (log['actor_name'] ?? log['admin_name'] ?? 'System').toString();
                  final actorRole = (log['actor_role'] ?? '').toString();
                  final meta = _getMeta(action);
                  final color = _severityColor(meta.severity);
                  final dateStr = log['created_at'] != null
                      ? DateFormat('MMM d, HH:mm').format(DateTime.parse(log['created_at']).toLocal())
                      : 'N/A';

                  return Material(
                    color: Colors.white,
                    child: InkWell(
                      onTap: () => _inspectLogPayload(log),
                      hoverColor: const Color(0xFFF8FAFC),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        child: Row(
                          children: [
                            // Severity Badge
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      meta.severity.name.toUpperCase(),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Action & Domain
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  Icon(meta.icon, size: 14, color: color),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      meta.label,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AdminUi.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Details
                            Expanded(
                              flex: 4,
                              child: Text(
                                details,
                                style: GoogleFonts.inter(fontSize: 12, color: AdminUi.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Actor
                            Expanded(
                              flex: 3,
                              child: Text(
                                actorRole.isNotEmpty ? '$actorName ($actorRole)' : actorName,
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AdminUi.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Time
                            Expanded(
                              flex: 2,
                              child: Text(
                                dateStr,
                                style: GoogleFonts.inter(fontSize: 11, color: AdminUi.textMuted),
                              ),
                            ),
                            // Action Button
                            Expanded(
                              flex: 1,
                              child: IconButton(
                                icon: const Icon(Icons.visibility_outlined, size: 16, color: AdminUi.brand),
                                onPressed: () => _inspectLogPayload(log),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tableHeaderCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AdminUi.textMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. RESPONSIVE PAGINATION BAR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPaginationBar(BuildContext context, int totalCount, int startRange, int endRange) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    final infoText = Text(
      totalCount > 0
          ? 'Showing ${startRange + 1}–$endRange of $totalCount activity logs'
          : 'No log records match current filter',
      style: GoogleFonts.inter(fontSize: 13, color: AdminUi.textSecondary),
    );

    final controlsRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(
          onPressed: _currentPage > 0
              ? () => setState(() => _currentPage--)
              : null,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: const Row(
            children: [
              Icon(Icons.chevron_left_rounded, size: 16),
              SizedBox(width: 4),
              Text('Previous'),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AdminUi.brandSoft,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Page ${_currentPage + 1}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AdminUi.brand,
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: endRange < totalCount
              ? () => setState(() => _currentPage++)
              : null,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: const Row(
            children: [
              Text('Next'),
              SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 16),
            ],
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                infoText,
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: controlsRow,
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                infoText,
                controlsRow,
              ],
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
      padding: const EdgeInsets.all(60),
      child: const Center(child: AppShimmerLoader(color: AdminUi.brand)),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_toggle_off_rounded, size: 40, color: AdminUi.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No activity logs match "$_searchQuery"'
                  : 'No logs match the selected filters',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AdminUi.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Try clearing your search query or selecting "All Action Domains".',
              style: GoogleFonts.inter(fontSize: 13, color: AdminUi.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
