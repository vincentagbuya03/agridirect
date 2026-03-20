// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'farmer_profile_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FarmerProfile _$FarmerProfileFromJson(Map<String, dynamic> json) =>
    FarmerProfile(
      farmerId: json['farmer_id'] as String,
      farmName: json['farm_name'] as String,
      specialty: json['specialty'] as String?,
      location: json['location'] as String?,
      badge: json['badge'] as String?,
      imageUrl: json['image_url'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      farmerName: json['farmer_name'] as String?,
      farmerEmail: json['farmer_email'] as String?,
      farmerPhone: json['farmer_phone'] as String?,
      averageRating: (json['average_rating'] as num?)?.toDouble(),
      totalReviews: (json['total_reviews'] as num?)?.toInt(),
    );

Map<String, dynamic> _$FarmerProfileToJson(FarmerProfile instance) =>
    <String, dynamic>{
      'farmer_id': instance.farmerId,
      'farm_name': instance.farmName,
      'specialty': instance.specialty,
      'location': instance.location,
      'badge': instance.badge,
      'image_url': instance.imageUrl,
      'is_verified': instance.isVerified,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'farmer_name': instance.farmerName,
      'farmer_email': instance.farmerEmail,
      'farmer_phone': instance.farmerPhone,
      'average_rating': instance.averageRating,
      'total_reviews': instance.totalReviews,
    };
