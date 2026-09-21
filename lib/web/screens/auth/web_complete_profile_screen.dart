import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/localization/farmer_locale_service.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/auth/textbee_otp_service.dart';
import '../../../shared/styles/farmer_theme.dart';
import '../../../shared/widgets/distinctive_phone_input.dart';
import '../../../shared/widgets/farmer/farmer_button.dart';
import '../../../shared/widgets/farmer/farmer_language_toggle.dart';
import '../../../shared/widgets/phone_otp_verification_dialog.dart';
import '../../../shared/widgets/premium_confirm_dialog.dart';

/// Dedicated Web Profile Completion Screen.
/// Provides a first-class desktop & responsive web layout for the 2-step
/// profile completion flow (Phone Number -> Password Creation).
class WebCompleteProfileScreen extends StatefulWidget {
  final String? userId;
  final String? email;
  final String? name;
  final VoidCallback? onComplete;
  final VoidCallback? onFinalizeSuccess;

  const WebCompleteProfileScreen({
    super.key,
    this.userId,
    this.email,
    this.name,
    this.onComplete,
    this.onFinalizeSuccess,
  });

  @override
  State<WebCompleteProfileScreen> createState() =>
      _WebCompleteProfileScreenState();
}

class _WebCompleteProfileScreenState extends State<WebCompleteProfileScreen> {
  int _currentStep = 0; // 0 = Phone, 1 = Password
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _verifiedPhone = '';
  bool _isPhoneVerified = false;
  bool _isPhoneOtpVerified = false;
  String _otpVerifiedPhoneNumber = '';
  bool _isSendingOtp = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String get _effectiveName {
    if (widget.name != null && widget.name!.trim().isNotEmpty) {
      return widget.name!.trim();
    }
    final auth = AuthService();
    if (auth.pendingName.trim().isNotEmpty) {
      return auth.pendingName.trim();
    }
    if (auth.userName.trim().isNotEmpty) {
      return auth.userName.trim();
    }
    final metaName = auth.client.auth.currentUser?.userMetadata?['full_name'] ??
        auth.client.auth.currentUser?.userMetadata?['name'];
    if (metaName != null && metaName.toString().trim().isNotEmpty) {
      return metaName.toString().trim();
    }
    return '';
  }

  Future<void> _goToPasswordStep() async {
    final rawInput =
        (_verifiedPhone.isNotEmpty ? _verifiedPhone : _phoneController.text)
            .trim();
    final cleanDigits = rawInput.replaceAll(RegExp(r'[^\d]'), '');
    final nationalDigits = cleanDigits.startsWith('63')
        ? cleanDigits.substring(2)
        : cleanDigits;

    if (nationalDigits.isEmpty) {
      _showErrorModal(
        'Phone Number Required',
        'Please enter your 10-digit Philippine mobile number (e.g. 0917 123 4567 or 917 123 4567) to continue.',
      );
      return;
    }

    if (!nationalDigits.startsWith('9')) {
      _showErrorModal(
        'Invalid Mobile Prefix',
        'Philippine mobile numbers start with 9 (e.g. 917 123 4567). Please change the first digit to 9.',
      );
      return;
    }

    if (nationalDigits.length < 10) {
      final remaining = 10 - nationalDigits.length;
      _showErrorModal(
        'Incomplete Mobile Number',
        'Please enter the full 10-digit mobile number ($remaining more digit${remaining > 1 ? "s" : ""} required).',
      );
      return;
    }

    if (!_isPhoneVerified) {
      _showErrorModal(
        'Phone Number Unavailable',
        'This phone number is already registered to another account or is still being validated. Please check the number or use a different one.',
      );
      return;
    }

    // If already verified via SMS OTP for this exact phone number, advance
    if (_isPhoneOtpVerified && _otpVerifiedPhoneNumber == _verifiedPhone) {
      setState(() => _currentStep = 1);
      return;
    }

    // Dispatch SMS OTP verification
    setState(() => _isSendingOtp = true);

    final sent = await TextBeeOtpService().sendOtp(
      phoneNumber: _verifiedPhone,
      onSuccess: (code) {
        debugPrint(
          '✅ TextBee SMS OTP dispatched for web complete profile: $_verifiedPhone',
        );
      },
      onError: (err) {
        debugPrint('⚠️ TextBee SMS OTP error: $err');
      },
    );

    if (!mounted) return;
    setState(() => _isSendingOtp = false);

    if (!sent) {
      _showErrorModal(
        'SMS Service Notice',
        'Failed to dispatch SMS verification code to $_verifiedPhone. Please check your signal and try again.',
      );
      return;
    }

    // Show Phone OTP Verification Dialog
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PhoneOtpVerificationDialog(
        phoneNumber: _verifiedPhone,
        title: 'Verify Phone Number',
        subtitle:
            'Enter the 6-digit SMS code sent to your phone to verify your number before setting your password.',
      ),
    );

