import 'dart:math';
import 'supabase_config.dart';

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
  Future<bool> storeOTP({
    required String email,
    required String code,
  }) async {
    try {
      // Delete any existing OTP for this email
      await _client
          .from('verification_codes')
          .delete()
          .eq('user_email', email);

      // Insert new OTP
      await _client.from('verification_codes').insert({
        'user_email': email,
        'code': code,
        'created_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now().add(const Duration(minutes: 10)).toIso8601String(),
        'attempts': 0,
        'is_verified': false,
      });

      return true;
    } catch (e) {
      print('Error storing OTP: $e');
      return false;
    }
  }

  /// Verify OTP code
  /// Returns true if code is valid, false otherwise
  Future<bool> verifyOTP({
    required String email,
    required String code,
  }) async {
    try {
      final response = await _client
          .from('verification_codes')
          .select()
          .eq('user_email', email)
          .maybeSingle();

      if (response == null) {
        print('No OTP found for this email');
        return false;
      }

      // Check if expired
      final expiresAt = DateTime.parse(response['expires_at'] as String);
      if (DateTime.now().isAfter(expiresAt)) {
        print('OTP expired');
        return false;
      }

      // Check if code matches
      if (response['code'] != code) {
        // Increment attempts
        int attempts = (response['attempts'] as int? ?? 0) + 1;
        await _client
            .from('verification_codes')
            .update({'attempts': attempts})
            .eq('user_email', email);

        // Block after 5 wrong attempts
        if (attempts >= 5) {
          await _client
              .from('verification_codes')
              .delete()
              .eq('user_email', email);
          print('Too many attempts');
        }

        return false;
      }

      // Mark as verified
      await _client
          .from('verification_codes')
          .update({'is_verified': true})
          .eq('user_email', email);

      return true;
    } catch (e) {
      print('Error verifying OTP: $e');
      return false;
    }
  }

  /// Check if OTP exists and is not expired
  Future<bool> otpExists({required String email}) async {
    try {
      final response = await _client
          .from('verification_codes')
          .select()
          .eq('user_email', email)
          .maybeSingle();

      if (response == null) return false;

      final expiresAt = DateTime.parse(response['expires_at'] as String);
      return DateTime.now().isBefore(expiresAt);
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
