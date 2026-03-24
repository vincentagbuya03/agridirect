import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

/// Wallet service for farmer wallet operations only.
/// Farmers receive payments from customer orders via GCash/PayMaya.
class WalletService {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Get the current farmer's wallet.
  Future<Map<String, dynamic>?> getMyFarmerWallet() async {
    final userId = SupabaseConfig.currentUser?.id;
    if (userId == null) return null;

    final farmer = await _client
        .from('farmers')
        .select('farmer_id')
        .eq('user_id', userId)
        .maybeSingle();

    if (farmer == null) return null;

    final farmerId = farmer['farmer_id'] as String;

    // Get or create wallet
    var wallet = await _client
        .from('farmer_wallets')
        .select()
        .eq('farmer_id', farmerId)
        .maybeSingle();

    if (wallet == null) {
      // Create wallet if it doesn't exist
      wallet = await _client
          .from('farmer_wallets')
          .insert({
            'farmer_id': farmerId,
            'balance': 0,
            'total_credited': 0,
            'total_withdrawn': 0,
          })
          .select()
          .single();
    }

    return wallet;
  }

  /// Get farmer wallet transactions with optional limit.
  Future<List<Map<String, dynamic>>> getMyFarmerWalletTransactions({
    int limit = 20,
    int offset = 0,
  }) async {
    final wallet = await getMyFarmerWallet();
    if (wallet == null) return [];

    final walletId = wallet['wallet_id'];
    if (walletId == null) return [];

    final response = await _client
        .from('wallet_transactions')
        .select()
        .eq('wallet_id', walletId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Get all farmer wallet transactions (no limit).
  Future<List<Map<String, dynamic>>> getAllFarmerWalletTransactions() async {
    final wallet = await getMyFarmerWallet();
    if (wallet == null) return [];

    final walletId = wallet['wallet_id'];
    if (walletId == null) return [];

    final response = await _client
        .from('wallet_transactions')
        .select()
        .eq('wallet_id', walletId)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Process a customer's payment and credit the farmer's wallet.
  /// Called after customer completes payment via GCash/PayMaya.
  Future<Map<String, dynamic>> processOrderPaymentToFarmerWallet({
    required String orderId,
    required double amount,
    required String paymentMethod,
    String? transactionReference,
    String? notes,
  }) async {
    final customerId = SupabaseConfig.currentUser?.id;
    if (customerId == null) {
      throw Exception('User not authenticated');
    }

    final result = await _client.rpc(
      'process_order_payment_to_farmer_wallet',
      params: {
        'p_order_id': orderId,
        'p_customer_id': customerId,
        'p_amount': amount,
        'p_payment_method': paymentMethod,
        'p_transaction_reference': transactionReference,
        'p_notes': notes,
      },
    );

    return Map<String, dynamic>.from(result as Map);
  }

  /// Request a withdrawal from the farmer's wallet.
  /// This creates a pending withdrawal request that admin can process.
  Future<Map<String, dynamic>> requestWithdrawal({
    required double amount,
    required String withdrawalMethod,
    required String accountDetails,
    String? notes,
  }) async {
    final userId = SupabaseConfig.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final wallet = await getMyFarmerWallet();
    if (wallet == null) throw Exception('Farmer wallet not found');

    final balance = (wallet['balance'] as num?)?.toDouble() ?? 0.0;
    if (amount > balance) {
      throw Exception(
        'Insufficient balance. Available: ₱${balance.toStringAsFixed(2)}',
      );
    }

    if (amount < 100) {
      throw Exception('Minimum withdrawal amount is ₱100.00');
    }

    final walletId = wallet['wallet_id'] as String;

    // Create withdrawal transaction (pending status)
    final transaction = await _client
        .from('wallet_transactions')
        .insert({
          'wallet_id': walletId,
          'transaction_type': 'debit',
          'amount': amount,
          'description':
              'Withdrawal request via $withdrawalMethod - $accountDetails${notes != null ? ' - $notes' : ''}',
        })
        .select()
        .single();

    // Update wallet balance
    await _client
        .from('farmer_wallets')
        .update({
          'balance': balance - amount,
          'total_withdrawn':
              (wallet['total_withdrawn'] as num?)?.toDouble() ?? 0.0 + amount,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('wallet_id', walletId);

    return {
      'transaction_id': transaction['transaction_id'],
      'amount': amount,
      'new_balance': balance - amount,
      'status': 'pending',
    };
  }
}