    if (verified == true && mounted) {
      setState(() {
        _isPhoneOtpVerified = true;
        _otpVerifiedPhoneNumber = _verifiedPhone;
        _currentStep = 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Phone number verified successfully!',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _goToPhoneStep() {
    setState(() => _currentStep = 0);
  }

  Future<void> _handleFinalize() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.isEmpty) {
      _showErrorModal(
        'Missing Password',
        'Please create a secure password for your account',
      );
      return;
    }

    if (password != confirmPassword) {
      _showErrorModal('Password Mismatch', 'Passwords do not match');
      return;
    }

    if (password.length < 6) {
      _showErrorModal(
        'Weak Password',
        'Password must be at least 6 characters',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await AuthService().completeProfile(
        phoneNumber: _verifiedPhone,
        password: password,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        if (widget.onComplete != null) {
          widget.onComplete!();
        } else if (widget.onFinalizeSuccess != null) {
          widget.onFinalizeSuccess!();
        } else {
          final auth = AuthService();
          if (auth.isAdmin) {
            context.go(AppRoutes.admin);
          } else if (auth.isViewingAsFarmer) {
            context.go(AppRoutes.farmerDashboard);
          } else {
            context.go(AppRoutes.home);
          }
        }
      } else {
        _showErrorModal(
          'Update Failed',
          AuthService().errorMessage ??
              'Failed to save profile. Please try again.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorModal('Error', 'An unexpected error occurred: $e');
    }
  }

  Future<void> _handleLogout() async {
    final locale = FarmerLocaleService.instance;
    await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => PremiumConfirmDialog(
        title: locale.t('logout_confirm_title'),
        content: locale.t('logout_confirm_body'),
        confirmText: locale.t('logout_sign_in_later'),
        loadingText: '...',
        onConfirm: () async {
          await AuthService().logout();
          if (mounted) {
            context.go(AppRoutes.login);
          }
        },
      ),
    );
  }

  void _showErrorModal(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          message,
          style:
              GoogleFonts.inter(fontSize: 14, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.inter(
                color: const Color(0xFF059669),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isDesktop = sw >= 1000;
    final locale = FarmerLocaleService.instance;

    return ListenableBuilder(
      listenable: locale,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Row(
            children: [
              // Left: High-Contrast Agriculture Billboard (Desktop Only)
              if (isDesktop)
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF064E3B), Color(0xFF047857)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 40,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.agriculture_rounded,
                                  color: Colors.white,
                                  size: 44,
                                ),
                              ),
                              const SizedBox(height: 28),
                              Text(
                                locale.t('complete_profile'),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.15,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                locale.t('complete_profile_sub'),
                                style: GoogleFonts.inter(
                                  fontSize: 15.5,
                                  color: Colors.white.withValues(alpha: 0.88),
                                  height: 1.55,
                                ),
                              ),
                              const SizedBox(height: 36),
                              _buildFeatureBadge(
                                icon: Icons.verified_user_rounded,
                                label: locale.isFilipino
                                    ? 'Ligtas at Beripikadong Transaksyon'
                                    : 'Safe & Verified Account Security',
                              ),
                              const SizedBox(height: 12),
                              _buildFeatureBadge(
                                icon: Icons.storefront_rounded,
                                label: locale.isFilipino
                                    ? 'Direktang Pamilihan sa Magsasaka'
                                    : 'Direct Farm-to-Table Marketplace',
                              ),
                              const SizedBox(height: 12),
                              _buildFeatureBadge(
                                icon: Icons.phonelink_ring_rounded,
                                label: locale.isFilipino
                                    ? 'Mabilis at Walang Antalang Pag-verify'
                                    : 'Instant SMS-Free Phone Linking',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Right: Centered Responsive Step Form Card
              Expanded(
                flex: 6,
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 40 : 20,
                      vertical: 36,
                    ),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 520),
                      padding: EdgeInsets.all(isDesktop ? 36 : 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top App Bar & Step Indicator
                          Row(
                            children: [
                              if (_currentStep == 1) ...[
                                IconButton(
                                  onPressed: _goToPhoneStep,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    color: FarmerTheme.textHeadline,
                                    size: 22,
                                  ),
                                  tooltip: 'Back to step 1',
                                ),
                                const SizedBox(width: 12),
                              ],
                              // Step Pill Indicator
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: FarmerTheme.softMint,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: FarmerTheme.primaryAction
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  locale.isFilipino
                                      ? 'Hakbang ${_currentStep + 1} ng 2'
                                      : 'Step ${_currentStep + 1} of 2',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: FarmerTheme.primaryAction,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              const FarmerLanguageToggle(compact: true),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // Animated Step View
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _currentStep == 0
                                ? _buildStep1Phone(locale)
                                : _buildStep2Password(locale),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Step 1: Mobile Phone Number UI
  Widget _buildStep1Phone(FarmerLocaleService locale) {
    final nameStr = _effectiveName;

    return Column(
      key: const ValueKey('step_1_phone'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Center Mint Circle Icon
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.phonelink_lock_rounded,
              color: Color(0xFF059669),
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Title
        Text(
          locale.t('phone_step_title'),
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),

        // Subtitle
        Text(
          nameStr.isNotEmpty
              ? '${locale.isFilipino ? "Maligayang pagdating" : "Welcome"}, $nameStr!\n${locale.t("phone_step_sub")}'
              : locale.t('phone_step_sub'),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14.5,
            color: const Color(0xFF64748B),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),

        // Distinctive Phone Input (with +63 flag, duplicate validation)
        DistinctivePhoneInput(
          key: const ValueKey('web_complete_profile_phone_input'),
          controller: _phoneController,
          initialPhone: _verifiedPhone,
          onChanged: (formattedE164, isValidAndUnique) {
            if (_verifiedPhone != formattedE164 ||
                _isPhoneVerified != isValidAndUnique) {
              setState(() {
                _verifiedPhone = formattedE164;
                _isPhoneVerified = isValidAndUnique;
                if (_verifiedPhone != _otpVerifiedPhoneNumber) {
                  _isPhoneOtpVerified = false;
                }
              });
            }
          },
        ),
        const SizedBox(height: 28),

        // CTA: Save & Continue / Verify with SMS OTP Button (56px)
        FarmerButton(
          label: _isPhoneOtpVerified
              ? (locale.isFilipino ? 'I-save at Magpatuloy' : 'Save & Continue')
              : (locale.isFilipino
                  ? 'I-verify gamit ang SMS OTP'
                  : 'Verify with SMS OTP'),
          icon: _isPhoneOtpVerified
              ? Icons.arrow_forward_rounded
              : Icons.sms_rounded,
          isLoading: _isSendingOtp,
          height: 56,
          onPressed: _goToPasswordStep,
        ),
        const SizedBox(height: 18),

        // Secondary Exit: Log Out & Sign In Later
        Center(
          child: TextButton.icon(
            onPressed: _handleLogout,
            icon: const Icon(
              Icons.logout_rounded,
              size: 16,
              color: FarmerTheme.statusError,
            ),
            label: Text(
              locale.t('logout_sign_in_later'),
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: FarmerTheme.statusError,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Step 2: Create Account Password UI
  Widget _buildStep2Password(FarmerLocaleService locale) {
    final isPasswordValid = _passwordController.text.length >= 6;
    final passwordsMatch = _passwordController.text.isNotEmpty &&
        _passwordController.text == _confirmPasswordController.text;

    return Column(
      key: const ValueKey('step_2_password'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Center Mint Circle Icon
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: FarmerTheme.softMint,
              shape: BoxShape.circle,
              border: Border.all(
                color: FarmerTheme.primaryAction.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: FarmerTheme.primaryAction,
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Title
        Text(
          locale.t('password_step_title'),
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),

        // Subtitle
        Text(
          locale.t('password_step_sub'),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14.5,
            color: const Color(0xFF64748B),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),

        // Password Label
        Text(
          locale.t('password_label'),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),

        // Password Input
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F172A),
          ),
          decoration: _inputDecoration(
            hintText: locale.t('password_hint'),
            prefixIcon: Icons.lock_rounded,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: const Color(0xFF94A3B8),
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),

        // Confirm Password Label
        Text(
          locale.t('confirm_password_label'),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),

        // Confirm Password Input
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F172A),
          ),
          decoration: _inputDecoration(
            hintText: locale.t('confirm_password_hint'),
            prefixIcon: Icons.lock_clock_rounded,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: const Color(0xFF94A3B8),
                size: 20,
              ),
              onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),

        // Requirement hints
        Row(
          children: [
            Icon(
              isPasswordValid
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 15,
              color: isPasswordValid
                  ? const Color(0xFF16A34A)
                  : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 6),
            Text(
              locale.isFilipino
                  ? 'Kahit 6 na letra o numero'
                  : 'At least 6 characters',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isPasswordValid
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 16),
            if (_confirmPasswordController.text.isNotEmpty) ...[
              Icon(
                passwordsMatch
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                size: 15,
                color: passwordsMatch
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
              ),
              const SizedBox(width: 6),
              Text(
                passwordsMatch
                    ? (locale.isFilipino ? 'Nagtutugma' : 'Passwords match')
                    : (locale.isFilipino
                        ? 'Hindi nagtutugma'
                        : 'Passwords do not match'),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: passwordsMatch
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 28),

        // Complete Profile CTA Button
        FarmerButton(
          label: locale.isFilipino
              ? 'Kumpletuhin ang Profile'
              : 'Complete Profile',
          icon: Icons.check_circle_rounded,
          height: 56,
          isLoading: _isLoading,
          onPressed: _handleFinalize,
        ),
        const SizedBox(height: 18),

        // Secondary Exit
        Center(
          child: TextButton.icon(
            onPressed: _isLoading ? null : _handleLogout,
            icon: const Icon(
              Icons.logout_rounded,
              size: 16,
              color: FarmerTheme.statusError,
            ),
            label: Text(
              locale.t('logout_sign_in_later'),
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: FarmerTheme.statusError,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureBadge({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        color: const Color(0xFF94A3B8),
      ),
      prefixIcon: Icon(prefixIcon, color: FarmerTheme.primaryAction, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: FarmerTheme.primaryAction,
          width: 2.0,
        ),
      ),
    );
  }
}
