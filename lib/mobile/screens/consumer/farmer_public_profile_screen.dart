import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/services/commerce/cart_service.dart';
import 'package:geolocator/geolocator.dart';
import 'marketplace_screen.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/social/follow_service.dart';
import '../../../shared/widgets/image_widgets.dart';

/// Full-screen public profile for a farmer, with Products & Posts tabs.
class FarmerPublicProfileScreen extends StatefulWidget {
  final Map<String, dynamic> farmer;

  const FarmerPublicProfileScreen({super.key, required this.farmer});

  @override
  State<FarmerPublicProfileScreen> createState() =>
      _FarmerPublicProfileScreenState();
}

class _FarmerPublicProfileScreenState extends State<FarmerPublicProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _calculatedDistance = 'Nearby';
  final FollowService _followService = FollowService();
  bool _isFollowing = false;
  bool _isFollowBusy = false;
  int _followerCount = 0;
  int _followingCount = 0;

  Map<String, dynamic> get f => widget.farmer;
  bool get _isOwnProfile =>
      AuthService().userId.isNotEmpty &&
      AuthService().userId == (f['farmerUserId']?.toString() ?? '');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _calculateDistance();
    _loadFollowState();
  }

  Future<void> _loadFollowState() async {
    final farmerId = f['farmerId']?.toString() ?? '';
    if (farmerId.isEmpty || _isOwnProfile) return;

    try {
      final state = await _followService.getFollowState(farmerId);
      if (!mounted) return;
      setState(() {
        _isFollowing = state['isFollowing'] as bool? ?? false;
        _followerCount = state['followers'] as int? ?? 0;
        _followingCount = state['following'] as int? ?? 0;
      });
    } catch (e) {
      debugPrint('Error loading follow state: $e');
    }
  }

  Future<void> _toggleFollow() async {
    if (_isFollowBusy || _isOwnProfile) return;

    final farmerId = f['farmerId']?.toString() ?? '';
    if (farmerId.isEmpty) return;

    setState(() => _isFollowBusy = true);
    try {
      final isNowFollowing = await _followService.toggleFollowFarmer(
        farmerId: farmerId,
        farmerUserId: f['farmerUserId']?.toString(),
        farmName: f['name']?.toString(),
      );
      if (!mounted) return;

      setState(() {
        _isFollowing = isNowFollowing;
        _followerCount += isNowFollowing ? 1 : -1;
        if (_followerCount < 0) _followerCount = 0;
        _followingCount += isNowFollowing ? 1 : -1;
        if (_followingCount < 0) _followingCount = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNowFollowing
                ? 'You are now following ${f['name'] ?? 'this farm'}.'
                : 'Unfollowed ${f['name'] ?? 'this farm'}.',
          ),
          backgroundColor:
              isNowFollowing ? AppColors.success : AppColors.textHeadline,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isFollowBusy = false);
      }
    }
  }

  Future<void> _calculateDistance() async {
    try {
      final double? farmLat = f['latitude'] as double?;
      final double? farmLon = f['longitude'] as double?;

      if (farmLat == null || farmLon == null) return;

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      
      if (permission == LocationPermission.deniedForever) return;

      final Position position = await Geolocator.getCurrentPosition();
      
      final double distanceInMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        farmLat,
        farmLon,
      );

      if (mounted) {
        setState(() {
          if (distanceInMeters < 1000) {
            _calculatedDistance = '${distanceInMeters.toStringAsFixed(0)}m';
          } else {
            _calculatedDistance = '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
          }
        });
      }
    } catch (e) {
      debugPrint('Error calculating distance: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _imagePlaceholder() {
    return Container(
      color: AppColors.primaryLight,
      child: const Center(
        child: Icon(
          Icons.agriculture_rounded,
          size: 48,
          color: AppColors.primary,
        ),
      ),
    );
  }


  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'F';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length > 1 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Widget _buildStat(IconData icon, String value, String label, Color iconColor) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textHeadline,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSubtle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() => Container(
        width: 1,
        height: 32,
        color: AppColors.textSubtle.withValues(alpha: 0.1),
      );

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 56, color: AppColors.textSubtle.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(title,
                style: AppTextStyles.headline3
                    .copyWith(color: AppColors.textHeadline)),
            const SizedBox(height: 8),
            Text(subtitle,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSubtle),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(context, innerBoxIsScrolled),
          _buildProfileCard(context),
          _buildTabBarHeader(context),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _ProductsTab(farmerId: f['farmerId']?.toString() ?? ''),
            _PostsTab(farmerUserId: f['farmerUserId']?.toString() ?? ''),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(BuildContext context, bool innerBoxIsScrolled) {
    final imageUrl = f['imageUrl']?.toString();
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.primary,
      elevation: 0,
      leadingWidth: 70,
      leading: Center(
        child: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: Colors.white),
          ),
        ),
      ),
      actions: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              onPressed: () {
                final farmerId = f['farmerId']?.toString();
                if (farmerId != null) {
                  context.push(AppRoutes.customerMessages,
                      extra: {'farmerId': farmerId});
                }
              },
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chat_bubble_outline_rounded,
                    size: 18, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
      title: AnimatedOpacity(
        opacity: innerBoxIsScrolled ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Text(
          _titleCase(f['name'] ?? 'Farm'),
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ),
      centerTitle: true,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'farmer_${f['farmerId']}',
              child: SafeNetworkImage(
                imageUrl: imageUrl,
                defaultBucket: 'uploads',
                fit: BoxFit.cover,
                placeholder: _imagePlaceholder(),
                errorWidget: _imagePlaceholder(),
              ),
            ),
            // Premium Gradient Overlay
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.5, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          children: [
            // Centered Avatar
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF1F5F9), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  _getInitials(f['name'] ?? 'Farm'),
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    _titleCase(f['name'] ?? 'Farm'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textHeadline,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (f['badge'] == 'VERIFIED') ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.verified_rounded,
                      size: 20, color: AppColors.secondary),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Text(
                _titleCase(f['specialty'] ?? 'Fresh Produce'),
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            if (!_isOwnProfile) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _isFollowBusy ? null : _toggleFollow,
                        style: FilledButton.styleFrom(
                          backgroundColor: _isFollowing
                              ? Colors.white
                              : AppColors.primary,
                          foregroundColor: _isFollowing
                              ? AppColors.textHeadline
                              : Colors.white,
                          side: BorderSide(
                            color: _isFollowing
                                ? AppColors.textSubtle.withValues(alpha: 0.2)
                                : AppColors.primary,
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        icon: _isFollowBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                            : Icon(
                                _isFollowing
                                    ? Icons.check_rounded
                                    : Icons.person_add_alt_1_rounded,
                                size: 18,
                              ),
                        label: Text(
                          _isFollowing ? 'Following' : 'Follow Farm',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      onPressed: () {
                        final farmerId = f['farmerId']?.toString();
                        if (farmerId != null) {
                          context.push(AppRoutes.customerMessages,
                              extra: {'farmerId': farmerId});
                        }
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            // Stats Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildStat(Icons.star_rounded, f['rating']?.toString() ?? '0.0', 'Rating', AppColors.accent),
                  _buildDivider(),
                  _buildStat(Icons.location_on_rounded, _calculatedDistance, 'Distance', AppColors.primary),
                  _buildDivider(),
                  _buildStat(
                    Icons.group_rounded,
                    _followerCount.toString(),
                    'Followers',
                    AppColors.secondary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBarHeader(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverTabBarDelegate(
        child: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSubtle,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
              unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Products'),
                Tab(text: 'Posts'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final PreferredSize child;

  _SliverTabBarDelegate({required this.child});

  @override
  double get minExtent => child.preferredSize.height;

  @override
  double get maxExtent => child.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) {
    return oldDelegate.child != child;
  }

}

String _titleCase(String text) {
  if (text.isEmpty) return text;
  return text.split(' ').map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

// ── Products Tab ──
class _ProductsTab extends StatelessWidget {
  final String farmerId;
  const _ProductsTab({required this.farmerId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductItem>>(
      future: SupabaseDataService().getProductsByFarmerId(farmerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final products = snapshot.data ?? [];
        if (products.isEmpty) {
          return (context.findAncestorStateOfType<_FarmerPublicProfileScreenState>()!)
              ._emptyState(
            Icons.storefront_rounded,
            'No Products Yet',
            'This farmer hasn\'t listed any products.',
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(20),
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.65,
          ),
          itemCount: products.length,
          itemBuilder: (_, i) => _buildProductCard(context, products[i]),
        );
      },
    );
  }

  Widget _buildProductCard(BuildContext context, ProductItem product) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => ProductViewScreen(product: product)),
        );
      },
      child: Container(
        decoration: AppDecorations.cardDecoration.copyWith(
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
              child: CachedNetworkImage(
                imageUrl: product.imageUrl,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => Container(
                  height: 120,
                  color: AppColors.primaryLight,
                  child: const Center(
                    child: Icon(Icons.image_outlined,
                        size: 32, color: AppColors.primary),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: AppTextStyles.headline3.copyWith(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _titleCase(product.farm),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSubtle,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.price,
                              style: AppTextStyles.headline3.copyWith(
                                color: AppColors.primary,
                                fontSize: 16,
                              ),
                            ),
                            if (product.unit.isNotEmpty)
                              Text(
                                product.unit,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSubtle,
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                        if (AuthService().userId.isEmpty || product.farmerId != AuthService().userId)
                          GestureDetector(
                            onTap: () {
                              CartService().addItem(product);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('${product.name} added to cart'),
                                  duration: const Duration(seconds: 1),
                                  backgroundColor: AppColors.primary,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppColors.primary.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.add_shopping_cart_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
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
}

// ── Posts Tab ──
class _PostsTab extends StatelessWidget {
  final String farmerUserId;
  const _PostsTab({required this.farmerUserId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ForumPostItem>>(
      future: SupabaseDataService().getForumPostsByUserId(farmerUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return (context.findAncestorStateOfType<_FarmerPublicProfileScreenState>()!)
              ._emptyState(
            Icons.article_outlined,
            'No Posts Yet',
            'This farmer hasn\'t shared any posts.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          physics: const BouncingScrollPhysics(),
          itemCount: posts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (_, i) => _buildPostCard(posts[i]),
        );
      },
    );
  }

  Widget _buildPostCard(ForumPostItem post) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.userName,
                      style: AppTextStyles.headline3.copyWith(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      post.time,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSubtle, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (post.title.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              post.title,
              style: AppTextStyles.headline3.copyWith(fontSize: 16),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Text(
            post.body,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textHeadline.withValues(alpha: 0.85),
              height: 1.5,
            ),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CachedNetworkImage(
                imageUrl: post.imageUrl!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Engagement row
          Row(
            children: [
              Icon(
                post.isLiked
                    ? Icons.thumb_up_alt_rounded
                    : Icons.thumb_up_alt_outlined,
                size: 18,
                color:
                    post.isLiked ? AppColors.primary : AppColors.textSubtle,
              ),
              const SizedBox(width: 6),
              Text(
                '${post.likes}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSubtle,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 20),
              const Icon(Icons.chat_bubble_outline_rounded,
                  size: 18, color: AppColors.textSubtle),
              const SizedBox(width: 6),
              Text(
                '${post.comments}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSubtle,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
