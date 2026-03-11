// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Category _$CategoryFromJson(Map<String, dynamic> json) => Category(
  categoryId: json['categoryId'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  icon: json['icon'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$CategoryToJson(Category instance) => <String, dynamic>{
  'categoryId': instance.categoryId,
  'name': instance.name,
  'description': instance.description,
  'icon': instance.icon,
  'createdAt': instance.createdAt.toIso8601String(),
};
