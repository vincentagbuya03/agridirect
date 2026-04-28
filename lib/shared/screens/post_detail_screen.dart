import 'package:flutter/material.dart';
import '../../shared/styles/app_theme.dart';
import '../../shared/data/app_data.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/comments_dialog.dart';
import '../widgets/report_content_dialog.dart';
import '../services/core/supabase_data_service.dart';

class PostDetailScreen extends StatefulWidget {
  final ForumPostItem post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late ForumPostItem _post;
  bool _isUpdatingLike = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  Future<void> _refreshPost() async {
    final latest = await SupabaseDataService().getForumPostById(_post.id);
    if (latest != null && mounted) {
      setState(() => _post = latest);
    }
  }

  Future<void> _toggleLike() async {
    if (_isUpdatingLike) return;

    final wasLiked = _post.isLiked;
    final nextLikes = wasLiked ? (_post.likes - 1) : (_post.likes + 1);

    setState(() {
      _isUpdatingLike = true;
      _post = ForumPostItem(
        id: _post.id,
        userId: _post.userId,
        userName: _post.userName,
        time: _post.time,
        title: _post.title,
        body: _post.body,
        imageUrl: _post.imageUrl,
        likes: nextLikes < 0 ? 0 : nextLikes,
        comments: _post.comments,
        isLiked: !wasLiked,
      );
    });

    await SupabaseDataService().togglePostLike(_post.id);
    await _refreshPost();

    if (mounted) {
      setState(() => _isUpdatingLike = false);
    }
  }

  Future<void> _openComments() async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => CommentsDialog(postId: _post.id),
    );
    if (updated == true) {
      await _refreshPost();
    }
  }

  Future<void> _openReportDialog() async {
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => ReportContentDialog(
        contentLabel: 'post',
        contentTitle: _post.title,
        onSubmit: (reason, details) {
          return SupabaseDataService().reportForumPost(
            postId: _post.id,
            reason: reason,
            description: details,
          );
        },
      ),
    );

    if (submitted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted. Our team will review it soon.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textHeadline),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Forum Post', style: AppTextStyles.headline3),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.textHeadline),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.textHeadline),
            onPressed: _openReportDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
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
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        child: Text(
                          _post.userName[0].toUpperCase(),
                          style: AppTextStyles.headline3.copyWith(
                            color: AppColors.primary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_post.userName, style: AppTextStyles.headline3.copyWith(fontSize: 14)),
                          Text(_post.time, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(_post.title, style: AppTextStyles.headline2.copyWith(fontSize: 22)),
                  const SizedBox(height: 16),
                  Text(_post.body, style: AppTextStyles.bodyMedium.copyWith(height: 1.6, color: AppColors.textBody.withValues(alpha: 0.85))),
                ],
              ),
            ),
            if (_post.imageUrl != null && _post.imageUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: CachedNetworkImage(
                    imageUrl: _post.imageUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: AppColors.background,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => const SizedBox.shrink(),
                  ),
                ),
              ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Divider(color: AppColors.background),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  InkWell(
                    onTap: _toggleLike,
                    borderRadius: BorderRadius.circular(10),
                    child: _buildStat(
                      _post.isLiked ? Icons.favorite : Icons.favorite_border,
                      _post.likes.toString(),
                      _post.isLiked ? AppColors.error : AppColors.textSubtle,
                    ),
                  ),
                  const SizedBox(width: 24),
                  InkWell(
                    onTap: _openComments,
                    borderRadius: BorderRadius.circular(10),
                    child: _buildStat(
                      Icons.chat_bubble_outline,
                      _post.comments.toString(),
                      AppColors.textSubtle,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.bookmark_border, color: AppColors.textSubtle),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // Placeholder for comments section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Comments (${_post.comments})', style: AppTextStyles.headline3),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.chat_outlined, size: 48, color: AppColors.textSubtle.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text('No comments yet', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _openComments,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Text('Add a comment...', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: _openComments,
              borderRadius: BorderRadius.circular(24),
              child: const CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 6),
        Text(value, style: AppTextStyles.labelSmall.copyWith(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
