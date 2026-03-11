// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'forum_comment_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ForumComment _$ForumCommentFromJson(Map<String, dynamic> json) => ForumComment(
  commentId: json['commentId'] as String,
  postId: json['postId'] as String,
  userId: json['userId'] as String,
  body: json['body'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  userName: json['userName'] as String?,
  userAvatar: json['userAvatar'] as String?,
);

Map<String, dynamic> _$ForumCommentToJson(ForumComment instance) =>
    <String, dynamic>{
      'commentId': instance.commentId,
      'postId': instance.postId,
      'userId': instance.userId,
      'body': instance.body,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'userName': instance.userName,
      'userAvatar': instance.userAvatar,
    };
