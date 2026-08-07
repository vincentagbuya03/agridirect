import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/core/supabase_config.dart';

class ManageDeviceScreen extends StatefulWidget {
  final bool isWebEmbedded;
  const ManageDeviceScreen({super.key, this.isWebEmbedded = false});

  @override
  State<ManageDeviceScreen> createState() => _ManageDeviceScreenState();
}

class _ManageDeviceScreenState extends State<ManageDeviceScreen> {
  late Future<List<Map<String, dynamic>>> _devicesFuture;

  @override
  void initState() {
    super.initState();
    _refreshDevices();
  }

  void _refreshDevices() {
    setState(() {
      _devicesFuture = _fetchDevices();
    });
  }

  Future<List<Map<String, dynamic>>> _fetchDevices() async {
    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await SupabaseConfig.client
          .from('app_sessions')
          .select()
          .eq('user_id', userId)
          .order('start_time', ascending: false)
          .limit(15);

      final Map<String, Map<String, dynamic>> uniqueDevices = {};
      for (var session in response) {
        final deviceName = session['device_info'] ?? 'Unknown Device';
        final platform = (session['platform'] ?? 'unknown').toString();
        final isActive = session['end_time'] == null;
        final startTime = DateTime.parse(session['start_time']);

        if (!uniqueDevices.containsKey(deviceName)) {
          uniqueDevices[deviceName] = {
            'session_id': session['session_id'],
            'name': deviceName,
            'type': platform.toLowerCase() == 'web' ? 'Desktop' : 'Phone',
            'active': isActive,
            'lastActive': isActive ? 'Active now' : 'Last active ${_formatDateTime(startTime)}',
            'location': platform.toUpperCase(),
          };
        }
      }
      return uniqueDevices.values.toList();
    } catch (e) {
      debugPrint('Error fetching devices: $e');
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

  Future<void> _logoutDevice(String sessionId) async {
    try {
      await SupabaseConfig.client
          .from('app_sessions')
          .update({'end_time': DateTime.now().toIso8601String()})
          .eq('session_id', sessionId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device logged out successfully.')),
      );
      _refreshDevices();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to logout device: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _devicesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFFF1F5F9),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final devices = snapshot.data ?? [];

        final listView = ListView.builder(
          shrinkWrap: widget.isWebEmbedded,
          physics: widget.isWebEmbedded ? const NeverScrollableScrollPhysics() : null,
          padding: EdgeInsets.symmetric(vertical: widget.isWebEmbedded ? 0 : 8),
          itemCount: devices.length,
          itemBuilder: (context, index) {
            final device = devices[index];
            final isActive = device['active'] as bool;
            final isPhone = device['type'] == 'Phone';

            return Container(
              margin: EdgeInsets.symmetric(horizontal: widget.isWebEmbedded ? 0 : 16, vertical: 6),
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
                            Expanded(
                              child: Text(
                                device['name'] as String,
                                style: GoogleFonts.inter(
                                    fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                                overflow: TextOverflow.ellipsis,
                              ),
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
                                  style: GoogleFonts.inter(
                                      fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
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
                  if (!isActive && device['session_id'] != null)
                    IconButton(
                      onPressed: () => _logoutDevice(device['session_id']),
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
          mainAxisSize: widget.isWebEmbedded ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(widget.isWebEmbedded ? 0 : 16, 24, widget.isWebEmbedded ? 0 : 16, 8),
              child: Text(
                'You\'re currently logged in on these devices.',
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
              ),
            ),
            if (widget.isWebEmbedded) listView else Expanded(child: listView),
          ],
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
      },
    );
  }
}
