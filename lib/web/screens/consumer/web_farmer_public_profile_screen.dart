import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/commerce/cart_service.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/services/social/follow_service.dart';
import '../../../shared/widgets/image_widgets.dart';
import '../../widgets/web_consumer_nav_bar.dart';

class WebFarmerPublicProfileScreen extends StatefulWidget {
  final String farmerId;

  const WebFarmerPublicProfileScreen({super.key, required this.farmerId});

  @override
  State<WebFarmerPublicProfileScreen> createState() =>
      _WebFarmerPublicProfileScreenState();
}

class _WebFarmerPublicProfileScreenState
    extends State<WebFarmerPublicProfileScreen>
    with TickerProviderStateMixin {
  static const Color _primary = Color(0xFF16A34A);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);
  static const Color _white = Colors.white;

  late final Future<Map<String, dynamic>?> _profileFuture;
  late final TabController _tabController;
  final _followService = FollowService();

  bool _isFollowing = false;
  bool _isFollowBusy = false;
  int _followerCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _profileFuture = SupabaseDataService().getFarmerProfileByFarmerId(
      widget.farmerId,
    );
    _profileFuture.then((profile) {
      if (profile != null && mounted) {
        _loadFollowState(profile);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isOwnProfile(Map<String, dynamic> farmer) =>
      AuthService().userId.isNotEmpty &&
      AuthService().userId == (farmer['user_id']?.toString() ?? '');

  Future<void> _loadFollowState(Map<String, dynamic> farmer) async {
    if (_isOwnProfile(farmer)) return;

    final state = await _followService.getFollowState(widget.farmerId);
    if (!mounted) return;
    setState(() {
      _isFollowing = state['isFollowing'] as bool? ?? false;
      _followerCount = state['followers'] as int? ?? 0;
    });
  }

  Future<void> _toggleFollow(Map<String, dynamic> farmer) async {
    if (_isFollowBusy || _isOwnProfile(farmer)) return;

    setState(() => _isFollowBusy = true);
    try {
      final isNowFollowing = await _followService.toggleFollowFarmer(
        farmerId: widget.farmerId,
        farmerUserId: farmer['user_id']?.toString(),
        farmName: _farmName(farmer),
      );
      if (!mounted) return;

      setState(() {
        _isFollowing = isNowFollowing;
        _followerCount += isNowFollowing ? 1 : -1;
        if (_followerCount < 0) _followerCount = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNowFollowing
                ? 'You are now following ${_farmName(farmer)}.'
                : 'Unfollowed ${_farmName(farmer)}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isFollowBusy = false);
      }
    }
  }

  void _handleNav(int index) {
    context.go(AppRoutes.webTabRoute(index));
  }

  String _farmName(Map<String, dynamic> farmer) =>
      farmer['farm_name']?.toString().trim().isNotEmpty == true
      ? farmer['farm_name'].toString()
      : (farmer['farmer_name']?.toString().trim().isNotEmpty == true
            ? farmer['farmer_name'].toString()
            : 'Farm');

  String _specialty(Map<String, dynamic> farmer) =>
      farmer['specialty']?.toString().trim().isNotEmpty == true
      ? farmer['specialty'].toString()
      : 'Fresh produce';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _primary),
            );
          }

          final farmer = snapshot.data;
          if (farmer == null) {
            return Center(
              child: Text(
                'Farmer profile not found.',
                style: GoogleFonts.inter(fontSize: 16, color: _muted),
              ),
            );
          }

          return Column(
            children: [
              WebConsumerNavBar(
                currentIndex: -1,
                onNavigate: _handleNav,
                onCartTap: () => context.go(AppRoutes.cart),
                margin: const EdgeInsets.fromLTRB(32, 20, 32, 12),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
                  child: Column(
                    children: [
                      _buildHeader(farmer),
                      const SizedBox(height: 24),
                      _buildStatsRow(farmer),
                      const SizedBox(height: 24),
                      _buildContent(farmer),
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

  Widget _buildHeader(Map<String, dynamic> farmer) {
    final coverImageUrl = farmer['image_url']?.toString();
    final farmName = _farmName(farmer);
    final ownProfile = _isOwnProfile(farmer);

    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 280,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              SafeNetworkImage(
                imageUrl: coverImageUrl,
                defaultBucket: 'uploads',
                fit: BoxFit.cover,
                placeholder: Container(color: _surface),
                errorWidget: Container(color: _surface),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 32,
                right: 32,
                bottom: 32,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            farmName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _specialty(farmer),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!ownProfile)
                      FilledButton.icon(
                        onPressed: _isFollowBusy
                            ? null
                            : () => _toggleFollow(farmer),
                        style: FilledButton.styleFrom(
                          backgroundColor: _isFollowing
                              ? Colors.white
                              : const Color(0xFF0F766E),
                          foregroundColor: _isFollowing ? _dark : _white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 18,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _isFollowBusy
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _isFollowing ? _dark : _white,
                                ),
                              )
                            : Icon(
                                _isFollowing
                                    ? Icons.check_rounded
                                    : Icons.person_add_alt_1_rounded,
                              ),
                        label: Text(
                          _isFollowing ? 'Following' : 'Follow Farm',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
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

  Widget _buildStatsRow(Map<String, dynamic> farmer) {
    final rating = farmer['average_rating']?.toString() ?? '0.0';
    final totalReviews = farmer['total_reviews']?.toString() ?? '0';
    return Row(
      children: [
        _buildStatCard(
          'AVERAGE RATING',
          rating,
          Icons.workspace_premium_rounded,
          const Color(0xFFDCFCE7),
          const Color(0xFF16A34A),
        ),
        const SizedBox(width: 14),
        _buildStatCard(
          'FOLLOWERS',
          '$_followerCount',
          Icons.favorite_rounded,
          const Color(0xFFFFEDD5),
          const Color(0xFFEA580C),
        ),
        const SizedBox(width: 14),
        _buildStatCard(
          'POSITIVE REVIEWS',
          totalReviews,
          Icons.thumb_up_rounded,
          const Color(0xFFFFE4E6),
          const Color(0xFFE11D48),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color iconBgColor,
    Color iconColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _muted,
                letterSpacing: 0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> farmer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: _border,
            indicatorColor: _primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: _dark,
            unselectedLabelColor: _muted,
            labelStyle: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelStyle: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(text: 'Products'),
              Tab(text: 'Posts'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            final showingPosts = _tabController.index == 1;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: showingPosts
                  ? _WebFarmerPostsTab(
                      key: const ValueKey('posts'),
                      farmerUserId: farmer['user_id']?.toString() ?? '',
                    )
                  : _WebFarmerProductsTab(
                      key: const ValueKey('products'),
                      farmerId: widget.farmerId,
                    ),
            );
          },
        ),
      ],
    );
  }
}

class _WebFarmerProductsTab extends StatelessWidget {
  final String farmerId;

  const _WebFarmerProductsTab({super.key, required this.farmerId});

  static const Color _primary = Color(0xFF16A34A);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductItem>>(
      future: SupabaseDataService().getProductsByFarmerId(farmerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _primary),
          );
        }

        final products = snapshot.data ?? [];
        if (products.isEmpty) {
          return _buildEmptyState(
            'No products yet',
            'This farmer has not listed products yet.',
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth >= 1320
                ? 3
                : constraints.maxWidth >= 860
                ? 2
                : 1;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
                mainAxisExtent: 400,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) =>
                  _buildProductCard(context, products[index], index),
            );
          },
        );
      },
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    ProductItem product,
    int index,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.preorderDetails, extra: product),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: product.imageUrl.isNotEmpty
                        ? Image.network(
                            product.imageUrl,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _buildImageFallback(),
                          )
                        : _buildImageFallback(),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _buildTag(product, index),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _dark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            product.price,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product.description ??
                            'Fresh and high quality produce sourced directly from our farm.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _muted,
                          height: 1.5,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 14,
                                  color: Color(0xFF0F766E),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'In Stock: ${product.targetQuantity?.toInt() ?? 50} ${product.unit.isNotEmpty ? product.unit : "units"}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0F766E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              await CartService().addItem(product);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${product.name} added to cart',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.add_shopping_cart_rounded,
                              size: 16,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF1F5F9),
                              foregroundColor: _dark,
                              padding: const EdgeInsets.all(10),
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
      ),
    );
  }

  Widget _buildTag(ProductItem product, int index) {
    String text = 'Organic';
    Color bgColor = const Color(0xFF047857);

    final cat = product.categoryName?.toLowerCase() ?? '';
    if (product.isFeatured) {
      text = "Farmer's Choice";
      bgColor = const Color(0xFFB45309);
    } else if (cat.contains('meat') ||
        cat.contains('livestock') ||
        index % 3 == 0) {
      text = 'Fresh Today';
      bgColor = const Color(0xFFEA580C);
    } else {
      text = 'Organic';
      bgColor = const Color(0xFF16A34A);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildImageFallback() {
    return Container(
      height: 200,
      color: _surface,
      child: const Center(
        child: Icon(Icons.image_outlined, color: _muted, size: 30),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.storefront_rounded, size: 44, color: _muted),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 13, color: _muted)),
        ],
      ),
    );
  }
}

