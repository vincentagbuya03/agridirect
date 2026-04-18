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
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _codeSent = false;
  bool _resetSuccess = false;

  static const Color _primary = Color(0xFF16A34A);
  static const Color _danger = Color(0xFFEF4444);

  @override
  void dispose() {
    _emailController.dispose();
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
      await PasswordResetService.resetPasswordWithLatestCode(
        email: email,
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
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: isMobile ? double.infinity : 480,
            padding: EdgeInsets.all(isMobile ? 24 : 48),
            child: _resetSuccess
                ? _buildSuccessView()
                : _codeSent
                ? _buildCreatePasswordForm()
                : _buildSendCodeForm(),
          ),
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
          'The latest valid reset code is used automatically when you set your new password.',
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

