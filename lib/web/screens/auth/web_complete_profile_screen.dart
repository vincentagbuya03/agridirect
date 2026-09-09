import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/localization/farmer_locale_service.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/styles/farmer_theme.dart';
import '../../../shared/widgets/distinctive_phone_input.dart';
import '../../../shared/widgets/farmer/farmer_button.dart';
import '../../../shared/widgets/farmer/farmer_language_toggle.dart';
import '../../../shared/widgets/farmer/farmer_step_card.dart';
import '../../../shared/widgets/premium_confirm_dialog.dart';

/// Farmer-First Web Profile Completion Screen.
/// Features instant bilingual switching (English ⇄ Filipino),
/// 56px+ tactile buttons, high sunlight contrast, and 2-step visual cards.
class WebCompleteProfileScreen extends StatefulWidget {
  final String userId;
  final String email;
  final String name;
  final VoidCallback onFinalizeSuccess;

  const WebCompleteProfileScreen({
    super.key,
    required this.userId,
    required this.email,
    required this.name,
    required this.onFinalizeSuccess,
  });

  @override
  State<WebCompleteProfileScreen> createState() =>
      _WebCompleteProfileScreenState();
}

class _WebCompleteProfileScreenState extends State<WebCompleteProfileScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _verifiedPhone = '';
  bool _isPhoneVerified = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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

  Future<void> _handleComplete() async {
    final locale = FarmerLocaleService.instance;

    if (!_isPhoneVerified || _verifiedPhone.isEmpty) {
      _showSnackBar(locale.t('phone_required'));
      return;
    }

    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar(locale.t('password_required'));
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar(locale.t('passwords_mismatch'));
      return;
    }

    final passwordError = AuthService.validatePassword(password);
    if (passwordError != null) {
      _showSnackBar(passwordError);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await AuthService().updateUserPasswordAndPhone(
        phoneNumber: _verifiedPhone,
        password: password,
      );

      if (!mounted) return;

      setState(() => _isLoading = false);
      if (success) {
        widget.onFinalizeSuccess();
      } else {
        _showSnackBar(
          AuthService().errorMessage ?? 'Unable to finalize registration',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Error: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 1100;
    final locale = FarmerLocaleService.instance;

    return ListenableBuilder(
      listenable: locale,
      builder: (context, _) {
        final isPasswordValid = _passwordController.text.isNotEmpty &&
            _passwordController.text == _confirmPasswordController.text &&
            _passwordController.text.length >= 6;

        return Scaffold(
          backgroundColor: FarmerTheme.backgroundLight,
          body: Row(
            children: [
              // Left: High-Contrast Agriculture Billboard (Desktop Only)
              if (!isCompact)
                Expanded(
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
                        padding: const EdgeInsets.all(56),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
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
                                size: 54,
                              ),
                            ),
                            const SizedBox(height: 32),
                            Text(
                              locale.t('complete_profile'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              locale.t('complete_profile_sub'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: Colors.white.withValues(alpha: 0.85),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 40),
                            _buildFeatureBadge(
                              icon: Icons.check_circle_rounded,
                              label: locale.isFilipino
                                  ? 'Direktang Koneksyon sa Mamimili'
                                  : 'Direct Connection to Buyers',
                            ),
                            const SizedBox(height: 12),
                            _buildFeatureBadge(
                              icon: Icons.security_rounded,
                              label: locale.isFilipino
                                  ? 'Ligtas at Protektadong Impormasyon'
                                  : 'Safe & Protected Account Security',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Right: Farmer-Friendly 2-Step Form Card
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 36,
                    ),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 560),
                      padding: EdgeInsets.all(isCompact ? 24 : 36),
                      decoration: FarmerTheme.cardDecoration,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top Header Row: Icon & Instant Language Toggle
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: FarmerTheme.softMint,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.eco_rounded,
                                  color: FarmerTheme.primaryAction,
                                  size: 28,
                                ),
                              ),
                              const FarmerLanguageToggle(),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Header Text
                          Text(
                            locale.t('complete_profile'),
                            style: FarmerTheme.headline,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${locale.isFilipino ? "Maligayang pagdating" : "Welcome"}, ${widget.name}. ${locale.t("complete_profile_sub")}',
                            style: FarmerTheme.bodyMuted,
                          ),
                          const SizedBox(height: 16),

                          // Verified Email Capsule
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: FarmerTheme.softMint,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: FarmerTheme.primaryAction.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.mark_email_read_rounded,
                                  color: FarmerTheme.primaryAction,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    widget.email,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF064E3B),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    locale.t('verified_badge'),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: FarmerTheme.primaryAction,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Step 1: Mobile Phone Number Card
                          FarmerStepCard(
                            stepNumber: '1',
                            title: locale.t('phone_step_title'),
                            subtitle: locale.t('phone_step_sub'),
                            icon: Icons.phone_iphone_rounded,
                            isCompleted:
                                _isPhoneVerified && _verifiedPhone.isNotEmpty,
                            child: DistinctivePhoneInput(
                              initialPhone: _verifiedPhone,
                              onChanged: (formattedE164, isValidAndUnique) {
                                setState(() {
                                  _verifiedPhone = formattedE164;
                                  _isPhoneVerified = isValidAndUnique;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Step 2: Create Account Password Card
                          FarmerStepCard(
                            stepNumber: '2',
                            title: locale.t('password_step_title'),
                            subtitle: locale.t('password_step_sub'),
                            icon: Icons.lock_outline_rounded,
                            isCompleted: isPasswordValid,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  locale.t('password_label'),
                                  style: FarmerTheme.body.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: FarmerTheme.body.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: _farmerInputDecoration(
                                    hintText: locale.t('password_hint'),
                                    prefixIcon: Icons.lock_rounded,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_rounded
                                            : Icons.visibility_rounded,
                                        color: FarmerTheme.textMuted,
                                      ),
                                      onPressed: () => setState(
                                        () =>
                                            _obscurePassword = !_obscurePassword,
                                      ),
                                    ),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  locale.t('confirm_password_label'),
                                  style: FarmerTheme.body.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _confirmPasswordController,
                                  obscureText: _obscureConfirmPassword,
                                  style: FarmerTheme.body.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: _farmerInputDecoration(
                                    hintText: locale.t('confirm_password_hint'),
                                    prefixIcon: Icons.lock_clock_rounded,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirmPassword
                                            ? Icons.visibility_off_rounded
                                            : Icons.visibility_rounded,
                                        color: FarmerTheme.textMuted,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscureConfirmPassword =
                                            !_obscureConfirmPassword,
                                      ),
                                    ),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Giant 58px Tactile CTA Button
                          FarmerButton(
                            label: locale.t('create_account_cta'),
                            icon: Icons.check_circle_rounded,
                            height: 58,
                            isLoading: _isLoading,
                            onPressed: _handleComplete,
                          ),
                          const SizedBox(height: 20),

                          // Clear Exit Option
                          Center(
                            child: TextButton.icon(
                              onPressed: _isLoading ? null : _handleLogout,
                              icon: const Icon(
                                Icons.logout_rounded,
                                size: 18,
                                color: FarmerTheme.statusError,
                              ),
                              label: Text(
                                locale.t('logout_sign_in_later'),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: FarmerTheme.statusError,
                                ),
                              ),
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
        );
      },
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

  InputDecoration _farmerInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: FarmerTheme.bodyMuted.copyWith(
        fontSize: 15,
        color: const Color(0xFF64748B),
      ),
      prefixIcon: Icon(prefixIcon, color: FarmerTheme.primaryAction, size: 22),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FarmerTheme.buttonBorderRadius),
        borderSide: const BorderSide(
          color: FarmerTheme.borderCrisp,
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FarmerTheme.buttonBorderRadius),
        borderSide: const BorderSide(
          color: FarmerTheme.borderFocused,
          width: 2.0,
        ),
      ),
    );
  }
}
