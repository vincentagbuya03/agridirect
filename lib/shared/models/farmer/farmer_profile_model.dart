// ============================================================================
// lib/shared/models/farmer/farmer_profile_model.dart
// Farmer profile data model
// ============================================================================

import 'package:json_annotation/json_annotation.dart';

part 'farmer_profile_model.g.dart';

@JsonSerializable()
class FarmerProfile {
  final String profileId;
  final String userId;
  final String farmName;
  final String? specialty;
  final String? location;
  final String? badge;
  final String? imageUrl;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Related data from view
  final String? farmerName;
  final String? farmerEmail;
  final String? farmerPhone;
  final double? averageRating;
  final int? totalReviews;

  FarmerProfile({
    required this.profileId,
    required this.userId,
    required this.farmName,
    this.specialty,
    this.location,
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
