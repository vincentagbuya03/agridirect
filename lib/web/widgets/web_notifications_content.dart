import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WebNotificationsContent extends StatefulWidget {
  const WebNotificationsContent({super.key});

  @override
  State<WebNotificationsContent> createState() => _WebNotificationsContentState();
}

class _WebNotificationsContentState extends State<WebNotificationsContent> {
  bool _isLoaded = false;
  bool _isSaving = false;

  bool _emailAlerts = true;
  bool _pushAlerts = true;
  bool _promoAlerts = false;

  final Color primary = const Color(0xFF10B981);
  final Color _dark = const Color(0xFF1E293B);
  final Color _muted = const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _emailAlerts = prefs.getBool('notifications.email_alerts') ?? true;
        _pushAlerts = prefs.getBool('notifications.push_alerts') ?? true;
        _promoAlerts = prefs.getBool('notifications.promo_alerts') ?? false;
        _isLoaded = true;
      });
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications.email_alerts', _emailAlerts);
    await prefs.setBool('notifications.push_alerts', _pushAlerts);
    await prefs.setBool('notifications.promo_alerts', _promoAlerts);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification preferences saved successfully!'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
    }

    return Container(
      padding: const EdgeInsets.all(32),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.notifications_active_outlined,
                  color: primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notification Settings',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Customize how and when you want to receive alerts from AgriDirect',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 48, color: Color(0xFFF1F5F9)),
          
          SwitchListTile.adaptive(
            activeTrackColor: primary.withValues(alpha: 0.5),
            activeThumbColor: primary,
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.mail_outline_rounded, color: Colors.blue),
            ),
            title: Text(
              'Email Notifications',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            subtitle: const Text('Receive order status updates via email'),
            value: _emailAlerts,
            onChanged: _isSaving ? null : (val) => setState(() => _emailAlerts = val),
          ),
          const Divider(height: 24),
          SwitchListTile.adaptive(
            activeTrackColor: primary.withValues(alpha: 0.5),
            activeThumbColor: primary,
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.phonelink_ring_rounded, color: Colors.green),
            ),
            title: Text(
              'Push Notifications',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            subtitle: const Text('Receive message alerts and activity updates'),
            value: _pushAlerts,
            onChanged: _isSaving ? null : (val) => setState(() => _pushAlerts = val),
          ),
          const Divider(height: 24),
          SwitchListTile.adaptive(
            activeTrackColor: primary.withValues(alpha: 0.5),
            activeThumbColor: primary,
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_offer_outlined, color: Colors.orange),
            ),
            title: Text(
              'Promotions & Offers',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            subtitle: const Text('Get notified of discount codes and local deals'),
            value: _promoAlerts,
            onChanged: _isSaving ? null : (val) => setState(() => _promoAlerts = val),
          ),
          const SizedBox(height: 48),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: _isSaving ? null : _savePreferences,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        'Save Preferences',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
