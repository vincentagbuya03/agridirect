import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/widgets/distinctive_phone_input.dart';
import '../../../shared/localization/farmer_locale_service.dart';
import '../../../shared/styles/farmer_theme.dart';
import '../../../shared/widgets/farmer/farmer_button.dart';
import '../../../shared/widgets/farmer/farmer_language_toggle.dart';

/// Screen shown to new users to complete their profile with a 2-step flow:
/// Step 1: Distinctive Phone Input (with duplicate check)
/// Step 2: Account Password Creation
class CompleteProfileScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const CompleteProfileScreen({super.key, required this.onComplete});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final PageController _pageController = PageController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _currentStep = 0;
  String _verifiedPhone = '';
  bool _isPhoneVerified = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _pageController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _goToPasswordStep() {
    final rawInput = (_verifiedPhone.isNotEmpty ? _verifiedPhone : _phoneController.text).trim();
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

    setState(() => _currentStep = 1);
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  void _goToPhoneStep() {
    setState(() => _currentStep = 0);
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
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

    final success = await AuthService().completeProfile(
      phoneNumber: _verifiedPhone,
      password: password,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      widget.onComplete();
      return;
    }

    _showErrorModal(
      'Update Failed',
      AuthService().errorMessage ?? 'Failed to save profile. Please try again.',
    );
  }

  void _showErrorModal(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            color: const Color(0xFF475569),
          ),
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
    final auth = AuthService();
    final locale = FarmerLocaleService.instance;

    return ListenableBuilder(
      listenable: locale,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        // Top App Bar & Step Indicator (Zero Overflow)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                          child: Row(
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
                                ),
                                const SizedBox(width: 10),
                              ],
                              // Step Pill Indicator
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: FarmerTheme.softMint,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: FarmerTheme.primaryAction.withValues(
                                      alpha: 0.3,
                                    ),
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
                        ),

                        // Page View: Step 1 (Phone) and Step 2 (Password)
                        Expanded(
                          child: PageView(
                            controller: _pageController,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _buildStep1Phone(auth, locale),
                              _buildStep2Password(locale),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (_isLoading)
                      Positioned.fill(
                        child: Container(
                          color: Colors.white.withValues(alpha: 0.7),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 20,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x14000000),
                                    blurRadius: 20,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: FarmerTheme.primaryAction,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    locale.isFilipino
                                        ? 'Inihahanda ang iyong account...'
                                        : 'Securing your account...',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: FarmerTheme.textHeadline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Step 1: Phone Verification
  Widget _buildStep1Phone(AuthService auth, FarmerLocaleService locale) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Icon
          Center(
            child: Container(
              width: 68,
              height: 68,
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
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 18),

          Center(
            child: Text(
              locale.t('phone_step_title'),
              style: FarmerTheme.headline.copyWith(fontSize: 22),
            ),
          ),
          const SizedBox(height: 6),

          Center(
            child: Text(
              '${locale.isFilipino ? "Maligayang pagdating" : "Welcome"}, ${auth.pendingName.isNotEmpty ? auth.pendingName : (locale.isFilipino ? "Magsasaka" : "Farmer")}!\n${locale.t("phone_step_sub")}',
              textAlign: TextAlign.center,
              style: FarmerTheme.bodyMuted.copyWith(fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),

          // Distinctive Phone Input (Zero OTP, Instant Uniqueness Check)
          DistinctivePhoneInput(
            key: const ValueKey('mobile_complete_profile_phone_input'),
            controller: _phoneController,
            initialPhone: _verifiedPhone,
            onChanged: (formattedE164, isValidAndUnique) {
              if (_verifiedPhone != formattedE164 || _isPhoneVerified != isValidAndUnique) {
                setState(() {
                  _verifiedPhone = formattedE164;
                  _isPhoneVerified = isValidAndUnique;
                });
              }
            },
          ),

          const SizedBox(height: 24),

          // Save & Continue Button (56px FarmerButton)
          FarmerButton(
            label: locale.isFilipino
                ? 'I-save at Magpatuloy'
                : 'Save & Continue',
            icon: Icons.arrow_forward_rounded,
            height: 56,
            onPressed: _goToPasswordStep,
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () async {
                await AuthService().logout();
                if (!mounted) return;
                context.go(AppRoutes.login);
              },
              icon: const Icon(
                Icons.logout_rounded,
                size: 16,
                color: FarmerTheme.statusError,
              ),
              label: Text(
                locale.t('logout_sign_in_later'),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: FarmerTheme.statusError,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Step 2: Account Password Creation
  Widget _buildStep2Password(FarmerLocaleService locale) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Icon
          Center(
            child: Container(
              width: 68,
              height: 68,
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
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 18),

          Center(
            child: Text(
              locale.t('password_step_title'),
              textAlign: TextAlign.center,
              style: FarmerTheme.headline.copyWith(fontSize: 22),
            ),
          ),
          const SizedBox(height: 6),

          Center(
            child: Text(
              locale.t('password_step_sub'),
              textAlign: TextAlign.center,
              style: FarmerTheme.bodyMuted.copyWith(fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),

          // Verified Phone summary pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF059669),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verified Number',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF047857),
                        ),
                      ),
                      Text(
                        _verifiedPhone,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _goToPhoneStep,
                  child: Text(
                    'Edit',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Password Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account Password *',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _passwordController,
                  hintText: 'Create password (min. 6 characters)',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: const Color(0xFF94A3B8),
                      size: 19,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  'Confirm Password *',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _confirmPasswordController,
                  hintText: 'Re-enter your password',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscureConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: const Color(0xFF94A3B8),
                      size: 19,
                    ),
                    onPressed: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Finalize Button (56px FarmerButton)
          FarmerButton(
            label: locale.t('create_account_cta'),
            icon: Icons.check_circle_rounded,
            height: 56,
            isLoading: _isLoading,
            onPressed: _handleFinalize,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(
          fontSize: 13,
          color: const Color(0xFF94A3B8),
        ),
        prefixIcon: Icon(prefixIcon, size: 19, color: const Color(0xFF64748B)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
        ),
      ),
    );
  }
}
