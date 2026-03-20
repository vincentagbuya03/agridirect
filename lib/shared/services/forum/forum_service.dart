// ============================================================================
// lib/shared/services/forum/forum_service.dart
// Community forum operations
// ============================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/forum/forum_post_model.dart';
import '../../models/forum/forum_comment_model.dart';

class ForumService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================================
  // FORUM POSTS OPERATIONS
  // ============================================================================

  /// Get all forum posts
  Future<List<ForumPost>> getPosts({int limit = 20, int offset = 0}) async {
    try {
      final response = await _supabase
          .from('v_forum_posts')
          .select()
          .range(offset, offset + limit - 1)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => ForumPost.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch posts: \$e');
    }
  }

  /// Get single post
  Future<ForumPost?> getPostById(String postId) async {
    try {
      final response = await _supabase
          .from('v_forum_posts')
          .select()
          .eq('post_id', postId)
          .single();

      return ForumPost.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Get user's posts
  Future<List<ForumPost>> getUserPosts(String userId,
      {int limit = 20}) async {
    try {
      final response = await _supabase
          .from('v_forum_posts')
          .select()
          .eq('user_id', userId)
          .limit(limit)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => ForumPost.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch user posts: \$e');
    }
  }

  /// Create forum post
  Future<ForumPost> createPost({
    required String title,
    required String body,
    String? imageUrl,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase.from('forum_posts').insert({
        'user_id': userId,
        'title': title,
        'body': body,
        'image_url': imageUrl,
      }).select().single();

      return ForumPost.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create post: \$e');
    }
  }

  /// Update post
  Future<ForumPost> updatePost(
    String postId, {
    String? title,
    String? body,
    String? imageUrl,
  }) async {
    try {
      final response = await _supabase
          .from('forum_posts')
          .update({
            'title': ?title,
            'body': ?body,
            'image_url': ?imageUrl,
          })
          .eq('post_id', postId)
          .select()
          .single();

      return ForumPost.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update post: \$e');
    }
  }

  /// Delete post
  Future<void> deletePost(String postId) async {
    try {
      await _supabase.from('forum_posts').delete().eq('post_id', postId);
    } catch (e) {
      throw Exception('Failed to delete post: \$e');
    }
  }

  // ============================================================================
  // FORUM COMMENTS OPERATIONS
  // ============================================================================

  /// Get post comments
  Future<List<ForumComment>> getPostComments(String postId,
      {int limit = 10}) async {
    try {
      final response = await _supabase
          .from('forum_comments')
          .select()
          .eq('post_id', postId)
          .limit(limit)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => ForumComment.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch comments: \$e');
    }
  }

  /// Create comment
  Future<ForumComment> createComment({
    required String postId,
    required String body,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase.from('forum_comments').insert({
        'post_id': postId,
        'user_id': userId,
        'body': body,
      }).select().single();

      return ForumComment.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create comment: \$e');
    }
  }

  /// Update comment
  Future<ForumComment> updateComment(String commentId, String body) async {
    try {
      final response = await _supabase
          .from('forum_comments')
          .update({'body': body})
          .eq('comment_id', commentId)
          .select()
          .single();

      return ForumComment.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update comment: \$e');
    }
  }

  /// Delete comment
  Future<void> deleteComment(String commentId) async {
    try {
      await _supabase
          .from('forum_comments')
          .delete()
          .eq('comment_id', commentId);
    } catch (e) {
      throw Exception('Failed to delete comment: \$e');
    }
  }

  // ============================================================================
  // POST LIKES OPERATIONS
  // ============================================================================

  /// Like post
  Future<void> likePost(String postId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase.from('post_likes').insert({
        'post_id': postId,
        'user_id': userId,
      });
    } catch (e) {
      throw Exception('Failed to like post: \$e');
    }
  }

  /// Unlike post
  Future<void> unlikePost(String postId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to unlike post: \$e');
    }
  }

  /// Check if user liked post
  Future<bool> hasUserLikedPost(String postId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('post_likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId);

      return (response as List<dynamic>).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Search posts
  Future<List<ForumPost>> searchPosts(String query) async {
    try {
      final response = await _supabase
          .from('v_forum_posts')
          .select()
          .or('title.ilike.%\$query%,body.ilike.%\$query%')
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => ForumPost.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to search posts: \$e');
    }
  }
}
