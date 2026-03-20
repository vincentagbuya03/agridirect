// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wishlist_item_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WishlistItem _$WishlistItemFromJson(Map<String, dynamic> json) => WishlistItem(
  wishlistId: json['wishlist_id'] as String,
  customerId: json['customer_id'] as String,
  productId: json['product_id'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
  productName: json['product_name'] as String?,
  price: (json['price'] as num?)?.toDouble(),
  productImage: json['product_image'] as String?,
  farmerId: json['farmer_id'] as String?,
  isPreorder: json['is_preorder'] as bool?,
  productQuantity: (json['product_quantity'] as num?)?.toDouble(),
  categoryName: json['category_name'] as String?,
  unitName: json['unit_name'] as String?,
  unitAbbr: json['unit_abbr'] as String?,
  farmName: json['farm_name'] as String?,
);

Map<String, dynamic> _$WishlistItemToJson(WishlistItem instance) =>
    <String, dynamic>{
      'wishlist_id': instance.wishlistId,
      'customer_id': instance.customerId,
      'product_id': instance.productId,
      'created_at': instance.createdAt.toIso8601String(),
      'product_name': instance.productName,
      'price': instance.price,
      'product_image': instance.productImage,
      'farmer_id': instance.farmerId,
      'is_preorder': instance.isPreorder,
      'product_quantity': instance.productQuantity,
      'category_name': instance.categoryName,
      'unit_name': instance.unitName,
      'unit_abbr': instance.unitAbbr,
      'farm_name': instance.farmName,
    };
