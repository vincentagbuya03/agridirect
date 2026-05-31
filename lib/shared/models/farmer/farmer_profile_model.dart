// ============================================================================
// lib/shared/models/farmer/farmer_profile_model.dart
// Farmer profile data model
// ============================================================================

import 'package:json_annotation/json_annotation.dart';

part 'farmer_profile_model.g.dart';

@JsonSerializable()
class FarmerProfile {
  @JsonKey(name: 'farmer_id')
  final String profileId;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'farm_name')
  final String farmName;
  final String? specialty;
  final String? location;
  @JsonKey(name: 'farm_latitude')
  final double? farmLatitude;
  @JsonKey(name: 'farm_longitude')
  final double? farmLongitude;
  final String? badge;
  @JsonKey(name: 'image_url')
  final String? imageUrl;
  @JsonKey(name: 'is_verified')
  final bool isVerified;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  // Related data from view
  @JsonKey(name: 'farmer_name')
  final String? farmerName;
  @JsonKey(name: 'farmer_email')
  final String? farmerEmail;
  @JsonKey(name: 'farmer_phone')
  final String? farmerPhone;
  @JsonKey(name: 'average_rating')
  final double? averageRating;
  @JsonKey(name: 'total_reviews')
  final int? totalReviews;

  FarmerProfile({
    required this.profileId,
    required this.userId,
    required this.farmName,
    this.specialty,
    this.location,
    this.farmLatitude,
    this.farmLongitude,
    this.badge,
    this.imageUrl,
    this.isVerified = false,
    required this.createdAt,
    required this.updatedAt,
    this.farmerName,
    this.farmerEmail,
    this.farmerPhone,
    this.averageRating,
    this.totalReviews,
  });

  factory FarmerProfile.fromJson(Map<String, dynamic> json) =>
      _$FarmerProfileFromJson(json);
  Map<String, dynamic> toJson() => _$FarmerProfileToJson(this);

  FarmerProfile copyWith({
    String? profileId,
    String? userId,
    String? farmName,
    String? specialty,
    String? location,
    double? farmLatitude,
    double? farmLongitude,
    String? badge,
    String? imageUrl,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? farmerName,
    String? farmerEmail,
    String? farmerPhone,
    double? averageRating,
    int? totalReviews,
  }) {
    return FarmerProfile(
      profileId: profileId ?? this.profileId,
      userId: userId ?? this.userId,
      farmName: farmName ?? this.farmName,
      specialty: specialty ?? this.specialty,
      location: location ?? this.location,
      farmLatitude: farmLatitude ?? this.farmLatitude,
      farmLongitude: farmLongitude ?? this.farmLongitude,
      badge: badge ?? this.badge,
      imageUrl: imageUrl ?? this.imageUrl,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      farmerName: farmerName ?? this.farmerName,
      farmerEmail: farmerEmail ?? this.farmerEmail,
      farmerPhone: farmerPhone ?? this.farmerPhone,
      averageRating: averageRating ?? this.averageRating,
      totalReviews: totalReviews ?? this.totalReviews,
    );
  }
}
