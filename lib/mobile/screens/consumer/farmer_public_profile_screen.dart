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

  Map<String, dynamic> get f => widget.farmer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _calculateDistance();
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

  bool _isValidUrl(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return false;
    final uri = Uri.tryParse(text);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  Widget _imagePlaceholder() {
    return Container(color: AppColors.primaryLight, child: const Center(child: Icon(Icons.store, size: 48, color: Colors.white)));
  }

  Widget _buildStat(IconData icon, String value, String label, Color iconColor) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textHeadline,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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
        height: 30,
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
          _buildCombinedAppBar(context),
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

  SliverAppBar _buildCombinedAppBar(BuildContext context) {
    final imageUrl = f['imageUrl']?.toString();
    return SliverAppBar(
      expandedHeight: 460,
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
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        stretchModes: const [StretchMode.zoomBackground],
        background: Column(
          children: [
            // Image Section
            SizedBox(
              height: 240,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_isValidUrl(imageUrl))
                    Hero(
                      tag: 'farmer_${f['farmerId']}',
                      child: CachedNetworkImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => _imagePlaceholder(),
                      ),
                    )
                  else
                    _imagePlaceholder(),
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
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Profile Info Section (Inside FlexibleSpace to scroll)
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            f['name'] ?? 'Farm',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 26,
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
                              size: 22, color: AppColors.secondary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        f['specialty'] ?? 'Fresh Produce',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Stats Row
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStat(Icons.star_rounded, f['rating'] ?? '0.0', 'Rating', AppColors.accent),
                          _buildDivider(),
                          _buildStat(Icons.location_on_rounded, _calculatedDistance, 'Distance', AppColors.primary),
                          _buildDivider(),
                          _buildStat(Icons.shopping_bag_rounded, 'Active', 'Status', AppColors.secondary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSubtle,
            indicatorColor: AppColors.primary,
            indicatorWeight: 4,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
            unselectedLabelStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            tabs: const [
              Tab(text: 'Products'),
              Tab(text: 'Posts'),
            ],
          ),
        ),
      ),
    );
  }

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
                      product.farm,
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
