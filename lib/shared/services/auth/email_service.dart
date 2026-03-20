import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';

class EmailService {
  /// Supabase Edge Function endpoint for sending OTP emails via Gmail SMTP
  static String get _edgeFunctionUrl =>
      '${SupabaseConfig.supabaseUrl}/functions/v1/send-email';

  /// Send an OTP verification code email via Supabase Edge Function (Gmail SMTP)
  static Future<bool> sendOTPEmail({
    required String email,
    required String otpCode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_edgeFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
        },
        body: jsonEncode({
          'to': email,
          'otpCode': otpCode,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[EmailService] Error sending OTP email: $e');
      return false;
    }
  }
}
