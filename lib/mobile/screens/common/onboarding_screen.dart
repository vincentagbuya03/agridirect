import 'dart:async';
import 'package:flutter/material.dart';
import '../../../shared/widgets/brand_logo.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../../shared/services/auth/onboarding_service.dart';

/// A professional, high-end immersive onboarding experience for AgriDirect.
/// Optimized for stability, content relevance, and layout constraints.
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

  // Local Lottie asset paths
  static const List<String> _lottieAssets = [
    'assets/lottie/onboarding_farm.json',
    'assets/lottie/onboarding_market.json',
    'assets/lottie/onboarding_tech.json',
  ];

  static const List<Map<String, dynamic>> _pages = [
    {
      'title': 'Smart Climate\nMonitoring',
      'subtitle':
          'Leverage real-time cloud data and weather analytics to protect your crops and optimize your yield strategy.',
      'icon': Icons.cloud_sync_rounded,
      'themeColor': Color(0xFF10B981),
      'gradient': [Color(0xFF065F46), Color(0xFF10B981)],
    },
    {
      'title': 'Direct Dealer\nNegotiations',
      'subtitle':
          'Close the best deals with zero intermediaries. Our secure platform connects you directly to verified bulk buyers.',
      'icon': Icons.handshake_rounded,
      'themeColor': Color(0xFFF59E0B),
      'gradient': [Color(0xFF92400E), Color(0xFFF59E0B)],
    },
    {
      'title': 'Connected Agri\nCommunity',
      'subtitle':
          'Instant messaging and 24/7 digital support. Stay connected with fellow farmers and industry experts anywhere.',
      'icon': Icons.forum_rounded,
      'themeColor': Color(0xFF3B82F6),
      'gradient': [Color(0xFF1E40AF), Color(0xFF3B82F6)],
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

  void _next() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutQuart,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPageData = _pages[_currentPage];
    final themeColor = currentPageData['themeColor'] as Color;
    final gradient = currentPageData['gradient'] as List<Color>;

    return Scaffold(
      body: Stack(
        children: [
          // ── Immersive Background ──
          AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
            ),
          ),

          // ── Decorative Mesh with Constraint Safety ──
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(painter: MeshPainter(themeColor)),
                ),
              ),
            ),
          ),

          // ── Main Content View ──
          PageView.builder(
            controller: _pageController,
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemCount: 3,
            itemBuilder: (context, index) => _buildPage(index),
          ),

          // ── Top Header ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const BrandLogo(size: BrandLogoSize.small, color: Colors.white),
                TextButton(
                  onPressed: _completeOnboarding,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.7),
                  ),
                  child: Text(
                    'SKIP',
                    style: GoogleFonts.plusJakartaSans(
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom Controller (Anchored) ──
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 40,
            left: 32,
            right: 32,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildProgressIndicators(),
                const SizedBox(height: 40),
                _buildActionButton(themeColor, _currentPage == 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    final page = _pages[index];
    final screenHeight = MediaQuery.of(context).size.height;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Container(
        // Set height to at least screenHeight, but allow it to be more if content overflows
        constraints: BoxConstraints(minHeight: screenHeight),
        // Significant bottom padding (200) to prevent overlap with fixed bottom controller
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 200),
        child: Column(
          children: [
            SizedBox(height: screenHeight * 0.16),

            // ── Animation Area ──
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, 30 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Container(
                height: screenHeight * 0.30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 50,
                      spreadRadius: -20,
                    ),
                  ],
                ),
                child: Lottie.asset(_lottieAssets[index], fit: BoxFit.contain),
              ),
            ),

            SizedBox(height: screenHeight * 0.06),

            // ── Typography Layer ──
            Text(
              page['title'] as String,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.1,
                letterSpacing: -1,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              page['subtitle'] as String,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final isActive = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 4,
          width: isActive ? 40 : 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.3),
          ),
        );
      }),
    );
  }

  Widget _buildActionButton(Color themeColor, bool isLastPage) {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _next,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: themeColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isLastPage ? 'Start' : 'CONTINUE',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            if (!isLastPage) ...[
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: themeColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Custom Mesh Painter for a professional textured background
class MeshPainter extends CustomPainter {
  final Color color;
  MeshPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width.isInfinite || size.height.isInfinite) return;

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const spacing = 40.0;
    if (size.width > 0 && size.height > 0) {
      for (double i = 0; i < size.width; i += spacing) {
        canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
      }
      for (double i = 0; i < size.height; i += spacing) {
        canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
