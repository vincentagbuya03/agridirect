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
  total: (json['total_amount'] as num?)?.toDouble(),
  itemCount: (json['itemCount'] as num?)?.toInt(),
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
  'total_amount': instance.total,
  'itemCount': instance.itemCount,
};
