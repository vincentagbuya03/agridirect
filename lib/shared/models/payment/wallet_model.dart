import 'package:json_annotation/json_annotation.dart';

part 'wallet_model.g.dart';

/// Farmer wallet model - stores farmer's earnings from sales.
@JsonSerializable()
class FarmerWallet {
  @JsonKey(name: 'wallet_id')
  final String walletId;
  @JsonKey(name: 'farmer_id')
  final String farmerId;
  final double balance;
  @JsonKey(name: 'total_credited')
  final double totalCredited;
  @JsonKey(name: 'total_withdrawn')
  final double totalWithdrawn;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  FarmerWallet({
    required this.walletId,
    required this.farmerId,
    required this.balance,
    required this.totalCredited,
    required this.totalWithdrawn,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FarmerWallet.fromJson(Map<String, dynamic> json) =>
      _$FarmerWalletFromJson(json);

  Map<String, dynamic> toJson() => _$FarmerWalletToJson(this);
}

/// Farmer wallet transaction model.
@JsonSerializable()
class FarmerWalletTransaction {
  @JsonKey(name: 'transaction_id')
  final String transactionId;
  @JsonKey(name: 'wallet_id')
  final String walletId;
  @JsonKey(name: 'order_id')
  final String? orderId;
  @JsonKey(name: 'payment_id')
  final String? paymentId;
  @JsonKey(name: 'transaction_type')
  final String transactionType; // 'credit', 'debit', 'adjustment'
  final double amount;
  final String? description;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  FarmerWalletTransaction({
    required this.transactionId,
    required this.walletId,
    this.orderId,
    this.paymentId,
    required this.transactionType,
    required this.amount,
    this.description,
    required this.createdAt,
  });

  factory FarmerWalletTransaction.fromJson(Map<String, dynamic> json) =>
      _$FarmerWalletTransactionFromJson(json);

  Map<String, dynamic> toJson() => _$FarmerWalletTransactionToJson(this);

  /// Returns true if this is a credit (incoming) transaction.
  bool get isCredit => transactionType == 'credit';

  /// Returns true if this is a debit (outgoing/withdrawal) transaction.
  bool get isDebit => transactionType == 'debit';
}
