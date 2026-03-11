// ============================================================================
// lib/shared/models/forum/forum_comment_model.dart
// Forum comment data model
// ============================================================================

import 'package:json_annotation/json_annotation.dart';

part 'forum_comment_model.g.dart';

@JsonSerializable()
class ForumComment {
  final String commentId;
  final String postId;
  final String userId;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Related data for display
  final String? userName;
  final String? userAvatar;

  ForumComment({
    required this.commentId,
    required this.postId,
    required this.userId,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.userName,
    this.userAvatar,
  });

  factory ForumComment.fromJson(Map<String, dynamic> json) =>
      _$ForumCommentFromJson(json);
  Map<String, dynamic> toJson() => _$ForumCommentToJson(this);

  ForumComment copyWith({
    String? commentId,
    String? postId,
    String? userId,
    String? body,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userName,
    String? userAvatar,
  }) {
    return ForumComment(
      commentId: commentId ?? this.commentId,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
    );
  }
}
