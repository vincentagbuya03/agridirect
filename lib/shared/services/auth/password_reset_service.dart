import 'package:flutter/foundation.dart';
import 'otp_service.dart';
import 'textbee_otp_service.dart';
import 'auth_service.dart';
import '../integration/email_service.dart';
import '../core/supabase_config.dart';

enum PasswordResetDeliveryMode { code, recoveryLink }

/// Password Reset Service - High-Security 3NF Implementation
/// Handles sending reset codes via Email or TextBee SMS OTP and updating passwords via secure DB RPCs.
class PasswordResetService {
  static final _client = SupabaseConfig.client;

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  static Future<String?> _findUserIdByIdentifier(String identifier) async {
    final clean = identifier.trim();
    if (clean.isEmpty) return null;

    if (!clean.contains('@')) {
      final digits = clean.replaceAll(RegExp(r'[^\d]'), '');
      if (digits.isNotEmpty) {
        String tenDigits = digits;
        if (digits.length >= 12 && digits.startsWith('639')) {
          tenDigits = digits.substring(2, 12);
        } else if (digits.length >= 11 && digits.startsWith('09')) {
          tenDigits = digits.substring(1, 11);
        } else if (digits.length >= 10 && digits.startsWith('9')) {
          tenDigits = digits.substring(0, 10);
        }

        final variantE164 = '+63$tenDigits';
        final variant63 = '63$tenDigits';
        final variant09 = '0$tenDigits';
        final variant10 = tenDigits;
        final syntheticEmail = '$variant63@phone.agridirect.ph';

        try {
          final row = await _client
              .from('users')
              .select('user_id')
              .or('phone.eq.$variantE164,phone.eq.$variant63,phone.eq.$variant09,phone.eq.$variant10,phone.ilike.%$tenDigits,email.eq.$syntheticEmail')
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          if (row != null && row['user_id'] != null) {
            return row['user_id'].toString();
          }
        } catch (_) {}
      }
    }

    final normalized = clean.toLowerCase();
    try {
      final usersRow = await _client
          .from('users')
          .select('user_id')
          .ilike('email', normalized)
          .maybeSingle();
      if (usersRow != null && usersRow['user_id'] != null) {
        return usersRow['user_id'].toString();
      }
    } catch (_) {}

    try {
      final viewRow = await _client
          .from('v_users_with_roles')
          .select('user_id')
          .ilike('email', normalized)
          .maybeSingle();
      if (viewRow != null && viewRow['user_id'] != null) {
        return viewRow['user_id'].toString();
      }
    } catch (_) {}

    return null;
  }

