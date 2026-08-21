import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/widgets/app_shimmer_loader.dart';
import '../../widgets/web_promo_header.dart';

class WebLocalShopsScreen extends StatefulWidget {
  const WebLocalShopsScreen({super.key});

  @override
  State<WebLocalShopsScreen> createState() => _WebLocalShopsScreenState();
}

class _WebLocalShopsScreenState extends State<WebLocalShopsScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<Map<String, dynamic>>> _shopsFuture;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  String _selectedFilter = 'All Farms';
  String _searchQuery = '';

  final List<String> _filters = [
    'All Farms',
    '⭐ Top Rated (4.8+)',
    '📍 Nearest (< 5km)',
    '🌾 Certified Organic',
    '📦 Bulk Producers',
  ];

  @override
  void initState() {
    super.initState();
    _shopsFuture = SupabaseDataService().getFeaturedFarmers();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _showFarmerProfile(BuildContext context, Map<String, dynamic> farmer) {
    final farmerId = farmer['farmer_id'] ?? farmer['id'];
    if (farmerId != null && farmerId.toString().isNotEmpty) {
      context.push('${AppRoutes.farmerProfileBase}/$farmerId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            WebPromoHeader(
              activeTab: 'local_shops',
              searchPlaceholder: 'Search registered farm shops, growers & cooperatives...',
              onSearchChanged: (q) => setState(() => _searchQuery = q.toLowerCase()),
            ),
            _buildHeroBanner(),
            const SizedBox(height: 32),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1350),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCommunityValues(),
                      const SizedBox(height: 36),
                      _buildSectionHeader(),
                      const SizedBox(height: 16),
                      _buildFilterChips(),
                      const SizedBox(height: 24),
                      _buildShopGrid(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF064E3B), // Dark green
            Color(0xFF047857), // Forest green
            Color(0xFF059669), // Emerald
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF047857).withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -60,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -80,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1350),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 32,
                  vertical: isMobile ? 24 : 48,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => context.pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_back_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Back to Marketplace',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFBBF24),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.favorite_rounded,
                                        size: 14, color: Color(0xFF78350F)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '100% DIRECT · SUPPORT LOCAL AGRICULTURE',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF78350F),
                                        fontSize: isMobile ? 9.5 : 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Local Farms & Shops',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: isMobile ? 30 : 42,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                'Meet Your Growers 🏡',
                                style: GoogleFonts.playfairDisplay(
                                  color: const Color(0xFF6EE7B7),
                                  fontSize: isMobile ? 32 : 48,
                                  fontWeight: FontWeight.w700,
                                  fontStyle: FontStyle.italic,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 620),
                                child: Text(
                                  'Explore verified farm storefronts across San Carlos City, Pangasinan. Read reviews, browse harvest calendars, and order straight from the field.',
                                  style: GoogleFonts.inter(
                                    color: Colors.white
                                        .withValues(alpha: 0.85),
                                    fontSize: isMobile ? 13 : 15,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isMobile) ...[
                          const SizedBox(width: 48),
                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.25),
                                    Colors.white.withValues(alpha: 0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                  color: Colors.white
                                      .withValues(alpha: 0.3),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF047857)
                                        .withValues(alpha: 0.5),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.storefront_rounded,
                                color: Colors.white,
                                size: 64,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityValues() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    final values = [
      {
        'icon': Icons.location_on_rounded,
        'title': 'Nearby Farms First',
        'desc': 'Shortest travel time ensures minimal carbon footprint.',
        'color': const Color(0xFF059669),
        'bg': const Color(0xFFD1FAE5),
      },
      {
        'icon': Icons.handshake_rounded,
        'title': 'Fair Farmer Profits',
        'desc': '100% of product pricing goes directly to local families.',
        'color': const Color(0xFF2563EB),
        'bg': const Color(0xFFDBEAFE),
      },
      {
        'icon': Icons.verified_user_rounded,
        'title': 'Registered Agri-Hubs',
        'desc': 'Verified credentials backed by Department of Agriculture.',
        'color': const Color(0xFFD97706),
        'bg': const Color(0xFFFEF3C7),
      },
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: isMobile ? 16 : 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              children: values.map((v) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: v['bg'] as Color,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          v['icon'] as IconData,
                          color: v['color'] as Color,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v['title'] as String,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              v['desc'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            )
          : Row(
              children: values.map((v) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: v['bg'] as Color,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            v['icon'] as IconData,
                            color: v['color'] as Color,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                v['title'] as String,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                v['desc'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildSectionHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Featured San Carlos Farm Producers',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Browse registered San Carlos City growers and view their fresh catalog',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              onTap: () => setState(() => _selectedFilter = filter),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF059669) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF059669)
                        : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF059669)
                                .withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  filter,
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildShopGrid() {
    final sw = MediaQuery.of(context).size.width;
    int crossAxisCount = sw < 600 ? 1 : (sw < 960 ? 2 : (sw < 1200 ? 3 : 4));
    double childAspectRatio = sw < 480 ? 1.05 : (sw < 640 ? 1.18 : (sw < 960 ? 1.08 : 1.18));

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _shopsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: childAspectRatio,
            ),
            itemCount: 4,
            itemBuilder: (context, index) =>
                const AppShimmerLoader(height: 260),
          );
        }

        var shops = snapshot.data ?? [];
        if (_searchQuery.isNotEmpty) {
          shops = shops.where((s) {
            final name = (s['farm_name'] ?? s['shop_name'] ?? s['full_name'] ?? s['name'] ?? '').toString().toLowerCase();
            final loc = (s['location'] ?? s['address'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery) || loc.contains(_searchQuery);
          }).toList();
        }
        if (_selectedFilter == '⭐ Top Rated (4.8+)') {
          shops = shops.where((s) {
            final r = _parseSafeDouble(s['rating'], 4.9);
            return r >= 4.8;
          }).toList();
        } else if (_selectedFilter == '📍 Nearest (< 5km)') {
          shops = shops.where((s) {
            final d = _parseSafeDouble(s['distance_km'], 2.0);
            return d <= 5.0;
          }).toList();
        }
        if (shops.isEmpty) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF0FDF4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.storefront_outlined,
                        size: 48, color: Color(0xFF059669)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Local Shops Found',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'We are continuously onboarding more local growers. Check back soon!',
                    style: GoogleFonts.inter(
                        color: const Color(0xFF64748B), fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: shops.length,
          itemBuilder: (context, index) {
            return _WebShopCard(
              farmer: shops[index],
              index: index,
              onTap: () => _showFarmerProfile(context, shops[index]),
            );
          },
        );
      },
    );
  }

  static double _parseSafeDouble(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? fallback;
  }
}

