// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_product_queue.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OfflineProductQueueAdapter extends TypeAdapter<OfflineProductQueue> {
  @override
  final int typeId = 0;

  @override
  OfflineProductQueue read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineProductQueue(
      id: fields[0] as String,
      farmerId: fields[1] as String,
      name: fields[2] as String,
      price: fields[3] as double,
      description: fields[4] as String,
      categoryId: fields[5] as int,
      unitId: fields[6] as int,
      imageUrl: fields[7] as String?,
      harvestDays: fields[8] as int,
      isPreorder: fields[9] as bool,
      availableQuantity: fields[10] as int,
      localImagePaths: (fields[11] as List).cast<String>(),
      createdAt: fields[12] as DateTime,
      synced: fields[13] as bool? ?? false,
      syncError: fields[14] as String?,
      categoryIdRef: fields[15] as String?,
      unitIdRef: fields[16] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineProductQueue obj) {
    writer
      ..writeByte(17)
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
      ..write(obj.categoryId)
      ..writeByte(6)
      ..write(obj.unitId)
      ..writeByte(7)
      ..write(obj.imageUrl)
      ..writeByte(8)
      ..write(obj.harvestDays)
      ..writeByte(9)
      ..write(obj.isPreorder)
      ..writeByte(10)
      ..write(obj.availableQuantity)
      ..writeByte(11)
      ..write(obj.localImagePaths)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.synced)
      ..writeByte(14)
      ..write(obj.syncError)
      ..writeByte(15)
      ..write(obj.categoryIdRef)
      ..writeByte(16)
      ..write(obj.unitIdRef);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineProductQueueAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
