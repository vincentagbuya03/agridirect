import 'package:json_annotation/json_annotation.dart';

part 'farmer_statistics_model.g.dart';

@JsonSerializable()
class FarmerStatistics {
  @JsonKey(name: 'farmer_id')
  final String farmerId;
  @JsonKey(name: 'farm_name')
  final String farmName;
  @JsonKey(name: 'average_rating')
  final double averageRating;
  @JsonKey(name: 'total_ratings')
  final int totalRatings;
  @JsonKey(name: 'follower_count')
  final int followerCount;
  @JsonKey(name: 'product_count')
  final int productCount;
  @JsonKey(name: 'completed_orders')
  final int completedOrders;

  FarmerStatistics({
    required this.farmerId,
    required this.farmName,
    this.averageRating = 0,
    this.totalRatings = 0,
    this.followerCount = 0,
    this.productCount = 0,
    this.completedOrders = 0,
  });

  factory FarmerStatistics.fromJson(Map<String, dynamic> json) =>
      _$FarmerStatisticsFromJson(json);
  Map<String, dynamic> toJson() => _$FarmerStatisticsToJson(this);

  FarmerStatistics copyWith({
    String? farmerId,
    String? farmName,
    double? averageRating,
    int? totalRatings,
    int? followerCount,
    int? productCount,
    int? completedOrders,
  }) {
    return FarmerStatistics(
      farmerId: farmerId ?? this.farmerId,
      farmName: farmName ?? this.farmName,
      averageRating: averageRating ?? this.averageRating,
      totalRatings: totalRatings ?? this.totalRatings,
      followerCount: followerCount ?? this.followerCount,
      productCount: productCount ?? this.productCount,
      completedOrders: completedOrders ?? this.completedOrders,
    );
  }
}
