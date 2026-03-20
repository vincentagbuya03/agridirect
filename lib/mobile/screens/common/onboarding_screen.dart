import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../../shared/services/user/onboarding_service.dart';

/// Onboarding screen shown once for first-time users.
/// Uses Lottie animations for a beautiful, modern experience.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onOnboardingComplete;

  const OnboardingScreen({super.key, required this.onOnboardingComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;

  static const Color _primary = Color(0xFF13EC5B);
  static const Color _darkGreen = Color(0xFF004D2B);

  // Lottie animation URLs (agriculture/marketplace themed)
  static const List<String> _lottieUrls = [
    // Page 1: Farm/organic produce
    'https://assets3.lottiefiles.com/packages/lf20_ysrn2iwp.json',
    // Page 2: Shopping/delivery
    'https://assets3.lottiefiles.com/packages/lf20_jmejybvu.json',
    // Page 3: Analytics/insights
    'https://assets3.lottiefiles.com/packages/lf20_fcfjwiyb.json',
  ];

  static const List<Map<String, dynamic>> _pages = [
    {
      'title': 'Direct From Farm',
      'subtitle':
          'Connect directly with local farmers for the freshest produce, ensuring fair prices for everyone.',
      'icon': Icons.eco_rounded,
      'gradientColors': [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
    },
    {
      'title': 'Pre-Order Upcoming\nHarvests',
      'subtitle':
          'Secure your seasonal favorites before harvest at exclusive prices and get notified when they\'re ready.',
      'icon': Icons.shopping_basket_rounded,
      'gradientColors': [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
    },
    {
      'title': 'AI-Powered\nInsights',
      'subtitle':
          'Stay ahead with weather alerts, demand predictions, and a community of growers sharing knowledge.',
      'icon': Icons.auto_awesome_rounded,
      'gradientColors': [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    await OnboardingService.completeOnboarding();
    if (mounted) {
      widget.onOnboardingComplete();
    }
  }

  void _skip() => _completeOnboarding();

  void _next() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  // ---------- BUILD ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Page content
          PageView.builder(
            controller: _pageController,
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemCount: 3,
            itemBuilder: (context, index) => _buildPage(index),
          ),
          // Top bar with logo and skip
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AgriDirect',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _darkGreen,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _skip,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Skip',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    final page = _pages[index];
    final gradientColors = page['gradientColors'] as List<Color>;
    final isLastPage = index == 2;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            gradientColors[0],
            gradientColors[1],
            Colors.white,
            Colors.white,
          ],
          stops: const [0.0, 0.35, 0.55, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),

            // Lottie animation area
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: _buildLottieAnimation(index, page),
              ),
            ),

            // Bottom content area
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(36),
                    topRight: Radius.circular(36),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Page indicators
                    _buildPageIndicators(),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      page['title'] as String,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: _darkGreen,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Subtitle
                    Text(
                      page['subtitle'] as String,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF6B7280),
                        height: 1.6,
                      ),
                    ),

                    const Spacer(),

                    // Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLastPage ? 'Get Started' : 'Next',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isLastPage
                                  ? Icons.rocket_launch_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLottieAnimation(int index, Map<String, dynamic> page) {
    return Center(
      child: Lottie.network(
        _lottieUrls[index],
        fit: BoxFit.contain,
        repeat: true,
        animate: true,
        errorBuilder: (context, error, stackTrace) {
          // Beautiful fallback with animated icon
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: child,
              );
            },
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: (page['gradientColors'] as List<Color>)[0],
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _primary.withOpacity(0.2),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Icon(
                page['icon'] as IconData,
                color: _primary,
                size: 80,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPageIndicators() {
    return Row(
      children: List.generate(3, (i) {
        final isActive = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(right: 8),
          height: 6,
          width: isActive ? 28 : 8,
          decoration: BoxDecoration(
            color: isActive ? _primary : const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
