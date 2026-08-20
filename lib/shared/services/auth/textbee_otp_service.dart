import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// TextBee Free SMS Gateway Service
/// Sends REAL carrier SMS directly to phone SIM cards via your paired Android phone.
class TextBeeOtpService {
  static final TextBeeOtpService _instance = TextBeeOtpService._internal();
  factory TextBeeOtpService() => _instance;
  TextBeeOtpService._internal();

  static const String _apiKey =
      String.fromEnvironment('TEXTBEE_API_KEY', defaultValue: '');
  static const String _fallbackDeviceId =
      String.fromEnvironment('TEXTBEE_DEVICE_ID', defaultValue: '');
  static const String _baseUrl = 'https://api.textbee.dev/api/v1/gateway';

  final Map<String, _TextBeeOtpRecord> _pendingOtps = {};
  String? _cachedDeviceId;

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

  /// Automatically discovers the active paired device ID
  Future<String> resolveActiveDeviceId() async {
    if (_cachedDeviceId != null && _cachedDeviceId!.isNotEmpty) {
      return _cachedDeviceId!;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/devices'),
        headers: {'x-api-key': _apiKey},
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List devices = data['data'] ?? [];
        if (devices.isNotEmpty) {
          // Find default or first enabled device
          final activeDevice = devices.firstWhere(
            (d) => d['enabled'] == true,
            orElse: () => devices.first,
          );
          _cachedDeviceId = activeDevice['_id'] ?? activeDevice['id'];
          debugPrint('📱 Dynamic TextBee device selected: $_cachedDeviceId (${activeDevice['name'] ?? activeDevice['brand']})');
          return _cachedDeviceId!;
        }
      }
    } catch (e) {
      debugPrint('TextBee dynamic device resolution notice: $e');
    }

    return _fallbackDeviceId;
  }

  /// Sends a REAL SMS OTP directly to any Philippine mobile number
  Future<bool> sendOtp({
    required String phoneNumber,
    required Function(String code) onSuccess,
    required Function(String error) onError,
  }) async {
    final formattedPhone = formatE164(phoneNumber);

    final random = Random();
    final otpCode = (100000 + random.nextInt(900000)).toString();

    _pendingOtps[formattedPhone] = _TextBeeOtpRecord(
      code: otpCode,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );

    try {
      final targetDeviceId = await resolveActiveDeviceId();

      debugPrint('📲 TextBee: Dispatching Real SMS to $formattedPhone via device $targetDeviceId with code $otpCode');
      final response = await http.post(
        Uri.parse('$_baseUrl/devices/$targetDeviceId/send-sms'),
        headers: {
          'x-api-key': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'recipients': [formattedPhone],
          'message': 'Your AgriDirect verification code is: $otpCode. Valid for 5 minutes.',
        }),
      ).timeout(const Duration(seconds: 12));

      debugPrint('📲 TextBee response (${response.statusCode}): ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        onSuccess(otpCode);
        return true;
      } else {
        onError('TextBee error (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ TextBee error: $e');
      onError('Network error sending SMS via TextBee: $e');
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

class _TextBeeOtpRecord {
  final String code;
  final DateTime expiresAt;

  _TextBeeOtpRecord({required this.code, required this.expiresAt});
}
