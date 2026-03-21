import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/router/app_router.dart';

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
    _handleAuthCallback();
  }

  Future<void> _handleAuthCallback() async {
    try {
      // Wait a moment for Supabase to process the OAuth callback
      await Future.delayed(const Duration(milliseconds: 1000));

      // Check if user is now logged in after OAuth
      final user = _auth.client.auth.currentUser;

      if (user != null) {
        // User successfully authenticated
        setState(() {
          _status = 'Login successful! Redirecting...';
        });

        // Initialize auth state
        await _auth.initialize();

        // Wait a moment before redirect
        await Future.delayed(const Duration(milliseconds: 1500));

        if (mounted) {
          // Check if new user needs profile completion
          if (_auth.needsProfileCompletion) {
            context.go(AppRoutes.googleCompleteProfile);
          } else {
            // Redirect to appropriate home page
            context.go(AppRoutes.home);
          }
        }
      } else {
        // Authentication failed
        setState(() {
          _status = 'Authentication failed. Please try again.';
          _isError = true;
        });

        // Redirect to login after a delay
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          context.go(AppRoutes.login);
        }
      }
    } catch (e) {
      setState(() {
        _status = 'An error occurred during authentication.';
        _isError = true;
      });

      // Redirect to login after a delay
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        context.go(AppRoutes.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF16A34A).withOpacity(0.1),
                    const Color(0xFF16A34A).withOpacity(0.08),
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

            // Loading indicator or error icon
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
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Color(0xFFEF4444),
                  size: 24,
                ),
              ),

            const SizedBox(height: 24),

            // Status text
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
