import 'package:flutter/material.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/auth/textbee_otp_service.dart';
import '../../../shared/services/integration/email_service.dart';
import '../../../shared/services/auth/otp_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/widgets/distinctive_phone_input.dart';
import 'web_otp_verification_screen.dart' show WebOTPVerificationScreen;
import 'web_complete_profile_screen.dart';

/// Web Registration screen — modern 3NF Implementation with Email & Phone tabs.
class WebRegistrationScreen extends StatefulWidget {
  final VoidCallback onRegistrationSuccess;

  const WebRegistrationScreen({super.key, required this.onRegistrationSuccess});

  @override
  State<WebRegistrationScreen> createState() => _WebRegistrationScreenState();
}

class _WebRegistrationScreenState extends State<WebRegistrationScreen> {
  int _selectedTab = 0; // 0 = Email Address, 1 = Phone Number

  // Email registration state
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  // Phone registration state
  final _phoneNameController = TextEditingController();
  final _phonePasswordController = TextEditingController();
  final _phoneConfirmPasswordController = TextEditingController();
  String _phoneE164 = '';
  bool _isPhoneValid = false;
  bool _obscurePhonePassword = true;
  bool _obscurePhoneConfirmPassword = true;
  bool _isPhoneLoading = false;

  static const Color _primary = Color(0xFF16A34A);
  static const Color _dark = Color(0xFF111827);
  static const Color _muted = Color(0xFF9CA3AF);
  static const Color _inputBg = Color(0xFFF9FAFB);

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
      _showSnackBar('Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Step 0: Check if email is already registered
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
          _showAccountExistsDialog(email: email);
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
          final errorMsg = AuthService().errorMessage ?? '';
          if (errorMsg.toLowerCase().contains('already registered') ||
              errorMsg.toLowerCase().contains('already exists')) {
            _showAccountExistsDialog(email: email);
          } else {
            _showSnackBar(errorMsg.isNotEmpty ? errorMsg : 'Registration failed');
          }
        }
        return;
      }

      // Step 2: Generate secure OTP code in the database
      final otpCode = await OTPService().generateAndStoreOTP(
        userId: userId,
        type: 'signup',
      );

      if (otpCode == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar('Preparation failed. Please try again.');
        }
        return;
      }

      // Step 3: Send the premium verification email
      final emailSent = await EmailService.sendOTPEmail(
        email: email,
        otpCode: otpCode,
      );

      if (!emailSent) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar(
            'Failed to send verification code. Check your connection.',
          );
        }
        return;
      }

      // Success! Navigate to verification
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WebOTPVerificationScreen(
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
        _showSnackBar('Error: $e');
      }
    }
  }

  void _handlePhoneRegister() async {
    final name = _phoneNameController.text.trim();
    final password = _phonePasswordController.text.trim();
    final confirmPassword = _phoneConfirmPasswordController.text.trim();

    if (name.isEmpty) {
      _showSnackBar('Please enter your full name');
      return;
    }

    if (!_isPhoneValid || _phoneE164.isEmpty) {
      _showSnackBar(
        'Please enter a valid, active Philippine mobile number (e.g. 0917 123 4567).',
      );
      return;
    }

    if (password.isEmpty) {
      _showSnackBar('Please create a password for your account');
      return;
    }

    if (password.length < 6) {
      _showSnackBar('Password must be at least 6 characters');
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar('Passwords do not match');
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

      if (!mounted) return;

      if (userId == null) {
        setState(() => _isPhoneLoading = false);
        _showSnackBar(
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
          debugPrint('✅ TextBee SMS OTP sent for web registration: $_phoneE164');
        },
        onError: (err) {
          debugPrint('⚠️ TextBee SMS OTP dispatch error: $err');
        },
      );

      if (!mounted) return;
      setState(() => _isPhoneLoading = false);

      if (!otpSent) {
        _showSnackBar(
          'Failed to send SMS code to $_phoneE164. Please check your signal and try again.',
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WebOTPVerificationScreen(
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
    } catch (e) {
      if (mounted) {
        setState(() => _isPhoneLoading = false);
        _showSnackBar('Error: $e');
      }
    }
  }

  void _showAccountExistsDialog({required String email}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: _primary),
            const SizedBox(width: 8),
            const Text('Account Exists'),
          ],
        ),
        content: Text(
          'An account with "$email" is already registered.\n\n'
          'If you already finished registration, please log in. '
          'If your registration was interrupted, you can reset your password to regain access.',
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF374151)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go(
                '${AppRoutes.resetPasswordWithCode}?email=${Uri.encodeComponent(email)}',
              );
            },
            child: const Text('Reset Password'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.go(AppRoutes.login);
            },
            child: const Text('Go to Login'),
          ),
        ],
      ),
    );
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

      // Completed profile users should continue using normal login.
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
          builder: (context) => WebCompleteProfileScreen(
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

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        backgroundColor: _dark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 1100;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Left branding panel
          if (!isCompact)
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF064E3B),
                      Color(0xFF065F46),
                      Color(0xFF047857),
                    ],
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 56,
                      vertical: 48,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              child: const Icon(
                                Icons.eco_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              'AgriDirect',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 36),
                        Text(
                          'Join Our Growing\nCommunity',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Right form panel
          Expanded(
            child: Container(
              color: Colors.white,
              child: Center(
                child: SingleChildScrollView(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 440),
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 24 : 44,
                      vertical: 48,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Create Account',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: _dark,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign up to join our farming community',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: _muted,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Tab Selector: Email vs Phone Number
                        Container(
                          height: 46,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedTab = 0),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color: _selectedTab == 0
                                          ? Colors.white
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: _selectedTab == 0
                                          ? [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.05),
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
                                          color: _selectedTab == 0
                                              ? _primary
                                              : _muted,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Email Address',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: _selectedTab == 0
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: _selectedTab == 0
                                                ? _dark
                                                : _muted,
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
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color: _selectedTab == 1
                                          ? Colors.white
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: _selectedTab == 1
                                          ? [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.05),
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
                                          color: _selectedTab == 1
                                              ? _primary
                                              : _muted,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Phone Number',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: _selectedTab == 1
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: _selectedTab == 1
                                                ? _dark
                                                : _muted,
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
                          _buildField(
                            'Full Name',
                            'Juan Dela Cruz',
                            Icons.person_outline_rounded,
                            _nameController,
                          ),
                          const SizedBox(height: 18),
                          _buildField(
                            'Email Address',
                            'you@example.com',
                            Icons.email_outlined,
                            _emailController,
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleRegister,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isLoading
                                  ? const AppShimmerLoader(color: Colors.white)
                                  : const Text(
                                      'Create Account with Email',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ] else ...[
                          _buildField(
                            'Full Name',
                            'Juan Dela Cruz',
                            Icons.person_outline_rounded,
                            _phoneNameController,
                          ),
                          const SizedBox(height: 18),
                          DistinctivePhoneInput(
                            initialPhone: _phoneE164,
                            label: 'Philippine Mobile Number',
                            onChanged: (formattedE164, isValidAndUnique) {
                              setState(() {
                                _phoneE164 = formattedE164;
                                _isPhoneValid = isValidAndUnique;
                              });
                            },
                          ),
                          const SizedBox(height: 18),
                          _buildPasswordField(
                            'Create Password',
                            'At least 6 characters',
                            _phonePasswordController,
                            _obscurePhonePassword,
                            () => setState(
                              () => _obscurePhonePassword =
                                  !_obscurePhonePassword,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _buildPasswordField(
                            'Confirm Password',
                            'Re-enter your password',
                            _phoneConfirmPasswordController,
                            _obscurePhoneConfirmPassword,
                            () => setState(
                              () => _obscurePhoneConfirmPassword =
                                  !_obscurePhoneConfirmPassword,
                            ),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed:
                                  _isPhoneLoading ? null : _handlePhoneRegister,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isPhoneLoading
                                  ? const AppShimmerLoader(color: Colors.white)
                                  : const Text(
                                      'Create Account with Phone',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Already have an account? '),
                            GestureDetector(
                              onTap: _isLoading
                                  ? null
                                  : () => context.go(AppRoutes.login),
                              child: const Text(
                                'Login',
                                style: TextStyle(
                                  color: _primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),
                        // Farmer Redirect Section
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _primary.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.agriculture_rounded,
                                      color: _primary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Sell on AgriDirect',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: _dark,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Farmer registration and listing management are exclusive to our mobile app.',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF166534),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    context.go(AppRoutes.home);
                                  },
                                  icon: const Icon(
                                    Icons.file_download_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Download Mobile App'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _primary,
                                    side: const BorderSide(color: _primary),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    String label,
    String hint,
    IconData icon,
    TextEditingController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: _inputBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField(
    String label,
    String hint,
    TextEditingController controller,
    bool obscureText,
    VoidCallback onToggleObscure,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
              onPressed: onToggleObscure,
            ),
            filled: true,
            fillColor: _inputBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }
}
