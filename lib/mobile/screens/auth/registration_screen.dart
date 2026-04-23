import 'package:flutter/material.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/integration/email_service.dart';
import '../../../shared/services/auth/otp_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/router/app_router.dart';
import 'otp_verification_screen.dart';
import 'registration_completion_screen.dart';

/// Mobile Registration screen with premium design.
class RegistrationScreen extends StatefulWidget {
  final VoidCallback onRegistrationSuccess;

  const RegistrationScreen({super.key, required this.onRegistrationSuccess});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty || email.isEmpty) {
      _showErrorModal('Missing Fields', 'Please fill in your name and email');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final emailTaken = await SupabaseDatabase.isEmailAlreadyRegistered(email);
      if (emailTaken) {
        final resumed = await _resumeIncompleteManualProfile(
          email: email,
          fallbackName: name,
        );
        if (resumed) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }

        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorModal(
            'Account Exists',
            'This email is already registered. Please log in instead.',
          );
        }
        return;
      }

      final temporaryPassword =
          AuthService.generateOneTimeRegistrationPassword();
      await AuthService.cachePendingRegistrationPassword(
        email: email,
        password: temporaryPassword,
      );

      final String? userId = await AuthService().register(
        name: name,
        email: email,
        password: temporaryPassword,
      );

      if (userId == null) {
        final resumed = await _resumeIfAlreadyRegistered(
          email: email,
          fallbackName: name,
        );
        if (resumed) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }

        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorModal(
            'Registration Failed',
            AuthService().errorMessage ?? 'Failed to create account',
          );
        }
        return;
      }

      final otpCode = await OTPService().generateAndStoreOTP(
        userId: userId,
        type: 'signup',
      );

      if (otpCode == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorModal(
            'System Error',
            'Unable to prepare verification. Please try again.',
          );
        }
        return;
      }

      final emailSent = await EmailService.sendOTPEmail(
        email: email,
        otpCode: otpCode,
      );

      if (!emailSent) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorModal(
            'Email Failure',
            'Failed to send verification code. Check your connection.',
          );
        }
        return;
      }

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPVerificationScreen(
              userId: userId,
              email: email,
              name: name,
              password: temporaryPassword,
              onVerificationSuccess: () {
                widget.onRegistrationSuccess();
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorModal('Error', 'An unexpected error occurred: $e');
      }
    }
  }

  Future<bool> _resumeIfAlreadyRegistered({
    required String email,
    required String fallbackName,
  }) async {
    final errorMessage = (AuthService().errorMessage ?? '').toLowerCase();
    final alreadyRegistered =
        errorMessage.contains('already registered') ||
        errorMessage.contains('user already registered');

    if (!alreadyRegistered) return false;

    return _resumeIncompleteManualProfile(
      email: email,
      fallbackName: fallbackName,
    );
  }

  Future<bool> _resumeIncompleteManualProfile({
    required String email,
    required String fallbackName,
  }) async {
    try {
      final temporaryPassword =
          await AuthService.getPendingRegistrationPassword(email);
      if (temporaryPassword == null || temporaryPassword.isEmpty) {
        return false;
      }

      final signInResult = await SupabaseConfig.client.auth.signInWithPassword(
        email: email,
        password: temporaryPassword,
      );

      final user = signInResult.user;
      if (user == null) return false;

      final profile = await SupabaseDatabase.getUserProfile(user.id);
      final phone = (profile?['phone'] as String?)?.trim() ?? '';

      // If phone already exists, this is likely a fully completed account.
      if (phone.isNotEmpty) {
        await SupabaseConfig.client.auth.signOut();
        return false;
      }

      if (!mounted) return true;

      final profileName = (profile?['name'] as String?)?.trim();
      final resolvedName = (profileName != null && profileName.isNotEmpty)
          ? profileName
          : fallbackName;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RegistrationCompletionScreen(
            userId: user.id,
            email: email,
            name: resolvedName,
            onFinalizeSuccess: widget.onRegistrationSuccess,
          ),
        ),
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  void _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    final success = await AuthService().signInWithGoogle();

    if (mounted) {
      setState(() => _isGoogleLoading = false);
      if (success) {
        if (AuthService().needsProfileCompletion) {
          context.push(AppRoutes.googleCompleteProfile);
        } else {
          widget.onRegistrationSuccess();
        }
      } else {
        _showErrorModal(
          'Google Sign-In Failed',
          AuthService().errorMessage ?? 'Failed to sign in',
        );
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
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(height: 32),
              Text('Create Account', style: AppTextStyles.headline1),
              const SizedBox(height: 8),
              Text(
                'Join our community and start trading directly with local farmers.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSubtle,
                ),
              ),
              const SizedBox(height: 40),

              // Fields Section
              _buildInputLabel('Full Name'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _nameController,
                hintText: 'Enter your full name',
                prefixIcon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 20),

              _buildInputLabel('Email Address'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _emailController,
                hintText: 'name@example.com',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 40),

              // Register Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: AppShimmerLoader(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Create Account',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[200])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('OR', style: AppTextStyles.labelSmall),
                  ),
                  Expanded(child: Divider(color: Colors.grey[200])),
                ],
              ),
              const SizedBox(height: 24),

              // Google Button Only
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[200]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    backgroundColor: Colors.white,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isGoogleLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: AppShimmerLoader(strokeWidth: 2),
                        )
                      else ...[
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'G',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF4285F4),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'Continue with Google',
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textHeadline,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: AppTextStyles.bodyMedium,
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      'Sign In',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
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

