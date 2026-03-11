// ============================================================================
// lib/shared/models/product/category_model.dart
// Product category data model
// ============================================================================

import 'package:json_annotation/json_annotation.dart';

part 'category_model.g.dart';

@JsonSerializable()
class Category {
  final String categoryId;
  final String name;
  final String? description;
  final String? icon;
  final DateTime createdAt;

  Category({
    required this.categoryId,
    required this.name,
    this.description,
    this.icon,
    required this.createdAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
  Map<String, dynamic> toJson() => _$CategoryToJson(this);

  Category copyWith({
    String? categoryId,
    String? name,
    String? description,
    String? icon,
    DateTime? createdAt,
  }) {
    return Category(
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
