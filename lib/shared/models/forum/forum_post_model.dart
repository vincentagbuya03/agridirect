// ============================================================================
// lib/shared/models/forum/forum_post_model.dart
// Forum post data model
// ============================================================================

import 'package:json_annotation/json_annotation.dart';

part 'forum_post_model.g.dart';

@JsonSerializable()
class ForumPost {
  final String postId;
  final String userId;
  final String title;
  final String body;
  final String? imageUrl;
  final String? videoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Related data from view
  final String? authorName;
  final String? authorAvatar;
  final int? likesCount;
  final int? commentsCount;

  ForumPost({
    required this.postId,
    required this.userId,
    required this.title,
    required this.body,
    this.imageUrl,
    this.videoUrl,
    required this.createdAt,
    required this.updatedAt,
    this.authorName,
    this.authorAvatar,
    this.likesCount,
    this.commentsCount,
  });

  factory ForumPost.fromJson(Map<String, dynamic> json) {
    final normalized = <String, dynamic>{
      'postId': json['postId'] ?? json['post_id'],
      'userId': json['userId'] ?? json['user_id'],
      'title': json['title'],
      'body': json['body'],
      'imageUrl': json['imageUrl'] ?? json['image_url'],
      'videoUrl': json['videoUrl'] ?? json['video_url'],
      'createdAt': json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String(),
      'updatedAt':
          json['updatedAt'] ?? json['updated_at'] ?? json['created_at'] ?? DateTime.now().toIso8601String(),
      'authorName': json['authorName'] ?? json['author_name'],
      'authorAvatar': json['authorAvatar'] ?? json['author_avatar'],
      'likesCount': json['likesCount'] ?? json['likes_count'],
      'commentsCount': json['commentsCount'] ?? json['comments_count'],
    };
    return _$ForumPostFromJson(normalized);
  }
  Map<String, dynamic> toJson() => _$ForumPostToJson(this);

  ForumPost copyWith({
    String? postId,
    String? userId,
    String? title,
    String? body,
    String? imageUrl,
    String? videoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? authorName,
    String? authorAvatar,
    int? likesCount,
    int? commentsCount,
  }) {
    return ForumPost(
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
    );
  }
}
