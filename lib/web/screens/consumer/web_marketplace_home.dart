import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../widgets/animated_components.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../widgets/web_consumer_nav_bar.dart';

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
  bool _hoveringDeliveryBadge = false;

  late Future<List<Map<String, dynamic>>> _categoriesFuture;
  late Future<List<Map<String, dynamic>>> _productsFuture;
  late Future<List<Map<String, dynamic>>> _farmersFuture;
  late Future<List<ForumPostItem>> _communityPostsFuture;

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

    _categoriesFuture = SupabaseDatabase.getCategories();
    _productsFuture = SupabaseDatabase.getProducts(
      limit: 4,
      onlyFeatured: true,
    );
    _farmersFuture = SupabaseDatabase.getFarmerSpotlight(limit: 3);
    _communityPostsFuture = SupabaseDataService().getForumPosts();
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
    return WebConsumerNavBar(
      currentIndex: widget.currentIndex,
      onNavigate: widget.onNavigate,
      onCartTap: () => context.go(AppRoutes.cart),
    );
  }

  void _openFarmerProfile(String? farmerId) {
    if (farmerId == null || farmerId.isEmpty) return;
    context.go(AppRoutes.farmerProfile(farmerId));
  }

  ProductItem _productFromMap(Map<String, dynamic> raw) {
    final farmer = raw['farmer'] as Map<String, dynamic>?;
    return ProductItem(
      productId: raw['product_id']?.toString(),
      farmerId:
          raw['farmer_id']?.toString() ?? farmer?['farmer_id']?.toString(),
      farmerName: farmer?['user']?['name']?.toString(),
      farmerAvatarUrl: farmer?['user']?['avatar_url']?.toString(),
      name: raw['name']?.toString() ?? 'Product',
      farm: farmer?['farm_name']?.toString() ?? 'Farm',
      price: 'P${raw['price']?.toString() ?? '0'}',
      unit: raw['unit_name']?.toString() ?? 'unit',
      imageUrl: raw['image_url']?.toString() ?? '',
      categoryName: raw['category_name']?.toString(),
      rating: raw['average_rating']?.toString(),
      reviews: raw['review_count']?.toString(),
      description: raw['description']?.toString(),
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
                  painter: AuroraGlowPainter(
                    animationValue: _waveController.value,
                  ),
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
                    color: Colors.white.withValues(alpha: 0.15),
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
                    color: AgriColors.emerald400.withValues(alpha: 0.15),
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
                    color: AgriColors.teal400.withValues(alpha: 0.15),
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
                    color: AgriColors.gold400.withValues(alpha: 0.12),
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
                    color: Colors.white.withValues(alpha: 0.1),
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
                    color: Colors.white.withValues(alpha: 0.05),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AgriColors.gold400.withValues(alpha: 0.2),
                              AgriColors.emerald400.withValues(alpha: 0.2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: AgriColors.gold300.withValues(alpha: 0.3),
                          ),
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
                                    color: AgriColors.gold400.withValues(
                                      alpha: 0.4,
                                    ),
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
                            color: Colors.white.withValues(alpha: 0.8),
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
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(left: 14),
                              child: Icon(
                                Icons.search,
                                color: _muted,
                                size: 20,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: _dark,
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      'Search for fresh vegetables, fruits...',
                                  hintStyle: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: _muted,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 9,
                                    ),
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
                                  _primary.withValues(alpha: 0.15),
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
                                      colors: [
                                        _heroMint,
                                        const Color(0xFFD1FAE5),
                                      ],
                                    ),
                                  ),
                                ),
                                AnimatedBuilder(
                                  animation: _waveController,
                                  builder: (context, _) => CustomPaint(
                                    painter: AuroraGlowPainter(
                                      animationValue: _waveController.value,
                                    ),
                                  ),
                                ),
                                CustomPaint(
                                  painter: HexPatternPainter(
                                    opacity: 0.04,
                                    color: _primary,
                                  ),
                                ),
                                AnimatedBuilder(
                                  animation: _waveController,
                                  builder: (context, _) => CustomPaint(
                                    painter: BlobPainter(
                                      animationValue: _waveController.value,
                                      color: _primary.withValues(alpha: 0.15),
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
                                      color: const Color(
                                        0xFF34D399,
                                      ).withValues(alpha: 0.15),
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
                                      color: _primary.withValues(alpha: 0.1),
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
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
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
                                    placeholder: (ctx, url) =>
                                        const SizedBox.shrink(),
                                    errorWidget: (ctx, url, err) =>
                                        const SizedBox.shrink(),
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
                                        _primary.withValues(alpha: 0.4),
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
                              final offsetY = Tween<double>(begin: 0, end: -6)
                                  .evaluate(
                                    CurvedAnimation(
                                      parent: _floatingCtrl,
                                      curve: Curves.easeInOut,
                                    ),
                                  );
                              return Transform.translate(
                                offset: Offset(0, offsetY),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  onEnter: (_) => setState(
                                    () => _hoveringDeliveryBadge = true,
                                  ),
                                  onExit: (_) => setState(
                                    () => _hoveringDeliveryBadge = false,
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _white,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: _hoveringDeliveryBadge
                                                ? 0.12
                                                : 0.08,
                                          ),
                                          blurRadius: _hoveringDeliveryBadge
                                              ? 20
                                              : 12,
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
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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
                                                fontSize: 11,
                                                color: _muted,
                                              ),
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
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _categoriesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: _primary),
                );
              }
              final cats = snapshot.data ?? [];
              if (cats.isEmpty) {
                return Text(
                  'No categories found',
                  style: GoogleFonts.inter(color: _muted),
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(cats.length.clamp(0, 5), (i) {
                  final cat = cats[i];
                  final isHovered = _hoveredCategories.contains(i);
                  // Map name to icon - simplified mapping
                  IconData icon = Icons.eco_rounded;
                  if (cat['name'].toString().toLowerCase().contains('fruit')) {
                    icon = Icons.apple_rounded;
                  }
                  if (cat['name'].toString().toLowerCase().contains('grain')) {
                    icon = Icons.grain_rounded;
                  }
                  if (cat['name'].toString().toLowerCase().contains('dairy')) {
                    icon = Icons.water_drop_rounded;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) => setState(() => _hoveredCategories.add(i)),
                      onExit: (_) =>
                          setState(() => _hoveredCategories.remove(i)),
                      child: GestureDetector(
                        onTap: () => widget.onNavigate(1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 160,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 24,
                          ),
                          decoration: BoxDecoration(
                            color: isHovered ? _surface : _white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isHovered
                                  ? _primary.withValues(alpha: 0.2)
                                  : _border,
                            ),
                            boxShadow: isHovered
                                ? [
                                    BoxShadow(
                                      color: _primary.withValues(alpha: 0.1),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
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
                                child: Icon(icon, color: _primary, size: 24),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                cat['name'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _dark,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                cat['description'] ?? 'Fresh & Organic',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: _muted,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // FEATURED PRODUCTS
  // ─────────────────────────────────────────────
  Widget _buildFeaturedProducts() {
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
                      const Icon(
                        Icons.arrow_forward,
                        size: 14,
                        color: _primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _productsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: _primary),
                );
              }
              final products = snapshot.data ?? [];
              if (products.isEmpty) {
                return Text(
                  'No products available',
                  style: GoogleFonts.inter(color: _muted),
                );
              }
              return Center(
                child: Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: List.generate(products.length.clamp(0, 4), (i) {
                    final p = products[i];
                    final isHovered = _hoveredProducts.contains(i);
                    final farmName = (p['farmer'] != null)
                        ? p['farmer']['farm_name']
                        : 'AgriDirect Farm';

                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) => setState(() => _hoveredProducts.add(i)),
                      onExit: (_) => setState(() => _hoveredProducts.remove(i)),
                      child: GestureDetector(
                        onTap: () => context.push(
                          AppRoutes.productDetails,
                          extra: _productFromMap(p),
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 280,
                          transform: Matrix4.translationValues(
                            0,
                            isHovered ? -4 : 0,
                            0,
                          ),
                          decoration: BoxDecoration(
                            color: _white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isHovered ? 0.08 : 0.04,
                                ),
                                blurRadius: isHovered ? 16 : 6,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(16),
                                    ),
                                    child: CachedNetworkImage(
                                      imageUrl:
                                          p['image_url'] ??
                                          'https://images.unsplash.com/photo-1592924357228-91a4daadce55?w=300&q=80',
                                      height: 180,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      placeholder: (ctx, url) => Container(
                                        height: 180,
                                        color: _surface,
                                      ),
                                      errorWidget: (ctx, url, err) => Container(
                                        height: 180,
                                        color: _surface,
                                        child: const Icon(
                                          Icons.image_outlined,
                                          color: _muted,
                                          size: 36,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _primary,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.2,
                                            ),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        '₱${p['price']?.toString() ?? '0'}',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if ((p['stock_quantity'] ?? 0) < 5)
                                    Positioned(
                                      top: 12,
                                      left: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(
                                            alpha: 0.9,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          'Low Stock',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p['category_name']
                                              ?.toString()
                                              .toUpperCase() ??
                                          'PRODUCE',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: _primary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      p['name'] as String,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: _dark,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.store_rounded,
                                          size: 14,
                                          color: _muted,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => _openFarmerProfile(
                                              p['farmer_id']?.toString() ??
                                                  p['farmer']?['farmer_id']
                                                      ?.toString(),
                                            ),
                                            child: Text(
                                              farmName,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: _muted,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.star_rounded,
                                              size: 16,
                                              color: Colors.orange,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              p['average_rating']?.toString() ??
                                                  '5.0',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: _dark,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          'Per ${p['unit_name'] ?? 'unit'}',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: _muted,
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
                      ),
                    );
                  }),
                ),
              );
            },
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
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _farmersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: _primary),
                );
              }
              final farmers = snapshot.data ?? [];
              if (farmers.isEmpty) return const SizedBox.shrink();

              final farmer = farmers[0];
              final farmerId = farmer['farmer_id']?.toString();
              final farmerName = (farmer['user'] != null)
                  ? farmer['user']['name']
                  : 'Local Farmer';
              final farmName = farmer['farm_name'] ?? 'AgriDirect Farm';
              final specialty = farmer['specialty'] ?? 'Organic Vegetables';

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left: Orange warm card
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
                        Center(
                          child: Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: CachedNetworkImage(
                                imageUrl:
                                    (farmer['user'] != null &&
                                        farmer['user']['avatar_url'] != null)
                                    ? farmer['user']['avatar_url']
                                    : '',
                                fit: BoxFit.cover,
                                placeholder: (ctx, url) =>
                                    _buildSpotlightAvatarFallback(farmerName),
                                errorWidget: (ctx, url, err) =>
                                    _buildSpotlightAvatarFallback(farmerName),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified_rounded,
                              size: 17,
                              color: Colors.white,
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
                          'Meet $farmerName',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: _dark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'The face behind $farmName. Specializing in $specialty, $farmerName is dedicated to providing the community with the freshest produce.',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: _muted,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => _openFarmerProfile(farmerId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _dark,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text('Visit $farmName'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // TESTIMONIALS
  // ─────────────────────────────────────────────
  Widget _buildTestimonials() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 64),
      color: _bg,
      child: FutureBuilder<List<ForumPostItem>>(
        future: _communityPostsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _primary),
            );
          }

          final posts = (snapshot.data ?? []).take(3).toList();
          if (posts.isEmpty) {
            return const SizedBox.shrink();
          }

          return Column(
            children: [
              Text(
                'Latest From the Community',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Real updates from growers and buyers across AgriDirect.',
                style: GoogleFonts.inter(fontSize: 14, color: _muted),
              ),
              const SizedBox(height: 36),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(posts.length, (i) {
                  final post = posts[i];
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: i == 0 ? 0 : 10,
                        right: i == posts.length - 1 ? 0 : 10,
                      ),
                      child: _buildCommunityPostCard(post),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCommunityPostCard(ForumPostItem post) {
    return Container(
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
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  post.time,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _primary,
                  ),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(
                    Icons.thumb_up_alt_outlined,
                    size: 14,
                    color: _muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post.likes}',
                    style: GoogleFonts.inter(fontSize: 12, color: _muted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            post.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            post.body,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 13, color: _dark, height: 1.7),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _surface,
                child: Text(
                  _initialsFor(post.userName),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _dark,
                      ),
                    ),
                    Text(
                      '${post.comments} comments',
                      style: GoogleFonts.inter(fontSize: 11, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpotlightAvatarFallback(String farmerName) {
    return Container(
      color: Colors.white.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(
        _initialsFor(farmerName),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 42,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  String _initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) return 'AD';
    return parts.map((part) => part[0].toUpperCase()).join();
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
                          child: const Icon(
                            Icons.eco_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AgriDirect',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
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
                        color: _white,
                      ),
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
                        color: _white,
                      ),
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
                        color: _white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Get the latest harvest\nupdates and recipes.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF9CA3AF),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F2937),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: const Color(0xFF374151),
                              ),
                            ),
                            child: TextField(
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: _white,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Email address',
                                hintStyle: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF6B7280),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 9,
                                ),
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
                          child: const Icon(
                            Icons.send_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
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
                  fontSize: 12,
                  color: const Color(0xFF6B7280),
                ),
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
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterBottomLink(String text) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
      ),
    );
  }
}
