import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/app_shimmer_loader.dart';

/// Mobile Login screen with an un-scrollable, pixel-perfect layout that fits
/// completely within standard mobile viewports without vertical scrolling.
class MobileLoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const MobileLoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<MobileLoginScreen> createState() => _MobileLoginScreenState();
}

class _MobileLoginScreenState extends State<MobileLoginScreen> {
  // Brand Color Tokens
  static const Color _primary = Color(0xFF005A36);
  static const Color _primaryLight = Color(0xFF047857);
  static const Color _emerald = Color(0xFF10B981);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);
  static const Color _cardBg = Colors.white;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _hasInternet = true;
  bool _isWaitingForInternet = false;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  final Connectivity _connectivity = Connectivity();
  Timer? _internetWaitTimer;

  @override
  void initState() {
    super.initState();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      if (results.contains(ConnectivityResult.none)) {
        setState(() {
          _hasInternet = false;
          if (!_isWaitingForInternet) _startWaitingForInternet();
        });
      } else {
        setState(() {
          _hasInternet = true;
          _isWaitingForInternet = false;
        });
      }
    });
  }

  Future<void> _checkInternetConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (mounted) {
        setState(() {
          _hasInternet = !results.contains(ConnectivityResult.none);
          if (!_hasInternet && !_isWaitingForInternet) {
            _startWaitingForInternet();
          }
        });
      }
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
    }
  }

  void _startWaitingForInternet() {
    if (mounted) {
      setState(() => _isWaitingForInternet = true);
    }

    _internetWaitTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _isWaitingForInternet) {
        _checkInternetStatus();
      }
    });
  }

  Future<void> _checkInternetStatus() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final hasInternet = !results.contains(ConnectivityResult.none);

      if (mounted) {
        setState(() {
          _isWaitingForInternet = false;
          if (!hasInternet) {
            _showNoInternetDialogWithQuit();
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isWaitingForInternet = false);
    }
  }

  void _handleLogin() async {
    // Prevent double clicking
    if (_isLoading || _isGoogleLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showErrorModal('Missing Fields', 'Please enter your email and password.');
      return;
    }

    await _checkInternetConnectivity();
    if (!_hasInternet) {
      _showNoInternetDialog();
      return;
    }

    setState(() => _isLoading = true);
    final auth = AuthService();
    final success = await auth.login(email: email, password: password);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        if (auth.requiresMfa) {
          context.push(AppRoutes.mfaChallenge);
        } else if (auth.needsProfileCompletion) {
          context.push(AppRoutes.completeProfile);
        } else {
          widget.onLoginSuccess();
        }
      } else {
        _showErrorModal(
          'Login Failed',
          auth.errorMessage ?? 'Invalid email or password. Please try again.',
        );
      }
    }
  }

  void _handleGoogleSignIn() async {
    // Prevent double clicking
    if (_isLoading || _isGoogleLoading) return;

    await _checkInternetConnectivity();
    if (!_hasInternet) {
      _showNoInternetDialog();
      return;
    }

    setState(() => _isGoogleLoading = true);
    final success = await AuthService().signInWithGoogle();

    if (mounted) {
      setState(() => _isGoogleLoading = false);
      if (success) {
        if (AuthService().needsProfileCompletion) {
          context.push(AppRoutes.completeProfile);
        } else {
          widget.onLoginSuccess();
        }
      } else {
        _showErrorModal(
          'Google Sign-In Failed',
          AuthService().errorMessage ?? 'Failed to sign in with Google.',
        );
      }
    }
  }

  void _showErrorModal(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: _dark,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(fontSize: 13.5, color: _muted, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showNoInternetDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.wifi_off_rounded, color: Color(0xFFD97706), size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'No Internet',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 17, color: _dark),
            ),
          ],
        ),
        content: Text(
          'Please check your network connection and try again.',
          style: GoogleFonts.inter(fontSize: 13.5, color: _muted),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showNoInternetDialogWithQuit() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: Colors.white,
        title: Text('Connection Error', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 17, color: _dark)),
        content: Text(
          'Unable to connect after multiple attempts. Please check your data connection.',
          style: GoogleFonts.inter(fontSize: 13.5, color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => SystemNavigator.pop(),
            child: const Text('Quit', style: TextStyle(color: Color(0xFFDC2626))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _checkInternetConnectivity();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _internetWaitTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ─── Ambient Organic Backdrop Orbs ───
          Positioned(
            top: -90,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _emerald.withValues(alpha: 0.12),
                    _primary.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 200,
            left: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _emerald.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ─── Unscrollable Core Viewport ───
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  // When keyboard is closed, physics disables scrolling because content fits perfectly.
                  // If keyboard opens on smaller screens, it smoothly adjusts to prevent overflow.
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 8),

                              // ─── Brand Logo & Identity (No Duplicate Text) ───
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 54,
                                      height: 54,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: _primary.withValues(alpha: 0.1),
                                            blurRadius: 16,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Center(
                                        child: BrandLogo(
                                          size: BrandLogoSize.small,
                                          useIconOnly: true,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'AgriDirect',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: _dark,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0xFFA7F3D0), width: 0.8),
                                      ),
                                      child: Text(
                                        'Direct from farm to your table',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _primary,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 18),

                              // ─── Welcome Header ───
                              Text(
                                'Welcome Back',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                  color: _dark,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Sign in to access fresh local produce directly from farmers.',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: _muted,
                                  height: 1.35,
                                ),
                              ),

                              const SizedBox(height: 14),

                              // ─── Form Card Container ───
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                decoration: BoxDecoration(
                                  color: _cardBg,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: _border),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 14,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Email Address Field
                                    _buildInputLabel('Email Address'),
                                    const SizedBox(height: 6),
                                    _buildTextField(
                                      controller: _emailController,
                                      hintText: 'name@example.com',
                                      prefixIcon: Icons.mail_outline_rounded,
                                      keyboardType: TextInputType.emailAddress,
                                      autofillHints: const [AutofillHints.email],
                                    ),
                                    const SizedBox(height: 12),

                                    // Password Field
                                    _buildInputLabel('Password'),
                                    const SizedBox(height: 6),
                                    _buildTextField(
                                      controller: _passwordController,
                                      hintText: 'Enter your password',
                                      prefixIcon: Icons.lock_outline_rounded,
                                      obscureText: _obscurePassword,
                                      autofillHints: const [AutofillHints.password],
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          size: 18,
                                          color: _muted,
                                        ),
                                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                      ),
                                    ),

                                    const SizedBox(height: 8),

                                    // Forgot Password Link
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: _isLoading
                                            ? null
                                            : () => context.push(AppRoutes.resetPasswordWithCode),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          'Forgot Password?',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _primary,
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 14),

                                    // Primary Sign In Button
                                    SizedBox(
                                      width: double.infinity,
                                      height: 46,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [_primary, _primaryLight],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _primary.withValues(alpha: 0.25),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: (_isLoading || _isGoogleLoading) ? null : _handleLogin,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            foregroundColor: Colors.white,
                                            shadowColor: Colors.transparent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: _isLoading
                                              ? const SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child: CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : Text(
                                                  'Sign In',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15,
                                                    letterSpacing: 0.2,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 14),

                              // ─── Divider ───
                              Row(
                                children: [
                                  const Expanded(child: Divider(color: _border, thickness: 1)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      'OR CONTINUE WITH',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF94A3B8),
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                  const Expanded(child: Divider(color: _border, thickness: 1)),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // ─── Google Sign In Button ───
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: OutlinedButton(
                                  onPressed: (_isLoading || _isGoogleLoading) ? null : _handleGoogleSignIn,
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: _border, width: 1.1),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    backgroundColor: Colors.white,
                                    elevation: 0,
                                  ),
                                  child: _isGoogleLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: _primary,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            _buildGoogleIcon(),
                                            const SizedBox(width: 10),
                                            Text(
                                              'Continue with Google',
                                              style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w600,
                                                color: _dark,
                                                fontSize: 13.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),

                              const Spacer(),

                              // ─── Sign Up Footer ───
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "Don't have an account? ",
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: _muted,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => context.push(AppRoutes.register),
                                        child: Text(
                                          'Sign Up',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: _primary,
                                            fontWeight: FontWeight.w700,
                                          ),
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
                    ),
                  ),
                );
              },
            ),
          ),

          // ─── Waiting for Internet Overlay ───
          if (_isWaitingForInternet)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppShimmerLoader(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(_primary),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Connecting',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: _dark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Establishing connection to AgriDirect servers...',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 12.5, color: _muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: _dark,
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
    List<String>? autofillHints,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      style: GoogleFonts.inter(fontSize: 13.5, color: _dark),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
        prefixIcon: Icon(prefixIcon, size: 18, color: _muted),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: _surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(Icons.g_mobiledata, size: 26, color: Color(0xFF4285F4)),
      ),
    );
  }
}
