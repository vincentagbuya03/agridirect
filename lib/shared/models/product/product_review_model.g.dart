// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_review_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductReview _$ProductReviewFromJson(Map<String, dynamic> json) =>
    ProductReview(
      reviewId: json['reviewId'] as String,
      productId: json['productId'] as String,
      userId: json['userId'] as String,
      rating: (json['rating'] as num).toDouble(),
      reviewText: json['reviewText'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      userName: json['userName'] as String?,
      userAvatar: json['userAvatar'] as String?,
    );

Map<String, dynamic> _$ProductReviewToJson(ProductReview instance) =>
    <String, dynamic>{
      'reviewId': instance.reviewId,
      'productId': instance.productId,
      'userId': instance.userId,
      'rating': instance.rating,
      'reviewText': instance.reviewText,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'userName': instance.userName,
      'userAvatar': instance.userAvatar,
    };
