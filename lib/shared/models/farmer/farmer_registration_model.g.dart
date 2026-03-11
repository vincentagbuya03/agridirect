// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'farmer_registration_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FarmerRegistration _$FarmerRegistrationFromJson(Map<String, dynamic> json) =>
    FarmerRegistration(
      registrationId: json['registrationId'] as String,
      userId: json['userId'] as String,
      birthDate: json['birthDate'] as String?,
      yearsOfExperience: (json['yearsOfExperience'] as num?)?.toInt(),
      residentialAddress: json['residentialAddress'] as String?,
      facePhotoPath: json['facePhotoPath'] as String?,
      validIdPath: json['validIdPath'] as String?,
      farmingHistory: json['farmingHistory'] as String?,
      certificationAccepted: json['certificationAccepted'] as bool? ?? false,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$FarmerRegistrationToJson(FarmerRegistration instance) =>
    <String, dynamic>{
      'registrationId': instance.registrationId,
      'userId': instance.userId,
      'birthDate': instance.birthDate,
      'yearsOfExperience': instance.yearsOfExperience,
      'residentialAddress': instance.residentialAddress,
      'facePhotoPath': instance.facePhotoPath,
      'validIdPath': instance.validIdPath,
      'farmingHistory': instance.farmingHistory,
      'certificationAccepted': instance.certificationAccepted,
      'status': instance.status,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
