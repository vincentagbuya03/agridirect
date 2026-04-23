import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
GoRouter createAppRouter() {
  final auth = AuthService();

  return GoRouter(
    navigatorKey: appNavigatorKey,
    refreshListenable: auth,
    redirect: (BuildContext context, GoRouterState state) async {
      final isLoggedIn = auth.isLoggedIn;
      final isAdmin = auth.isAdmin;
      final isFarmer = auth.isViewingAsFarmer;
      final location = state.matchedLocation;
      
      // Use View.of for a more stable width check that doesn't trigger loops
      final view = View.of(context);
      final width = view.physicalSize.width / view.devicePixelRatio;
      final isMobile = width <= 800;

      debugPrint('🔀 Router Redirect: [${isMobile ? "MOBILE" : "WEB"}] location=$location isLoggedIn=$isLoggedIn admin=$isAdmin');

      // 1. ABSOLUTE PRIORITY: Admin Redirect
      if (isLoggedIn && isAdmin) {
        if (location != AppRoutes.admin &&
            location != AppRoutes.loading &&
            location != AppRoutes.webWelcome) {
          debugPrint('↪️ Router: Force routing Admin to /admin');
          return AppRoutes.admin;
        }
        return null;
      }

      // 2. Public Routes (Always accessible)
      if (location == AppRoutes.resetPassword ||
          location == AppRoutes.resetPasswordWithCode ||
          location == AppRoutes.authCallback) {
        return null;
      }

      // 3. Profile Completion Redirect
      if (auth.needsProfileCompletion &&
          location != AppRoutes.googleCompleteProfile) {
        debugPrint('↪️ Router: Redirecting to complete profile');
        return AppRoutes.googleCompleteProfile;
      }

      // 4. Authenticated Users logic
      if (isLoggedIn) {
        // Skip auth pages
        if (location == AppRoutes.login || 
            location == AppRoutes.register || 
            location == AppRoutes.webWelcome) {
          debugPrint('↪️ Router: Logged in, going to loading');
          return AppRoutes.loading;
        }
        
        // If on home/base path, go to correct dashboard
        if (location == AppRoutes.home) {
          // On mobile, the home path (/) is already the dashboard
          if (isMobile) return null;
          
          return isFarmer ? AppRoutes.farmerDashboard : AppRoutes.marketplace;
        }
      } else {
        // 5. Unauthenticated Users logic
        const protectedRoutes = {
          AppRoutes.profile,
          AppRoutes.farmerDashboard,
          AppRoutes.addProduct,
          AppRoutes.myDetails,
          AppRoutes.messages,
          AppRoutes.customerMessages,
          AppRoutes.farmerMessages,
          AppRoutes.admin,
        };

        if (protectedRoutes.contains(location)) {
          debugPrint('↪️ Router: Protected route, going to login');
          return AppRoutes.login;
        }

        // Home redirect for unauthenticated
        if (location == AppRoutes.home) {
          if (kIsWeb) {
            // For web, always show welcome screen if not logged in
            return AppRoutes.webWelcome;
          } else {
            // For native mobile apps, show onboarding then login
            final done = await OnboardingService.isOnboardingComplete();
            if (!done) return AppRoutes.onboarding;
            return AppRoutes.login;
          }
        }
      }

      // 6. Web Session Restoration Guard
      if (kIsWeb && !isLoggedIn) {
        if (isMobile && location != AppRoutes.webWelcome && location != AppRoutes.login && location != AppRoutes.onboarding) {
          debugPrint('↪️ Router: Unauthenticated web user on protected route, going to welcome');
          return AppRoutes.webWelcome;
        }
      }

      // Prevent redundant redirects if we are already where we need to be
      if (isLoggedIn && (location == AppRoutes.login || location == AppRoutes.webWelcome || location == AppRoutes.onboarding)) {
        // On mobile, the "Dashboard" is just the home route (/)
        if (isMobile) {
          debugPrint('↪️ Router: Logged in mobile user at entry page, sending to home');
          return AppRoutes.home;
        }
        
        final target = isAdmin ? AppRoutes.admin : (isFarmer ? AppRoutes.farmerDashboard : AppRoutes.marketplace);
        debugPrint('↪️ Router: Logged in web user at entry page, sending to $target');
        return target;
      }

      return null;
    },

    routes: [
      // ── Home (acts as redirect hub) ──────────────────────────────────────────
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

      // ── Web Tab Routes (Responsive: WebNavigation on desktop, MobileNavigation on phone) ──
      GoRoute(
        path: AppRoutes.marketplace,
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
              initialIndex: 1, // Marketplace tab
              onLogout: () {
                AuthService().logout();
                context.go(AppRoutes.login);
              },
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.shop,
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
              initialIndex: 1, // Shop maps to Marketplace on mobile
              onLogout: () {
                AuthService().logout();
                context.go(AppRoutes.login);
              },
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.community,
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
              initialIndex: 0, // Community maps to Home/News on mobile
              onLogout: () {
                AuthService().logout();
                context.go(AppRoutes.login);
              },
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.profile,
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
              initialIndex: 4, // Profile tab
              onLogout: () {
                AuthService().logout();
                context.go(AppRoutes.login);
              },
            );
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
                if (!auth.isLoggedIn) {
                  context.go(isMobile ? AppRoutes.onboarding : AppRoutes.webWelcome);
                  return;
                }

                if (auth.isAdmin) {
                  context.go(AppRoutes.admin);
                  return;
                }

                if (isMobile) {
                  context.go(AppRoutes.home);
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
