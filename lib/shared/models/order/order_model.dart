// ============================================================================
// lib/shared/models/order/order_model.dart
// Order data model
// ============================================================================

import 'package:json_annotation/json_annotation.dart';

part 'order_model.g.dart';

@JsonSerializable()
class Order {
  final String orderId;
  final String orderNumber;
  final String customerId;
  final String farmerId;
  final String status; // PENDING, CONFIRMED, SHIPPED, DELIVERED, CANCELLED
  final DateTime createdAt;
  final DateTime updatedAt;

  // Computed fields from view
  final double? total;
  final int? itemCount;

  Order({
    required this.orderId,
    required this.orderNumber,
    required this.customerId,
    required this.farmerId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.total,
    this.itemCount,
  });

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);
  Map<String, dynamic> toJson() => _$OrderToJson(this);

  Order copyWith({
    String? orderId,
    String? orderNumber,
    String? customerId,
    String? farmerId,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? total,
    int? itemCount,
  }) {
    return Order(
      orderId: orderId ?? this.orderId,
      orderNumber: orderNumber ?? this.orderNumber,
      customerId: customerId ?? this.customerId,
      farmerId: farmerId ?? this.farmerId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      total: total ?? this.total,
      itemCount: itemCount ?? this.itemCount,
    );
  }

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isConfirmed => status.toUpperCase() == 'CONFIRMED';
  bool get isShipped => status.toUpperCase() == 'SHIPPED';
  bool get isDelivered => status.toUpperCase() == 'DELIVERED';
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';
}
