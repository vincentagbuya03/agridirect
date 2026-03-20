// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'farmer_rating_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FarmerRating _$FarmerRatingFromJson(Map<String, dynamic> json) => FarmerRating(
  ratingId: json['rating_id'] as String,
  farmerId: json['farmer_id'] as String,
  customerId: json['customer_id'] as String,
  orderId: json['order_id'] as String?,
  rating: (json['rating'] as num).toDouble(),
  reviewText: json['review_text'] as String?,
  categories: json['categories'] as Map<String, dynamic>?,
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
  customerName: json['customer_name'] as String?,
  customerAvatar: json['customer_avatar'] as String?,
  farmName: json['farm_name'] as String?,
);

Map<String, dynamic> _$FarmerRatingToJson(FarmerRating instance) =>
    <String, dynamic>{
      'rating_id': instance.ratingId,
      'farmer_id': instance.farmerId,
      'customer_id': instance.customerId,
      'order_id': instance.orderId,
      'rating': instance.rating,
      'review_text': instance.reviewText,
      'categories': instance.categories,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'customer_name': instance.customerName,
      'customer_avatar': instance.customerAvatar,
      'farm_name': instance.farmName,
    };
