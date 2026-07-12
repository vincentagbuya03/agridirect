import 'package:flutter/material.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../widgets/animated_components.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/create_post_dialog.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/integration/weather_service.dart';
import '../../../shared/models/weather_model.dart';
import '../../widgets/web_consumer_nav_bar.dart';
import '../../widgets/web_hamburger_menu_button.dart';
import '../../../shared/widgets/image_widgets.dart';

import '../../../shared/screens/article_detail_screen.dart';
import '../../../shared/widgets/post_detail_dialog.dart';
import '../../../shared/widgets/forum_video_player.dart';

/// Web-only Community Hub — two-column layout with sidebar.
/// Completely separate UI from the mobile community hub.
class WebCommunityHub extends StatefulWidget {
  final Function(int) onNavigate;
  final int currentIndex;

  const WebCommunityHub({
    super.key,
    required this.onNavigate,
    required this.currentIndex,
  });

  @override
  State<WebCommunityHub> createState() => _WebCommunityHubState();
}

class _WebCommunityHubState extends State<WebCommunityHub>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _fadeInController;
  late List<AnimationController> _postControllers;
  late Future<List<ForumPostItem>> _forumPostsFuture;
  List<ForumPostItem>? _postsList;
  late Future<WeatherData?> _weatherFuture;
  final Set<int> _hoveredPosts = {};
  int _hoveredNav = -1;

  static const Color _primary = Color(0xFF10B981); // Unified Emerald
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _postControllers = [];
    _forumPostsFuture = SupabaseDataService().getForumPosts();
    _weatherFuture = WeatherService().getWeatherByCity('Manila');
  }

  void _refreshForumPosts() {
    setState(() {
      _postsList = null;
      _forumPostsFuture = SupabaseDataService().getForumPosts();
    });
  }

  void _syncPostControllers(int count) {
    if (_postControllers.length == count) return;

    // Dispose old
    for (final c in _postControllers) {
      c.dispose();
    }

    // Create new
    _postControllers = List.generate(
      count,
      (i) => AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      ),
    );

    // Stagger animations
    Future.delayed(const Duration(milliseconds: 100), () {
      for (int i = 0; i < _postControllers.length; i++) {
        Future.delayed(Duration(milliseconds: 80 * i), () {
          if (mounted && i < _postControllers.length) {
            _postControllers[i].forward();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeInController.dispose();
    for (final controller in _postControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Navigate to the public profile of a farmer by their user_id.
  /// Looks up the farmer_id from the farmers table, then routes to /farm/:farmerId.
  Future<void> _navigateToFarmerProfile(String? userId) async {
    if (userId == null || userId.isEmpty) return;
    final farmerId = await SupabaseDataService().getFarmerIdByUserId(userId);
    if (!mounted) return;
    if (farmerId != null && farmerId.isNotEmpty) {
      context.push(AppRoutes.farmerProfile(farmerId));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This user does not have a public farm profile.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final showSidebar = sw >= 850;

    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        children: [
          // Subtle dot pattern background
          Positioned.fill(
            child: CustomPaint(
              painter: DotPatternPainter(
                opacity: 0.03,
                color: const Color(0xFF10B981),
              ),
            ),
          ),
          // Particles
          const Positioned.fill(
            child: FloatingParticles(
              count: 8,
              maxSize: 1.8,
              color: Color(0xFF34D399),
              height: 1000,
            ),
          ),
          Column(
            children: [
              _buildNavBar(),
              _buildTopBar(),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main content
                    Expanded(flex: 3, child: _buildMainContent()),
                    // Right sidebar
                    if (showSidebar)
                      SizedBox(width: 320, child: _buildRightSidebar()),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: AuthService().isSeller
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: AgriColors.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AgriColors.emerald500.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                onPressed: () async {
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (context) => const CreatePostDialog(),
                  );
                  if (result == true && mounted) {
                    _refreshForumPosts();
                  }
                },
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                icon: const Icon(Icons.edit_rounded, size: 20),
                label: Text(
                  'New Post',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            )
          : null,
    );
  }

  // ─── Site Header (consistent across all pages) ───
  Widget _buildNavBar() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 650;

    if (!AuthService().isViewingAsFarmer) {
      return WebConsumerNavBar(
        currentIndex: widget.currentIndex,
        onNavigate: widget.onNavigate,
        onCartTap: () => context.go(AppRoutes.cart),
        margin: isMobile
            ? const EdgeInsets.fromLTRB(16, 16, 16, 8)
            : const EdgeInsets.fromLTRB(32, 24, 32, 12),
      );
    }

    final navItems = ['Dashboard', 'Products', 'Orders', 'Community', 'Pre-Orders'];
    return Container(
      margin: isMobile
          ? const EdgeInsets.fromLTRB(16, 16, 16, 8)
          : const EdgeInsets.fromLTRB(32, 24, 32, 12),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 28,
        vertical: isMobile ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: _dark.withValues(alpha: 0.03),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo with pulsing glow
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => widget.onNavigate(0),
              child: BrandLogo(
                size: isMobile ? BrandLogoSize.small : BrandLogoSize.medium,
              ),
            ),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 48),
            // Nav items
            ...List.generate(navItems.length, (i) {
              final isActive = i == widget.currentIndex;
              final isHovered = _hoveredNav == i;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _hoveredNav = i),
                  onExit: (_) => setState(() => _hoveredNav = -1),
                  child: GestureDetector(
                    onTap: () => widget.onNavigate(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: isActive
                            ? _primary.withValues(alpha: 0.1)
                            : isHovered
                            ? _border.withValues(alpha: 0.35)
                            : Colors.transparent,
                      ),
                      child: Text(
                        navItems[i],
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isActive
                              ? _primary
                              : isHovered
                              ? _dark
                              : _muted,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
          const Spacer(),
          // Circle person icon
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => widget.onNavigate(5), // Profile is index 5
              child: Container(
                width: isMobile ? 38 : 46,
                height: isMobile ? 38 : 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primary, Color(0xFF059669)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: Colors.white,
                  size: isMobile ? 20 : 24,
                ),
              ),
            ),
          ),
          if (isMobile) ...[
            const SizedBox(width: 8),
            WebHamburgerMenuButton(
              currentIndex: widget.currentIndex,
              onNavigate: widget.onNavigate,
            ),
          ],
        ],
      ),
    );
  }

  // ─── Top Bar ───
  Widget _buildTopBar() {
    final sw = MediaQuery.of(context).size.width;
    final isCompact = sw < 750;

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: _border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  'Community Hub',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                  ),
                ),
                const Spacer(),
                // Tabs
                Container(
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: _primary,
                    unselectedLabelColor: _muted,
                    indicatorSize: TabBarIndicatorSize.label,
                    indicatorColor: _primary,
                    indicatorWeight: 2,
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    dividerColor: Colors.transparent,
                    tabAlignment: TabAlignment.center,
                    tabs: const [
                      Tab(text: 'Forum'),
                      Tab(text: 'Articles'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Search
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search topics, pests, crops...',
                  hintStyle: TextStyle(color: _muted, fontSize: 13),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: _muted,
                    size: 18,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          const Text(
            'Community Hub',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          const SizedBox(width: 32),
          // Search
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search topics, pests, crops...',
                  hintStyle: TextStyle(color: _muted, fontSize: 13),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: _muted,
                    size: 18,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Tabs
          Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: _primary,
              unselectedLabelColor: _muted,
              indicatorSize: TabBarIndicatorSize.label,
              indicatorColor: _primary,
              indicatorWeight: 2,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              dividerColor: Colors.transparent,
              tabAlignment: TabAlignment.center,
              tabs: const [
                Tab(text: 'Forum'),
                Tab(text: 'Articles'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Main Content ───
  Widget _buildMainContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 680),
            child: _buildForumFeed(),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _buildArticlesFeed(),
          ),
        ),
      ],
    );
  }

  Widget _buildForumFeed() {
    final sw = MediaQuery.of(context).size.width;
    final padding = sw < 600 ? const EdgeInsets.all(16) : const EdgeInsets.all(32);

    if (_postsList != null) {
      return _buildForumList(padding, _postsList!);
    }

    return FutureBuilder<List<ForumPostItem>>(
      future: _forumPostsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: AppShimmerLoader());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final posts = snapshot.data ?? [];
        _postsList = List.from(posts);

        return _buildForumList(padding, _postsList!);
      },
    );
  }

  Widget _buildForumList(EdgeInsets padding, List<ForumPostItem> posts) {
    if (posts.isEmpty) {
      return Center(
        child: Text('No forum posts yet', style: TextStyle(color: _muted)),
      );
    }

    // Sync controllers once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncPostControllers(posts.length);
    });

    final showCreateCard = AuthService().isSeller;
    return ListView.builder(
      padding: padding,
      itemCount: posts.length + (showCreateCard ? 1 : 0),
      itemBuilder: (context, i) {
        if (showCreateCard) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _buildFacebookCreatePostCard(),
            );
          }
          final postIndex = i - 1;
          if (postIndex < _postControllers.length) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _buildAnimatedForumCard(postIndex, posts[postIndex]),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _buildForumCard(posts[postIndex]),
          );
        } else {
          final postIndex = i;
          if (postIndex < _postControllers.length) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _buildAnimatedForumCard(postIndex, posts[postIndex]),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _buildForumCard(posts[postIndex]),
          );
        }
      },
    );
  }

  Widget _buildAnimatedForumCard(int index, ForumPostItem post) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _postControllers[index],
          curve: Curves.easeInOut,
        ),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(-0.2, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: _postControllers[index],
                curve: Curves.easeOutCubic,
              ),
            ),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hoveredPosts.add(index)),
          onExit: (_) => setState(() => _hoveredPosts.remove(index)),
          child: _buildForumCard(post, _hoveredPosts.contains(index)),
        ),
      ),
    );
  }

  Widget _buildForumCard(ForumPostItem post, [bool isHovered = false]) {
    return GestureDetector(
      onTap: () => _showPostDetailFlow(post),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHovered ? _primary : _border,
            width: isHovered ? 2 : 1,
          ),
          boxShadow: isHovered
              ? [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Author row - clickable to visit farmer profile
          Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _navigateToFarmerProfile(post.userId),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _primary.withValues(alpha: 0.2), width: 1.5),
                        ),
                        child: ClipOval(
                          child: SafeNetworkImage(
                            imageUrl: post.authorAvatarUrl,
                            defaultBucket: 'uploads',
                            fit: BoxFit.cover,
                            placeholder: Container(
                              color: _primary.withValues(alpha: 0.1),
                              child: Center(
                                child: Text(
                                  post.userName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _primary,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: Container(
                              color: _primary.withValues(alpha: 0.1),
                              child: Center(
                                child: Text(
                                  post.userName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.userName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _dark,
                            ),
                          ),
                          Text(
                            post.time,
                            style: TextStyle(fontSize: 12, color: _muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.more_horiz_rounded, size: 18, color: _muted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Title & Body
          if (post.title.isNotEmpty) ...[
            Text(
              post.title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            post.body,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF334155),
              height: 1.5,
            ),
          ),
          // Video or Image display
          if (post.videoUrl != null && post.videoUrl!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border.withValues(alpha: 0.8)),
                color: const Color(0xFFF8FAFC),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 340,
                    ),
                    child: ForumVideoPlayer(videoUrl: post.videoUrl!),
                  ),
                ),
              ),
            ),
          ] else if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border.withValues(alpha: 0.8)),
                color: const Color(0xFFF8FAFC),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 340,
                    ),
                    child: SafeNetworkImage(
                      imageUrl: post.imageUrl!,
                      defaultBucket: 'uploads',
                      fit: BoxFit.contain,
                      placeholder: Container(
                        height: 200,
                        color: const Color(0xFFF1F5F9),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
                        ),
                      ),
                      errorWidget: Container(
                        height: 100,
                        color: const Color(0xFFF1F5F9),
                        child: const Icon(Icons.broken_image_outlined, color: _muted),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          // Like and comment counts summary
          if (post.likes > 0 || post.comments > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (post.likes > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.thumb_up_rounded, size: 10, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${post.likes}',
                    style: GoogleFonts.inter(fontSize: 12, color: _muted),
                  ),
                ],
                const Spacer(),
                if (post.comments > 0)
                  Text(
                    '${post.comments} ${post.comments == 1 ? "comment" : "comments"}',
                    style: GoogleFonts.inter(fontSize: 12, color: _muted),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 6),
          // Actions row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _buildFacebookActionBtn(
                  icon: post.isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined,
                  label: 'Like',
                  color: post.isLiked ? const Color(0xFF3B82F6) : _muted,
                  onTap: () async {
                    if (!AuthService().isLoggedIn) {
                      context.go(AppRoutes.login);
                      return;
                    }

                    // Optimistic update
                    final index = _postsList?.indexWhere((p) => p.id == post.id) ?? -1;
                    if (index != -1 && _postsList != null) {
                      final targetPost = _postsList![index];
                      final wasLiked = targetPost.isLiked;
                      setState(() {
                        _postsList![index] = ForumPostItem(
                          id: targetPost.id,
                          userId: targetPost.userId,
                          userName: targetPost.userName,
                          time: targetPost.time,
                          title: targetPost.title,
                          body: targetPost.body,
                          imageUrl: targetPost.imageUrl,
                          likes: wasLiked ? targetPost.likes - 1 : targetPost.likes + 1,
                          comments: targetPost.comments,
                          isLiked: !wasLiked,
                          isPinned: targetPost.isPinned,
                          authorAvatarUrl: targetPost.authorAvatarUrl,
                        );
                      });
                    }

                    try {
                      await SupabaseDataService().togglePostLike(post.id);
                    } catch (e) {
                      if (mounted) _refreshForumPosts();
                    }
                  },
                ),
              ),
              Expanded(
                child: _buildFacebookActionBtn(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Comment',
                  color: _muted,
                  onTap: () {
                    if (!AuthService().isLoggedIn) {
                      context.go(AppRoutes.login);
                      return;
                    }
                    _showPostDetailFlow(post);
                  },
                ),
              ),
              Expanded(
                child: _buildFacebookActionBtn(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  color: _muted,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied to clipboard!')),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _buildFacebookActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFacebookCreatePostCard() {
    final auth = AuthService();
    final displayName = auth.isLoggedIn ? auth.userName : 'Guest';
    final avatarUrl = auth.isLoggedIn ? auth.userAvatarUrl : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _primary.withValues(alpha: 0.2), width: 1.5),
                ),
                child: ClipOval(
                  child: SafeNetworkImage(
                    imageUrl: avatarUrl,
                    defaultBucket: 'uploads',
                    fit: BoxFit.cover,
                    placeholder: Container(color: Colors.grey[200]),
                    errorWidget: const Icon(Icons.person, color: _muted),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _showCreatePostFlow,
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "What's on your mind, ${displayName.split(' ').first}?",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: _muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 1),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceEvenly,
            children: [
              _buildCreatePostAction(
                icon: Icons.photo_library_rounded,
                label: 'Photo/video',
                color: const Color(0xFF22C55E),
                onTap: _showCreatePostFlow,
              ),
              _buildCreatePostAction(
                icon: Icons.label_important_rounded,
                label: 'Tag Farmer',
                color: const Color(0xFF3B82F6),
                onTap: _showCreatePostFlow,
              ),
              _buildCreatePostAction(
                icon: Icons.emoji_emotions_rounded,
                label: 'Feeling/activity',
                color: const Color(0xFFEAB308),
                onTap: _showCreatePostFlow,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreatePostAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCreatePostFlow() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const CreatePostDialog(),
    );
    if (result == true && mounted) {
      _refreshForumPosts();
    }
  }

  Future<void> _showPostDetailFlow(ForumPostItem post) async {
    final result = await showDialog<dynamic>(
      context: context,
      builder: (context) => PostDetailDialog(
        post: post,
        onPostUpdated: (updatedPost) {
          if (mounted) {
            setState(() {
              if (_postsList != null) {
                final index = _postsList!.indexWhere((p) => p.id == updatedPost.id);
                if (index != -1) {
                  _postsList![index] = updatedPost;
                }
              }
            });
          }
        },
      ),
    );
    if (result is ForumPostItem && mounted) {
      setState(() {
        if (_postsList != null) {
          final index = _postsList!.indexWhere((p) => p.id == result.id);
          if (index != -1) {
            _postsList![index] = result;
          }
        }
      });
    }
  }

  Widget _buildArticlesFeed() {
    final sw = MediaQuery.of(context).size.width;
    final padding = sw < 600 ? const EdgeInsets.all(16) : const EdgeInsets.all(32);

    return FutureBuilder<List<ArticleItem>>(
      future: SupabaseDataService().getArticles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: AppShimmerLoader());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final articles = snapshot.data ?? [];
        if (articles.isEmpty) {
          return Center(
            child: Text('No articles yet', style: TextStyle(color: _muted)),
          );
        }

        return ListView.builder(
          padding: padding,
          itemCount: articles.length,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _buildArticleCard(articles[i]),
          ),
        );
      },
    );
  }

  Widget _buildArticleCard(ArticleItem article) {
    final sw = MediaQuery.of(context).size.width;
    final isSmall = sw < 600;

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'FEATURED ARTICLE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _primary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          article.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _dark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          article.excerpt,
          style: TextStyle(fontSize: 13, color: _muted, height: 1.4),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              'By ${article.author}',
              style: TextStyle(fontSize: 12, color: _muted),
            ),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: _muted,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              article.readTime,
              style: TextStyle(fontSize: 12, color: _muted),
            ),
          ],
        ),
      ],
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ArticleDetailScreen(article: article),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: isSmall
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (article.imageUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: article.imageUrl!,
                          height: 180,
                          fit: BoxFit.cover,
                          placeholder: (ctx, url) => Container(
                            height: 180,
                            color: Colors.grey[100],
                          ),
                          errorWidget: (ctx, url, err) => Container(
                            height: 180,
                            color: Colors.grey[100],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    content,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: content),
                    if (article.imageUrl != null) ...[
                      const SizedBox(width: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: article.imageUrl!,
                          width: 120,
                          height: 90,
                          fit: BoxFit.cover,
                          placeholder: (ctx, url) => Container(
                            width: 120,
                            height: 90,
                            color: Colors.grey[100],
                          ),
                          errorWidget: (ctx, url, err) => Container(
                            width: 120,
                            height: 90,
                            color: Colors.grey[100],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  // ─── Right Sidebar ───
  Widget _buildRightSidebar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: _border)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWeatherWidget(),
            const SizedBox(height: 24),
            _buildTrendingTopics(),
            const SizedBox(height: 24),
            _buildPopularTags(),
            const SizedBox(height: 24),
            _buildTopContributors(),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherWidget() {
    return FutureBuilder<WeatherData?>(
      future: _weatherFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final temp = data?.temperature.toStringAsFixed(0) ?? '28';
        final desc = data?.description ?? 'Partly Cloudy';
        final location = data?.location ?? 'Manila';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.cloud_rounded,
                  color: Color(0xFF3B82F6),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$temp°C',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                      ),
                    ),
                    Text(
                      '$desc · $location',
                      style: TextStyle(fontSize: 12, color: _muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrendingTopics() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseDataService().getTrendingTopics(),
      builder: (context, snapshot) {
        final topics = snapshot.data ?? [];

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Trending Topics',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 16),
              if (topics.isEmpty &&
                  snapshot.connectionState != ConnectionState.waiting)
                Text(
                  'No trending topics yet',
                  style: TextStyle(fontSize: 12, color: _muted),
                )
              else
                ...topics.asMap().entries.map((entry) {
                  final i = entry.key;
                  final t = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            gradient: i == 0
                                ? AgriColors.goldGradient
                                : AgriColors.primaryGradient,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            t['title'],
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _dark,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${t['engagement']}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPopularTags() {
    return FutureBuilder<List<String>>(
      future: SupabaseDataService().getPopularTags(),
      builder: (context, snapshot) {
        final tags = snapshot.data ?? [];

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Popular Tags',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 14),
              if (tags.isEmpty &&
                  snapshot.connectionState != ConnectionState.waiting)
                Text(
                  'No tags found',
                  style: TextStyle(fontSize: 12, color: _muted),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _border),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _muted,
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopContributors() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseDataService().getTopContributors(),
      builder: (context, snapshot) {
        final contributors = snapshot.data ?? [];
        final colors = [
          const Color(0xFF16A34A),
          const Color(0xFF3B82F6),
          const Color(0xFFF59E0B),
        ];

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Top Contributors',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 16),
              if (contributors.isEmpty &&
                  snapshot.connectionState != ConnectionState.waiting)
                Text(
                  'No contributors yet',
                  style: TextStyle(fontSize: 12, color: _muted),
                )
              else
                ...contributors.asMap().entries.map((entry) {
                  final i = entry.key;
                  final c = entry.value;
                  final color = colors[i % colors.length];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              c['name']
                                  .toString()
                                  .split(' ')
                                  .map((w) => w.isNotEmpty ? w[0] : '')
                                  .take(2)
                                  .join(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: color,
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
                                c['name'],
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _dark,
                                ),
                              ),
                              Text(
                                c['posts'],
                                style: TextStyle(fontSize: 11, color: _muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
