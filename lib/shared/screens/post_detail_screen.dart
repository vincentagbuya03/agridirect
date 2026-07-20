import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/styles/app_theme.dart';
import '../../shared/data/app_data.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/comments_dialog.dart';
import '../widgets/report_content_dialog.dart';
import '../services/core/supabase_data_service.dart';
import '../widgets/forum_video_player.dart';
import '../services/auth/auth_service.dart';
import '../router/app_routes.dart';
import '../services/community/forum_service.dart';
import '../models/forum/forum_comment_model.dart';

class PostDetailScreen extends StatefulWidget {
  final ForumPostItem post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late ForumPostItem _post;
  bool _isUpdatingLike = false;

  final _forumService = ForumService();
  final _commentController = TextEditingController();
  List<ForumComment> _comments = [];
  bool _isLoadingComments = true;
  bool _isPosting = false;
  final Set<String> _likedCommentIds = {};

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    if (!mounted) return;
    setState(() => _isLoadingComments = true);
    try {
      final comments = await _forumService.getPostComments(_post.id);
      final likedIds = <String>{};
      for (final comment in comments) {
        final isLiked = await _forumService.hasUserLikedComment(comment.commentId);
        if (isLiked) {
          likedIds.add(comment.commentId);
        }
      }
      if (mounted) {
        setState(() {
          _comments = comments;
          _likedCommentIds.clear();
          _likedCommentIds.addAll(likedIds);
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingComments = false);
      }
    }
  }

  Future<void> _postComment() async {
    if (!AuthService().isLoggedIn) {
      context.go(AppRoutes.login);
      return;
    }
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPosting = true);
    try {
      final newComment = await _forumService.createComment(
        postId: _post.id,
        body: text,
      );
      if (mounted) {
        setState(() {
          _comments.insert(0, newComment);
          _commentController.clear();
          _isPosting = false;
          _post = _post.copyWith(
            comments: _post.comments + 1,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPosting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    }
  }

  Future<void> _toggleCommentLike(String commentId) async {
    if (!AuthService().isLoggedIn) {
      context.go(AppRoutes.login);
      return;
    }
    final isLiked = _likedCommentIds.contains(commentId);
    setState(() {
      if (isLiked) {
        _likedCommentIds.remove(commentId);
      } else {
        _likedCommentIds.add(commentId);
      }
    });

    try {
      if (isLiked) {
        await _forumService.unlikeComment(commentId);
      } else {
        await _forumService.likeComment(commentId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (isLiked) {
            _likedCommentIds.add(commentId);
          } else {
            _likedCommentIds.remove(commentId);
          }
        });
      }
    }
  }

  Future<void> _reportComment(ForumComment comment) async {
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => ReportContentDialog(
        contentLabel: 'comment',
        contentTitle: comment.body,
        onSubmit: (reason, details) {
          return SupabaseDataService().reportForumComment(
            commentId: comment.commentId,
            reason: reason,
            description: details,
          );
        },
      ),
    );

    if (submitted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comment reported. Our team will review it soon.'),
        ),
      );
    }
  }

  Future<void> _refreshPost() async {
    final latest = await SupabaseDataService().getForumPostById(_post.id);
    if (latest != null && mounted) {
      setState(() => _post = latest);
    }
    await _loadComments();
  }

  Future<void> _toggleLike() async {
    if (!AuthService().isLoggedIn) {
      context.go(AppRoutes.login);
      return;
    }
    if (_isUpdatingLike) return;

    final wasLiked = _post.isLiked;
    final nextLikes = wasLiked ? (_post.likes - 1) : (_post.likes + 1);

    setState(() {
      _isUpdatingLike = true;
      _post = _post.copyWith(
        likes: nextLikes < 0 ? 0 : nextLikes,
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
    if (!AuthService().isLoggedIn) {
      context.go(AppRoutes.login);
      return;
    }
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
    final cleanTitle = _post.title.trim();
    final cleanBody = _post.body.trim();
    final bool showTitle = cleanTitle.isNotEmpty && cleanBody != cleanTitle;
    final String displayBody = (cleanBody.startsWith(cleanTitle) && cleanBody != cleanTitle)
        ? cleanBody.substring(cleanTitle.length).trim()
        : cleanBody;

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
                  if (showTitle) ...[
                    Text(_post.title, style: AppTextStyles.headline2.copyWith(fontSize: 22)),
                    const SizedBox(height: 16),
                  ],
                  if (displayBody.isNotEmpty)
                    Text(
                      displayBody,
                      style: AppTextStyles.bodyMedium.copyWith(height: 1.6, color: AppColors.textBody.withValues(alpha: 0.85)),
                    ),
                ],
              ),
            ),
            if (_post.videoUrl != null && _post.videoUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: ForumVideoPlayer(videoUrl: _post.videoUrl!),
                ),
              )
            else if (_post.imageUrl != null && _post.imageUrl!.isNotEmpty)
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
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Comments (${_post.comments})', style: AppTextStyles.headline3),
            ),
            const SizedBox(height: 10),
            if (_isLoadingComments)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            else if (_comments.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.chat_outlined, size: 48, color: AppColors.textSubtle.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text('No comments yet', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle)),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _comments.length,
                itemBuilder: (context, index) => _buildCommentItemWidget(_comments[index]),
              ),
            const SizedBox(height: 20),
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
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _postComment(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _isPosting ? null : _postComment,
              child: CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary,
                child: _isPosting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 20),
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

  Widget _buildCommentItemWidget(ForumComment comment) {
    final isLiked = _likedCommentIds.contains(comment.commentId);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              (comment.userName ?? 'U')[0].toUpperCase(),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.textSubtle.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          comment.userName ?? 'Anonymous',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textHeadline,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        onSelected: (value) {
                          if (value == 'report') {
                            _reportComment(comment);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem<String>(
                            value: 'report',
                            child: Text('Report comment'),
                          ),
                        ],
                        child: const Icon(
                          Icons.more_horiz_rounded,
                          size: 18,
                          color: AppColors.textSubtle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment.body,
                    style: const TextStyle(color: AppColors.textSubtle),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _toggleCommentLike(comment.commentId),
                        child: Icon(
                          isLiked
                              ? Icons.thumb_up_rounded
                              : Icons.thumb_up_outlined,
                          size: 16,
                          color: isLiked ? AppColors.primary : AppColors.textSubtle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isLiked ? 'Liked' : 'Like',
                        style: TextStyle(
                          fontSize: 12,
                          color: isLiked ? AppColors.primary : AppColors.textSubtle,
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
    );
  }
}
