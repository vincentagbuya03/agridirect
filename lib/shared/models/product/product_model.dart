// ============================================================================
// lib/shared/models/product/product_model.dart
// Product listing data model
// ============================================================================

import 'package:json_annotation/json_annotation.dart';

part 'product_model.g.dart';

@JsonSerializable()
class Product {
  @JsonKey(name: 'product_id')
  final String productId;
  final String name;
  final double price;
  final String? description;
  @JsonKey(name: 'image_url')
  final String? imageUrl;
  @JsonKey(name: 'harvest_days')
  final int? harvestDays;
  @JsonKey(name: 'is_preorder')
  final bool isPreorder;
  final double quantity;
  @JsonKey(name: 'farmer_id')
  final String farmerId;
  @JsonKey(name: 'category_id')
  final String categoryId;
  @JsonKey(name: 'unit_id')
  final String unitId;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  // Computed fields from view
  @JsonKey(name: 'category_name')
  final String? categoryName;
  @JsonKey(name: 'unit_name')
  final String? unitName;
  @JsonKey(name: 'unit_abbr')
  final String? unitAbbr;
  @JsonKey(name: 'farm_name')
  final String? farmName;
  @JsonKey(name: 'average_rating')
  final double? averageRating;
  @JsonKey(name: 'review_count')
  final int? reviewCount;

  Product({
    required this.productId,
    required this.name,
    required this.price,
    this.description,
    this.imageUrl,
    this.harvestDays,
    this.isPreorder = false,
    this.quantity = 0,
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
    double? quantity,
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
      quantity: quantity ?? this.quantity,
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
