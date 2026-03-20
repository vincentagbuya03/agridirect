// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Tag _$TagFromJson(Map<String, dynamic> json) => Tag(
  tagId: json['tag_id'] as String,
  name: json['name'] as String,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$TagToJson(Tag instance) => <String, dynamic>{
  'tag_id': instance.tagId,
  'name': instance.name,
  'created_at': instance.createdAt.toIso8601String(),
};
