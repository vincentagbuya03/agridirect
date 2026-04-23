import 'package:flutter/material.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/integration/email_service.dart';
import '../../../shared/services/auth/otp_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import 'web_otp_verification_screen.dart' show WebOTPVerificationScreen;
import 'web_complete_profile_screen.dart';

/// Web Registration screen — modern 3NF Implementation.
class WebRegistrationScreen extends StatefulWidget {
  final VoidCallback onRegistrationSuccess;

  const WebRegistrationScreen({super.key, required this.onRegistrationSuccess});

  @override
  State<WebRegistrationScreen> createState() => _WebRegistrationScreenState();
}

class _WebRegistrationScreenState extends State<WebRegistrationScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  static const Color _primary = Color(0xFF16A34A);
  static const Color _dark = Color(0xFF111827);
  static const Color _muted = Color(0xFF9CA3AF);
  static const Color _inputBg = Color(0xFFF9FAFB);

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
          _showSnackBar(
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

      // Step 1: Create user via AuthService
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
          _showSnackBar(AuthService().errorMessage ?? 'Registration failed');
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
                        const SizedBox(height: 32),
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
                                ? const AppShimmerLoader(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    'Create Account',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Already have an account? '),
                            GestureDetector(
                              onTap: _isLoading
                                  ? null
                                  : () => Navigator.pop(context),
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
                                    // Redirect logic - could be a URL or showing a download modal
                                    // For now, we'll assume there's a download section on the home page
                                    Navigator.pop(context);
                                  },
                                  icon: const Icon(Icons.file_download_rounded, size: 18),
                                  label: const Text('Download Mobile App'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _primary,
                                    side: const BorderSide(color: _primary),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
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
}

