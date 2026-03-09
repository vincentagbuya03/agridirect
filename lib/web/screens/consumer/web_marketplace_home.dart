import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/animated_components.dart';

/// Web Marketplace Home — Modern AgriDirect Landing Page
/// Clean white/green design with hero, categories, products, farmer spotlight, testimonials
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
  static const Color _bg = Color(0xFFFAFAFA);

  late AnimationController _fadeCtrl;
  late AnimationController _waveCtrl;
  final Set<int> _hoveredProducts = {};
  final Set<int> _hoveredCategories = {};
  int _hoveredNav = -1;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    )..forward();
    _waveCtrl = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _waveCtrl.dispose();
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
  // NAV BAR
  // ─────────────────────────────────────────────
  Widget _buildNavBar() {
    final navItems = ['Home', 'Shop', 'Community'];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
          // Nav items with hover animation
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
                          ? _primary.withValues(alpha: 0.08)
                          : isHovered
                              ? _border.withValues(alpha: 0.5)
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
          // Cart
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFECF4EE),
                shape: BoxShape.circle,
                border: Border.all(color: _border),
              ),
              child: Icon(Icons.shopping_cart_outlined, size: 20, color: _dark),
            ),
          ),
          const SizedBox(width: 10),
          // Person icon button
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
                  border: Border.all(
                    color: _primary,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: _primary,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HERO SECTION — Premium animated hero
  // ─────────────────────────────────────────────
  Widget _buildHero() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 520),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AgriColors.warmHeroGradient,
              ),
            ),
          ),
          // Aurora glow
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _waveCtrl,
              builder: (context, _) => CustomPaint(
                painter: AuroraGlowPainter(animationValue: _waveCtrl.value),
              ),
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
              animation: _waveCtrl,
              builder: (context, _) => CustomPaint(
                painter: RibbonPainter(
                  animationValue: _waveCtrl.value,
                  color: Colors.white.withValues(alpha: 0.035),
                  strokeWidth: 0.8,
                ),
              ),
            ),
          ),
          // Animated blobs
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _waveCtrl,
              builder: (context, _) => CustomPaint(
                painter: BlobPainter(
                  animationValue: _waveCtrl.value,
                  color: AgriColors.emerald400.withValues(alpha: 0.07),
                  center: const Offset(0.8, 0.3),
                  radius: 220,
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: FloatingParticles(count: 30, maxSize: 3, color: Color(0xFF34D399), height: 520),
          ),
          // Gold accent particles
          const Positioned.fill(
            child: FloatingParticles(count: 5, maxSize: 1.8, color: Color(0xFFFBBF24), height: 520),
          ),
          // Animated wave at bottom
          Positioned(
            bottom: 0, left: 0, right: 0, height: 100,
            child: AnimatedBuilder(
              animation: _waveCtrl,
              builder: (context, _) => CustomPaint(
                painter: WavePainter(
                  animationValue: _waveCtrl.value,
                  color: Colors.white.withValues(alpha: 0.05),
                  amplitude: 20,
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 72),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left content
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Badge — gold accent
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AgriColors.gold400.withValues(alpha: 0.15),
                              AgriColors.emerald400.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: AgriColors.gold300.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: AgriColors.emerald400, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text('DIRECT FROM SOURCE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AgriColors.emerald300, letterSpacing: 1.5)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Headline
                      Text.rich(TextSpan(children: [
                        TextSpan(text: 'Fresh From\nFarmers ', style: GoogleFonts.plusJakartaSans(fontSize: 52, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1, letterSpacing: -1)),
                        TextSpan(text: 'To Your Table', style: GoogleFonts.plusJakartaSans(fontSize: 52, fontWeight: FontWeight.w800, color: AgriColors.emerald300, height: 1.1, letterSpacing: -1)),
                      ])),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: 440,
                        child: Text(
                          'Experience the true taste of nature with direct-from-farm produce delivered to your doorstep within 24 hours.',
                          style: GoogleFonts.inter(fontSize: 16, color: Colors.white.withValues(alpha: 0.6), height: 1.7),
                        ),
                      ),
                      const SizedBox(height: 36),
                      // Glassmorphism search bar
                      Container(
                        width: 460,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Padding(padding: const EdgeInsets.only(left: 16), child: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.5), size: 22)),
                            Expanded(
                              child: TextField(
                                style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Search for fresh vegetables, fruits...',
                                  hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.white.withValues(alpha: 0.4)),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.all(5),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () => widget.onNavigate(1),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                                    child: Text('Search', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AgriColors.emerald700)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),
                      // Stats row
                      Row(
                        children: [
                          _buildHeroStat('200+', 'Local Farmers'),
                          Container(width: 1, height: 36, margin: const EdgeInsets.symmetric(horizontal: 24), color: Colors.white.withValues(alpha: 0.15)),
                          _buildHeroStat('5,000+', 'Products'),
                          Container(width: 1, height: 36, margin: const EdgeInsets.symmetric(horizontal: 24), color: Colors.white.withValues(alpha: 0.15)),
                          _buildHeroStat('24hrs', 'Delivery'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 60),
                // Right: Hero visual card
                Expanded(
                  flex: 4,
                  child: SizedBox(
                    height: 400,
                    child: Stack(
                      children: [
                        // Glassmorphism card
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.white.withValues(alpha: 0.12), Colors.white.withValues(alpha: 0.04)],
                              ),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: Stack(
                                children: [
                                  CustomPaint(size: const Size(400, 400), painter: DotPatternPainter(opacity: 0.06, color: AgriColors.emerald300)),
                                  Center(child: AnimatedLeafIcon(size: 120, color: AgriColors.emerald400.withValues(alpha: 0.12))),
                                  // Bottom info glass card
                                  Positioned(
                                    bottom: 20, left: 20, right: 20,
                                    child: GlassCard(
                                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                                      borderColor: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: 16,
                                      padding: const EdgeInsets.all(16),
                                      child: Row(children: [
                                        Container(
                                          width: 44, height: 44,
                                          decoration: BoxDecoration(gradient: AgriColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
                                          child: const Icon(Icons.eco_rounded, color: Colors.white, size: 22),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text('100% Fresh & Organic', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                                          Text('Direct from verified farms', style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.6))),
                                        ])),
                                      ]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Floating delivery badge
                        Positioned(
                          bottom: -5, left: -10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 8))],
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(width: 36, height: 36, decoration: BoxDecoration(color: AgriColors.emerald50, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.local_shipping_rounded, size: 18, color: _primary)),
                              const SizedBox(width: 10),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                Text('Fast Delivery', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _dark)),
                                Text('Under 24 hours', style: GoogleFonts.inter(fontSize: 10, color: _muted)),
                              ]),
                            ]),
                          ),
                        ),
                        // Floating trusted badge
                        Positioned(
                          top: -5, right: -5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: AgriColors.glowGradient,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: AgriColors.emerald400.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4))],
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.verified_rounded, size: 14, color: Colors.white),
                              const SizedBox(width: 6),
                              Text('Trusted', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                            ]),
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

  Widget _buildHeroStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // CATEGORIES
  // ─────────────────────────────────────────────
  Widget _buildCategories() {
    final cats = [
      {'icon': Icons.eco_rounded, 'name': 'Vegetables', 'sub': 'Organic & Fresh', 'count': '150+'},
      {'icon': Icons.apple_rounded, 'name': 'Fruits', 'sub': 'Seasonal Picks', 'count': '120+'},
      {'icon': Icons.grain_rounded, 'name': 'Grains', 'sub': 'Whole Grains', 'count': '80+'},
      {'icon': Icons.water_drop_rounded, 'name': 'Dairy', 'sub': 'Farm Milk & Eggs', 'count': '60+'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 64),
      color: _white,
      child: Column(
        children: [
          Text(
            'Shop by Category',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Everything you need for a healthy lifestyle',
            style: GoogleFonts.inter(fontSize: 14, color: _muted),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(cats.length, (i) {
              final cat = cats[i];
              final isHovered = _hoveredCategories.contains(i);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _hoveredCategories.add(i)),
                  onExit: (_) => setState(() => _hoveredCategories.remove(i)),
                  child: GestureDetector(
                    onTap: () => widget.onNavigate(1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 180,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                      decoration: BoxDecoration(
                        color: isHovered ? _surface : _white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isHovered ? _primary.withValues(alpha: 0.3) : _border,
                        ),
                        boxShadow: isHovered
                            ? [BoxShadow(color: _primary.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))]
                            : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: isHovered ? _primary.withValues(alpha: 0.1) : _surface,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              cat['icon'] as IconData,
                              color: _primary,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            cat['name'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _dark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cat['sub'] as String,
                            style: GoogleFonts.inter(fontSize: 12, color: _muted),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${cat['count']} items',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: _primary,
                                fontWeight: FontWeight.w500,
                              ),
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
  // FEATURED PRODUCTS
  // ─────────────────────────────────────────────
  Widget _buildFeaturedProducts() {
    final products = [
      {'name': 'Organic Cherry\nTomatoes', 'farm': 'Green Valley Farm', 'price': '\$4.99/lb', 'rating': '4.8', 'img': 'https://images.unsplash.com/photo-1592924357228-91a4daadce55?w=300&q=80', 'badge': 'ORGANIC'},
      {'name': 'Fresh Kale\nLeaves', 'farm': 'Sunny Ridge Fields', 'price': '\$3.50/ea', 'rating': '4.6', 'img': 'https://images.unsplash.com/photo-1524179091875-bf99a9a6af57?w=300&q=80', 'badge': 'LOCAL'},
      {'name': 'Crispy Farm\nCarrots', 'farm': 'Root Harvest Organics', 'price': '\$2.99/lb', 'rating': '4.9', 'img': 'https://images.unsplash.com/photo-1598170845058-32b9d6a5da37?w=300&q=80', 'badge': 'FRESH'},
      {'name': 'Pure Grass-Fed\nMilk', 'farm': 'Meadow Brook Dairy', 'price': '\$5.25/qt', 'rating': '4.7', 'img': 'https://images.unsplash.com/photo-1563636619-e9143da7973b?w=300&q=80', 'badge': 'PREMIUM'},
    ];

    final badgeColors = {
      'ORGANIC': const Color(0xFF16A34A),
      'LOCAL': const Color(0xFF2563EB),
      'FRESH': const Color(0xFFF59E0B),
      'PREMIUM': const Color(0xFF9333EA),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 64),
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
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Fresh items picked this morning',
                    style: GoogleFonts.inter(fontSize: 14, color: _muted),
                  ),
                ],
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => widget.onNavigate(1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: _primary),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View All',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward, size: 16, color: _primary),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
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
                      duration: const Duration(milliseconds: 200),
                      transform: Matrix4.translationValues(0, isHovered ? -4 : 0, 0),
                      decoration: BoxDecoration(
                        color: _white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isHovered ? 0.08 : 0.04),
                            blurRadius: isHovered ? 16 : 8,
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
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                child: CachedNetworkImage(
                                  imageUrl: p['img']!,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) => Container(
                                    height: 180,
                                    color: _surface,
                                    child: const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
                                    ),
                                  ),
                                  errorWidget: (_, _, _) => Container(
                                    height: 180,
                                    color: _surface,
                                    child: const Icon(Icons.image_outlined, color: _muted, size: 40),
                                  ),
                                ),
                              ),
                              // Badge
                              Positioned(
                                top: 10,
                                left: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: badgeColors[p['badge']]!,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    p['badge']!,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                              // Favorite
                              Positioned(
                                top: 10,
                                right: 10,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: _white.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.favorite_border, size: 16, color: _dark),
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
                                    color: _dark,
                                  ),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.storefront, size: 12, color: _muted),
                                    const SizedBox(width: 4),
                                    Text(
                                      p['farm']!,
                                      style: GoogleFonts.inter(fontSize: 12, color: _muted),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Rating
                                Row(
                                  children: [
                                    ...List.generate(5, (s) => Icon(
                                      Icons.star_rounded,
                                      size: 14,
                                      color: s < 4 ? const Color(0xFFF59E0B) : _border,
                                    )),
                                    const SizedBox(width: 4),
                                    Text(
                                      p['rating']!,
                                      style: GoogleFonts.inter(fontSize: 11, color: _muted, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      p['price']!,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: _dark,
                                      ),
                                    ),
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: _primary,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.add_shopping_cart, size: 16, color: Colors.white),
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
  // FARMER SPOTLIGHT
  // ─────────────────────────────────────────────
  Widget _buildFarmerSpotlight() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
      color: _white,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 960),
          padding: const EdgeInsets.all(48),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF0FDF4), Color(0xFFFEFCE8)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AgriColors.emerald200.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: AgriColors.emerald500.withValues(alpha: 0.06),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Row(
            children: [
              // Farmer image
              Container(
                width: 220,
                height: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: const Color(0xFFE8D5B7),
                  image: const DecorationImage(
                    image: NetworkImage(
                      'https://images.unsplash.com/photo-1605000797499-95a51c5269ae?w=300&q=80',
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.eco_rounded, size: 14, color: _primary),
                            const SizedBox(width: 6),
                            Text(
                              "FARMER'S SPOTLIGHT",
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: _primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 40),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: AgriColors.goldGradient,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: AgriColors.gold400.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.verified, size: 18, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'FARMER SPOTLIGHT',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _primary,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Meet Farmer John',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '"I believe that everyone deserves access to food grown with love and respect for the earth. At Sunny Ridge, we use zero pesticides and traditional farming methods passed down through four generations."',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: _muted,
                        height: 1.7,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Sunny Ridge Fields',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Specializing in organic leafy greens and heritage tomatoes.',
                      style: GoogleFonts.inter(fontSize: 13, color: _muted),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: Text(
                        "View Farmer's Profile",
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _primary,
                        ),
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
        'text': '"The quality of the vegetables is incomparable to anything I find in the supermarkets. You can really taste the freshness!"',
        'name': 'Sarah Jenkins',
        'role': 'Home Chef',
        'img': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&q=80',
      },
      {
        'text': '"AgriDirect has made it so easy for my family to eat healthy while supporting local farmers. The delivery is always on time."',
        'name': 'Mark Thompson',
        'role': 'Health Enthusiast',
        'img': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&q=80',
      },
      {
        'text': '"I love knowing exactly where my food comes from. Reading about the farmers makes every meal feel special."',
        'name': 'Elena Rodriguez',
        'role': 'Nutritionist',
        'img': 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100&q=80',
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 64),
      color: _bg,
      child: Column(
        children: [
          Text(
            'What Our Community Says',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (_) => const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 22)),
          ),
          const SizedBox(height: 40),
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
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ...List.generate(5, (_) => const Icon(
                              Icons.star_rounded, size: 14, color: Color(0xFFF59E0B),
                            )),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          t['text']!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF1F2937),
                            height: 1.7,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: NetworkImage(t['img']!),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t['name']!,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _dark,
                                  ),
                                ),
                                Text(
                                  t['role']!,
                                  style: GoogleFonts.inter(fontSize: 11, color: _muted),
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
  // FOOTER
  // ─────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
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
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.eco_rounded, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'AgriDirect',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Connecting local farmers\ndirectly to your kitchen for a\nhealthier, more sustainable\nworld.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF9CA3AF),
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildSocialIcon(Icons.language),
                        const SizedBox(width: 8),
                        _buildSocialIcon(Icons.facebook_rounded),
                        const SizedBox(width: 8),
                        _buildSocialIcon(Icons.camera_alt_outlined),
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
                    Text('Quick Links', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _white)),
                    const SizedBox(height: 16),
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
                    Text('Categories', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _white)),
                    const SizedBox(height: 16),
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
                    Text('Newsletter', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _white)),
                    const SizedBox(height: 8),
                    Text(
                      'Get the latest harvest\nupdates and recipes.',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF9CA3AF), height: 1.6),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F2937),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF374151)),
                            ),
                            child: TextField(
                              style: GoogleFonts.inter(fontSize: 13, color: _white),
                              decoration: InputDecoration(
                                hintText: 'Email address',
                                hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7280)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Container(height: 1, color: const Color(0xFF374151)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '© 2026 AgriDirect. All rights reserved.',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
              ),
              Row(
                children: [
                  _buildFooterBottomLink('Privacy Policy'),
                  const SizedBox(width: 24),
                  _buildFooterBottomLink('Terms of Service'),
                  const SizedBox(width: 24),
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
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: const Color(0xFF9CA3AF)),
    );
  }

  Widget _buildFooterLink(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF9CA3AF)),
      ),
    );
  }

  Widget _buildFooterBottomLink(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
    );
  }
}
