import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/services/commerce/cart_service.dart';
import '../../widgets/web_consumer_nav_bar.dart';
import '../../widgets/quick_links/quick_links_dialogs.dart';

/// Web Marketplace Home — Clean AgriDirect Landing Page
/// Light mint/green design matching reference screenshot
class WebMarketplaceHome extends StatefulWidget {
  final Function(int, [String?]) onNavigate;
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

  late AnimationController _fadeCtrl;
  late AnimationController _floatingCtrl;
  late AnimationController _waveController;
  final Set<int> _hoveredCategories = {};

  late PageController _bannerController;
  int _bannerIndex = 0;
  Timer? _bannerTimer;
  Timer? _flashTimer;
  Duration _flashRemaining = const Duration(hours: 3, minutes: 42, seconds: 15);

  final List<Map<String, dynamic>> _promoBanners = [
    {
      'tag': 'SAN CARLOS CITY HARVEST SALE',
      'title': 'FRESH LOCAL HARVEST!',
      'subtitle':
          'Fresh local produce & farm essentials direct from San Carlos City, Pangasinan growers.',
      'badge1': '🎟️ ₱100 OFF VOUCHER',
      'badge2': '⚡ UP TO 50% OFF',
      'badge3': '🚚 LOCAL DELIVERY',
      'bgGradient': [Color(0xFF991B1B), Color(0xFFDC2626), Color(0xFFEA580C)],
      'imageUrl': 'assets/images/banner_3.jpg',
      'route': AppRoutes.flashSale,
      'cta': 'SHOP DEALS NOW >',
    },
    {
      'tag': '100% DIRECT FROM SAN CARLOS GROWERS',
      'title': 'SAN CARLOS FRESH PICKS',
      'subtitle':
          'Fresh vegetables, farm-fresh eggs, and organic harvests picked daily across barangays.',
      'badge1': '⭐ 4.9 RATED FARMS',
      'badge2': '🌿 100% FRESH',
      'badge3': '⏰ SAME-DAY DELIVERY',
      'bgGradient': [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF059669)],
      'imageUrl': 'assets/images/banner2.jpg',
      'route': AppRoutes.freshProduce,
      'cta': 'DISCOVER HARVEST >',
    },
    {
      'tag': 'BULK SACKS & COMMERCIAL PRICING',
      'title': 'GRAIN & RICE WHOLESALE',
      'subtitle':
          'Direct milling from San Carlos City farmer cooperatives. Save on sacks & bulk bundles.',
      'badge1': '📦 SACK WHOLESALE',
      'badge2': '💰 BULK DISCOUNTS',
      'badge3': '🚚 LOCAL FREIGHT',
      'bgGradient': [Color(0xFF78350F), Color(0xFFB45309), Color(0xFFD97706)],
      'imageUrl': 'assets/images/banner_1.jpg',
      'route': AppRoutes.wholesale,
      'cta': 'EXPLORE WHOLESALE >',
    },
    {
      'tag': 'SAN CARLOS CITY LOGISTICS',
      'title': 'FREE LOCAL DELIVERY',
      'subtitle':
          'Fast farm-to-door delivery on orders across San Carlos City, Pangasinan.',
      'badge1': '🚚 ₱0 MIN SPEND',
      'badge2': '⚡ INSTANT CLAIM',
      'badge3': '🌿 DIRECT DISPATCH',
      'bgGradient': [Color(0xFF1E3A8A), Color(0xFF1D4ED8), Color(0xFF0284C7)],
      'imageUrl': 'assets/images/promo_banner_2.jpg',
      'route': AppRoutes.freeShipping,
      'cta': 'CLAIM VOUCHERS >',
    },
  ];

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

    _bannerController = PageController();
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_bannerController.hasClients) {
        final next = (_bannerIndex + 1) % _promoBanners.length;
        _bannerController.animateToPage(
          next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });

    _flashTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _flashRemaining.inSeconds > 0) {
        setState(() {
          _flashRemaining = _flashRemaining - const Duration(seconds: 1);
        });
      }
    });

    _categoriesFuture = SupabaseDatabase.getCategories();
    _productsFuture = SupabaseDatabase.getProducts(
      limit: 8,
      onlyFeatured: true,
    );
    _farmersFuture = SupabaseDatabase.getFarmerSpotlight(limit: 6);
    _communityPostsFuture = SupabaseDataService().getForumPosts();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _flashTimer?.cancel();
    _bannerController.dispose();
    _fadeCtrl.dispose();
    _floatingCtrl.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildNavBar(),
              _buildLazadaMegaBannerSection(),
              _buildLazadaChannelGrid(),
              _buildLazadaFlashSaleSection(),
              _buildCategories(),
              _buildFeaturedProducts(),
              _buildFarmerSpotlight(),
              _buildTrustPillars(),
              _buildTestimonials(),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // NAV BAR â€” Glassmorphism floating card (matches Community Hub)
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
    final farmerObj =
        raw['farmer'] as Map<String, dynamic>? ??
        raw['farmers'] as Map<String, dynamic>?;

    final String extractedFarm = (raw['farm_name'] != null &&
            raw['farm_name'].toString().isNotEmpty)
        ? raw['farm_name'].toString()
        : ((farmerObj?['farm_name'] != null &&
                farmerObj!['farm_name'].toString().isNotEmpty)
            ? farmerObj['farm_name'].toString()
            : ((raw['farmer_name'] != null &&
                    raw['farmer_name'].toString().isNotEmpty)
                ? raw['farmer_name'].toString()
                : ((farmerObj?['users']?['name'] != null &&
                        farmerObj!['users']!['name'].toString().isNotEmpty)
                    ? farmerObj['users']!['name'].toString()
                    : ((farmerObj?['user']?['name'] != null &&
                            farmerObj!['user']!['name'].toString().isNotEmpty)
                        ? farmerObj['user']!['name'].toString()
                        : 'Local Farm'))));

    final String? ratingStr = (raw['average_rating'] != null &&
            raw['average_rating'].toString() != '0' &&
            raw['average_rating'].toString() != '0.0')
        ? raw['average_rating'].toString()
        : ((raw['rating'] != null &&
                raw['rating'].toString() != '0' &&
                raw['rating'].toString() != '0.0')
            ? raw['rating'].toString()
            : null);

    return ProductItem(
      productId: raw['product_id']?.toString(),
      farmerId:
          raw['farmer_id']?.toString() ?? farmerObj?['farmer_id']?.toString(),
      farmerName: raw['farmer_name']?.toString() ??
          farmerObj?['users']?['name']?.toString() ??
          farmerObj?['user']?['name']?.toString() ??
          extractedFarm,
      farmerAvatarUrl: raw['farmer_avatar_url']?.toString() ??
          farmerObj?['users']?['avatar_url']?.toString() ??
          farmerObj?['user']?['avatar_url']?.toString(),
      name: raw['name']?.toString() ?? 'Product',
      farm: extractedFarm,
      price: 'P${raw['price']?.toString() ?? '0'}',
      unit: raw['unit_name']?.toString() ??
          raw['unit_abbr']?.toString() ??
          raw['unit']?.toString() ??
          'kg',
      imageUrl: raw['image_url']?.toString() ?? '',
      categoryName: raw['category_name']?.toString(),
      rating: ratingStr,
      reviews: raw['review_count']?.toString() ?? raw['reviews']?.toString(),
      description: raw['description']?.toString(),
    );
  }

  Widget _buildLazadaMegaBannerSection() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 992;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 32,
        vertical: 16,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: isMobile
              ? Column(
                  children: [
                    _buildMegaBannerCarousel(height: 220),
                    const SizedBox(height: 12),
                    _buildAppPerksCard(isFullWidth: true),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 9,
                      child: _buildMegaBannerCarousel(height: 340),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: _buildAppPerksCard(isFullWidth: false),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildMegaBannerCarousel({required double height}) {
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          PageView.builder(
            controller: _bannerController,
            onPageChanged: (i) => setState(() => _bannerIndex = i),
            itemCount: _promoBanners.length,
            itemBuilder: (context, index) {
              final banner = _promoBanners[index];
              final List<Color> colors = banner['bgGradient'] as List<Color>;

              return GestureDetector(
                onTap: () => context.push(banner['route'] as String),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: colors,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.first.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          // Background Image with overlay
                          Positioned.fill(
                            child: CachedNetworkImage(
                              imageUrl: banner['imageUrl'] as String,
                              fit: BoxFit.cover,
                              placeholder: (ctx, url) =>
                                  Container(color: colors.first),
                              errorWidget: (ctx, url, err) =>
                                  Container(color: colors.first),
                            ),
                          ),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    colors.first.withValues(alpha: 0.95),
                                    colors[1].withValues(alpha: 0.85),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.55, 1.0],
                                ),
                              ),
                            ),
                          ),
                          // Content
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 24,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Text(
                                    banner['tag'] as String,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.amberAccent,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  banner['title'] as String,
                                  style: GoogleFonts.poppins(
                                    fontSize: height < 300 ? 20 : 32,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1.1,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: 420,
                                  child: Text(
                                    banner['subtitle'] as String,
                                    style: GoogleFonts.inter(
                                      fontSize: height < 300 ? 11 : 13,
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      height: 1.4,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                // Badges
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    _buildBannerPill(
                                      banner['badge1'] as String,
                                    ),
                                    _buildBannerPill(
                                      banner['badge2'] as String,
                                    ),
                                    if (height >= 300)
                                      _buildBannerPill(
                                        banner['badge3'] as String,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        banner['cta'] as String,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: colors.first,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 14,
                                        color: colors.first,
                                      ),
                                    ],
                                  ),
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
            },
          ),
          // Carousel Indicator Dots
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_promoBanners.length, (i) {
                final isSelected = _bannerIndex == i;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 7,
                  width: isSelected ? 24 : 7,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white30),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LAZADA-STYLE RIGHT SIDE APP / VOUCHERS PERKS CARD
  // ─────────────────────────────────────────────────────────────
  Widget _buildAppPerksCard({required bool isFullWidth}) {
    return Container(
      height: isFullWidth ? null : 340,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.phone_android_rounded,
                  size: 20,
                  color: Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TRY OUR APP',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 13,
                        color: Color(0xFFF59E0B),
                      ),
                      Text(
                        ' 4.9 Rated • 50k+ Deliveries',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.local_shipping_rounded,
                      size: 16,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'FREE SHIPPING',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Exclusive vouchers for first 3 farm-direct orders',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xFF78350F),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              height: 90,
              width: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl:
                      'https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=https://agridirect.ph',
                  fit: BoxFit.cover,
                  placeholder: (ctx, url) => const Icon(
                    Icons.qr_code_2_rounded,
                    size: 50,
                    color: Color(0xFF059669),
                  ),
                  errorWidget: (ctx, url, err) => const Icon(
                    Icons.qr_code_2_rounded,
                    size: 50,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push(AppRoutes.vouchers),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'CLAIM ₱100 VOUCHER',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LAZADA-STYLE CHANNEL QUICK HUB BAR (UNDER BANNER)
  // ─────────────────────────────────────────────────────────────
  Widget _buildLazadaChannelGrid() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    final channels = [
      {
        'icon': Icons.eco_rounded,
        'title': 'Fresh Produce',
        'subtitle': 'San Carlos City, Pangasinan',
        'color': const Color(0xFF059669),
        'bgColor': const Color(0xFFECFDF5),
        'route': AppRoutes.freshProduce,
      },
      {
        'icon': Icons.flash_on_rounded,
        'title': 'Flash Deals',
        'subtitle': 'Up to 50% Off Today',
        'color': const Color(0xFFDC2626),
        'bgColor': const Color(0xFFFEF2F2),
        'route': AppRoutes.flashSale,
      },
      {
        'icon': Icons.local_shipping_rounded,
        'title': 'Free Shipping',
        'subtitle': 'Across San Carlos City',
        'color': const Color(0xFF0284C7),
        'bgColor': const Color(0xFFF0F9FF),
        'route': AppRoutes.freeShipping,
      },
      {
        'icon': Icons.confirmation_number_rounded,
        'title': 'Voucher Center',
        'subtitle': 'Collect & Save Big',
        'color': const Color(0xFFD97706),
        'bgColor': const Color(0xFFFFFBEB),
        'route': AppRoutes.vouchers,
      },
      {
        'icon': Icons.inventory_2_rounded,
        'title': 'Bulk Wholesale',
        'subtitle': 'Sacks & Commercial',
        'color': const Color(0xFF7C3AED),
        'bgColor': const Color(0xFFF5F3FF),
        'route': AppRoutes.wholesale,
      },
      {
        'icon': Icons.storefront_rounded,
        'title': 'Local Farms',
        'subtitle': 'Accredited Growers',
        'color': const Color(0xFF0D9488),
        'bgColor': const Color(0xFFF0FDFA),
        'route': AppRoutes.localShops,
      },
    ];

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 32,
        vertical: 16,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              int count = width < 600 ? 2 : (width < 900 ? 3 : 6);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: count,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: width < 600 ? 2.6 : 2.4,
                ),
                itemCount: channels.length,
                itemBuilder: (context, i) {
                  final ch = channels[i];
                  return InkWell(
                    onTap: () => context.push(ch['route'] as String),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: (ch['bgColor'] as Color),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (ch['color'] as Color).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (ch['color'] as Color),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              ch['icon'] as IconData,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  ch['title'] as String,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  ch['subtitle'] as String,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LAZADA-STYLE FLASH SALE WITH LIVE COUNTDOWN TIMER
  // ─────────────────────────────────────────────────────────────
  Widget _buildLazadaFlashSaleSection() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    final hours = _flashRemaining.inHours.toString().padLeft(2, '0');
    final minutes = (_flashRemaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_flashRemaining.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 14),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 32,
        vertical: 24,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Flash Sale',
                        style: GoogleFonts.poppins(
                          fontSize: isMobile ? 18 : 22,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Text(
                          'On Sale Now',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (!isMobile) ...[
                        Text(
                          'Ending in',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      _buildTimerBlock(hours),
                      const Text(
                        ' : ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      _buildTimerBlock(minutes),
                      const Text(
                        ' : ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      _buildTimerBlock(seconds),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push(AppRoutes.flashSale),
                    icon: const Icon(Icons.bolt_rounded, size: 14),
                    label: Text(
                      'SHOP ALL PRODUCTS',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Horizontal Flash Sale Product Shelf
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _productsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    );
                  }
                  final products = snapshot.data ?? [];
                  if (products.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return SizedBox(
                    height: 270,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: products.length.clamp(0, 6),
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 14),
                      itemBuilder: (context, i) {
                        final p = products[i];
                        final item = _productFromMap(p);
                        return _buildFlashSaleCard(item);
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerBlock(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        value,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFlashSaleCard(ProductItem product) {
    final rawPrice = product.price.replaceAll(RegExp(r'[^0-9.]'), '');
    final double price = double.tryParse(rawPrice) ?? 0.0;
    final double origPrice = price * 1.35;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (product.productId != null) {
            context.push('/product/${product.productId}');
          }
        },
        child: Container(
          width: 175,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
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
                      top: Radius.circular(11),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrl.isNotEmpty
                          ? product.imageUrl
                          : 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=300&q=80',
                      height: 130,
                      width: 175,
                      fit: BoxFit.cover,
                      placeholder: (ctx, url) =>
                          Container(color: const Color(0xFFF8FAFC)),
                      errorWidget: (ctx, url, err) => Container(
                        color: const Color(0xFFF8FAFC),
                        child: const Icon(
                          Icons.eco_rounded,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '-35%',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          '₱${price.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '₱${origPrice.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: const Color(0xFF94A3B8),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: const LinearProgressIndicator(
                        value: 0.8,
                        minHeight: 5,
                        backgroundColor: Color(0xFFFEE2E2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFDC2626),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '🔥 18 Sold',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFDC2626),
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

  // ─────────────────────────────────────────────────────────────
  // 4 TRUST PILLARS (Direct Farmer Support & 24h Cold Chain)
  // ─────────────────────────────────────────────────────────────
  Widget _buildTrustPillars() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    final pillars = [
      {
        'icon': Icons.agriculture_rounded,
        'title': '100% Direct Farmer Profit',
        'desc':
            'Zero middlemen cuts. Every peso directly empowers accredited Filipino growers.',
      },
      {
        'icon': Icons.electric_bolt_rounded,
        'title': '24-Hour Cold Chain Delivery',
        'desc':
            'Harvested at dawn, chilled, and delivered to your kitchen table fresh by evening.',
      },
      {
        'icon': Icons.verified_rounded,
        'title': 'Certified Authentic Quality',
        'desc':
            'Strict quality screening for pesticide-free and organic produce standards.',
      },
      {
        'icon': Icons.savings_rounded,
        'title': 'Commercial Bulk Savings',
        'desc':
            'Save up to 35% on wholesale sacks for households, restaurants, and caterers.',
      },
    ];

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: 40,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              int crossAxisCount = width < 600 ? 1 : (width < 992 ? 2 : 4);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: width < 600 ? 3.0 : 2.2,
                ),
                itemCount: pillars.length,
                itemBuilder: (context, i) {
                  final p = pillars[i];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            p['icon'] as IconData,
                            size: 20,
                            color: const Color(0xFF059669),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                p['title'] as String,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                p['desc'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: const Color(0xFF64748B),
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // CATEGORIES â€” Clean card grid
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildCategories() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 64,
        vertical: 56,
      ),
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
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Everything you need for a healthy lifestyle',
            style: GoogleFonts.inter(fontSize: 14, color: _muted),
            textAlign: TextAlign.center,
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

              Widget buildCategoryItem(int i, Map<String, dynamic> cat) {
                final isHovered = _hoveredCategories.contains(i);
                final name = cat['name']?.toString() ?? 'Category';
                final desc =
                    cat['description']?.toString() ?? 'Fresh & Organic';

                IconData icon = Icons.eco_rounded;
                Color iconColor = _primary;
                Color cardBg = isHovered ? _surface : _white;
                final nameLower = name.toLowerCase();

                if (nameLower.contains('fruit')) {
                  icon = Icons.apple_rounded;
                  iconColor = const Color(0xFFEA580C);
                } else if (nameLower.contains('veg')) {
                  icon = Icons.agriculture_rounded;
                  iconColor = const Color(0xFF16A34A);
                } else if (nameLower.contains('grain') ||
                    nameLower.contains('rice')) {
                  icon = Icons.grain_rounded;
                  iconColor = const Color(0xFFD97706);
                } else if (nameLower.contains('dairy')) {
                  icon = Icons.water_drop_rounded;
                  iconColor = const Color(0xFF2563EB);
                } else if (nameLower.contains('poultry') ||
                    nameLower.contains('egg')) {
                  icon = Icons.egg_rounded;
                  iconColor = const Color(0xFFCA8A04);
                } else if (nameLower.contains('livestock') ||
                    nameLower.contains('meat')) {
                  icon = Icons.pets_rounded;
                  iconColor = const Color(0xFFB45309);
                } else if (nameLower.contains('herb') ||
                    nameLower.contains('spice')) {
                  icon = Icons.spa_rounded;
                  iconColor = const Color(0xFF0D9488);
                } else if (nameLower.contains('root') ||
                    nameLower.contains('potato')) {
                  icon = Icons.grass_rounded;
                  iconColor = const Color(0xFF4F46E5);
                }

                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _hoveredCategories.add(i)),
                  onExit: (_) => setState(() => _hoveredCategories.remove(i)),
                  child: GestureDetector(
                    onTap: () => widget.onNavigate(1, name),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 150,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isHovered
                              ? _primary.withValues(alpha: 0.3)
                              : _border,
                          width: 1.5,
                        ),
                        boxShadow: isHovered
                            ? [
                                BoxShadow(
                                  color: _primary.withValues(alpha: 0.12),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: isHovered
                                  ? iconColor.withValues(alpha: 0.15)
                                  : _surface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: iconColor, size: 28),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _dark,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            desc,
                            style: GoogleFonts.inter(
                              fontSize: 11,
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
                );
              }

              if (isMobile) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: List.generate(cats.length, (i) {
                      return Padding(
                        padding: EdgeInsets.only(
                          left: i == 0 ? 0 : 12,
                          right: i == cats.length - 1 ? 0 : 12,
                        ),
                        child: buildCategoryItem(i, cats[i]),
                      );
                    }),
                  ),
                );
              }

              return Wrap(
                spacing: 18,
                runSpacing: 18,
                alignment: WrapAlignment.center,
                children: List.generate(cats.length, (i) {
                  return buildCategoryItem(i, cats[i]);
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FEATURED FARM PRODUCE (E-Commerce Style Grid)
  // ─────────────────────────────────────────────────────────────
  Widget _buildFeaturedProducts() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1320),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 24,
          vertical: isMobile ? 32 : 48,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.eco_rounded,
                            size: 13,
                            color: Color(0xFF059669),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'HARVESTED TODAY',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF059669),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Featured Farm Products',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Support local growers — 100% farm-direct produce delivered in 24 hours',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => widget.onNavigate(1),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'View All Products',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF059669),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 15,
                          color: Color(0xFF059669),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _productsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: Color(0xFF059669)),
                    ),
                  );
                }
                final currentUserId = SupabaseConfig.currentUser?.id;
                final products = (snapshot.data ?? []).where((p) {
                  final fId =
                      p['farmer_id']?.toString() ??
                      p['farmer']?['farmer_id']?.toString();
                  return currentUserId == null || fId != currentUserId;
                }).toList();

                if (products.isEmpty) {
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        'No featured farm products available right now.',
                        style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                      ),
                    ),
                  );
                }

                final displayProducts = products.take(12).toList();

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    // Responsive compact cross-axis count (Lazada / Shopee standard)
                    int crossAxisCount = width < 550
                        ? 2
                        : (width < 800
                            ? 3
                            : (width < 1100
                                ? 4
                                : (width < 1350 ? 5 : 6)));

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: displayProducts.length,
                      itemBuilder: (context, i) {
                        final p = displayProducts[i];
                        final productItem = _productFromMap(p);
                        return _buildMarketplaceProductCard(productItem, p);
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketplaceProductCard(
    ProductItem product,
    Map<String, dynamic> raw,
  ) {
    final rawPrice = product.price.replaceAll(RegExp(r'[^0-9.]'), '');
    final double price = double.tryParse(rawPrice) ?? 0.0;
    final String unitLabel = product.unit.isNotEmpty
        ? ' / ${product.unit}'
        : '';
    final String farmTitle = (product.farm.isNotEmpty && product.farm != 'Farm')
        ? product.farm
        : ((product.farmerName != null && product.farmerName!.isNotEmpty)
              ? product.farmerName!
              : 'Local Farm');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (product.productId != null) {
            context.push('/product/${product.productId}');
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    height: 125,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(11),
                      ),
                      color: Color(0xFFF8FAFC),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(11),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: product.imageUrl.isNotEmpty
                            ? product.imageUrl
                            : 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=400&q=80',
                        fit: BoxFit.cover,
                        placeholder: (ctx, url) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (ctx, url, err) => const Center(
                          child: Icon(
                            Icons.eco_rounded,
                            size: 36,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Farm Fresh Badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF059669), Color(0xFF10B981)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF059669,
                            ).withValues(alpha: 0.35),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.eco, size: 10, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            'Farm Fresh',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Real discount badge if exists in database
                  if (raw['discount'] != null || raw['original_price'] != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          raw['discount'] != null
                              ? '-${raw['discount']}%'
                              : 'SALE',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),

                      // Farmer / Origin
                      GestureDetector(
                        onTap: () {
                          if (product.farmerId != null) {
                            _openFarmerProfile(product.farmerId);
                          }
                        },
                        child: Row(
                          children: [
                            const Icon(
                              Icons.storefront_rounded,
                              size: 11,
                              color: Color(0xFF059669),
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                farmTitle,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF059669),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (product.rating != null &&
                                product.rating != '0' &&
                                product.rating != '0.0') ...[
                              const Icon(
                                Icons.star_rounded,
                                size: 12,
                                color: Color(0xFFF59E0B),
                              ),
                              Text(
                                ' ${product.rating}',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ] else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Direct',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF059669),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Price Section
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '₱${price.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF059669),
                            ),
                          ),
                          Text(
                            unitLabel,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          if (raw['original_price'] != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              '₱${raw['original_price']}',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: const Color(0xFF94A3B8),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Add to Cart Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            CartService().addItem(product);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added ${product.name} to Cart!'),
                                backgroundColor: const Color(0xFF059669),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                                action: SnackBarAction(
                                  label: 'VIEW CART',
                                  textColor: Colors.white,
                                  onPressed: () => context.push(AppRoutes.cart),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.shopping_bag_outlined,
                            size: 13,
                          ),
                          label: const Text('Add to Cart'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
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
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PROMOTED FARMERS & GROWERS (Meet Your Growers Hub)
  // ─────────────────────────────────────────────────────────────
  Widget _buildFarmerSpotlight() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1320),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 24,
          vertical: isMobile ? 32 : 48,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_user_rounded,
                            size: 13,
                            color: Color(0xFFD97706),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'PROMOTED GROWERS',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFD97706),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Meet Our Featured Farmers',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Direct partnerships with accredited Filipino agricultural cooperatives and farms',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => context.push(AppRoutes.localShops),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Explore All Farms',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF059669),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 15,
                          color: Color(0xFF059669),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _farmersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: Color(0xFF059669)),
                    ),
                  );
                }
                final farmers = snapshot.data ?? [];
                if (farmers.isEmpty) {
                  return const SizedBox.shrink();
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    int crossAxisCount =
                        width < 650 ? 1 : (width < 1050 ? 2 : 3);

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.30,
                      ),
                      itemCount: farmers.take(6).length,
                      itemBuilder: (context, i) {
                        final f = farmers[i];
                        return _buildPromotedFarmerCard(f);
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotedFarmerCard(Map<String, dynamic> farmer) {
    final farmName = farmer['farm_name'] ?? farmer['full_name'] ?? 'Local Farm';
    final ownerName = farmer['full_name'] ?? 'Accredited Farmer';
    final location =
        farmer['farm_address'] ?? farmer['location'] ?? 'San Carlos City, Pangasinan';
    final specialty = farmer['farming_type'] ?? 'Organic Vegetables & Rice';
    final farmerId = farmer['farmer_id'] ?? farmer['id'] ?? '';
    final avatarUrl = farmer['avatar_url'] ?? farmer['profile_picture'] ?? '';
    final coverUrl = farmer['cover_image_url'] ??
        farmer['farm_image_url'] ??
        'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?w=600&q=80';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _openFarmerProfile(farmerId),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover Banner + Farmer Avatar overlay
                SizedBox(
                  height: 90,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CachedNetworkImage(
                          imageUrl: coverUrl,
                          fit: BoxFit.cover,
                          placeholder: (ctx, url) => Container(
                            color: const Color(0xFFE2E8F0),
                          ),
                          errorWidget: (ctx, url, err) => Container(
                            color: const Color(0xFF064E3B),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.6),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Location Pill
                      Positioned(
                        top: 8,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                size: 10,
                                color: Color(0xFF34D399),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                location,
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Verified Badge
                      Positioned(
                        top: 8,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified_rounded,
                                size: 11,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Verified Grower',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Avatar positioned at bottom-left overlapping cover
                      Positioned(
                        bottom: -16,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFFDCFCE7),
                            backgroundImage: avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl.isEmpty
                                ? Text(
                                    ownerName.isNotEmpty
                                        ? ownerName[0].toUpperCase()
                                        : 'F',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF059669),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 20, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                farmName,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 13,
                                  color: Color(0xFFF59E0B),
                                ),
                                Text(
                                  ' 4.9',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Owner: $ownerName',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '🌾 $specialty',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _openFarmerProfile(farmerId),
                            icon: const Icon(
                              Icons.storefront_outlined,
                              size: 14,
                            ),
                            label: const Text('Visit Farm Store'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF059669),
                              side: const BorderSide(
                                color: Color(0xFF059669),
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              textStyle: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTestimonials() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 64,
        vertical: 64,
      ),
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
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Real updates from growers and buyers across AgriDirect.',
                style: GoogleFonts.inter(fontSize: 14, color: _muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              if (isMobile)
                Column(
                  children: posts.map((post) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildCommunityPostCard(post),
                    );
                  }).toList(),
                )
              else
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

  Widget _buildFooter() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 64,
        vertical: 48,
      ),
      color: _dark,
      child: Column(
        children: [
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand
                Column(
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
                const SizedBox(height: 32),
                // Links and Categories in a Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
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
                    Expanded(
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
                  ],
                ),
                const SizedBox(height: 32),
                // Newsletter
                Column(
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
                      'Get the latest harvest updates and recipes.',
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
              ],
            )
          else
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
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
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Â© 2024 AgriDirect. All rights reserved.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    _buildFooterBottomLink('Privacy Policy'),
                    _buildFooterBottomLink('Terms of Service'),
                    _buildFooterBottomLink('Cookie Policy'),
                  ],
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Â© 2024 AgriDirect. All rights reserved.',
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

  static const String _privacyPolicyText =
      'At AgriDirect, we value your privacy. We collect basic account details (name, email, phone) to facilitate purchases and connect you with local farmers. We never share your data with third parties without your consent. By using the app, you agree to our standard data handling procedures.';
  static const String _termsOfServiceText =
      'Welcome to AgriDirect. By registering as a consumer or farmer, you agree to comply with our community guidelines. Farmers must supply authentic information and fresh, high-quality produce. Customers must complete transaction payments in good faith.';
  static const String _cookiePolicyText =
      'AgriDirect uses cookies to enhance your browsing experience, store session parameters, and analyze site metrics. Cookies are stored locally on your device and can be managed through your browser settings at any time.';

  void _handleFooterLinkTap(String text) {
    if (text == 'Find a Farmer') {
      FindAFarmerDialog.show(
        context,
        onExploreFarmers: () => context.go(AppRoutes.farmersMap),
      );
    } else if (text == 'Vegetables' ||
        text == 'Fruits & Berries' ||
        text == 'Dairy & Eggs' ||
        text == 'Organic Grains') {
      widget.onNavigate(1, text);
    } else if (text == 'Seasonal Calendar') {
      SeasonalCalendarDialog.show(context);
    } else if (text == 'Pricing Plans') {
      PricingPlansDialog.show(context);
    } else if (text == 'Help Center') {
      HelpCenterDialog.show(context);
    } else if (text == 'Privacy Policy') {
      _showPolicyModal('Privacy Policy', _privacyPolicyText);
    } else if (text == 'Terms of Service') {
      _showPolicyModal('Terms of Service', _termsOfServiceText);
    } else if (text == 'Cookie Policy') {
      _showPolicyModal('Cookie Policy', _cookiePolicyText);
    }
  }

  void _showPolicyModal(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Text(
              content,
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.6,
                color: Colors.grey[800],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Redirecting to official social media channel...'),
            ),
          );
        },
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: const Color(0xFF374151)),
          ),
          child: Icon(icon, size: 15, color: const Color(0xFF9CA3AF)),
        ),
      ),
    );
  }

  Widget _buildFooterLink(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _handleFooterLinkTap(text),
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF9CA3AF),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterBottomLink(String text) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _handleFooterLinkTap(text),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}
