// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'farmer_profile_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FarmerProfile _$FarmerProfileFromJson(Map<String, dynamic> json) =>
    FarmerProfile(
      profileId: json['farmer_id'] as String,
      userId: json['user_id'] as String,
      farmName: json['farm_name'] as String,
      specialty: json['specialty'] as String?,
      location: json['location'] as String?,
      farmLatitude: (json['farm_latitude'] as num?)?.toDouble(),
      farmLongitude: (json['farm_longitude'] as num?)?.toDouble(),
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
      'profileId': instance.profileId,
      'userId': instance.userId,
      'farmName': instance.farmName,
      'specialty': instance.specialty,
      'location': instance.location,
      'farmLatitude': instance.farmLatitude,
      'farmLongitude': instance.farmLongitude,
      'badge': instance.badge,
      'imageUrl': instance.imageUrl,
      'isVerified': instance.isVerified,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'farmerName': instance.farmerName,
      'farmerEmail': instance.farmerEmail,
      'farmerPhone': instance.farmerPhone,
      'averageRating': instance.averageRating,
      'totalReviews': instance.totalReviews,
    };
