// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Product _$ProductFromJson(Map<String, dynamic> json) => Product(
  productId: json['product_id'] as String,
  name: json['name'] as String,
  price: (json['price'] as num).toDouble(),
  description: json['description'] as String?,
  imageUrl: json['image_url'] as String?,
  harvestDays: (json['harvest_days'] as num?)?.toInt(),
  isPreorder: json['is_preorder'] as bool? ?? false,
  quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
  farmerId: json['farmer_id'] as String,
  categoryId: json['category_id'] as String,
  unitId: json['unit_id'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
  categoryName: json['category_name'] as String?,
  unitName: json['unit_name'] as String?,
  unitAbbr: json['unit_abbr'] as String?,
  farmName: json['farm_name'] as String?,
  averageRating: (json['average_rating'] as num?)?.toDouble(),
  reviewCount: (json['review_count'] as num?)?.toInt(),
);

Map<String, dynamic> _$ProductToJson(Product instance) => <String, dynamic>{
  'product_id': instance.productId,
  'name': instance.name,
  'price': instance.price,
  'description': instance.description,
  'image_url': instance.imageUrl,
  'harvest_days': instance.harvestDays,
  'is_preorder': instance.isPreorder,
  'quantity': instance.quantity,
  'farmer_id': instance.farmerId,
  'category_id': instance.categoryId,
  'unit_id': instance.unitId,
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt.toIso8601String(),
  'category_name': instance.categoryName,
  'unit_name': instance.unitName,
  'unit_abbr': instance.unitAbbr,
  'farm_name': instance.farmName,
  'average_rating': instance.averageRating,
  'review_count': instance.reviewCount,
};
