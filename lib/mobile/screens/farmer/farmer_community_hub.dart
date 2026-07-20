import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/widgets/create_post_dialog.dart';
import '../../../shared/widgets/comments_dialog.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/screens/post_detail_screen.dart';
import '../../../shared/screens/article_detail_screen.dart';
import '../../../shared/router/app_routes.dart';

import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/community/notification_service.dart';
import '../../../shared/widgets/forum_video_player.dart';

/// Farmer Community Hub - Professional Social Interface
class FarmerCommunityHub extends StatefulWidget {
  const FarmerCommunityHub({super.key});

  @override
  State<FarmerCommunityHub> createState() => _FarmerCommunityHubState();
}

class _FarmerCommunityHubState extends State<FarmerCommunityHub>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  late Stream<List<ForumPostItem>> _forumStream;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _forumStream = SupabaseDataService().watchForumPosts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Navigate to the public profile of a farmer by their user_id.
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildPremiumHeader(),
          _buildSearchBar(),
          _buildSleekTabs(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildForumContent(), _buildArticlesContent()],
            ),
          ),
        ],
      ),
      floatingActionButton: AuthService().isSeller
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await showDialog<bool>(
                  context: context,
                  builder: (context) => const CreatePostDialog(),
                );
                if (result == true && mounted) {
                  setState(() {});
                }
              },
              backgroundColor: AppColors.primary,
              elevation: 6,
              icon: const Icon(Icons.edit_square, color: Colors.white, size: 20),
              label: Text(
                'POST QUESTION',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildPremiumHeader() {
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                    ),
                    child: const ClipOval(
                      child: Icon(Icons.person_rounded, color: AppColors.textSubtle),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COMMUNITY',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'AgriDirect Hub',
                        style: AppTextStyles.headline2.copyWith(fontSize: 22),
                      ),
                    ],
                  ),
                ],
              ),
              _buildNotificationBadge(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationBadge() {
    final userId = AuthService().userId;
    return FutureBuilder<int>(
      future: NotificationService().getUnreadNotificationCount(userId),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return GestureDetector(
          onTap: () => context.push(AppRoutes.notifications),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.notifications_none_rounded, size: 24, color: AppColors.textHeadline),
              ),
              if (count > 0)
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
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Container(
        height: 52,
        decoration: AppDecorations.cardDecoration.copyWith(
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() => _searchQuery = value.trim().toLowerCase());
          },
          decoration: InputDecoration(
            hintText: 'Search pests, crops, or topics...',
            hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSubtle),
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSubtle, size: 22),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildSleekTabs() {
    return Container(
      width: double.infinity,
      color: Colors.transparent,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSubtle,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 3,
        dividerColor: Colors.transparent,
        labelStyle: AppTextStyles.labelSmall.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
        tabs: const [
          Tab(text: 'Forum'),
          Tab(text: 'Articles'),
        ],
      ),
    );
  }

  Widget _buildForumContent() {
    return StreamBuilder<List<ForumPostItem>>(
      stream: _forumStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load community posts right now.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSubtle,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final posts = (snapshot.data ?? [])
            .where((post) {
              if (_searchQuery.isEmpty) return true;
              final haystack =
                  '${post.userName} ${post.title} ${post.body}'.toLowerCase();
              return haystack.contains(_searchQuery);
            })
            .toList();

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.forum_outlined, size: 64, color: AppColors.textSubtle.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text('No posts yet', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSubtle)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          physics: const BouncingScrollPhysics(),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return InkWell(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PostDetailScreen(post: post),
                  ),
                );
                if (mounted) setState(() {});
              },
              borderRadius: BorderRadius.circular(24),
              child: _buildForumCard(post: post),
            );
          },
        );
      },
    );
  }

  Widget _buildArticlesContent() {
    return FutureBuilder<List<ArticleItem>>(
      future: SupabaseDataService().getArticles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final articles = (snapshot.data ?? [])
            .where((article) {
              if (_searchQuery.isEmpty) return true;
              final haystack =
                  '${article.title} ${article.author} ${article.excerpt} ${article.content ?? ''}'.toLowerCase();
              return haystack.contains(_searchQuery);
            })
            .toList();
        if (articles.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.article_outlined, size: 64, color: AppColors.textSubtle.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text('No articles yet', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSubtle)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          physics: const BouncingScrollPhysics(),
          itemCount: articles.length,
          itemBuilder: (context, index) {
            final article = articles[index];
            return InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ArticleDetailScreen(article: article)),
              ),
              borderRadius: BorderRadius.circular(24),
              child: _buildArticleCard(article: article),
            );
          },
        );
      },
    );
  }

  Widget _buildForumCard({required ForumPostItem post}) {
    final cleanTitle = post.title.trim();
    final cleanBody = post.body.trim();
    final bool showTitle = cleanTitle.isNotEmpty && cleanBody != cleanTitle;
    final String displayBody = (cleanBody.startsWith(cleanTitle) && cleanBody != cleanTitle)
        ? cleanBody.substring(cleanTitle.length).trim()
        : cleanBody;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: AppDecorations.cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _navigateToFarmerProfile(post.userId),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.3)),
                            ),
                            child: const Icon(Icons.person_rounded, size: 20, color: AppColors.textSubtle),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(post.userName, style: AppTextStyles.headline3.copyWith(fontSize: 15)),
                                  if (post.isPinned) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.push_pin_rounded, size: 10, color: AppColors.primary),
                                          const SizedBox(width: 4),
                                          Text(
                                            'PINNED',
                                            style: AppTextStyles.labelSmall.copyWith(
                                              color: AppColors.primary,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(post.time, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.more_horiz_rounded, color: AppColors.textSubtle),
                  ],
                ),
                const SizedBox(height: 16),
                if (showTitle) ...[
                  Text(post.title, style: AppTextStyles.headline3.copyWith(fontSize: 17, height: 1.3)),
                  const SizedBox(height: 8),
                ],
                if (displayBody.isNotEmpty)
                  Text(
                    displayBody,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHeadline.withValues(alpha: 0.7), height: 1.5),
                  ),
                if (post.videoUrl != null && post.videoUrl!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ForumVideoPlayer(videoUrl: post.videoUrl!),
                  ),
                ] else if (post.imageUrl != null) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: post.imageUrl!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.textHeadline.withValues(alpha: 0.1))),
            ),
            child: Row(
              children: [
                 _buildSocialAction(
                  post.isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                  '${post.likes}',
                  post.isLiked ? AppColors.primary : AppColors.textSubtle,
                  onTap: () async {
                    if (!AuthService().isLoggedIn) {
                      context.go(AppRoutes.login);
                      return;
                    }
                    await SupabaseDataService().togglePostLike(post.id);
                    if (mounted) setState(() {});
                  },
                ),
                const SizedBox(width: 24),
                _buildSocialAction(
                  Icons.chat_bubble_outline_rounded,
                  '${post.comments}',
                  AppColors.textSubtle,
                  onTap: () async {
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
                const Icon(Icons.share_outlined, size: 20, color: AppColors.textSubtle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialAction(
    IconData icon,
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleCard({required ArticleItem article}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: AppDecorations.cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RESOURCE GUIDE',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                  if (article.audience == 'FARMER') ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'FARMERS ONLY',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.warning,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ] else if (article.audience == 'CUSTOMER') ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'CUSTOMERS ONLY',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(article.title, style: AppTextStyles.headline3.copyWith(fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const CircleAvatar(radius: 8, backgroundColor: AppColors.primary, child: Icon(Icons.spa, size: 8, color: Colors.white)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'By ${article.author}',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.circle, size: 3, color: AppColors.textSubtle),
                      const SizedBox(width: 8),
                      Text(article.time, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 90,
                height: 90,
                color: AppColors.background,
                child: article.imageUrl != null && article.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: article.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Icon(Icons.article_outlined, color: AppColors.textSubtle),
                      errorWidget: (context, url, error) => const Icon(Icons.article_outlined, color: AppColors.textSubtle),
                    )
                  : const Icon(Icons.article_outlined, color: AppColors.textSubtle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
