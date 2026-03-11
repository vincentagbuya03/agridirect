// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_item_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderItem _$OrderItemFromJson(Map<String, dynamic> json) => OrderItem(
  orderItemId: json['orderItemId'] as String,
  orderId: json['orderId'] as String,
  productId: json['productId'] as String,
  quantity: (json['quantity'] as num).toDouble(),
  unitPrice: (json['unitPrice'] as num).toDouble(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  productName: json['productName'] as String?,
  productImage: json['productImage'] as String?,
  subtotal: (json['subtotal'] as num?)?.toDouble(),
);

Map<String, dynamic> _$OrderItemToJson(OrderItem instance) => <String, dynamic>{
  'orderItemId': instance.orderItemId,
  'orderId': instance.orderId,
  'productId': instance.productId,
  'quantity': instance.quantity,
  'unitPrice': instance.unitPrice,
  'createdAt': instance.createdAt.toIso8601String(),
  'productName': instance.productName,
  'productImage': instance.productImage,
  'subtotal': instance.subtotal,
};
