import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/admin/admin_service.dart';
import '../../../shared/services/integration/email_service.dart';

class AdminSupportTab extends StatefulWidget {
  final AdminService adminService;

  const AdminSupportTab({super.key, required this.adminService});

  @override
  State<AdminSupportTab> createState() => _AdminSupportTabState();
}

class _AdminSupportTabState extends State<AdminSupportTab> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();

  String _searchQuery = '';
  String _statusFilter = 'All'; // 'All', 'open', 'resolved'

  List<Map<String, dynamic>> _tickets = [];
  Map<String, dynamic>? _selectedTicket;
  bool _isLoading = true;
  bool _isReplying = false;

  static const Color _primary = Color(0xFF059669);
  static const Color _primaryDark = Color(0xFF047857);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    try {
      setState(() => _isLoading = true);
      final tickets = await widget.adminService.getSupportTickets();
      if (mounted) {
        setState(() {
          _tickets = tickets;
          if (_tickets.isNotEmpty && _selectedTicket == null) {
            _selectedTicket = _tickets.first;
          } else if (_selectedTicket != null) {
            _selectedTicket = _tickets.firstWhere(
              (t) => t['ticket_id'] == _selectedTicket!['ticket_id'],
              orElse: () => _tickets.first,
            );
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredTickets {
    return _tickets.where((ticket) {
      final subject = ticket['subject']?.toString().toLowerCase() ?? '';
      final name = ticket['user_name']?.toString().toLowerCase() ?? '';
      final email = ticket['user_email']?.toString().toLowerCase() ?? '';
      final msg = ticket['message_text']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      final matchesSearch = query.isEmpty ||
          subject.contains(query) ||
          name.contains(query) ||
          email.contains(query) ||
          msg.contains(query);

      if (_statusFilter == 'All') return matchesSearch;
      return matchesSearch && ticket['status']?.toString().toLowerCase() == _statusFilter.toLowerCase();
    }).toList();
  }

  int _countForStatus(String status) {
    if (status == 'All') return _tickets.length;
    return _tickets.where((t) => (t['status'] ?? '').toString().toLowerCase() == status.toLowerCase()).length;
  }

  int get _openTicketsCount => _countForStatus('open');
  int get _resolvedTicketsCount => _countForStatus('resolved');

  Future<void> _updateTicketStatus(String ticketId, String newStatus) async {
    final success = await widget.adminService.updateSupportTicketStatus(ticketId, newStatus);
    if (!mounted) return;
    if (success) {
      _loadTickets();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ticket status updated to ${newStatus.toUpperCase()}.'),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update ticket status.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _replyViaEmail() async {
    if (_replyController.text.trim().isEmpty || _selectedTicket == null) return;

    setState(() => _isReplying = true);

    final userEmail = _selectedTicket!['user_email']?.toString() ?? '';
    final userName = _selectedTicket!['user_name']?.toString() ?? 'User';
    final subject = _selectedTicket!['subject']?.toString() ?? 'Support Request';
    final replyMessage = _replyController.text.trim();

    try {
      final success = await EmailService.sendSupportResolutionEmail(
        userEmail: userEmail,
        userName: userName,
        subject: subject,
        replyText: replyMessage,
      );

      if (!mounted) return;

      if (success) {
        await _updateTicketStatus(_selectedTicket!['ticket_id'].toString(), 'resolved');
        _replyController.clear();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resolution response sent successfully to $userEmail.'),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        throw 'Email dispatch failed.';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send email response: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isReplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 400,
        child: Center(
          child: CircularProgressIndicator(color: _primary),
        ),
      );
    }

    final sw = MediaQuery.of(context).size.width;
    final isDesktop = sw >= 1024;
    final filtered = _filteredTickets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopHeader(sw < 768),
        const SizedBox(height: 20),
        _buildMetricsStrip(context),
        const SizedBox(height: 24),
        if (isDesktop)
          _buildDesktopMasterDetail(filtered)
        else
          _buildMobileStackedLayout(filtered),
      ],
    );
  }

  // ─── Executive Header ──────────────────────────────────────────────────────
  Widget _buildTopHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _openTicketsCount > 0 ? const Color(0xFFFFFBEB) : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _openTicketsCount > 0 ? const Color(0xFFFDE68A) : _primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _openTicketsCount > 0 ? Icons.headphones_rounded : Icons.verified_user_rounded,
                        size: 13,
                        color: _openTicketsCount > 0 ? const Color(0xFFD97706) : _primaryDark,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _openTicketsCount > 0
                            ? '$_openTicketsCount INQUIRIES AWAITING REPLY'
                            : 'SUPPORT QUEUE ALL CLEAR',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _openTicketsCount > 0 ? const Color(0xFFB45309) : _primaryDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Support Ticket Center',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isMobile ? 20 : 26,
                    fontWeight: FontWeight.w900,
                    color: _dark,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage customer & farmer enquiries, address platform issues, and dispatch email resolutions.',
                  style: GoogleFonts.inter(
                    fontSize: isMobile ? 12 : 13.5,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: _loadTickets,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(
              isMobile ? '' : 'Refresh Queue',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _dark,
              side: const BorderSide(color: _border),
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── KPI Metrics Strip (4 Cards) ───────────────────────────────────────────
  Widget _buildMetricsStrip(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;
    final isTablet = width >= 768 && width < 1100;

    final metrics = [
      _kpiMetricCard(
        title: 'TOTAL INQUIRIES',
        value: '${_tickets.length}',
        subtitle: 'All-time support tickets',
        icon: Icons.mark_email_unread_rounded,
        color: const Color(0xFF0284C7),
        bgColor: const Color(0xFFF0F9FF),
        borderColor: const Color(0xFFBAE6FD),
      ),
      _kpiMetricCard(
        title: 'AWAITING REPLY',
        value: '$_openTicketsCount',
        subtitle: _openTicketsCount > 0 ? 'Needs response' : 'All caught up',
        icon: Icons.hourglass_top_rounded,
        color: _openTicketsCount > 0 ? const Color(0xFFD97706) : const Color(0xFF059669),
        bgColor: _openTicketsCount > 0 ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5),
        borderColor: _openTicketsCount > 0 ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0),
        badgeText: _openTicketsCount > 0 ? 'ACTION' : 'CLEAN',
      ),
      _kpiMetricCard(
        title: 'RESOLVED TICKETS',
        value: '$_resolvedTicketsCount',
        subtitle: _tickets.isNotEmpty
            ? '${((_resolvedTicketsCount / _tickets.length) * 100).toStringAsFixed(0)}% resolution rate'
            : '100% resolved',
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF059669),
        bgColor: const Color(0xFFECFDF5),
        borderColor: const Color(0xFFA7F3D0),
      ),
      _kpiMetricCard(
        title: 'RESPONSE SLA',
        value: '< 1h',
        subtitle: 'Avg. resolution turnaround',
        icon: Icons.bolt_rounded,
        color: const Color(0xFF7C3AED),
        bgColor: const Color(0xFFF5F3FF),
        borderColor: const Color(0xFFDDD6FE),
        badgeText: 'FAST',
      ),
    ];

    if (isMobile) {
      return SizedBox(
        height: 110,
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

  Widget _kpiMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    String? badgeText,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x03000000),
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
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 11, color: _muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ─── Desktop Master-Detail Workspace ───────────────────────────────────────
  Widget _buildDesktopMasterDetail(List<Map<String, dynamic>> filtered) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (40%): Ticket List & Triage Filter
        Expanded(
          flex: 40,
          child: _buildTicketQueuePanel(filtered),
        ),
        const SizedBox(width: 24),

        // Right Column (60%): Ticket Detail & Email Resolution Console
        Expanded(
          flex: 60,
          child: _buildInvestigationConsole(),
        ),
      ],
    );
  }

  // ─── Mobile Stacked Layout ─────────────────────────────────────────────────
  Widget _buildMobileStackedLayout(List<Map<String, dynamic>> filtered) {
    return Column(
      children: [
        _buildTicketQueuePanel(filtered, isMobile: true),
        const SizedBox(height: 20),
        if (_selectedTicket != null) _buildInvestigationConsole(),
      ],
    );
  }

  // ─── Left Panel: Ticket Triage Queue ───────────────────────────────────────
  Widget _buildTicketQueuePanel(List<Map<String, dynamic>> filtered, {bool isMobile = false}) {
    final statusTabs = ['All', 'Open', 'Resolved'];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search input
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            style: GoogleFonts.inter(fontSize: 13, color: _dark),
            decoration: InputDecoration(
              hintText: 'Search tickets by subject, user, email...',
              hintStyle: GoogleFonts.inter(fontSize: 12.5, color: _muted),
              prefixIcon: const Icon(Icons.search_rounded, color: _muted, size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: _muted),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: _surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Status Filter Tabs
          Row(
            children: statusTabs.map((st) {
              final isSelected = _statusFilter == st;
              final count = _countForStatus(st);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => setState(() => _statusFilter = st),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? _primary : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? _primary : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            st,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              count.toString(),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? Colors.white : _muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Tickets List
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.inbox_outlined, size: 36, color: Color(0xFFCBD5E1)),
                  const SizedBox(height: 10),
                  Text(
                    'No tickets in this view',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Try clearing your search or switching filter tabs.',
                    style: GoogleFonts.inter(fontSize: 12, color: _muted),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final ticket = filtered[index];
                final isSelected = _selectedTicket?['ticket_id'] == ticket['ticket_id'];
                final status = (ticket['status'] ?? 'open').toString().toLowerCase();
                final isOpen = status == 'open';

                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTicket = ticket;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFECFDF5) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? _primary : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: _primary.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  ticket['subject']?.toString() ?? 'Support Inquiry',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: _dark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _statusBadge(status),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: isOpen ? const Color(0xFFFEF3C7) : const Color(0xFFE0F2FE),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    (ticket['user_name']?.toString() ?? 'U')[0].toUpperCase(),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: isOpen ? const Color(0xFFB45309) : const Color(0xFF0369A1),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  ticket['user_name']?.toString() ?? 'User',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF334155),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ticket['message_text']?.toString() ?? '',
                            style: GoogleFonts.inter(fontSize: 11.5, color: _muted),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
    );
  }

  // ─── Right Panel: Investigation & Email Resolution Console ────────────────
  Widget _buildInvestigationConsole() {
    if (_selectedTicket == null) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.touch_app_outlined, size: 40, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text(
                'Select a ticket to investigate and reply',
                style: GoogleFonts.inter(fontSize: 13.5, color: _muted),
              ),
            ],
          ),
        ),
      );
    }

    final ticket = _selectedTicket!;
    final status = (ticket['status'] ?? 'open').toString().toLowerCase();
    final isOpen = status == 'open';
    final userEmail = ticket['user_email']?.toString() ?? '';
    final userName = ticket['user_name']?.toString() ?? 'User';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Customer Identity + Email Copy + Status Toggle
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: userEmail));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied email: $userEmail'),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              userEmail,
                              style: GoogleFonts.inter(fontSize: 12.5, color: _muted),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.copy_rounded, size: 12, color: _muted),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Status Toggle Button
              ElevatedButton.icon(
                onPressed: () => _updateTicketStatus(
                  ticket['ticket_id'].toString(),
                  isOpen ? 'resolved' : 'open',
                ),
                icon: Icon(
                  isOpen ? Icons.check_circle_rounded : Icons.history_rounded,
                  size: 16,
                ),
                label: Text(
                  isOpen ? 'Mark Resolved' : 'Reopen Ticket',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOpen ? const Color(0xFF059669) : const Color(0xFF475569),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 18),

          // Message Subject
          Text(
            'INQUIRY SUBJECT',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: _muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ticket['subject']?.toString() ?? 'Support Request',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          const SizedBox(height: 14),

          // Message Body Container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Text(
              ticket['message_text']?.toString() ?? 'No message body.',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: const Color(0xFF334155),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Canned Response Templates
          Text(
            'QUICK RESPONSE TEMPLATES',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: _muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _cannedTemplateChip(
                label: '✅ Issue Resolved',
                text:
                    'Hi $userName,\n\nWe have reviewed and resolved your reported inquiry. Everything should now be functioning properly.\n\nThank you for using AgriDirect!',
              ),
              _cannedTemplateChip(
                label: '⏳ Under Investigation',
                text:
                    'Hi $userName,\n\nThank you for contacting AgriDirect Support. We have logged this report and our engineering team is actively investigating. We will update you shortly.',
              ),
              _cannedTemplateChip(
                label: '❓ Need More Info',
                text:
                    'Hi $userName,\n\nTo help us resolve this swiftly, could you please provide additional details or screenshots regarding this issue?\n\nBest regards,\nAgriDirect Support Team',
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Email Resolution Composer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DISPATCH OFFICIAL EMAIL RESPONSE',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _muted,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'To: $userEmail',
                style: GoogleFonts.inter(fontSize: 11.5, color: _primaryDark, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _replyController,
            maxLines: 5,
            style: GoogleFonts.inter(fontSize: 13.5, color: _dark),
            decoration: InputDecoration(
              hintText: 'Type your official support resolution message here...',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: _muted),
              filled: true,
              fillColor: _surface,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Dispatch Action Button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _isReplying ? null : _replyViaEmail,
                icon: _isReplying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 16),
                label: Text(
                  _isReplying ? 'Sending Email...' : 'Send Resolution Email',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cannedTemplateChip({required String label, required String text}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _replyController.text = text;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final isOpen = status.toLowerCase() == 'open';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isOpen ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isOpen ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0),
        ),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: isOpen ? const Color(0xFFB45309) : const Color(0xFF047857),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
