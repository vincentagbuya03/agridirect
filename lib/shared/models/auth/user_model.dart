// ============================================================================
// lib/shared/models/auth/user_model.dart
// User data model
// ============================================================================

import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class User {
  final String userId;
  final String email;
  final String name;
  final String? phone;
  final String? avatarUrl;
  final String? bio;
  final bool emailVerified;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String>? roles;

  User({
    required this.userId,
    required this.email,
    required this.name,
    this.phone,
    this.avatarUrl,
    this.bio,
    this.emailVerified = false,
    required this.createdAt,
    required this.updatedAt,
    this.roles,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  User copyWith({
    String? userId,
    String? email,
    String? name,
    String? phone,
    String? avatarUrl,
    String? bio,
    bool? emailVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? roles,
  }) {
    return User(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      emailVerified: emailVerified ?? this.emailVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      roles: roles ?? this.roles,
    );
  }

  bool hasRole(String role) => roles?.contains(role) ?? false;
  bool get isSeller => hasRole('seller');
  bool get isAdmin => hasRole('admin');
  bool get isConsumer => hasRole('consumer');
}
