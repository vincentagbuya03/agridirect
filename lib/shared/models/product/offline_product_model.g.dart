// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_product_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OfflineProduct _$OfflineProductFromJson(Map<String, dynamic> json) =>
    OfflineProduct(
      localId: json['localId'] as String,
      productId: json['productId'] as String?,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      imageBase64: json['imageBase64'] as String?,
      harvestDays: (json['harvestDays'] as num?)?.toInt(),
      isPreorder: json['isPreorder'] as bool? ?? false,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      farmerId: json['farmerId'] as String,
      categoryId: json['categoryId'] as String,
      unitId: json['unitId'] as String,
      tagIds:
          (json['tagIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      syncStatus:
          $enumDecodeNullable(_$SyncStatusEnumMap, json['syncStatus']) ??
          SyncStatus.pending,
      syncError: json['syncError'] as String?,
      syncAttempts: (json['syncAttempts'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$OfflineProductToJson(OfflineProduct instance) =>
    <String, dynamic>{
      'localId': instance.localId,
      'productId': instance.productId,
      'name': instance.name,
      'price': instance.price,
      'description': instance.description,
      'imageUrl': instance.imageUrl,
      'imageBase64': instance.imageBase64,
      'harvestDays': instance.harvestDays,
      'isPreorder': instance.isPreorder,
      'quantity': instance.quantity,
      'farmerId': instance.farmerId,
      'categoryId': instance.categoryId,
      'unitId': instance.unitId,
      'tagIds': instance.tagIds,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'syncStatus': _$SyncStatusEnumMap[instance.syncStatus]!,
      'syncError': instance.syncError,
      'syncAttempts': instance.syncAttempts,
    };

const _$SyncStatusEnumMap = {
  SyncStatus.pending: 'pending',
  SyncStatus.syncing: 'syncing',
  SyncStatus.synced: 'synced',
  SyncStatus.failed: 'failed',
};
