// ============================================================================
// lib/shared/models/order/order_item_model.dart
// Order item data model
// ============================================================================

import 'package:json_annotation/json_annotation.dart';

part 'order_item_model.g.dart';

@JsonSerializable()
class OrderItem {
  final String orderItemId;
  final String orderId;
  final String productId;
  final double quantity;
  final double unitPrice;
  final DateTime createdAt;

  // Related data from view
  final String? productName;
  final String? productImage;
  final double? subtotal;

  OrderItem({
    required this.orderItemId,
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.createdAt,
    this.productName,
    this.productImage,
    this.subtotal,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) =>
      _$OrderItemFromJson(json);
  Map<String, dynamic> toJson() => _$OrderItemToJson(this);

  OrderItem copyWith({
    String? orderItemId,
    String? orderId,
    String? productId,
    double? quantity,
    double? unitPrice,
    DateTime? createdAt,
    String? productName,
    String? productImage,
    double? subtotal,
  }) {
    return OrderItem(
      orderItemId: orderItemId ?? this.orderItemId,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      createdAt: createdAt ?? this.createdAt,
      productName: productName ?? this.productName,
      productImage: productImage ?? this.productImage,
      subtotal: subtotal ?? this.subtotal,
    );
  }
}
