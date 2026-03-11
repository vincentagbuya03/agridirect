// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Product _$ProductFromJson(Map<String, dynamic> json) => Product(
  productId: json['productId'] as String,
  name: json['name'] as String,
  price: (json['price'] as num).toDouble(),
  description: json['description'] as String?,
  imageUrl: json['imageUrl'] as String?,
  harvestDays: (json['harvestDays'] as num?)?.toInt(),
  isPreorder: json['isPreorder'] as bool? ?? false,
  farmerId: json['farmerId'] as String,
  categoryId: json['categoryId'] as String,
  unitId: json['unitId'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  categoryName: json['categoryName'] as String?,
  unitName: json['unitName'] as String?,
  unitAbbr: json['unitAbbr'] as String?,
  farmName: json['farmName'] as String?,
  averageRating: (json['averageRating'] as num?)?.toDouble(),
  reviewCount: (json['reviewCount'] as num?)?.toInt(),
);

Map<String, dynamic> _$ProductToJson(Product instance) => <String, dynamic>{
  'productId': instance.productId,
  'name': instance.name,
  'price': instance.price,
  'description': instance.description,
  'imageUrl': instance.imageUrl,
  'harvestDays': instance.harvestDays,
  'isPreorder': instance.isPreorder,
  'farmerId': instance.farmerId,
  'categoryId': instance.categoryId,
  'unitId': instance.unitId,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'categoryName': instance.categoryName,
  'unitName': instance.unitName,
  'unitAbbr': instance.unitAbbr,
  'farmName': instance.farmName,
  'averageRating': instance.averageRating,
  'reviewCount': instance.reviewCount,
};
