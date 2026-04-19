import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth/auth_service.dart';
import '../services/auth/onboarding_service.dart';
import '../../mobile/mobile_navigation.dart';
import '../../mobile/screens/auth/login_screen.dart';
import '../../mobile/screens/auth/registration_screen.dart';
import '../../mobile/screens/auth/farmer_registration_screen.dart';
import '../../mobile/screens/auth/google_complete_profile_screen.dart';
import '../../mobile/screens/common/onboarding_screen.dart';
import '../../mobile/screens/common/face_capture_screen.dart';
import '../../mobile/screens/farmer/add_product_screen.dart';
import '../../mobile/screens/consumer/farmers_map_screen.dart';
import '../../mobile/screens/consumer/my_details_screen.dart';
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
import '../screens/messages/messages_screen.dart';
import '../../mobile/screens/common/loading_screen.dart';

import 'app_routes.dart';

export 'app_routes.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Creates and configures the GoRouter instance for the app.
///
/// All auth and onboarding redirect logic lives here.
/// Mobile vs web routing is decided by screen width (≤ 800 = mobile).
GoRouter createAppRouter() {
  final auth = AuthService();

  return GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: AppRoutes.home,
    refreshListenable: auth,
    redirect: (BuildContext context, GoRouterState state) async {
      final isLoggedIn = auth.isLoggedIn;
      final isAdmin = auth.isAdmin;
      final isFarmer = auth.isViewingAsFarmer;
      final location = state.matchedLocation;
      final width = MediaQuery.of(context).size.width;
      final isMobile = width <= 800;

      // Never redirect away while profile completion is actively saving.
      if (auth.isLoading && location == AppRoutes.googleCompleteProfile) {
        return null;
      }

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
          AppRoutes.resetPassword,
          AppRoutes.resetPasswordWithCode,
        ];
        if (!isLoggedIn && !mobilePublic.contains(location)) {
          return AppRoutes.login;
        }
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

      const protectedWebRoutes = <String>{
        AppRoutes.profile,
        AppRoutes.farmerDashboard,
        AppRoutes.addProduct,
        AppRoutes.myDetails,
        AppRoutes.messages,
        AppRoutes.customerMessages,
        AppRoutes.farmerMessages,
        AppRoutes.admin,
      };

      if (!isLoggedIn && protectedWebRoutes.contains(location)) {
        return AppRoutes.login;
      }

      if (location == AppRoutes.admin && !isAdmin) {
        if (!isLoggedIn) return AppRoutes.login;
        return isFarmer ? AppRoutes.farmerDashboard : AppRoutes.marketplace;
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

      // Home → welcome (landing page) or the correct dashboard
      if (location == AppRoutes.home) {
        if (!isLoggedIn) {
          if (isMobile) {
            final done = await OnboardingService.isOnboardingComplete();
            if (!done) return AppRoutes.onboarding;
          } else {
            // On web, play the loading animation before opening the welcome page.
            return AppRoutes.loading;
          }
        }
        if (isAdmin) return AppRoutes.admin;
        if (isFarmer) return AppRoutes.farmerDashboard;
        return AppRoutes.marketplace;
      }

      // Profile requires login on web
      if (location == AppRoutes.profile && !isLoggedIn) return AppRoutes.login;

      // Farmer dashboard requires login
      if (location == AppRoutes.farmerDashboard && !isLoggedIn) {
        return AppRoutes.marketplace;
      }

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

            final auth = AuthService();
            auth.switchToFarmerMode();
            return MobileNavigation(
              onLogout: () {
                AuthService().logout();
                context.go(AppRoutes.login);
              },
            );
          },
        ),
      ),

      // ── Wallet (shared) ──────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.addProduct,
        builder: (context, state) => const AddProductScreen(),
      ),
      GoRoute(
        path: AppRoutes.myDetails,
        builder: (context, state) => const MyDetailsScreen(),
      ),
      GoRoute(
        path: AppRoutes.farmersMap,
        builder: (context, state) => const FarmersMapScreen(),
      ),
      GoRoute(
        path: AppRoutes.messages,
        builder: (context, state) {
          final extra = state.extra;
          final farmerId = extra is Map<String, dynamic>
              ? extra['farmerId'] as String?
              : null;
          final conversationId = extra is Map<String, dynamic>
              ? extra['conversationId'] as String?
              : null;
          final asFarmer = extra is Map<String, dynamic>
              ? extra['asFarmer'] as bool?
              : null;

          return MessagesScreen(
            initialFarmerId: farmerId,
            initialConversationId: conversationId,
            asFarmer: asFarmer ?? (farmerId == null ? null : false),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.customerMessages,
        builder: (context, state) {
          final extra = state.extra;
          final farmerId = extra is Map<String, dynamic>
              ? extra['farmerId'] as String?
              : null;

          return MessagesScreen(initialFarmerId: farmerId, asFarmer: false);
        },
      ),
      GoRoute(
        path: AppRoutes.farmerMessages,
        builder: (context, state) => MessagesScreen(asFarmer: true),
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
      GoRoute(
        path: AppRoutes.loading,
        builder: (context, state) => LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth <= 800;
            final auth = AuthService();

            return LoadingScreen(
              onFinished: () {
                if (isMobile) {
                  context.go(AppRoutes.home);
                  return;
                }

                if (!auth.isLoggedIn) {
                  context.go(AppRoutes.webWelcome);
                  return;
                }

                if (auth.isAdmin) {
                  context.go(AppRoutes.admin);
                  return;
                }

                context.go(
                  auth.isViewingAsFarmer
                      ? AppRoutes.farmerDashboard
                      : AppRoutes.marketplace,
                );
              },
            );
          },
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
                    onLoginSuccess: () => context.go(AppRoutes.loading),
                  ),
                ),
              );
            }
            return MobileLoginScreen(
              onLoginSuccess: () => context.go(AppRoutes.loading),
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
