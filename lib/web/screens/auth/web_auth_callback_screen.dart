import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/router/app_router.dart';
import '../../../shared/services/auth/auth_service.dart';

/// Web OAuth callback handler screen.
/// This screen is shown after Google OAuth redirect and handles the authentication result.
class WebAuthCallbackScreen extends StatefulWidget {
  const WebAuthCallbackScreen({super.key});

  @override
  State<WebAuthCallbackScreen> createState() => _WebAuthCallbackScreenState();
}

class _WebAuthCallbackScreenState extends State<WebAuthCallbackScreen> {
  final AuthService _auth = AuthService();
  String _status = 'Processing login...';
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    debugPrint('WebAuthCallbackScreen: initState triggered');
    _handleAuthCallback();
  }

  Future<void> _handleAuthCallback() async {
    try {
      final code = Uri.base.queryParameters['code'];
      debugPrint('WebAuthCallbackScreen: Detected OAuth code in URL: ${code != null}');
      
      // The PKCE code exchange should already be done by main.dart during bootstrap.
      // As a fallback, try exchanging if currentUser is still null.
      if (_auth.client.auth.currentUser == null) {
        if (code != null && code.isNotEmpty) {
          try {
            debugPrint('OAuth callback: Fallback code exchange starting...');
            await _auth.client.auth.exchangeCodeForSession(code);
            debugPrint('OAuth callback: Fallback exchange complete!');
          } catch (e) {
            debugPrint('OAuth callback fallback exchange error: $e');
          }
        } else {
          debugPrint('OAuth callback: No code found in URL and currentUser is null');
        }
      } else {
        debugPrint('OAuth callback: currentUser is already logged in: ${_auth.client.auth.currentUser?.email}');
      }

      final user = await _waitForAuthenticatedUser();

      if (user == null) {
        debugPrint('OAuth callback: Failed to resolve authenticated user (timeout)');
        setState(() {
          _status =
              'Authentication timed out. Please try again from the login page.';
          _isError = true;
        });

        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          context.go(AppRoutes.login);
        }
        return;
      }

      // Ensure AuthService is fully initialized with the new session
      debugPrint('OAuth callback: Initializing AuthService for user ${user.email}...');
      await _auth.initialize(event: AuthChangeEvent.signedIn);

      setState(() {
        _status = 'Login successful! Redirecting...';
      });

      debugPrint('OAuth successful for email: ${user.email}');

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      debugPrint('OAuth callback: Redirecting to loading route...');
      context.go(AppRoutes.loading);
    } catch (e) {
      debugPrint('OAuth callback error: $e');
      setState(() {
        _status = 'An error occurred during authentication.';
        _isError = true;
      });

      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        context.go(AppRoutes.login);
      }
    }
  }

  Future<User?> _waitForAuthenticatedUser() async {
    final currentUser = _auth.client.auth.currentUser;
    if (currentUser != null) return currentUser;

    for (var attempt = 0; attempt < 20; attempt++) {
      await Future.delayed(const Duration(milliseconds: 400));
      final user = _auth.client.auth.currentUser;
      if (user != null) return user;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('WebAuthCallbackScreen: build() - Status: $_status, Error: $_isError');
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF16A34A).withValues(alpha: 0.1),
                    const Color(0xFF16A34A).withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.eco_rounded,
                color: Color(0xFF16A34A),
                size: 32,
              ),
            ),
            const SizedBox(height: 24),
            if (!_isError)
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF16A34A)),
                ),
              )
            else
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Color(0xFFEF4444),
                  size: 24,
                ),
              ),
            const SizedBox(height: 24),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _isError
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            if (!_isError)
              Text(
                'Please wait while we complete your authentication...',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF6B7280),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
