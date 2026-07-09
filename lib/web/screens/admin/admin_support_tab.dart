import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/admin/admin_service.dart';
import 'admin_ui.dart';
import '../../../shared/styles/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _loadTickets();
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
            // Refresh selected ticket references
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
      final query = _searchQuery.toLowerCase();
      
      final matchesSearch = subject.contains(query) || name.contains(query) || email.contains(query);
      
      if (_statusFilter == 'All') return matchesSearch;
      return matchesSearch && ticket['status'] == _statusFilter.toLowerCase();
    }).toList();
  }

  Future<void> _updateTicketStatus(String ticketId, String newStatus) async {
    final success = await widget.adminService.updateSupportTicketStatus(ticketId, newStatus);
    if (!mounted) return;
    if (success) {
      _loadTickets();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ticket status updated to $newStatus.'),
          backgroundColor: AdminUi.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update ticket status.'),
          backgroundColor: AdminUi.danger,
        ),
      );
    }
  }

  Future<void> _replyViaEmail() async {
    if (_replyController.text.trim().isEmpty || _selectedTicket == null) return;
    
    setState(() => _isReplying = true);
    
    final userEmail = _selectedTicket!['user_email'];
    final userName = _selectedTicket!['user_name'];
    final subject = _selectedTicket!['subject'];
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
        // Auto-resolve ticket since response is sent
        await _updateTicketStatus(_selectedTicket!['ticket_id'], 'resolved');
        _replyController.clear();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resolution response sent successfully to $userEmail.'),
            backgroundColor: AdminUi.success,
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
          backgroundColor: AdminUi.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isReplying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 400,
        child: Center(
          child: CircularProgressIndicator(color: AdminUi.brand),
        ),
      );
    }

    final filtered = _filteredTickets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Bar / Subheading
        Text(
          'Support Ticket Center',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AdminUi.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Manage user enquiries, report issues, and respond directly via email.',
          style: AdminUi.label(size: 13, color: AdminUi.textMuted),
        ),
        const SizedBox(height: 24),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Master List Panel
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: AdminUi.cardDecoration(),
                child: Column(
                  children: [
                    // Search box
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: AdminUi.inputDecoration(
                        hintText: 'Search tickets...',
                        prefixIcon: const Icon(Icons.search_rounded, color: AdminUi.textMuted, size: 20),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Filter Tabs
                    Row(
                      children: [
                        _buildFilterButton('All'),
                        const SizedBox(width: 8),
                        _buildFilterButton('Open'),
                        const SizedBox(width: 8),
                        _buildFilterButton('Resolved'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Tickets List
                    if (filtered.isEmpty)
                      SizedBox(
                        height: 200,
                        child: Center(
                          child: Text(
                            'No tickets found',
                            style: AdminUi.label(size: 14, color: AdminUi.textMuted),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 20),
                        itemBuilder: (context, index) {
                          final ticket = filtered[index];
                          final isSelected = _selectedTicket?['ticket_id'] == ticket['ticket_id'];
                          
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedTicket = ticket;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected ? AdminUi.brand.withValues(alpha: 0.05) : Colors.transparent,
                                borderRadius: AdminUi.radiusSm,
                                border: isSelected ? Border.all(color: AdminUi.brand.withValues(alpha: 0.2)) : null,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          ticket['subject'].toString(),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AdminUi.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      _buildStatusBadge(ticket['status'].toString()),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    ticket['user_name'].toString(),
                                    style: AdminUi.label(size: 12, color: AdminUi.textSecondary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    ticket['message_text'].toString(),
                                    style: AdminUi.label(size: 12, color: AdminUi.textMuted),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),

            // Right Detail Panel
            Expanded(
              flex: 6,
              child: _selectedTicket == null
                  ? Container(
                      height: 400,
                      decoration: AdminUi.cardDecoration(),
                      child: Center(
                        child: Text(
                          'Select a ticket to view details',
                          style: AdminUi.label(size: 14, color: AdminUi.textMuted),
                        ),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.all(28),
                      decoration: AdminUi.cardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // User / Sender header
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: AdminUi.brand.withValues(alpha: 0.1),
                                child: const Icon(Icons.person_rounded, color: AdminUi.brand),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedTicket!['user_name'].toString(),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AdminUi.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _selectedTicket!['user_email'].toString(),
                                      style: AdminUi.label(size: 13, color: AdminUi.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              // Status button switcher
                              DropdownButton<String>(
                                value: _selectedTicket!['status'].toString(),
                                items: const [
                                  DropdownMenuItem(value: 'open', child: Text('Open')),
                                  DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    _updateTicketStatus(_selectedTicket!['ticket_id'], val);
                                  }
                                },
                              ),
                            ],
                          ),
                          const Divider(height: 40),

                          // Message Subject
                          Text(
                            _selectedTicket!['subject'].toString(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AdminUi.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Message Body Text
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AdminUi.background,
                              borderRadius: AdminUi.radiusMd,
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Text(
                              _selectedTicket!['message_text'].toString(),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AdminUi.textSecondary,
                                height: 1.6,
                              ),
                            ),
                          ),
                          const Divider(height: 40),

                          // Reply Composer Section
                          Text(
                            'Respond to User',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AdminUi.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Type a response to trigger your mail client and notify the user.',
                            style: AdminUi.label(size: 11, color: AdminUi.textMuted),
                          ),
                          const SizedBox(height: 12),
                          
                          TextField(
                            controller: _replyController,
                            maxLines: 5,
                            decoration: AdminUi.inputDecoration(
                              hintText: 'Compose your response message here...',
                            ),
                          ),
                          const SizedBox(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: AdminUi.radiusSm,
                                  ),
                                ),
                                onPressed: () => _updateTicketStatus(
                                  _selectedTicket!['ticket_id'], 
                                  _selectedTicket!['status'] == 'open' ? 'resolved' : 'open'
                                ),
                                icon: Icon(
                                  _selectedTicket!['status'] == 'open' 
                                      ? Icons.check_circle_outline_rounded 
                                      : Icons.history_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  _selectedTicket!['status'] == 'open' 
                                      ? 'Mark as Resolved' 
                                      : 'Reopen Ticket'
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AdminUi.brand,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: AdminUi.radiusSm,
                                  ),
                                ),
                                onPressed: _isReplying ? null : _replyViaEmail,
                                icon: const Icon(Icons.send_rounded, size: 18),
                                label: Text(_isReplying ? 'Opening Email...' : 'Send Email Response'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterButton(String label) {
    final isSelected = _statusFilter == label;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _statusFilter = label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AdminUi.brand : Colors.transparent,
            border: Border.all(color: isSelected ? AdminUi.brand : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: AdminUi.label(
              size: 12,
              color: isSelected ? Colors.white : AdminUi.textSecondary,
              weight: isSelected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isOpen = status.toLowerCase() == 'open';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOpen ? AdminUi.warning.withValues(alpha: 0.1) : AdminUi.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: AdminUi.label(
          size: 10,
          color: isOpen ? const Color(0xFFB45309) : AdminUi.success,
          weight: FontWeight.w800,
        ),
      ),
    );
  }
}
