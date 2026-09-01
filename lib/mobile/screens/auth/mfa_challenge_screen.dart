import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/widgets/app_shimmer_loader.dart';

class MfaChallengeScreen extends StatefulWidget {
  const MfaChallengeScreen({super.key});

  @override
  State<MfaChallengeScreen> createState() => _MfaChallengeScreenState();
}

class _MfaChallengeScreenState extends State<MfaChallengeScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  String? _error;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initial focus on first input box after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusNodes.isNotEmpty) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String _getCode() => _controllers.map((c) => c.text.trim()).join();

  void _clearAllFields({bool refocusFirst = true}) {
    for (final c in _controllers) {
      c.clear();
    }
    if (refocusFirst && mounted) {
      _focusNodes[0].requestFocus();
    }
  }

  void _handleChanged(int index, String value) {
    if (value.isEmpty) return;

    // Handle multi-character paste
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isNotEmpty) {
        for (int i = 0; i < 6; i++) {
          if (i < digits.length) {
            _controllers[i].text = digits[i];
          }
        }
        final targetIndex = digits.length < 6 ? digits.length : 5;
        _focusNodes[targetIndex].requestFocus();

        if (digits.length >= 6) {
          _verify();
        }
        return;
      }
    }

    // Keep only the last typed character
    final singleDigit = value.substring(value.length - 1);
    _controllers[index].text = singleDigit;

    if (_error != null) {
      setState(() => _error = null);
    }

    if (index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else {
      _focusNodes[index].unfocus();
    }

    // Automatically submit once all 6 fields are completed
    if (_getCode().length == 6 && !_isLoading) {
      _verify();
    }
  }

  void _handleKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty && index > 0) {
        _controllers[index - 1].clear();
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  Future<void> _verify() async {
    if (_isLoading) return;

    final auth = AuthService();
    if (!auth.canVerifyMfa) {
      context.go(AppRoutes.login);
      return;
    }

    final code = _getCode();
    if (code.length != 6) {
      setState(() => _error = 'Please enter all 6 digits');
      return;
    }

    // Unfocus keyboard during verification
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final success = await auth.verifyMfa(code);

    if (!mounted) return;

    if (success) {
      context.go(AppRoutes.home);
    } else {
      setState(() {
        _isLoading = false;
        _error = auth.errorMessage ?? 'Invalid verification code. Please try again.';
      });
      // Clear fields and focus back to first cell on error
      _clearAllFields(refocusFirst: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: AppColors.textHeadline,
              ),
            ),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 12),
                      _buildSecurityBadge(),
                      const SizedBox(height: 28),
                      Text(
                        'Two-Factor Authentication',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textHeadline,
                          letterSpacing: -0.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Enter the 6-digit code from your authenticator app (Google Authenticator, Authy, etc.)',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textSubtle,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 36),
                      _buildPinInputSection(),
                      const SizedBox(height: 24),
                      if (_error != null) _buildErrorBanner(),
                      const SizedBox(height: 28),
                      _buildStatusIndicator(),
                      const SizedBox(height: 36),
                      _buildSecurityFooter(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSecurityBadge() {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.18),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.12),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.shield_outlined,
            size: 38,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildPinInputSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _error != null
              ? AppColors.error.withValues(alpha: 0.3)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < 6; i++) ...[
            if (i == 3)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                width: 6,
                height: 2,
                decoration: BoxDecoration(
                  color: const Color(0xFF94A3B8),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            Expanded(
              child: AspectRatio(
                aspectRatio: 0.85,
                child: _buildDigitCell(i),
              ),
            ),
            if (i < 5 && i != 2) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildDigitCell(int index) {
    final isFocused = _focusNodes[index].hasFocus;
    final isFilled = _controllers[index].text.isNotEmpty;

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) => _handleKeyEvent(index, event),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        enabled: !_isLoading,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 6, // Allows paste of full code
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        style: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textHeadline,
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: isFocused
              ? AppColors.primary.withValues(alpha: 0.05)
              : (isFilled ? const Color(0xFFF8FAFC) : Colors.white),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isFilled ? AppColors.primary : const Color(0xFFE2E8F0),
              width: isFilled ? 1.5 : 1.0,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.primary,
              width: 2.0,
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        onChanged: (val) => _handleChanged(index, val),
        onTap: () {
          if (_controllers[index].text.isNotEmpty) {
            _controllers[index].selection = TextSelection(
              baseOffset: 0,
              extentOffset: _controllers[index].text.length,
            );
          }
        },
      ),
    );
  }

  Widget _buildErrorBanner() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF991B1B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: AppShimmerLoader(
                color: AppColors.primary,
                strokeWidth: 2.2,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Verifying code...',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bolt_rounded,
            size: 16,
            color: AppColors.primary.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Code verifies automatically upon entering 6 digits',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSubtle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityFooter() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_clock_outlined,
                size: 15,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Authenticator codes refresh every 30 seconds',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _isLoading ? null : () => context.go(AppRoutes.login),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSubtle,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: Text(
            'Switch Account / Back to Login',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
