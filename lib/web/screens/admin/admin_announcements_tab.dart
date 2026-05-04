import 'package:flutter/material.dart';
import '../../../shared/services/admin/admin_service.dart';
import 'admin_ui.dart';

class AdminAnnouncementsTab extends StatefulWidget {
  final AdminService adminService;
  const AdminAnnouncementsTab({super.key, required this.adminService});

  @override
  State<AdminAnnouncementsTab> createState() => _AdminAnnouncementsTabState();
}

class _AdminAnnouncementsTabState extends State<AdminAnnouncementsTab> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  String _audience = 'farmers';
  bool _sending = false;
  Map<String, dynamic>? _lastResult;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and message are required.')),
      );
      return;
    }

    setState(() {
      _sending = true;
      _lastResult = null;
    });

    try {
      final result = await widget.adminService.sendAnnouncementPush(
        audience: _audience,
        title: title,
        body: message,
      );
      if (!mounted) return;
      setState(() => _lastResult = result);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Announcement sent.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.adminService.errorMessage ?? 'Failed to send: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminDashboardHeader(
          title: 'Announcements',
          subtitle: 'Send a push announcement to farmers, customers, or both.',
          actions: [
            ElevatedButton(
              onPressed: _sending ? null : _send,
              style: AdminUi.primaryButton,
              child: Text(_sending ? 'Sending...' : 'Send Announcement'),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AdminUi.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Audience', style: AdminUi.label(size: 12)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _audience,
                decoration: AdminUi.inputDecoration(),
                items: const [
                  DropdownMenuItem(value: 'farmers', child: Text('Farmers')),
                  DropdownMenuItem(
                    value: 'customers',
                    child: Text('Customers'),
                  ),
                  DropdownMenuItem(
                    value: 'farmers_customers',
                    child: Text('Farmers + Customers'),
                  ),
                ],
                onChanged: _sending
                    ? null
                    : (v) => setState(() => _audience = v ?? _audience),
              ),
              const SizedBox(height: 16),
              Text('Title', style: AdminUi.label(size: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                enabled: !_sending,
                decoration: AdminUi.inputDecoration(
                  hintText: 'Announcement title',
                ),
              ),
              const SizedBox(height: 16),
              Text('Message', style: AdminUi.label(size: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: _messageController,
                enabled: !_sending,
                maxLines: 6,
                decoration: AdminUi.inputDecoration(
                  hintText: 'Write the announcement message',
                ),
              ),
              const SizedBox(height: 16),
              if (_lastResult != null) ...[
                const Divider(height: 1, color: AdminUi.border),
                const SizedBox(height: 16),
                _ResultSummary(result: _lastResult!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultSummary extends StatelessWidget {
  final Map<String, dynamic> result;
  const _ResultSummary({required this.result});

  @override
  Widget build(BuildContext context) {
    final users = (result['users'] as num?)?.toInt();
    final sent = (result['sent'] as num?)?.toInt();
    final total = (result['total'] as num?)?.toInt();
    final reason = result['reason']?.toString();

    final summary = [
      if (users != null) 'Users: $users',
      if (sent != null && total != null) 'Delivered: $sent/$total',
      if (reason != null && reason.isNotEmpty) reason,
    ].join(' • ');

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: (sent != null && total != null && total > 0 && sent == 0)
                ? AdminUi.warning
                : AdminUi.success,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            summary.isEmpty ? 'Sent.' : summary,
            style: AdminUi.body(size: 13, color: AdminUi.textSecondary),
          ),
        ),
      ],
    );
  }
}
