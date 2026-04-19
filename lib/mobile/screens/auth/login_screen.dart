import 'package:flutter/material.dart';
import '../../../shared/widgets/brand_logo.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/styles/app_theme.dart';
import 'dart:async';

/// Mobile Login screen with premium design.
class MobileLoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const MobileLoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<MobileLoginScreen> createState() => _MobileLoginScreenState();
}

class _MobileLoginScreenState extends State<MobileLoginScreen> {
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
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showErrorModal('Missing Fields', 'Please fill in all fields');
      return;
    }

    await _checkInternetConnectivity();
    if (!_hasInternet) {
      _showNoInternetDialog();
      return;
    }

    setState(() => _isLoading = true);
    final success = await AuthService().login(email: email, password: password);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        widget.onLoginSuccess();
      } else {
        _showErrorModal(
          'Login Failed',
          AuthService().errorMessage ?? 'Invalid credentials',
        );
      }
    }
  }

  void _handleGoogleSignIn() async {
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
          context.push(AppRoutes.googleCompleteProfile);
        } else {
          widget.onLoginSuccess();
        }
      } else {
        _showErrorModal(
          'Google Sign-In Failed',
          AuthService().errorMessage ?? 'Failed to sign in',
        );
      }
    }
  }

  void _showErrorModal(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: AppTextStyles.headline2),
        content: Text(message, style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: AppColors.warning),
            const SizedBox(width: 12),
            Text('No Internet', style: AppTextStyles.headline2),
          ],
        ),
        content: Text(
          'Please check your connection and try again.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Retry',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('No Internet Connection', style: AppTextStyles.headline2),
        content: Text(
          'Unable to connect after multiple attempts.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => SystemNavigator.pop(),
            child: const Text('Quit', style: TextStyle(color: AppColors.error)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkInternetConnectivity();
            },
            child: Text('Retry', style: TextStyle(color: AppColors.primary)),
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
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Subtle background decoration
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.05),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 32.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 56),
                  // Premium Brand Header
                  Center(
                    child: Column(
                      children: [
                        const BrandLogo(size: BrandLogoSize.large),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Direct from farm to your table',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 60),
                  Text(
                    'Welcome Back',
                    style: AppTextStyles.headline1.copyWith(
                      fontSize: 32,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to access fresh local produce directly from farmers.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSubtle,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Login Form Section
                  _buildInputLabel('Email Address'),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _emailController,
                    hintText: 'name@example.com',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 28),

                  _buildInputLabel('Password'),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _passwordController,
                    hintText: 'Enter your password',
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: AppColors.textSubtle,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => context.push(AppRoutes.resetPasswordWithCode),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Forgot Password?',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Sign In Button
                  SizedBox(
                    width: double.infinity,
                    height: 62,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shadowColor: AppColors.primary.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              'Sign In',
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 40),
                  // Divider
                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: Colors.grey[200], thickness: 1.5),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'OR CONTINUE WITH',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSubtle.withValues(alpha: 0.6),
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: Colors.grey[200], thickness: 1.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // Google Sign In
                  SizedBox(
                    width: double.infinity,
                    height: 62,
                    child: OutlinedButton(
                      onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[200]!, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        backgroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isGoogleLoading)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else ...[
                            Image.network(
                              'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_Logo.svg',
                              width: 22,
                              height: 22,
                              errorBuilder: (context, _, _) => const Icon(Icons.g_mobiledata, size: 30, color: Color(0xFF4285F4)),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              'Sign in with Google',
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textHeadline,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 56),
                  Center(
                    child: RichText(
                      text: TextSpan(
                        style: AppTextStyles.bodyMedium,
                        children: [
                          const TextSpan(text: "Don't have an account? "),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: GestureDetector(
                              onTap: () => context.push(AppRoutes.register),
                              child: Text(
                                'Sign Up',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),

          // Waiting for internet connection overlay
          if (_isWaitingForInternet)
            Container(
              color: Colors.black.withAlpha(150),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppShimmerLoader(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('Connecting', style: AppTextStyles.headline2),
                      const SizedBox(height: 12),
                      Text(
                        'Establishing connection to AgriDirect servers...',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSubtle,
                        ),
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
      style: AppTextStyles.labelSmall.copyWith(
        color: AppColors.textHeadline,
        fontWeight: FontWeight.w600,
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
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(prefixIcon, size: 20, color: AppColors.textSubtle),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

