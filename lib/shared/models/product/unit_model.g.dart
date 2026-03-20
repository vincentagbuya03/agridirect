// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unit_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Unit _$UnitFromJson(Map<String, dynamic> json) => Unit(
  unitId: json['unit_id'] as String,
  name: json['name'] as String,
  abbreviation: json['abbreviation'] as String,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$UnitToJson(Unit instance) => <String, dynamic>{
  'unit_id': instance.unitId,
  'name': instance.name,
  'abbreviation': instance.abbreviation,
  'created_at': instance.createdAt.toIso8601String(),
};
