// ============================================================================
// lib/shared/models/product/offline_product_model.dart
// Model for storing products locally when offline
// ============================================================================

import 'package:json_annotation/json_annotation.dart';

part 'offline_product_model.g.dart';

enum SyncStatus { pending, syncing, synced, failed }

@JsonSerializable()
class OfflineProduct {
  final String localId; // Unique local identifier (UUID)
  final String? productId; // Null until synced to Supabase
  final String name;
  final double price;
  final String? description;
  final String? imageUrl;
  final String? imageBase64; // Local image stored as base64
  final int? harvestDays;
  final bool isPreorder;
  final double quantity;
  final String farmerId;
  final String categoryId;
  final String unitId;
  final List<String> tagIds; // Tag IDs selected for this product
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;
  final String? syncError;
  final int syncAttempts;

  OfflineProduct({
    required this.localId,
    this.productId,
    required this.name,
    required this.price,
    this.description,
    this.imageUrl,
    this.imageBase64,
    this.harvestDays,
    this.isPreorder = false,
    this.quantity = 0,
    required this.farmerId,
    required this.categoryId,
    required this.unitId,
    this.tagIds = const [],
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
    this.syncError,
    this.syncAttempts = 0,
  });

  factory OfflineProduct.fromJson(Map<String, dynamic> json) =>
      _$OfflineProductFromJson(json);

  Map<String, dynamic> toJson() => _$OfflineProductToJson(this);

  OfflineProduct copyWith({
    String? localId,
    String? productId,
    String? name,
    double? price,
    String? description,
    String? imageUrl,
    String? imageBase64,
    int? harvestDays,
    bool? isPreorder,
    double? quantity,
    String? farmerId,
    String? categoryId,
    String? unitId,
    List<String>? tagIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
    String? syncError,
    int? syncAttempts,
  }) {
    return OfflineProduct(
      localId: localId ?? this.localId,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      imageBase64: imageBase64 ?? this.imageBase64,
      harvestDays: harvestDays ?? this.harvestDays,
      isPreorder: isPreorder ?? this.isPreorder,
      quantity: quantity ?? this.quantity,
      farmerId: farmerId ?? this.farmerId,
      categoryId: categoryId ?? this.categoryId,
      unitId: unitId ?? this.unitId,
      tagIds: tagIds ?? this.tagIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: syncError ?? this.syncError,
      syncAttempts: syncAttempts ?? this.syncAttempts,
    );
  }

  /// Convert OfflineProduct to JSON for local database (SQLite)
  Map<String, dynamic> toDBJson() => {
    'local_id': localId,
    'product_id': productId,
    'name': name,
    'price': price,
    'description': description,
    'image_url': imageUrl,
    'image_base64': imageBase64,
    'harvest_days': harvestDays,
    'is_preorder': isPreorder ? 1 : 0,
    'quantity': quantity,
    'farmer_id': farmerId,
    'category_id': categoryId,
    'unit_id': unitId,
    'tag_ids': tagIds.join(','), // Store as comma-separated string
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'sync_status': syncStatus.name,
    'sync_error': syncError,
    'sync_attempts': syncAttempts,
  };

  /// Create OfflineProduct from database JSON
  factory OfflineProduct.fromDBJson(Map<String, dynamic> json) {
    return OfflineProduct(
      localId: json['local_id'] as String,
      productId: json['product_id'] as String?,
      name: json['name'] as String,
      price: json['price'] as double,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      imageBase64: json['image_base64'] as String?,
      harvestDays: json['harvest_days'] as int?,
      isPreorder: (json['is_preorder'] as int?) == 1,
      quantity: json['quantity'] as double,
      farmerId: json['farmer_id'] as String,
      categoryId: json['category_id'] as String,
      unitId: json['unit_id'] as String,
      tagIds:
          (json['tag_ids'] as String?)
              ?.split(',')
              .where((t) => t.isNotEmpty)
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      syncStatus: SyncStatus.values.byName(
        json['sync_status'] as String? ?? 'pending',
      ),
      syncError: json['sync_error'] as String?,
      syncAttempts: (json['sync_attempts'] as int?) ?? 0,
    );
  }
}
