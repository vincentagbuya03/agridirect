// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Order _$OrderFromJson(Map<String, dynamic> json) => Order(
  orderId: json['orderId'] as String,
  orderNumber: json['orderNumber'] as String,
  customerId: json['customerId'] as String,
  farmerId: json['farmerId'] as String,
  status: json['status'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  total: (json['total'] as num?)?.toDouble(),
  itemCount: (json['itemCount'] as num?)?.toInt(),
);

Map<String, dynamic> _$OrderToJson(Order instance) => <String, dynamic>{
  'orderId': instance.orderId,
  'orderNumber': instance.orderNumber,
  'customerId': instance.customerId,
  'farmerId': instance.farmerId,
  'status': instance.status,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'total': instance.total,
  'itemCount': instance.itemCount,
};
