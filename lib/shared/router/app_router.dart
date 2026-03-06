import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../services/onboarding_service.dart';
import '../../mobile/mobile_navigation.dart';
import '../../mobile/screens/auth/login_screen.dart';
import '../../mobile/screens/auth/registration_screen.dart';
import '../../mobile/screens/auth/farmer_registration_screen.dart';
import '../../mobile/screens/common/onboarding_screen.dart';
import '../../mobile/screens/common/face_capture_screen.dart';
import '../../web/web_navigation.dart';
import '../../web/screens/auth/web_login_screen.dart';
import '../../web/screens/auth/web_registration_screen.dart';
import '../../web/screens/auth/web_farmer_registration_screen.dart';
import '../../web/screens/consumer/web_preorder_details.dart';
import '../../web/screens/admin/admin_dashboard_redesigned.dart';

/// Route name constants for type-safe navigation
class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String onboarding = '/onboarding';
  static const String farmerRegister = '/farmer-register';
  static const String webFarmerRegister = '/web-farmer-register';
  static const String faceCapture = '/face-capture';
  static const String admin = '/admin';
  static const String preorderDetails = '/preorder-details';
}

/// Creates and configures the GoRouter instance for the app.
///
/// Handles auth redirects, onboarding flow, and adaptive layout
/// (mobile vs web) based on screen width.
GoRouter createAppRouter() {
  final auth = AuthService();

  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: auth,
    redirect: (BuildContext context, GoRouterState state) async {
      final isLoggedIn = auth.isLoggedIn;
      final isAdmin = auth.isAdmin;
      final location = state.matchedLocation;

      // Allow onboarding, login, and register routes without auth
      final publicRoutes = [
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.onboarding,
      ];
      final isPublicRoute = publicRoutes.contains(location);

      // Check screen width for mobile vs web detection
      final width = MediaQuery.of(context).size.width;
      final isMobile = width <= 800;

      // Mobile: check onboarding first
      if (isMobile && location == AppRoutes.home) {
        final onboardingComplete =
            await OnboardingService.isOnboardingComplete();
        if (!onboardingComplete) {
          return AppRoutes.onboarding;
        }
      }

      // Mobile: redirect to login if not authenticated (except public routes)
      if (isMobile && !isLoggedIn && !isPublicRoute) {
        return AppRoutes.login;
      }

      // If logged in and trying to access login/register, go home
      if (isLoggedIn && (location == AppRoutes.login || location == AppRoutes.register)) {
        return AppRoutes.home;
      }

      // Web admin redirect
      if (!isMobile && isAdmin && location == AppRoutes.home) {
        return AppRoutes.admin;
      }

      return null; // No redirect
    },
    routes: [
      // ── Main App (Adaptive: Mobile or Web) ──
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) {
          return LayoutBuilder(
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
          );
        },
      ),

      // ── Onboarding (Mobile only) ──
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => OnboardingScreen(
          onOnboardingComplete: () => context.go(AppRoutes.home),
        ),
      ),

      // ── Login ──
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) {
          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                // Web: login as a full page
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
          );
        },
      ),

      // ── Registration ──
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) {
          return LayoutBuilder(
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
          );
        },
      ),

      // ── Farmer Registration (Mobile) ──
      GoRoute(
        path: AppRoutes.farmerRegister,
        builder: (context, state) {
          final onComplete = state.extra as VoidCallback?;
          return FarmerRegistrationScreen(
            onRegistrationComplete: onComplete ?? () => context.pop(),
          );
        },
      ),

      // ── Farmer Registration (Web) ──
      GoRoute(
        path: AppRoutes.webFarmerRegister,
        builder: (context, state) {
          final onComplete = state.extra as VoidCallback?;
          return WebFarmerRegistrationScreen(
            onRegistrationComplete: onComplete ?? () => context.pop(),
          );
        },
      ),

      // ── Face Capture ──
      GoRoute(
        path: AppRoutes.faceCapture,
        builder: (context, state) => const FaceCaptureScreen(),
      ),

      // ── Admin Dashboard ──
      GoRoute(
        path: AppRoutes.admin,
        builder: (context, state) => AdminDashboardRedesigned(
          onLogout: () {
            AuthService().logout();
            context.go(AppRoutes.home);
          },
        ),
      ),

      // ── Preorder Details ──
      GoRoute(
        path: AppRoutes.preorderDetails,
        builder: (context, state) => const WebPreorderDetails(),
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