class _WebShopCard extends StatefulWidget {
  final Map<String, dynamic> farmer;
  final int index;
  final VoidCallback onTap;

  const _WebShopCard({
    required this.farmer,
    this.index = 0,
    required this.onTap,
  });

  @override
  State<_WebShopCard> createState() => _WebShopCardState();
}

class _WebShopCardState extends State<_WebShopCard> {
  bool _isHovered = false;

  static const List<String> _defaultFarmPhotos = [
    'assets/images/farmer images/Pangasinan-farmers.jpg',
    'assets/images/farmer images/images (1).jpg',
    'assets/images/farmer images/images.jpg',
  ];

  double _safeDouble(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? fallback;
  }

  int _safeInt(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    final farmer = widget.farmer;
    final shopName = farmer['farm_name'] ??
        farmer['shop_name'] ??
        farmer['full_name'] ??
        farmer['users']?['name'] ??
        farmer['user']?['name'] ??
        farmer['name'] ??
        'Local Farm';
    final location =
        farmer['farm_address'] ?? farmer['location'] ?? farmer['address'] ?? 'San Carlos City, Pangasinan';
    final dynamic rawRating = farmer['rating'] ?? farmer['average_rating'];
    final double rating = _safeDouble(rawRating, 0.0);
    final dynamic rawOrders = farmer['order_count'] ?? farmer['orders'];
    final int orders = _safeInt(rawOrders, 0);
    final dynamic rawDist = farmer['distance_km'];
    final double? distance = rawDist != null ? _safeDouble(rawDist, 0.0) : null;
    
    String? resolveImg(String? rawUrl) {
      if (rawUrl == null || rawUrl.trim().isEmpty || rawUrl == 'null') {
        return null;
      }
      final trimmed = rawUrl.trim();
      if (trimmed.startsWith('assets/')) {
        return trimmed;
      }
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return trimmed;
      }
      String cleanPath = trimmed;
      if (cleanPath.startsWith('uploads/')) {
        cleanPath = cleanPath.substring('uploads/'.length);
      } else if (cleanPath.startsWith('/uploads/')) {
        cleanPath = cleanPath.substring('/uploads/'.length);
      }
      return SupabaseConfig.client.storage.from('uploads').getPublicUrl(cleanPath);
    }

