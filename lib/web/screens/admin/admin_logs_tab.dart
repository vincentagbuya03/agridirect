import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/admin/admin_service.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'admin_ui.dart';

class AdminLogsTab extends StatefulWidget {
  final AdminService adminService;
  const AdminLogsTab({super.key, required this.adminService});

  @override
  State<AdminLogsTab> createState() => _AdminLogsTabState();
}

class _AdminLogsTabState extends State<AdminLogsTab> {
  late Future<List<Map<String, dynamic>>> _logsFuture;
  String _searchQuery = '';
  String _filterAction = 'all';
  String _severityFilter = 'all'; // all, critical, warning, info

  // Action → human label + severity mapping
  static const Map<String, _ActionMeta> _actionMap = {
    'delete_user': _ActionMeta(
      'User Deleted',
      _Severity.critical,
      Icons.person_remove_rounded,
    ),
    'suspend_user': _ActionMeta(
      'User Suspended',
      _Severity.critical,
      Icons.block_rounded,
    ),
    'unsuspend_user': _ActionMeta(
      'User Unsuspended',
      _Severity.info,
      Icons.check_circle_outline_rounded,
    ),
    'delete_forum_post': _ActionMeta(
      'Post Removed',
      _Severity.warning,
      Icons.delete_sweep_rounded,
    ),
    'pin_forum_post': _ActionMeta(
      'Post Pinned',
      _Severity.info,
      Icons.push_pin_rounded,
    ),
    'delete_product': _ActionMeta(
      'Product Removed',
      _Severity.warning,
      Icons.inventory_2_outlined,
    ),
    'reject_product': _ActionMeta(
      'Product Rejected',
      _Severity.warning,
      Icons.cancel_outlined,
    ),
    'verify_user': _ActionMeta(
      'User Verified',
      _Severity.info,
      Icons.verified_user_rounded,
    ),
    'approve_product': _ActionMeta(
      'Product Approved',
      _Severity.info,
      Icons.check_circle_rounded,
    ),
    'approve_farmer': _ActionMeta(
      'Farmer Approved',
      _Severity.info,
      Icons.agriculture_rounded,
    ),
    'reject_farmer': _ActionMeta(
      'Farmer Rejected',
      _Severity.warning,
      Icons.cancel_outlined,
    ),
    'update_user_role': _ActionMeta(
      'Role Changed',
      _Severity.warning,
      Icons.admin_panel_settings_rounded,
    ),
    'create_article': _ActionMeta(
      'Article Created',
      _Severity.info,
      Icons.article_rounded,
    ),
    'update_article': _ActionMeta(
      'Article Updated',
      _Severity.info,
      Icons.edit_note_rounded,
    ),
    'update_article_audience': _ActionMeta(
      'Audience Changed',
      _Severity.info,
      Icons.people_alt_rounded,
    ),
    'update_article_status': _ActionMeta(
      'Article Status',
      _Severity.info,
      Icons.toggle_on_rounded,
    ),
    'delete_article': _ActionMeta(
      'Article Deleted',
      _Severity.warning,
      Icons.delete_outline_rounded,
    ),
    'create_category': _ActionMeta(
      'Category Created',
      _Severity.info,
      Icons.category_rounded,
    ),
    'update_category': _ActionMeta(
      'Category Updated',
      _Severity.info,
      Icons.edit_rounded,
    ),
    'delete_category': _ActionMeta(
      'Category Deleted',
      _Severity.warning,
      Icons.delete_outline_rounded,
    ),
    'create_unit': _ActionMeta(
      'Unit Created',
      _Severity.info,
      Icons.straighten_rounded,
    ),
    'update_unit': _ActionMeta(
      'Unit Updated',
      _Severity.info,
      Icons.edit_rounded,
    ),
    'delete_unit': _ActionMeta(
      'Unit Deleted',
      _Severity.warning,
      Icons.delete_outline_rounded,
    ),
    'resolve_report': _ActionMeta(
      'Report Resolved',
      _Severity.info,
      Icons.flag_rounded,
    ),
    'send_announcement': _ActionMeta(
      'Announcement Sent',
      _Severity.info,
      Icons.campaign_rounded,
    ),
    'user_session_start': _ActionMeta(
      'User Session',
      _Severity.info,
      Icons.person_outline_rounded,
    ),
    'farmer_session_start': _ActionMeta(
      'Farmer Activity',
      _Severity.info,
      Icons.agriculture_rounded,
    ),
    'customer_session_start': _ActionMeta(
      'Customer Activity',
      _Severity.info,
      Icons.shopping_bag_outlined,
    ),
    'grant_admin_role': _ActionMeta(
      'Admin Granted',
      _Severity.critical,
      Icons.shield_rounded,
    ),
    'remove_admin_role': _ActionMeta(
      'Admin Revoked',
      _Severity.critical,
      Icons.shield_outlined,
    ),
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _logsFuture = widget.adminService.getSystemActivityLogs(
        actionFilter: _filterAction,
      );
    });
  }

  _ActionMeta _getMeta(String action) {
    return _actionMap[action] ??
        _ActionMeta(
          action.replaceAll('_', ' '),
          _Severity.info,
          Icons.event_note_rounded,
        );
  }

  Color _severityColor(_Severity s) {
    switch (s) {
      case _Severity.critical:
        return AdminUi.danger;
      case _Severity.warning:
        return AdminUi.warning;
      case _Severity.info:
        return AdminUi.brand;
    }
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> logs) {
    var filtered = logs;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((l) {
        final action = (l['action'] ?? '').toString().toLowerCase();
        final details = (l['details'] ?? '').toString().toLowerCase();
        final name = (l['admin_name'] ?? '').toString().toLowerCase();
        final actorName = (l['actor_name'] ?? '').toString().toLowerCase();
        final actorRole = (l['actor_role'] ?? '').toString().toLowerCase();
        return action.contains(_searchQuery) ||
            details.contains(_searchQuery) ||
            name.contains(_searchQuery) ||
            actorName.contains(_searchQuery) ||
            actorRole.contains(_searchQuery);
      }).toList();
    }

    if (_severityFilter != 'all') {
      filtered = filtered.where((l) {
        final meta = _getMeta(l['action'] ?? '');
        switch (_severityFilter) {
          case 'critical':
            return meta.severity == _Severity.critical;
          case 'warning':
            return meta.severity == _Severity.warning;
          case 'info':
            return meta.severity == _Severity.info;
          default:
            return true;
        }
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: SingleChildScrollView(
        padding: AdminUi.pagePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildSeverityCards(),
            const SizedBox(height: 24),
            _buildToolbar(),
            const SizedBox(height: 16),
            _buildLogsList(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF065F46)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AdminUi.radiusLg,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF064E3B).withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: AdminUi.radiusFull,
                  ),
                  child: Text(
                    'AUDIT TRAIL',
                    style: AdminUi.label(
                      size: 10,
                      color: Colors.white.withValues(alpha: 0.9),
                      weight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'System Activity Logs',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Real-time monitoring of all administrative actions, user changes, and system events.',
                  style: AdminUi.body(
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: AdminUi.radiusMd,
            ),
            child: Icon(
              Icons.shield_rounded,
              size: 40,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SEVERITY QUICK-FILTER CARDS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSeverityCards() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _logsFuture,
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];
        int critical = 0, warning = 0, info = 0;
        for (final l in logs) {
          final s = _getMeta(l['action'] ?? '').severity;
          if (s == _Severity.critical) {
            critical++;
          } else if (s == _Severity.warning) {
            warning++;
          } else {
            info++;
          }
        }

        return Row(
          children: [
            _severityCard(
              'All Events',
              '${logs.length}',
              Icons.list_alt_rounded,
              AdminUi.brand,
              'all',
            ),
            const SizedBox(width: 16),
            _severityCard(
              'Critical',
              '$critical',
              Icons.error_rounded,
              AdminUi.danger,
              'critical',
            ),
            const SizedBox(width: 16),
            _severityCard(
              'Warnings',
              '$warning',
              Icons.warning_amber_rounded,
              AdminUi.warning,
              'warning',
            ),
            const SizedBox(width: 16),
            _severityCard(
              'Info',
              '$info',
              Icons.info_outline_rounded,
              AdminUi.info,
              'info',
            ),
          ],
        );
      },
    );
  }

  Widget _severityCard(
    String label,
    String count,
    IconData icon,
    Color color,
    String filterKey,
  ) {
    final isActive = _severityFilter == filterKey;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _severityFilter = filterKey),
        borderRadius: AdminUi.radiusMd,
        child: AnimatedContainer(
          duration: AdminUi.animFast,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.08) : Colors.white,
            borderRadius: AdminUi.radiusMd,
            border: Border.all(
              color: isActive ? color.withValues(alpha: 0.4) : AdminUi.border,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : AdminUi.shadowSm,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: AdminUi.radiusSm,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AdminUi.textPrimary,
                    ),
                  ),
                  Text(
                    label.toUpperCase(),
                    style: AdminUi.label(
                      size: 9,
                      color: AdminUi.textMuted,
                      weight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
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
  // TOOLBAR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: AdminUi.cardDecoration(),
      child: Row(
        children: [
          // Search
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AdminUi.background,
                borderRadius: AdminUi.radiusMd,
              ),
              child: TextField(
                decoration:
                    AdminUi.inputDecoration(
                      hintText: 'Search by action, details, or admin name...',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AdminUi.textMuted,
                        size: 20,
                      ),
                    ).copyWith(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                onChanged: (v) =>
                    setState(() => _searchQuery = v.toLowerCase()),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Action filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AdminUi.background,
              borderRadius: AdminUi.radiusMd,
            ),
            child: DropdownButton<String>(
              value: _filterAction,
              underline: const SizedBox(),
              icon: const Icon(
                Icons.filter_list_rounded,
                size: 18,
                color: AdminUi.textSecondary,
              ),
              style: AdminUi.label(
                size: 13,
                color: AdminUi.textPrimary,
                weight: FontWeight.w700,
              ),
              onChanged: (v) {
                setState(() => _filterAction = v ?? 'all');
                _loadData();
              },
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Actions')),
                DropdownMenuItem(
                  value: 'verify_user',
                  child: Text('Verifications'),
                ),
                DropdownMenuItem(
                  value: 'update_user_role',
                  child: Text('Role Updates'),
                ),
                DropdownMenuItem(
                  value: 'suspend_user',
                  child: Text('Suspensions'),
                ),
                DropdownMenuItem(
                  value: 'approve_product',
                  child: Text('Product Approval'),
                ),
                DropdownMenuItem(
                  value: 'approve_farmer',
                  child: Text('Farmer Approval'),
                ),
                DropdownMenuItem(
                  value: 'farmer_session_start',
                  child: Text('Farmer Activity'),
                ),
                DropdownMenuItem(
                  value: 'customer_session_start',
                  child: Text('Customer Activity'),
                ),
                DropdownMenuItem(
                  value: 'user_session_start',
                  child: Text('User Sessions'),
                ),
                DropdownMenuItem(
                  value: 'create_article',
                  child: Text('Articles'),
                ),
                DropdownMenuItem(
                  value: 'delete_forum_post',
                  child: Text('Post Deletions'),
                ),
                DropdownMenuItem(
                  value: 'resolve_report',
                  child: Text('Report Resolutions'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('REFRESH'),
            style: AdminUi.secondaryButton,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TIMELINE LOG LIST
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildLogsList() {
    return Container(
      decoration: AdminUi.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _logsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(100),
              child: Center(child: AppShimmerLoader(color: AdminUi.brand)),
            );
          }

          final logs = _applyFilters(snapshot.data ?? []);

          if (logs.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(80),
              child: Column(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 48,
                    color: AdminUi.textMuted.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No activity logs found.',
                    style: AdminUi.body(color: AdminUi.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Adjust your filters or check back later.',
                    style: AdminUi.body(size: 13, color: AdminUi.textMuted),
                  ),
                ],
              ),
            );
          }

          // Group logs by date
          final grouped = <String, List<Map<String, dynamic>>>{};
          for (final log in logs) {
            final date = log['created_at'] != null
                ? DateFormat(
                    'EEEE, MMMM d, yyyy',
                  ).format(DateTime.parse(log['created_at']).toLocal())
                : 'Unknown Date';
            grouped.putIfAbsent(date, () => []).add(log);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: grouped.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    color: AdminUi.panelAlt,
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 13,
                          color: AdminUi.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          entry.key,
                          style: AdminUi.label(
                            size: 12,
                            color: AdminUi.textSecondary,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AdminUi.brand.withValues(alpha: 0.08),
                            borderRadius: AdminUi.radiusFull,
                          ),
                          child: Text(
                            '${entry.value.length} events',
                            style: AdminUi.label(
                              size: 10,
                              color: AdminUi.brand,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Timeline entries
                  ...entry.value.asMap().entries.map(
                    (e) => _buildTimelineRow(
                      e.value,
                      isLast: e.key == entry.value.length - 1,
                    ),
                  ),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildTimelineRow(Map<String, dynamic> log, {bool isLast = false}) {
    final action = (log['action'] ?? 'system_event').toString();
    final details = (log['details'] ?? 'No details').toString();
    final actorName = (log['actor_name'] ?? log['admin_name'] ?? 'System')
        .toString();
    final actorRole = (log['actor_role'] ?? '').toString();
    final createdAt = log['created_at'] != null
        ? DateFormat(
            'h:mm a',
          ).format(DateTime.parse(log['created_at']).toLocal())
        : '';
    final meta = _getMeta(action);
    final color = _severityColor(meta.severity);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline line + dot
            SizedBox(
              width: 32,
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
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(width: 1.5, color: AdminUi.border),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Content card
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 2, top: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AdminUi.radiusSm,
                  border: Border.all(
                    color: AdminUi.border.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    // Action icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: AdminUi.radiusSm,
                      ),
                      child: Icon(meta.icon, size: 16, color: color),
                    ),
                    const SizedBox(width: 14),
                    // Action + Details
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meta.label.toUpperCase(),
                            style: AdminUi.label(
                              size: 11,
                              color: color,
                              weight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            details,
                            style: AdminUi.body(
                              size: 13,
                              color: AdminUi.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Actor name
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: AdminUi.brandSoft,
                            child: Text(
                              actorName.isNotEmpty
                                  ? actorName[0].toUpperCase()
                                  : 'S',
                              style: TextStyle(
                                fontSize: 10,
                                color: AdminUi.brand,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              actorRole.isEmpty
                                  ? actorName
                                  : '$actorName - $actorRole',
                              style: AdminUi.label(
                                size: 12,
                                color: AdminUi.textPrimary,
                                weight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Timestamp
                    SizedBox(
                      width: 80,
                      child: Text(
                        createdAt,
                        textAlign: TextAlign.right,
                        style: AdminUi.label(
                          size: 12,
                          color: AdminUi.textMuted,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════
enum _Severity { critical, warning, info }

class _ActionMeta {
  final String label;
  final _Severity severity;
  final IconData icon;
  const _ActionMeta(this.label, this.severity, this.icon);
}
