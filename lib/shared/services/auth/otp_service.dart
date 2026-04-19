import 'package:flutter/foundation.dart';
import '../core/supabase_config.dart';

/// OTP (One-Time Password) Service - Professional 3NF Logic
/// Handles generation and verification of 6-digit OTP codes via secure DB RPCs.
class OTPService {
  static final OTPService _instance = OTPService._internal();
  factory OTPService() => _instance;
  OTPService._internal();

  final _client = SupabaseConfig.client;

  String _normalizeVerificationType(String type) {
    final normalized = type.trim().toLowerCase();

    // Backward compatibility: older app flows still pass "signup".
    if (normalized == 'signup') return 'email';

    return normalized;
  }

  /// Generate and store a secure 6-digit OTP using the Database RPC
  /// Returns the generated code or null if it fails.
  Future<String?> generateAndStoreOTP({
    required String userId,
    required String type, // e.g., 'signup' or 'password_reset'
  }) async {
    try {
      final normalizedType = _normalizeVerificationType(type);

      // 1. Call our secure DB function
      final response = await _client.rpc(
        'generate_verification_code',
        params: {'p_user_id': userId, 'p_type': normalizedType},
      );

      if (response == null || response['success'] != true) {
        debugPrint('❌ Error generating OTP from DB: ${response?['message']}');
        return null;
      }

      // 2. Return the 6-digit code for the SMTP service to send
      return response['code']?.toString();
    } catch (e) {
      debugPrint('❌ RPC Error calling generate_verification_code: $e');
      return null;
    }
  }

  /// Get the most recent active OTP for a user and type.
  /// Returns null when no unexpired, unused code exists.
  Future<String?> getActiveOTPCode({
    required String userId,
    required String type,
  }) async {
    try {
      final response = await _client
          .from('verification_codes')
          .select('verification_code, expires_at')
          .eq('user_id', userId)
          .eq('verification_type', type)
          .filter('used_at', 'is', null)
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      return response['verification_code']?.toString();
    } catch (e) {
      debugPrint('❌ Error getting active OTP code: $e');
      return null;
    }
  }

  /// Verify OTP code using the Database RPC
  /// If successful, the DB automatically marks the user's email as verified.
  Future<Map<String, dynamic>> verifyOTP({
    required String userId,
    required String code,
  }) async {
    try {
      // 1. Call our secure DB function
      final response = await _client.rpc(
        'verify_user_code',
        params: {'p_user_id': userId, 'p_code': code},
      );

      if (response == null) {
        return {
          'success': false,
          'message': 'Communication error with database',
        };
      }

      return {
        'success': response['success'] ?? false,
        'message': response['message'] ?? 'Unknown error',
      };
    } catch (e) {
      debugPrint('❌ RPC Error calling verify_user_code: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Check if a valid OTP currently exists for this user (not expired or used)
  Future<bool> otpExists({required String userId}) async {
    try {
      final response = await _client
          .from('verification_codes')
          .select()
          .eq('user_id', userId)
          .filter('used_at', 'is', null)
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('❌ Error checking OTP existence: $e');
      return false;
    }
  }

  /// Get remaining time for the current OTP (in seconds)
  Future<int?> getOTPTimeRemaining({required String userId}) async {
    try {
      final response = await _client
          .from('verification_codes')
          .select('expires_at')
          .eq('user_id', userId)
          .filter('used_at', 'is', null)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      final expiresAt = DateTime.parse(response['expires_at'] as String);
      final secondsRemaining = expiresAt.difference(DateTime.now()).inSeconds;

      return secondsRemaining > 0 ? secondsRemaining : 0;
    } catch (e) {
      debugPrint('❌ Error getting OTP time remaining: $e');
      return null;
    }
  }
}
