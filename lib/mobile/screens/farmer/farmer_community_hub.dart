import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/widgets/create_post_dialog.dart';
import '../../../shared/widgets/comments_dialog.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/screens/post_detail_screen.dart';
import '../../../shared/screens/article_detail_screen.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/utils/share_util.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/community/notification_service.dart';
import '../../../shared/widgets/forum_video_player.dart';
import '../../../shared/localization/farmer_locale_service.dart';
import '../../widgets/farmer/farmer_language_toggle.dart';

/// Farmer Community Hub - Modern Social & Agricultural Knowledge Interface
class FarmerCommunityHub extends StatefulWidget {
  final String? initialPostId;
  const FarmerCommunityHub({super.key, this.initialPostId});

  @override
  State<FarmerCommunityHub> createState() => _FarmerCommunityHubState();
}

class _FarmerCommunityHubState extends State<FarmerCommunityHub>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  late Stream<List<ForumPostItem>> _forumStream;
  late Future<List<ArticleItem>> _articlesFuture;
  List<ForumPostItem>? _cachedPosts;
  List<ArticleItem>? _cachedArticles;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  // Topic filter tags
  final List<String> _topics = [
    'All',
    '🌾 Crops',
    '🐛 Pest Alert',
    '💧 Irrigation',
    '💰 Market Rates',
    '🚜 Tools & Equip',
    '📢 Advisory',
  ];

  static const Color _primary = Color(0xFF059669);
  static const Color _primaryLight = Color(0xFFDCFCE7);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _cardBg = Colors.white;
  static const Color _bg = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _forumStream = SupabaseDataService().watchForumPosts();
    _articlesFuture = SupabaseDataService().getArticles();

    if (widget.initialPostId != null && widget.initialPostId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showDialog<bool>(
            context: context,
            builder: (context) => CommentsDialog(postId: widget.initialPostId!),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Navigate to farmer public profile
  Future<void> _navigateToFarmerProfile(String? userId) async {
    if (userId == null || userId.isEmpty) return;
    final farmerId = await SupabaseDataService().getFarmerIdByUserId(userId);
    if (!mounted) return;
    if (farmerId != null && farmerId.isNotEmpty) {
      context.push(AppRoutes.farmerProfile(farmerId));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This user does not have a public farm profile.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatName(String raw) {
    if (raw.isEmpty) return 'Farmer';
    return raw
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  String _getInitials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'AD';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FarmerLocaleService.instance,
      builder: (context, _) {
        final loc = FarmerLocaleService.instance;
        final auth = AuthService();
        final userAvatar = auth.userAvatarUrl;
        final userName = auth.userName.isNotEmpty
            ? _formatName(auth.userName)
            : loc.s('Grower', 'Magsasaka');

        return Scaffold(
          backgroundColor: _bg,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _buildHeader(userAvatar, userName),
                      _buildSearchBar(),
                      _buildTopicPills(),
                      _buildSegmentedTab(),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _KeepAlivePage(child: _buildForumFeed()),
                _KeepAlivePage(child: _buildArticlesFeed()),
              ],
            ),
          ),
          floatingActionButton: auth.isSeller
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (context) => const CreatePostDialog(),
                    );
                    if (result == true && mounted) {
                      setState(() {});
                    }
                  },
                  backgroundColor: _primary,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  icon: const Icon(
                    Icons.edit_note_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  label: Text(
                    loc.s('Post Question', 'Magtanong sa Komunidad'),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeader(String userAvatar, String userName) {
    final loc = FarmerLocaleService.instance;
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 20,
        bottom: 14,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: Row(
        children: [
          // User Avatar / Profile
          GestureDetector(
            onTap: () => context.push(AppRoutes.profile),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _primary.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: _primaryLight,
                backgroundImage: (userAvatar.isNotEmpty && userAvatar != 'null')
                    ? CachedNetworkImageProvider(userAvatar)
                    : null,
                child: (userAvatar.isEmpty || userAvatar == 'null')
                    ? Text(
                        _getInitials(userName),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _primary,
                        ),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Title & Greeting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _primaryLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        loc.s('COMMUNITY HUB', 'SENTRO NG KOMUNIDAD'),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _primary,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  loc.s('AgriDirect Farmers', 'Mga Magsasaka ng AgriDirect'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),

          // Language Toggle
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: FarmerLanguageToggle(compact: true),
          ),

          // Notification Button
          _buildNotificationButton(),
        ],
      ),
    );
  }

  Widget _buildNotificationButton() {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationService().unreadCountNotifier,
      builder: (context, count, _) {
        return InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            context.push(AppRoutes.notifications);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  size: 22,
                  color: _dark,
                ),
                if (count > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 8,
                        minHeight: 8,
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

  // ─────────────────────────────────────────────────────────────
  // SEARCH BAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    final loc = FarmerLocaleService.instance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) =>
              setState(() => _searchQuery = val.trim().toLowerCase()),
          style: GoogleFonts.inter(fontSize: 14, color: _dark),
          decoration: InputDecoration(
            hintText: loc.s(
              'Search posts, crop diagnosis, pests...',
              'Maghanap ng talakayan, sakit ng pananim, peste...',
            ),
            hintStyle: GoogleFonts.inter(fontSize: 13, color: _muted),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: _muted,
              size: 20,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.cancel_rounded,
                      size: 18,
                      color: _muted,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TOPIC FILTER PILLS
  // ─────────────────────────────────────────────────────────────
  Widget _buildTopicPills() {
    final loc = FarmerLocaleService.instance;
    final topicLabels = {
      'All': loc.s('All', 'Lahat'),
      '🌾 Crops': loc.s('🌾 Crops', '🌾 Pananim'),
      '🐛 Pest Alert': loc.s('🐛 Pest Alert', '🐛 Babala sa Peste'),
      '💧 Irrigation': loc.s('💧 Irrigation', '💧 Patubig'),
      '💰 Market Rates': loc.s('💰 Market Rates', '💰 Presyo sa Merkado'),
      '🚜 Tools & Equip': loc.s('🚜 Tools & Equip', '🚜 Kagamitan sa Bukid'),
      '📢 Advisory': loc.s('📢 Advisory', '📢 Payo at Anunsyo'),
    };

    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _topics.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final topic = _topics[index];
          final displayLabel = topicLabels[topic] ?? topic;
          final isSelected = _selectedCategory == topic;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedCategory = topic);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? _primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? _primary : _border,
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: _primary.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  displayLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SEGMENTED TAB SWITCHER
  // ─────────────────────────────────────────────────────────────
  Widget _buildSegmentedTab() {
    final loc = FarmerLocaleService.instance;
    final activeIndex = _tabController.index;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildTabButton(
                title: loc.s('Discussions', 'Talakayan'),
                icon: Icons.forum_rounded,
                isActive: activeIndex == 0,
                onTap: () => _tabController.animateTo(0),
              ),
            ),
            Expanded(
              child: _buildTabButton(
                title: loc.s('Guides & Articles', 'Gabay at Artikulo'),
                icon: Icons.menu_book_rounded,
                isActive: activeIndex == 1,
                onTap: () => _tabController.animateTo(1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isActive ? _primary : _muted),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? _dark : _muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FORUM FEED
  // ─────────────────────────────────────────────────────────────
  Future<void> _refreshForumPosts() async {
    setState(() {
      _forumStream = SupabaseDataService().watchForumPosts();
    });
  }

  Widget _buildForumFeed() {
    return StreamBuilder<List<ForumPostItem>>(
      stream: _forumStream,
      initialData: _cachedPosts,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          _cachedPosts = snapshot.data;
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            _cachedPosts == null) {
          return _buildLoadingSkeleton();
        }
        if (snapshot.hasError && _cachedPosts == null) {
          return _buildErrorState();
        }

        final rawList = _cachedPosts ?? snapshot.data ?? [];
        final posts = rawList.where((post) {
          // Category filter
          if (_selectedCategory != 'All') {
            final categoryKeyword = _selectedCategory
                .replaceAll(RegExp(r'[^\w\s]'), '')
                .trim()
                .toLowerCase();
            final matchesCategory =
                post.title.toLowerCase().contains(categoryKeyword) ||
                post.body.toLowerCase().contains(categoryKeyword);
            if (!matchesCategory) return false;
          }

          // Search query
          if (_searchQuery.isEmpty) return true;
          final haystack = '${post.userName} ${post.title} ${post.body}'
              .toLowerCase();
          return haystack.contains(_searchQuery);
        }).toList();

        if (posts.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refreshForumPosts,
            color: _primary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.4,
                  child: _buildEmptyState(
                    title: 'No discussions found',
                    subtitle: _searchQuery.isNotEmpty
                        ? 'Try searching with different keywords.'
                        : 'Be the first grower to ask a question or share advice!',
                    icon: Icons.chat_bubble_outline_rounded,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshForumPosts,
          color: _primary,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return _buildModernPostCard(post);
            },
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // MODERN POST CARD
  // ─────────────────────────────────────────────────────────────
  Widget _buildModernPostCard(ForumPostItem post) {
    final cleanTitle = post.title.trim();
    final cleanBody = post.body.trim();
    final bool showTitle = cleanTitle.isNotEmpty && cleanBody != cleanTitle;
    final String displayBody =
        (cleanBody.startsWith(cleanTitle) && cleanBody != cleanTitle)
        ? cleanBody.substring(cleanTitle.length).trim()
        : cleanBody;
    final formattedName = _formatName(post.userName);
    final avatar = post.authorAvatarUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailScreen(post: post),
              ),
            );
            if (mounted) setState(() {});
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Author Header ──
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _navigateToFarmerProfile(post.userId),
                      child: Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _primary.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: _primaryLight,
                          backgroundImage: (avatar != null && avatar.isNotEmpty)
                              ? CachedNetworkImageProvider(avatar)
                              : null,
                          child: (avatar == null || avatar.isEmpty)
                              ? Text(
                                  _getInitials(formattedName),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _primary,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _navigateToFarmerProfile(post.userId),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    formattedName,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _dark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 14,
                                  color: _primary,
                                ),
                                if (post.isPinned) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _primaryLight,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.push_pin_rounded,
                                          size: 10,
                                          color: _primary,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          'PINNED',
                                          style: GoogleFonts.inter(
                                            color: _primary,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 1),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 11,
                                  color: _muted,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  post.time,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: _muted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildPostOptionsMenu(post),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Post Title ──
                if (showTitle) ...[
                  Text(
                    cleanTitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],

                // ── Post Body ──
                if (displayBody.isNotEmpty)
                  Text(
                    displayBody,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      color: const Color(0xFF334155),
                      height: 1.5,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),

                // ── Video / Media Player ──
                if (post.videoUrl != null && post.videoUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ForumVideoPlayer(videoUrl: post.videoUrl!),
                  ),
                ] else if (post.imageUrl != null &&
                    post.imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _openFullscreenImage(post.imageUrl!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          CachedNetworkImage(
                            imageUrl: post.imageUrl!,
                            height: 210,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              height: 210,
                              color: const Color(0xFFF1F5F9),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _primary,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              height: 160,
                              color: const Color(0xFFF1F5F9),
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image_rounded,
                                  color: _muted,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.zoom_in_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    FarmerLocaleService.instance.s(
                                      'View Photo',
                                      'Tingnan ang Larawan',
                                    ),
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // ── Action Bar (Like, Comment, Share) ──
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Like Action
                      _buildActionButton(
                        icon: post.isLiked
                            ? Icons.thumb_up_alt_rounded
                            : Icons.thumb_up_alt_outlined,
                        label: FarmerLocaleService.instance.s(
                          '${post.likes} ${post.likes == 1 ? 'Like' : 'Likes'}',
                          '${post.likes} ${post.likes == 1 ? 'Gusto' : 'Mga Gusto'}',
                        ),
                        isActive: post.isLiked,
                        activeColor: _primary,
                        activeBg: _primaryLight,
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          if (!AuthService().isLoggedIn) {
                            context.go(AppRoutes.login);
                            return;
                          }
                          await SupabaseDataService().togglePostLike(post.id);
                          if (mounted) setState(() {});
                        },
                      ),

                      const SizedBox(width: 12),

                      // Comment Action
                      _buildActionButton(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: FarmerLocaleService.instance.s(
                          '${post.comments} ${post.comments == 1 ? 'Reply' : 'Replies'}',
                          '${post.comments} ${post.comments == 1 ? 'Sagot' : 'Mga Sagot'}',
                        ),
                        isActive: false,
                        activeColor: _dark,
                        activeBg: Colors.transparent,
                        onTap: () async {
                          HapticFeedback.selectionClick();
                          if (!AuthService().isLoggedIn) {
                            context.go(AppRoutes.login);
                            return;
                          }
                          final updated = await showDialog<bool>(
                            context: context,
                            builder: (context) =>
                                CommentsDialog(postId: post.id),
                          );
                          if (updated == true && mounted) {
                            setState(() {});
                          }
                        },
                      ),

                      const Spacer(),

                      // Share Action
                      IconButton(
                        onPressed: () => _sharePost(post),
                        icon: const Icon(
                          Icons.share_outlined,
                          size: 18,
                          color: _muted,
                        ),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                        tooltip: FarmerLocaleService.instance.s(
                          'Share post',
                          'Ibahagi ang post',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required Color activeBg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isActive ? activeColor : _muted),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? activeColor : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostOptionsMenu(ForumPostItem post) {
    final loc = FarmerLocaleService.instance;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz_rounded, color: _muted, size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (action) {
        if (action == 'share') {
          _sharePost(post);
        } else if (action == 'profile') {
          _navigateToFarmerProfile(post.userId);
        } else if (action == 'report') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                loc.s(
                  'Thank you. This post has been reported for moderation.',
                  'Salamat. Nai-report na ang post na ito para sa pagsusuri.',
                ),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              const Icon(Icons.share_outlined, size: 16, color: _dark),
              const SizedBox(width: 8),
              Text(
                loc.s('Share Link', 'Ibahagi ang Link'),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        if (post.userId != null)
          PopupMenuItem(
            value: 'profile',
            child: Row(
              children: [
                const Icon(Icons.storefront_outlined, size: 16, color: _dark),
                const SizedBox(width: 8),
                Text(
                  loc.s('View Farm Profile', 'Tingnan ang Profile ng Sakahan'),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'report',
          child: Row(
            children: [
              const Icon(Icons.flag_outlined, size: 16, color: Colors.red),
              const SizedBox(width: 8),
              Text(
                loc.s('Report Post', 'I-report ang Post'),
                style: const TextStyle(fontSize: 13, color: Colors.red),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _sharePost(ForumPostItem post) async {
    final shareUrl =
        '${ShareUtil.baseDomain}${AppRoutes.community}?post=${post.id}';
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: shareUrl));
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          FarmerLocaleService.instance.s(
            '🔗 Post link copied to clipboard!',
            '🔗 Nakopya ang link ng post sa clipboard!',
          ),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openFullscreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ARTICLES FEED
  // ─────────────────────────────────────────────────────────────
  Future<void> _refreshArticles() async {
    final future = SupabaseDataService().getArticles();
    setState(() {
      _articlesFuture = future;
    });
    final data = await future;
    if (mounted) {
      setState(() {
        _cachedArticles = data;
      });
    }
  }

  Widget _buildArticlesFeed() {
    return FutureBuilder<List<ArticleItem>>(
      future: _articlesFuture,
      initialData: _cachedArticles,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          _cachedArticles = snapshot.data;
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            _cachedArticles == null) {
          return _buildLoadingSkeleton();
        }

        if (snapshot.hasError && _cachedArticles == null) {
          return _buildErrorState();
        }

        final rawList = _cachedArticles ?? snapshot.data ?? [];
        final articles = rawList.where((article) {
          if (_searchQuery.isEmpty) return true;
          final haystack =
              '${article.title} ${article.author} ${article.excerpt} ${article.content ?? ''}'
                  .toLowerCase();
          return haystack.contains(_searchQuery);
        }).toList();

        if (articles.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refreshArticles,
            color: _primary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.4,
                  child: _buildEmptyState(
                    title: 'No articles found',
                    subtitle:
                        'Agricultural guides and farming tutorials will appear here.',
                    icon: Icons.article_outlined,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshArticles,
          color: _primary,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            itemCount: articles.length,
            itemBuilder: (context, index) {
              final article = articles[index];
              return _buildModernArticleCard(article);
            },
          ),
        );
      },
    );
  }

  Widget _buildModernArticleCard(ArticleItem article) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ArticleDetailScreen(article: article),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 90,
                    height: 90,
                    color: const Color(0xFFF1F5F9),
                    child:
                        (article.imageUrl != null &&
                            article.imageUrl!.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: article.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: Icon(
                                Icons.menu_book_rounded,
                                color: _muted,
                              ),
                            ),
                            errorWidget: (context, url, error) => const Center(
                              child: Icon(Icons.article_rounded, color: _muted),
                            ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.article_outlined,
                              color: _muted,
                              size: 28,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                // Article Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _primaryLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              FarmerLocaleService.instance.s('GUIDE', 'GABAY'),
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: _primary,
                              ),
                            ),
                          ),
                          if (article.audience == 'FARMER') ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                FarmerLocaleService.instance.s(
                                  'FARMERS ONLY',
                                  'PARA SA MAGSASAKA',
                                ),
                                style: GoogleFonts.inter(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        article.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: _dark,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              article.author,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: _muted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.circle, size: 3, color: _muted),
                          const SizedBox(width: 6),
                          Text(
                            article.time,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: _muted,
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
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LOADING / EMPTY / ERROR STATES
  // ─────────────────────────────────────────────────────────────
  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 120,
                        height: 12,
                        color: const Color(0xFFF1F5F9),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 60,
                        height: 10,
                        color: const Color(0xFFF8FAFC),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 14,
                color: const Color(0xFFF1F5F9),
              ),
              const SizedBox(height: 8),
              Container(width: 200, height: 12, color: const Color(0xFFF8FAFC)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: _primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _muted,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final loc = FarmerLocaleService.instance;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 42, color: _muted),
            const SizedBox(height: 12),
            Text(
              loc.s(
                'Unable to load community posts',
                'Hindi ma-load ang mga post ng komunidad',
              ),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              loc.s(
                'Please check your internet connection.',
                'Pakisuri ang iyong koneksyon sa internet.',
              ),
              style: GoogleFonts.inter(fontSize: 13, color: _muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper widget to keep TabBarView page state alive and prevent rebuilding/reloading
class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
