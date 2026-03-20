// ============================================================================
// lib/shared/models/product/unit_model.dart
// Measurement unit data model
// ============================================================================

import 'package:json_annotation/json_annotation.dart';

part 'unit_model.g.dart';

@JsonSerializable()
class Unit {
  @JsonKey(name: 'unit_id')
  final String unitId;
  final String name;
  final String abbreviation;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  Unit({
    required this.unitId,
    required this.name,
    required this.abbreviation,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Unit.fromJson(Map<String, dynamic> json) => _$UnitFromJson(json);
  Map<String, dynamic> toJson() => _$UnitToJson(this);

  Unit copyWith({
    String? unitId,
    String? name,
    String? abbreviation,
    DateTime? createdAt,
  }) {
    return Unit(
      unitId: unitId ?? this.unitId,
      name: name ?? this.name,
      abbreviation: abbreviation ?? this.abbreviation,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
