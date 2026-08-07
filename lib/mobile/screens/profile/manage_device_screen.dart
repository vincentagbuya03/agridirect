import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ManageDeviceScreen extends StatelessWidget {
  final bool isWebEmbedded;
  const ManageDeviceScreen({super.key, this.isWebEmbedded = false});

  @override
  Widget build(BuildContext context) {
    // Dummy device data
    final devices = [
      {'name': 'TECNO Mobile', 'type': 'Phone', 'active': true, 'lastActive': 'Active now', 'location': 'Manila, Philippines'},
      {'name': 'Windows PC - Chrome', 'type': 'Desktop', 'active': false, 'lastActive': 'Last active yesterday', 'location': 'Manila, Philippines'},
    ];

    final listView = ListView.builder(
      shrinkWrap: isWebEmbedded,
      physics: isWebEmbedded ? const NeverScrollableScrollPhysics() : null,
      padding: EdgeInsets.symmetric(vertical: isWebEmbedded ? 0 : 8),
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        final isActive = device['active'] as bool;
        final isPhone = device['type'] == 'Phone';
        
        return Container(
          margin: EdgeInsets.symmetric(horizontal: isWebEmbedded ? 0 : 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPhone ? Icons.smartphone_rounded : Icons.desktop_windows_rounded,
                  color: const Color(0xFF475569),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          device['name'] as String,
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Current',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
                            ),
                          ),
                        ]
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${device['location']} • ${device['lastActive']}',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              if (!isActive)
                IconButton(
                  onPressed: () {
                    // Implement logout for other device
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Device logged out successfully.')),
                    );
                  },
                  icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                  tooltip: 'Log out device',
                ),
            ],
          ),
        );
      },
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: isWebEmbedded ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(isWebEmbedded ? 0 : 16, 24, isWebEmbedded ? 0 : 16, 8),
          child: Text(
            'You\'re currently logged in on these devices.',
            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
          ),
        ),
        if (isWebEmbedded) listView else Expanded(child: listView),
      ],
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
                  'Manage Login Devices',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
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
          'Manage Login Devices',
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
