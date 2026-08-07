import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AccountActivityScreen extends StatelessWidget {
  final bool isWebEmbedded;
  const AccountActivityScreen({super.key, this.isWebEmbedded = false});

  @override
  Widget build(BuildContext context) {
    // Dummy activity data
    final activities = [
      {'action': 'New login', 'device': 'TECNO Mobile', 'date': 'Today, 10:30 AM', 'location': 'Manila, Philippines'},
      {'action': 'Password changed', 'device': 'Windows PC - Chrome', 'date': 'Yesterday, 2:15 PM', 'location': 'Manila, Philippines'},
      {'action': 'New login', 'device': 'Windows PC - Chrome', 'date': 'Yesterday, 2:10 PM', 'location': 'Manila, Philippines'},
      {'action': 'Logged out', 'device': 'TECNO Mobile', 'date': 'Aug 5, 2026, 8:00 AM', 'location': 'Quezon City, Philippines'},
    ];

    final body = ListView.builder(
      shrinkWrap: isWebEmbedded,
      physics: isWebEmbedded ? const NeverScrollableScrollPhysics() : null,
      padding: EdgeInsets.symmetric(vertical: isWebEmbedded ? 0 : 12),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final item = activities[index];
        final isLogin = item['action'] == 'New login';
        return Container(
          margin: EdgeInsets.symmetric(horizontal: isWebEmbedded ? 0 : 16, vertical: 6),
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
                  color: isLogin ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFF59E0B).withValues(alpha: 0.1),
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
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
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

    if (isWebEmbedded) {
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
  }
}
