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
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Expanded(
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Verification Guide',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),

                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: const Color(0xFF10B981),
                    unselectedLabelColor: Colors.grey[400],
                    indicatorColor: const Color(0xFF10B981),
                    indicatorWeight: 3,
                    labelStyle: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    tabs: const [
                      Tab(text: 'Face Scan'),
                      Tab(text: 'ID Front'),
                      Tab(text: 'ID Back / QR'),
                    ],
                  ),

                  Expanded(
                    child: TabBarView(
                      children: [
                        _GuidePage(
                          title: 'Face Biometric Scan',
                          description:
                              'We need to verify that you are the real owner of the ID.',
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
                                  'Align your face within the circular frame provided.',
                              isCorrect: true,
                            ),
                            _GuideStep(
                              title: 'Remove Accessories',
                              description:
                                  'Remove sunglasses, masks, or hats that cover your face.',
                              isCorrect: false,
                              wrongLabel: 'Don\'t cover your face',
                            ),
                          ],
                        ),
                        _GuidePage(
                          title: 'ID Front Capture',
                          description:
                              'Capture a clear photo of the front side of your ID.',
                          lottiePath: 'assets/lottie/Scan User ID.json',
                          steps: [
                            _GuideStep(
                              title: 'Flat Surface',
                              description:
                                  'Place your ID on a flat, dark surface for contrast.',
                              isCorrect: true,
                            ),
                            _GuideStep(
                              title: 'Avoid Glare',
                              description:
                                  'Ensure there are no bright reflections on the ID card.',
                              isCorrect: true,
                            ),
                            _GuideStep(
                              title: 'Blurry Photo',
                              description:
                                  'Text must be readable. Don\'t move while capturing.',
                              isCorrect: false,
                              wrongLabel: 'Don\'t submit blurry images',
                            ),
                          ],
                        ),
                        _GuidePage(
                          title: 'QR Code / ID Back',
                          description:
                              'Scan the QR code on the back of your National ID.',
                          lottiePath: 'assets/lottie/Scan User ID.json',
                          steps: [
                            _GuideStep(
                              title: 'Steady Focus',
                              description:
                                  'Hold your phone steady until the QR is recognized.',
                              isCorrect: true,
                            ),
                            _GuideStep(
                              title: 'Distance',
                              description:
                                  'Keep the QR code about 10-15cm away from the camera.',
                              isCorrect: true,
                            ),
                            _GuideStep(
                              title: 'Moving Camera',
                              description:
                                  'Movement will cause the scanner to fail extraction.',
                              isCorrect: false,
                              wrongLabel: 'Avoid shaky hands',
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
                      height: 56,
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
                            fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Center(
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Lottie.asset(
                lottiePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Lottie error ($lottiePath): $error');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 40,
                          color: const Color(0xFFEF4444),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Animation error',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
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
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCorrect ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCorrect ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCorrect
                  ? const Color(0xFF22C55E)
                  : const Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCorrect ? Icons.check_rounded : Icons.close_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCorrect ? title : (wrongLabel ?? title),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isCorrect
                        ? const Color(0xFF166534)
                        : const Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                    style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: isCorrect
                        ? const Color(0xFF166534).withValues(alpha: 0.7)
                        : const Color(0xFF991B1B).withValues(alpha: 0.7),
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
