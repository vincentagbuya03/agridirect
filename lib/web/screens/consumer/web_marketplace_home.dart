import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/animated_components.dart';

/// Web Marketplace Home — Clean AgriDirect Landing Page
/// Light mint/green design matching reference screenshot
class WebMarketplaceHome extends StatefulWidget {
  final Function(int) onNavigate;
  final int currentIndex;

  const WebMarketplaceHome({
    super.key,
    required this.onNavigate,
    required this.currentIndex,
  });

  @override
  State<WebMarketplaceHome> createState() => _WebMarketplaceHomeState();
}

class _WebMarketplaceHomeState extends State<WebMarketplaceHome>
    with TickerProviderStateMixin {
  // ─── Color Palette ───
  static const Color _primary = Color(0xFF16A34A);
  static const Color _dark = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _surface = Color(0xFFF0FDF4);
  static const Color _white = Colors.white;
  static const Color _bg = Color(0xFFF9FAFB);
  static const Color _heroMint = Color(0xFFF0FDF4);

  late AnimationController _fadeCtrl;
  late AnimationController _floatingCtrl;
  late AnimationController _waveController;
  final Set<int> _hoveredProducts = {};
  final Set<int> _hoveredCategories = {};
  int _hoveredNav = -1;
  bool _hoveringDeliveryBadge = false;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    )..forward();
    _floatingCtrl = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    _waveController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _floatingCtrl.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _white,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildNavBar(),
              _buildHero(),
              _buildCategories(),
              _buildFeaturedProducts(),
              _buildFarmerSpotlight(),
              _buildTestimonials(),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // NAV BAR — Glassmorphism floating card (matches Community Hub)
  // ─────────────────────────────────────────────
  Widget _buildNavBar() {
    final navItems = ['Home', 'Shop', 'Community'];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo with pulsing glow
          Row(
            children: [
              PulsingGlow(
                color: _primary,
                radius: 20,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AgriColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: AnimatedLeafIcon(size: 22, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'AgriDirect',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: 48),
          // Nav items
          ...List.generate(navItems.length, (i) {
            final isActive = i == widget.currentIndex;
            final isHovered = _hoveredNav == i;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _hoveredNav = i),
                onExit: (_) => setState(() => _hoveredNav = -1),
                child: GestureDetector(
                  onTap: () => widget.onNavigate(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isActive
                          ? _primary.withOpacity(0.08)
                          : isHovered
                              ? _border.withOpacity(0.5)
                              : Colors.transparent,
                    ),
                    child: Text(
                      navItems[i],
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        color: isActive ? _primary : isHovered ? _dark : _muted,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          // Circle person icon
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => widget.onNavigate(3),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                  border: Border.all(color: _primary, width: 1.5),
                ),
                child: const Icon(Icons.person_rounded, color: _primary, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HERO — Animated dark emerald background (matches Welcome Screen)
  // ─────────────────────────────────────────────
  Widget _buildHero() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 640),
      child: Stack(
        children: [
          // Background gradient — warm dark hero (same as welcome screen)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AgriColors.warmHeroGradient,
              ),
            ),
          ),

          // Aurora glow — ambient color blobs
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) {
                return CustomPaint(
                  painter: AuroraGlowPainter(animationValue: _waveController.value),
                );
              },
            ),
          ),

          // Hex pattern overlay
          Positioned.fill(
            child: CustomPaint(
              painter: HexPatternPainter(opacity: 0.025, color: Colors.white),
            ),
          ),

          // Ribbon curves
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) {
                return CustomPaint(
                  painter: RibbonPainter(
                    animationValue: _waveController.value,
                    color: Colors.white.withOpacity(0.04),
                    strokeWidth: 1.0,
                  ),
                );
              },
            ),
          ),

          // Animated blob — emerald top right
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) {
                return CustomPaint(
                  painter: BlobPainter(
                    animationValue: _waveController.value,
                    color: AgriColors.emerald400.withOpacity(0.08),
                    center: const Offset(0.8, 0.3),
                    radius: 280,
                  ),
                );
              },
            ),
          ),

          // Animated blob — teal bottom left
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) {
                return CustomPaint(
                  painter: BlobPainter(
                    animationValue: 1 - _waveController.value,
                    color: AgriColors.teal400.withOpacity(0.06),
                    center: const Offset(0.2, 0.7),
                    radius: 220,
                  ),
                );
              },
            ),
          ),

          // Animated blob — gold accent top far right
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) {
                return CustomPaint(
                  painter: BlobPainter(
                    animationValue: _waveController.value * 0.7,
                    color: AgriColors.gold400.withOpacity(0.03),
                    center: const Offset(0.9, 0.15),
                    radius: 120,
                  ),
                );
              },
            ),
          ),

          // Floating particles — mixed green + gold
          const Positioned.fill(
            child: FloatingParticles(
              count: 35,
              maxSize: 3.5,
              color: Color(0xFF34D399),
              height: 640,
            ),
          ),
          const Positioned.fill(
            child: FloatingParticles(
              count: 6,
              maxSize: 2,
              color: Color(0xFFFBBF24),
              height: 640,
            ),
          ),

          // Animated waves at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 120,
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) {
                return CustomPaint(
                  painter: WavePainter(
                    animationValue: _waveController.value,
                    color: Colors.white.withOpacity(0.06),
                    amplitude: 25,
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 80,
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) {
                return CustomPaint(
                  painter: WavePainter(
                    animationValue: 1 - _waveController.value,
                    color: Colors.white.withOpacity(0.04),
                    amplitude: 15,
                  ),
                );
              },
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 60),
            child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left content
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge — gold accent (matches welcome screen)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AgriColors.gold400.withOpacity(0.15),
                        AgriColors.emerald400.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AgriColors.gold300.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: AgriColors.goldGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AgriColors.gold400.withOpacity(0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'FARM-TO-TABLE MARKETPLACE',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AgriColors.gold200,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Headline
                Text(
                  'Fresh From\nFarmers',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.05,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  'To Your Table',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    color: AgriColors.emerald300,
                    height: 1.1,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: 420,
                  child: Text(
                    'Experience the true taste of nature with direct-from-farm produce delivered to your doorstep within 24 hours.',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.6),
                      height: 1.7,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // Search bar
                Container(
                  width: 440,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 14),
                        child: Icon(Icons.search, color: _muted, size: 20),
                      ),
                      Expanded(
                        child: TextField(
                          style: GoogleFonts.inter(fontSize: 14, color: _dark),
                          decoration: InputDecoration(
                            hintText: 'Search for fresh vegetables, fruits...',
                            hintStyle: GoogleFonts.inter(fontSize: 13, color: _muted),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(5),
                        child: GestureDetector(
                          onTap: () => widget.onNavigate(1),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                              decoration: BoxDecoration(
                                color: _primary,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                'Search',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _white,
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
          const SizedBox(width: 48),
          // Right: Image card with floating badge & overlay
          Expanded(
            flex: 4,
            child: SizedBox(
              height: 360,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Gradient overlay for enhanced background effect
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [
                            _primary.withOpacity(0.06),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Main image card with animated background
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: SizedBox(
                      height: 360,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // ── Animated background (from welcome screen) ──
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [_heroMint, const Color(0xFFD1FAE5)],
                              ),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _waveController,
                            builder: (context, _) => CustomPaint(
                              painter: AuroraGlowPainter(animationValue: _waveController.value),
                            ),
                          ),
                          CustomPaint(
                            painter: HexPatternPainter(opacity: 0.04, color: _primary),
                          ),
                          AnimatedBuilder(
                            animation: _waveController,
                            builder: (context, _) => CustomPaint(
                              painter: BlobPainter(
                                animationValue: _waveController.value,
                                color: _primary.withOpacity(0.10),
                                center: const Offset(0.8, 0.2),
                                radius: 180,
                              ),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _waveController,
                            builder: (context, _) => CustomPaint(
                              painter: BlobPainter(
                                animationValue: 1 - _waveController.value,
                                color: const Color(0xFF34D399).withOpacity(0.08),
                                center: const Offset(0.2, 0.8),
                                radius: 140,
                              ),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _waveController,
                            builder: (context, _) => CustomPaint(
                              painter: RibbonPainter(
                                animationValue: _waveController.value,
                                color: _primary.withOpacity(0.05),
                                strokeWidth: 1.0,
                              ),
                            ),
                          ),
                          const FloatingParticles(
                            count: 22,
                            maxSize: 2.8,
                            color: Color(0xFF16A34A),
                            height: 360,
                          ),
                          // Wave at bottom of card
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 80,
                            child: AnimatedBuilder(
                              animation: _waveController,
                              builder: (context, _) => CustomPaint(
                                painter: WavePainter(
                                  animationValue: _waveController.value,
                                  color: Colors.white.withOpacity(0.10),
                                  amplitude: 16,
                                ),
                              ),
                            ),
                          ),
                          // ── Photo overlay (semi-transparent so animation shows) ──
                          Opacity(
                            opacity: 0.45,
                            child: CachedNetworkImage(
                              imageUrl:
                                  'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&q=80',
                              height: 360,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (ctx, url) => const SizedBox.shrink(),
                              errorWidget: (ctx, url, err) => const SizedBox.shrink(),
                            ),
                          ),
                          // Gradient scrim so text/badge reads cleanly
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  _primary.withOpacity(0.15),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Floating delivery badge
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: AnimatedBuilder(
                      animation: _floatingCtrl,
                      builder: (context, child) {
                        final offsetY = Tween<double>(begin: 0, end: -6).evaluate(
                          CurvedAnimation(
                            parent: _floatingCtrl,
                            curve: Curves.easeInOut,
                          ),
                        );
                        return Transform.translate(
                          offset: Offset(0, offsetY),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            onEnter: (_) =>
                                setState(() => _hoveringDeliveryBadge = true),
                            onExit: (_) =>
                                setState(() => _hoveringDeliveryBadge = false),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: _white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                        alpha: _hoveringDeliveryBadge
                                            ? 0.12
                                            : 0.08),
                                    blurRadius:
                                        _hoveringDeliveryBadge ? 20 : 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: _surface,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.local_shipping_rounded,
                                      size: 17,
                                      color: _primary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Fast Delivery',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: _dark,
                                        ),
                                      ),
                                      Text(
                                        'Under 24 hours',
                                        style: GoogleFonts.inter(
                                            fontSize: 11, color: _muted),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
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

  // ─────────────────────────────────────────────
  // CATEGORIES — Clean card grid
  // ─────────────────────────────────────────────
  Widget _buildCategories() {
    final cats = [
      {'icon': Icons.eco_rounded, 'name': 'Vegetables', 'sub': 'Organic & Fresh'},
      {'icon': Icons.apple_rounded, 'name': 'Fruits', 'sub': 'Seasonal Picks'},
      {'icon': Icons.grain_rounded, 'name': 'Grains', 'sub': 'Whole Grains'},
      {'icon': Icons.water_drop_rounded, 'name': 'Dairy', 'sub': 'Farm Milk & Eggs'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 56),
      color: _white,
      child: Column(
        children: [
          Text(
            'Shop by Category',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Everything you need for a healthy lifestyle',
            style: GoogleFonts.inter(fontSize: 14, color: _muted),
          ),
          const SizedBox(height: 36),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(cats.length, (i) {
              final cat = cats[i];
              final isHovered = _hoveredCategories.contains(i);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _hoveredCategories.add(i)),
                  onExit: (_) => setState(() => _hoveredCategories.remove(i)),
                  child: GestureDetector(
                    onTap: () => widget.onNavigate(1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 160,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 24),
                      decoration: BoxDecoration(
                        color: isHovered ? _surface : _white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isHovered
                              ? _primary.withOpacity(0.25)
                              : _border,
                        ),
                        boxShadow: isHovered
                            ? [
                                BoxShadow(
                                  color: _primary.withOpacity(0.07),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : [],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(cat['icon'] as IconData,
                                color: _primary, size: 24),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            cat['name'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _dark,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            cat['sub'] as String,
                            style:
                                GoogleFonts.inter(fontSize: 12, color: _muted),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // FEATURED PRODUCTS
  // ─────────────────────────────────────────────
  Widget _buildFeaturedProducts() {
    final products = [
      {
        'name': 'Organic Cherry\nTomatoes',
        'farm': 'Green Valley Farm',
        'price': '\$4.99/lb',
        'img':
            'https://images.unsplash.com/photo-1592924357228-91a4daadce55?w=300&q=80',
      },
      {
        'name': 'Fresh Kale\nLeaves',
        'farm': 'Sunny Ridge Fields',
        'price': '\$3.50/ea',
        'img':
            'https://images.unsplash.com/photo-1524179091875-bf99a9a6af57?w=300&q=80',
      },
      {
        'name': 'Crispy Farm\nCarrots',
        'farm': 'Root Harvest Organics',
        'price': '\$2.99/lb',
        'img':
            'https://images.unsplash.com/photo-1598170845058-32b9d6a5da37?w=300&q=80',
      },
      {
        'name': 'Pure Grass-Fed\nMilk',
        'farm': 'Meadow Brook Dairy',
        'price': '\$5.25/qt',
        'img':
            'https://images.unsplash.com/photo-1563636619-e9143da7973b?w=300&q=80',
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 56),
      color: _bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Featured Products',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fresh items picked this morning',
                    style: GoogleFonts.inter(fontSize: 13, color: _muted),
                  ),
                ],
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => widget.onNavigate(1),
                  child: Row(
                    children: [
                      Text(
                        'View All',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward,
                          size: 14, color: _primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: List.generate(products.length, (i) {
              final p = products[i];
              final isHovered = _hoveredProducts.contains(i);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: i == 0 ? 0 : 10,
                    right: i == products.length - 1 ? 0 : 10,
                  ),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => _hoveredProducts.add(i)),
                    onExit: (_) => setState(() => _hoveredProducts.remove(i)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      transform:
                          Matrix4.translationValues(0, isHovered ? -4 : 0, 0),
                      decoration: BoxDecoration(
                        color: _white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                                alpha: isHovered ? 0.08 : 0.04),
                            blurRadius: isHovered ? 16 : 6,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(14)),
                                child: CachedNetworkImage(
                                  imageUrl: p['img']!,
                                  height: 170,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (ctx, url) =>
                                      Container(height: 170, color: _surface),
                                  errorWidget: (ctx, url, err) => Container(
                                    height: 170,
                                    color: _surface,
                                    child: const Icon(Icons.image_outlined,
                                        color: _muted, size: 36),
                                  ),
                                ),
                              ),
                              // Heart
                              Positioned(
                                top: 10,
                                right: 10,
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: _white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                            alpha: 0.08),
                                        blurRadius: 6,
                                      )
                                    ],
                                  ),
                                  child: const Icon(Icons.favorite_border,
                                      size: 15, color: _dark),
                                ),
                              ),
                            ],
                          ),
                          // Content
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['name']!,
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _dark),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  p['farm']!,
                                  style: GoogleFonts.inter(
                                      fontSize: 12, color: _muted),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      p['price']!,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: _dark,
                                      ),
                                    ),
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: _surface,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: _primary.withValues(
                                                alpha: 0.2)),
                                      ),
                                      child: const Icon(
                                          Icons.add_shopping_cart,
                                          size: 15,
                                          color: _primary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // FARMER SPOTLIGHT — Orange card left, content right
  // ─────────────────────────────────────────────
  Widget _buildFarmerSpotlight() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 64),
      color: _white,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Orange warm card with farmer illustration
              Container(
                width: 260,
                height: 280,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                  ),
                ),
                child: Stack(
                  children: [
                    // Farmer photo in circle
                    Center(
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl:
                                'https://images.unsplash.com/photo-1605000797499-95a51c5269ae?w=200&q=80',
                            fit: BoxFit.cover,
                            placeholder: (ctx, url) => const Icon(Icons.person,
                                size: 60, color: Colors.white),
                            errorWidget: (ctx, url, err) => const Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    // Verified badge top right
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _primary.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: const Icon(Icons.verified_rounded,
                            size: 17, color: Colors.white),
                      ),
                    ),
                    // Bottom label
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            "FARMER'S SPOTLIGHT",
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: _primary,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 52),
              // Right: Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FARMER SPOTLIGHT',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Meet Farmer John',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '"I believe that everyone deserves access to food grown with love and respect for the earth. At Sunny Ridge, we use zero pesticides and traditional farming methods passed down through four generations."',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: _muted,
                        height: 1.75,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Sunny Ridge Fields',
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _dark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Specializing in organic leafy greens and heritage tomatoes.',
                      style: GoogleFonts.inter(fontSize: 13, color: _muted),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _primary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 11),
                      ),
                      child: Text(
                        "View Farmer's Profile",
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // TESTIMONIALS
  // ─────────────────────────────────────────────
  Widget _buildTestimonials() {
    final testimonials = [
      {
        'text':
            '"The quality of the vegetables is incomparable to anything I find in the supermarkets. You can really taste the freshness!"',
        'name': 'Sarah Jenkins',
        'role': 'Home Chef',
        'img':
            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=80&q=80',
      },
      {
        'text':
            '"AgriDirect has made it so easy for my family to eat healthy while supporting local farmers. The delivery is always on time."',
        'name': 'Mark Thompson',
        'role': 'Health Enthusiast',
        'img':
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=80&q=80',
      },
      {
        'text':
            '"I love knowing exactly where my food comes from. Reading about the farmers makes every meal feel special."',
        'name': 'Elena Rodriguez',
        'role': 'Nutritionist',
        'img':
            'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=80&q=80',
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 64),
      color: _bg,
      child: Column(
        children: [
          Text(
            'What Our Community Says',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (_) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Icon(Icons.star_rounded,
                    color: Color(0xFFFBBF24), size: 20),
              ),
            ),
          ),
          const SizedBox(height: 36),
          Row(
            children: List.generate(testimonials.length, (i) {
              final t = testimonials[i];
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: i == 0 ? 0 : 10,
                    right: i == testimonials.length - 1 ? 0 : 10,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: List.generate(
                            5,
                            (_) => const Padding(
                              padding: EdgeInsets.only(right: 2),
                              child: Icon(Icons.star_rounded,
                                  size: 13, color: Color(0xFFFBBF24)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          t['text']!,
                          style: GoogleFonts.inter(
                              fontSize: 13, color: _dark, height: 1.7),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundImage: NetworkImage(t['img']!),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t['name']!,
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _dark),
                                ),
                                Text(
                                  t['role']!,
                                  style: GoogleFonts.inter(
                                      fontSize: 11, color: _muted),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // FOOTER — Dark with columns
  // ─────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 48),
      color: _dark,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Brand
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _primary,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(Icons.eco_rounded,
                              color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AgriDirect',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Connecting local farmers\ndirectly to your kitchen for a\nhealthier, more sustainable\nworld.',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF9CA3AF),
                          height: 1.7),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildSocialIcon(Icons.language),
                        const SizedBox(width: 8),
                        _buildSocialIcon(Icons.facebook_rounded),
                      ],
                    ),
                  ],
                ),
              ),
              // Quick Links
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Links',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _white),
                    ),
                    const SizedBox(height: 14),
                    _buildFooterLink('Find a Farmer'),
                    _buildFooterLink('Seasonal Calendar'),
                    _buildFooterLink('Pricing Plans'),
                    _buildFooterLink('Help Center'),
                  ],
                ),
              ),
              // Categories
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Categories',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _white),
                    ),
                    const SizedBox(height: 14),
                    _buildFooterLink('Vegetables'),
                    _buildFooterLink('Fruits & Berries'),
                    _buildFooterLink('Dairy & Eggs'),
                    _buildFooterLink('Organic Grains'),
                  ],
                ),
              ),
              // Newsletter
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Newsletter',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Get the latest harvest\nupdates and recipes.',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF9CA3AF),
                          height: 1.6),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 38,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F2937),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                  color: const Color(0xFF374151)),
                            ),
                            child: TextField(
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: _white),
                              decoration: InputDecoration(
                                hintText: 'Email address',
                                hintStyle: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: const Color(0xFF6B7280)),
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 9),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _primary,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(Icons.send_rounded,
                              size: 16, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),
          Container(height: 1, color: const Color(0xFF1F2937)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '© 2024 AgriDirect. All rights reserved.',
                style: GoogleFonts.inter(
                    fontSize: 12, color: const Color(0xFF6B7280)),
              ),
              Row(
                children: [
                  _buildFooterBottomLink('Privacy Policy'),
                  const SizedBox(width: 20),
                  _buildFooterBottomLink('Terms of Service'),
                  const SizedBox(width: 20),
                  _buildFooterBottomLink('Cookie Policy'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: Icon(icon, size: 15, color: const Color(0xFF9CA3AF)),
    );
  }

  Widget _buildFooterLink(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Text(text,
            style: GoogleFonts.inter(
                fontSize: 13, color: const Color(0xFF9CA3AF))),
      ),
    );
  }

  Widget _buildFooterBottomLink(String text) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Text(
        text,
        style:
            GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
      ),
    );
  }
}
