import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../../shared/styles/app_theme.dart';

class VerificationGuideWidget extends StatefulWidget {
  const VerificationGuideWidget({super.key});

  @override
  State<VerificationGuideWidget> createState() => _VerificationGuideWidgetState();
}

class _VerificationGuideWidgetState extends State<VerificationGuideWidget> {
  bool _isClosing = false;

  void _safeClose() {
    if (_isClosing) return;
    _isClosing = true;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 6),
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Header Row
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 18, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verification Guide',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textHeadline,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Follow these tips for quick and smooth approval',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSubtle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _safeClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Custom Segmented Pill Tab Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TabBar(
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  labelColor: AppColors.primary,
                  unselectedLabelColor: const Color(0xFF64748B),
                  labelStyle: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                  unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  tabs: const [
                    Tab(
                      height: 36,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.face_rounded, size: 14),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Face Scan',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      height: 36,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.badge_rounded, size: 14),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'ID Front',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      height: 36,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flip_rounded, size: 14),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'ID Back',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Tab Content with Stack for Sticky Bottom Button
            Expanded(
              child: Stack(
                children: [
                  const TabBarView(
                    children: [
                      _GuidePage(
                        title: 'Face Biometric Scan',
                        description:
                            'We verify your selfie matches your official government ID.',
                        lottiePath: 'assets/lottie/Face Scan.json',
                        steps: [
                          _GuideStep(
                            title: 'Good Lighting',
                            description:
                                'Make sure your face is well-lit and evenly illuminated without harsh shadows.',
                            isCorrect: true,
                          ),
                          _GuideStep(
                            title: 'Center Your Face',
                            description:
                                'Position your face directly inside the camera guide frame and look straight ahead.',
                            isCorrect: true,
                          ),
                          _GuideStep(
                            title: 'Remove Obstructions',
                            description:
                                'Take off sunglasses, hats, face masks, or thick scarves before scanning.',
                            isCorrect: false,
                            wrongLabel: 'Don\'t Cover Your Face',
                          ),
                        ],
                      ),
                      _GuidePage(
                        title: 'ID Front Photo',
                        description:
                            'Capture a clear, high-resolution photo of the front of your ID card.',
                        lottiePath: 'assets/lottie/Scan User ID.json',
                        steps: [
                          _GuideStep(
                            title: 'Flat & Contrasting Background',
                            description:
                                'Place your ID on a flat, clean surface with a contrasting dark background.',
                            isCorrect: true,
                          ),
                          _GuideStep(
                            title: 'Avoid Glare & Reflections',
                            description:
                                'Tilt away from overhead lights to ensure text and your photo are completely glare-free.',
                            isCorrect: true,
                          ),
                          _GuideStep(
                            title: 'Blurry or Tilted Photos',
                            description:
                                'All letters, numbers, and ID details must be sharp, clear, and easy to read.',
                            isCorrect: false,
                            wrongLabel: 'Don\'t Submit Blurry Photos',
                          ),
                        ],
                      ),
                      _GuidePage(
                        title: 'ID Back Photo',
                        description:
                            'Capture a crisp photo of the back side of your ID card.',
                        lottiePath: 'assets/lottie/Scan User ID.json',
                        steps: [
                          _GuideStep(
                            title: 'All 4 Corners Visible',
                            description:
                                'Ensure the entire card fits inside the viewfinder without cutting off edges.',
                            isCorrect: true,
                          ),
                          _GuideStep(
                            title: 'Hold Device Steady',
                            description:
                                'Keep your hands still so the camera can achieve sharp autofocus on barcodes.',
                            isCorrect: true,
                          ),
                          _GuideStep(
                            title: 'Covered Barcodes / Signatures',
                            description:
                                'Do not place fingers or objects over barcodes, QR codes, or signature boxes.',
                            isCorrect: false,
                            wrongLabel: 'Don\'t Obscure Barcodes',
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Floating Gradient CTA Container at bottom
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.95),
                            Colors.white,
                          ],
                          stops: const [0.0, 0.35, 1.0],
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _safeClose,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: AppColors.primary.withValues(alpha: 0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Got it, let\'s start!',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidePage extends StatelessWidget {
  final String title;
  final String description;
  final String lottiePath;
  final List<_GuideStep> steps;

  const _GuidePage({
    required this.title,
    required this.description,
    required this.lottiePath,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      // Extra bottom padding (100px) ensures full scroll clearance above the sticky CTA button
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Animation Container
          Center(
            child: Container(
              height: 165,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Lottie.asset(
                  lottiePath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified_user_rounded,
                              size: 36,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Section Title & Description
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textHeadline,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: AppColors.textSubtle,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),

          // Checklist Cards
          ...steps,
        ],
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  final String title;
  final String description;
  final bool isCorrect;
  final String? wrongLabel;

  const _GuideStep({
    required this.title,
    required this.description,
    required this.isCorrect,
    this.wrongLabel,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isCorrect ? const Color(0xFFF0FDF4) : const Color(0xFFFFF1F2);
    final borderColor = isCorrect ? const Color(0xFFBBF7D0) : const Color(0xFFFECDD3);
    final tagBgColor = isCorrect ? const Color(0xFFDCFCE7) : const Color(0xFFFFE4E6);
    final tagTextColor = isCorrect ? const Color(0xFF166534) : const Color(0xFF9F1239);
    final iconColor = isCorrect ? const Color(0xFF16A34A) : const Color(0xFFE11D48);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Circle
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCorrect ? Icons.check_rounded : Icons.close_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 12),

          // Title, Tag & Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // DO / AVOID pill tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: tagBgColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: borderColor,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        isCorrect ? 'DO' : 'AVOID',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: tagTextColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isCorrect ? title : (wrongLabel ?? title),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: tagTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: tagTextColor.withValues(alpha: 0.85),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
