import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/screens/post_detail_screen.dart';
import '../../../shared/widgets/forum_video_player.dart';
import '../../../shared/widgets/comments_dialog.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/utils/share_util.dart';

/// Community Stories - Modern Consumer Discovery & Grower Stories Screen
class CommunityStoriesScreen extends StatefulWidget {
  const CommunityStoriesScreen({super.key});

  @override
  State<CommunityStoriesScreen> createState() => _CommunityStoriesScreenState();
}

class _CommunityStoriesScreenState extends State<CommunityStoriesScreen> {
  late Stream<List<ForumPostItem>> _forumStream;
  String _searchQuery = '';
  String _selectedTag = 'All';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _tags = [
    'All',
    '🌾 Harvest Logs',
    '🌱 Farm Tips',
    '🍅 Crop Updates',
    '🧑‍🌾 Grower Life',
    '💡 Ask Farmers',
  ];

  static const Color _primary = Color(0xFF059669);
  static const Color _primaryLight = Color(0xFFDCFCE7);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _bg = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _forumStream = SupabaseDataService().watchForumPosts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatName(String raw) {
    if (raw.isEmpty) return 'Local Grower';
    return raw.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'AG';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

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

  Future<void> _sharePost(ForumPostItem post) async {
    HapticFeedback.selectionClick();
    final shareUrl = '${ShareUtil.baseDomain}${AppRoutes.community}?post=${post.id}';
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: shareUrl));
    messenger.showSnackBar(
      const SnackBar(
        content: Text('🔗 Story link copied to clipboard!'),
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
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: _dark),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              'Community Stories',
              style: GoogleFonts.plusJakartaSans(
                color: _dark,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Live updates directly from accredited farms',
              style: GoogleFonts.inter(
                color: _muted,
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildSearchBar(),
                _buildTopicTags(),
                const SizedBox(height: 12),
              ],
            ),
          ),
          StreamBuilder<List<ForumPostItem>>(
            stream: _forumStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return SliverToBoxAdapter(child: _buildLoadingSkeleton());
              }

              final List<ForumPostItem> posts = snapshot.data ?? const <ForumPostItem>[];
              final filteredPosts = posts.where((post) {
                // Topic tag filter
                if (_selectedTag != 'All') {
                  final keyword = _selectedTag
                      .replaceAll(RegExp(r'[^\w\s]'), '')
                      .trim()
                      .toLowerCase();
                  final matches = post.title.toLowerCase().contains(keyword) ||
                      post.body.toLowerCase().contains(keyword);
                  if (!matches) return false;
                }

                // Search query
                if (_searchQuery.isEmpty) return true;
                final query = _searchQuery.toLowerCase();
                return post.userName.toLowerCase().contains(query) ||
                    post.title.toLowerCase().contains(query) ||
                    post.body.toLowerCase().contains(query);
              }).toList();

              if (filteredPosts.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildStoryCard(post: filteredPosts[index]),
                      );
                    },
                    childCount: filteredPosts.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SEARCH BAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val.trim()),
          style: GoogleFonts.inter(fontSize: 14, color: _dark),
          decoration: InputDecoration(
            hintText: 'Search stories, growers, crops...',
            hintStyle: GoogleFonts.inter(fontSize: 13, color: _muted),
            prefixIcon: const Icon(Icons.search_rounded, color: _muted, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.cancel_rounded, size: 18, color: _muted),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TOPIC TAGS
  // ─────────────────────────────────────────────────────────────
  Widget _buildTopicTags() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: _tags.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final tag = _tags[index];
            final isSelected = _selectedTag == tag;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedTag = tag);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? _primary : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? _primary : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    tag,
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
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // STORY CARD
  // ─────────────────────────────────────────────────────────────
  Widget _buildStoryCard({required ForumPostItem post}) {
    final cleanTitle = post.title.trim();
    final cleanBody = post.body.trim();
    final bool showTitle = cleanTitle.isNotEmpty && cleanBody != cleanTitle;
    final String displayBody = (cleanBody.startsWith(cleanTitle) && cleanBody != cleanTitle)
        ? cleanBody.substring(cleanTitle.length).trim()
        : cleanBody;
    final formattedName = _formatName(post.userName);
    final avatar = post.authorAvatarUrl;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
            ).then((_) {
              if (mounted) setState(() {});
            });
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
                            color: _primary.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 20,
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
                                      fontSize: 14.5,
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
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _primaryLight,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.push_pin_rounded, size: 10, color: _primary),
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
                    _buildStoryOptionsMenu(post),
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

                // ── Story Content Body ──
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
                ] else if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
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
                                child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              height: 160,
                              color: const Color(0xFFF1F5F9),
                              child: const Center(
                                child: Icon(Icons.broken_image_rounded, color: _muted),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                                  const SizedBox(width: 3),
                                  Text(
                                    'View Photo',
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

                // ── Interactive Action Bar ──
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
                      _buildPillAction(
                        icon: post.isLiked ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                        label: '${post.likes} ${post.likes == 1 ? 'Like' : 'Likes'}',
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
                      _buildPillAction(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: '${post.comments} ${post.comments == 1 ? 'Reply' : 'Replies'}',
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
                            builder: (context) => CommentsDialog(postId: post.id),
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
                        icon: const Icon(Icons.share_outlined, size: 18, color: _muted),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                        tooltip: 'Share story',
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

  Widget _buildPillAction({
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
            Icon(
              icon,
              size: 16,
              color: isActive ? activeColor : _muted,
            ),
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

  Widget _buildStoryOptionsMenu(ForumPostItem post) {
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
            const SnackBar(
              content: Text('Thank you. This story has been reported for moderation.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              Icon(Icons.share_outlined, size: 16, color: _dark),
              SizedBox(width: 8),
              Text('Share Link', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        if (post.userId != null)
          const PopupMenuItem(
            value: 'profile',
            child: Row(
              children: [
                Icon(Icons.storefront_outlined, size: 16, color: _dark),
                SizedBox(width: 8),
                Text('View Farm Profile', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'report',
          child: Row(
            children: [
              Icon(Icons.flag_outlined, size: 16, color: Colors.red),
              SizedBox(width: 8),
              Text('Report Post', style: TextStyle(fontSize: 13, color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SKELETON / EMPTY STATES
  // ─────────────────────────────────────────────────────────────
  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(3, (index) {
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
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 120, height: 12, color: const Color(0xFFF1F5F9)),
                        const SizedBox(height: 4),
                        Container(width: 60, height: 10, color: const Color(0xFFF8FAFC)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(width: double.infinity, height: 14, color: const Color(0xFFF1F5F9)),
                const SizedBox(height: 8),
                Container(width: 180, height: 12, color: const Color(0xFFF8FAFC)),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState() {
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
              child: const Icon(
                Icons.auto_stories_outlined,
                size: 36,
                color: _primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'No matching stories' : 'No community stories yet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try searching with different keywords or clearing filters.'
                  : 'Farming logs and harvest stories from local growers will appear here.',
              style: GoogleFonts.inter(fontSize: 13, color: _muted, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
