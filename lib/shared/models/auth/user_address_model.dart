// ============================================================================
// lib/shared/models/auth/user_address_model.dart
// User address data model
// ============================================================================

import 'package:json_annotation/json_annotation.dart';

part 'user_address_model.g.dart';

@JsonSerializable()
class UserAddress {
  @JsonKey(name: 'address_id')
  final String addressId;
  @JsonKey(name: 'user_id')
  final String userId;
  final String street;
  final String barangay;
  final String city;
  final String province;
  @JsonKey(name: 'zip_code', defaultValue: '')
  final String zipCode;
  final String label;
  @JsonKey(name: 'recipient_name', defaultValue: '')
  final String recipientName;
  @JsonKey(name: 'recipient_phone', defaultValue: '')
  final String recipientPhone;
  @JsonKey(name: 'is_default', defaultValue: false)
  final bool isDefault;
  final double? latitude;
  final double? longitude;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  UserAddress({
    required this.addressId,
    required this.userId,
    required this.street,
    required this.barangay,
    required this.city,
    required this.province,
    required this.zipCode,
    this.label = 'Home',
    this.recipientName = '',
    this.recipientPhone = '',
    this.isDefault = false,
    this.latitude,
    this.longitude,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserAddress.fromJson(Map<String, dynamic> json) =>
      _$UserAddressFromJson(json);
  Map<String, dynamic> toJson() => _$UserAddressToJson(this);

  UserAddress copyWith({
    String? addressId,
    String? userId,
    String? street,
    String? barangay,
    String? city,
    String? province,
    String? zipCode,
    String? label,
    String? recipientName,
    String? recipientPhone,
    bool? isDefault,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserAddress(
      addressId: addressId ?? this.addressId,
      userId: userId ?? this.userId,
      street: street ?? this.street,
      barangay: barangay ?? this.barangay,
      city: city ?? this.city,
      province: province ?? this.province,
      zipCode: zipCode ?? this.zipCode,
      label: label ?? this.label,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      isDefault: isDefault ?? this.isDefault,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get fullAddress =>
      '$street, $barangay, $city, $province, $zipCode'.trim().replaceAll(RegExp(r', ,'), ',');
}