class _WebFarmerPostsTab extends StatelessWidget {
  final String farmerUserId;

  const _WebFarmerPostsTab({super.key, required this.farmerUserId});

  static const Color _primary = Color(0xFF16A34A);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ForumPostItem>>(
      future: SupabaseDataService().getForumPostsByUserId(farmerUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _primary),
          );
        }

        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return _buildEmptyState(
            'No posts yet',
            'This farmer has not shared any community posts yet.',
          );
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              for (var index = 0; index < posts.length; index++) ...[
                if (index > 0) const SizedBox(height: 16),
                _buildPostCard(posts[index]),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPostCard(ForumPostItem post) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: _primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.userName,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    Text(
                      post.time,
                      style: GoogleFonts.inter(fontSize: 12, color: _muted),
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
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            post.body,
            style: GoogleFonts.inter(fontSize: 14, color: _dark, height: 1.7),
          ),
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                post.imageUrl!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.thumb_up_alt_outlined, size: 16, color: _muted),
              const SizedBox(width: 6),
              Text(
                '${post.likes}',
                style: GoogleFonts.inter(fontSize: 12, color: _muted),
              ),
              const SizedBox(width: 20),
              const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 16,
                color: _muted,
              ),
              const SizedBox(width: 6),
              Text(
                '${post.comments}',
                style: GoogleFonts.inter(fontSize: 12, color: _muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.forum_outlined, size: 44, color: _muted),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 13, color: _muted)),
        ],
      ),
    );
  }
}
