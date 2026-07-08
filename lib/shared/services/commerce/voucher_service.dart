import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VoucherService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Create a new store voucher
  Future<Map<String, dynamic>?> createVoucher({
    required String farmerId,
    required String code,
    required String discountType,
    required double discountValue,
    required double minSpend,
    double? maxDiscount,
    required int usageLimit,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _supabase.from('vouchers').insert({
        'farmer_id': farmerId,
        'code': code.toUpperCase().trim(),
        'discount_type': discountType,
        'discount_value': discountValue,
        'min_spend': minSpend,
        'max_discount': maxDiscount,
        'usage_limit': usageLimit,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
      }).select().single();

      return response;
    } catch (e) {
      debugPrint('Error creating voucher: $e');
      throw Exception('Failed to create voucher: $e');
    }
  }

  /// Get all vouchers created by a specific farmer
  Future<List<Map<String, dynamic>>> getFarmerVouchers(String farmerId) async {
    try {
      final response = await _supabase
          .from('vouchers')
          .select()
          .eq('farmer_id', farmerId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Error fetching farmer vouchers: $e');
      return [];
    }
  }

  /// Delete a voucher
  Future<void> deleteVoucher(String voucherId) async {
    try {
      await _supabase.from('vouchers').delete().eq('voucher_id', voucherId);
    } catch (e) {
      debugPrint('Error deleting voucher: $e');
      throw Exception('Failed to delete voucher: $e');
    }
  }

  /// Claim a voucher for a user
  Future<bool> claimVoucher(String userId, String voucherId) async {
    try {
      await _supabase.from('user_claimed_vouchers').insert({
        'user_id': userId,
        'voucher_id': voucherId,
      });
      return true;
    } catch (e) {
      debugPrint('Error claiming voucher: $e');
      return false;
    }
  }

  /// Get all claimed, unused vouchers for a user, including voucher details
  Future<List<Map<String, dynamic>>> getUserClaimedVouchers(String userId) async {
    try {
      final response = await _supabase
          .from('user_claimed_vouchers')
          .select('*, vouchers(*)')
          .eq('user_id', userId)
          .eq('is_used', false);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Error fetching claimed vouchers: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getFarmerVouchersForUser({
    required String farmerId,
    required String userId,
  }) async {
    try {
      // Resolve farmer profile ID to user ID if needed
      String targetUserId = farmerId;
      final farmerData = await _supabase
          .from('farmers')
          .select('user_id')
          .eq('farmer_id', farmerId)
          .maybeSingle();
      if (farmerData != null && farmerData['user_id'] != null) {
        targetUserId = farmerData['user_id'].toString();
      }

      // 1. Fetch all active vouchers for this farmer
      final now = DateTime.now().toIso8601String();
      final activeVouchers = await _supabase
          .from('vouchers')
          .select()
          .eq('farmer_id', targetUserId)
          .gte('end_date', now)
          .lte('start_date', now);

      final vouchersList = List<Map<String, dynamic>>.from(activeVouchers as List);

      // 2. Fetch claimed vouchers for this user
      final claimedResponse = await _supabase
          .from('user_claimed_vouchers')
          .select('voucher_id')
          .eq('user_id', userId);

      final claimedIds = List<Map<String, dynamic>>.from(claimedResponse as List)
          .map((item) => item['voucher_id'].toString())
          .toSet();

      // 3. Flag claimed status
      for (var voucher in vouchersList) {
        voucher['is_claimed'] = claimedIds.contains(voucher['voucher_id'].toString());
      }

      return vouchersList;
    } catch (e) {
      debugPrint('Error fetching farmer vouchers for user: $e');
      return [];
    }
  }

  /// Get valid vouchers a user can apply at checkout for a specific farmer and spend amount
  Future<List<Map<String, dynamic>>> getValidCheckoutVouchers({
    required String userId,
    required String farmerId,
    required double cartAmount,
  }) async {
    try {
      final claimed = await getUserClaimedVouchers(userId);
      final List<Map<String, dynamic>> valid = [];

      for (var item in claimed) {
        final voucher = item['vouchers'] as Map<String, dynamic>?;
        if (voucher != null) {
          final vFarmerId = voucher['farmer_id'].toString();
          final minSpend = (voucher['min_spend'] as num).toDouble();
          
          if (vFarmerId == farmerId && cartAmount >= minSpend) {
            // Include claim ID for applying
            final Map<String, dynamic> enriched = Map.from(voucher);
            enriched['claim_id'] = item['claim_id'];
            valid.add(enriched);
          }
        }
      }
      return valid;
    } catch (e) {
      debugPrint('Error filtering valid checkout vouchers: $e');
      return [];
    }
  }

  /// Mark a claimed voucher as used and increment its used count
  Future<void> markVoucherAsUsed(String claimId, String voucherId) async {
    try {
      // 1. Mark as used
      await _supabase
          .from('user_claimed_vouchers')
          .update({'is_used': true})
          .eq('claim_id', claimId);

      // 2. Fetch current voucher used_count
      final voucher = await _supabase
          .from('vouchers')
          .select('used_count')
          .eq('voucher_id', voucherId)
          .single();

      final currentUsed = (voucher['used_count'] as num).toInt();

      // 3. Increment used_count
      await _supabase
          .from('vouchers')
          .update({'used_count': currentUsed + 1})
          .eq('voucher_id', voucherId);
    } catch (e) {
      debugPrint('Error marking voucher as used: $e');
    }
  }
}
