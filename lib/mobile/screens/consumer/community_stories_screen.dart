import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/screens/post_detail_screen.dart';
import '../../../shared/widgets/image_widgets.dart';
import '../../../shared/widgets/forum_video_player.dart';
import '../../../shared/widgets/app_shimmer_loader.dart';

class CommunityStoriesScreen extends StatefulWidget {
  const CommunityStoriesScreen({super.key});

  @override
  State<CommunityStoriesScreen> createState() => _CommunityStoriesScreenState();
}

class _CommunityStoriesScreenState extends State<CommunityStoriesScreen> {
  late Stream<List<ForumPostItem>> _forumStream;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textHeadline),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Community Stories',
          style: GoogleFonts.poppins(
            color: AppColors.textHeadline,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: _buildSearchBar(),
          ),
        ),
      ),
      body: StreamBuilder<List<ForumPostItem>>(
        stream: _forumStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: AppShimmerLoader());
          }

          final List<ForumPostItem> posts = snapshot.data ?? const <ForumPostItem>[];
          final filteredPosts = posts.where((post) {
            final query = _searchQuery.toLowerCase();
            return post.userName.toLowerCase().contains(query) ||
                post.title.toLowerCase().contains(query) ||
                post.body.toLowerCase().contains(query);
          }).toList();

          if (filteredPosts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 64,
                      color: AppColors.textSubtle.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isEmpty
                          ? 'No community stories available yet.'
                          : 'No stories match your search.',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSubtle),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 20),
            physics: const BouncingScrollPhysics(),
            itemCount: filteredPosts.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _buildCommunityPostCard(post: filteredPosts[index]),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textHeadline.withValues(alpha: 0.08),
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search stories, farmers, crops...',
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSubtle,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textSubtle,
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCommunityPostCard({required ForumPostItem post}) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
        ).then((_) {
          if (mounted) setState(() {});
        });
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
                  post.isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined,
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
                    ).then((_) {
                      if (mounted) setState(() {});
                    });
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
}
