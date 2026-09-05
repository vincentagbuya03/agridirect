import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../constants/web_design_tokens.dart';
import '../../widgets/web_footer.dart';
import '../../widgets/ecom/web_ecom_header.dart';
import '../../widgets/ecom/web_hero_bento_grid.dart';
import '../../widgets/ecom/web_trust_badge_strip.dart';
import '../../widgets/ecom/web_flash_sale_strip.dart';
import '../../widgets/ecom/web_farmer_spotlight_card.dart';
import '../../widgets/ecom/web_product_card.dart';

/// Flagship E-Commerce & Marketplace Home for AgriDirect Web
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

class _WebMarketplaceHomeState extends State<WebMarketplaceHome> {
  final SupabaseDataService _dataService = SupabaseDataService();

  late Future<List<ProductItem>> _productsFuture;
  late Future<List<Map<String, dynamic>>> _farmersFuture;

  String _activeTab = 'All';

  final List<Map<String, dynamic>> _visualCategories = [
    {
      'title': 'Fresh Veggies',
      'icon': Icons.eco_rounded,
      'items': 'Direct Farm Harvest',
      'category': 'Vegetables',
    },
    {
      'title': 'Root Crops',
      'icon': Icons.grass_rounded,
      'items': 'Cassava, Ube & Taro',
      'category': 'Root Crops',
    },
    {
      'title': 'Sweet Fruits',
      'icon': Icons.apple_rounded,
      'items': 'Seasonal Orchards',
      'category': 'Fruits',
    },
    {
      'title': 'Rice & Grains',
      'icon': Icons.grain_rounded,
      'items': 'Pangasinan Grains',
      'category': 'Grains',
    },
    {
      'title': 'Organic & GAP',
      'icon': Icons.spa_rounded,
      'items': 'Certified Eco-Farms',
      'category': 'Organic',
    },
    {
      'title': 'Flash Deals',
      'icon': Icons.bolt_rounded,
      'items': 'Limited Discounts',
      'category': 'Deals',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _productsFuture = _dataService.getNearbyProducts();
    _farmersFuture = _dataService.getFeaturedFarmers();
  }

  void _navigateToProduct(ProductItem product) {
    final prodId = product.productId ?? 'view';
    context.push(AppRoutes.product(prodId), extra: product);
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final containerWidth = WebBreakpoints.containerWidth(sw);
    final isMobile = WebBreakpoints.isMobile(sw);

    return Scaffold(
      backgroundColor: WebDesignTokens.bg,
      body: Column(
        children: [
          // ─── 3-Tier Enterprise E-Commerce Header ───
          WebEcomHeader(
            currentIndex: widget.currentIndex,
            onNavigate: widget.onNavigate,
            onSearch: (query) {
              context.go(AppRoutes.shop, extra: {'search': query});
            },
          ),

          // ─── Main Scrollable Marketplace Storefront ───
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // Content Container
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: containerWidth),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 12 : 24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Hero Bento Grid
                            WebHeroBentoGrid(
                              onNavigate: widget.onNavigate,
                            ),
                            const SizedBox(height: 28),

                            // 2. 4-Pillar Trust Badge Strip
                            const WebTrustBadgeStrip(),
                            const SizedBox(height: 36),

                            // 3. Visual Harvest Categories
                            _buildVisualCategoriesSection(context),
                            const SizedBox(height: 36),

                            // 4. Dynamic Flash Deals Strip
                            _buildFlashDealsSection(),
                            const SizedBox(height: 36),

                            // 5. Featured Farmer Cooperatives
                            _buildFarmerCooperativesSection(),
                            const SizedBox(height: 36),

                            // 6. Curated Harvest Picks Grid
                            _buildCuratedProduceGrid(sw),
                            const SizedBox(height: 48),

                            // 7. AgriDirect Ecosystem & Community Hub
                            _buildAgriServicesHub(context, sw),
                            const SizedBox(height: 48),

                            // 8. Community & Economic Impact Counter
                            _buildImpactMetricsSection(),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Enterprise Footer
                  const AgriDirectWebFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Visual Categories Slider ───
  Widget _buildVisualCategoriesSection(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isWideDesktop = sw >= 1024;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Explore by Harvest Category',
                  style: GoogleFonts.rubik(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: WebDesignTokens.dark,
                  ),
                ),
                Text(
                  'Find fresh local crops sorted by agricultural department',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 13,
                    color: WebDesignTokens.slate500,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.shop),
              child: Text(
                'All Categories >',
                style: GoogleFonts.rubik(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: WebDesignTokens.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (isWideDesktop)
          Row(
            children: _visualCategories.map((cat) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: _buildCategoryCard(cat),
                ),
              );
            }).toList(),
          )
        else
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _visualCategories.length,
              separatorBuilder: (_, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                return SizedBox(
                  width: 140,
                  child: _buildCategoryCard(_visualCategories[index]),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> cat) {
    final isDeal = cat['category'] == 'Deals';

    return InkWell(
      onTap: () {
        if (isDeal) {
          context.go(AppRoutes.flashSale);
        } else {
          final catName = Uri.encodeComponent(cat['category'] as String);
          context.go('${AppRoutes.shop}?category=$catName');
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 106,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: isDeal
              ? WebDesignTokens.dealAmber.withValues(alpha: 0.08)
              : WebDesignTokens.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDeal
                ? WebDesignTokens.dealAmber.withValues(alpha: 0.3)
                : WebDesignTokens.border,
          ),
          boxShadow: WebDesignTokens.cardRest,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDeal
                    ? WebDesignTokens.dealAmber.withValues(alpha: 0.15)
                    : WebDesignTokens.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                cat['icon'] as IconData,
                color: isDeal
                    ? WebDesignTokens.dealAmber
                    : WebDesignTokens.primary,
                size: 20,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              cat['title'] as String,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.rubik(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: WebDesignTokens.dark,
              ),
            ),
            Text(
              cat['items'] as String,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                fontSize: 11,
                color: WebDesignTokens.slate500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Dynamic Flash Deals Strip ───
  Widget _buildFlashDealsSection() {
    return FutureBuilder<List<ProductItem>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final all = snapshot.data!;
        final flashDeals = all
            .where((p) =>
                p.isFlashSale ||
                (p.discountPercent != null && p.discountPercent! > 0))
            .take(8)
            .toList();

        if (flashDeals.isEmpty) {
          // Fallback: take first 4 items as showcase deals
          return WebFlashSaleStrip(
            flashProducts: all.take(4).toList(),
            onViewAll: () => context.go(AppRoutes.flashSale),
            onProductTap: _navigateToProduct,
          );
        }

        return WebFlashSaleStrip(
          flashProducts: flashDeals,
          onViewAll: () => context.go(AppRoutes.flashSale),
          onProductTap: _navigateToProduct,
        );
      },
    );
  }

  // ─── Featured Farmer Cooperatives ───
  Widget _buildFarmerCooperativesSection() {
    final sw = MediaQuery.of(context).size.width;
    final isCompact = sw < 1024;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Featured Local Cooperatives',
                  style: GoogleFonts.rubik(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: WebDesignTokens.dark,
                  ),
                ),
                Text(
                  'Accredited farmer associations committed to transparent, fair trade produce',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 13,
                    color: WebDesignTokens.slate500,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.localShops),
              child: Text(
                'View All Growers >',
                style: GoogleFonts.rubik(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: WebDesignTokens.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _farmersFuture,
          builder: (context, snapshot) {
            final farmers = snapshot.data ?? [];
            final topFarmers = farmers.take(3).toList();

            if (topFarmers.isEmpty) {
              // Verified Regional Cooperatives Overview
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: WebDesignTokens.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: WebDesignTokens.border),
                  boxShadow: WebDesignTokens.cardRest,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(
                        color: WebDesignTokens.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified_user_rounded,
                          color: WebDesignTokens.primary, size: 28),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'San Carlos Agricultural Cooperatives & Registered Farms',
                            style: GoogleFonts.rubik(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: WebDesignTokens.dark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'All local growers on AgriDirect are verified in partnership with the City Agriculture Office. Browse certified organic and standard producers across all 86 barangays.',
                            style: GoogleFonts.nunitoSans(
                              fontSize: 13,
                              color: WebDesignTokens.slate600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WebDesignTokens.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () =>
                          context.go(AppRoutes.localShops),
                      child: Text(
                        'Explore Farm Directory >',
                        style: GoogleFonts.rubik(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            if (isCompact) {
              return Column(
                children: topFarmers.map((f) {
                  final farmName = (f['farm_name'] ?? f['shop_name'] ?? 'Local Farm').toString();
                  final farmerName = (f['full_name'] ?? f['farmer_name'] ?? 'Local Farmer').toString();
                  final barangay = (f['location'] ?? f['farm_address'] ?? 'San Carlos City').toString();
                  final rating = (f['average_rating'] ?? f['rating'] ?? '5.0').toString();
                  final reviews = int.tryParse(f['review_count']?.toString() ?? '') ?? 0;
                  final crops = (f['specialty'] ?? 'Fresh Crops').toString();
                  final fid = f['farmer_id'] ?? f['id'];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: WebFarmerSpotlightCard(
                      farmName: farmName,
                      farmerName: farmerName,
                      barangay: barangay,
                      rating: rating,
                      totalReviews: reviews,
                      cropsSummary: crops,
                      onVisit: () {
                        if (fid != null && fid.toString().isNotEmpty) {
                          context.push('${AppRoutes.farmerProfileBase}/$fid');
                        } else {
                          context.go(AppRoutes.localShops);
                        }
                      },
                    ),
                  );
                }).toList(),
              );
            }

            return Row(
              children: topFarmers.map((f) {
                final farmName = (f['farm_name'] ?? f['shop_name'] ?? 'Local Farm').toString();
                final farmerName = (f['full_name'] ?? f['farmer_name'] ?? 'Local Farmer').toString();
                final barangay = (f['location'] ?? f['farm_address'] ?? 'San Carlos City').toString();
                final rating = (f['average_rating'] ?? f['rating'] ?? '5.0').toString();
                final reviews = int.tryParse(f['review_count']?.toString() ?? '') ?? 0;
                final crops = (f['specialty'] ?? 'Fresh Crops').toString();
                final fid = f['farmer_id'] ?? f['id'];

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: WebFarmerSpotlightCard(
                      farmName: farmName,
                      farmerName: farmerName,
                      barangay: barangay,
                      rating: rating,
                      totalReviews: reviews,
                      cropsSummary: crops,
                      onVisit: () {
                        if (fid != null && fid.toString().isNotEmpty) {
                          context.push('${AppRoutes.farmerProfileBase}/$fid');
                        } else {
                          context.go(AppRoutes.localShops);
                        }
                      },
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ─── Curated Harvest Picks Grid ───
  Widget _buildCuratedProduceGrid(double screenWidth) {
    int columns = 5;
    if (screenWidth < 650) {
      columns = 2;
    } else if (screenWidth < 950) {
      columns = 3;
    } else if (screenWidth < 1280) {
      columns = 4;
    }

    return FutureBuilder<List<ProductItem>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: CircularProgressIndicator(color: WebDesignTokens.primary),
            ),
          );
        }

        final products = snapshot.data ?? [];
        final filtered = _activeTab == 'All'
            ? products
            : products
                .where((p) =>
                    (p.categoryName?.toLowerCase() ?? '') ==
                    _activeTab.toLowerCase())
                .toList();

        final displayItems = filtered.take(15).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header & Tabs
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fresh Harvest Picks For You',
                      style: GoogleFonts.rubik(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: WebDesignTokens.dark,
                      ),
                    ),
                    Text(
                      'Direct from San Carlos farms picked in the last 24 hours',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 13,
                        color: WebDesignTokens.slate500,
                      ),
                    ),
                  ],
                ),
                // Tab Filter Chips
                Wrap(
                  spacing: 6,
                  children: ['All', 'Vegetables', 'Fruits', 'Grains'].map((tab) {
                    final isSelected = _activeTab == tab;
                    return ChoiceChip(
                      label: Text(tab),
                      labelStyle: GoogleFonts.rubik(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : WebDesignTokens.slate600,
                      ),
                      selected: isSelected,
                      selectedColor: WebDesignTokens.primary,
                      backgroundColor: WebDesignTokens.surface,
                      side: BorderSide(
                        color: isSelected
                            ? WebDesignTokens.primary
                            : WebDesignTokens.border,
                      ),
                      onSelected: (_) => setState(() => _activeTab = tab),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Product Grid
            if (displayItems.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: WebDesignTokens.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: WebDesignTokens.border),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.eco_outlined,
                        size: 48, color: WebDesignTokens.slate400),
                    const SizedBox(height: 12),
                    Text(
                      'No produce available in this category today',
                      style: GoogleFonts.rubik(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: WebDesignTokens.dark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Check back tomorrow morning for new harvest dispatches!',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 13,
                        color: WebDesignTokens.slate500,
                      ),
                    ),
                  ],
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  childAspectRatio: 0.68,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemCount: displayItems.length,
                itemBuilder: (context, index) {
                  final product = displayItems[index];
                  return WebProductCard(
                    product: product,
                    onTap: () => _navigateToProduct(product),
                  );
                },
              ),

            const SizedBox(height: 28),

            // View Complete Catalog CTA
            Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: WebDesignTokens.primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.storefront_rounded, size: 20),
                label: Text(
                  'Explore Complete Produce Catalog >',
                  style: GoogleFonts.rubik(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () => context.go(AppRoutes.shop),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Community & Economic Impact Counter ───
  Widget _buildImpactMetricsSection() {
    final metrics = [
      {'val': '100%', 'label': 'Direct Farmer Payouts (0% Markup)'},
      {'val': '86', 'label': 'San Carlos Barangays Covered'},
      {'val': '24h', 'label': 'Harvest-to-Door Freshness'},
      {'val': 'DA Verified', 'label': 'Accredited Grower Network'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: WebDesignTokens.primaryLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: WebDesignTokens.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.volunteer_activism_rounded,
                  color: WebDesignTokens.primaryDark, size: 22),
              const SizedBox(width: 8),
              Text(
                'AgriDirect Community & Transparency Impact',
                style: GoogleFonts.rubik(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: WebDesignTokens.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: metrics.map((m) {
              return Expanded(
                child: Column(
                  children: [
                    Text(
                      m['val']!,
                      style: GoogleFonts.rubik(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: WebDesignTokens.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      m['label']!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunitoSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: WebDesignTokens.slate600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── AgriDirect Ecosystem & Community Hub ───
  Widget _buildAgriServicesHub(BuildContext context, double screenWidth) {
    final services = [
      {
        'title': 'Find Local Growers',
        'tag': 'INTERACTIVE MAP',
        'desc':
            'Locate 200+ verified growers across 86 San Carlos barangays. View farm locations and shop directly.',
        'icon': Icons.explore_rounded,
        'color': WebDesignTokens.primary,
        'action': 'Explore Map →',
        'route': AppRoutes.farmersMap,
      },
      {
        'title': 'Agricultural Weather',
        'tag': 'RADAR & FORECAST',
        'desc':
            'Hyper-local precipitation radar, typhoon advisories, and seasonal harvest forecasting for Pangasinan.',
        'icon': Icons.cloud_sync_rounded,
        'color': const Color(0xFF0284C7),
        'action': 'Check Weather →',
        'route': AppRoutes.weatherRadar,
      },
      {
        'title': 'Farmer Community',
        'tag': 'GROWER FORUM',
        'desc':
            'Engage with local farmers, share recipes, read harvest dispatches, and ask agricultural questions.',
        'icon': Icons.forum_rounded,
        'color': const Color(0xFFD97706),
        'action': 'Join Forum →',
        'route': AppRoutes.community,
      },
      {
        'title': 'Our Mission & Story',
        'tag': 'FARM-TO-TABLE',
        'desc':
            'Learn why AgriDirect exists: 100% fair payouts to growers, zero middleman markups, and fresh harvest.',
        'icon': Icons.local_florist_rounded,
        'color': const Color(0xFF059669),
        'action': 'Read Our Story →',
        'route': AppRoutes.webWelcome,
      },
    ];

    Widget buildCard(Map<String, dynamic> svc) {
      final color = svc['color'] as Color;
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: WebDesignTokens.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: WebDesignTokens.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(svc['icon'] as IconData, color: color, size: 22),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    svc['tag'] as String,
                    style: GoogleFonts.rubik(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              svc['title'] as String,
              style: GoogleFonts.rubik(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: WebDesignTokens.dark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              svc['desc'] as String,
              style: GoogleFonts.nunitoSans(
                fontSize: 12.5,
                color: WebDesignTokens.slate500,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => context.go(svc['route'] as String),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      svc['action'] as String,
                      style: GoogleFonts.rubik(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AgriDirect Ecosystem & Community Hub',
                  style: GoogleFonts.rubik(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: WebDesignTokens.dark,
                  ),
                ),
                Text(
                  'Connecting San Carlos consumers with accredited growers, weather intelligence, and community resources',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 13,
                    color: WebDesignTokens.slate500,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.aboutUs),
              child: Text(
                'About AgriDirect >',
                style: GoogleFonts.rubik(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: WebDesignTokens.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (screenWidth >= 1024)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: services.map((s) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: buildCard(s),
                ),
              );
            }).toList(),
          )
        else if (screenWidth >= 650)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: services.map((s) {
              return SizedBox(
                width: (screenWidth - 72) / 2,
                child: buildCard(s),
              );
            }).toList(),
          )
        else
          Column(
            children: services.map((s) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: buildCard(s),
              );
            }).toList(),
          ),
      ],
    );
  }
}