  static bool _isRetryableRecoveryError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('authretryablefetchexception') ||
        msg.contains('unexpected_failure') ||
        msg.contains('error sending recovery email') ||
        msg.contains('statuscode: 500') ||
        msg.contains('network');
  }

  static String _friendlyRecoveryError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('rate') || msg.contains('too many')) {
      return 'Too many reset attempts. Please wait a few minutes and try again.';
    }
    if (msg.contains('error sending recovery email') ||
        msg.contains('unexpected_failure')) {
      return 'We could not send the password reset email right now. Please try again later or contact support.';
    }
    if (_isRetryableRecoveryError(e)) {
      return 'Temporary delivery issue. Please try again in a moment.';
    }
    return e.toString().replaceAll('Exception:', '').trim();
  }

  static Future<void> _sendRecoveryEmailWithFallback({
    required String normalizedEmail,
  }) async {
    final redirectUrl = kIsWeb
        ? '${Uri.base.origin}/reset-password'
        : 'com.agridirect://reset-password';

    // First try with explicit redirect, then fallback to server defaults.
    try {
      await _client.auth.resetPasswordForEmail(
        normalizedEmail,
        redirectTo: redirectUrl,
      );
      return;
    } catch (e) {
      debugPrint(
        '[PasswordResetService] Recovery email with redirect failed, retrying without redirect: $e',
      );
    }

    await _client.auth.resetPasswordForEmail(normalizedEmail);
  }

  /// Send a 6-digit password reset code to user's email or mobile number
  static Future<PasswordResetDeliveryMode> sendResetCode(String identifier) async {
    try {
      final clean = identifier.trim();
      final isPhone = !clean.contains('@');

      if (isPhone) {
        final digits = clean.replaceAll(RegExp(r'[^\d]'), '');
        String tenDigits = digits;
        if (digits.length >= 12 && digits.startsWith('639')) {
          tenDigits = digits.substring(2, 12);
        } else if (digits.length >= 11 && digits.startsWith('09')) {
          tenDigits = digits.substring(1, 11);
        } else if (digits.length >= 10 && digits.startsWith('9')) {
          tenDigits = digits.substring(0, 10);
        }

        final e164 = '+63$tenDigits';
        final userId = await _findUserIdByIdentifier(clean);
        if (userId == null) {
          throw 'No account found for mobile number $clean. Please check the number or sign up.';
        }

        final code = await _getOrCreatePasswordResetCode(userId);

        final smsSent = await TextBeeOtpService().sendOtp(
          phoneNumber: e164,
          customCode: code,
          customMessage: 'AgriDirect: Your password reset code is: $code. Valid for 10 minutes. Do not share this code.',
          onSuccess: (_) {
            debugPrint('✅ TextBee password reset SMS sent to $e164');
          },
          onError: (err) {
            debugPrint('❌ TextBee password reset SMS error: $err');
          },
        );

        if (!smsSent) {
          throw 'Failed to send SMS reset code to $clean. Please check your signal and try again.';
        }

        return PasswordResetDeliveryMode.code;
      }

      // Email flow
      final normalizedEmail = _normalizeEmail(clean);
      final userId = await _findUserIdByIdentifier(normalizedEmail);

      // If user row is missing in public table, seamlessly dispatch Supabase recovery email.
      if (userId == null) {
        debugPrint(
          '[PasswordResetService] No user profile in public table for $normalizedEmail, sending Supabase recovery email',
        );
        await _sendRecoveryEmailWithFallback(normalizedEmail: normalizedEmail);
        return PasswordResetDeliveryMode.recoveryLink;
      }

      // If user profile exists, generate/retrieve 6-digit OTP code in database.
      final code = await _getOrCreatePasswordResetCode(userId);

      // Attempt to send 6-digit code via EmailService (Web API on Web, Gmail SMTP on Mobile)
      bool sent = false;
      try {
        sent = await EmailService.sendPasswordResetCode(
          email: normalizedEmail,
          code: code,
        );
      } catch (e) {
        debugPrint('[PasswordResetService] Custom code email dispatch error: $e');
        sent = false;
      }

      // If custom code dispatch failed or is unreachable, seamlessly fallback to Supabase recovery email
      if (!sent) {
        debugPrint(
          '[PasswordResetService] Custom code dispatch failed or unreachable, falling back to Supabase recovery email for $normalizedEmail',
        );
        await _sendRecoveryEmailWithFallback(normalizedEmail: normalizedEmail);
        return PasswordResetDeliveryMode.recoveryLink;
      }

      return PasswordResetDeliveryMode.code;
    } catch (e) {
      debugPrint('[PasswordResetService] Error sending reset code: $e');
      throw _friendlyRecoveryError(e);
    }
  }

  static Future<String> _getOrCreatePasswordResetCode(String userId) async {
    final existingCode = await OTPService().getActiveOTPCode(
      userId: userId,
      type: 'password_reset',
    );

    final code =
        existingCode ??
        await OTPService().generateAndStoreOTP(
          userId: userId,
          type: 'password_reset',
        );

    if (code == null) {
      throw 'Failed to generate reset code. Please try again later.';
    }

    return code;
  }

  /// Verify code and update password securely
  static Future<void> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final resolvedEmail = await AuthService.resolveEmailForIdentifier(email);

      if (newPassword.trim().isEmpty || newPassword.trim().length < 6) {
        throw 'Password must be at least 6 characters.';
      }

      final response = await _client.functions.invoke(
        'reset-password-with-code',
        body: {
          'email': resolvedEmail,
          'code': code.trim(),
          'newPassword': newPassword,
        },
      );

      if (response.status >= 400) {
        final data = response.data;
        if (data is Map && data['error'] is String) {
          throw data['error'] as String;
        }
        throw 'Password reset failed. Please try again.';
      }

      // Security notification for email users
      if (!resolvedEmail.endsWith('@phone.agridirect.ph')) {
        await EmailService.sendPasswordChangedAlert(email: resolvedEmail);
      }
    } catch (e) {
      debugPrint('[PasswordResetService] Error resetting password: $e');
      rethrow;
    }
  }

  /// Reset the password using the latest active password-reset code for the email.
  /// This keeps the code invisible in the UI while still enforcing that it is
  /// unexpired and unused.
  static Future<void> resetPasswordWithLatestCode({
    required String email,
    required String newPassword,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    final userId = await _findUserIdByIdentifier(normalizedEmail);

    if (userId == null) {
      throw 'Account identification failed.';
    }

    final code = await OTPService().getActiveOTPCode(
      userId: userId,
      type: 'password_reset',
    );

    if (code == null) {
      throw 'Your reset code is expired or already used. Please request a new one.';
    }

    await resetPasswordWithCode(
      email: normalizedEmail,
      code: code,
      newPassword: newPassword,
    );
  }

  /// Verify reset code first (step 1), before accepting password input.
  static Future<void> verifyResetCode({
    required String email,
    required String code,
  }) async {
    try {
      final userId = await _findUserIdByIdentifier(email);
      if (userId == null) {
        throw 'Account identification failed.';
      }

      if (code.trim().isEmpty || code.trim().length != 6) {
        throw 'Please enter a valid 6-digit code.';
      }

      final verification = await OTPService().verifyOTP(
        userId: userId,
        code: code.trim(),
      );

      if (verification['success'] != true) {
        throw verification['message'] ?? 'Invalid or expired code.';
      }
    } catch (e) {
      debugPrint('[PasswordResetService] Error verifying reset code: $e');
      rethrow;
    }
  }

  /// After code verification succeeds, request Supabase recovery link.
  static Future<void> requestFinalResetLink({required String email}) async {
    final normalizedEmail = _normalizeEmail(email);

    final retryDelays = <Duration>[
      const Duration(milliseconds: 700),
      const Duration(milliseconds: 1400),
    ];

    Object? lastError;

    for (var attempt = 0; attempt < retryDelays.length; attempt++) {
      try {
        await _sendRecoveryEmailWithFallback(normalizedEmail: normalizedEmail);
        return;
      } catch (e) {
        lastError = e;
        debugPrint(
          '[PasswordResetService] Error requesting final reset link (attempt ${attempt + 1}): $e',
        );

        if (!_isRetryableRecoveryError(e) ||
            attempt == retryDelays.length - 1) {
          break;
        }

        await Future.delayed(retryDelays[attempt]);
      }
    }

    throw _friendlyRecoveryError(lastError ?? 'Unknown error');
  }
}
