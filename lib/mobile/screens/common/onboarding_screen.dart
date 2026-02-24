import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/onboarding_service.dart';

/// Onboarding screen shown once for first-time users.
/// Matches the provided 3-page design mockups.
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

  void _goToLogin() => _completeOnboarding();

  // ---------- DOT INDICATORS ----------
  Widget _buildDots({
    Color activeColor = _primary,
    Color inactiveColor = const Color(0xFFE0E0E0),
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final isActive = i == _currentPage;
        return GestureDetector(
          onTap: () => _pageController.animateToPage(
            i,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 6,
            width: isActive ? 24 : 8,
            decoration: BoxDecoration(
              color: isActive ? activeColor : inactiveColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }

  // =====================================================
  //  PAGE 1 – Direct From Farm
  // =====================================================
  Widget _buildPage1() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background image
        Image.asset(
          'assets/images/00018379-scaled.webp',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              Container(color: const Color(0xFF76B399)),
        ),
        // Dark overlay
        Container(color: Colors.black.withAlpha(40)),
        // Top header with app name and skip
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 20,
          right: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AgriDirect',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              _buildSkipText(color: Colors.white),
            ],
          ),
        ),
        // Bottom white card
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dots
                _buildDots(),
                const SizedBox(height: 20),
                // Title
                Text(
                  'Direct From Farm',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF004D2B),
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 16),
                // Subtitle
                Text(
                  'Connect directly with local farmers for the freshest produce, ensuring fair prices for everyone.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF6B7280),
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 24),
                // Next button full width
                _buildNextButton(compact: false),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =====================================================
  //  PAGE 2 – Pre-Order Upcoming Harvests
  // =====================================================
  Widget _buildPage2() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background image
        Image.asset(
          'assets/images/istockphoto-1137976179-612x612.jpg',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              Container(color: const Color(0xFF8B4513)),
        ),
        // Dark overlay
        Container(color: Colors.black.withAlpha(20)),
        // Top bar: dash indicators + Skip
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 20,
          right: 20,
          child: Row(
            children: [
              ..._buildDashIndicators(),
              const Spacer(),
              _buildSkipText(color: Colors.white70),
            ],
          ),
        ),
        // Days to harvest timer
        Positioned(
          top: 120,
          left: 0,
          right: 0,
          child: Center(child: _buildHarvestTimer()),
        ),
        // Bottom white card
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Shopping basket icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Color(0xFF13EC5B).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shopping_basket_outlined,
                    color: Color(0xFF13EC5B),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                // Title
                Text(
                  'Pre-Order Upcoming\nHarvests',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A1A1A),
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 16),
                // Subtitle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Secure your seasonal favorites before harvest at exclusive prices and get notified when they are ready for delivery.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF6B7280),
                      height: 1.55,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Next button in dark navy
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Next',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =====================================================
  //  PAGE 3 – AI-Powered Insights
  // =====================================================
  Widget _buildPage3() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background image
        Image.asset(
          'assets/images/638342653_1435027501422399_4429077061672726972_n.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              Container(color: const Color(0xFF76B399)),
        ),
        // Light overlay
        Container(color: Colors.white.withAlpha(0)),
        // Top bar: dash indicators + Skip
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 20,
          right: 20,
          child: Row(
            children: [
              ..._buildDashIndicators(),
              const Spacer(),
              _buildSkipText(color: Colors.grey[600]),
            ],
          ),
        ),
        // Bottom white card
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sparkle icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Color(0xFF13EC5B).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF13EC5B),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                // Title
                Text(
                  'AI-Powered Insights',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A1A1A),
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 16),
                // Subtitle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Stay ahead with weather alerts, demand predictions, and a community of growers sharing knowledge.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF6B7280),
                      height: 1.55,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Get Started button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _completeOnboarding,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Get Started',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------- SHARED WIDGETS ----------

  Widget _buildSkipChip({bool light = false}) {
    return GestureDetector(
      onTap: _skip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: light ? Colors.white.withAlpha(200) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Skip',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: light ? const Color(0xFF4A4A4A) : Colors.grey[400],
          ),
        ),
      ),
    );
  }

  Widget _buildSkipText({Color? color}) {
    return GestureDetector(
      onTap: _skip,
      child: Text(
        'Skip',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: color ?? Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildNextButton({required bool compact}) {
    if (compact) {
      return SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: _next,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Next',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _next,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Next',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDashIndicators() {
    return List.generate(3, (i) {
      final isActive = i == _currentPage;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        height: 4,
        width: isActive ? 28 : 20,
        decoration: BoxDecoration(
          color: isActive ? _primary : Colors.white.withAlpha(120),
          borderRadius: BorderRadius.circular(2),
        ),
      );
    });
  }

  Widget _buildHarvestTimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(100),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: _primary, shape: BoxShape.circle),
            child: const Icon(
              Icons.schedule_rounded,
              color: Colors.black,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '05',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            'DAYS TO HARVEST',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- BUILD ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (page) => setState(() => _currentPage = page),
        children: [_buildPage1(), _buildPage2(), _buildPage3()],
      ),
    );
  }
}

// =====================================================
//  Custom painters for illustrations
// =====================================================
/// Custom painters removed - now using Image.network for backgrounds
