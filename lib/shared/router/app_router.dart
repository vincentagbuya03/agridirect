import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../services/auth/auth_service.dart';
import '../services/auth/onboarding_service.dart';
import '../../mobile/mobile_navigation.dart';
import '../../mobile/screens/auth/login_screen.dart';
import '../../mobile/screens/auth/registration_screen.dart';
import '../../mobile/screens/auth/farmer_registration_screen.dart';
import '../../mobile/screens/auth/complete_profile_screen.dart';
import '../../mobile/screens/common/onboarding_screen.dart';
import '../../mobile/screens/common/face_capture_screen.dart';
import '../../mobile/screens/farmer/add_product_screen.dart';
import '../../mobile/screens/farmer/farmer_followers_screen.dart';
import '../../mobile/screens/consumer/cart_screen.dart';
import '../../mobile/screens/consumer/marketplace_screen.dart';
import '../../mobile/screens/consumer/preorder_details_screen.dart';
import '../../mobile/screens/consumer/preorder_hub_screen.dart';
import '../../mobile/screens/consumer/farmers_map_screen.dart';
import '../../mobile/screens/consumer/my_details_screen.dart';
import '../../mobile/screens/profile/address_book_screen.dart';
import '../../mobile/screens/profile/favorites_screen.dart';
import '../../mobile/screens/profile/help_center_screen.dart';
import '../../mobile/screens/profile/app_settings_screen.dart';
import '../../web/web_navigation.dart';
import '../../web/screens/auth/web_login_screen.dart';
import '../../web/screens/auth/web_registration_screen.dart';
import '../../web/screens/auth/web_farmer_registration_screen.dart';
import '../../web/screens/auth/web_auth_callback_screen.dart';
import '../../web/screens/auth/web_password_reset_screen.dart';
import '../../web/screens/auth/web_password_reset_with_code_screen.dart';
import '../../web/screens/consumer/web_cart_screen.dart';
import '../../web/screens/consumer/web_farmer_public_profile_screen.dart';
import '../../web/screens/consumer/web_preorder_details.dart';
import '../../web/screens/consumer/web_product_details.dart';
import '../../web/screens/consumer/web_preorder_hub.dart';
import '../../web/screens/consumer/web_checkout_screen.dart';
import '../../web/screens/consumer/web_cart_checkout_screen.dart';
import '../../web/screens/consumer/web_order_success_screen.dart';
import '../../web/screens/admin/admin_dashboard_redesigned.dart';
import '../../web/screens/common/web_welcome_screen.dart';
import '../screens/messages/messages_screen.dart';
import '../screens/messages/in_app_call_screen.dart';
import '../../mobile/screens/common/loading_screen.dart';
import '../../mobile/screens/common/notifications_screen.dart';
import '../../mobile/screens/consumer/orders_screen.dart';
import '../../mobile/screens/farmer/farmer_order_details_screen.dart';
import '../models/order/order_model.dart';
import '../services/commerce/order_service.dart';
import '../styles/app_theme.dart';

