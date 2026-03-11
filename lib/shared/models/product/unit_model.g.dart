// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unit_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Unit _$UnitFromJson(Map<String, dynamic> json) => Unit(
  unitId: json['unitId'] as String,
  name: json['name'] as String,
  abbreviation: json['abbreviation'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$UnitToJson(Unit instance) => <String, dynamic>{
  'unitId': instance.unitId,
  'name': instance.name,
  'abbreviation': instance.abbreviation,
  'createdAt': instance.createdAt.toIso8601String(),
};
