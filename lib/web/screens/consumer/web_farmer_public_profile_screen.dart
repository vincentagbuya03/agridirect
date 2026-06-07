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

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) return 'F';
    return parts.map((part) => part[0].toUpperCase()).join();
  }

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
    final avatarUrl = farmer['avatar_url']?.toString();
    final rating = farmer['average_rating']?.toString() ?? '0.0';
    final totalReviews = farmer['total_reviews']?.toString() ?? '0';
    final farmName = _farmName(farmer);
    final ownProfile = _isOwnProfile(farmer);

    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: SizedBox(
              height: 260,
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
                          Colors.black.withValues(alpha: 0.18),
                          Colors.black.withValues(alpha: 0.58),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 28,
                    right: 28,
                    bottom: 24,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            color: _primary.withValues(alpha: 0.18),
                          ),
                          child: ClipOval(
                            child: avatarUrl != null && avatarUrl.isNotEmpty
                                ? SafeNetworkImage(
                                    imageUrl: avatarUrl,
                                    defaultBucket: 'uploads',
                                    fit: BoxFit.cover,
                                    placeholder: _buildAvatarFallback(farmName),
                                    errorWidget: _buildAvatarFallback(farmName),
                                  )
                                : _buildAvatarFallback(farmName),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                farmName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _specialty(farmer),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.86),
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
                                  : _primary,
                              foregroundColor: _isFollowing ? _dark : _white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
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
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                _buildStatCard('Rating', rating),
                const SizedBox(width: 14),
                _buildStatCard('Followers', '$_followerCount'),
                const SizedBox(width: 14),
                _buildStatCard('Reviews', totalReviews),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(String farmName) {
    return Container(
      color: _primary.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(
        _initials(farmName),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 13, color: _muted)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> farmer) {
    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: TabBar(
              controller: _tabController,
              labelColor: _primary,
              unselectedLabelColor: _muted,
              indicatorColor: _primary,
              labelStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              tabs: const [
                Tab(text: 'Products'),
                Tab(text: 'Posts'),
              ],
            ),
          ),
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
      ),
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
              padding: const EdgeInsets.all(24),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 18,
                mainAxisSpacing: 18,
                mainAxisExtent: 360,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) =>
                  _buildProductCard(context, products[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildProductCard(BuildContext context, ProductItem product) {
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
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: product.imageUrl.isNotEmpty
                    ? Image.network(
                        product.imageUrl,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildImageFallback(),
                      )
                    : _buildImageFallback(),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product.price,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.unit,
                      style: GoogleFonts.inter(fontSize: 12, color: _muted),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.push(
                              AppRoutes.preorderDetails,
                              extra: product,
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: _border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              'View',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                color: _dark,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
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
                            style: FilledButton.styleFrom(
                              backgroundColor: _primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              'Add',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildImageFallback() {
    return Container(
      height: 180,
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

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: posts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (_, index) => _buildPostCard(posts[index]),
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
