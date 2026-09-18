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
    context.go(AppRoutes.product(prodId), extra: product);
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final containerWidth = WebBreakpoints.containerWidth(sw);
    final isMobile = WebBreakpoints.isMobile(sw);

    return Scaffold(
      backgroundColor: WebDesignTokens.bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxHeight <= 120) {
            return const SizedBox.shrink();
          }

          return Column(
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
                                const SizedBox(height: 24),

                                // 1.5 Quick Promotional Discovery Buttons
                                _buildMarketplaceChannelButtons(context, sw),
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
          );
        },
      ),
    );
  }

  // ─── Visual Categories Slider ───
  Widget _buildVisualCategoriesSection(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isWideDesktop = sw >= 1024;

    final isMobile = sw < 650;

    final headerText = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Explore by Harvest Category',
          style: GoogleFonts.rubik(
            fontSize: isMobile ? 18 : 20,
            fontWeight: FontWeight.w700,
            color: WebDesignTokens.dark,
          ),
        ),
        Text(
          'Find fresh local crops sorted by department',
          style: GoogleFonts.nunitoSans(
            fontSize: isMobile ? 12 : 13,
            color: WebDesignTokens.slate500,
          ),
        ),
      ],
    );

    final allCatBtn = TextButton(
      onPressed: () => context.go(AppRoutes.shop),
      child: Text(
        'All Categories >',
        style: GoogleFonts.rubik(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: WebDesignTokens.primary,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              headerText,
              Align(alignment: Alignment.centerLeft, child: allCatBtn),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              headerText,
              allCatBtn,
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
    final isMobile = sw < 650;

    final headerText = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Featured Local Cooperatives',
          style: GoogleFonts.rubik(
            fontSize: isMobile ? 18 : 20,
            fontWeight: FontWeight.w700,
            color: WebDesignTokens.dark,
          ),
        ),
        Text(
          'Accredited farmer associations committed to transparent, fair trade produce',
          style: GoogleFonts.nunitoSans(
            fontSize: isMobile ? 12 : 13,
            color: WebDesignTokens.slate500,
          ),
        ),
      ],
    );

    final viewAllBtn = TextButton(
      onPressed: () => context.go(AppRoutes.localShops),
      child: Text(
        'View All Growers >',
        style: GoogleFonts.rubik(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: WebDesignTokens.primary,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              headerText,
              const SizedBox(height: 6),
              Align(alignment: Alignment.centerLeft, child: viewAllBtn),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              headerText,
              viewAllBtn,
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
                  final avatar = (f['logo_url'] ?? f['avatar_url'] ?? f['profile_image_url'])?.toString();
                  final cover = (f['cover_url'] ?? f['cover_image_url'] ?? f['farm_banner_url'])?.toString();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: WebFarmerSpotlightCard(
                      farmName: farmName,
                      farmerName: farmerName,
                      barangay: barangay,
                      rating: rating,
                      totalReviews: reviews,
                      cropsSummary: crops,
                      avatarUrl: avatar,
                      coverUrl: cover,
                      onVisit: () {
                        if (fid != null && fid.toString().isNotEmpty) {
                          context.go('${AppRoutes.farmerProfileBase}/$fid');
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
                final avatar = (f['logo_url'] ?? f['avatar_url'] ?? f['profile_image_url'])?.toString();
                final cover = (f['cover_url'] ?? f['cover_image_url'] ?? f['farm_banner_url'])?.toString();

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
                      avatarUrl: avatar,
                      coverUrl: cover,
                      onVisit: () {
                        if (fid != null && fid.toString().isNotEmpty) {
                          context.go('${AppRoutes.farmerProfileBase}/$fid');
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
            Builder(
              builder: (context) {
                final isMobile = screenWidth < 768;

                final headerTitles = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fresh Harvest Picks For You',
                      style: GoogleFonts.rubik(
                        fontSize: isMobile ? 18 : 20,
                        fontWeight: FontWeight.w700,
                        color: WebDesignTokens.dark,
                      ),
                    ),
                    Text(
                      isMobile
                          ? 'Direct from San Carlos farms picked in last 24h'
                          : 'Direct from San Carlos farms picked in the last 24 hours',
                      style: GoogleFonts.nunitoSans(
                        fontSize: isMobile ? 12 : 13,
                        color: WebDesignTokens.slate500,
                      ),
                    ),
                  ],
                );

                final tabChips = SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Vegetables', 'Fruits', 'Grains'].map((tab) {
                      final isSelected = _activeTab == tab;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
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
                        ),
                      );
                    }).toList(),
                  ),
                );

                if (isMobile) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      headerTitles,
                      const SizedBox(height: 12),
                      tabChips,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    headerTitles,
                    tabChips,
                  ],
                );
              },
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
                  childAspectRatio: screenWidth < 500
                      ? 0.58
                      : (screenWidth < 650 ? 0.62 : 0.68),
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
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 700;

    final metrics = [
      {'val': '100%', 'label': 'Direct Farmer Payouts (0% Markup)'},
      {'val': '86', 'label': 'San Carlos Barangays Covered'},
      {'val': '24h', 'label': 'Harvest-to-Door Freshness'},
      {'val': 'DA Verified', 'label': 'Accredited Grower Network'},
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 20 : 28,
      ),
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
              Flexible(
                child: Text(
                  'AgriDirect Community & Transparency Impact',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.rubik(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w700,
                    color: WebDesignTokens.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (isMobile)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.8,
                crossAxisSpacing: 12,
                mainAxisSpacing: 16,
              ),
              itemCount: metrics.length,
              itemBuilder: (context, i) {
                final m = metrics[i];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      m['val']!,
                      style: GoogleFonts.rubik(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: WebDesignTokens.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      m['label']!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunitoSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: WebDesignTokens.slate600,
                      ),
                    ),
                  ],
                );
              },
            )
          else
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
        'route': AppRoutes.aboutUs,
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

    final isMobile = screenWidth < 768;

    final headerText = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AgriDirect Ecosystem & Community Hub',
          style: GoogleFonts.rubik(
            fontSize: isMobile ? 18 : 20,
            fontWeight: FontWeight.w700,
            color: WebDesignTokens.dark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Connecting San Carlos consumers with accredited growers, weather intelligence, and community resources',
          style: GoogleFonts.nunitoSans(
            fontSize: isMobile ? 12 : 13,
            color: WebDesignTokens.slate500,
          ),
        ),
      ],
    );

    final aboutBtn = TextButton(
      onPressed: () => context.go(AppRoutes.aboutUs),
      child: Text(
        'About AgriDirect >',
        style: GoogleFonts.rubik(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: WebDesignTokens.primary,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              headerText,
              const SizedBox(height: 4),
              Align(alignment: Alignment.centerLeft, child: aboutBtn),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: headerText),
              const SizedBox(width: 16),
              aboutBtn,
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

  // ─── Marketplace Discovery Channel Buttons ───
  Widget _buildMarketplaceChannelButtons(BuildContext context, double sw) {
    final channels = [
      {
        'title': 'Fresh Produce',
        'subtitle': 'Farm Harvest',
        'icon': Icons.eco_rounded,
        'color': const Color(0xFF059669),
        'bgColor': const Color(0xFFECFDF5),
        'route': AppRoutes.freshProduce,
        'badge': 'DAILY',
      },
      {
        'title': 'Flash Sale',
        'subtitle': 'Up to 50% Off',
        'icon': Icons.bolt_rounded,
        'color': const Color(0xFFDC2626),
        'bgColor': const Color(0xFFFEF2F2),
        'route': AppRoutes.flashSale,
        'badge': 'HOT',
      },
      {
        'title': 'Free Shipping',
        'subtitle': 'Min. ₱500 Order',
        'icon': Icons.local_shipping_rounded,
        'color': const Color(0xFF0D9488),
        'bgColor': const Color(0xFFF0FDFA),
        'route': AppRoutes.freeShipping,
        'badge': 'FREE',
      },
      {
        'title': 'Vouchers Hub',
        'subtitle': 'Claim Coupons',
        'icon': Icons.confirmation_number_rounded,
        'color': const Color(0xFFD97706),
        'bgColor': const Color(0xFFFFFBEB),
        'route': AppRoutes.vouchers,
        'badge': 'SAVE',
      },
      {
        'title': 'Wholesale Bulk',
        'subtitle': 'Sacks & Crates',
        'icon': Icons.inventory_2_rounded,
        'color': const Color(0xFF2563EB),
        'bgColor': const Color(0xFFEFF6FF),
        'route': AppRoutes.wholesale,
        'badge': 'BULK',
      },
      {
        'title': 'Local Farms',
        'subtitle': 'San Carlos Shops',
        'icon': Icons.storefront_rounded,
        'color': const Color(0xFF16A34A),
        'bgColor': const Color(0xFFF0FDF4),
        'route': AppRoutes.localShops,
        'badge': 'DIRECT',
      },
    ];

    final isMobile = sw < 768;

    if (isMobile) {
      return SizedBox(
        height: 84,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: channels.length,
          separatorBuilder: (context, index) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final c = channels[i];
            return SizedBox(
              width: 154,
              child: _buildChannelButtonCard(
                context: context,
                title: c['title'] as String,
                subtitle: c['subtitle'] as String,
                icon: c['icon'] as IconData,
                color: c['color'] as Color,
                bgColor: c['bgColor'] as Color,
                route: c['route'] as String,
                badge: c['badge'] as String,
                isMobile: true,
              ),
            );
          },
        ),
      );
    }

    if (sw < 1024) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: channels.map((c) {
          return SizedBox(
            width: (sw - 48 - 24) / 3,
            child: _buildChannelButtonCard(
              context: context,
              title: c['title'] as String,
              subtitle: c['subtitle'] as String,
              icon: c['icon'] as IconData,
              color: c['color'] as Color,
              bgColor: c['bgColor'] as Color,
              route: c['route'] as String,
              badge: c['badge'] as String,
              isMobile: false,
            ),
          );
        }).toList(),
      );
    }

    return Row(
      children: channels.map((c) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildChannelButtonCard(
              context: context,
              title: c['title'] as String,
              subtitle: c['subtitle'] as String,
              icon: c['icon'] as IconData,
              color: c['color'] as Color,
              bgColor: c['bgColor'] as Color,
              route: c['route'] as String,
              badge: c['badge'] as String,
              isMobile: false,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChannelButtonCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String route,
    required String badge,
    required bool isMobile,
  }) {
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: WebDesignTokens.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: WebDesignTokens.border),
          boxShadow: WebDesignTokens.cardRest,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.rubik(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: WebDesignTokens.dark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunitoSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: WebDesignTokens.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: -6,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.rubik(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
