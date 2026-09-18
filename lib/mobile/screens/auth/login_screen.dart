import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/router/app_router.dart';
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

    final identifier = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      _showErrorModal(
        'Missing Fields',
        'Please enter your email or mobile number and password.',
      );
      return;
    }

    await _checkInternetConnectivity();
    if (!_hasInternet) {
      _showNoInternetDialog();
      return;
    }

    setState(() => _isLoading = true);
    final auth = AuthService();
    final success = await auth.login(email: identifier, password: password);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        if (auth.requiresMfa) {
          context.go(AppRoutes.mfaChallenge);
        } else if (auth.needsProfileCompletion) {
          context.go(AppRoutes.completeProfile);
        } else {
          widget.onLoginSuccess();
        }
      } else {
        _showErrorModal(
          'Login Failed',
          auth.errorMessage ??
              'Invalid email/mobile number or password. Please try again.',
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
          context.go(AppRoutes.completeProfile);
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
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFF002E1B),
      resizeToAvoidBottomInset: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            // ─── Main Scrollable Layout ───
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
                            // ─── 1. Lush Brand Hero Header (Top Canopy) ───
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.only(
                                top: topPadding + 14,
                                bottom: 30,
                                left: 24,
                                right: 24,
                              ),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF002616),
                                    Color(0xFF004D2C),
                                    Color(0xFF006837),
                                  ],
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Subtle organic backdrop radial glows
                                  Positioned(
                                    top: -40,
                                    right: -30,
                                    child: Container(
                                      width: 140,
                                      height: 140,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _emerald.withValues(alpha: 0.20),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: -20,
                                    left: -30,
                                    child: Container(
                                      width: 110,
                                      height: 110,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withValues(alpha: 0.07),
                                      ),
                                    ),
                                  ),

                                  // Brand Identity Column
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Elevated Logo Container
                                      Container(
                                        width: 66,
                                        height: 66,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.85),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.22),
                                              blurRadius: 18,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: Image.asset(
                                          'assets/icon/logo_v3.png',
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'AgriDirect',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: -0.6,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.25),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.eco_rounded,
                                              size: 13,
                                              color: Color(0xFF86EFAC),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Direct from farm to your table',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFFF0FDF4),
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // ─── 2. Sleek Curved White Sheet (Form Container) ───
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(30),
                                    topRight: Radius.circular(30),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x18000000),
                                      blurRadius: 20,
                                      offset: Offset(0, -6),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                                child: AutofillGroup(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Title & Subtitle
                                      Text(
                                        'Welcome Back 👋',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: _dark,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Sign in to access fresh produce & manage your account.',
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          color: _muted,
                                          height: 1.35,
                                        ),
                                      ),

                                      const SizedBox(height: 18),

                                      // Email or Mobile Number Field
                                      _buildInputLabel('Email or Mobile Number'),
                                      const SizedBox(height: 6),
                                      _buildTextField(
                                        controller: _emailController,
                                        hintText: 'name@example.com or 09XXXXXXXXX',
                                        prefixIcon: Icons.alternate_email_rounded,
                                        keyboardType: TextInputType.emailAddress,
                                        autofillHints: const [AutofillHints.email, AutofillHints.telephoneNumber],
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
                                            size: 19,
                                            color: const Color(0xFF94A3B8),
                                          ),
                                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                        ),
                                      ),

                                      const SizedBox(height: 6),

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
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: _primary,
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 14),

                                      // Primary Sign In Button
                                      SizedBox(
                                        width: double.infinity,
                                        height: 50,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [_primary, _primaryLight],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(14),
                                            boxShadow: [
                                              BoxShadow(
                                                color: _primary.withValues(alpha: 0.32),
                                                blurRadius: 14,
                                                offset: const Offset(0, 5),
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
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                            ),
                                            child: _isLoading
                                                ? const SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child: CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2.2,
                                                    ),
                                                  )
                                                : Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Text(
                                                        'Sign In',
                                                        style: GoogleFonts.plusJakartaSans(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.w700,
                                                          fontSize: 15.5,
                                                          letterSpacing: 0.2,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      const Icon(
                                                        Icons.arrow_forward_rounded,
                                                        size: 18,
                                                        color: Colors.white,
                                                      ),
                                                    ],
                                                  ),
                                          ),
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
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF94A3B8),
                                                letterSpacing: 0.9,
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
                                        height: 48,
                                        child: OutlinedButton(
                                          onPressed: (_isLoading || _isGoogleLoading) ? null : _handleGoogleSignIn,
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            backgroundColor: const Color(0xFFF8FAFC),
                                            elevation: 0,
                                          ),
                                          child: _isGoogleLoading
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    color: _primary,
                                                    strokeWidth: 2.2,
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    _buildGoogleIcon(),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      'Continue with Google',
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontWeight: FontWeight.w700,
                                                        color: const Color(0xFF1E293B),
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
                                          padding: const EdgeInsets.only(top: 8.0, bottom: 2.0),
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
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 13.5,
                                                    color: _primary,
                                                    fontWeight: FontWeight.w800,
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
                          ],
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
    ),
  );
}

  Widget _buildInputLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
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
        prefixIcon: Icon(prefixIcon, size: 19, color: const Color(0xFF94A3B8)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: _surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primary, width: 1.6),
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: const Size(16, 16),
          painter: const _GoogleLogoPainter(),
        ),
      ),
    );
  }
}

/// Precise 4-color Google G logo vector painter.
class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double strokeWidth = w * 0.22;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      w - strokeWidth,
      h - strokeWidth,
    );

    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Red arc (top: from ~215 deg to ~315 deg)
    canvas.drawArc(rect, 3.8, 1.6, false, redPaint);
    // Yellow arc (left: from ~125 deg to ~215 deg)
    canvas.drawArc(rect, 2.2, 1.6, false, yellowPaint);
    // Green arc (bottom: from ~35 deg to ~125 deg)
    canvas.drawArc(rect, 0.6, 1.6, false, greenPaint);
    // Blue arc (right: from ~-25 deg to ~35 deg)
    canvas.drawArc(rect, -0.4, 1.0, false, bluePaint);

    // Blue horizontal crossbar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final barRect = Rect.fromLTWH(
      w * 0.45,
      h * 0.5 - strokeWidth / 2,
      w * 0.55 - strokeWidth / 2,
      strokeWidth,
    );
    canvas.drawRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
