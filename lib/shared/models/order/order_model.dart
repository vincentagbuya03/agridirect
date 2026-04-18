// ============================================================================
// lib/shared/models/order/order_model.dart
// Order data model
// ============================================================================

import 'package:json_annotation/json_annotation.dart';

part 'order_model.g.dart';

@JsonSerializable()
class Order {
  @JsonKey(name: 'order_id')
  final String orderId;
  @JsonKey(name: 'order_number')
  final String orderNumber;
  @JsonKey(name: 'customer_id')
  final String customerId;
  @JsonKey(name: 'farmer_id')
  final String farmerId;
  @JsonKey(name: 'status_code')
  final String status; // PENDING, CONFIRMED, SHIPPED, DELIVERED, CANCELLED
  @JsonKey(name: 'delivery_address_id')
  final String? deliveryAddressId;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  // Computed fields from view
  @JsonKey(name: 'total_amount')
  final double? total;
  final int? itemCount;

  // Added farm details from view
  @JsonKey(name: 'farm_name')
  final String? farmName;
  @JsonKey(name: 'farmer_avatar_url')
  final String? farmerAvatarUrl;

  Order({
    required this.orderId,
    required this.orderNumber,
    required this.customerId,
    required this.farmerId,
    required this.status,
    this.deliveryAddressId,
    required this.createdAt,
    required this.updatedAt,
    this.total,
    this.itemCount,
    this.farmName,
    this.farmerAvatarUrl,
  });

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);
  Map<String, dynamic> toJson() => _$OrderToJson(this);

  Order copyWith({
    String? orderId,
    String? orderNumber,
    String? customerId,
    String? farmerId,
    String? status,
    String? deliveryAddressId,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? total,
    int? itemCount,
    String? farmName,
    String? farmerAvatarUrl,
  }) {
    return Order(
      orderId: orderId ?? this.orderId,
      orderNumber: orderNumber ?? this.orderNumber,
      customerId: customerId ?? this.customerId,
      farmerId: farmerId ?? this.farmerId,
      status: status ?? this.status,
      deliveryAddressId: deliveryAddressId ?? this.deliveryAddressId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      total: total ?? this.total,
      itemCount: itemCount ?? this.itemCount,
      farmName: farmName ?? this.farmName,
      farmerAvatarUrl: farmerAvatarUrl ?? this.farmerAvatarUrl,
    );
  }

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isConfirmed => status.toUpperCase() == 'CONFIRMED';
  bool get isShipped => status.toUpperCase() == 'SHIPPED';
  bool get isDelivered => status.toUpperCase() == 'DELIVERED';
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';
}
