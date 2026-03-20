import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/router/app_router.dart';

/// Web screen shown to new Google sign-in users to complete their profile.
/// Collects phone number and optional password.
class WebGoogleCompleteProfileScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const WebGoogleCompleteProfileScreen({super.key, required this.onComplete});

  @override
  State<WebGoogleCompleteProfileScreen> createState() =>
      _WebGoogleCompleteProfileScreenState();
}

class _WebGoogleCompleteProfileScreenState
    extends State<WebGoogleCompleteProfileScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _phoneError;

  static const Color _primary   = Color(0xFF16A34A);
  static const Color _dark      = Color(0xFF111827);
  static const Color _muted     = Color(0xFF9CA3AF);
  static const Color _inputBg   = Color(0xFFF9FAFB);
  static const Color _border    = Color(0xFFE5E7EB);

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleBack() async {
    await AuthService().cancelGoogleProfileCompletion();
    if (mounted) {
      context.go(AppRoutes.login);
    }
  }

  void _handleComplete() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    setState(() => _phoneError = null);

    if (phone.isEmpty) {
      setState(() => _phoneError = 'Please enter your phone number');
      return;
    }
    if (password.isNotEmpty && password != confirmPassword) {
      _showSnackBar('Passwords do not match');
      return;
    }
    if (password.isNotEmpty && password.length < 6) {
      _showSnackBar('Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);

    final success = await AuthService().completeGoogleProfile(
      phoneNumber: phone,
      password: password.isNotEmpty ? password : null,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        widget.onComplete();
      } else {
        final errorMsg = AuthService().errorMessage ?? 'Failed to save profile. Try again.';
        if (errorMsg.contains('number is already used')) {
          setState(() => _phoneError = errorMsg);
        } else {
          _showSnackBar(errorMsg);
        }
      }
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: Stack(
        children: [
          // Back button
          Positioned(
            top: 24,
            left: 24,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: _dark),
              onPressed: _handleBack,
              tooltip: 'Back to login',
            ),
          ),
          Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 460,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icon
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      color: _primary,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  'Complete Your Profile',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'Welcome, ${auth.pendingGoogleName}!\nJust a few more details to get started.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF6B7280),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Email badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          color: _primary,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          auth.pendingGoogleEmail,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Phone number
                _buildLabel('Phone Number *'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: _phoneController,
                  hint: 'Enter your phone number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  hasError: _phoneError != null,
                ),
                if (_phoneError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _phoneError!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.red[600],
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Password (optional)
                _buildLabel('Password (Optional)'),
                const SizedBox(height: 4),
                Text(
                  'Set a password to also sign in with email & password',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: _passwordController,
                  hint: 'Create a password',
                  icon: Icons.lock_outline,
                  obscure: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: _muted,
                      size: 18,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _confirmPasswordController,
                  hint: 'Confirm password',
                  icon: Icons.lock_outline,
                  obscure: _obscureConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: _muted,
                      size: 18,
                    ),
                    onPressed: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Submit button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleComplete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Create Account',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _dark,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool hasError = false,
  }) {
    final borderColor = hasError ? Colors.red[400]! : _border;
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 14, color: _dark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: _muted, fontSize: 14),
        prefixIcon: Icon(icon, color: hasError ? Colors.red[400] : _muted, size: 18),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: _inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: hasError ? Colors.red[400]! : _primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
    );
  }
}
