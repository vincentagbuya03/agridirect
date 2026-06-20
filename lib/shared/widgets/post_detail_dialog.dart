import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../styles/app_theme.dart';
import '../data/app_data.dart';
import '../services/community/forum_service.dart';
import '../services/core/supabase_data_service.dart';
import '../models/forum/forum_comment_model.dart';
import '../widgets/image_widgets.dart';
import 'report_content_dialog.dart';

class PostDetailDialog extends StatefulWidget {
  final ForumPostItem post;

  const PostDetailDialog({super.key, required this.post});

  @override
  State<PostDetailDialog> createState() => _PostDetailDialogState();
}

class _PostDetailDialogState extends State<PostDetailDialog> {
  final _forumService = ForumService();
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  
  late ForumPostItem _currentPost;
  List<ForumComment> _comments = [];
  bool _isLoadingComments = true;
  bool _isPostingComment = false;
  final Set<String> _likedCommentIds = {};

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoadingComments = true);
    try {
      final comments = await _forumService.getPostComments(_currentPost.id);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load comments: $e')),
        );
      }
    }
  }

  Future<void> _togglePostLike() async {
    final wasLiked = _currentPost.isLiked;
    final newLikes = wasLiked ? _currentPost.likes - 1 : _currentPost.likes + 1;
    
    setState(() {
      _currentPost = ForumPostItem(
        id: _currentPost.id,
        userId: _currentPost.userId,
        userName: _currentPost.userName,
        time: _currentPost.time,
        title: _currentPost.title,
        body: _currentPost.body,
        imageUrl: _currentPost.imageUrl,
        likes: newLikes,
        comments: _currentPost.comments,
        isLiked: !wasLiked,
        isPinned: _currentPost.isPinned,
        authorAvatarUrl: _currentPost.authorAvatarUrl,
      );
    });

    try {
      await SupabaseDataService().togglePostLike(_currentPost.id);
    } catch (e) {
      // Revert local state on error
      if (mounted) {
        setState(() {
          _currentPost = widget.post;
        });
      }
    }
  }

  Future<void> _postComment() async {
    final commentBody = _commentController.text.trim();
    if (commentBody.isEmpty) return;

    setState(() => _isPostingComment = true);
    try {
      final newComment = await _forumService.createComment(
        postId: _currentPost.id,
        body: commentBody,
      );
      if (mounted) {
        setState(() {
          _comments.insert(0, newComment);
          _commentController.clear();
          _isPostingComment = false;
          // Increment comment count locally
          _currentPost = ForumPostItem(
            id: _currentPost.id,
            userId: _currentPost.userId,
            userName: _currentPost.userName,
            time: _currentPost.time,
            title: _currentPost.title,
            body: _currentPost.body,
            imageUrl: _currentPost.imageUrl,
            likes: _currentPost.likes,
            comments: _currentPost.comments + 1,
            isLiked: _currentPost.isLiked,
            isPinned: _currentPost.isPinned,
            authorAvatarUrl: _currentPost.authorAvatarUrl,
          );
        });
        
        // Scroll to top of comments list
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPostingComment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    }
  }

  Future<void> _toggleCommentLike(String commentId) async {
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
        const SnackBar(content: Text('Comment reported. Our team will review it.')),
      );
    }
  }

  void _viewFullScreenImage(BuildContext context) {
    if (_currentPost.imageUrl == null) return;
    
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (context) => Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            child: Center(
              child: SafeNetworkImage(
                imageUrl: _currentPost.imageUrl,
                defaultBucket: 'uploads',
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            top: 24,
            right: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Material(
                color: Colors.black45,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900 && _currentPost.imageUrl != null && _currentPost.imageUrl!.isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 1100 : 650,
          maxHeight: size.height > 850 ? 780 : size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: isDesktop ? _buildSplitLayout(context) : _buildSingleColumnLayout(context),
        ),
      ),
    );
  }

  // ─── Split Layout (Desktop Style Lightbox) ───
  Widget _buildSplitLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Side: Immersive Image Viewer
        Expanded(
          flex: 6,
          child: GestureDetector(
            onTap: () => _viewFullScreenImage(context),
            child: Container(
              color: const Color(0xFF0F172A), // Sleek Facebook dark bg
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: SafeNetworkImage(
                      imageUrl: _currentPost.imageUrl,
                      defaultBucket: 'uploads',
                      fit: BoxFit.contain,
                    ),
                  ),
                  // Hover indication / zoom button
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Right Side: Post content and comments
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.white,
            child: _buildCommentsSection(context, showPostHeader: true),
          ),
        ),
      ],
    );
  }

  // ─── Single Column Layout (Mobile Style) ───
  Widget _buildSingleColumnLayout(BuildContext context) {
    return Container(
      color: Colors.white,
      child: _buildCommentsSection(context, showPostHeader: true),
    );
  }

  // ─── Combined Post details + comments feed ───
  Widget _buildCommentsSection(BuildContext context, {required bool showPostHeader}) {
    return Column(
      children: [
        // Top Bar Header with Close Button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Post Details',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1),
        
        // Scrollable List containing Post Header, Post Description, and Comments
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              if (showPostHeader) ...[
                _buildPostHeaderWidget(context),
                const SizedBox(height: 16),
              ],
              
              const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 12),
              
              // Comments header count
              Row(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Text(
                    'Comments (${_comments.length})',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Comments Feed Loader
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
                    child: Text(
                      'No comments yet. Be the first to reply!',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                    ),
                  ),
                )
              else
                ..._comments.map((comment) => _buildCommentItemWidget(comment)),
            ],
          ),
        ),

        const Divider(height: 1, thickness: 1),
        
        // Comment input at the bottom
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _commentController,
                    style: GoogleFonts.inter(fontSize: 14),
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _postComment(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _isPostingComment ? null : _postComment,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: _isPostingComment
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Post Card Header Rendered Inside Detail Panel ───
  Widget _buildPostHeaderWidget(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final showImageInline = size.width <= 900; // Inline image only if not split-view

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Author profile row
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1.5),
              ),
              child: ClipOval(
                child: SafeNetworkImage(
                  imageUrl: _currentPost.authorAvatarUrl,
                  defaultBucket: 'uploads',
                  fit: BoxFit.cover,
                  placeholder: Container(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    child: Center(
                      child: Text(
                        _currentPost.userName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase(),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
                  ),
                  errorWidget: Container(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    child: Center(
                      child: Text(
                        _currentPost.userName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase(),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
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
                    _currentPost.userName,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                  ),
                  Text(
                    _currentPost.time,
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Title and body
        if (_currentPost.title.isNotEmpty) ...[
          Text(
            _currentPost.title,
            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          _currentPost.body,
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF334155), height: 1.5),
        ),

        // Inline image (For single column mode)
        if (showImageInline && _currentPost.imageUrl != null && _currentPost.imageUrl!.isNotEmpty) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => _viewFullScreenImage(context),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                color: const Color(0xFFF8FAFC),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: SafeNetworkImage(
                      imageUrl: _currentPost.imageUrl,
                      defaultBucket: 'uploads',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),

        // Like Count Summary Row
        Row(
          children: [
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
              '${_currentPost.likes} Likes',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Interaction Action Row
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: _togglePostLike,
                icon: Icon(
                  _currentPost.isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined,
                  size: 18,
                  color: _currentPost.isLiked ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
                ),
                label: Text(
                  'Like',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _currentPost.isLiked ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF64748B)),
                label: Text(
                  'Comment',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Single Comment Item Widget ───
  Widget _buildCommentItemWidget(ForumComment comment) {
    final isLiked = _likedCommentIds.contains(comment.commentId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              (comment.userName ?? 'U')[0].toUpperCase(),
              style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Comment bubble container
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            comment.userName ?? 'Anonymous',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                          ),
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            iconSize: 14,
                            onSelected: (value) {
                              if (value == 'report') {
                                _reportComment(comment);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem<String>(
                                value: 'report',
                                child: Text('Report comment', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                            child: const Icon(Icons.more_horiz_rounded, size: 14, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        comment.body,
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                
                // Comment like actions row
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _toggleCommentLike(comment.commentId),
                        child: Text(
                          'Like',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: isLiked ? FontWeight.w800 : FontWeight.w500,
                            color: isLiked ? AppColors.primary : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
