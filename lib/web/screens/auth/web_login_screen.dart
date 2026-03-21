import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/services/email_service.dart';
import '../../../shared/services/otp_service.dart';
import '../../../shared/services/supabase_config.dart';
import 'web_otp_verification_screen.dart';

/// Web Login / Register screen.
/// Modern split layout with animated branding on left, form on right.
class WebLoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const WebLoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<WebLoginScreen> createState() => _WebLoginScreenState();
}

class _WebLoginScreenState extends State<WebLoginScreen>
    with TickerProviderStateMixin {
  bool _isRegister = false;
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _registerNameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPhoneController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmController = TextEditingController();
  bool _loginObscure = true;
  bool _registerObscure = true;
  bool _registerLoading = false;
  bool _loginLoading = false;

  // 2025 Modern color palette
  static const Color _primary = Color(0xFF16A34A);
  static const Color _dark = Color(0xFF111827);
  static const Color _darkSecondary = Color(0xFF1F2937);
  static const Color _muted = Color(0xFF9CA3AF);
  static const Color _mutedDark = Color(0xFF6B7280);
  static const Color _border = Color(0xFFF3F4F6);
  static const Color _inputBg = Color(0xFFF9FAFB);

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerNameController.dispose();
    _registerEmailController.dispose();
    _registerPhoneController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Please fill in all fields');
      return;
    }
    setState(() => _loginLoading = true);
    final success = await AuthService().login(email: email, password: password);
    if (mounted) setState(() => _loginLoading = false);
    if (success) {
      widget.onLoginSuccess();
    } else {
      _showLoginErrorDialog(AuthService().errorMessage ?? 'Login failed');
    }
  }

  void _handleGoogleLogin() async {
    setState(() => _loginLoading = true);
    final authService = AuthService();

    // On web, this will redirect to Google login
    // On mobile, it will show account picker
    final success = await authService.signInWithGoogle();

    // If we reach here, we need to check the result
    if (mounted) {
      setState(() => _loginLoading = false);

      // On mobile, check if there was an actual error
      // On web, we might reach here if redirect didn't happen, which is rare
      if (!success &&
          authService.errorMessage != null &&
          authService.errorMessage!.isNotEmpty) {
        _showLoginErrorDialog(authService.errorMessage!);
        return;
      }

      // Check if new user needs profile completion (mobile only)
      if (authService.needsProfileCompletion) {
        _showSnackBar('Complete your profile to finish setup');
        // TODO: Navigate to profile completion screen for web
        return;
      }

      // Existing user - proceed with login
      if (success) {
        widget.onLoginSuccess();
      }
    }
  }

  void _showLoginErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFEF4444).withOpacity(0.1),
                        const Color(0xFFFCA5A5).withOpacity(0.15),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFEF4444),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Login Failed',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  errorMessage.contains('incorrect')
                      ? 'The email or password you entered is incorrect. Please try again or reset your password.'
                      : errorMessage.contains('confirm')
                      ? 'Please confirm your email before logging in. Check your inbox for the verification link.'
                      : errorMessage,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _mutedDark,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _loginPasswordController.clear();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Try Again',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showForgotPasswordDialog();
                    },
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      backgroundColor: _primary.withOpacity(0.08),
                    ),
                    child: Text(
                      'Reset Password',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleRegister() async {
    final name = _registerNameController.text.trim();
    final email = _registerEmailController.text.trim();
    final phone = _registerPhoneController.text.trim();
    final password = _registerPasswordController.text.trim();
    final confirm = _registerConfirmController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar('Please fill in all fields');
      return;
    }
    if (password != confirm) {
      _showSnackBar('Passwords do not match');
      return;
    }
    if (password.length < 6) {
      _showSnackBar('Password must be at least 6 characters');
      return;
    }

    setState(() => _registerLoading = true);

    try {
      final emailTaken = await SupabaseDB.isEmailAlreadyRegistered(email);
      if (emailTaken) {
        if (mounted) {
          setState(() => _registerLoading = false);
          _showSnackBar(
            'This email is already registered. Please log in instead.',
          );
        }
        return;
      }

      if (phone.isNotEmpty) {
        final phoneTaken = await SupabaseDB.isPhoneAlreadyRegistered(phone);
        if (phoneTaken) {
          if (mounted) {
            setState(() => _registerLoading = false);
            _showSnackBar(
              'This phone number is already associated with an account.',
            );
          }
          return;
        }
      }

      final timeRemaining = await OTPService().getOTPTimeRemaining(
        email: email,
      );
      final hasExistingOTP = timeRemaining != null && timeRemaining > 0;

      if (!hasExistingOTP) {
        final otpCode = OTPService.generateOTP();

        final otpStored = await OTPService().storeOTP(
          email: email,
          code: otpCode,
        );

        if (!otpStored) {
          if (mounted) {
            setState(() => _registerLoading = false);
            _showSnackBar('Failed to prepare verification. Please try again.');
          }
          return;
        }

        final emailSent = await EmailService.sendOTPEmail(
          email: email,
          otpCode: otpCode,
        );

        if (!emailSent) {
          if (mounted) {
            setState(() => _registerLoading = false);
            _showSnackBar(
              'Failed to send verification code. Please try again.',
            );
          }
          return;
        }
      }

      if (mounted) {
        setState(() => _registerLoading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WebOTPVerificationScreen(
              email: email,
              name: name,
              password: password,
              phoneNumber: phone.isNotEmpty ? phone : null,
              initialSecondsRemaining: hasExistingOTP ? timeRemaining : 600,
              onVerificationSuccess: () {
                _showSnackBar(
                  'Account created successfully! Redirecting to login...',
                );
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) {
                    Navigator.pop(context);
                    _registerNameController.clear();
                    _registerEmailController.clear();
                    _registerPhoneController.clear();
                    _registerPasswordController.clear();
                    _registerConfirmController.clear();
                    setState(() => _isRegister = false);
                  }
                });
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _registerLoading = false);
        _showSnackBar('Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 1100;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Left: Modern branding panel with local Lottie
          if (!isCompact)
            Expanded(
              flex: 5,
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
                child: Stack(
                  children: [
                    // Soft decorative orbs
                    Positioned(
                      top: -100,
                      right: -80,
                      child: Container(
                        width: 320,
                        height: 320,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _primary.withOpacity(0.15),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -60,
                      left: -60,
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF34D399).withOpacity(0.12),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Top-left subtle pattern dots
                    Positioned(
                      top: 40,
                      left: 40,
                      child: Opacity(
                        opacity: 0.08,
                        child: SizedBox(
                          width: 120,
                          height: 120,
                          child: GridView.count(
                            crossAxisCount: 5,
                            physics: const NeverScrollableScrollPhysics(),
                            children: List.generate(
                              25,
                              (_) => Container(
                                margin: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Main branding content
                    Center(
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 56,
                            vertical: 48,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Logo
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
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
                              const SizedBox(height: 48),

                              // Animated icon - instant load (no Lottie needed)
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.07),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: SizedBox(
                                  width: 300,
                                  height: 260,
                                  child: Lottie.asset(
                                    'assets/lottie/Security.json',
                                    fit: BoxFit.contain,
                                    repeat: true,
                                    errorBuilder: (context, error, stack) =>
                                        Center(
                                          child: ScaleTransition(
                                            scale:
                                                Tween<double>(
                                                  begin: 0.8,
                                                  end: 1.0,
                                                ).animate(
                                                  CurvedAnimation(
                                                    parent: _fadeController,
                                                    curve: Curves.easeOutBack,
                                                  ),
                                                ),
                                            child: Icon(
                                              _isRegister
                                                  ? Icons
                                                        .shopping_basket_rounded
                                                  : Icons.eco_rounded,
                                              size: 120,
                                              color: Colors.white.withOpacity(
                                                0.4,
                                              ),
                                            ),
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 36),

                              // Headline
                              Text(
                                _isRegister
                                    ? 'Join Our Community'
                                    : 'Farm Fresh, Direct\nTo Your Table',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.2,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _isRegister
                                    ? 'Connect with verified local farmers\nand pre-order upcoming harvests.'
                                    : 'Skip the middleman. Get fresh produce\ndirectly from local farmers.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: Colors.white.withOpacity(0.65),
                                  height: 1.7,
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Trust badges
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildTrustBadge(
                                    Icons.verified_rounded,
                                    '500+ Farmers',
                                  ),
                                  const SizedBox(width: 12),
                                  _buildTrustBadge(
                                    Icons.eco_rounded,
                                    '100% Organic',
                                  ),
                                  const SizedBox(width: 12),
                                  _buildTrustBadge(
                                    Icons.bolt_rounded,
                                    'Same Day',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Right: Form panel
          Expanded(
            flex: isCompact ? 1 : 4,
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
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.03, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: _isRegister
                            ? _buildRegisterForm()
                            : _buildLoginForm(),
                      ),
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

  Widget _buildTrustBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF6EE7B7), size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      key: const ValueKey('login'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Greeting
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primary.withOpacity(0.1), _primary.withOpacity(0.08)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.waving_hand_rounded,
            color: _primary,
            size: 26,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Welcome back',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: _dark,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to discover fresh farm products',
          style: GoogleFonts.inter(fontSize: 15, color: _muted, height: 1.5),
        ),
        const SizedBox(height: 36),

        _buildModernField(
          controller: _loginEmailController,
          label: 'Email Address',
          hint: 'you@example.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),
        _buildModernField(
          controller: _loginPasswordController,
          label: 'Password',
          hint: 'Enter your password',
          icon: Icons.lock_outline_rounded,
          obscure: _loginObscure,
          suffixIcon: IconButton(
            icon: Icon(
              _loginObscure
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: _muted,
              size: 20,
            ),
            onPressed: () => setState(() => _loginObscure = !_loginObscure),
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _showForgotPasswordDialog,
              child: Text(
                'Forgot Password?',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        _buildModernButton(
          text: 'Sign In',
          onPressed: _handleLogin,
          isLoading: _loginLoading,
        ),
        const SizedBox(height: 24),
        _buildDividerWithText('or'),
        const SizedBox(height: 24),
        _buildSocialButtons(),
        const SizedBox(height: 32),
        _buildSwitchPrompt(
          'Don\'t have an account?',
          'Create one',
          () => setState(() => _isRegister = true),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      key: const ValueKey('register'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primary.withOpacity(0.1), _primary.withOpacity(0.08)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.person_add_rounded,
            color: _primary,
            size: 26,
          ),
        ),
        const SizedBox(height: 24),
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
          'Join the AgriDirect farming community',
          style: GoogleFonts.inter(fontSize: 15, color: _muted, height: 1.5),
        ),
        const SizedBox(height: 32),

        _buildModernField(
          controller: _registerNameController,
          label: 'Full Name',
          hint: 'Juan Dela Cruz',
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 18),
        _buildModernField(
          controller: _registerEmailController,
          label: 'Email Address',
          hint: 'you@example.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 18),
        _buildModernField(
          controller: _registerPhoneController,
          label: 'Phone Number (optional)',
          hint: '09XX XXX XXXX',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 18),
        _buildModernField(
          controller: _registerPasswordController,
          label: 'Password',
          hint: 'Min. 6 characters',
          icon: Icons.lock_outline_rounded,
          obscure: _registerObscure,
          suffixIcon: IconButton(
            icon: Icon(
              _registerObscure
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: _muted,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _registerObscure = !_registerObscure),
          ),
        ),
        const SizedBox(height: 18),
        _buildModernField(
          controller: _registerConfirmController,
          label: 'Confirm Password',
          hint: 'Re-enter your password',
          icon: Icons.lock_outline_rounded,
          obscure: _registerObscure,
        ),
        const SizedBox(height: 28),
        _buildModernButton(
          text: _registerLoading ? 'Sending verification...' : 'Create Account',
          onPressed: _registerLoading ? null : _handleRegister,
          isLoading: _registerLoading,
        ),
        const SizedBox(height: 28),
        _buildSwitchPrompt(
          'Already have an account?',
          'Sign in',
          () => setState(() => _isRegister = false),
        ),
      ],
    );
  }

  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _darkSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(fontSize: 14, color: _dark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: _muted, fontSize: 14),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(icon, color: _mutedDark, size: 20),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 44),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: _inputBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: const Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildModernButton({
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _primary.withOpacity(0.6),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                text,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _buildSwitchPrompt(
    String question,
    String action,
    VoidCallback onTap,
  ) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$question ',
            style: GoogleFonts.inter(fontSize: 14, color: _muted),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onTap,
              child: Text(
                action,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDividerWithText(String text) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: const Color(0xFFE5E7EB))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: _muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: const Color(0xFFE5E7EB))),
      ],
    );
  }

  Widget _buildSocialButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildSocialButton(
            Icons.g_mobiledata_rounded,
            'Google',
            onPressed: _loginLoading ? null : _handleGoogleLogin,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSocialButton(
            Icons.facebook_rounded,
            'Facebook',
            onPressed: null, // Not implemented yet
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton(
    IconData icon,
    String label, {
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: 20,
          color: onPressed != null ? _darkSecondary : _muted,
        ),
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: onPressed != null ? _darkSecondary : _muted,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: onPressed != null
                ? const Color(0xFFE5E7EB)
                : const Color(0xFFE5E7EB).withOpacity(0.5),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
              backgroundColor: Colors.white,
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: _primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Reset Password',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your email address and we\'ll send you a link to reset your password.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: _mutedDark,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildModernField(
                      controller: resetEmailController,
                      label: 'Email Address',
                      hint: 'you@example.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: isLoading
                                  ? null
                                  : () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFFE5E7EB),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _darkSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: isLoading
                                  ? null
                                  : () async {
                                      final email = resetEmailController.text
                                          .trim();
                                      if (email.isEmpty) {
                                        _showSnackBar(
                                          'Please enter your email address',
                                        );
                                        return;
                                      }

                                      if (!email.contains('@')) {
                                        _showSnackBar(
                                          'Please enter a valid email address',
                                        );
                                        return;
                                      }

                                      setState(() => isLoading = true);

                                      try {
                                        await AuthService().resetPassword(
                                          email: email,
                                        );
                                        Navigator.pop(dialogContext);
                                        _showSnackBar(
                                          'Password reset link sent! Please check your email.',
                                        );
                                      } catch (e) {
                                        setState(() => isLoading = false);
                                        _showSnackBar(
                                          'Failed to send reset link: ${e.toString()}',
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                disabledBackgroundColor: _muted,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Text(
                                      'Send Link',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        backgroundColor: _dark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
