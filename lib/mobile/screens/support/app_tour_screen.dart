import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../../shared/styles/app_theme.dart';

class AppTourScreen extends StatefulWidget {
  const AppTourScreen({super.key});

  @override
  State<AppTourScreen> createState() => _AppTourScreenState();
}

class _AppTourScreenState extends State<AppTourScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _tourSlides = [
    {
      'title': 'Direct Farm-to-Table',
      'subtitle': 'Connect directly with local agricultural producers in your area with zero middlemen.',
      'lottie': 'assets/lottie/onboarding_farm.json',
      'icon': Icons.agriculture_rounded,
      'color': const Color(0xFF10B981),
      'badge': 'Fresh Harvests',
    },
    {
      'title': 'Smart Crop Pre-Orders',
      'subtitle': 'Reserve upcoming harvests ahead of time. Farmers cultivate with guaranteed buyers.',
      'lottie': 'assets/lottie/onboarding_market.json',
      'icon': Icons.calendar_month_rounded,
      'color': const Color(0xFF0EA5E9),
      'badge': 'Pre-Order Engine',
    },
    {
      'title': 'Live Weather & Radar Insights',
      'subtitle': 'Stay informed with hyper-local rain radar and weather warnings tailored to your location.',
      'lottie': 'assets/lottie/onboarding_tech.json',
      'icon': Icons.thunderstorm_rounded,
      'color': const Color(0xFFF59E0B),
      'badge': 'Radar & Analytics',
    },
    {
      'title': 'Kiko Smart AI Assistant',
      'subtitle': 'Ask Kiko anything—from crop care & market price trends to app features & vouchers.',
      'lottie': 'assets/lottie/Security.json',
      'icon': Icons.support_agent_rounded,
      'color': const Color(0xFF8B5CF6),
      'badge': '24/7 Carabao Help',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = _tourSlides[_currentPage];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textHeadline, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'App Tour & Feature Guide',
          style: AppTextStyles.headline3.copyWith(fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Skip',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: AppColors.textSubtle,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _tourSlides.length,
                itemBuilder: (context, index) {
                  final item = _tourSlides[index];
                  final Color itemColor = item['color'];
                  final String lottiePath = item['lottie'];

                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Lottie Hero Container (same as onboarding)
                        Container(
                          width: double.infinity,
                          height: 220,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: itemColor.withValues(alpha: 0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: itemColor.withValues(alpha: 0.1),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Lottie.asset(
                            lottiePath,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                alignment: Alignment.center,
                                child: Icon(
                                  item['icon'] as IconData,
                                  size: 72,
                                  color: itemColor,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: itemColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            item['badge'].toString().toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: itemColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          item['title'].toString(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textHeadline,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item['subtitle'].toString(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            color: AppColors.textSubtle,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Page indicator and Navigation Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Indicators
                  Row(
                    children: List.generate(_tourSlides.length, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 6),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive ? (slide['color'] as Color) : Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  // Next / Finish Button
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage < _tourSlides.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: slide['color'] as Color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _currentPage == _tourSlides.length - 1 ? 'Get Started' : 'Next',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
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
