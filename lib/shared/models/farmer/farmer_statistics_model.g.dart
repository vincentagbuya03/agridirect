// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'farmer_statistics_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FarmerStatistics _$FarmerStatisticsFromJson(Map<String, dynamic> json) =>
    FarmerStatistics(
      farmerId: json['farmer_id'] as String,
      farmName: json['farm_name'] as String,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      totalRatings: (json['total_ratings'] as num?)?.toInt() ?? 0,
      followerCount: (json['follower_count'] as num?)?.toInt() ?? 0,
      productCount: (json['product_count'] as num?)?.toInt() ?? 0,
      completedOrders: (json['completed_orders'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$FarmerStatisticsToJson(FarmerStatistics instance) =>
    <String, dynamic>{
      'farmer_id': instance.farmerId,
      'farm_name': instance.farmName,
      'average_rating': instance.averageRating,
      'total_ratings': instance.totalRatings,
      'follower_count': instance.followerCount,
      'product_count': instance.productCount,
      'completed_orders': instance.completedOrders,
    };
