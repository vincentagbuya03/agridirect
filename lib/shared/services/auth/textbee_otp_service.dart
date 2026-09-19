import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// TextBee Free SMS Gateway Service
/// Sends REAL carrier SMS directly to phone SIM cards via your paired Android phone.
class TextBeeOtpService {
  static final TextBeeOtpService _instance = TextBeeOtpService._internal();
  factory TextBeeOtpService() => _instance;
  TextBeeOtpService._internal();

  static String get _apiKey {
    const env = String.fromEnvironment('TEXTBEE_API_KEY', defaultValue: '');
    if (env.isNotEmpty) return env;
    try {
      return dotenv.env['TEXTBEE_API_KEY'] ?? '';
    } catch (_) {
      return '';
    }
  }

  static String get _fallbackDeviceId {
    const env = String.fromEnvironment('TEXTBEE_DEVICE_ID', defaultValue: '');
    if (env.isNotEmpty) return env;
    try {
      return dotenv.env['TEXTBEE_DEVICE_ID'] ?? '';
    } catch (_) {
      return '';
    }
  }

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

    if (_fallbackDeviceId.isNotEmpty) {
      _cachedDeviceId = _fallbackDeviceId;
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
    String? customCode,
    String? customMessage,
    required Function(String code) onSuccess,
    required Function(String error) onError,
  }) async {
    final formattedPhone = formatE164(phoneNumber);

    final random = Random();
    final otpCode = customCode ?? (100000 + random.nextInt(900000)).toString();

    final expiresAt = DateTime.now().add(const Duration(minutes: 10));
    _pendingOtps[formattedPhone] = _TextBeeOtpRecord(
      code: otpCode,
      expiresAt: expiresAt,
    );

    // Persist to local storage to survive app pause / background kill / tab reload
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'textbee_otp_$formattedPhone',
        jsonEncode({
          'code': otpCode,
          'expires_at': expiresAt.toIso8601String(),
        }),
      );
    } catch (e) {
      debugPrint('TextBee persistence save notice: $e');
    }

    if (_apiKey.isEmpty) {
      debugPrint('⚠️ TextBee: TEXTBEE_API_KEY is not set in .env');
      debugPrint('📲 [SIMULATED SMS OTP]: Generated code $otpCode for $formattedPhone');
      onSuccess(otpCode);
      return true;
    }

    try {
      final targetDeviceId = await resolveActiveDeviceId();
      final messageBody = customMessage ??
          'AgriDirect: Your verification code is: $otpCode. Valid for 10 minutes.';

      debugPrint('📲 TextBee: Dispatching Real SMS to $formattedPhone via device $targetDeviceId with code $otpCode');
      final response = await http.post(
        Uri.parse('$_baseUrl/devices/$targetDeviceId/send-sms'),
        headers: {
          'x-api-key': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'recipients': [formattedPhone],
          'message': messageBody,
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

  /// Verify entered OTP code (checks in-memory first, falls back to persistent storage)
  Future<bool> verifyOtp({
    required String phoneNumber,
    required String enteredCode,
  }) async {
    final formattedPhone = formatE164(phoneNumber);
    final cleanEnteredCode = enteredCode.trim();

    // 1. Check in-memory first
    final record = _pendingOtps[formattedPhone];
    if (record != null) {
      if (DateTime.now().isAfter(record.expiresAt)) {
        _pendingOtps.remove(formattedPhone);
        await _clearPersistedOtp(formattedPhone);
        return false;
      }

      if (record.code == cleanEnteredCode) {
        _pendingOtps.remove(formattedPhone);
        await _clearPersistedOtp(formattedPhone);
        return true;
      }
    }

    // 2. Fallback to SharedPreferences if app process was refreshed or suspended
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('textbee_otp_$formattedPhone');
      if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final code = data['code']?.toString() ?? '';
        final expiresAtStr = data['expires_at']?.toString() ?? '';
        final expiresAt =
            DateTime.tryParse(expiresAtStr) ?? DateTime.fromMillisecondsSinceEpoch(0);

        if (DateTime.now().isAfter(expiresAt)) {
          await prefs.remove('textbee_otp_$formattedPhone');
          return false;
        }

        if (code == cleanEnteredCode) {
          await prefs.remove('textbee_otp_$formattedPhone');
          _pendingOtps.remove(formattedPhone);
          return true;
        }
      }
    } catch (e) {
      debugPrint('TextBee persistence check notice: $e');
    }

    return false;
  }

  Future<void> _clearPersistedOtp(String formattedPhone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('textbee_otp_$formattedPhone');
    } catch (_) {}
  }
}

class _TextBeeOtpRecord {
  final String code;
  final DateTime expiresAt;

  _TextBeeOtpRecord({required this.code, required this.expiresAt});
}
