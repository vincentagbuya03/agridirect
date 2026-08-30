import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/utils/apk_downloader.dart';

class WebMobileFarmerDialog extends StatelessWidget {
  const WebMobileFarmerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const WebMobileFarmerDialog(),
    );
  }

  static const Color _primary = Color(0xFF16A34A);
  static const Color _dark = Color(0xFF111827);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isCompact = sw < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 16 : 32,
        vertical: 24,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isCompact ? 24 : 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header Icon Badge
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _primary.withValues(alpha: 0.25),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.phone_android_rounded,
                  color: _primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Register Farm on Mobile',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isCompact ? 22 : 26,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                'Farm registration, live GPS geotagging, and seller verification are exclusively available on the AgriDirect Mobile App.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: _muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Feature Highlights Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  children: [
                    _buildFeatureItem(
                      icon: Icons.location_on_rounded,
                      title: 'Live GPS Farm Geotagging',
                      description:
                          'Accurate on-site mapping of your agricultural land.',
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: _border),
                    ),
                    _buildFeatureItem(
                      icon: Icons.badge_rounded,
                      title: 'Instant ID & Face Verification',
                      description:
                          'Secure PhilSys and biometric capture using your device camera.',
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: _border),
                    ),
                    _buildFeatureItem(
                      icon: Icons.inventory_2_rounded,
                      title: 'Mobile Farm Management',
                      description:
                          'Post harvests, manage orders, and track deliveries on the go.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: _border, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _muted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
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
          child: Icon(icon, color: _primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 12,
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
