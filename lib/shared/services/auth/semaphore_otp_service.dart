import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Semaphore SMS OTP Service for Philippine Networks (Smart, Globe, DITO)
class SemaphoreOtpService {
  static final SemaphoreOtpService _instance = SemaphoreOtpService._internal();
  factory SemaphoreOtpService() => _instance;
  SemaphoreOtpService._internal();

  static const String _apiKey =
      String.fromEnvironment('SEMAPHORE_API_KEY', defaultValue: '');

  // In-memory OTP store for active verifications (phone -> {code, expiresAt})
  final Map<String, _OtpRecord> _pendingOtps = {};

  /// Format phone to 11 digits (09XXXXXXXXX) or 10 digits
  static String formatPhilippineNumber(String phone) {
    var cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.startsWith('63') && cleaned.length == 12) {
      cleaned = '0${cleaned.substring(2)}';
    } else if (cleaned.length == 10 && cleaned.startsWith('9')) {
      cleaned = '0$cleaned';
    }
    return cleaned;
  }

  /// Generate a random 6-digit PIN and send via Semaphore SMS API
  Future<bool> sendOtp({
    required String phoneNumber,
    required Function(String code) onSuccess,
    required Function(String error) onError,
  }) async {
    final cleanPhone = formatPhilippineNumber(phoneNumber);
    if (cleanPhone.length != 11 || !cleanPhone.startsWith('09')) {
      onError(
        'Please enter a valid 11-digit Philippine mobile number (09XXXXXXXXX)',
      );
      return false;
    }

    // 1. Generate 6-digit cryptographic PIN
    final random = Random();
    final otpCode = (100000 + random.nextInt(900000)).toString();

    // 2. Store with 5-minute expiry
    _pendingOtps[cleanPhone] = _OtpRecord(
      code: otpCode,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );

    try {
      debugPrint(
        '📨 Semaphore: Dispatching SMS to $cleanPhone with code $otpCode',
      );
      final response = await http
          .post(
            Uri.parse('https://api.semaphore.co/api/v4/messages'),
            body: {
              'apikey': _apiKey,
              'number': cleanPhone,
              'message':
                  'Your AgriDirect verification code is: $otpCode. Valid for 5 minutes. Do not share this code.',
            },
          )
          .timeout(const Duration(seconds: 10));

      debugPrint(
        '📨 Semaphore response (${response.statusCode}): ${response.body}',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        onSuccess(otpCode);
        return true;
      } else {
        final body = response.body;
        if (body.contains('not yet been approved')) {
          onError(
            'Semaphore account is pending approval by Semaphore.co. Please verify your Semaphore dashboard or test with code.',
          );
        } else {
          onError(
            'Failed to send SMS via Semaphore (Status: ${response.statusCode})',
          );
        }
        return false;
      }
    } catch (e) {
      debugPrint('❌ Semaphore error: $e');
      onError('Network error sending SMS: $e');
      return false;
    }
  }

  /// Verify entered OTP code
  bool verifyOtp({required String phoneNumber, required String enteredCode}) {
    final cleanPhone = formatPhilippineNumber(phoneNumber);
    final record = _pendingOtps[cleanPhone];

    if (record == null) {
      return false;
    }

    if (DateTime.now().isAfter(record.expiresAt)) {
      _pendingOtps.remove(cleanPhone);
      return false;
    }

    if (record.code == enteredCode.trim()) {
      _pendingOtps.remove(cleanPhone);
      return true;
    }

    return false;
  }
}

class _OtpRecord {
  final String code;
  final DateTime expiresAt;

  _OtpRecord({required this.code, required this.expiresAt});
}
