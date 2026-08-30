import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

class VerificationGuideWidget extends StatelessWidget {
  const VerificationGuideWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 14),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          Expanded(
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verification Guide',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tips for quick and successful approval',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: const Color(0xFF10B981),
                    unselectedLabelColor: const Color(0xFF94A3B8),
                    indicatorColor: const Color(0xFF10B981),
                    indicatorWeight: 3,
                    indicatorSize: TabBarIndicatorSize.label,
                    dividerColor: const Color(0xFFF1F5F9),
                    labelStyle: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    tabs: const [
                      Tab(text: 'Face Scan'),
                      Tab(text: 'ID Front'),
                      Tab(text: 'ID Back'),
                    ],
                  ),

                  Expanded(
                    child: TabBarView(
                      children: [
                        _GuidePage(
                          title: 'Face Biometric Scan',
                          description:
                              'We verify that you match your valid government ID.',
                          lottiePath: 'assets/lottie/Face Scan.json',
                          steps: [
                            _GuideStep(
                              title: 'Good Lighting',
                              description:
                                  'Make sure your face is well-lit and not in shadow.',
                              isCorrect: true,
                            ),
                            _GuideStep(
                              title: 'Center your Face',
                              description:
                                  'Align your face within the circle frame provided.',
                              isCorrect: true,
                            ),
                            _GuideStep(
                              title: 'Remove Accessories',
                              description:
                                  'Remove sunglasses, face masks, or hats covering your face.',
                              isCorrect: false,
                              wrongLabel: 'Don\'t cover your face',
                            ),
                          ],
                        ),
                        _GuidePage(
                          title: 'ID Front Capture',
                          description:
                              'Capture a clear, sharp photo of the front of your ID card.',
                          lottiePath: 'assets/lottie/Scan User ID.json',
                          steps: [
                            _GuideStep(
                              title: 'Flat & Contrasting Surface',
                              description:
                                  'Place your ID on a plain, dark background for high contrast.',
                              isCorrect: true,
                            ),
                            _GuideStep(
                              title: 'Avoid Direct Glare',
                              description:
                                  'Ensure no bright light reflections obscure your photo or name.',
                              isCorrect: true,
                            ),
                            _GuideStep(
                              title: 'Blurry Photo',
                              description:
                                  'All text and ID numbers must be sharp and legible.',
                              isCorrect: false,
                              wrongLabel: 'Don\'t submit blurry images',
                            ),
                          ],
                        ),
                        _GuidePage(
                          title: 'ID Back Capture',
                          description:
                              'Capture a clear, sharp photo of the back side of your ID.',
                          lottiePath: 'assets/lottie/Scan User ID.json',
                          steps: [
                            _GuideStep(
                              title: 'All 4 Corners Visible',
                              description:
                                  'Keep the full ID card inside the capture camera frame.',
                              isCorrect: true,
                            ),
                            _GuideStep(
                              title: 'Hold Steady',
                              description:
                                  'Rest your hands to ensure maximum camera focus.',
                              isCorrect: true,
                            ),
                            _GuideStep(
                              title: 'Obscured Details',
                              description:
                                  'Ensure fingers or shadows do not block barcodes or signatures.',
                              isCorrect: false,
                              wrongLabel: 'Avoid covering card edges',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Got it, let\'s start!',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Center(
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Lottie.asset(
                lottiePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.badge_rounded,
                          size: 48,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Card Verification Guide',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
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
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCorrect ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCorrect ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isCorrect
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCorrect ? Icons.check_rounded : Icons.close_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCorrect ? title : (wrongLabel ?? title),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isCorrect
                        ? const Color(0xFF166534)
                        : const Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: isCorrect
                        ? const Color(0xFF166534).withValues(alpha: 0.8)
                        : const Color(0xFF991B1B).withValues(alpha: 0.8),
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
