// ============================================================================
// lib/shared/models/product/product_model.dart
// Product listing data model
// ============================================================================

import 'package:json_annotation/json_annotation.dart';

part 'product_model.g.dart';

@JsonSerializable()
class Product {
  final String productId;
  final String name;
  final double price;
  final String? description;
  final String? imageUrl;
  final int? harvestDays;
  final bool isPreorder;
  final String farmerId;
  final String categoryId;
  final String unitId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Computed fields from view
  final String? categoryName;
  final String? unitName;
  final String? unitAbbr;
  final String? farmName;
  final double? averageRating;
  final int? reviewCount;

  Product({
    required this.productId,
    required this.name,
    required this.price,
    this.description,
    this.imageUrl,
    this.harvestDays,
    this.isPreorder = false,
    required this.farmerId,
    required this.categoryId,
    required this.unitId,
    required this.createdAt,
    required this.updatedAt,
    this.categoryName,
    this.unitName,
    this.unitAbbr,
    this.farmName,
    this.averageRating,
    this.reviewCount,
  });

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);
  Map<String, dynamic> toJson() => _$ProductToJson(this);

  Product copyWith({
    String? productId,
    String? name,
    double? price,
    String? description,
    String? imageUrl,
    int? harvestDays,
    bool? isPreorder,
    String? farmerId,
    String? categoryId,
    String? unitId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? categoryName,
    String? unitName,
    String? unitAbbr,
    String? farmName,
    double? averageRating,
    int? reviewCount,
  }) {
    return Product(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      harvestDays: harvestDays ?? this.harvestDays,
      isPreorder: isPreorder ?? this.isPreorder,
      farmerId: farmerId ?? this.farmerId,
      categoryId: categoryId ?? this.categoryId,
      unitId: unitId ?? this.unitId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      categoryName: categoryName ?? this.categoryName,
      unitName: unitName ?? this.unitName,
      unitAbbr: unitAbbr ?? this.unitAbbr,
      farmName: farmName ?? this.farmName,
      averageRating: averageRating ?? this.averageRating,
      reviewCount: reviewCount ?? this.reviewCount,
    );
  }
}
