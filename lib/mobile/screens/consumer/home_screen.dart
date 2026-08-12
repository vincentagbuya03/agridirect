import 'package:flutter/material.dart';
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
import '../../../shared/services/social/follow_service.dart';
import 'marketplace_screen.dart';
import '../../../shared/services/community/notification_service.dart';
import '../../../shared/services/community/message_service.dart';
import '../../../shared/services/auth/auth_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../shared/widgets/forum_video_player.dart';
import 'promo_action_screen.dart';
import 'free_shipping_screen.dart';
import 'vouchers_screen.dart';
import 'agrimall_screen.dart';
import 'wholesale_screen.dart';
import 'fresh_produce_screen.dart';
import 'flash_sale_screen.dart';
import 'local_shops_screen.dart';
import 'more_actions_bottom_sheet.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserAddress? _defaultAddress;
  bool _addressLoaded = false;
  final FollowService _followService = FollowService();
  late Stream<List<ForumPostItem>> _forumStream;
  late Stream<int> _unreadCountStream;
  late Future<Map<String, dynamic>> _followingHomeDataFuture;
  late Future<List<CategoryItem>> _categoriesFuture;
  late Future<List<ProductItem>> _dailyDiscoveriesFuture;



  @override
  void initState() {
    super.initState();
    _forumStream = SupabaseDataService().watchForumPosts();
    _unreadCountStream = MessageService().watchTotalUnreadCount(
      asFarmer: false,
    );
    _followingHomeDataFuture = _loadFollowingHomeData();
    _categoriesFuture = SupabaseDataService().getCategories();
    _dailyDiscoveriesFuture = SupabaseDataService().getNearbyProducts();
    _loadDefaultAddress();
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

  String get _displayCity {
    if (!_addressLoaded) return 'Loading...';
    return _defaultAddress?.city ?? 'Set Location';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildPremiumHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  _buildPromoBannerCarousel(),
                  _buildQuickActionMenu(),
                  _buildFollowingUpdatesSection(),
                  _buildSectionHeader('Browse Categories', 'Show all', () {
                    SupabaseDataService.navigationTabNotifier.value = 1;
                    SupabaseDataService.marketplaceCategoryNotifier.value =
                        null;
                  }),
                  _buildCategoryGrid(),
                  const SizedBox(height: 32),
                  _buildDailyDiscoveries(),
                  const SizedBox(height: 32),
                  _buildSectionHeader(
                    'Featured Farmers',
                    'Map View',
                    () => context.push(AppRoutes.farmersMap),
                  ),
                  _buildFeaturedFarmersList(context),
                  const SizedBox(height: 32),
                  _buildSectionHeader('Community Stories', 'See All', () {
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
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoBannerCarousel() {
    return Container(
      height: 180,
      margin: const EdgeInsets.only(bottom: 24),
      child: PageView(
        children: [
          _buildPromoBanner('Fresh Produce Sale', 'Up to 30% Off', const Color(0xFF10B981)),
          _buildPromoBanner('Free Delivery', 'On orders over ₱500', const Color(0xFFF59E0B)),
          _buildPromoBanner('Support Local', 'Buy directly from farmers', const Color(0xFF3B82F6)),
        ],
      ),
    );
  }

  Widget _buildPromoBanner(String title, String subtitle, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Shop Now',
                    style: GoogleFonts.inter(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Icon(
            Icons.shopping_bag_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionMenu() {
    final actions = [
      {'icon': Icons.local_shipping_rounded, 'label': 'Free Shipping', 'color': Colors.green},
      {'icon': Icons.card_giftcard_rounded, 'label': 'Vouchers', 'color': Colors.orange},
      {'icon': Icons.agriculture_rounded, 'label': 'AgriMall', 'color': Colors.red},
      {'icon': Icons.inventory_2_rounded, 'label': 'Wholesale', 'color': Colors.blue},
      {'icon': Icons.eco_rounded, 'label': 'Fresh Produce', 'color': Colors.teal},
      {'icon': Icons.flash_on_rounded, 'label': 'Flash Sale', 'color': Colors.amber},
      {'icon': Icons.storefront_rounded, 'label': 'Local Shops', 'color': Colors.purple},
      {'icon': Icons.more_horiz_rounded, 'label': 'More', 'color': Colors.grey},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final action = actions[index];
          return InkWell(
            onTap: () {
              final label = action['label'] as String;
              if (label == 'More') {
                showMoreActionsBottomSheet(context);
                return;
              }
              
              Widget? screen;
              switch (label) {
                case 'Free Shipping':
                  screen = const FreeShippingScreen();
                  break;
                case 'Vouchers':
                  screen = const VouchersScreen();
                  break;
                case 'AgriMall':
                  screen = const AgriMallScreen();
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
                    title: label,
                    icon: action['icon'] as IconData,
                    color: action['color'] as Color,
                  );
              }

              if (screen != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => screen!),
                );
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (action['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(action['icon'] as IconData, color: action['color'] as Color, size: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  action['label'] as String,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600),
                  maxLines: 2,
                ),
              ],
            ),
          );
        },
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
                  Text('Daily Discoveries', style: AppTextStyles.headline2.copyWith(fontSize: 22)),
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
                      MaterialPageRoute(builder: (_) => ProductViewScreen(product: product)),
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
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: CachedNetworkImage(
                                imageUrl: product.imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                placeholder: (context, url) => const AppShimmerLoader(),
                                errorWidget: (context, url, error) => const Icon(Icons.error),
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
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  product.price,
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
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
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.textHeadline.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showAddressPicker(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DELIVERING TO',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _displayCity,
                                  style: AppTextStyles.headline3.copyWith(
                                    fontSize: 18,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 20,
                                color: AppColors.textHeadline,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 12,
                  ), // Ensure spacing between address and actions
                  Row(
                    children: [
                      StreamBuilder<int>(
                        stream: _unreadCountStream,
                        builder: (context, snapshot) {
                          final unreadMessages = snapshot.data ?? 0;
                          return _buildHeaderAction(
                            context,
                            Icons.chat_bubble_outline_rounded,
                            unreadMessages > 0,
                            () => context.push(AppRoutes.customerMessages),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildHeaderNotification(context),
                      const SizedBox(width: 8),
                      _buildCartAction(context),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.textHeadline.withValues(alpha: 0.1),
                        ),
                      ),
                      child: TextField(
                        readOnly: true,
                        onTap: () {
                          SupabaseDataService
                                  .marketplaceCategoryNotifier
                                  .value =
                              null;
                          SupabaseDataService.navigationTabNotifier.value = 1;
                        },
                        decoration: InputDecoration(
                          hintText: 'Search fresh produce...',
                          hintStyle: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSubtle,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.textSubtle,
                            size: 22,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () {
                      SupabaseDataService.marketplaceCategoryNotifier.value =
                          null;
                      SupabaseDataService.navigationTabNotifier.value = 1;
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 52,
                      width: 52,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderAction(
    BuildContext context,
    IconData icon,
    bool hasNotification,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.textHeadline.withValues(alpha: 0.1),
          ),
        ),
        child: Stack(
          children: [
            Icon(icon, color: AppColors.textHeadline, size: 24),
            if (hasNotification)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartAction(BuildContext context) {
    return ListenableBuilder(
      listenable: CartService(),
      builder: (context, _) {
        final count = CartService().itemCount;
        return InkWell(
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const CartScreen())),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.textHeadline.withValues(alpha: 0.1),
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.shopping_cart_outlined,
                  color: AppColors.textHeadline,
                  size: 24,
                ),
                if (count > 0)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
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
          ),
        );
      },
    );
  }

  Widget _buildHeaderNotification(BuildContext context) {
    final userId = AuthService().userId;
    return FutureBuilder<int>(
      future: NotificationService().getUnreadNotificationCount(userId),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return GestureDetector(
          onTap: () => context.push(AppRoutes.notifications),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.textHeadline.withValues(alpha: 0.1),
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.textHeadline,
                  size: 24,
                ),
                if (count > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
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


  Future<Map<String, dynamic>> _loadFollowingHomeData() async {
    final results = await Future.wait<dynamic>([
      _followService.getFollowingCount(),
      _followService.getFollowingUpdates(limit: 6),
    ]);

    return {
      'count': results[0] as int,
      'updates': results[1] as List<Map<String, dynamic>>,
    };
  }

  Widget _buildFollowingUpdatesSection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _followingHomeDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              height: 160,
              child: Center(child: AppShimmerLoader()),
            ),
          );
        }

        final count = snapshot.data?['count'] as int? ?? 0;
        final updates =
            snapshot.data?['updates'] as List<Map<String, dynamic>>? ??
            const <Map<String, dynamic>>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'Following Updates',
              count > 0 ? '$count farms' : 'Discover',
              () => context.push(AppRoutes.farmersMap),
            ),
            if (count == 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: AppDecorations.cardDecoration.copyWith(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Follow farmers to get product launches and community posts in one place.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textHeadline,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => context.push(AppRoutes.farmersMap),
                        child: const Text('Find Farmers'),
                      ),
                    ],
                  ),
                ),
              )
            else if (updates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: AppDecorations.cardDecoration.copyWith(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    'You are following $count farms. New updates will appear here once they post.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSubtle,
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                height: 290,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: updates.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 16),
                  itemBuilder: (_, index) =>
                      _buildFollowingUpdateCard(updates[index]),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFollowingUpdateCard(Map<String, dynamic> update) {
    final isProduct = update['type'] == 'product';
    final imageUrl = (update['imageUrl']?.toString() ?? '').trim();
    final createdAt = update['createdAt'] as DateTime?;

    return InkWell(
      onTap: () => _openFollowingUpdate(update),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 290,
        decoration: AppDecorations.cardDecoration.copyWith(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: SizedBox(
                height: 108,
                width: double.infinity,
                child: imageUrl.isEmpty
                    ? Container(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        child: Icon(
                          isProduct
                              ? Icons.inventory_2_rounded
                              : Icons.campaign_rounded,
                          color: AppColors.primary,
                          size: 34,
                        ),
                      )
                    : SafeNetworkImage(
                        imageUrl: imageUrl,
                        defaultBucket: 'uploads',
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isProduct
                            ? AppColors.secondary.withValues(alpha: 0.12)
                            : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isProduct ? 'NEW PRODUCT' : 'NEW POST',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: isProduct
                              ? AppColors.secondary
                              : AppColors.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      update['farmerName']?.toString() ?? 'Farm',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSubtle,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      update['title']?.toString().trim().isNotEmpty == true
                          ? update['title'].toString()
                          : 'Fresh update',
                      style: AppTextStyles.headline3.copyWith(fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isProduct
                          ? '${update['subtitle'] ?? 'Fresh produce'}${update['isPreorder'] == true ? ' • Pre-order' : ''}'
                          : (update['body']?.toString() ?? ''),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSubtle,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        if (isProduct && update['price'] != null)
                          Text(
                            'PHP ${(update['price'] as num).toStringAsFixed(2)}',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        else
                          Text(
                            _formatRelativeTime(createdAt),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textSubtle,
                            ),
                          ),
                        const Spacer(),
                        Text(
                          'Open',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFollowingUpdate(Map<String, dynamic> update) async {
    if (update['type'] == 'product') {
      final productId = update['productId']?.toString() ?? '';
      if (productId.isEmpty) return;
      final product = await SupabaseDataService().getProductById(productId);
      if (!mounted) return;
      if (product == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This product is no longer available.')),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductViewScreen(product: product)),
      );
      if (mounted) {
        setState(() {
          _followingHomeDataFuture = _loadFollowingHomeData();
        });
      }
      return;
    }

    final post = ForumPostItem(
      id: update['postId']?.toString() ?? '',
      userId: update['farmerUserId']?.toString(),
      userName: update['farmerName']?.toString() ?? 'Farmer',
      time: _formatRelativeTime(update['createdAt'] as DateTime?),
      title: update['title']?.toString() ?? '',
      body: update['body']?.toString() ?? '',
      imageUrl: update['imageUrl']?.toString(),
      videoUrl: update['videoUrl']?.toString(),
      likes: update['likes'] as int? ?? 0,
      comments: update['comments'] as int? ?? 0,
      isLiked: false,
    );

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)));
    if (mounted) {
      setState(() {
        _followingHomeDataFuture = _loadFollowingHomeData();
      });
    }
  }

  String _formatRelativeTime(DateTime? dateTime) {
    if (dateTime == null) return 'Just now';

    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  Widget _buildCategoryGrid() {
    return FutureBuilder<List<CategoryItem>>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 110,
            child: Center(child: AppShimmerLoader()),
          );
        }

        final categories = snapshot.data ?? [];
        if (categories.isEmpty) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 80,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final cat = categories[i];
              return GestureDetector(
                onTap: () {
                  // 1. Set the global category filter
                  SupabaseDataService.marketplaceCategoryNotifier.value =
                      cat.name;
                  // 2. Switch to the Marketplace tab (Index 1 in MobileNavigation)
                  SupabaseDataService.navigationTabNotifier.value = 1;
                },
                child: Container(
                  width: 130,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Color(cat.bgColor).withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(cat.bgColor).withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Color(cat.iconColor),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          cat.name,
                          style: AppTextStyles.labelSmall.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textHeadline,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFeaturedFarmersList(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseDataService().getFeaturedFarmers(),
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
                'No community stories available yet.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSubtle,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final List<ForumPostItem> visiblePosts = posts
            .take(2)
            .toList(growable: false);

        return Column(
          children: [
            ...visiblePosts.map(
              (ForumPostItem post) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _buildCommunityPostCard(post: post),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: InkWell(
                onTap: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) => const CommunityStoriesScreen(),
                        ),
                      )
                      .then((_) {
                        if (mounted) setState(() {});
                      });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.people_outline_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'VIEW COMMUNITY STORIES',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
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

  Widget _buildCommunityPostCard({required ForumPostItem post}) {
    return InkWell(
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)));
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: AppDecorations.cardDecoration.copyWith(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: SafeCircleAvatar(
                      imageUrl: post.authorAvatarUrl,
                      radius: 22,
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userName,
                        style: AppTextStyles.headline3.copyWith(fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${post.title.isEmpty ? 'Farmer' : post.title} • ${post.time}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSubtle,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              post.body,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textHeadline.withValues(alpha: 0.9),
                height: 1.5,
              ),
            ),
            if (post.videoUrl != null && post.videoUrl!.isNotEmpty) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ForumVideoPlayer(videoUrl: post.videoUrl!),
              ),
            ] else if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: post.imageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const SizedBox(
                    height: 200,
                    child: Center(child: AppShimmerLoader()),
                  ),
                  errorWidget: (context, url, error) => const SizedBox.shrink(),
                ),
              ),
            ],
            const SizedBox(height: 16),
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
                const SizedBox(width: 20),
                _buildPostAction(
                  Icons.chat_bubble_outline_rounded,
                  post.comments.toString(),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PostDetailScreen(post: post),
                      ),
                    );
                  },
                ),
                const Spacer(),
                const Icon(
                  Icons.share_outlined,
                  size: 20,
                  color: AppColors.textSubtle,
                ),
              ],
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

  // ── Farmer Profile Bottom Sheet ──
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

  // ── Address Picker Bottom Sheet ──
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
