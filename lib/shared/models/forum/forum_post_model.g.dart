// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'forum_post_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ForumPost _$ForumPostFromJson(Map<String, dynamic> json) => ForumPost(
  postId: json['postId'] as String,
  userId: json['userId'] as String,
  title: json['title'] as String,
  body: json['body'] as String,
  imageUrl: json['imageUrl'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  authorName: json['authorName'] as String?,
  authorAvatar: json['authorAvatar'] as String?,
  likesCount: (json['likesCount'] as num?)?.toInt(),
  commentsCount: (json['commentsCount'] as num?)?.toInt(),
);

Map<String, dynamic> _$ForumPostToJson(ForumPost instance) => <String, dynamic>{
  'postId': instance.postId,
  'userId': instance.userId,
  'title': instance.title,
  'body': instance.body,
  'imageUrl': instance.imageUrl,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'authorName': instance.authorName,
  'authorAvatar': instance.authorAvatar,
  'likesCount': instance.likesCount,
  'commentsCount': instance.commentsCount,
};
