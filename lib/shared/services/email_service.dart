import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class EmailService {
  static const String _awsSesEndpoint =
      'https://u7it0loyg9.execute-api.ap-southeast-2.amazonaws.com/dev/send-email';

  /// Send an OTP verification code email via AWS SES
  static Future<bool> sendOTPEmail({
    required String email,
    required String otpCode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_awsSesEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to': email,
          'subject': 'Your AgriDirect Verification Code',
          'body': 'Your verification code is: $otpCode\n\nThis code expires in 10 minutes.',
          'otpCode': otpCode,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[EmailService] Error sending OTP email: $e');
      return false;
    }
  }

  /// Send password reset code email via AWS SES
  static Future<bool> sendPasswordResetCode({
    required String email,
    required String code,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_awsSesEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to': email,
          'subject': 'AgriDirect - Password Reset Code',
          'body':
              'Your password reset code is: $code\n\nThis code expires in 10 minutes.\n\nIf you did not request this code, please ignore this email.',
          'resetCode': code,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[EmailService] Error sending password reset code: $e');
      return false;
    }
  }
}
