import 'package:flutter/material.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/services/user/user_service.dart';
import '../../../shared/models/auth/user_address_model.dart';
import '../../../shared/widgets/image_widgets.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/screens/post_detail_screen.dart';
import '../../../shared/services/community/message_service.dart';

import 'farmer_public_profile_screen.dart';
import 'community_stories_screen.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/widgets/farmer/farmer_mode_switcher_capsule.dart';
import 'home/widgets/ecom_sliver_app_bar.dart';
import 'home/widgets/ecom_hero_banner.dart';
import 'home/widgets/ecom_quick_channels.dart';
import 'home/widgets/ecom_flash_sale_section.dart';
import 'home/widgets/ecom_product_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late Future<List<Map<String, dynamic>>> _featuredFarmersFuture =
      SupabaseDataService().getFeaturedFarmers();
  UserAddress? _defaultAddress;
  bool _addressLoaded = false;

  late Stream<List<ForumPostItem>> _forumStream;
  late Stream<int> _unreadCountStream;

  late Future<List<ProductItem>> _dailyDiscoveriesFuture;
  late Future<List<ProductItem>> _flashSaleProductsFuture;
  Position? _userPosition;

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
    _loadUserPosition();
  }

  Future<void> _loadUserPosition() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (mounted && pos != null) {
        setState(() => _userPosition = pos);
      }
    } catch (_) {}
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
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          setState(() {
            _dailyDiscoveriesFuture = SupabaseDataService().getNearbyProducts();
            _featuredFarmersFuture = SupabaseDataService().getFeaturedFarmers();
            _flashSaleProductsFuture =
                SupabaseDataService().getFlashSaleProducts();
          });
          await Future.wait([
            _loadDefaultAddress(),
            _loadUserPosition(),
          ]);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            EcomSliverAppBar(
              displayCity: _displayCity,
              onLocationTap: () => _showAddressPicker(context),
              unreadMessagesStream: _unreadCountStream,
            ),
            if (AuthService().isSeller)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: FarmerModeSwitcherCapsule(
                    onSwitch: () {
                      AuthService().switchToFarmerMode();
                      context.go(AppRoutes.farmerDashboard);
                    },
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 6)),
            const SliverToBoxAdapter(child: EcomHeroBanner()),
            const SliverToBoxAdapter(child: EcomQuickChannels()),
            SliverToBoxAdapter(
              child: FutureBuilder<List<ProductItem>>(
                future: _flashSaleProductsFuture,
                builder: (context, snapshot) {
                  final products = snapshot.data ?? [];
                  return EcomFlashSaleSection(flashProducts: products);
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildSectionHeader(
                    'Featured Farmers',
                    'Map View',
                    () => context.push(AppRoutes.farmersMap),
                  ),
                  _buildFeaturedFarmersList(context),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'DAILY DISCOVERIES',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        SupabaseDataService.navigationTabNotifier.value = 1;
                      },
                      child: Text(
                        'See All',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildDailyDiscoveriesSliver(),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
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
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyDiscoveriesSliver() {
    return FutureBuilder<List<ProductItem>>(
      future: _dailyDiscoveriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(child: AppShimmerLoader()),
                ),
                childCount: 4,
              ),
            ),
          );
        }

        final products = snapshot.data ?? [];
        if (products.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final product = products[index];
                return EcomProductCard(
                  key: ValueKey('home_prod_${product.productId ?? index}'),
                  product: product,
                  userPosition: _userPosition,
                );
              },
              childCount: products.length,
            ),
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
