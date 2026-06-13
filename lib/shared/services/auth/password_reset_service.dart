import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'otp_service.dart';
import '../integration/email_service.dart';
import '../core/supabase_config.dart';

enum PasswordResetDeliveryMode { code, recoveryLink }

/// Password Reset Service - High-Security 3NF Implementation
/// Handles sending reset codes and updating passwords via secure DB RPCs.
class PasswordResetService {
  static final _client = SupabaseConfig.client;

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  static Future<String?> _findUserIdByEmail(String email) async {
    final normalized = _normalizeEmail(email);
    if (normalized.isEmpty) return null;

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
      return 'Temporary email delivery issue. Please try again in a moment.';
    }
    return 'Unable to send reset link right now. Please try again later.';
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

  static String get _webEmailApiBase {
    final configured = dotenv.env['WEB_EMAIL_API_BASE']?.trim() ?? '';
    if (configured.isNotEmpty) return configured.replaceAll(RegExp(r'/$'), '');

    final currentOrigin = Uri.base.origin;
    final host = Uri.base.host.toLowerCase();
    if (host != 'localhost' && host != '127.0.0.1' && host != '::1') {
      return currentOrigin;
    }

    return 'https://agridirect-app.vercel.app';
  }

  static Future<void> _sendResetCodeViaWebApi(String normalizedEmail) async {
    final uri = Uri.parse('$_webEmailApiBase/api/password-reset/send-code');

    try {
      final response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'email': normalizedEmail}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }

      final data = jsonDecode(response.body);
      if (data is Map && data['error'] is String) {
        throw data['error'] as String;
      }

      throw 'Unable to send password reset email right now.';
    } catch (e) {
      debugPrint('[PasswordResetService] Web reset-code API failed: $e');
      final message = e.toString().toLowerCase();
      if (message.contains('failed to fetch') ||
          message.contains('xmlhttprequest error') ||
          message.contains('clientexception')) {
        throw 'Password reset email service is not reachable. Please deploy the web email API or check its environment variables.';
      }

      throw 'Unable to send password reset email right now. Please try again later or contact support.';
    }
  }

  /// Send a 6-digit password reset code to the user's email
  static Future<PasswordResetDeliveryMode> sendResetCode(String email) async {
    try {
      final normalizedEmail = _normalizeEmail(email);
      final userId = await _findUserIdByEmail(normalizedEmail);

      if (kIsWeb) {
        await _sendResetCodeViaWebApi(normalizedEmail);
        return PasswordResetDeliveryMode.code;
      }

      // If users/profile row is missing, still allow Supabase recovery email.
      if (userId == null) {
        await _sendRecoveryEmailWithFallback(normalizedEmail: normalizedEmail);
        return PasswordResetDeliveryMode.recoveryLink;
      }

      final code = await _getOrCreatePasswordResetCode(userId);

      // 3. Send via Gmail SMTP
      final sent = await EmailService.sendPasswordResetCode(
        email: normalizedEmail,
        code: code,
      );

      if (!sent) {
        debugPrint(
          '[PasswordResetService] Password reset code email failed, falling back to recovery link for $normalizedEmail',
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
      final normalizedEmail = _normalizeEmail(email);

      if (newPassword.trim().isEmpty || newPassword.trim().length < 6) {
        throw 'Password must be at least 6 characters.';
      }

      final response = await _client.functions.invoke(
        'reset-password-with-code',
        body: {
          'email': normalizedEmail,
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

      // Security notification should not block successful reset.
      await EmailService.sendPasswordChangedAlert(email: normalizedEmail);
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
    final userId = await _findUserIdByEmail(normalizedEmail);

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
      final normalizedEmail = _normalizeEmail(email);
      final userId = await _findUserIdByEmail(normalizedEmail);
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
