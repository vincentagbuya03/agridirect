import 'package:http/http.dart' as http;
import 'dart:convert';

class EmailService {
  // Replace this with YOUR actual API Gateway Invoke URL
  static const String apiEndpoint = 'https://u7it0loyg9.execute-api.ap-southeast-2.amazonaws.com/dev/send-email';

  /// Send an email via AWS SES
  static Future<bool> sendEmail({
    required String recipient,
    required String subject,
    required String body,
  }) async {
    try {
      print('[EmailService] Sending email to: $recipient');
      print('[EmailService] Subject: $subject');
      print('[EmailService] Endpoint: $apiEndpoint');

      final requestBody = jsonEncode({
        'recipient': recipient,
        'subject': subject,
        'body': body,
      });

      print('[EmailService] Request body: $requestBody');

      final response = await http.post(
        Uri.parse(apiEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('[EmailService] Request timed out after 30 seconds');
          return http.Response('Request timed out', 408);
        },
      );

      print('[EmailService] Response status: ${response.statusCode}');
      print('[EmailService] Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('[EmailService] Email sent successfully to $recipient');
        return true;
      } else {
        print('[EmailService] Failed to send email. Status: ${response.statusCode}, Body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('[EmailService] Error: $e');
      return false;
    }
  }

  /// Send order confirmation email
  static Future<bool> sendOrderConfirmation({
    required String email,
    required String orderId,
    required String items,
    required String totalPrice,
  }) async {
    final subject = 'Order Confirmation - #$orderId';
    final body = '''
Hello,

Your order has been confirmed!

Order ID: $orderId
Items: $items
Total: $totalPrice

Thank you for shopping with AgriDirect!

Best regards,
AgriDirect Team
    ''';

    return sendEmail(recipient: email, subject: subject, body: body);
  }

  /// Send password reset email
  static Future<bool> sendPasswordResetEmail({
    required String email,
    required String resetLink,
  }) async {
    final subject = 'Password Reset - AgriDirect';
    final body = '''
Hello,

Click the link below to reset your password:

$resetLink

This link will expire in 24 hours.

Best regards,
AgriDirect Team
    ''';

    return sendEmail(recipient: email, subject: subject, body: body);
  }

  /// Send account verification email
  static Future<bool> sendVerificationEmail({
    required String email,
    required String verificationCode,
  }) async {
    final subject = 'Verify Your AgriDirect Account';
    final body = '''
Hello,

Welcome to AgriDirect! 

Your verification code is: $verificationCode

Enter this code in the app to verify your account.

Best regards,
AgriDirect Team
    ''';

    return sendEmail(recipient: email, subject: subject, body: body);
  }

  /// Send OTP (One-Time Password) for email verification
  static Future<bool> sendOTPEmail({
    required String email,
    required String otpCode,
  }) async {
    final subject = 'Your AgriDirect Verification Code: $otpCode';
    final body = '''
Hello,

Welcome to AgriDirect!

Your one-time verification code is:

    $otpCode

This code will expire in 10 minutes.

If you did not request this code, please ignore this email.

Best regards,
AgriDirect Team
''';

    return sendEmail(recipient: email, subject: subject, body: body);
  }
}
