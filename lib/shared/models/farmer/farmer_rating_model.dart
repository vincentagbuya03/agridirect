import 'package:json_annotation/json_annotation.dart';

part 'farmer_rating_model.g.dart';

@JsonSerializable()
class FarmerRating {
  @JsonKey(name: 'rating_id')
  final String ratingId;
  @JsonKey(name: 'farmer_id')
  final String farmerId;
  @JsonKey(name: 'customer_id')
  final String customerId;
  @JsonKey(name: 'order_id')
  final String? orderId;
  final double rating;
  @JsonKey(name: 'review_text')
  final String? reviewText;
  final Map<String, dynamic>? categories;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  // View fields
  @JsonKey(name: 'customer_name')
  final String? customerName;
  @JsonKey(name: 'customer_avatar')
  final String? customerAvatar;
  @JsonKey(name: 'farm_name')
  final String? farmName;

  FarmerRating({
    required this.ratingId,
    required this.farmerId,
    required this.customerId,
    this.orderId,
    required this.rating,
    this.reviewText,
    this.categories,
    required this.createdAt,
    required this.updatedAt,
    this.customerName,
    this.customerAvatar,
    this.farmName,
  });

  factory FarmerRating.fromJson(Map<String, dynamic> json) =>
      _$FarmerRatingFromJson(json);
  Map<String, dynamic> toJson() => _$FarmerRatingToJson(this);

  FarmerRating copyWith({
    String? ratingId,
    String? farmerId,
    String? customerId,
    String? orderId,
    double? rating,
    String? reviewText,
    Map<String, dynamic>? categories,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? customerName,
    String? customerAvatar,
    String? farmName,
  }) {
    return FarmerRating(
      ratingId: ratingId ?? this.ratingId,
      farmerId: farmerId ?? this.farmerId,
      customerId: customerId ?? this.customerId,
      orderId: orderId ?? this.orderId,
      rating: rating ?? this.rating,
      reviewText: reviewText ?? this.reviewText,
      categories: categories ?? this.categories,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customerName: customerName ?? this.customerName,
      customerAvatar: customerAvatar ?? this.customerAvatar,
      farmName: farmName ?? this.farmName,
    );
  }
}
