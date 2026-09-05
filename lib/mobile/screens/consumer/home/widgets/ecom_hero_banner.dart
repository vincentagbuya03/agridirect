import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../free_shipping_screen.dart';
import '../../fresh_produce_screen.dart';
import '../../local_shops_screen.dart';

/// 16:9 auto-sliding promotional hero banner for AgriDirect.
class EcomHeroBanner extends StatefulWidget {
  const EcomHeroBanner({super.key});

  @override
  State<EcomHeroBanner> createState() => _EcomHeroBannerState();
}

class _EcomHeroBannerState extends State<EcomHeroBanner> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoPlayTimer;

  static const List<Map<String, dynamic>> _bannerData = [
    {
      'title': 'Highland Harvest Deals',
      'subtitle': 'Direct from Benguet & Cordillera farmers',
      'tag': '🌱 100% FARM DIRECT',
      'start': Color(0xFF047857),
      'end': Color(0xFF10B981),
      'icon': Icons.eco_rounded,
      'route': 'fresh_produce',
    },
    {
      'title': 'Free Shipping Program',
      'subtitle': 'Enjoy subsidized delivery on fresh crops',
      'tag': '🚚 ZERO SHIPPING',
      'start': Color(0xFFB45309),
      'end': Color(0xFFF59E0B),
      'icon': Icons.local_shipping_rounded,
      'route': 'free_shipping',
    },
    {
      'title': 'Support Local Farmers',
      'subtitle': 'Empowering agricultural communities nationwide',
      'tag': '🇵🇭 LOCAL PRIDE',
      'start': Color(0xFF1E40AF),
      'end': Color(0xFF3B82F6),
      'icon': Icons.storefront_rounded,
      'route': 'local_shops',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % _bannerData.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _handleBannerTap(String route) {
    Widget? target;
    switch (route) {
      case 'fresh_produce':
        target = const FreshProduceScreen();
        break;
      case 'free_shipping':
        target = const FreeShippingScreen();
        break;
      case 'local_shops':
        target = const LocalShopsScreen();
        break;
    }
    if (target != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => target!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 7.8,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemCount: _bannerData.length,
                  itemBuilder: (context, index) {
                    final banner = _bannerData[index];
                    final start = banner['start'] as Color;
                    final end = banner['end'] as Color;
                    final icon = banner['icon'] as IconData;

                    return GestureDetector(
                      onTap: () => _handleBannerTap(banner['route'] as String),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [start, end],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: start.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            // Ambient backdrop shapes
                            Positioned(
                              right: -25,
                              top: -25,
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 12,
                              bottom: -10,
                              child: Icon(
                                icon,
                                size: 85,
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),

                            // Copy and Tag
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Text(
                                      banner['tag'] as String,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        banner['title'] as String,
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                          height: 1.1,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        banner['subtitle'] as String,
                                        style: GoogleFonts.inter(
                                          color: Colors.white.withValues(alpha: 0.9),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // Floating bottom-right page indicator pill
                Positioned(
                  bottom: 10,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_currentPage + 1} / ${_bannerData.length}',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
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
}
