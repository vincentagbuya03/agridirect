import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../services/onboarding_service.dart';
import '../screens/wallet_screen.dart';
import '../../mobile/mobile_navigation.dart';
import '../../mobile/screens/auth/login_screen.dart';
import '../../mobile/screens/auth/registration_screen.dart';
import '../../mobile/screens/auth/farmer_registration_screen.dart';
import '../../mobile/screens/auth/google_complete_profile_screen.dart';
import '../../mobile/screens/common/onboarding_screen.dart';
import '../../mobile/screens/common/face_capture_screen.dart';
import '../../web/web_navigation.dart';
import '../../web/screens/auth/web_login_screen.dart';
import '../../web/screens/auth/web_registration_screen.dart';
import '../../web/screens/auth/web_farmer_registration_screen.dart';
import '../../web/screens/auth/web_auth_callback_screen.dart';
import '../../web/screens/auth/web_password_reset_screen.dart';
import '../../web/screens/auth/web_password_reset_with_code_screen.dart';
import '../../web/screens/consumer/web_preorder_details.dart';
import '../../web/screens/admin/admin_dashboard_redesigned.dart';
import '../../web/screens/common/web_welcome_screen.dart';

/// Route name constants for type-safe navigation.
class AppRoutes {
  // ── Shared ──
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String onboarding = '/onboarding';
  static const String faceCapture = '/face-capture';
  static const String admin = '/admin';
  static const String preorderDetails = '/preorder-details';
  static const String authCallback = '/auth/callback';
  static const String resetPassword = '/reset-password';
  static const String resetPasswordWithCode = '/reset-password-code';
  static const String wallet = '/wallet';

  // ── Mobile-specific ──
  static const String farmerRegister = '/farmer-register';
  static const String googleCompleteProfile = '/google-complete-profile';

  // ── Web-specific ──
  static const String webWelcome = '/web-welcome';
  static const String marketplace = '/marketplace'; // consumer home / index 0
  static const String shop = '/shop'; // index 1
  static const String community = '/community'; // index 2
  static const String profile = '/profile'; // index 3 (auth required)
  static const String farmerDashboard =
      '/farmer-dashboard'; // farmer home / index 0
  static const String webFarmerRegister = '/web-farmer-register';

  // ── Web tab helpers ──

  /// Converts a route path to the active tab index used by web screens.
  static int webTabIndex(String location) {
    if (location.startsWith(shop)) return 1;
    if (location.startsWith(community)) return 2;
    if (location.startsWith(profile)) return 3;
    return 0; // marketplace / farmerDashboard / home all → 0
  }

  /// Converts a tab index back to the appropriate route path.
  static String webTabRoute(int index, {bool isFarmer = false}) {
    switch (index) {
      case 1:
        return shop;
      case 2:
        return community;
      case 3:
        return profile;
      default:
        return isFarmer ? farmerDashboard : marketplace;
    }
  }
}

