import 'package:hive/hive.dart';

part 'offline_product_queue.g.dart';

@HiveType(typeId: 0)
class OfflineProductQueue extends HiveObject {
  @HiveField(0)
  late String id; // UUID for tracking

  @HiveField(1)
  late String farmerId;

  @HiveField(2)
  late String name;

  @HiveField(3)
  late double price;

  @HiveField(4)
  late String description;

  @HiveField(5)
  late int categoryId;

  @HiveField(6)
  late int unitId;

  @HiveField(7)
  late String? imageUrl; // Comma-separated URLs

  @HiveField(8)
  late int harvestDays;

  @HiveField(9)
  late bool isPreorder;

  @HiveField(10)
  late int availableQuantity;

  @HiveField(11)
  late List<String> localImagePaths; // Local file paths to upload

  @HiveField(12)
  late DateTime createdAt;

  @HiveField(13)
  late bool synced;

  @HiveField(14)
  late String? syncError;

  @HiveField(15)
  late String? categoryIdRef;

  @HiveField(16)
  late String? unitIdRef;

  OfflineProductQueue({
    required this.id,
    required this.farmerId,
    required this.name,
    required this.price,
    required this.description,
    required this.categoryId,
    required this.unitId,
    this.imageUrl,
    required this.harvestDays,
    required this.isPreorder,
    required this.availableQuantity,
    required this.localImagePaths,
    required this.createdAt,
    this.synced = false,
    this.syncError,
    this.categoryIdRef,
    this.unitIdRef,
  });
}
