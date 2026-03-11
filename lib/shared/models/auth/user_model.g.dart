// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
  userId: json['userId'] as String,
  email: json['email'] as String,
  name: json['name'] as String,
  phone: json['phone'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
  bio: json['bio'] as String?,
  emailVerified: json['emailVerified'] as bool? ?? false,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  roles: (json['roles'] as List<dynamic>?)?.map((e) => e as String).toList(),
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'userId': instance.userId,
  'email': instance.email,
  'name': instance.name,
  'phone': instance.phone,
  'avatarUrl': instance.avatarUrl,
  'bio': instance.bio,
  'emailVerified': instance.emailVerified,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'roles': instance.roles,
};
