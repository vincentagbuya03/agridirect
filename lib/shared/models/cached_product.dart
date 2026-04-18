import 'package:hive/hive.dart';

part 'cached_product.g.dart';

@HiveType(typeId: 1)
class CachedProduct extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String farmerId;

  @HiveField(2)
  late String name;

  @HiveField(3)
  late double price;

  @HiveField(4)
  late String? description;

  @HiveField(5)
  late String? imageUrl;

  @HiveField(6)
  late String? category;

  @HiveField(7)
  late String? unit;

  @HiveField(8)
  late int? availableQuantity;

  @HiveField(9)
  late bool isPreorder;

  @HiveField(10)
  late int harvestDays;

  @HiveField(11)
  late DateTime cachedAt;

  @HiveField(12)
  late bool isManuallySaved; // For user "save for offline" feature

  @HiveField(13)
  late double? rating;

  @HiveField(14)
  late String? farmName;

  @HiveField(15)
  late String? farmerAvatarUrl;

  CachedProduct({
    required this.id,
    required this.farmerId,
    required this.name,
    required this.price,
    this.description,
    this.imageUrl,
    this.category,
    this.unit,
    this.availableQuantity,
    this.isPreorder = false,
    this.harvestDays = 0,
    DateTime? cachedAt,
    this.isManuallySaved = false,
    this.rating,
    this.farmName,
    this.farmerAvatarUrl,
  }) {
    this.cachedAt = cachedAt ?? DateTime.now();
  }
}
