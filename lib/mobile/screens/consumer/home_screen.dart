import 'package:flutter/material.dart';
import 'search_screen.dart';
import '../auth/qr_scanner_screen.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/services/commerce/cart_service.dart';
import '../../../shared/services/user/user_service.dart';
import '../../../shared/models/auth/user_address_model.dart';
import '../../../shared/widgets/image_widgets.dart';
import 'cart_screen.dart';
import 'farmer_public_profile_screen.dart';
import 'community_stories_screen.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/screens/post_detail_screen.dart';
import 'product_view_screen.dart';
import '../../../shared/services/community/notification_service.dart';
import '../../../shared/services/community/message_service.dart';
import '../../../shared/services/auth/auth_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'promo_action_screen.dart';
import 'free_shipping_screen.dart';
import 'vouchers_screen.dart';
import 'wholesale_screen.dart';
import 'fresh_produce_screen.dart';
import 'flash_sale_screen.dart';
import 'local_shops_screen.dart';
import 'more_actions_bottom_sheet.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Map<String, dynamic>>> _featuredFarmersFuture =
      SupabaseDataService().getFeaturedFarmers();
  UserAddress? _defaultAddress;
  bool _addressLoaded = false;

  late Stream<List<ForumPostItem>> _forumStream;
  late Stream<int> _unreadCountStream;

  late Future<List<ProductItem>> _dailyDiscoveriesFuture;

  late Future<List<ProductItem>> _flashSaleProductsFuture;
  String _firstName = '';
  int _currentBannerPage = 0;
  final PageController _bannerController = PageController();
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _forumStream = SupabaseDataService().watchForumPosts();
    _unreadCountStream = MessageService().watchTotalUnreadCount(
      asFarmer: false,
    );

    _dailyDiscoveriesFuture = SupabaseDataService().getNearbyProducts();

    _flashSaleProductsFuture = SupabaseDataService().getFlashSaleProducts();
    _loadDefaultAddress();
    _loadUserFirstName();
    _startBannerAutoPlay();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultAddress() async {
    try {
      final address = await UserService().getUserAddress();
      if (mounted) {
        setState(() {
          _defaultAddress = address;
          _addressLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _addressLoaded = true);
    }
  }

  void _startBannerAutoPlay() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_bannerController.hasClients) {
        final next = (_currentBannerPage + 1) % 3;
        _bannerController.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _loadUserFirstName() async {
    try {
      final user = SupabaseConfig.currentUser;
      if (user == null) return;
      final profile = await SupabaseDataService().getFarmerProfile(user.id);
      final name =
          profile?['full_name']?.toString() ??
          user.userMetadata?['full_name']?.toString() ??
          user.email?.split('@').first ??
          '';
      final first = name.split(' ').first;
      if (mounted) setState(() => _firstName = first);
    } catch (_) {}
  }

  String get _displayCity {
    if (!_addressLoaded) return 'Loading...';
    return _defaultAddress?.city ?? 'Set Location';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          setState(() {
            _dailyDiscoveriesFuture = SupabaseDataService().getNearbyProducts();
            _featuredFarmersFuture = SupabaseDataService().getFeaturedFarmers();

            _flashSaleProductsFuture = SupabaseDataService()
                .getFlashSaleProducts();
          });
        },
        child: Column(
          children: [
            _buildPremiumHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 14, bottom: 40),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGreetingStrip(),
                    _buildFlashSaleCountdownBanner(),
                    _buildPromoBannerCarousel(),
                    _buildQuickActionMenu(),
                    const SizedBox(height: 24),
                    _buildCategoryChipBar(),
                    const SizedBox(height: 24),
                    _buildDailyDiscoveries(),
                    const SizedBox(height: 32),
                    _buildSectionHeader(
                      'Featured Farmers',
                      'Map View',
                      () => context.push(AppRoutes.farmersMap),
                    ),
                    _buildFeaturedFarmersList(context),
                    const SizedBox(height: 32),
                    _buildSectionHeader('Community Feed', 'See All', () {
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (_) => const CommunityStoriesScreen(),
                            ),
                          )
                          .then((_) {
                            if (mounted) setState(() {});
                          });
                    }),
                    _buildCommunityFeed(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ——————————————————————————————————————————————————————————————————————
  Widget _buildGreetingStrip() {
    final hour = DateTime.now().hour;
    final String greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final String emoji = hour < 12
        ? '☀️'
        : hour < 17
        ? '🌤️'
        : '🌙';
    if (_firstName.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting, $_firstName! $emoji',
            style: GoogleFonts.poppins(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
              letterSpacing: -0.4,
            ),
          ),
          Text(
            "What's fresh today?",
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ FLASH SALE LIVE BANNER â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildFlashSaleCountdownBanner() {
    return FutureBuilder<List<ProductItem>>(
      future: _flashSaleProductsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            (snapshot.data ?? []).isEmpty) {
          return const SizedBox.shrink();
        }
        return GestureDetector(
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const FlashSaleScreen())),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C2D12), Color(0xFFEA580C)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Flash Sale is LIVE — Deals ending soon!',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Shop Now →',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── PROMO BANNER CAROUSEL ──────────────────────────────────────────────────
  Widget _buildPromoBannerCarousel() {
    final banners = [
      {
        'title': 'Fresh Produce Sale',
        'subtitle': 'Up to 30% off — limited time!',
        'tag': '🌿 SEASONAL',
        'start': const Color(0xFF047857),
        'end': const Color(0xFF10B981),
        'icon': Icons.eco_rounded,
      },
      {
        'title': 'Free Delivery',
        'subtitle': 'On orders over 500',
        'tag': 'ðŸšš FREE SHIP',
        'start': const Color(0xFFB45309),
        'end': const Color(0xFFF59E0B),
        'icon': Icons.local_shipping_rounded,
      },
      {
        'title': 'Support Local',
        'subtitle': 'Buy directly from farmers',
        'tag': ' FARM FRESH',
        'start': const Color(0xFF1E40AF),
        'end': const Color(0xFF3B82F6),
        'icon': Icons.storefront_rounded,
      },
    ];
    return Column(
      children: [
        SizedBox(
          height: 175,
          child: PageView.builder(
            controller: _bannerController,
            onPageChanged: (i) => setState(() => _currentBannerPage = i),
            itemCount: banners.length,
            itemBuilder: (ctx, index) {
              final b = banners[index];
              return _buildPromoBanner(
                b['title'] as String,
                b['subtitle'] as String,
                b['tag'] as String,
                b['start'] as Color,
                b['end'] as Color,
                b['icon'] as IconData,
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            banners.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentBannerPage == i ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentBannerPage == i
                    ? AppColors.primary
                    : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPromoBanner(
    String title,
    String subtitle,
    String tag,
    Color colorStart,
    Color colorEnd,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorStart, colorEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorStart.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: -15,
              child: Icon(
                icon,
                size: 100,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      tag,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () =>
                        SupabaseDataService.navigationTabNotifier.value = 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Shop Now',
                            style: GoogleFonts.inter(
                              color: colorStart,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 13,
                            color: colorStart,
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
      ),
    );
  }

  // ── CATEGORY CHIP BAR ──────────────────────────────────────────────
  Widget _buildCategoryChipBar() {
    final chips = [
      {'label': 'Vegetables', 'cat': 'Vegetables'},
      {'label': 'Fruits', 'cat': 'Fruits'},
      {'label': 'Grains', 'cat': 'Grains'},
      {'label': 'Livestock', 'cat': 'Livestock'},
      {'label': 'Herbs', 'cat': 'Herbs'},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Text(
            'Shop by Type',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
              letterSpacing: -0.3,
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: chips.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final chip = chips[index];
              return GestureDetector(
                onTap: () {
                  SupabaseDataService.marketplaceCategoryNotifier.value =
                      chip['cat'];
                  SupabaseDataService.navigationTabNotifier.value = 1;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFD1FAE5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    chip['label']!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF065F46),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionMenu() {
    final actions = [
      {
        'icon': Icons.local_shipping_rounded,
        'label': 'Free\nShipping',
        'shortLabel': 'Free Shipping',
        'gradientStart': const Color(0xFF059669),
        'gradientEnd': const Color(0xFF10B981),
      },
      {
        'icon': Icons.card_giftcard_rounded,
        'label': 'My\nVouchers',
        'shortLabel': 'Vouchers',
        'gradientStart': const Color(0xFFD97706),
        'gradientEnd': const Color(0xFFF59E0B),
      },
      {
        'icon': Icons.inventory_2_rounded,
        'label': 'Whole\nsale',
        'shortLabel': 'Wholesale',
        'gradientStart': const Color(0xFF1D4ED8),
        'gradientEnd': const Color(0xFF3B82F6),
      },
      {
        'icon': Icons.eco_rounded,
        'label': 'Fresh\nProduce',
        'shortLabel': 'Fresh Produce',
        'gradientStart': const Color(0xFF0F766E),
        'gradientEnd': const Color(0xFF14B8A6),
      },
      {
        'icon': Icons.flash_on_rounded,
        'label': 'Flash\nSale',
        'shortLabel': 'Flash Sale',
        'gradientStart': const Color(0xFFB45309),
        'gradientEnd': const Color(0xFFF59E0B),
      },
      {
        'icon': Icons.storefront_rounded,
        'label': 'Local\nShops',
        'shortLabel': 'Local Shops',
        'gradientStart': const Color(0xFF6D28D9),
        'gradientEnd': const Color(0xFF8B5CF6),
      },
      {
        'icon': Icons.apps_rounded,
        'label': 'More\nServices',
        'shortLabel': 'More',
        'gradientStart': const Color(0xFF475569),
        'gradientEnd': const Color(0xFF64748B),
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 14),
            child: Row(
              children: [
                Text(
                  'Shop by Category',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.push(AppRoutes.marketplace),
                  child: Text(
                    'View All',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 14,
              crossAxisSpacing: 10,
              childAspectRatio: 0.78,
            ),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              final gradientStart = action['gradientStart'] as Color;
              final gradientEnd = action['gradientEnd'] as Color;
              return _QuickActionButton(
                icon: action['icon'] as IconData,
                label: action['label'] as String,
                gradientStart: gradientStart,
                gradientEnd: gradientEnd,
                onTap: () {
                  final shortLabel = action['shortLabel'] as String;
                  if (shortLabel == 'More') {
                    showMoreActionsBottomSheet(context);
                    return;
                  }
                  Widget? screen;
                  switch (shortLabel) {
                    case 'Free Shipping':
                      screen = const FreeShippingScreen();
                      break;
                    case 'Vouchers':
                      screen = const VouchersScreen();
                      break;
                    case 'Wholesale':
                      screen = const WholesaleScreen();
                      break;
                    case 'Fresh Produce':
                      screen = const FreshProduceScreen();
                      break;
                    case 'Flash Sale':
                      screen = const FlashSaleScreen();
                      break;
                    case 'Local Shops':
                      screen = const LocalShopsScreen();
                      break;
                    default:
                      screen = PromoActionScreen(
                        title: shortLabel,
                        icon: action['icon'] as IconData,
                        color: gradientStart,
                      );
                  }
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (context) => screen!));
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDailyDiscoveries() {
    return FutureBuilder<List<ProductItem>>(
      future: _dailyDiscoveriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final products = snapshot.data ?? [];
        if (products.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Daily Discoveries',
                    style: AppTextStyles.headline2.copyWith(fontSize: 22),
                  ),
                  GestureDetector(
                    onTap: () {
                      SupabaseDataService.navigationTabNotifier.value = 1;
                    },
                    child: Text(
                      'See All',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: products.length > 6 ? 6 : products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProductViewScreen(product: product),
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              child: CachedNetworkImage(
                                imageUrl: product.imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                placeholder: (context, url) =>
                                    const AppShimmerLoader(),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.error),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  product.price,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(
    String title,
    String action,
    VoidCallback onAction,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTextStyles.headline2.copyWith(fontSize: 22)),
          GestureDetector(
            onTap: onAction,
            child: Text(
              action,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF047857), Color(0xFF059669), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF064E3B).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: Location selector pill + Quick Actions (Messages, Alerts, Cart)
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showAddressPicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              color: Color(0xFFFDE047),
                              size: 16,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: RichText(
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Deliver to: ',
                                      style: GoogleFonts.inter(
                                        color: Colors.white.withValues(alpha: 0.85),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    TextSpan(
                                      text: _displayCity,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  StreamBuilder<int>(
                    stream: _unreadCountStream,
                    builder: (context, snapshot) {
                      return _buildCompactHeaderAction(
                        Icons.chat_bubble_outline_rounded,
                        (snapshot.data ?? 0) > 0,
                        () => context.push(AppRoutes.customerMessages),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildCompactHeaderNotification(context),
                  const SizedBox(width: 12),
                  _buildCompactHeaderCart(context),
                ],
              ),
              const SizedBox(height: 10),
              // Row 2: Full-width Hero Search Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF059669),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Search fresh vegetables, fruits, crops...',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF94A3B8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          height: 20,
                          width: 1,
                          color: const Color(0xFFE2E8F0),
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const QRScannerScreen(
                                  title: 'Scan QR / Product',
                                  instruction: 'Scan QR code to locate produce',
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.qr_code_scanner_rounded,
                              color: Color(0xFF059669),
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHeaderAction(
    IconData icon,
    bool hasNotification,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: Colors.white, size: 23),
          if (hasNotification)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF10B981),
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactHeaderNotification(BuildContext context) {
    final userId = AuthService().userId;
    return FutureBuilder<int>(
      future: NotificationService().getUnreadNotificationCount(userId),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return _buildCompactHeaderAction(
          Icons.notifications_none_rounded,
          count > 0,
          () => context.push(AppRoutes.notifications),
        );
      },
    );
  }

  Widget _buildCompactHeaderCart(BuildContext context) {
    return ListenableBuilder(
      listenable: CartService(),
      builder: (context, _) {
        final count = CartService().itemCount;
        return GestureDetector(
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const CartScreen())),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.shopping_cart_outlined,
                color: Colors.white,
                size: 23,
              ),
              if (count > 0)
                Positioned(
                  right: -7,
                  top: -7,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeaturedFarmersList(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _featuredFarmersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 344,
            child: Center(child: AppShimmerLoader()),
          );
        }

        final currentUserId = SupabaseConfig.currentUser?.id;
        final farmers = (snapshot.data ?? [])
            .where((f) => f['farmerUserId'] != currentUserId)
            .toList();

        if (farmers.isEmpty) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          height: 344,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: farmers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 20),
            itemBuilder: (_, index) {
              final f = farmers[index];
              return _buildFarmerCard(context, f);
            },
          ),
        );
      },
    );
  }

  Widget _buildFarmerCard(BuildContext context, Map<String, dynamic> f) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Hero(
                tag: 'farmer_${f['farmerId']}',
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  child: SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildFarmerImage(f['imageUrl']?.toString()),
                        // Premium Gradient Overlay
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.4),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        f['rating'] ?? '4.5',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppColors.textHeadline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Verified Badge
              if (f['badge'] == 'VERIFIED')
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f['name'] ?? 'Farmer Name',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textHeadline,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 14,
                      color: AppColors.primary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      f['distance'] ?? 'Nearby',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textSubtle,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textSubtle.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f['specialty'] ?? 'Fresh Produce',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.textSubtle,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.8),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => _showFarmerProfile(context, f),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'View Profile',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 0.2,
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
    );
  }

  Widget _buildCommunityFeed(BuildContext context) {
    return StreamBuilder<List<ForumPostItem>>(
      stream: _forumStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: AppShimmerLoader()),
          );
        }

        final List<ForumPostItem> posts =
            snapshot.data ?? const <ForumPostItem>[];
        if (posts.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: AppDecorations.cardDecoration.copyWith(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'No community posts yet. Be the first to share!',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSubtle,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final visiblePosts = posts.take(3).toList(growable: false);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              ...visiblePosts.map((post) => _buildCompactPostCard(post: post)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) => const CommunityStoriesScreen(),
                        ),
                      )
                      .then((_) {
                        if (mounted) setState(() {});
                      }),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.forum_outlined, size: 18),
                  label: Text(
                    'Join the Conversation',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFarmerImage(String? rawUrl) {
    return SafeNetworkImage(
      imageUrl: rawUrl,
      defaultBucket: 'uploads',
      width: double.infinity,
      height: 150,
      fit: BoxFit.cover,
      placeholder: _farmerImagePlaceholder(),
      errorWidget: _farmerImagePlaceholder(),
    );
  }

  Widget _farmerImagePlaceholder() {
    return Container(
      height: 150,
      width: double.infinity,
      color: AppColors.primary.withValues(alpha: 0.1),
      child: const Center(
        child: Icon(
          Icons.agriculture_rounded,
          size: 42,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildCompactPostCard({required ForumPostItem post}) {
    return InkWell(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => PostDetailScreen(post: post))),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: AppDecorations.cardDecoration.copyWith(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipOval(
              child: SafeCircleAvatar(
                imageUrl: post.authorAvatarUrl,
                radius: 20,
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          post.userName,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textHeadline,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        post.time,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSubtle,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.body,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textBody,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildPostAction(
                        post.isLiked
                            ? Icons.thumb_up_rounded
                            : Icons.thumb_up_alt_outlined,
                        post.likes.toString(),
                        isActive: post.isLiked,
                        onTap: () async {
                          await SupabaseDataService().togglePostLike(post.id);
                          if (mounted) setState(() {});
                        },
                      ),
                      const SizedBox(width: 16),
                      _buildPostAction(
                        Icons.chat_bubble_outline_rounded,
                        post.comments.toString(),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PostDetailScreen(post: post),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(left: 12),
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  image: DecorationImage(
                    image: CachedNetworkImageProvider(post.imageUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostAction(
    IconData icon,
    String count, {
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    final color = isActive ? AppColors.primary : AppColors.textSubtle;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              count,
              style: AppTextStyles.labelSmall.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ Farmer Profile Bottom Sheet ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬
  void _showFarmerProfile(BuildContext context, Map<String, dynamic> f) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => FarmerPublicProfileScreen(farmer: f),
          ),
        )
        .then((_) {
          if (mounted) setState(() {});
        });
  }

  // ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ Address Picker Bottom Sheet ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬
  void _showAddressPicker(BuildContext context) async {
    final addresses = await UserService().getAllUserAddresses();
    if (!mounted) return;

    showModalBottomSheet(
      context: this.context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSubtle.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Deliver To',
              style: AppTextStyles.headline2.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 16),
            if (addresses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(
                      Icons.location_off_rounded,
                      size: 48,
                      color: AppColors.textSubtle.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No saved addresses',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textSubtle,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.push(AppRoutes.myDetails);
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Address'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: addresses.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final addr = addresses[i];
                    final isSelected =
                        _defaultAddress?.addressId == addr.addressId;
                    return InkWell(
                      onTap: () async {
                        await UserService().setDefaultAddress(addr.addressId);
                        if (mounted) {
                          setState(() => _defaultAddress = addr);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.06)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textHeadline.withValues(
                                    alpha: 0.08,
                                  ),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                addr.label.toLowerCase() == 'home'
                                    ? Icons.home_rounded
                                    : Icons.work_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        addr.label,
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      if (addr.isDefault) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            'Default',
                                            style: AppTextStyles.labelSmall
                                                .copyWith(
                                                  color: AppColors.primary,
                                                  fontSize: 10,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${addr.barangay}, ${addr.city}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSubtle,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (addresses.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push(AppRoutes.addressBook);
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Manage Addresses'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Quick Action Button Ã¢â‚¬â€ premium animated widget
// -----------------------------------------------------------------------------
class _QuickActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color gradientStart;
  final Color gradientEnd;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.gradientStart,
    required this.gradientEnd,
    required this.onTap,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.90,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [widget.gradientStart, widget.gradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: widget.gradientStart.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(widget.icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 7),
            Text(
              widget.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF334155),
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
