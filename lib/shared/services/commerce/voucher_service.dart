import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VoucherService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Create a new store voucher matching the Supabase SQL schema precisely
  Future<Map<String, dynamic>?> createVoucher({
    required String farmerId,
    required String code,
    required String discountType,
    required double discountValue,
    required double minSpend,
    double? maxDiscount,
    int usageLimit = 100,
    required DateTime startDate,
    required DateTime endDate,
    String? title,
    String? description,
  }) async {
    try {
      // 1. Resolve farmer profile & ID from farmers table
      String resolvedFarmerId = farmerId;
      String farmName = 'Farm Store';

      try {
        final farmerRecord = await _supabase
            .from('farmers')
            .select('farmer_id, user_id, farm_name')
            .or('user_id.eq.$farmerId,farmer_id.eq.$farmerId')
            .maybeSingle();

        if (farmerRecord != null) {
          resolvedFarmerId = farmerRecord['farmer_id']?.toString() ??
              farmerRecord['user_id']?.toString() ??
              farmerId;
          farmName = farmerRecord['farm_name']?.toString() ?? farmName;
        }
      } catch (e) {
        debugPrint('Farmer resolution notice (non-fatal): $e');
      }

      final cleanCode = code.toUpperCase().trim();
      final defaultTitle = title ??
          (discountType == 'flat'
              ? '₱${discountValue.toStringAsFixed(0)} OFF'
              : (discountType == 'free_shipping'
                  ? 'Free Delivery Voucher'
                  : '${discountValue.toStringAsFixed(0)}% OFF Fresh Produce'));
      final defaultDesc = description ??
          'Direct farm discount from $farmName (Min. spend ₱${minSpend.toStringAsFixed(0)})';

      // Precise Postgres schema payload for public.vouchers table
      final payload = {
        'farmer_id': resolvedFarmerId,
        'code': cleanCode,
        'title': defaultTitle,
        'description': defaultDesc,
        'discount_type': discountType,
        'discount_percentage': discountValue,
        'min_spend': minSpend,
        'max_discount': ?maxDiscount,
        'valid_until': endDate.toIso8601String(),
        'is_active': true,
      };

      final response = await _supabase
          .from('vouchers')
          .insert(payload)
          .select()
          .single();

      return response;
    } catch (e) {
      debugPrint('Error creating voucher: $e');
      throw Exception('Failed to create voucher: $e');
    }
  }

  /// Get all vouchers created by a specific farmer (resolving both user_id & farmer_id)
  Future<List<Map<String, dynamic>>> getFarmerVouchers(
      String farmerIdOrUserId) async {
    try {
      String targetUserId = farmerIdOrUserId;
      String targetFarmerId = farmerIdOrUserId;

      try {
        final farmerRecord = await _supabase
            .from('farmers')
            .select('farmer_id, user_id')
            .or('user_id.eq.$farmerIdOrUserId,farmer_id.eq.$farmerIdOrUserId')
            .maybeSingle();

        if (farmerRecord != null) {
          targetFarmerId =
              farmerRecord['farmer_id']?.toString() ?? targetFarmerId;
          targetUserId = farmerRecord['user_id']?.toString() ?? targetUserId;
        }
      } catch (_) {}

      final response = await _supabase
          .from('vouchers')
          .select()
          .or('farmer_id.eq.$targetFarmerId,farmer_id.eq.$targetUserId')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Error fetching farmer vouchers: $e');
      return [];
    }
  }

  /// Get all active farmer-issued vouchers enriched with farmer profiles for public hubs
  Future<List<Map<String, dynamic>>> getAllActiveFarmerVouchers() async {
    try {
      final now = DateTime.now().toIso8601String();
      final response = await _supabase
          .from('vouchers')
          .select('*, farmers(farm_name, image_url, face_photo_path, location, residential_address)')
          .eq('is_active', true)
          .or('valid_until.gte.$now,valid_until.is.null')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> vouchers =
          List<Map<String, dynamic>>.from(response as List);

      for (var v in vouchers) {
        final farmer = v['farmers'] as Map<String, dynamic>? ?? {};
        v['farm_name'] = farmer['farm_name'] ?? 'Local Verified Farm';
        v['avatar_url'] = farmer['image_url'] ?? farmer['face_photo_path'];
        v['location'] = farmer['location'] ??
            farmer['residential_address'] ??
            'San Carlos City';
      }

      return vouchers;
    } catch (e) {
      debugPrint('Error fetching all active farmer vouchers: $e');
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

  /// Claim a voucher for a user into user_vouchers
  Future<bool> claimVoucher(String userId, String voucherId) async {
    try {
      await _supabase.from('user_vouchers').insert({
        'user_id': userId,
        'voucher_id': voucherId,
        'status': 'available',
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
          .from('user_vouchers')
          .select('*, vouchers(*, farmers(farm_name, image_url, face_photo_path))')
          .eq('user_id', userId)
          .eq('status', 'available')
          .order('claimed_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(response as List);
      return list.map((item) {
        final map = Map<String, dynamic>.from(item);
        final voucher = map['vouchers'] as Map<String, dynamic>? ?? {};
        final farmer = voucher['farmers'] as Map<String, dynamic>? ?? {};
        map['claim_id'] = map['id'];
        map['vouchers'] = {
          ...voucher,
          'farm_name': farmer['farm_name'] ?? 'Local Farm',
          'avatar_url': farmer['image_url'] ?? farmer['face_photo_path'],
        };
        return map;
      }).toList();
    } catch (e) {
      debugPrint('Error fetching claimed vouchers: $e');
      return [];
    }
  }

  /// Get all claimed vouchers for a user (history) enriched with farmer profiles
  Future<List<Map<String, dynamic>>> getUserClaimedVouchersHistory(String userId) async {
    try {
      final response = await _supabase
          .from('user_vouchers')
          .select('*, vouchers(*, farmers(farm_name, image_url, face_photo_path))')
          .eq('user_id', userId)
          .order('claimed_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(response as List);
      return list.map((item) {
        final map = Map<String, dynamic>.from(item);
        final voucher = map['vouchers'] as Map<String, dynamic>? ?? {};
        final farmer = voucher['farmers'] as Map<String, dynamic>? ?? {};
        map['claim_id'] = map['id'];
        map['vouchers'] = {
          ...voucher,
          'farm_name': farmer['farm_name'] ?? 'Local Farm',
          'avatar_url': farmer['image_url'] ?? farmer['face_photo_path'],
        };
        return map;
      }).toList();
    } catch (e) {
      debugPrint('Error fetching claimed vouchers history: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getFarmerVouchersForUser({
    required String farmerId,
    required String userId,
  }) async {
    try {
      String targetUserId = farmerId;
      final farmerData = await _supabase
          .from('farmers')
          .select('farmer_id, user_id')
          .or('user_id.eq.$farmerId,farmer_id.eq.$farmerId')
          .maybeSingle();

      if (farmerData != null) {
        targetUserId = farmerData['farmer_id']?.toString() ??
            farmerData['user_id']?.toString() ??
            farmerId;
      }

      final now = DateTime.now().toIso8601String();
      final activeVouchers = await _supabase
          .from('vouchers')
          .select()
          .eq('farmer_id', targetUserId)
          .eq('is_active', true)
          .or('valid_until.gte.$now,valid_until.is.null');

      final vouchersList = List<Map<String, dynamic>>.from(activeVouchers as List);

      final claimedResponse = await _supabase
          .from('user_vouchers')
          .select('voucher_id')
          .eq('user_id', userId);

      final claimedIds = List<Map<String, dynamic>>.from(claimedResponse as List)
          .map((item) => item['voucher_id']?.toString())
          .toSet();

      for (var voucher in vouchersList) {
        voucher['is_claimed'] =
            claimedIds.contains(voucher['voucher_id']?.toString());
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
          final vFarmerId = voucher['farmer_id']?.toString() ?? '';
          final minSpend = (voucher['min_spend'] as num?)?.toDouble() ?? 0.0;

          if ((vFarmerId == farmerId || vFarmerId.isEmpty) &&
              cartAmount >= minSpend) {
            final Map<String, dynamic> enriched = Map.from(voucher);
            enriched['claim_id'] = item['claim_id'] ?? item['id'];
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

  /// Mark a claimed voucher as used
  Future<void> markVoucherAsUsed(String claimId, String voucherId) async {
    try {
      await _supabase
          .from('user_vouchers')
          .update({'status': 'used'})
          .eq('id', claimId);
    } catch (e) {
      debugPrint('Error marking voucher as used: $e');
    }
  }
}
