// ============================================================================
// lib/shared/models/auth/user_address_model.dart
// User address data model
// ============================================================================

import 'package:json_annotation/json_annotation.dart';

part 'user_address_model.g.dart';

@JsonSerializable()
class UserAddress {
  final String addressId;
  final String userId;
  final String street;
  final String barangay;
  final String city;
  final String province;
  final String zipCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserAddress({
    required this.addressId,
    required this.userId,
    required this.street,
    required this.barangay,
    required this.city,
    required this.province,
    required this.zipCode,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get fullAddress =>
      '$street, $barangay, $city, $province $zipCode';
}