    final rawAvatar = (farmer['image_url'] ??
            farmer['imageUrl'] ??
            farmer['avatar_url'] ??
            farmer['profile_picture'] ??
            farmer['users']?['avatar_url'] ??
            '')
        .toString()
        .trim();
    final avatarUrl = resolveImg(rawAvatar) ?? '';

    // Check multiple possible image fields for cover banner
    String rawImg = (farmer['cover_image_url'] ??
            farmer['farm_image_url'] ??
            farmer['farm_banner_url'] ??
            farmer['banner_url'] ??
            farmer['image_url'] ??
            farmer['imageUrl'] ??
            '')
        .toString()
        .trim();
    String? resolvedBanner = resolveImg(rawImg);
    if (resolvedBanner == null || resolvedBanner.isEmpty) {
      rawImg = _defaultFarmPhotos[widget.index % _defaultFarmPhotos.length];
    } else {
      rawImg = resolvedBanner;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? const Color(0xFF059669).withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: _isHovered ? 18 : 8,
                offset: Offset(0, _isHovered ? 6 : 2),
              ),
            ],
            border: Border.all(
              color: _isHovered
                  ? const Color(0xFF059669).withValues(alpha: 0.35)
                  : const Color(0xFFF1F5F9),
              width: _isHovered ? 1.5 : 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox(
                      height: 95,
                      width: double.infinity,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: rawImg.startsWith('assets/')
                                ? Image.asset(
                                    rawImg,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        _buildDefaultBanner(),
                                  )
                                : CachedNetworkImage(
                                    imageUrl: rawImg,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        _buildDefaultBanner(),
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
                                    Colors.black.withValues(alpha: 0.5),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: -18,
                      left: 14,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: (avatarUrl.isNotEmpty && avatarUrl != 'null')
                              ? (avatarUrl.startsWith('assets/')
                                  ? Image.asset(
                                      avatarUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          _buildAvatarFallback(shopName),
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: avatarUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) =>
                                          _buildAvatarFallback(shopName),
                                    ))
                              : _buildAvatarFallback(shopName),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded, size: 11, color: Colors.white),
                            const SizedBox(width: 3),
                            Text(
                              'Verified',
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
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 22, 14, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                shopName,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E293B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 12, color: Color(0xFF059669)),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                distance != null
                                    ? '$location • ${distance.toStringAsFixed(1)} km'
                                    : location,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (rating > 0) ...[
                              const Icon(Icons.star_rounded,
                                  size: 14, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 2),
                              Text(
                                rating.toStringAsFixed(1),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ],
                            if (orders > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                rating > 0 ? '• $orders orders' : '$orders orders',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ] else if (rating == 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Direct Grower',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF059669),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: widget.onTap,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF059669),
                              side: const BorderSide(
                                  color: Color(0xFF059669), width: 1.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                            ),
                            child: Text(
                              'Visit Store',
                              style: GoogleFonts.inter(
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
      ),
    );
  }

  Widget _buildAvatarFallback(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'F';
    return Container(
      color: const Color(0xFFDCFCE7),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF059669),
        ),
      ),
    );
  }

  Widget _buildDefaultBanner() {
    return Image.asset(
      'assets/images/farmer images/Pangasinan-farmers.jpg',
      fit: BoxFit.cover,
      errorBuilder: (ctx, err, stack) => Image.asset(
        'assets/images/san_carlos_farming_1.jpg',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFF005A36),
          child: const Center(
            child: Icon(Icons.agriculture_rounded, color: Colors.white38, size: 36),
          ),
        ),
      ),
    );
  }
}
