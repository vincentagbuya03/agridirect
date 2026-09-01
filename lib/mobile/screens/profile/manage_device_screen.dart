import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/services/community/analytics_service.dart';
import '../../../shared/styles/app_theme.dart';

class ManageDeviceScreen extends StatefulWidget {
  final bool isWebEmbedded;
  const ManageDeviceScreen({super.key, this.isWebEmbedded = false});

  @override
  State<ManageDeviceScreen> createState() => _ManageDeviceScreenState();
}

class _ManageDeviceScreenState extends State<ManageDeviceScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _currentDevice;
  List<Map<String, dynamic>> _otherDevices = [];
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _isLoading = false;
          _currentDevice = null;
          _otherDevices = [];
        });
        return;
      }

      final response = await SupabaseConfig.client
          .from('app_sessions')
          .select()
          .eq('user_id', userId)
          .order('start_time', ascending: false)
          .limit(25);

      var currentSessionId = AnalyticsService().currentSessionId;
      if (currentSessionId == null) {
        await AnalyticsService().startSession(userId: userId);
        currentSessionId = AnalyticsService().currentSessionId;
      }

      Map<String, dynamic>? current;
      final Map<String, Map<String, dynamic>> uniqueOthers = {};

      // First pass: find current session
      for (var session in response) {
        final sessionId = session['session_id'] as String?;
        final rawDeviceInfo = (session['device_info'] ?? 'Unknown Device').toString();
        final platform = (session['platform'] ?? 'unknown').toString();
        final isCurrent = sessionId == currentSessionId;
        final startTime = DateTime.tryParse(session['start_time'] ?? '') ?? DateTime.now();

        if (isCurrent) {
          final formattedInfo = _parseDeviceInfo(rawDeviceInfo, platform);
          current = {
            'session_id': sessionId,
            'raw_name': rawDeviceInfo,
            'title': formattedInfo.title,
            'subtitle': formattedInfo.subtitle,
            'device_type': formattedInfo.deviceType,
            'platform': platform.toUpperCase(),
            'isCurrent': true,
            'start_time': startTime,
            'last_active_formatted': 'Active now',
          };
          break;
        }
      }

      // Second pass: collect other unique active devices & cleanup previous stale sessions of this device
      for (var session in response) {
        final sessionId = session['session_id'] as String?;
        final rawDeviceInfo = (session['device_info'] ?? 'Unknown Device').toString();
        final platform = (session['platform'] ?? 'unknown').toString();
        final isActive = session['end_time'] == null;
        final isCurrent = sessionId == currentSessionId;
        final startTime = DateTime.tryParse(session['start_time'] ?? '') ?? DateTime.now();

        if (isCurrent) continue;
        if (!isActive) continue;

        // If it's a previous unclosed session from this same device, silently close it in DB
        if (current != null && current['raw_name'] == rawDeviceInfo) {
          if (sessionId != null) {
            SupabaseConfig.client
                .from('app_sessions')
                .update({'end_time': DateTime.now().toIso8601String()})
                .eq('session_id', sessionId);
          }
          continue;
        }

        // For different devices, group by device name so each device only appears once
        if (!uniqueOthers.containsKey(rawDeviceInfo)) {
          final formattedInfo = _parseDeviceInfo(rawDeviceInfo, platform);
          uniqueOthers[rawDeviceInfo] = {
            'session_id': sessionId,
            'raw_name': rawDeviceInfo,
            'title': formattedInfo.title,
            'subtitle': formattedInfo.subtitle,
            'device_type': formattedInfo.deviceType,
            'platform': platform.toUpperCase(),
            'isCurrent': false,
            'start_time': startTime,
            'last_active_formatted':
                'Last active ${DateFormat('MMM d, yyyy • h:mm a').format(startTime)}',
          };
        }
      }

      // If current device wasn't in DB yet, create a synthetic entry
      if (current == null && currentSessionId != null) {
        current = {
          'session_id': currentSessionId,
          'raw_name': 'current_device',
          'title': 'This Device',
          'subtitle': 'Current active session',
          'device_type': DeviceCategory.phone,
          'platform': 'MOBILE',
          'isCurrent': true,
          'start_time': DateTime.now(),
          'last_active_formatted': 'Active now',
        };
      }

      if (mounted) {
        setState(() {
          _currentDevice = current;
          _otherDevices = uniqueOthers.values.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching devices: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load device list.';
          _isLoading = false;
        });
      }
    }
  }

  DateTime? _lastClickTime;

  bool _isDebounced() {
    final now = DateTime.now();
    if (_lastClickTime != null &&
        now.difference(_lastClickTime!) < const Duration(milliseconds: 650)) {
      return true; // Too fast, ignore double tap
    }
    _lastClickTime = now;
    return false;
  }

  Future<void> _logoutDevice(String sessionId, String rawDeviceInfo, String deviceTitle) async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);

    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId != null) {
        // End all sessions for this device
        await SupabaseConfig.client
            .from('app_sessions')
            .update({'end_time': DateTime.now().toIso8601String()})
            .eq('user_id', userId)
            .eq('device_info', rawDeviceInfo);
      } else {
        await SupabaseConfig.client
            .from('app_sessions')
            .update({'end_time': DateTime.now().toIso8601String()})
            .eq('session_id', sessionId);
      }

      if (!mounted) return;

      // Immediately update local list state
      setState(() {
        _otherDevices.removeWhere((d) => d['raw_name'] == rawDeviceInfo || d['session_id'] == sessionId);
        _isLoggingOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text('$deviceTitle was logged out.')),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to logout device: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _logoutAllOtherDevices() async {
    if (_isLoggingOut) return;
    final currentSessionId = AnalyticsService().currentSessionId;
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoggingOut = true);

    try {
      var query = SupabaseConfig.client
          .from('app_sessions')
          .update({'end_time': DateTime.now().toIso8601String()})
          .eq('user_id', userId)
          .filter('end_time', 'is', 'null');

      if (currentSessionId != null) {
        query = query.neq('session_id', currentSessionId);
      }

      await query;

      if (!mounted) return;

      setState(() {
        _otherDevices.clear();
        _isLoggingOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.verified_user_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text('All other devices have been logged out.')),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to logout other devices: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showLogoutConfirmation(String sessionId, String rawDeviceInfo, String deviceTitle) {
    if (_isDebounced()) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFDC2626),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Log Out Device?',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textHeadline,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to end the session on "$deviceTitle"? You will need to sign in again on that device.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: AppColors.textSubtle,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _logoutDevice(sessionId, rawDeviceInfo, deviceTitle);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Log Out',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLogoutAllConfirmation() {
    if (_isDebounced()) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.power_settings_new_rounded,
                    color: Color(0xFFDC2626),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Log Out All Other Devices?',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textHeadline,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This will immediately sign out all other devices logged into your account. You will stay signed in on this device.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: AppColors.textSubtle,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _logoutAllOtherDevices();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Log Out All',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isWebEmbedded) {
      return _buildContent();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textHeadline,
            size: 18,
          ),
          onPressed: () {
            if (!_isDebounced()) Navigator.pop(context);
          },
        ),
        title: Text(
          'Manage Login Devices',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17.5,
            fontWeight: FontWeight.w800,
            color: AppColors.textHeadline,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2.5,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSubtle),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        if (!_isDebounced()) _loadDevices();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDevices,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Security header info card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Review all devices currently signed in to your account. Log out unrecognized sessions anytime.',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: AppColors.textSubtle,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // THIS DEVICE SECTION
            Text(
              'THIS DEVICE',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF64748B),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            if (_currentDevice != null)
              _buildThisDeviceCard(_currentDevice!)
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text('Current device session initialized.'),
              ),

            const SizedBox(height: 28),

            // OTHER DEVICES SECTION
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'OTHER ACTIVE SESSIONS (${_otherDevices.length})',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_otherDevices.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.devices_rounded,
                        color: Color(0xFF94A3B8),
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No Other Active Sessions',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHeadline,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your account is currently active only on this device.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: AppColors.textSubtle,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _otherDevices.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final device = _otherDevices[index];
                  return _buildOtherDeviceCard(device);
                },
              ),

              const SizedBox(height: 24),

              // Logout All Other Sessions Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _isLoggingOut ? null : _showLogoutAllConfirmation,
                  icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                  label: Text(
                    'Log Out of All Other Devices',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    backgroundColor: const Color(0xFFFEF2F2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildThisDeviceCard(Map<String, dynamic> device) {
    final title = device['title'] as String;
    final subtitle = device['subtitle'] as String;
    final deviceType = device['device_type'] as DeviceCategory? ?? DeviceCategory.phone;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _getDeviceIcon(deviceType),
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF065F46),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF16A34A),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Active now',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$subtitle • Current Session',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF047857),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherDeviceCard(Map<String, dynamic> device) {
    final sessionId = device['session_id'] as String;
    final title = device['title'] as String;
    final subtitle = device['subtitle'] as String;
    final lastActive = device['last_active_formatted'] as String;
    final deviceType = device['device_type'] as DeviceCategory? ?? DeviceCategory.desktop;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _getDeviceIcon(deviceType),
              color: const Color(0xFF475569),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHeadline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '$subtitle • $lastActive',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSubtle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isLoggingOut
                ? null
                : () => _showLogoutConfirmation(
                      sessionId,
                      device['raw_name'] as String? ?? '',
                      title,
                    ),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFEE2E2)),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFDC2626),
                size: 16,
              ),
            ),
            tooltip: 'Log out device',
          ),
        ],
      ),
    );
  }

  IconData _getDeviceIcon(DeviceCategory category) {
    switch (category) {
      case DeviceCategory.phone:
        return Icons.smartphone_rounded;
      case DeviceCategory.tablet:
        return Icons.tablet_mac_rounded;
      case DeviceCategory.desktop:
        return Icons.laptop_mac_rounded;
    }
  }

  FormattedDeviceInfo _parseDeviceInfo(String raw, String platform) {
    final lowerRaw = raw.toLowerCase();
    final lowerPlatform = platform.toLowerCase();

    // 1. Android Mobile / Tablet
    if (lowerPlatform == 'android' || lowerRaw.contains('android')) {
      final parts = raw.split('|').map((s) => s.trim()).toList();
      String osVersion = '';
      String model = '';

      for (var p in parts) {
        if (p.toLowerCase().startsWith('android')) {
          osVersion = p;
        } else if (model.isEmpty && p.isNotEmpty) {
          model = p;
        }
      }

      final title = model.isNotEmpty ? model : 'Android Device';
      final subtitle = osVersion.isNotEmpty ? 'Android App ($osVersion)' : 'Android Mobile';
      return FormattedDeviceInfo(
        title: title,
        subtitle: subtitle,
        deviceType: DeviceCategory.phone,
      );
    }

    // 2. iOS (iPhone / iPad)
    if (lowerPlatform == 'ios' || lowerRaw.contains('iphone') || lowerRaw.contains('ipad')) {
      final isTablet = lowerRaw.contains('ipad');
      String title = isTablet ? 'iPad' : 'iPhone';
      if (lowerRaw.contains('iphone')) {
        title = 'Apple iPhone';
      }
      return FormattedDeviceInfo(
        title: title,
        subtitle: 'iOS Mobile App',
        deviceType: isTablet ? DeviceCategory.tablet : DeviceCategory.phone,
      );
    }

    // 3. Web Browsers
    if (lowerPlatform == 'web' || lowerRaw.contains('mozilla') || lowerRaw.contains('chrome') || lowerRaw.contains('safari')) {
      String browser = 'Web Browser';
      if (lowerRaw.contains('edg/') || lowerRaw.contains('edge')) {
        browser = 'Microsoft Edge';
      } else if (lowerRaw.contains('chrome')) {
        browser = 'Google Chrome';
      } else if (lowerRaw.contains('safari') && !lowerRaw.contains('chrome')) {
        browser = 'Apple Safari';
      } else if (lowerRaw.contains('firefox')) {
        browser = 'Mozilla Firefox';
      }

      String os = 'Web';
      if (lowerRaw.contains('windows')) {
        os = 'Windows PC';
      } else if (lowerRaw.contains('macintosh') || lowerRaw.contains('mac os')) {
        os = 'macOS';
      } else if (lowerRaw.contains('linux')) {
        os = 'Linux';
      } else if (lowerRaw.contains('android')) {
        os = 'Android Web';
      } else if (lowerRaw.contains('iphone') || lowerRaw.contains('ipad')) {
        os = 'iOS Web';
      }

      return FormattedDeviceInfo(
        title: '$browser on $os',
        subtitle: 'Web Session',
        deviceType: DeviceCategory.desktop,
      );
    }

    // 4. Desktop apps
    if (lowerPlatform == 'windows') {
      return FormattedDeviceInfo(
        title: 'Windows Computer',
        subtitle: 'Desktop App',
        deviceType: DeviceCategory.desktop,
      );
    }
    if (lowerPlatform == 'macos') {
      return FormattedDeviceInfo(
        title: 'Mac Computer',
        subtitle: 'Desktop App',
        deviceType: DeviceCategory.desktop,
      );
    }

    return FormattedDeviceInfo(
      title: raw.isNotEmpty ? raw : 'AgriDirect Device',
      subtitle: platform.toUpperCase(),
      deviceType: DeviceCategory.phone,
    );
  }
}

enum DeviceCategory { phone, tablet, desktop }

class FormattedDeviceInfo {
  final String title;
  final String subtitle;
  final DeviceCategory deviceType;

  FormattedDeviceInfo({
    required this.title,
    required this.subtitle,
    required this.deviceType,
  });
}
