// ============================================================================
// lib/shared/models/farmer/farmer_registration_model.dart
// Farmer verification registration data model
// ============================================================================

import 'package:json_annotation/json_annotation.dart';

part 'farmer_registration_model.g.dart';

@JsonSerializable()
class FarmerRegistration {
  final String registrationId;
  final String userId;
  final String? birthDate;
  final int? yearsOfExperience;
  final String? residentialAddress;
  final String? facePhotoPath;
  final String? validIdPath;
  final String? farmingHistory;
  final bool certificationAccepted;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;
  final DateTime updatedAt;

  FarmerRegistration({
    required this.registrationId,
    required this.userId,
    this.birthDate,
    this.yearsOfExperience,
    this.residentialAddress,
    this.facePhotoPath,
    this.validIdPath,
    this.farmingHistory,
    this.certificationAccepted = false,
    this.status = 'pending',
    required this.createdAt,
    required this.updatedAt,
  });

  factory FarmerRegistration.fromJson(Map<String, dynamic> json) =>
      _$FarmerRegistrationFromJson(json);
  Map<String, dynamic> toJson() => _$FarmerRegistrationToJson(this);

  FarmerRegistration copyWith({
    String? registrationId,
    String? userId,
    String? birthDate,
    int? yearsOfExperience,
    String? residentialAddress,
    String? facePhotoPath,
    String? validIdPath,
    String? farmingHistory,
    bool? certificationAccepted,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FarmerRegistration(
      registrationId: registrationId ?? this.registrationId,
      userId: userId ?? this.userId,
      birthDate: birthDate ?? this.birthDate,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
      residentialAddress: residentialAddress ?? this.residentialAddress,
      facePhotoPath: facePhotoPath ?? this.facePhotoPath,
      validIdPath: validIdPath ?? this.validIdPath,
      farmingHistory: farmingHistory ?? this.farmingHistory,
      certificationAccepted: certificationAccepted ?? this.certificationAccepted,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}
