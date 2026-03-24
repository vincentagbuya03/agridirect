import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/auth_service.dart';

/// Screen shown to new Google sign-in users to complete their profile.
/// Collects phone number and optional password before creating their account.
class GoogleCompleteProfileScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const GoogleCompleteProfileScreen({super.key, required this.onComplete});

  @override
  State<GoogleCompleteProfileScreen> createState() =>
      _GoogleCompleteProfileScreenState();
}

class _GoogleCompleteProfileScreenState
    extends State<GoogleCompleteProfileScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  static const Color primary = Color(0xFF13EC5B);

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleComplete() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (phone.isEmpty) {
      _showSnackBar('Please enter your phone number');
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
        _showSnackBar(
          AuthService().errorMessage ?? 'Failed to save profile. Try again.',
        );
      }
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                // Icon
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0F7F3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      color: primary,
                      size: 42,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Center(
                  child: Text(
                    'Complete Your Profile',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle with Google account info
                Center(
                  child: Text(
                    'Welcome, ${auth.pendingGoogleName}!\nJust a few more details to get started.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // Email badge (already verified)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F7F3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          color: primary,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          auth.pendingGoogleEmail,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F4C2A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Phone number field
                _buildLabel('Phone Number *'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _phoneController,
                  hint: 'Enter your phone number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 20),

                // Password field (optional)
                _buildLabel('Password (Optional)'),
                const SizedBox(height: 4),
                Text(
                  'Set a password to also log in with email & password',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 8),
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
                      color: Colors.grey[400],
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 16),

                // Confirm password
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
                      color: Colors.grey[400],
                      size: 20,
                    ),
                    onPressed: () => setState(
                      () =>
                          _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Submit button
                _buildPrimaryButton(
                  'Create Account',
                  _handleComplete,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1F2937),
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
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
          prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(
    String text,
    VoidCallback onPressed, {
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: primary,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  text,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
