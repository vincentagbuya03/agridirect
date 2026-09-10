import 'package:flutter/material.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/widgets/distinctive_phone_input.dart';

/// Final step of manual registration after OTP verification.
/// Collects required profile details before entering the app.
class RegistrationCompletionScreen extends StatefulWidget {
  final String userId;
  final String email;
  final String name;
  final VoidCallback onFinalizeSuccess;

  const RegistrationCompletionScreen({
    super.key,
    required this.userId,
    required this.email,
    required this.name,
    required this.onFinalizeSuccess,
  });

  @override
  State<RegistrationCompletionScreen> createState() =>
      _RegistrationCompletionScreenState();
}

class _RegistrationCompletionScreenState
    extends State<RegistrationCompletionScreen> {
  String _phoneE164 = '';
  bool _isPhoneValid = false;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleFinalize() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (!_isPhoneValid || _phoneE164.isEmpty) {
      _showErrorModal('Invalid Phone Number', 'Please enter a valid, unique Philippine mobile number');
      return;
    }

    if (password.isEmpty) {
      _showErrorModal('Missing Password', 'Please create a password for your account');
      return;
    }

    if (password != confirmPassword) {
      _showErrorModal('Password Mismatch', 'Passwords do not match');
      return;
    }

    final passwordError = AuthService.validatePassword(password);
    if (passwordError != null) {
      _showErrorModal('Weak Password', passwordError);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Update the user password and phone in database
      // Pass the email to ensure it's not wiped in the upsert
      final success = await AuthService().updateUserPasswordAndPhone(
        phoneNumber: _phoneE164,
        password: password,
        email: widget.email,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          widget.onFinalizeSuccess();
        } else {
          _showErrorModal(
            'Update Failed',
            AuthService().errorMessage ?? 'Unable to finalize registration',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorModal('Error', 'An unexpected error occurred: $e');
      }
    }
  }

  void _showErrorModal(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: AppTextStyles.headline2),
        content: Text(message, style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Complete Your Profile', style: AppTextStyles.headline1),
              const SizedBox(height: 8),
              Text(
                'Set up your secure password and phone number to start using AgriDirect.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSubtle),
              ),
              const SizedBox(height: 40),

              DistinctivePhoneInput(
                onChanged: (formattedE164, isValidAndUnique) {
                  setState(() {
                    _phoneE164 = formattedE164;
                    _isPhoneValid = isValidAndUnique;
                  });
                },
              ),
              const SizedBox(height: 24),

              _buildInputLabel('Create Password'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _passwordController,
                hintText: 'Enter strong password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20,
                    color: AppColors.textSubtle,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 24),

              _buildInputLabel('Confirm Password'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _confirmPasswordController,
                hintText: 'Re-enter password',
                prefixIcon: Icons.lock_reset_rounded,
                obscureText: _obscureConfirmPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20,
                    color: AppColors.textSubtle,
                  ),
                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
              ),
              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleFinalize,
                  style: AppDecorations.primaryButton.copyWith(
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  child: _isLoading
                      ? const AppShimmerLoader(size: 24)
                      : Text(
                          'Finish Registration',
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.labelSmall.copyWith(
        color: AppColors.textHeadline,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(prefixIcon, size: 20, color: AppColors.textSubtle),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
