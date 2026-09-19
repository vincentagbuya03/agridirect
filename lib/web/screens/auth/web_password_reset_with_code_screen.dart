import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/auth/password_reset_service.dart';
import '../../../shared/router/app_router.dart';

/// Web Password Reset with Code Screen
/// High-Security 3NF Implementation.
class WebPasswordResetWithCodeScreen extends StatefulWidget {
  const WebPasswordResetWithCodeScreen({super.key});

  @override
  State<WebPasswordResetWithCodeScreen> createState() =>
      _WebPasswordResetWithCodeScreenState();
}

class _WebPasswordResetWithCodeScreenState
    extends State<WebPasswordResetWithCodeScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _codeSent = false;
  bool _codeVerified = false;
  bool _resetSuccess = false;
  bool _recoveryLinkSent = false;
  String? _feedbackMessage;
  bool _feedbackIsError = false;

  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  static const Color _primary = Color(0xFF16A34A);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _mutedDark = Color(0xFF6B7280);

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_cooldownSeconds <= 1) {
          _cooldownSeconds = 0;
          timer.cancel();
        } else {
          _cooldownSeconds--;
        }
      });
    });
  }

  Future<void> _handleSendCode() async {
    if (_isLoading || _cooldownSeconds > 0) return;

    final identifier = _emailController.text.trim();
    final isEmail = identifier.contains('@');
    final digits = identifier.replaceAll(RegExp(r'[^\d]'), '');
    final isPhone = digits.length >= 10 &&
        (digits.startsWith('9') ||
            digits.startsWith('09') ||
            digits.startsWith('639'));

    if (identifier.isEmpty || (!isEmail && !isPhone)) {
      _setFeedback(
        'Please enter a valid email address or Philippine mobile number',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _feedbackMessage = null;
    });

    try {
      final mode = await PasswordResetService.sendResetCode(identifier);

      if (mode == PasswordResetDeliveryMode.code) {
        setState(() {
          _isLoading = false;
          _codeSent = true;
        });
        _startCooldown(60);
        _setFeedback(
          isPhone
              ? 'Reset code sent via SMS! Check your messages, then enter the code below.'
              : 'Reset code sent! Check your email, then set your new password below.',
          isError: false,
        );
      } else {
        setState(() {
          _isLoading = false;
          _recoveryLinkSent = true;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _setFeedback(e.toString(), isError: true);
    }
  }

  Future<void> _handleVerifyCode() async {
    final identifier = _emailController.text.trim();
    final code = _codeController.text.trim();

    if (identifier.isEmpty || code.isEmpty) {
      _setFeedback('Please fill in all fields', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _feedbackMessage = null;
    });

    try {
      await PasswordResetService.verifyResetCode(email: identifier, code: code);
      setState(() {
        _isLoading = false;
        _codeVerified = true;
      });
      _setFeedback('Code verified! Set your new password.', isError: false);
    } catch (e) {
      setState(() => _isLoading = false);
      _setFeedback('Invalid code: $e', isError: true);
    }
  }

  Future<void> _handleResetPassword() async {
    final identifier = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    final isEmail = identifier.contains('@');
    final digits = identifier.replaceAll(RegExp(r'[^\d]'), '');
    final isPhone = digits.length >= 10 &&
        (digits.startsWith('9') ||
            digits.startsWith('09') ||
            digits.startsWith('639'));

    if (identifier.isEmpty || (!isEmail && !isPhone)) {
      _setFeedback(
        'Please enter a valid email address or Philippine mobile number',
        isError: true,
      );
      return;
    }

    if (password.isEmpty || confirmPassword.isEmpty) {
      _setFeedback('Please fill in all fields', isError: true);
      return;
    }

    if (password.length < 6) {
      _setFeedback('Password must be at least 6 characters', isError: true);
      return;
    }

    if (password != confirmPassword) {
      _setFeedback('Passwords do not match', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _feedbackMessage = null;
    });

    try {
      await PasswordResetService.resetPasswordWithCode(
        email: identifier,
        code: _codeController.text.trim(),
        newPassword: password,
      );

      setState(() {
        _isLoading = false;
        _resetSuccess = true;
      });

      _setFeedback('Password reset successfully!', isError: false);
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      context.go(AppRoutes.login);
    } catch (e) {
      setState(() => _isLoading = false);
      _setFeedback('Failed to reset password: $e', isError: true);
    }
  }

  void _setFeedback(String message, {required bool isError}) {
    if (!mounted) return;
    setState(() {
      _feedbackMessage = message;
      _feedbackIsError = isError;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final shortestSide = screenSize.shortestSide;
    final isHandset = shortestSide < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = isHandset ? 16.0 : 24.0;
            final cardPadding = isHandset ? 24.0 : 40.0;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(cardPadding),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x140F172A),
                          blurRadius: 32,
                          offset: Offset(0, 16),
                        ),
                      ],
                    ),
                    child: _recoveryLinkSent
                        ? _buildRecoveryLinkSentView()
                        : _resetSuccess
                        ? _buildSuccessView()
                        : _codeVerified
                        ? _buildCreatePasswordForm()
                        : _codeSent
                        ? _buildVerifyCodeForm()
                        : _buildSendCodeForm(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSendCodeForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock_reset_rounded, color: _primary, size: 64),
        const SizedBox(height: 32),
        Text(
          'Reset Password',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Enter your email or registered mobile number to receive a reset code.',
          textAlign: TextAlign.center,
        ),
        if (_feedbackMessage != null) ...[
          const SizedBox(height: 20),
          _buildFeedbackBanner(),
        ],
        const SizedBox(height: 36),
        _buildTextField(
          _emailController,
          'Email or Mobile Number',
          Icons.account_circle_outlined,
          hint: 'name@example.com or 09XXXXXXXXX',
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: (_isLoading || _cooldownSeconds > 0)
                ? null
                : _handleSendCode,
            child: _isLoading
                ? const AppShimmerLoader(color: Colors.white)
                : Text(
                    _cooldownSeconds > 0
                        ? 'Resend Code in ${_cooldownSeconds}s'
                        : 'Send Reset Code',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        TextButton(
          onPressed: () => context.go(AppRoutes.login),
          child: const Text('Back to Login', style: TextStyle(color: _primary)),
        ),
      ],
    );
  }

  Widget _buildVerifyCodeForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.pin_rounded, color: _primary, size: 64),
        const SizedBox(height: 32),
        Text(
          'Verify Code',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Please enter the 6-digit verification code sent to your email or mobile number.',
          textAlign: TextAlign.center,
        ),
        if (_feedbackMessage != null) ...[
          const SizedBox(height: 20),
          _buildFeedbackBanner(),
        ],
        const SizedBox(height: 36),
        _buildTextField(
          _codeController,
          'Verification Code',
          Icons.pin_rounded,
          maxLength: 6,
          hint: 'Enter 6-digit code',
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _isLoading ? null : _handleVerifyCode,
            child: _isLoading
                ? const AppShimmerLoader(color: Colors.white)
                : const Text(
                    'Verify Code',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Didn't receive the code? ",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            TextButton(
              onPressed: (_isLoading || _cooldownSeconds > 0)
                  ? null
                  : _handleSendCode,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _cooldownSeconds > 0
                    ? 'Resend in ${_cooldownSeconds}s'
                    : 'Resend Code',
                style: TextStyle(
                  color: _cooldownSeconds > 0 ? Colors.grey : _primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            setState(() {
              _codeSent = false;
              _feedbackMessage = null;
            });
          },
          child: const Text(
            'Change Email or Mobile Number',
            style: TextStyle(color: _mutedDark, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildCreatePasswordForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.verified_user_rounded, color: _primary, size: 64),
        const SizedBox(height: 32),
        Text(
          'Create New Password',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Your identity is verified. Please set your new secure password.',
          textAlign: TextAlign.center,
        ),
        if (_feedbackMessage != null) ...[
          const SizedBox(height: 20),
          _buildFeedbackBanner(),
        ],
        const SizedBox(height: 36),
        _buildTextField(
          _passwordController,
          'New Password',
          Icons.lock_outline,
          obscure: _obscurePassword,
          onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        const SizedBox(height: 18),
        _buildTextField(
          _confirmPasswordController,
          'Confirm New Password',
          Icons.lock_outline,
          obscure: _obscureConfirmPassword,
          onToggle: () => setState(
            () => _obscureConfirmPassword = !_obscureConfirmPassword,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _isLoading ? null : _handleResetPassword,
            child: _isLoading
                ? const AppShimmerLoader(color: Colors.white)
                : const Text(
                    'Reset Password',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecoveryLinkSentView() {
    final identifier = _emailController.text.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_rounded,
            color: _primary,
            size: 44,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Check Your Email',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.inter(
              fontSize: 14.5,
              color: _mutedDark,
              height: 1.5,
            ),
            children: [
              const TextSpan(
                text: 'We sent a secure password reset link to:\n',
              ),
              TextSpan(
                text: identifier,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: _primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Click the reset link in your email to choose a new password. If you don\'t see the email, please check your spam folder.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF166534),
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => context.go(AppRoutes.login),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Back to Login',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_rounded, color: _primary, size: 80),
        const SizedBox(height: 32),
        Text(
          'Success!',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Your password has been reset. Redirecting...',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscure = false,
    VoidCallback? onToggle,
    int? maxLength,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          maxLength: maxLength,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20),
            hintText: hint,
            suffixIcon: onToggle != null
                ? IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: onToggle,
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            counterText: '',
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackBanner() {
    final color = _feedbackIsError ? _danger : _primary;
    final bgColor = _feedbackIsError
        ? _danger.withValues(alpha: 0.08)
        : _primary.withValues(alpha: 0.08);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _feedbackIsError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _feedbackMessage!,
              style: TextStyle(
                color: _feedbackIsError ? const Color(0xFF991B1B) : _mutedDark,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
