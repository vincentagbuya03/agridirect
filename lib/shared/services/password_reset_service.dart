import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'email_service.dart';

/// Service to handle password reset with verification codes
class PasswordResetService {
  static final _client = SupabaseConfig.client;
  static const _codeLength = 6;
  static const _codeExpiration = Duration(minutes: 10);

  /// Generate a random 6-digit code
  static String _generateCode() {
    final random = Random();
    return List.generate(_codeLength, (index) => random.nextInt(10)).join();
  }

  /// Send reset code to email
  static Future<void> sendResetCode(String email) async {
    try {
      debugPrint('📧 Sending reset code to $email');

      // Check if user exists
      final user = await _client
          .from('users')
          .select('user_id')
          .eq('email', email)
          .maybeSingle();

      if (user == null) {
        throw 'User not found with this email address';
      }

      final userId = user['user_id'] as String?;
      if (userId == null || userId.isEmpty) {
        debugPrint('❌ User found but user_id is null for email: $email');
        throw 'User account is not properly configured. Please contact support.';
      }

      // Generate code
      final code = _generateCode();
      debugPrint('🔐 Generated code: $code');

      // Delete any existing codes for this user
      await _client
          .from('password_reset_codes')
          .delete()
          .eq('user_id', userId);

      // Store code in database
      await _client.from('password_reset_codes').insert({
        'user_id': userId,
        'email': email,
        'code': code,
        'created_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now().add(_codeExpiration).toIso8601String(),
        'used': false,
      });

      debugPrint('✅ Code stored in database');

      // Send email with code
      await EmailService.sendPasswordResetCode(
        email: email,
        code: code,
      );

      debugPrint('✅ Reset code email sent');
    } catch (e) {
      debugPrint('❌ Error sending reset code: $e');
      rethrow;
    }
  }

  /// Verify code and reset password
  static Future<void> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      debugPrint('🔐 Verifying reset code for $email');

      // Check if code exists and is valid
      final resetRecord = await _client
          .from('password_reset_codes')
          .select()
          .eq('email', email)
          .eq('code', code)
          .eq('used', false)
          .maybeSingle();

      if (resetRecord == null) {
        throw 'Invalid verification code';
      }

      // Check if code is expired
      final expiresAt = DateTime.parse(resetRecord['expires_at'] as String);
      if (DateTime.now().isAfter(expiresAt)) {
        throw 'Verification code has expired';
      }

      // Check if code has already been used
      if (resetRecord['used'] == true) {
        throw 'This code has already been used';
      }

      // Get user
      final user = await _client
          .from('users')
          .select('user_id')
          .eq('email', email)
          .maybeSingle();

      if (user == null) {
        throw 'User not found';
      }

      // Update password using secure database function
      final result = await _client.rpc('reset_user_password', params: {
        'user_email': email,
        'new_password': newPassword,
      });

      if (result == false) {
        throw 'Failed to update password';
      }

      // Mark code as used
      await _client
          .from('password_reset_codes')
          .update({'used': true})
          .eq('email', email)
          .eq('code', code);

      debugPrint('✅ Password reset successfully');
    } catch (e) {
      debugPrint('❌ Error resetting password: $e');
      rethrow;
    }
  }

  /// Get remaining time for code
  static Future<Duration?> getCodeExpirationTime(String email) async {
    try {
      final resetRecord = await _client
          .from('password_reset_codes')
          .select()
          .eq('email', email)
          .eq('used', false)
          .maybeSingle();

      if (resetRecord == null) return null;

      final expiresAt = DateTime.parse(resetRecord['expires_at'] as String);
      final remaining = expiresAt.difference(DateTime.now());

      return remaining.isNegative ? Duration.zero : remaining;
    } catch (e) {
      debugPrint('Error getting expiration time: $e');
      return null;
    }
  }
}
