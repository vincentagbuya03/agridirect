import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/email_service.dart';
import '../../../shared/services/otp_service.dart';
import '../../../shared/services/supabase_config.dart';
import 'web_otp_verification_screen.dart' show WebOTPVerificationScreen;

/// Web Registration screen — modern split layout.
class WebRegistrationScreen extends StatefulWidget {
  final VoidCallback onRegistrationSuccess;

  const WebRegistrationScreen({super.key, required this.onRegistrationSuccess});

  @override
  State<WebRegistrationScreen> createState() => _WebRegistrationScreenState();
}

class _WebRegistrationScreenState extends State<WebRegistrationScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  static const Color _primary = Color(0xFF16A34A);
  static const Color _accent = Color(0xFF22C55E);
  static const Color _dark = Color(0xFF111827);
  static const Color _muted = Color(0xFF9CA3AF);
  static const Color _mutedDark = Color(0xFF6B7280);
  static const Color _inputBg = Color(0xFFF9FAFB);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar('Please fill in all fields');
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar('Passwords do not match');
      return;
    }

    if (password.length < 6) {
      _showSnackBar('Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final emailTaken = await SupabaseDB.isEmailAlreadyRegistered(email);
      if (emailTaken) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar('This email is already registered. Please log in instead.');
        }
        return;
      }

      if (phone.isNotEmpty) {
        final phoneTaken = await SupabaseDB.isPhoneAlreadyRegistered(phone);
        if (phoneTaken) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showSnackBar('This phone number is already associated with an account.');
          }
          return;
        }
      }

      final timeRemaining = await OTPService().getOTPTimeRemaining(email: email);
      final hasExistingOTP = timeRemaining != null && timeRemaining > 0;

      if (!hasExistingOTP) {
        final otpCode = OTPService.generateOTP();

        final otpStored = await OTPService().storeOTP(
          email: email,
          code: otpCode,
        );

        if (!otpStored) {
          if (mounted) {
            setState(() => _isLoading = false);
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
            setState(() => _isLoading = false);
            _showSnackBar('Failed to send verification code. Please try again.');
          }
          return;
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
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
                _showSnackBar('Account created successfully! Redirecting to login...');
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) {
                    Navigator.pop(context);
                    widget.onRegistrationSuccess();
                  }
                });
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

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
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
                child: Stack(
                  children: [
                    Positioned(
                      top: -80,
                      right: -60,
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [_accent.withOpacity(0.12), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -60,
                      left: -60,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [const Color(0xFF34D399).withOpacity(0.1), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
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
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                                  ),
                                  child: const Icon(Icons.eco_rounded, color: Colors.white, size: 26),
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
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.07),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: SizedBox(
                                width: 280,
                                height: 240,
                                child: Center(
                                  child: Icon(
                                    Icons.person_add_rounded,
                                    size: 100,
                                    color: Colors.white.withOpacity(0.4),
                                  ),
                                ),
                              ),
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
                            const SizedBox(height: 14),
                            Text(
                              'Connect with verified local farmers\nand access fresh produce directly.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: Colors.white.withOpacity(0.65),
                                height: 1.7,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_primary.withOpacity(0.1), _accent.withOpacity(0.08)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.person_add_rounded, color: _primary, size: 26),
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
                          'Sign up to join our farming community',
                          style: GoogleFonts.inter(fontSize: 15, color: _muted, height: 1.5),
                        ),
                        const SizedBox(height: 32),

                        _buildField('Full Name', 'Juan Dela Cruz', Icons.person_outline_rounded, _nameController),
                        const SizedBox(height: 18),
                        _buildField('Email Address', 'you@example.com', Icons.email_outlined, _emailController),
                        const SizedBox(height: 18),
                        _buildField('Phone (optional)', '09XX XXX XXXX', Icons.phone_outlined, _phoneController),
                        const SizedBox(height: 18),
                        _buildField('Password', 'Min. 6 characters', Icons.lock_outline_rounded, _passwordController,
                            obscure: _obscurePassword,
                            onToggle: () => setState(() => _obscurePassword = !_obscurePassword)),
                        const SizedBox(height: 18),
                        _buildField('Confirm Password', 'Re-enter password', Icons.lock_outline_rounded,
                            _confirmPasswordController,
                            obscure: _obscureConfirmPassword,
                            onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)),
                        const SizedBox(height: 28),

                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleRegister,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: _primary.withOpacity(0.6),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text('Create Account',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Already have an account? ',
                                style: GoogleFonts.inter(fontSize: 14, color: _muted)),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: _isLoading ? null : () => Navigator.pop(context),
                                child: Text('Login',
                                    style: GoogleFonts.inter(
                                        fontSize: 14, fontWeight: FontWeight.w700, color: _primary)),
                              ),
                            ),
                          ],
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

  Widget _buildField(String label, String hint, IconData icon, TextEditingController controller,
      {bool obscure = false, VoidCallback? onToggle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1F2937))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          enabled: !_isLoading,
          style: GoogleFonts.inter(fontSize: 14, color: _dark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: _muted, fontSize: 14),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(icon, color: _mutedDark, size: 20),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 44),
            suffixIcon: onToggle != null
                ? IconButton(
                    icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: _muted, size: 20),
                    onPressed: onToggle,
                  )
                : null,
            filled: true,
            fillColor: _inputBg,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _primary, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }
}