import '../data/app_data.dart';
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
      // 0. Hold redirection until auth is initialized (restored from Supabase)
      if (!auth.isInitialized) {
        debugPrint('⏳ Router: Hold redirection until auth is initialized');
        return null;
      }

      final isLoggedIn = auth.isLoggedIn;
      final isAdmin = auth.isAdmin;
      final isFarmer = auth.isViewingAsFarmer;
      final location = state.matchedLocation;

      const protectedRoutes = {
        AppRoutes.profile,
        AppRoutes.farmerDashboard,
        AppRoutes.addProduct,
        AppRoutes.myDetails,
        AppRoutes.messages,
        AppRoutes.customerMessages,
        AppRoutes.farmerMessages,
        AppRoutes.addressBook,
        AppRoutes.favorites,
        AppRoutes.farmerFollowers,
        AppRoutes.helpCenter,
        AppRoutes.appSettings,
        AppRoutes.admin,
        AppRoutes.completeProfile,
        AppRoutes.checkout,
        AppRoutes.cartCheckout,
        AppRoutes.orderSuccess,
        AppRoutes.customerOrders,
      };

      // Use View.of for a more stable width check that doesn't trigger loops
      final view = View.of(context);
      final width = view.physicalSize.width / view.devicePixelRatio;
      final isMobile = !kIsWeb && (width <= 800);

      // debugPrint('🔀 Router Redirect: [${isMobile ? "MOBILE" : "WEB"}] location=$location isLoggedIn=$isLoggedIn admin=$isAdmin needsProfile=${auth.needsProfileCompletion}');

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

      // 3. Authenticated Users logic
      if (isLoggedIn) {
        // Allow unverified users to stay on login or register
        if (!auth.isEmailVerified &&
            location != AppRoutes.login &&
            location != AppRoutes.register) {
          return AppRoutes.login;
        }

        // 4. Profile Completion Redirect
        if (auth.needsProfileCompletion &&
            location != AppRoutes.completeProfile) {
          return AppRoutes.completeProfile;
        }

        // Skip auth pages
        if (location == AppRoutes.login ||
            location == AppRoutes.register ||
            location == AppRoutes.webWelcome) {
          if (!auth.isEmailVerified) {
            return null; // Stay on login or register to allow fresh start or resume
          }
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
        if (protectedRoutes.contains(location)) {
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
            if (done) return AppRoutes.login;
            return AppRoutes.onboarding;
          }
        }
      }

      // 6. Web Session Restoration Guard
      if (kIsWeb && !isLoggedIn) {
        if (protectedRoutes.contains(location)) {
          debugPrint(
            '↪️ Router: Unauthenticated web user on protected route, going to welcome',
          );
          return AppRoutes.webWelcome;
        }
      }

      // Prevent redundant redirects if we are already where we need to be
      if (isLoggedIn &&
          (location == AppRoutes.login ||
              location == AppRoutes.webWelcome ||
              location == AppRoutes.onboarding)) {
        // On mobile, the "Dashboard" is just the home route (/)
        if (isMobile) {
          debugPrint(
            '↪️ Router: Logged in mobile user at entry page, sending to home',
          );
          return AppRoutes.home;
        }

        final target = isAdmin
            ? AppRoutes.admin
            : (isFarmer ? AppRoutes.farmerDashboard : AppRoutes.marketplace);
        debugPrint(
          '↪️ Router: Logged in web user at entry page, sending to $target',
        );
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
            if (kIsWeb || constraints.maxWidth > 800) {
              final tabParam = state.uri.queryParameters['tab'];
              final tabIndex = tabParam != null ? int.tryParse(tabParam) ?? 0 : 0;
              return WebNavigation(
                initialIndex: tabIndex,
                onLogout: () async {
                  await AuthService().logout();
                  if (context.mounted) context.go(AppRoutes.login);
                },
              );
            }
            return MobileNavigation(
              onLogout: () async {
                await AuthService().logout();
                if (context.mounted) context.go(AppRoutes.login);
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
            if (kIsWeb || constraints.maxWidth > 800) {
              return WebNavigation(
                initialIndex: 0,
                onLogout: () async {
                  await AuthService().logout();
                  if (context.mounted) context.go(AppRoutes.login);
                },
              );
            }
            return MobileNavigation(
              initialIndex: 1, // Marketplace tab
              onLogout: () async {
                await AuthService().logout();
                if (context.mounted) context.go(AppRoutes.login);
              },
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.shop,
        builder: (context, state) {
          final showPreOrders =
              state.uri.queryParameters['mode'] == 'preorders';
          return LayoutBuilder(
          builder: (context, constraints) {
            if (kIsWeb || constraints.maxWidth > 800) {
              return WebNavigation(
                initialIndex: 1,
                showPreOrdersInShop: showPreOrders,
                onLogout: () async {
                  await AuthService().logout();
                  if (context.mounted) context.go(AppRoutes.login);
                },
              );
            }
            return MobileNavigation(
              initialIndex: 1, // Shop maps to Marketplace on mobile
              onLogout: () async {
                await AuthService().logout();
                if (context.mounted) context.go(AppRoutes.login);
              },
            );
          },
        );
        },
      ),
      GoRoute(
        path: AppRoutes.community,
        builder: (context, state) => LayoutBuilder(
          builder: (context, constraints) {
            if (kIsWeb || constraints.maxWidth > 800) {
              return WebNavigation(
                initialIndex: AuthService().isViewingAsFarmer ? 3 : 2,
                onLogout: () async {
                  await AuthService().logout();
                  if (context.mounted) context.go(AppRoutes.login);
                },
              );
            }
            return MobileNavigation(
              initialIndex: 0, // Community maps to Home/News on mobile
              onLogout: () async {
                await AuthService().logout();
                if (context.mounted) context.go(AppRoutes.login);
              },
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => LayoutBuilder(
          builder: (context, constraints) {
            if (kIsWeb || constraints.maxWidth > 800) {
              return WebNavigation(
                initialIndex: AuthService().isViewingAsFarmer ? 4 : 3,
                onLogout: () async {
                  await AuthService().logout();
                  if (context.mounted) context.go(AppRoutes.login);
                },
              );
            }
            return MobileNavigation(
              initialIndex: 4, // Profile tab
              onLogout: () async {
                await AuthService().logout();
                if (context.mounted) context.go(AppRoutes.login);
              },
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.cart,
        builder: (context, state) => LayoutBuilder(
          builder: (context, constraints) {
            if (kIsWeb || constraints.maxWidth > 800) {
              return const WebCartScreen();
            }
            return const CartScreen();
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.preorders,
        builder: (context, state) => LayoutBuilder(
          builder: (context, constraints) {
            if (kIsWeb || constraints.maxWidth > 800) {
              return WebPreOrderHub(
                currentIndex: 1,
                onNavigate: (index) => context.go(AppRoutes.webTabRoute(index)),
              );
            }
            return const PreOrderHubScreen();
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.farmerDashboard,
        builder: (context, state) => LayoutBuilder(
          builder: (context, constraints) {
            if (kIsWeb || constraints.maxWidth > 800) {
              final tabParam = state.uri.queryParameters['tab'];
              final tabIndex = tabParam != null ? int.tryParse(tabParam) ?? 0 : 0;
              return WebNavigation(
                initialIndex: tabIndex,
                onLogout: () async {
                  await AuthService().logout();
                  if (context.mounted) context.go(AppRoutes.login);
                },
              );
            }

            return MobileNavigation(
              onLogout: () async {
                await AuthService().logout();
                if (context.mounted) context.go(AppRoutes.login);
              },
            );
          },
        ),
      ),
      GoRoute(
        path: '${AppRoutes.farmerProfileBase}/:farmerId',
        builder: (context, state) {
          final farmerId = state.pathParameters['farmerId'] ?? '';
          return WebFarmerPublicProfileScreen(farmerId: farmerId);
        },
      ),

      // ── Wallet (shared) ──────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.addProduct,
        builder: (context, state) => const AddProductScreen(),
      ),
      GoRoute(
        path: AppRoutes.editProduct,
        builder: (context, state) {
          final productMap = state.extra as Map<String, dynamic>?;
          return AddProductScreen(editProduct: productMap);
        },
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
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsScreen(),
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
          final product = extra is Map<String, dynamic>
              ? extra['product'] as ProductItem?
              : null;

          return MessagesScreen(
            initialFarmerId: farmerId,
            asFarmer: false,
            initialProduct: product,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.farmerMessages,
        builder: (context, state) {
          final extra = state.extra;
          final customerId = extra is Map<String, dynamic>
              ? extra['customerId'] as String?
              : null;

          return MessagesScreen(asFarmer: true, initialCustomerId: customerId);
        },
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
            final isMobile = !kIsWeb && (constraints.maxWidth <= 800);
            final auth = AuthService();

            if (!isMobile) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
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
              });
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF16A34A),
                  ),
                ),
              );
            }

            return LoadingScreen(
              onFinished: () {
                if (!auth.isLoggedIn) {
                  context.go(AppRoutes.onboarding);
                  return;
                }

                if (auth.isAdmin) {
                  context.go(AppRoutes.admin);
                  return;
                }

                context.go(AppRoutes.home);
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
            if (kIsWeb || constraints.maxWidth > 800) {
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
            if (kIsWeb || constraints.maxWidth > 800) {
              return Scaffold(
                body: Center(
                  child: WebRegistrationScreen(
                    onRegistrationSuccess: () => context.go(AppRoutes.loading),
                  ),
                ),
              );
            }
            return RegistrationScreen(
              onRegistrationSuccess: () => context.go(AppRoutes.loading),
            );
          },
        ),
      ),

      // ── Google Complete Profile ───────────────────────────────────────────
      GoRoute(
        path: AppRoutes.completeProfile,
        builder: (context, state) =>
            CompleteProfileScreen(onComplete: () => context.go(AppRoutes.home)),
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
          onLogout: () async {
            await AuthService().logout();
            if (context.mounted) context.go(AppRoutes.login);
          },
        ),
      ),

      // ── Preorder Details ──────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.preorderDetails,
        builder: (context, state) => LayoutBuilder(
          builder: (context, constraints) {
            final product = state.extra is ProductItem
                ? state.extra as ProductItem
                : null;

            if (!kIsWeb && constraints.maxWidth <= 800) {
              return PreOrderDetailsScreen(initialProduct: product);
            }

            return WebPreorderDetails(initialProduct: product);
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.productDetails,
        builder: (context, state) => LayoutBuilder(
          builder: (context, constraints) {
            final product = state.extra is ProductItem
                ? state.extra as ProductItem
                : null;

            if (!kIsWeb && constraints.maxWidth <= 800) {
              if (product == null) {
                return const Scaffold(
                  body: Center(child: Text('Product not found')),
                );
              }
              return ProductViewScreen(product: product);
            }

            return WebProductDetails(initialProduct: product);
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.checkout,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final product = extra?['product'] as ProductItem?;
          final quantity = extra?['quantity'] as int? ?? 1;

          if (product == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go(AppRoutes.shop);
            });
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF16A34A),
                ),
              ),
            );
          }

          return WebCheckoutScreen(
            product: product,
            initialQuantity: quantity,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.cartCheckout,
        builder: (context, state) => const WebCartCheckoutScreen(),
      ),
      GoRoute(
        path: AppRoutes.orderSuccess,
        builder: (context, state) {
          final categoryName = state.extra as String?;
          return WebOrderSuccessScreen(categoryName: categoryName);
        },
      ),
      GoRoute(
        path: AppRoutes.customerOrders,
        builder: (context, state) => const OrdersScreen(),
      ),
      GoRoute(
        path: '/orders/:orderId',
        builder: (context, state) {
          final orderId = state.pathParameters['orderId'] ?? '';
          return OrdersScreen(initialOrderId: orderId);
        },
      ),
      GoRoute(
        path: '/farmer/orders/:orderId',
        builder: (context, state) {
          final orderId = state.pathParameters['orderId'] ?? '';
          return FutureBuilder<Order?>(
            future: OrderService().getOrderById(orderId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }
              final order = snapshot.data;
              if (order == null) {
                return Scaffold(
                  appBar: AppBar(
                    title: const Text('Order Details'),
                  ),
                  body: const Center(
                    child: Text('Order not found'),
                  ),
                );
              }
              return FarmerOrderDetailsScreen(order: order);
            },
          );
        },
      ),
      // ── Web Call Page (full-screen, used when calling from web) ─────────
      GoRoute(
        path: '/call/:callId',
        builder: (context, state) {
          final callId = state.pathParameters['callId'] ?? '';
          final extra = state.extra as Map<String, dynamic>?;
          return InAppCallScreen(
            name: extra?['name'] as String? ?? 'Unknown',
            avatarUrl: extra?['avatarUrl'] as String?,
            callId: callId,
            channelName: extra?['channelName'] as String? ?? '',
            isVideo: extra?['isVideo'] as bool? ?? false,
            isIncoming: extra?['isIncoming'] as bool? ?? false,
            isAlreadyAccepted: extra?['isAlreadyAccepted'] as bool? ?? false,
            isRoute: true,
          );
        },
      ),

      GoRoute(
        path: AppRoutes.addressBook,
        builder: (context, state) => const AddressBookScreen(),
      ),
      GoRoute(
        path: AppRoutes.favorites,
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        path: AppRoutes.farmerFollowers,
        builder: (context, state) => const FarmerFollowersScreen(),
      ),
      GoRoute(
        path: AppRoutes.helpCenter,
        builder: (context, state) => const HelpCenterScreen(),
      ),
      GoRoute(
        path: AppRoutes.appSettings,
        builder: (context, state) => const AppSettingsScreen(),
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
