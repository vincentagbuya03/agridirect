import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/email_service.dart';
import '../../../shared/services/otp_service.dart';
import '../../../shared/services/supabase_config.dart';
import 'web_otp_verification_screen.dart';

/// Web Registration screen.
/// Full-width split layout with illustration on left, registration form on right.
class WebRegistrationScreen extends StatefulWidget {
  final VoidCallback onRegistrationSuccess;

  const WebRegistrationScreen(
      {super.key, required this.onRegistrationSuccess});

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

  static const Color primary = Color(0xFF13EC5B);
  static const Color sidebarBg = Color(0xFF0F172A);

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
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 1200;

    return Scaffold(
      body: SingleChildScrollView(
        child: Row(
          children: [
            // Left side - Illustration (Hidden on small screens)
            if (!isSmallScreen)
              Expanded(
                child: Container(
                  height: screenHeight,
                  color: sidebarBg,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.agriculture_outlined,
                          size: 120,
                          color: primary.withValues(alpha: 0.8),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Join ArgiDirect',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 48,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: 300,
                          child: Text(
                            'Connect directly with farmers and access fresh, local produce',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              color: Colors.grey[300],
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Right side - Registration Form
            Expanded(
              child: Container(
                color: Colors.grey[50],
                child: Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal:
                            isSmallScreen ? 24 : 48, // More padding on larger screens
                        vertical: 40,
                      ),
                      child: SizedBox(
                        width: 400,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Logo
                            Center(
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.agriculture_outlined,
                                  color: primary,
                                  size: 28,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Title
                            Text(
                              'Create Account',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sign up to join our farming community',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Name Field
                            _buildTextField(
                              controller: _nameController,
                              label: 'Full Name',
                              icon: Icons.person_outline_rounded,
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 16),

                            // Email Field
                            _buildTextField(
                              controller: _emailController,
                              label: 'Email Address',
                              icon: Icons.email_outlined,
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 16),

                            // Phone Field
                            _buildTextField(
                              controller: _phoneController,
                              label: 'Phone Number (optional)',
                              icon: Icons.phone_outlined,
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 16),

                            _buildTextField(
                              controller: _passwordController,
                              label: 'Password',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscurePassword,
                              onObscureToggle: () {
                                setState(
                                    () => _obscurePassword = !_obscurePassword);
                              },
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 16),

                            // Confirm Password Field
                            _buildTextField(
                              controller: _confirmPasswordController,
                              label: 'Confirm Password',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscureConfirmPassword,
                              onObscureToggle: () {
                                setState(() =>
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword);
                              },
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 24),

                            // Register Button
                            _buildPrimaryButton(
                              'Create Account',
                              _handleRegister,
                              isLoading: _isLoading,
                            ),
                            const SizedBox(height: 16),

                            // Already have an account
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Already have an account? ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _isLoading
                                      ? null
                                      : () {
                                          Navigator.pop(context);
                                        },
                                  child: Text(
                                    'Login',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: primary,
                                    ),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    VoidCallback? onObscureToggle,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
        suffixIcon: obscure != false
            ? GestureDetector(
                onTap: onObscureToggle,
                child: Icon(
                  obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.grey[400],
                  size: 20,
                ),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildPrimaryButton(
    String text,
    VoidCallback onPressed, {
    bool isLoading = false,
  }) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
    );
  }
}
