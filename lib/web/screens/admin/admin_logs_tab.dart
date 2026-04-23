import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _logsFuture = widget.adminService.getAdminLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: SingleChildScrollView(
        padding: AdminUi.pagePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminHeroCard(
              useGradient: true,
              eyebrow: 'System Integrity',
              title: 'Activity Logs',
              description: 'Comprehensive audit trail of all administrative actions and system updates.',
              metrics: [
                FutureBuilder<Map<String, dynamic>>(
                  future: widget.adminService.getDashboardCounts(),
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    return Row(
                      children: [
                        AdminMiniMetric(
                          label: 'Critical Actions', 
                          value: '${(data?['pending_verifications'] ?? 0)}', 
                          icon: Icons.security_rounded, 
                          color: AdminUi.danger,
                          light: true
                        ),
                        const SizedBox(width: 24),
                        AdminMiniMetric(
                          label: 'Reports Filed', 
                          value: '${data?['pending_reports'] ?? 0}', 
                          icon: Icons.flag_rounded, 
                          color: AdminUi.warning,
                          light: true
                        ),
                        const SizedBox(width: 24),
                        AdminMiniMetric(
                          label: 'System Admins', 
                          value: '${data?['total_admins'] ?? "0"}', 
                          icon: Icons.admin_panel_settings_rounded, 
                          light: true
                        ),
                      ],
                    );
                  }
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AdminUi.radiusLg,
                border: Border.all(color: AdminUi.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _buildToolbar(),
                  const Divider(height: 1, color: AdminUi.border),
                  _buildTableHeader(),
                  const Divider(height: 1, color: AdminUi.border),
                  _buildTableBody(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AdminUi.background,
                borderRadius: AdminUi.radiusMd,
              ),
              child: TextField(
                decoration: AdminUi.inputDecoration(
                  hintText: 'Search logs by details or action...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AdminUi.textMuted, size: 20),
                ).copyWith(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AdminUi.background,
              borderRadius: AdminUi.radiusMd,
            ),
            child: DropdownButton<String>(
              value: _filterAction,
              underline: const SizedBox(),
              icon: const Icon(Icons.filter_list_rounded, size: 18, color: AdminUi.textSecondary),
              style: AdminUi.label(size: 13, color: AdminUi.textPrimary, weight: FontWeight.w700),
              onChanged: (v) => setState(() => _filterAction = v ?? 'all'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Actions')),
                DropdownMenuItem(value: 'verify_user', child: Text('Verifications')),
                DropdownMenuItem(value: 'update_user_role', child: Text('Role Updates')),
                DropdownMenuItem(value: 'delete_user', child: Text('Deletions')),
                DropdownMenuItem(value: 'approve_product', child: Text('Product Approval')),
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

  Widget _buildTableHeader() {
    return Container(
      color: AdminUi.panelAlt,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          _headerCell('Timestamp', flex: 2),
          _headerCell('Action', flex: 2),
          _headerCell('Details', flex: 4),
          _headerCell('Admin ID', flex: 2),
          _headerCell('IP Address', flex: 2),
        ],
      ),
    );
  }

  Widget _headerCell(String text, {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        text.toUpperCase(),
        textAlign: align,
        style: AdminUi.label(size: 11, color: AdminUi.textMuted, weight: FontWeight.w700),
      ),
    );
  }

  Widget _buildTableBody() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _logsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(100),
            child: Center(child: AppShimmerLoader(color: AdminUi.brand)),
          );
        }

        var logs = snapshot.data ?? [];
        
        // Filtering
        if (_searchQuery.isNotEmpty) {
          logs = logs.where((l) {
            final action = (l['action'] ?? '').toString().toLowerCase();
            final details = (l['details'] ?? '').toString().toLowerCase();
            return action.contains(_searchQuery) || details.contains(_searchQuery);
          }).toList();
        }
        if (_filterAction != 'all') {
          logs = logs.where((l) => l['action'] == _filterAction).toList();
        }

        if (logs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(80),
            child: Column(
              children: [
                Icon(Icons.history_rounded, size: 48, color: AdminUi.textMuted.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text('No activity logs found matching your criteria.', style: AdminUi.body(color: AdminUi.textMuted)),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: logs.length,
          separatorBuilder: (context, index) => const Divider(height: 1, color: AdminUi.border),
          itemBuilder: (context, index) => _buildRow(logs[index]),
        );
      },
    );
  }

  Widget _buildRow(Map<String, dynamic> log) {
    final action = (log['action'] ?? 'system_event').toString();
    final details = (log['details'] ?? 'No additional details provided').toString();
    final adminId = (log['admin_id'] ?? 'System').toString();
    final ipAddress = (log['ip_address'] ?? 'Internal').toString();
    final createdAt = log['created_at'] != null 
        ? DateFormat('MMM d, HH:mm:ss').format(DateTime.parse(log['created_at']).toLocal())
        : 'Unknown';

    Color actionColor;
    IconData actionIcon;
    
    if (action.contains('delete') || action.contains('suspend')) {
      actionColor = AdminUi.danger;
      actionIcon = Icons.delete_forever_rounded;
    } else if (action.contains('approve') || action.contains('verify') || action.contains('create')) {
      actionColor = AdminUi.success;
      actionIcon = Icons.check_circle_rounded;
    } else if (action.contains('update')) {
      actionColor = AdminUi.info;
      actionIcon = Icons.edit_rounded;
    } else {
      actionColor = AdminUi.textSecondary;
      actionIcon = Icons.event_note_rounded;
    }

    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(createdAt, style: AdminUi.label(size: 13, color: AdminUi.textPrimary, weight: FontWeight.w500)),
            ),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Icon(actionIcon, size: 14, color: actionColor),
                  const SizedBox(width: 8),
                  Text(
                    action.replaceAll('_', ' ').toUpperCase(),
                    style: AdminUi.label(size: 11, color: actionColor, weight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                details,
                style: AdminUi.body(size: 13, color: AdminUi.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                adminId,
                style: AdminUi.label(size: 12, color: AdminUi.textMuted, weight: FontWeight.w600),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                ipAddress,
                style: AdminUi.label(size: 12, color: AdminUi.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
