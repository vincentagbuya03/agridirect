import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/admin_service.dart';

/// Admin Logs Tab - View all admin activity logs
class AdminLogsTab extends StatefulWidget {
  final AdminService adminService;

  const AdminLogsTab({super.key, required this.adminService});

  @override
  State<AdminLogsTab> createState() => _AdminLogsTabState();
}

// Modern light theme colors
const Color _primary = Color(0xFF10B981);
const Color _danger = Color(0xFFEF4444);
const Color _info = Color(0xFF3B82F6);
const Color _warning = Color(0xFFF59E0B);
const Color _background = Color(0xFFFAFAFA);
const Color _card = Colors.white;
const Color _border = Color(0xFFE2E8F0);
const Color _text = Color(0xFF1E293B);
const Color _muted = Color(0xFF64748B);

class _AdminLogsTabState extends State<AdminLogsTab> {
  late Future<List<Map<String, dynamic>>> _logsFuture;
  int _currentPage = 0;
  String _selectedFilter = 'all';

  final List<String> _filters = [
    'all',
    'user',
    'farmer',
    'product',
    'order',
    'category',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _logsFuture = widget.adminService.getAdminLogs(page: _currentPage);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      color: _background,
      child: Column(
        children: [
          // Header with Filters
          Container(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Activity Logs',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Track all administrative actions',
                          style: GoogleFonts.inter(fontSize: 13, color: _muted),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _loadData()),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _card,
                        foregroundColor: _text,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: _border),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text(
                            filter == 'all'
                                ? 'All Actions'
                                : '${filter[0].toUpperCase()}${filter.substring(1)} Actions',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected ? _primary : _muted,
                            ),
                          ),
                          backgroundColor: _card,
                          selectedColor: _primary.withOpacity(0.15),
                          checkmarkColor: _primary,
                          side: BorderSide(
                            color: isSelected
                                ? _primary.withOpacity(0.5)
                                : _border,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          onSelected: (_) =>
                              setState(() => _selectedFilter = filter),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          // Logs List
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _logsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _primary),
                  );
                }

                if (snapshot.hasError) {
                  return _buildErrorState();
                }

                var logs = snapshot.data ?? [];

                // Filter logs
                if (_selectedFilter != 'all') {
                  logs = logs.where((log) {
                    final action = (log['action'] ?? '')
                        .toString()
                        .toLowerCase();
                    return action.contains(_selectedFilter);
                  }).toList();
                }

                if (logs.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
                  itemCount: logs.length + 1,
                  itemBuilder: (context, index) {
                    if (index == logs.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: _buildPagination(logs.length),
                      );
                    }
                    return _LogItem(log: logs[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.history_rounded, color: _muted, size: 56),
          ),
          const SizedBox(height: 24),
          Text(
            'No activity logs',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Admin actions will appear here',
            style: GoogleFonts.inter(fontSize: 13, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: _danger, size: 48),
          const SizedBox(height: 16),
          Text(
            'Failed to load logs',
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
            ),
          ),
        ],
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
          onPressed: count >= 50
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

class _LogItem extends StatelessWidget {
  final Map<String, dynamic> log;

  const _LogItem({required this.log});

  @override
  Widget build(BuildContext context) {
    final action = log['action'] ?? 'unknown';
    final actionInfo = _getActionInfo(action);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: actionInfo.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(actionInfo.icon, color: actionInfo.color, size: 22),
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: actionInfo.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        actionInfo.label,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: actionInfo.color,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatDate(log['created_at']),
                      style: GoogleFonts.inter(fontSize: 11, color: _muted),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  log['details'] ?? 'No details available',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded, size: 14, color: _muted),
                    const SizedBox(width: 6),
                    Text(
                      'Admin ID: ${log['admin_id']?.toString().substring(0, 8) ?? 'Unknown'}...',
                      style: GoogleFonts.inter(fontSize: 11, color: _muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _ActionInfo _getActionInfo(String action) {
    if (action.contains('approve') || action.contains('verify')) {
      return _ActionInfo(Icons.check_circle_rounded, _primary, 'Approved');
    } else if (action.contains('reject') ||
        action.contains('suspend') ||
        action.contains('delete')) {
      return _ActionInfo(Icons.cancel_rounded, _danger, 'Restricted');
    } else if (action.contains('create') || action.contains('add')) {
      return _ActionInfo(Icons.add_circle_rounded, _info, 'Created');
    } else if (action.contains('update') || action.contains('edit')) {
      return _ActionInfo(Icons.edit_rounded, _warning, 'Updated');
    } else if (action.contains('promote')) {
      return _ActionInfo(Icons.arrow_upward_rounded, _primary, 'Promoted');
    } else if (action.contains('remove')) {
      return _ActionInfo(Icons.remove_circle_rounded, _warning, 'Removed');
    } else if (action.contains('resolve')) {
      return _ActionInfo(Icons.done_all_rounded, _primary, 'Resolved');
    } else {
      return _ActionInfo(Icons.info_rounded, _muted, 'Action');
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) {
        return 'Just now';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      } else {
        return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}

class _ActionInfo {
  final IconData icon;
  final Color color;
  final String label;

  _ActionInfo(this.icon, this.color, this.label);
}
