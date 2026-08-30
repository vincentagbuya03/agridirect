import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/utils/apk_downloader.dart';

/// Web Farmer Registration Screen — informs users that farm onboarding & identity verification
/// are exclusive to the AgriDirect Mobile App with GPS & Camera biometrics.
class WebFarmerRegistrationScreen extends StatelessWidget {
  final VoidCallback onRegistrationComplete;

  const WebFarmerRegistrationScreen({
    super.key,
    required this.onRegistrationComplete,
  });

  static const Color _primary = Color(0xFF16A34A);
  static const Color _dark = Color(0xFF111827);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 700;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _dark),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
        title: Text(
          'Farmer Registration',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _dark,
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _border, height: 1),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 32,
            vertical: 40,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 620),
            padding: EdgeInsets.all(isMobile ? 24 : 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Visual Badge
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _primary.withValues(alpha: 0.25),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.agriculture_rounded,
                    color: _primary,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),

                // Main Heading
                Text(
                  'Farm Registration is on Mobile',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isMobile ? 24 : 28,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),

                // Subtitle
                Text(
                  'To ensure high trust and security, farm verification, live GPS geotagging, and ID biometric scanning require the AgriDirect Mobile App.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: _muted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),

                // Key Requirements list
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    children: [
                      _buildReasonRow(
                        icon: Icons.pin_drop_rounded,
                        title: 'Live GPS Farm Geolocation',
                        desc:
                            'Capture exact farm boundaries and location on-site.',
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: _border),
                      ),
                      _buildReasonRow(
                        icon: Icons.document_scanner_rounded,
                        title: 'PhilSys / Valid ID Verification',
                        desc:
                            'Real-time photo ID scanning and face verification.',
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: _border),
                      ),
                      _buildReasonRow(
                        icon: Icons.store_rounded,
                        title: 'Mobile Seller Dashboard',
                        desc:
                            'Manage crops, orders, and chats directly from your phone.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // CTA Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go(AppRoutes.home);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: _border, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Back to Home',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _muted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await ApkDownloader.download();
                        },
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: Text(
                          'Get Android App',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReasonRow({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _primary, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
