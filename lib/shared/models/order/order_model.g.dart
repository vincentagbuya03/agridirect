// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Order _$OrderFromJson(Map<String, dynamic> json) => Order(
      orderId: json['order_id'] as String,
      orderNumber: json['order_number'] as String,
      customerId: json['customer_id'] as String,
      farmerId: json['farmer_id'] as String,
      status: json['status_code'] as String,
      deliveryAddressId: json['delivery_address_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      subtotal: (json['subtotal'] as num?)?.toDouble(),
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble(),
      total: (json['total_amount'] as num?)?.toDouble(),
      paymentMethod: json['payment_method'] as String?,
      itemCount: (json['item_count'] as num?)?.toInt(),
      cancellationReason: json['cancellation_reason'] as String?,
      cancelledBy: json['cancelled_by'] as String?,
      farmName: json['farm_name'] as String?,
      farmerAvatarUrl: json['farmer_avatar_url'] as String?,
    );

Map<String, dynamic> _$OrderToJson(Order instance) => <String, dynamic>{
      'order_id': instance.orderId,
      'order_number': instance.orderNumber,
      'customer_id': instance.customerId,
      'farmer_id': instance.farmerId,
      'status_code': instance.status,
      'delivery_address_id': instance.deliveryAddressId,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'subtotal': instance.subtotal,
      'delivery_fee': instance.deliveryFee,
      'total_amount': instance.total,
      'payment_method': instance.paymentMethod,
      'item_count': instance.itemCount,
      'cancellation_reason': instance.cancellationReason,
      'cancelled_by': instance.cancelledBy,
      'farm_name': instance.farmName,
      'farmer_avatar_url': instance.farmerAvatarUrl,
    };
