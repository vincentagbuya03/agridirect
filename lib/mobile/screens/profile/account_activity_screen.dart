import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/core/supabase_config.dart';

class AccountActivityScreen extends StatefulWidget {
  final bool isWebEmbedded;
  const AccountActivityScreen({super.key, this.isWebEmbedded = false});

  @override
  State<AccountActivityScreen> createState() => _AccountActivityScreenState();
}

class _AccountActivityScreenState extends State<AccountActivityScreen> {
  Future<List<Map<String, dynamic>>> _fetchActivities() async {
    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await SupabaseConfig.client
          .from('app_sessions')
          .select()
          .eq('user_id', userId)
          .order('start_time', ascending: false)
          .limit(20);

      final List<Map<String, dynamic>> activities = [];
      for (var session in response) {
        final startTime = DateTime.parse(session['start_time']);
        final device = session['device_info'] ?? 'Unknown Device';
        final platform = (session['platform'] ?? 'unknown').toString().toUpperCase();

        activities.add({
          'action': 'New login',
          'device': device,
          'date': _formatDateTime(startTime),
          'location': platform,
          'timestamp': startTime,
        });

        if (session['end_time'] != null) {
          final endTime = DateTime.parse(session['end_time']);
          activities.add({
            'action': 'Logged out',
            'device': device,
            'date': _formatDateTime(endTime),
            'location': platform,
            'timestamp': endTime,
          });
        }
      }

      activities.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
      return activities;
    } catch (e) {
      debugPrint('Error fetching activities: $e');
      return [];
    }
  }

  String _formatDateTime(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}, $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchActivities(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFFF1F5F9),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final activities = snapshot.data ?? [];

        final body = activities.isEmpty
            ? Center(
                child: Text(
                  'No recent account activity.',
                  style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                ),
              )
            : ListView.builder(
                shrinkWrap: widget.isWebEmbedded,
                physics: widget.isWebEmbedded ? const NeverScrollableScrollPhysics() : null,
                padding: EdgeInsets.symmetric(vertical: widget.isWebEmbedded ? 0 : 12),
                itemCount: activities.length,
                itemBuilder: (context, index) {
                  final item = activities[index];
                  final isLogin = item['action'] == 'New login';
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: widget.isWebEmbedded ? 0 : 16, vertical: 6),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isLogin
                                ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isLogin ? Icons.login_rounded : Icons.security_rounded,
                            color: isLogin ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['action']!,
                                style: GoogleFonts.inter(
                                    fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item['device']} • ${item['location']}',
                                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['date']!,
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );

        if (widget.isWebEmbedded) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              return Container(
                padding: EdgeInsets.all(isMobile ? 16 : 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Account Activity',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: isMobile ? 18 : 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Check your login and account changes in the last 30 days',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                    const Divider(height: 32, color: Color(0xFFF1F5F9)),
                    body,
                  ],
                ),
              );
            },
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          appBar: AppBar(
            title: Text(
              'Account Activity',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w500, color: const Color(0xFF1E293B)),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: const Color(0xFFE2E8F0), height: 1),
            ),
          ),
          body: body,
        );
      },
    );
  }
}
