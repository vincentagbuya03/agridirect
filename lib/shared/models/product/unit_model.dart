// ============================================================================
// lib/shared/models/product/unit_model.dart
// Measurement unit data model
// ============================================================================

import 'package:json_annotation/json_annotation.dart';

part 'unit_model.g.dart';

@JsonSerializable()
class Unit {
  final String unitId;
  final String name;
  final String abbreviation;
  final DateTime createdAt;

  Unit({
    required this.unitId,
    required this.name,
    required this.abbreviation,
    required this.createdAt,
  });

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
