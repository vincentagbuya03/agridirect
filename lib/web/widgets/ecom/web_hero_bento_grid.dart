import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../constants/web_design_tokens.dart';

/// Hero Bento Grid: Main Carousel (8 cols) + Dual Promotional Micro-Cards (4 cols)
class WebHeroBentoGrid extends StatefulWidget {
  final void Function(int, [String?]) onNavigate;

  const WebHeroBentoGrid({
    super.key,
    required this.onNavigate,
  });

  @override
  State<WebHeroBentoGrid> createState() => _WebHeroBentoGridState();
}

class _WebHeroBentoGridState extends State<WebHeroBentoGrid> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoPlayTimer;
  Timer? _countdownTimer;
  Duration _flashRemaining = const Duration(hours: 3, minutes: 42, seconds: 15);
  Map<String, dynamic>? _featuredFarmer;

  final List<Map<String, dynamic>> _heroSlides = [
    {
      'tag': '100% FARM-DIRECT • SAN CARLOS CITY',
      'title': 'FRESH LOCAL HARVEST\nSTRAIGHT TO YOUR DOOR',
      'subtitle':
          'Experience farm-fresh produce picked daily by certified Pangasinan growers. Zero middleman markups.',
      'badge1': '🌾 Verified Growers',
      'badge2': '⚡ Up to 40% Off',
      'badge3': '🚚 Same-Day Delivery',
      'gradient': [
        const Color(0xFF064E3B),
        const Color(0xFF047857),
        const Color(0xFF059669)
      ],
      'cta': 'SHOP TODAY\'S HARVEST',
      'route': AppRoutes.shop,
    },
    {
      'tag': 'SEASONAL HARVEST RADAR',
      'title': 'PRE-ORDER PANGASINAN\nSWEET MANGOES & GRAINS',
      'subtitle':
          'Lock in guaranteed seasonal prices with local cooperatives before crops hit retail shelves.',
      'badge1': '📦 Bulk Savings',
      'badge2': '🌱 100% Organic',
      'badge3': '🛡️ Escrow Protected',
      'gradient': [
        const Color(0xFF78350F),
        const Color(0xFFB45309),
        const Color(0xFFD97706)
      ],
      'cta': 'EXPLORE PRE-ORDERS',
      'route': AppRoutes.preorders,
    },
    {
      'tag': 'COMMUNITY COOPERATIVE PROGRAM',
      'title': 'SUPPORT LOCAL FARMERS\nEAT HEALTHIER FOOD',
      'subtitle':
          'Over 45 accredited farming families across San Carlos City barangays are ready to deliver.',
      'badge1': '🤝 Fair Payouts',
      'badge2': '🌿 GAP Certified',
      'badge3': '📍 Tracked Batches',
      'gradient': [
        const Color(0xFF1E293B),
        const Color(0xFF0F766E),
        const Color(0xFF16A34A)
      ],
      'cta': 'DISCOVER COOPERATIVES',
      'route': AppRoutes.localShops,
    },
  ];

  @override
  void initState() {
    super.initState();
    _calculateFlashRemaining();
    _loadFeaturedFarmer();
    _pageController = PageController();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % _heroSlides.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        if (_flashRemaining.inSeconds > 0) {
          setState(() {
            _flashRemaining = _flashRemaining - const Duration(seconds: 1);
          });
        } else {
          _calculateFlashRemaining();
          setState(() {});
        }
      }
    });
  }

  Future<void> _loadFeaturedFarmer() async {
    try {
      final farmers = await SupabaseDataService().getFeaturedFarmers();
      if (farmers.isNotEmpty && mounted) {
        setState(() {
          _featuredFarmer = farmers.first;
        });
      }
    } catch (_) {}
  }

  void _calculateFlashRemaining() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _flashRemaining = midnight.difference(now);
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _countdownTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isStacked = sw < 1024;
    final isMobile = sw < 650;

    if (isStacked) {
      return Column(
        children: [
          _buildMainSlider(height: isMobile ? 320 : 380, sw: sw),
          const SizedBox(height: 16),
          if (isMobile) ...[
            _buildFlashDealMiniCard(context),
            const SizedBox(height: 16),
            _buildFarmerSpotlightMiniCard(context),
          ] else ...[
            Row(
              children: [
                Expanded(child: _buildFlashDealMiniCard(context)),
                const SizedBox(width: 16),
                Expanded(child: _buildFarmerSpotlightMiniCard(context)),
              ],
            ),
          ],
        ],
      );
    }

    return SizedBox(
      height: 440,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 8 Columns: Main Hero Slider
          Expanded(
            flex: 8,
            child: _buildMainSlider(sw: sw),
          ),
          const SizedBox(width: 20),
          // 4 Columns: Side Promotional Bento Cards
          Expanded(
            flex: 4,
            child: Column(
              children: [
                Expanded(child: _buildFlashDealMiniCard(context)),
                const SizedBox(height: 16),
                Expanded(child: _buildFarmerSpotlightMiniCard(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainSlider({double? height, required double sw}) {
    final titleFontSize = sw < 450 ? 18.0 : (sw < 650 ? 22.0 : (sw < 1024 ? 26.0 : 30.0));
    final subtitleFontSize = sw < 450 ? 12.0 : 14.0;
    final isMobile = sw < 650;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: WebDesignTokens.cardRest,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemCount: _heroSlides.length,
              itemBuilder: (context, index) {
                final slide = _heroSlides[index];
                final List<Color> colors = slide['gradient'];

                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 20 : 40,
                    vertical: isMobile ? 20 : 36,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          slide['tag'],
                          style: GoogleFonts.rubik(
                            fontSize: isMobile ? 10 : 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      SizedBox(height: isMobile ? 8 : 14),

                      // Headline
                      Text(
                        slide['title'],
                        style: GoogleFonts.rubik(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.15,
                        ),
                      ),
                      SizedBox(height: isMobile ? 6 : 12),

                      // Subtitle
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Text(
                          slide['subtitle'],
                          maxLines: isMobile ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunitoSans(
                            fontSize: subtitleFontSize,
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.35,
                          ),
                        ),
                      ),
                      SizedBox(height: isMobile ? 12 : 20),

                      // Badges
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildSlideBadge(slide['badge1']),
                          _buildSlideBadge(slide['badge2']),
                          _buildSlideBadge(slide['badge3']),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // CTA
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: WebDesignTokens.primaryDark,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                        ),
                        onPressed: () {
                          context.go(slide['route']);
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              slide['cta'],
                              style: GoogleFonts.rubik(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: WebDesignTokens.primaryDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded,
                                size: 16, color: WebDesignTokens.primaryDark),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Indicator Dots
            Positioned(
              bottom: 20,
              right: 28,
              child: Row(
                children: List.generate(
                  _heroSlides.length,
                  (dotIndex) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(left: 6),
                    width: _currentPage == dotIndex ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == dotIndex
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlideBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.nunitoSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFlashDealMiniCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WebDesignTokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WebDesignTokens.border),
        boxShadow: WebDesignTokens.cardRest,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt_rounded,
                      color: WebDesignTokens.dealAmber, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    'FLASH SALE',
                    style: GoogleFonts.rubik(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: WebDesignTokens.dealAmber,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: WebDesignTokens.dealAmber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _formatDuration(_flashRemaining),
                  style: GoogleFonts.rubik(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: WebDesignTokens.dealAmber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'San Carlos Fresh Pick Deals',
            style: GoogleFonts.rubik(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: WebDesignTokens.dark,
            ),
          ),
          Text(
            'Up to 35% off on morning harvests of tomatoes, eggplants & native greens.',
            style: GoogleFonts.nunitoSans(
              fontSize: 12,
              color: WebDesignTokens.slate500,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => context.go(AppRoutes.flashSale),
            child: Row(
              children: [
                Text(
                  'Explore Flash Deals',
                  style: GoogleFonts.rubik(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: WebDesignTokens.dealAmber,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: WebDesignTokens.dealAmber),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmerSpotlightMiniCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WebDesignTokens.primaryLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: WebDesignTokens.primary.withValues(alpha: 0.3),
        ),
        boxShadow: WebDesignTokens.cardRest,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: WebDesignTokens.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.agriculture_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'GROWER SPOTLIGHT',
                  style: GoogleFonts.rubik(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: WebDesignTokens.primaryDark,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded,
                        size: 12, color: WebDesignTokens.trustBlue),
                    const SizedBox(width: 3),
                    Text(
                      'Verified',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: WebDesignTokens.trustBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _featuredFarmer?['farm_name'] ??
                _featuredFarmer?['shop_name'] ??
                'San Carlos Organic Growers',
            style: GoogleFonts.rubik(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: WebDesignTokens.dark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${_featuredFarmer?['location'] ?? _featuredFarmer?['farm_address'] ?? 'Brgy. Roxas, San Carlos City'} • ⭐ ${_featuredFarmer?['average_rating']?.toString() ?? _featuredFarmer?['rating']?.toString() ?? '4.9'} Rating',
            style: GoogleFonts.nunitoSans(
              fontSize: 12,
              color: WebDesignTokens.slate600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              final fid = _featuredFarmer?['farmer_id'] ?? _featuredFarmer?['id'];
              if (fid != null && fid.toString().isNotEmpty) {
                context.go('${AppRoutes.farmerProfileBase}/$fid');
              } else {
                context.go(AppRoutes.localShops);
              }
            },
            child: Row(
              children: [
                Text(
                  'Visit Farm Storefront',
                  style: GoogleFonts.rubik(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: WebDesignTokens.primaryDark,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: WebDesignTokens.primaryDark),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
