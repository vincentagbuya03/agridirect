import 'package:flutter/material.dart';
import '../styles/app_theme.dart';
import '../services/community/forum_service.dart';
import '../models/forum/forum_comment_model.dart';

class CommentsDialog extends StatefulWidget {
  final String postId;

  const CommentsDialog({super.key, required this.postId});

  @override
  State<CommentsDialog> createState() => _CommentsDialogState();
}

class _CommentsDialogState extends State<CommentsDialog> {
  final _forumService = ForumService();
  final _commentController = TextEditingController();
  List<ForumComment> _comments = [];
  bool _isLoading = true;
  bool _isPosting = false;
  final Set<String> _likedCommentIds = {}; // We'll keep local state for liked comments for now

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final comments = await _forumService.getPostComments(widget.postId);
      // Fetch likes status
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
          _likedCommentIds.addAll(likedIds);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load comments: $e')));
      }
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isPosting = true);
    try {
      final newComment = await _forumService.createComment(
        postId: widget.postId,
        body: _commentController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _comments.insert(0, newComment);
          _commentController.clear();
          _isPosting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPosting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post comment: $e')));
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
      // Revert on error
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

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SafeArea(
        child: SizedBox(
          width: size.width > 700 ? 600 : size.width - 24,
          height: size.height > 860 ? 800 : size.height * 0.8,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Comments',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textHeadline),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.close_rounded, color: AppColors.textSubtle),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _comments.isEmpty
                          ? const Center(child: Text('No comments yet. Be the first!', style: TextStyle(color: AppColors.textSubtle)))
                          : ListView.builder(
                              itemCount: _comments.length,
                              itemBuilder: (context, index) {
                                final comment = _comments[index];
                                final isLiked = _likedCommentIds.contains(comment.commentId);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                        child: Text(
                                          (comment.userName ?? 'U')[0].toUpperCase(),
                                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppColors.surface,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: AppColors.textSubtle.withValues(alpha: 0.2)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                comment.userName ?? 'Anonymous',
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHeadline),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(comment.body, style: const TextStyle(color: AppColors.textSubtle)),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  GestureDetector(
                                                    onTap: () => _toggleCommentLike(comment.commentId),
                                                    child: Icon(
                                                      isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                                                      size: 16,
                                                      color: isLiked ? AppColors.primary : AppColors.textSubtle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(isLiked ? 'Liked' : 'Like', style: TextStyle(fontSize: 12, color: isLiked ? AppColors.primary : AppColors.textSubtle)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                          filled: true,
                          fillColor: AppColors.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (_) => _postComment(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _isPosting ? null : _postComment,
                      icon: _isPosting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded, color: AppColors.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
