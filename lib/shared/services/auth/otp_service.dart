import 'dart:math';
import '../config/supabase_config.dart';

/// OTP (One-Time Password) Service
/// Handles generation, storage, and verification of 6-digit OTP codes
class OTPService {
  static final OTPService _instance = OTPService._internal();
  factory OTPService() => _instance;
  OTPService._internal();

  final _client = SupabaseConfig.client;

  /// Generate a random 6-digit OTP code
  static String generateOTP() {
    final random = Random();
    final code = (100000 + random.nextInt(900000)).toString();
    return code;
  }

  /// Store OTP code in database with 10-minute expiry
  /// Uses SECURITY DEFINER RPC to bypass RLS
  Future<bool> storeOTP({
    required String email,
    required String code,
  }) async {
    try {
      final result = await _client.rpc(
        'store_otp',
        params: {
          'p_email': email,
          'p_code': code,
          'p_expires_in_minutes': 10,
        },
      );
      return result == true;
    } catch (e) {
      print('Error storing OTP: $e');
      return false;
    }
  }

  /// Verify OTP code
  /// Returns true if code is valid, false otherwise
  /// Uses SECURITY DEFINER RPC to bypass RLS
  Future<bool> verifyOTP({
    required String email,
    required String code,
  }) async {
    try {
      final result = await _client.rpc(
        'verify_otp_code',
        params: {
          'p_email': email,
          'p_code': code,
        },
      );
      return result == true;
    } catch (e) {
      print('Error verifying OTP: $e');
      return false;
    }
  }

  /// Check if OTP exists and is not expired
  /// Uses SECURITY DEFINER RPC to bypass RLS
  Future<bool> otpExists({required String email}) async {
    try {
      final result = await _client.rpc(
        'otp_exists_check',
        params: {'p_email': email},
      );
      return result == true;
    } catch (e) {
      print('Error checking OTP: $e');
      return false;
    }
  }

  /// Get remaining time for OTP expiry (in seconds)
  Future<int?> getOTPTimeRemaining({required String email}) async {
    try {
      final response = await _client
          .from('verification_codes')
          .select('expires_at')
          .eq('user_email', email)
          .maybeSingle();

      if (response == null) return null;

      final expiresAt = DateTime.parse(response['expires_at'] as String);
      final secondsRemaining = expiresAt.difference(DateTime.now()).inSeconds;

      return secondsRemaining > 0 ? secondsRemaining : 0;
    } catch (e) {
      print('Error getting time remaining: $e');
      return null;
    }
  }

  /// Resend OTP (generate new code and delete old one)
  Future<String?> resendOTP({required String email}) async {
    try {
      final newCode = generateOTP();
      final success = await storeOTP(email: email, code: newCode);

      return success ? newCode : null;
    } catch (e) {
      print('Error resending OTP: $e');
      return null;
    }
  }

  /// Delete OTP after successful verification
  Future<void> deleteOTP({required String email}) async {
    try {
      await _client
          .from('verification_codes')
          .delete()
          .eq('user_email', email);
    } catch (e) {
      print('Error deleting OTP: $e');
    }
  }
}
