// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cached_product.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CachedProductAdapter extends TypeAdapter<CachedProduct> {
  @override
  final int typeId = 1;

  @override
  CachedProduct read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedProduct(
      id: fields[0] as String,
      farmerId: fields[1] as String,
      name: fields[2] as String,
      price: fields[3] as double,
      description: fields[4] as String?,
      imageUrl: fields[5] as String?,
      category: fields[6] as String?,
      unit: fields[7] as String?,
      availableQuantity: fields[8] as int?,
      isPreorder: fields[9] as bool? ?? false,
      harvestDays: fields[10] as int? ?? 0,
      cachedAt: fields[11] as DateTime?,
      isManuallySaved: fields[12] as bool? ?? false,
      rating: fields[13] as double?,
      farmName: fields[14] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CachedProduct obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.farmerId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.price)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.imageUrl)
      ..writeByte(6)
      ..write(obj.category)
      ..writeByte(7)
      ..write(obj.unit)
      ..writeByte(8)
      ..write(obj.availableQuantity)
      ..writeByte(9)
      ..write(obj.isPreorder)
      ..writeByte(10)
      ..write(obj.harvestDays)
      ..writeByte(11)
      ..write(obj.cachedAt)
      ..writeByte(12)
      ..write(obj.isManuallySaved)
      ..writeByte(13)
      ..write(obj.rating)
      ..writeByte(14)
      ..write(obj.farmName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedProductAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
