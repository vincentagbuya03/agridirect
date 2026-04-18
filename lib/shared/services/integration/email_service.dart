import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter/foundation.dart';

/// Email Service - Gmail SMTP Implementation
/// Handles sending of transactional emails (OTPs, Reset codes) using professional HTML templates.
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EmailService {
  // Use .env variables with hardcoded fallbacks
  static String get _gmailUser =>
      dotenv.env['GMAIL_USER'] ?? 'noreplyagridirect@gmail.com';

  static String get _gmailPass =>
      dotenv.env['GMAIL_PASS'] ?? 'snoe apvj svld cank';

  /// Send an OTP verification code email via Gmail SMTP
  static Future<bool> sendOTPEmail({
    required String email,
    required String otpCode,
  }) async {
    try {
      final smtpServer = gmail(_gmailUser, _gmailPass);

      final message = Message()
        ..from = Address(_gmailUser, 'AgriDirect Support')
        ..recipients.add(email)
        ..subject = 'AgriDirect: Account Verification Code'
        ..html = _buildHtmlTemplate(otpCode, 'verify your account');

      await send(message, smtpServer);
      return true;
    } catch (e) {
      debugPrint('[EmailService] Error sending OTP email: $e');
      return false;
    }
  }

  /// Send password reset code email via Gmail SMTP
  static Future<bool> sendPasswordResetCode({
    required String email,
    required String code,
  }) async {
    try {
      final smtpServer = gmail(_gmailUser, _gmailPass);

      final message = Message()
        ..from = Address(_gmailUser, 'AgriDirect Support')
        ..recipients.add(email)
        ..subject = 'AgriDirect: Password Reset Request'
        ..html = _buildHtmlTemplate(code, 'reset your password');

      await send(message, smtpServer);
      return true;
    } catch (e) {
      debugPrint('[EmailService] Error sending password reset code: $e');
      return false;
    }
  }

  /// Send password-changed security notification via Gmail SMTP
  static Future<bool> sendPasswordChangedAlert({required String email}) async {
    try {
      final smtpServer = gmail(_gmailUser, _gmailPass);

      final message = Message()
        ..from = Address(_gmailUser, 'AgriDirect Support')
        ..recipients.add(email)
        ..subject = 'AgriDirect: Your Password Was Changed'
        ..html = _buildPasswordChangedTemplate();

      await send(message, smtpServer);
      return true;
    } catch (e) {
      debugPrint('[EmailService] Error sending password changed alert: $e');
      return false;
    }
  }

  /// Modern, Enterprise-grade HTML Template Generator
  static String _buildHtmlTemplate(String code, String action) {
    final cleanCode = code.trim();
    final splitDigits = cleanCode.split('');
    final useDigitBoxes = splitDigits.length == 6;
    final isPasswordReset = action.toLowerCase().contains('reset');

    final actionLabel = isPasswordReset
        ? 'Password Reset Code'
        : 'Verification Code';
    final helpLine = isPasswordReset
        ? 'Enter this code in AgriDirect to continue resetting your password.'
        : 'Enter this code in AgriDirect to finish verifying your account.';

    final codeContent = useDigitBoxes
        ? splitDigits
              .map(
                (digit) =>
                    '<td style="width:42px; height:50px; border:1px solid #cfe0d1; border-radius:10px; background:#ffffff; text-align:center; font-family:\'Courier New\', Courier, monospace; font-size:28px; font-weight:700; color:#0f6c34;">$digit</td>',
              )
              .join('<td style="width:8px;"></td>')
        : '<td style="border:1px solid #cfe0d1; border-radius:10px; background:#ffffff; text-align:center; font-family:\'Courier New\', Courier, monospace; font-size:34px; font-weight:700; color:#0f6c34; letter-spacing:8px; padding:10px 16px;">$cleanCode</td>';

    return """
<!doctype html>
<html>
  <body style="margin:0; padding:0; background:#edf3ee; font-family:Arial, Helvetica, sans-serif;">
    <div style="display:none; max-height:0; overflow:hidden; opacity:0; mso-hide:all;">$actionLabel for your AgriDirect account.</div>
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background:#f3f7f4; padding:24px 12px;">
      <tr>
        <td align="center">
          <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="600" style="width:100%; max-width:600px; background:#ffffff; border:1px solid #d6e2d9; border-radius:16px; overflow:hidden;">
            <tr>
              <td style="height:6px; background:linear-gradient(90deg,#0f6c34,#2aa85a);"></td>
            </tr>
            <tr>
              <td style="padding:26px 28px 12px 28px; text-align:center;">
                <div style="font-size:34px; line-height:34px;">🌱</div>
                <h1 style="margin:10px 0 0 0; color:#0f6c34; font-size:30px; font-weight:800; line-height:1.2;">AgriDirect</h1>
                <p style="margin:6px 0 0 0; color:#5f6f62; font-size:14px; line-height:1.5;">Secure account access</p>
              </td>
            </tr>

            <tr>
              <td style="padding:0 28px 4px 28px; text-align:center;">
                <p style="margin:0; color:#153b24; font-size:20px; font-weight:700; line-height:1.4;">$actionLabel</p>
              </td>
            </tr>

            <tr>
              <td style="padding:8px 28px 0 28px;">
                <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background:#eef9f1; border:1px solid #cfe7d5; border-radius:12px;">
                  <tr>
                    <td style="padding:24px; text-align:center;">
                      <p style="margin:0 0 10px 0; color:#1f3c29; font-size:16px; line-height:1.5;">Use this code to $action.</p>
                      <p style="margin:0 0 16px 0; color:#476450; font-size:13px; line-height:1.5;">$helpLine</p>
                      <table role="presentation" cellpadding="0" cellspacing="0" border="0" align="center" style="margin:0 auto; border-collapse:separate; border-spacing:0;">
                        <tr>
                          $codeContent
                        </tr>
                      </table>
                      <p style="margin:14px 0 0 0; color:#4e6955; font-size:12px; line-height:1.5; font-weight:700;">This code expires in 10 minutes.</p>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>

            <tr>
              <td style="padding:18px 28px 6px 28px;">
                <p style="margin:0; color:#5f6f62; font-size:13px; line-height:1.6;">For your security, do not share this code with anyone. AgriDirect support will never ask for this code.</p>
              </td>
            </tr>

            <tr>
              <td style="padding:8px 28px 8px 28px;">
                <p style="margin:0; color:#6b7c70; font-size:12px; line-height:1.6;">If you did not request this, you can safely ignore this email.</p>
              </td>
            </tr>

            <tr>
              <td style="padding:18px 28px 26px 28px; border-top:1px solid #edf2ee; text-align:center;">
                <p style="margin:0; color:#8a978d; font-size:12px; line-height:1.6;">Need help? Contact AgriDirect Support</p>
                <p style="margin:4px 0 0 0; color:#8a978d; font-size:11px; line-height:1.6;">© 2026 AgriDirect. All rights reserved.</p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>
    """;
  }

  static String _buildPasswordChangedTemplate() {
    return """
<!doctype html>
<html>
  <body style="margin:0; padding:0; background:#edf3ee; font-family:Arial, Helvetica, sans-serif;">
    <div style="display:none; max-height:0; overflow:hidden; opacity:0; mso-hide:all;">Your AgriDirect password was changed.</div>
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background:#f3f7f4; padding:24px 12px;">
      <tr>
        <td align="center">
          <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="600" style="width:100%; max-width:600px; background:#ffffff; border:1px solid #d6e2d9; border-radius:16px; overflow:hidden;">
            <tr>
              <td style="height:6px; background:linear-gradient(90deg,#0f6c34,#2aa85a);"></td>
            </tr>
            <tr>
              <td style="padding:26px 28px 12px 28px; text-align:center;">
                <div style="font-size:34px; line-height:34px;">🔒</div>
                <h1 style="margin:10px 0 0 0; color:#0f6c34; font-size:28px; font-weight:800; line-height:1.2;">Password Updated</h1>
                <p style="margin:8px 0 0 0; color:#5f6f62; font-size:14px; line-height:1.5;">Your AgriDirect password was successfully changed.</p>
              </td>
            </tr>
            <tr>
              <td style="padding:8px 28px 0 28px;">
                <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background:#eef9f1; border:1px solid #cfe7d5; border-radius:12px;">
                  <tr>
                    <td style="padding:18px 20px; text-align:left;">
                      <p style="margin:0; color:#1f3c29; font-size:14px; line-height:1.6;">If this was you, no action is needed.</p>
                      <p style="margin:8px 0 0 0; color:#1f3c29; font-size:14px; line-height:1.6;">If this was not you, reset your password immediately and contact support.</p>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
            <tr>
              <td style="padding:16px 28px 10px 28px;">
                <p style="margin:0; color:#6b7c70; font-size:12px; line-height:1.6;">This is an automated security alert from AgriDirect.</p>
              </td>
            </tr>
            <tr>
              <td style="padding:16px 28px 24px 28px; border-top:1px solid #edf2ee; text-align:center;">
                <p style="margin:0; color:#8a978d; font-size:11px; line-height:1.6;">© 2026 AgriDirect. All rights reserved.</p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>
    """;
  }
}
