// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'farmer_profile_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FarmerProfile _$FarmerProfileFromJson(Map<String, dynamic> json) =>
    FarmerProfile(
      profileId: json['profileId'] as String,
      userId: json['userId'] as String,
      farmName: json['farmName'] as String,
      specialty: json['specialty'] as String?,
      location: json['location'] as String?,
      badge: json['badge'] as String?,
      imageUrl: json['imageUrl'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      farmerName: json['farmerName'] as String?,
      farmerEmail: json['farmerEmail'] as String?,
      farmerPhone: json['farmerPhone'] as String?,
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      totalReviews: (json['totalReviews'] as num?)?.toInt(),
    );

Map<String, dynamic> _$FarmerProfileToJson(FarmerProfile instance) =>
    <String, dynamic>{
      'profileId': instance.profileId,
      'userId': instance.userId,
      'farmName': instance.farmName,
      'specialty': instance.specialty,
      'location': instance.location,
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
