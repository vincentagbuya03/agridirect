// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_address_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserAddress _$UserAddressFromJson(Map<String, dynamic> json) => UserAddress(
  addressId: json['address_id'] as String,
  userId: json['user_id'] as String,
  label: json['label'] as String? ?? 'Home',
  recipientName: json['recipient_name'] as String? ?? '',
  recipientPhone: json['recipient_phone'] as String? ?? '',
  street: json['street'] as String,
  barangay: json['barangay'] as String,
  city: json['city'] as String,
  province: json['province'] as String,
  zipCode: json['zip_code'] as String? ?? '',
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  isDefault: json['is_default'] as bool? ?? false,
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$UserAddressToJson(UserAddress instance) =>
    <String, dynamic>{
      'address_id': instance.addressId,
      'user_id': instance.userId,
      'label': instance.label,
      'recipient_name': instance.recipientName,
      'recipient_phone': instance.recipientPhone,
      'street': instance.street,
      'barangay': instance.barangay,
      'city': instance.city,
      'province': instance.province,
      'zip_code': instance.zipCode,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'is_default': instance.isDefault,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };
