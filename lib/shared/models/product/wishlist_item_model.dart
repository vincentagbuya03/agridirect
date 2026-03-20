import 'package:json_annotation/json_annotation.dart';

part 'wishlist_item_model.g.dart';

@JsonSerializable()
class WishlistItem {
  @JsonKey(name: 'wishlist_id')
  final String wishlistId;
  @JsonKey(name: 'customer_id')
  final String customerId;
  @JsonKey(name: 'product_id')
  final String productId;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  // View fields
  @JsonKey(name: 'product_name')
  final String? productName;
  final double? price;
  @JsonKey(name: 'product_image')
  final String? productImage;
  @JsonKey(name: 'farmer_id')
  final String? farmerId;
  @JsonKey(name: 'is_preorder')
  final bool? isPreorder;
  @JsonKey(name: 'product_quantity')
  final double? productQuantity;
  @JsonKey(name: 'category_name')
  final String? categoryName;
  @JsonKey(name: 'unit_name')
  final String? unitName;
  @JsonKey(name: 'unit_abbr')
  final String? unitAbbr;
  @JsonKey(name: 'farm_name')
  final String? farmName;

  WishlistItem({
    required this.wishlistId,
    required this.customerId,
    required this.productId,
    required this.createdAt,
    this.productName,
    this.price,
    this.productImage,
    this.farmerId,
    this.isPreorder,
    this.productQuantity,
    this.categoryName,
    this.unitName,
    this.unitAbbr,
    this.farmName,
  });

  factory WishlistItem.fromJson(Map<String, dynamic> json) =>
      _$WishlistItemFromJson(json);
  Map<String, dynamic> toJson() => _$WishlistItemToJson(this);

  WishlistItem copyWith({
    String? wishlistId,
    String? customerId,
    String? productId,
    DateTime? createdAt,
    String? productName,
    double? price,
    String? productImage,
    String? farmerId,
    bool? isPreorder,
    double? productQuantity,
    String? categoryName,
    String? unitName,
    String? unitAbbr,
    String? farmName,
  }) {
    return WishlistItem(
      wishlistId: wishlistId ?? this.wishlistId,
      customerId: customerId ?? this.customerId,
      productId: productId ?? this.productId,
      createdAt: createdAt ?? this.createdAt,
      productName: productName ?? this.productName,
      price: price ?? this.price,
      productImage: productImage ?? this.productImage,
      farmerId: farmerId ?? this.farmerId,
      isPreorder: isPreorder ?? this.isPreorder,
      productQuantity: productQuantity ?? this.productQuantity,
      categoryName: categoryName ?? this.categoryName,
      unitName: unitName ?? this.unitName,
      unitAbbr: unitAbbr ?? this.unitAbbr,
      farmName: farmName ?? this.farmName,
    );
  }
}
