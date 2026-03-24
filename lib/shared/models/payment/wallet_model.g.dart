// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FarmerWallet _$FarmerWalletFromJson(Map<String, dynamic> json) => FarmerWallet(
  walletId: json['wallet_id'] as String,
  farmerId: json['farmer_id'] as String,
  balance: (json['balance'] as num).toDouble(),
  totalCredited: (json['total_credited'] as num).toDouble(),
  totalWithdrawn: (json['total_withdrawn'] as num).toDouble(),
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$FarmerWalletToJson(FarmerWallet instance) =>
    <String, dynamic>{
      'wallet_id': instance.walletId,
      'farmer_id': instance.farmerId,
      'balance': instance.balance,
      'total_credited': instance.totalCredited,
      'total_withdrawn': instance.totalWithdrawn,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };

FarmerWalletTransaction _$FarmerWalletTransactionFromJson(
  Map<String, dynamic> json,
) => FarmerWalletTransaction(
  transactionId: json['transaction_id'] as String,
  walletId: json['wallet_id'] as String,
  orderId: json['order_id'] as String?,
  paymentId: json['payment_id'] as String?,
  transactionType: json['transaction_type'] as String,
  amount: (json['amount'] as num).toDouble(),
  description: json['description'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$FarmerWalletTransactionToJson(
  FarmerWalletTransaction instance,
) => <String, dynamic>{
  'transaction_id': instance.transactionId,
  'wallet_id': instance.walletId,
  'order_id': instance.orderId,
  'payment_id': instance.paymentId,
  'transaction_type': instance.transactionType,
  'amount': instance.amount,
  'description': instance.description,
  'created_at': instance.createdAt.toIso8601String(),
};
