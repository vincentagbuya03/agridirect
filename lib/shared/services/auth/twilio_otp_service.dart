import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Twilio SMS OTP Service
class TwilioOtpService {
  static final TwilioOtpService _instance = TwilioOtpService._internal();
  factory TwilioOtpService() => _instance;
  TwilioOtpService._internal();

  static const String _accountSid =
      String.fromEnvironment('TWILIO_ACCOUNT_SID', defaultValue: '');
  static const String _authToken =
      String.fromEnvironment('TWILIO_AUTH_TOKEN', defaultValue: '');
  static const String _fromNumber =
      String.fromEnvironment('TWILIO_FROM_NUMBER', defaultValue: '');

  final Map<String, _TwilioOtpRecord> _pendingOtps = {};

  /// Format phone to E.164 (+639XXXXXXXXX)
  static String formatE164(String phone) {
    var cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.startsWith('09') && cleaned.length == 11) {
      cleaned = '+63${cleaned.substring(1)}';
    } else if (cleaned.startsWith('9') && cleaned.length == 10) {
      cleaned = '+63$cleaned';
    } else if (cleaned.startsWith('63') && !cleaned.startsWith('+')) {
      cleaned = '+$cleaned';
    } else if (!cleaned.startsWith('+') && cleaned.isNotEmpty) {
      cleaned = '+$cleaned';
    }
    return cleaned;
  }

  /// Sends a REAL SMS OTP directly to the phone via Twilio REST API
  Future<bool> sendOtp({
    required String phoneNumber,
    required Function(String code) onSuccess,
    required Function(String error) onError,
  }) async {
    final formattedPhone = formatE164(phoneNumber);

    final random = Random();
    final otpCode = (100000 + random.nextInt(900000)).toString();

    _pendingOtps[formattedPhone] = _TwilioOtpRecord(
      code: otpCode,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );

    final basicAuth = 'Basic ${base64Encode(utf8.encode('$_accountSid:$_authToken'))}';

    try {
      debugPrint('📲 Twilio: Dispatching SMS to $formattedPhone with code $otpCode');
      final response = await http.post(
        Uri.parse('https://api.twilio.com/2010-04-01/Accounts/$_accountSid/Messages.json'),
        headers: {
          'Authorization': basicAuth,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'From': _fromNumber,
          'To': formattedPhone,
          'Body': 'Your AgriDirect verification code is: $otpCode. Valid for 5 minutes.',
        },
      ).timeout(const Duration(seconds: 12));

      debugPrint('📲 Twilio response (${response.statusCode}): ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        onSuccess(otpCode);
        return true;
      } else {
        final decoded = jsonDecode(response.body);
        final msg = decoded['message'] ?? 'Failed to send SMS via Twilio';
        if (msg.contains('unverified')) {
          onError('Please add your number in Twilio Verified Caller IDs (twilio.com/user/account/phone-numbers/verified)');
        } else {
          onError(msg);
        }
        return false;
      }
    } catch (e) {
      debugPrint('❌ Twilio error: $e');
      onError('Network error sending SMS via Twilio: $e');
      return false;
    }
  }

  /// Verify entered OTP code
  bool verifyOtp({
    required String phoneNumber,
    required String enteredCode,
  }) {
    final formattedPhone = formatE164(phoneNumber);
    final record = _pendingOtps[formattedPhone];

    if (record == null) return false;
    if (DateTime.now().isAfter(record.expiresAt)) {
      _pendingOtps.remove(formattedPhone);
      return false;
    }

    if (record.code == enteredCode.trim()) {
      _pendingOtps.remove(formattedPhone);
      return true;
    }

    return false;
  }
}

class _TwilioOtpRecord {
  final String code;
  final DateTime expiresAt;

  _TwilioOtpRecord({required this.code, required this.expiresAt});
}