/// Creates and configures the GoRouter instance for the app.
///
/// All auth and onboarding redirect logic lives here.
/// Mobile vs web routing is decided by screen width (≤ 800 = mobile).
GoRouter createAppRouter() {
  final auth = AuthService();

  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: auth,
    redirect: (BuildContext context, GoRouterState state) async {
      final isLoggedIn = auth.isLoggedIn;
      final isAdmin = auth.isAdmin;
      final isFarmer = auth.isViewingAsFarmer;
      final location = state.matchedLocation;
      final width = MediaQuery.of(context).size.width;
      final isMobile = width <= 800;

      // ── Mobile redirect logic ──────────────────────────────────────────────
      if (isMobile) {
        // ⚠️ NEW: If user needs profile completion, redirect them there!
        if (auth.needsProfileCompletion &&
            location != AppRoutes.googleCompleteProfile) {
          return AppRoutes.googleCompleteProfile;
        }

        // If on profile completion screen but don't need it, redirect to home/login
        if (location == AppRoutes.googleCompleteProfile &&
            !auth.needsProfileCompletion) {
          return isLoggedIn ? AppRoutes.home : AppRoutes.login;
        }

        // First-time launch → onboarding
        if (location == AppRoutes.home) {
          final done = await OnboardingService.isOnboardingComplete();
          if (!done) return AppRoutes.onboarding;
        }
        const mobilePublic = [
          AppRoutes.login,
          AppRoutes.register,
          AppRoutes.onboarding,
          AppRoutes.faceCapture,
          AppRoutes.googleCompleteProfile,
        ];
        if (!isLoggedIn && !mobilePublic.contains(location))
          return AppRoutes.login;
        if (isLoggedIn &&
            (location == AppRoutes.login || location == AppRoutes.register)) {
          return AppRoutes.home;
        }
        return null;
      }

      // ── Web redirect logic ─────────────────────────────────────────────────

      // Allow password reset without auth
      if (location == AppRoutes.resetPassword ||
          location == AppRoutes.resetPasswordWithCode) {
        return null;
      }

      // ⚠️ NEW: If user needs profile completion (mobile or web), redirect them there!
      if (auth.needsProfileCompletion &&
          location != AppRoutes.googleCompleteProfile) {
        return AppRoutes.googleCompleteProfile;
      }

      // If on profile completion screen but don't need it, redirect to home/login
      if (location == AppRoutes.googleCompleteProfile &&
          !auth.needsProfileCompletion) {
        return isLoggedIn ? AppRoutes.home : AppRoutes.login;
      }

      // Admin always goes to /admin
      if (isAdmin && location == AppRoutes.home) return AppRoutes.admin;

      // Home → welcome (first visit) or the correct tab home
      if (location == AppRoutes.home) {
        if (!isLoggedIn) {
          final done = await OnboardingService.isOnboardingComplete();
          if (!done) return AppRoutes.webWelcome;
        }
        if (isAdmin) return AppRoutes.admin;
        if (isFarmer) return AppRoutes.farmerDashboard;
        return AppRoutes.marketplace;
      }

      // Profile requires login on web
      if (location == AppRoutes.profile && !isLoggedIn) return AppRoutes.login;

      // Wallet requires login on web
      if (location == AppRoutes.wallet && !isLoggedIn) return AppRoutes.login;

      // Farmer dashboard requires login
      if (location == AppRoutes.farmerDashboard && !isLoggedIn)
        return AppRoutes.marketplace;

      // Logged-in users skip login/register pages
      if (isLoggedIn &&
          (location == AppRoutes.login || location == AppRoutes.register)) {
        if (isAdmin) return AppRoutes.admin;
        return isFarmer ? AppRoutes.farmerDashboard : AppRoutes.marketplace;
      }

      return null;
    },

    routes: [
      // ── Home (acts as redirect hub) ───────────────────────────────────────
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 800) {
              return WebNavigation(
                onLogout: () {
                  AuthService().logout();
                  context.go(AppRoutes.home);
                },
              );
            }
            return MobileNavigation(
              onLogout: () {
                AuthService().logout();
                context.go(AppRoutes.login);
              },
            );
          },
        ),
      ),

      // ── Web Tab Routes (all render WebNavigation; tab derived from path) ──
      GoRoute(
        path: AppRoutes.marketplace,
        builder: (context, state) => WebNavigation(
          onLogout: () {
            AuthService().logout();
            context.go(AppRoutes.home);
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.shop,
        builder: (context, state) => WebNavigation(
          onLogout: () {
            AuthService().logout();
            context.go(AppRoutes.home);
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.community,
        builder: (context, state) => WebNavigation(
          onLogout: () {
            AuthService().logout();
            context.go(AppRoutes.home);
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => WebNavigation(
          onLogout: () {
            AuthService().logout();
            context.go(AppRoutes.home);
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.farmerDashboard,
        builder: (context, state) => WebNavigation(
          onLogout: () {
            AuthService().logout();
            context.go(AppRoutes.home);
          },
        ),
      ),

      // ── Wallet (shared) ──────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.wallet,
        builder: (context, state) => const WalletScreen(),
      ),

      // ── Web Welcome (landing page for first-time visitors) ────────────────
      GoRoute(
        path: AppRoutes.webWelcome,
        builder: (context, state) => const WebWelcomeScreen(),
      ),

      // ── Onboarding (mobile only) ──────────────────────────────────────────
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => OnboardingScreen(
          onOnboardingComplete: () => context.go(AppRoutes.home),
        ),
      ),

      // ── Login ─────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 800) {
              return Scaffold(
                body: Center(
                  child: WebLoginScreen(
                    onLoginSuccess: () => context.go(AppRoutes.home),
                  ),
                ),
              );
            }
            return MobileLoginScreen(
              onLoginSuccess: () => context.go(AppRoutes.home),
            );
          },
        ),
      ),

      // ── Registration ──────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 800) {
              return Scaffold(
                body: Center(
                  child: WebRegistrationScreen(
                    onRegistrationSuccess: () => context.go(AppRoutes.login),
                  ),
                ),
              );
            }
            return RegistrationScreen(
              onRegistrationSuccess: () => context.go(AppRoutes.login),
            );
          },
        ),
      ),

      // ── Google Complete Profile ───────────────────────────────────────────
      GoRoute(
        path: AppRoutes.googleCompleteProfile,
        builder: (context, state) => GoogleCompleteProfileScreen(
          onComplete: () => context.go(AppRoutes.home),
        ),
      ),

      // ── Farmer Registration (mobile) ──────────────────────────────────────
      GoRoute(
        path: AppRoutes.farmerRegister,
        builder: (context, state) {
          final onComplete = state.extra as VoidCallback?;
          return FarmerRegistrationScreen(
            onRegistrationComplete: onComplete ?? () => context.pop(),
          );
        },
      ),

      // ── Farmer Registration (web) ─────────────────────────────────────────
      GoRoute(
        path: AppRoutes.webFarmerRegister,
        builder: (context, state) {
          final onComplete = state.extra as VoidCallback?;
          return WebFarmerRegistrationScreen(
            onRegistrationComplete: onComplete ?? () => context.pop(),
          );
        },
      ),

      // ── Face Capture ──────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.faceCapture,
        builder: (context, state) => const FaceCaptureScreen(),
      ),

      // ── Admin Dashboard ───────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.admin,
        builder: (context, state) => AdminDashboardRedesigned(
          onLogout: () {
            AuthService().logout();
            context.go(AppRoutes.home);
          },
        ),
      ),

      // ── Preorder Details ──────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.preorderDetails,
        builder: (context, state) => const WebPreorderDetails(),
      ),

      // ── Auth Callback (Google OAuth) ──────────────────────────────────────
      GoRoute(
        path: AppRoutes.authCallback,
        builder: (context, state) => const WebAuthCallbackScreen(),
      ),

      // ── Password Reset ────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => const WebPasswordResetScreen(),
      ),

      // ── Password Reset with Code ──────────────────────────────────────────
      GoRoute(
        path: AppRoutes.resetPasswordWithCode,
        builder: (context, state) => const WebPasswordResetWithCodeScreen(),
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('No route found for: ${state.uri}'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
}
