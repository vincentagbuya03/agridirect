// ============================================================================
// lib/shared/models/product/tag_model.dart
// Product tag data model
// ============================================================================

import 'package:json_annotation/json_annotation.dart';

part 'tag_model.g.dart';

@JsonSerializable()
class Tag {
  @JsonKey(name: 'tag_id')
  final String tagId;
  final String name;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  Tag({required this.tagId, required this.name, DateTime? createdAt})
    : createdAt = createdAt ?? DateTime.now();

  factory Tag.fromJson(Map<String, dynamic> json) => _$TagFromJson(json);
  Map<String, dynamic> toJson() => _$TagToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tag && runtimeType == other.runtimeType && tagId == other.tagId;
  @override
  int get hashCode => tagId.hashCode;
}
