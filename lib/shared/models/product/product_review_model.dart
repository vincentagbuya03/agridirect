// ============================================================================
// lib/shared/models/product/product_review_model.dart
// Product review data model
// ============================================================================

import 'package:json_annotation/json_annotation.dart';

part 'product_review_model.g.dart';

@JsonSerializable()
class ProductReview {
  final String reviewId;
  final String productId;
  final String userId;
  final double rating;
  final String? reviewText;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Related data for display
  final String? userName;
  final String? userAvatar;

  ProductReview({
    required this.reviewId,
    required this.productId,
    required this.userId,
    required this.rating,
    this.reviewText,
    required this.createdAt,
    required this.updatedAt,
    this.userName,
    this.userAvatar,
  });

  factory ProductReview.fromJson(Map<String, dynamic> json) =>
      _$ProductReviewFromJson(json);
  Map<String, dynamic> toJson() => _$ProductReviewToJson(this);

  ProductReview copyWith({
    String? reviewId,
    String? productId,
    String? userId,
    double? rating,
    String? reviewText,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userName,
    String? userAvatar,
  }) {
    return ProductReview(
      reviewId: reviewId ?? this.reviewId,
      productId: productId ?? this.productId,
      userId: userId ?? this.userId,
      rating: rating ?? this.rating,
      reviewText: reviewText ?? this.reviewText,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
    );
  }
}
