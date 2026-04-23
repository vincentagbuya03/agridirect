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

  static const Color _primary = Color(0xFF16A34A);
  static const Color _danger = Color(0xFFEF4444);

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnackBar('Please enter a valid email address', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final mode = await PasswordResetService.sendResetCode(email);

      if (mode == PasswordResetDeliveryMode.code) {
        setState(() {
          _isLoading = false;
          _codeSent = true;
        });
        _showSnackBar(
          'Reset code sent! Check your email, then set your new password below.',
          isError: false,
        );
      } else {
        setState(() {
          _isLoading = false;
          _resetSuccess = true;
        });
        _showSnackBar(
          'Reset link sent! Check your email to continue.',
          isError: false,
        );

        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        context.go(AppRoutes.login);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed: $e', isError: true);
    }
  }

  Future<void> _handleVerifyCode() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();

    if (email.isEmpty || code.isEmpty) {
      _showSnackBar('Please fill in all fields', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await PasswordResetService.verifyResetCode(email: email, code: code);
      setState(() {
        _isLoading = false;
        _codeVerified = true;
      });
      _showSnackBar('Code verified! Set your new password.', isError: false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Invalid code: $e', isError: true);
    }
  }

  Future<void> _handleResetPassword() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showSnackBar('Please enter a valid email address', isError: true);
      return;
    }

    if (password.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar('Please fill in all fields', isError: true);
      return;
    }

    if (password.length < 6) {
      _showSnackBar('Password must be at least 6 characters', isError: true);
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar('Passwords do not match', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await PasswordResetService.resetPasswordWithCode(
        email: email,
        code: _codeController.text.trim(),
        newPassword: password,
      );

      setState(() {
        _isLoading = false;
        _resetSuccess = true;
      });

      _showSnackBar('Password reset successfully!', isError: false);
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      context.go(AppRoutes.login);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to reset password: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _danger : _primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
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
                    child: _resetSuccess
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
          'Enter your email to receive a reset code. If a valid code already exists, it will be reused.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 36),
        _buildTextField(
          _emailController,
          'Email Address',
          Icons.email_outlined,
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
            onPressed: _isLoading ? null : _handleSendCode,
            child: _isLoading
                ? const AppShimmerLoader(color: Colors.white)
                : const Text(
                    'Send Reset Code',
                    style: TextStyle(
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
          'Please enter the 6-digit verification code sent to your email.',
          textAlign: TextAlign.center,
        ),
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
}

