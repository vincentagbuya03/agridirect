// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_address_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserAddress _$UserAddressFromJson(Map<String, dynamic> json) => UserAddress(
  addressId: json['addressId'] as String,
  userId: json['userId'] as String,
  street: json['street'] as String,
  barangay: json['barangay'] as String,
  city: json['city'] as String,
  province: json['province'] as String,
  zipCode: json['zipCode'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$UserAddressToJson(UserAddress instance) =>
    <String, dynamic>{
      'addressId': instance.addressId,
      'userId': instance.userId,
      'street': instance.street,
      'barangay': instance.barangay,
      'city': instance.city,
      'province': instance.province,
      'zipCode': instance.zipCode,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
