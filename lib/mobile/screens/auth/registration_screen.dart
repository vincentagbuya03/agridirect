import 'package:flutter/material.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/integration/email_service.dart';
import '../../../shared/services/auth/otp_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/widgets/distinctive_phone_input.dart';
import 'otp_verification_screen.dart';
import 'registration_completion_screen.dart';
import '../../../shared/services/auth/textbee_otp_service.dart';

/// Mobile Registration screen with premium design.
class RegistrationScreen extends StatefulWidget {
  final VoidCallback onRegistrationSuccess;

  const RegistrationScreen({super.key, required this.onRegistrationSuccess});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  int _selectedTab = 0; // 0 = Email (Buyer), 1 = Phone Number (Farmer)

  // Email registration state
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  // Phone registration state (Ideal for farmers without email)
  final _phoneNameController = TextEditingController();
  final _phonePasswordController = TextEditingController();
  final _phoneConfirmPasswordController = TextEditingController();
  String _phoneE164 = '';
  bool _isPhoneValid = false;
  bool _obscurePhonePassword = true;
  bool _obscurePhoneConfirmPassword = true;
  bool _isPhoneLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneNameController.dispose();
    _phonePasswordController.dispose();
    _phoneConfirmPasswordController.dispose();
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

  void _handlePhoneRegister() async {
    final name = _phoneNameController.text.trim();
    final password = _phonePasswordController.text.trim();
    final confirmPassword = _phoneConfirmPasswordController.text.trim();

    if (name.isEmpty) {
      _showErrorModal('Missing Name', 'Please enter your full name.');
      return;
    }

    if (!_isPhoneValid || _phoneE164.isEmpty) {
      _showErrorModal(
        'Invalid Mobile Number',
        'Please enter a valid, active Philippine mobile number (e.g., 0917 123 4567).',
      );
      return;
    }

    if (password.isEmpty) {
      _showErrorModal(
        'Missing Password',
        'Please create a password or 6-digit PIN.',
      );
      return;
    }

    if (password.length < 6) {
      _showErrorModal(
        'Password Too Short',
        'Password must be at least 6 characters or numbers.',
      );
      return;
    }

    if (password != confirmPassword) {
      _showErrorModal(
        'Password Mismatch',
        'Passwords do not match. Please re-enter.',
      );
      return;
    }

    setState(() => _isPhoneLoading = true);

    try {
      final userId = await AuthService().registerWithPhone(
        name: name,
        phoneNumber: _phoneE164,
        password: password,
        autoSignIn: false,
      );

      if (mounted) {
        if (userId == null) {
          setState(() => _isPhoneLoading = false);
          _showErrorModal(
            'Registration Failed',
            AuthService().errorMessage ??
                'Unable to create account. Please try again.',
          );
          return;
        }

        final digits = _phoneE164.replaceAll('+', '');
        final syntheticEmail = '$digits@phone.agridirect.ph';

        // Dispatch SMS verification code via TextBee
        final otpSent = await TextBeeOtpService().sendOtp(
          phoneNumber: _phoneE164,
          onSuccess: (code) {
            debugPrint('✅ TextBee SMS OTP sent for new registration: $_phoneE164');
          },
          onError: (err) {
            debugPrint('⚠️ TextBee SMS OTP dispatch error: $err');
          },
        );

        if (!otpSent) {
          if (mounted) {
            setState(() => _isPhoneLoading = false);
            _showErrorModal(
              'SMS Verification Notice',
              'Failed to dispatch SMS code to $_phoneE164. Please check your signal or network connection and try again.',
            );
          }
          return;
        }

        if (mounted) {
          setState(() => _isPhoneLoading = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPVerificationScreen(
                userId: userId,
                email: syntheticEmail,
                phoneNumber: _phoneE164,
                name: name,
                password: password,
                onVerificationSuccess: () {
                  widget.onRegistrationSuccess();
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPhoneLoading = false);
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
          context.push(AppRoutes.completeProfile);
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

  void _navigateBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go(AppRoutes.login);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: _navigateBack,
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
              const SizedBox(height: 24),

              // Tab Selector: Email vs Phone Number
              Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _selectedTab == 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.email_outlined,
                                size: 16,
                                color: _selectedTab == 0 ? AppColors.primary : AppColors.textSubtle,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Email',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.w500,
                                  color: _selectedTab == 0 ? AppColors.primary : AppColors.textSubtle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 1),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _selectedTab == 1
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.phone_android_rounded,
                                size: 16,
                                color: _selectedTab == 1 ? AppColors.primary : AppColors.textSubtle,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Phone Number',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.w500,
                                  color: _selectedTab == 1 ? AppColors.primary : AppColors.textSubtle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (_selectedTab == 0) ...[
                // Email Registration Fields
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

                const SizedBox(height: 32),

                // Register Button (Email)
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
              ] else ...[
                // Phone / Farmer Registration Fields
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_android_rounded, color: AppColors.primary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Sign up quickly using your mobile phone number. No email or Gmail account required!',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                _buildInputLabel('Full Name'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _phoneNameController,
                  hintText: 'e.g. Juan dela Cruz',
                  prefixIcon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 18),

                _buildInputLabel('Philippine Mobile Number'),
                const SizedBox(height: 8),
                DistinctivePhoneInput(
                  label: 'Mobile Number',
                  helperText: 'Enter your 11-digit number (e.g., 0917 123 4567)',
                  onChanged: (formattedE164, isValidAndUnique) {
                    setState(() {
                      _phoneE164 = formattedE164;
                      _isPhoneValid = isValidAndUnique;
                    });
                  },
                ),
                const SizedBox(height: 18),

                _buildInputLabel('Password / 6-Digit PIN'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _phonePasswordController,
                  hintText: 'Create a password or 6-digit PIN',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscurePhonePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePhonePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 19,
                      color: AppColors.textSubtle,
                    ),
                    onPressed: () => setState(
                      () => _obscurePhonePassword = !_obscurePhonePassword,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                _buildInputLabel('Confirm Password / PIN'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _phoneConfirmPasswordController,
                  hintText: 'Re-enter your password or PIN',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscurePhoneConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePhoneConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 19,
                      color: AppColors.textSubtle,
                    ),
                    onPressed: () => setState(
                      () => _obscurePhoneConfirmPassword =
                          !_obscurePhoneConfirmPassword,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Register Button (Phone)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isPhoneLoading ? null : _handlePhoneRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isPhoneLoading
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
              ],

              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: AppTextStyles.bodyMedium,
                  ),
                  GestureDetector(
                    onTap: _navigateBack,
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

