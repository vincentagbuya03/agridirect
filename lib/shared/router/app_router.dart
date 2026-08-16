import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../services/auth/auth_service.dart';
import '../services/auth/onboarding_service.dart';
import '../../mobile/mobile_navigation.dart';
import '../../mobile/screens/auth/login_screen.dart';
import '../../mobile/screens/auth/mfa_challenge_screen.dart';
import '../../mobile/screens/auth/registration_screen.dart';
import '../../mobile/screens/auth/farmer_registration_screen.dart';
import '../../mobile/screens/auth/complete_profile_screen.dart';
import '../../mobile/screens/common/onboarding_screen.dart';
import '../../mobile/screens/common/face_capture_screen.dart';
import '../../mobile/screens/farmer/add_product_screen.dart';
import '../../mobile/screens/farmer/farmer_followers_screen.dart';
import '../../mobile/screens/farmer/farmer_vouchers_screen.dart';
import '../../mobile/screens/consumer/claimed_vouchers_screen.dart';
import '../../mobile/screens/consumer/cart_screen.dart';
import '../../mobile/screens/consumer/product_view_screen.dart';
import '../../mobile/screens/consumer/preorder_details_screen.dart';
import '../../mobile/screens/consumer/preorder_hub_screen.dart';
import '../../mobile/screens/consumer/farmers_map_screen.dart';
import '../../mobile/screens/consumer/farmer_public_profile_screen.dart';
import '../../mobile/screens/consumer/my_details_screen.dart';
import '../../mobile/screens/profile/address_book_screen.dart';
import '../../mobile/screens/profile/favorites_screen.dart';
import '../../mobile/screens/profile/help_center_screen.dart';
import '../../mobile/screens/profile/app_settings_screen.dart';
import '../../mobile/screens/profile/change_password_screen.dart';
import '../../mobile/screens/profile/account_activity_screen.dart';
import '../../mobile/screens/profile/manage_device_screen.dart';
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
import '../../web/screens/consumer/web_find_farmer_screen.dart';
import '../../web/screens/farmer/web_farmer_preorder_details.dart';
import '../../web/screens/consumer/web_preorder_hub.dart';
import '../../web/screens/consumer/web_checkout_screen.dart';
import '../../web/screens/consumer/web_cart_checkout_screen.dart';
import '../../web/screens/consumer/web_order_success_screen.dart';
import '../../web/screens/consumer/web_consumer_weather_radar_screen.dart';
import '../../web/screens/consumer/web_free_shipping_screen.dart';
import '../../web/screens/consumer/web_flash_sale_screen.dart';
import '../../web/screens/consumer/web_vouchers_screen.dart';
import '../../web/screens/consumer/web_fresh_produce_screen.dart';
import '../../web/screens/consumer/web_wholesale_screen.dart';
import '../../web/screens/consumer/web_local_shops_screen.dart';
import '../../web/screens/common/web_articles_screen.dart';
import '../../web/screens/common/web_about_us_screen.dart';
import '../../mobile/screens/consumer/free_shipping_screen.dart';
import '../../mobile/screens/consumer/flash_sale_screen.dart';
import '../../mobile/screens/consumer/vouchers_screen.dart';
import '../../mobile/screens/consumer/fresh_produce_screen.dart';
import '../../mobile/screens/consumer/wholesale_screen.dart';
import '../../mobile/screens/consumer/local_shops_screen.dart';
import '../../web/screens/admin/admin_dashboard_redesigned.dart';
import '../../web/screens/common/web_welcome_screen.dart';
import '../screens/messages/messages_screen.dart';
import '../screens/messages/in_app_call_screen.dart';
import '../../mobile/screens/common/loading_screen.dart';
import '../../mobile/screens/common/notifications_screen.dart';
import '../../mobile/screens/consumer/orders_screen.dart';
import '../../mobile/screens/farmer/farmer_order_details_screen.dart';
import '../../mobile/screens/consumer/order_success_screen.dart';
import '../../mobile/screens/support/app_tour_screen.dart';
import '../../mobile/screens/support/faqs_screen.dart';
import '../../mobile/screens/support/contact_support_screen.dart';
import '../../mobile/screens/support/report_issue_screen.dart';
import '../../mobile/screens/support/farmer_guides_screen.dart';
import '../../mobile/screens/support/kiko_ai_chat_screen.dart';
import '../models/order/order_model.dart';
import '../services/commerce/order_service.dart';
import '../services/core/supabase_data_service.dart';
import '../screens/article_detail_screen.dart';
import '../styles/app_theme.dart';

import '../data/app_data.dart';
import 'app_routes.dart';

export 'app_routes.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Creates and configures the GoRouter instance for the app.
GoRouter createAppRouter({String? initialRoute}) {
  final auth = AuthService();

  // On web, start from the actual browser URL so deep links (e.g. /community?post=xxx)
  // are preserved instead of being redirected away on first load.
  String? initialLocation = initialRoute;
  if (kIsWeb && initialLocation == null) {
    final uri = Uri.base;
    final path = uri.path.isEmpty ? '/' : uri.path;
    final query = uri.query.isNotEmpty ? '?${uri.query}' : '';
    final candidate = '$path$query';
    // Only use it as initial location if it looks like an app route
    if (candidate != '/' && candidate.isNotEmpty) {
      initialLocation = candidate;
    }
  }

  return GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: initialLocation,
    refreshListenable: auth,
    redirect: (BuildContext context, GoRouterState state) async {
      // 0. Hold redirection until auth is initialized (restored from Supabase)
      if (!auth.isInitialized) {
        debugPrint('â³ Router: Hold redirection until auth is initialized');
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
        AppRoutes.claimedVouchers,
      };

      // Use View.of for a more stable width check that doesn't trigger loops
      final view = View.of(context);
      final width = view.physicalSize.width / view.devicePixelRatio;
      final isMobile = !kIsWeb && (width <= 800);

      // debugPrint('ðŸ”€ Router Redirect: [${isMobile ? "MOBILE" : "WEB"}] location=$location isLoggedIn=$isLoggedIn admin=$isAdmin needsProfile=${auth.needsProfileCompletion}');

      // 1. ABSOLUTE PRIORITY: Admin Redirect
      if (isLoggedIn && isAdmin) {
        if (location != AppRoutes.admin &&
            location != AppRoutes.loading &&
            location != AppRoutes.webWelcome) {
          debugPrint('â†ªï¸ Router: Force routing Admin to /admin');
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

      if (auth.requiresMfa) {
        if (location == AppRoutes.login) {
          return null;
        }
        return auth.canVerifyMfa ? AppRoutes.mfaChallenge : AppRoutes.login;
      }

      if (location == AppRoutes.mfaChallenge && !auth.canVerifyMfa) {
        return AppRoutes.login;
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
            'â†ªï¸ Router: Unauthenticated web user on protected route, going to welcome',
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
            'â†ªï¸ Router: Logged in mobile user at entry page, sending to home',
          );
          return AppRoutes.home;
        }

        final target = isAdmin
            ? AppRoutes.admin
            : (isFarmer ? AppRoutes.farmerDashboard : AppRoutes.marketplace);
        debugPrint(
          'â†ªï¸ Router: Logged in web user at entry page, sending to $target',
        );
        return target;
      }

      return null;
    },

    routes: [
      // â”€â”€ Home (acts as redirect hub) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => LayoutBuilder(
          builder: (context, constraints) {
            if (kIsWeb || constraints.maxWidth > 800) {
              final tabParam = state.uri.queryParameters['tab'];
              final tabIndex = tabParam != null
                  ? int.tryParse(tabParam) ?? 0
                  : 0;
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

      // â”€â”€ Web Tab Routes (Responsive: WebNavigation on desktop, MobileNavigation on phone) â”€â”€
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
        builder: (context, state) {
          // Preserve ?post query parameter so WebCommunityHub can deep-link to it
          final postId = state.uri.queryParameters['post'];
          return LayoutBuilder(
            builder: (context, constraints) {
              if (kIsWeb || constraints.maxWidth > 800) {
                return WebNavigation(
                  initialIndex: AuthService().isViewingAsFarmer ? 3 : 2,
                  initialPostId: postId,
                  onLogout: () async {
                    await AuthService().logout();
                    if (context.mounted) context.go(AppRoutes.login);
                  },
                );
              }
              return MobileNavigation(
                initialIndex: 0,
                initialPostId: postId,
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
        path: AppRoutes.profile,
        builder: (context, state) => LayoutBuilder(
          builder: (context, constraints) {
            if (kIsWeb || constraints.maxWidth > 800) {
              return WebNavigation(
                initialIndex: AuthService().isViewingAsFarmer ? 5 : 3,
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
        path: AppRoutes.weatherRadar,
        builder: (context, state) => const WebConsumerWeatherRadarScreen(),
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
              final tabIndex = tabParam != null
                  ? int.tryParse(tabParam) ?? 0
                  : 0;
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

          final view = View.of(context);
          final width = view.physicalSize.width / view.devicePixelRatio;
          final isMobile = (width <= 800);

          if (isMobile) {
            return FutureBuilder<Map<String, dynamic>?>(
              future: SupabaseDataService().getFarmerProfileByFarmerId(
                farmerId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('Farmer Profile')),
                    body: const Center(
                      child: Text('Farmer not found or offline.'),
                    ),
                  );
                }

                final dbProfile = snapshot.data!;
                final mappedProfile = <String, dynamic>{
                  ...dbProfile,
                  'farmerId': dbProfile['farmer_id'],
                  'farmerUserId': dbProfile['user_id'],
                  'name':
                      dbProfile['farm_name'] ??
                      dbProfile['full_name'] ??
                      'Farm',
                  'specialty': dbProfile['specialty'],
                  'location': dbProfile['location'],
                  'imageUrl': dbProfile['image_url'],
                  'avatarUrl': dbProfile['avatar_url'],
                  'badge':
                      dbProfile['badge'] ??
                      (dbProfile['is_verified'] == true ? 'VERIFIED' : null),
                  'farmingHistory': dbProfile['farming_history'],
                  'isVerified': dbProfile['is_verified'],
                  'yearsOfExperience': dbProfile['years_of_experience'],
                  'latitude': dbProfile['farm_latitude'],
                  'longitude': dbProfile['farm_longitude'],
                };

                return FarmerPublicProfileScreen(farmer: mappedProfile);
              },
            );
          }

          return WebFarmerPublicProfileScreen(farmerId: farmerId);
        },
      ),

      // â”€â”€ Wallet (shared) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
        path: AppRoutes.farmerVouchers,
        builder: (context, state) => const FarmerVouchersScreen(),
      ),
      GoRoute(
        path: AppRoutes.myDetails,
        builder: (context, state) => const MyDetailsScreen(),
      ),
      GoRoute(
        path: AppRoutes.farmersMap,
        builder: (context, state) =>
            kIsWeb ? const WebFindFarmerScreen() : const FarmersMapScreen(),
      ),
      // ── Consumer Promos & Hubs ──────────────────────────────────────────
      GoRoute(
        path: AppRoutes.freshProduce,
        builder: (context, state) => LayoutBuilder(
          builder: (context, constraints) => (kIsWeb || constraints.maxWidth > 800)
              ? const WebFreshProduceScreen()
              : const FreshProduceScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.flashSale,
        builder: (context, state) => LayoutBuilder(
          builder: (context, constraints) => (kIsWeb || constraints.maxWidth > 800)
              ? const WebFlashSaleScreen()
              : const FlashSaleScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.freeShipping,
        builder: (context, state) => LayoutBuilder(
          builder: (context, constraints) => (kIsWeb || constraints.maxWidth > 800)
              ? const WebFreeShippingScreen()
              : const FreeShippingScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.vouchers,
        builder: (context, state) => LayoutBuilder(
          builder: (context, constraints) => (kIsWeb || constraints.maxWidth > 800)
              ? const WebVouchersScreen()
              : const VouchersScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.wholesale,
        builder: (context, state) => LayoutBuilder(
          builder: (context, constraints) => (kIsWeb || constraints.maxWidth > 800)
              ? const WebWholesaleScreen()
              : const WholesaleScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.localShops,
        builder: (context, state) => LayoutBuilder(
          builder: (context, constraints) => (kIsWeb || constraints.maxWidth > 800)
              ? const WebLocalShopsScreen()
              : const LocalShopsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.articles,
        builder: (context, state) {
          final articleId = state.uri.queryParameters['id'];
          return WebArticlesScreen(initialArticleId: articleId);
        },
      ),
      GoRoute(
        path: AppRoutes.aboutUs,
        builder: (context, state) => const WebAboutUsScreen(),
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

      // â”€â”€ Web Welcome (landing page for first-time visitors) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      GoRoute(
        path: AppRoutes.webWelcome,
        builder: (context, state) => const WebWelcomeScreen(),
      ),

      // â”€â”€ Onboarding (mobile only) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                  child: CircularProgressIndicator(color: Color(0xFF16A34A)),
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

                // Do not override if user opened a specific deep link route
                final location = GoRouterState.of(context).matchedLocation;
                if (location != AppRoutes.home &&
                    location != AppRoutes.loading &&
                    location != AppRoutes.login &&
                    location != AppRoutes.onboarding) {
                  return;
                }

                context.go(AppRoutes.home);
              },
            );
          },
        ),
      ),

      // â”€â”€ Login â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

      // â”€â”€ Registration â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

      // â”€â”€ Google Complete Profile â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      GoRoute(
        path: AppRoutes.completeProfile,
        builder: (context, state) =>
            CompleteProfileScreen(onComplete: () => context.go(AppRoutes.home)),
      ),

      // â”€â”€ Farmer Registration (mobile) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      GoRoute(
        path: AppRoutes.farmerRegister,
        builder: (context, state) {
          final onComplete = state.extra as VoidCallback?;
          return FarmerRegistrationScreen(
            onRegistrationComplete: onComplete ?? () => context.pop(),
          );
        },
      ),

      // â”€â”€ Farmer Registration (web) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      GoRoute(
        path: AppRoutes.webFarmerRegister,
        builder: (context, state) {
          final onComplete = state.extra as VoidCallback?;
          return WebFarmerRegistrationScreen(
            onRegistrationComplete: onComplete ?? () => context.pop(),
          );
        },
      ),

      // â”€â”€ Face Capture â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      GoRoute(
        path: AppRoutes.faceCapture,
        builder: (context, state) => const FaceCaptureScreen(),
      ),

      // â”€â”€ Admin Dashboard â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      GoRoute(
        path: AppRoutes.admin,
        builder: (context, state) => AdminDashboardRedesigned(
          onLogout: () async {
            await AuthService().logout();
            if (context.mounted) context.go(AppRoutes.login);
          },
        ),
      ),

      // â”€â”€ Preorder Details â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
        path: AppRoutes.farmerPreorderDetail,
        builder: (context, state) {
          final product = state.extra as ProductItem;
          return WebFarmerPreorderDetails(product: product);
        },
      ),
      GoRoute(
        path: AppRoutes.productDetails,
        builder: (context, state) => LayoutBuilder(
          builder: (context, constraints) {
            final productId = state.uri.queryParameters['id'];
            final ProductItem? productFromExtra = state.extra is ProductItem
                ? state.extra as ProductItem
                : null;

            // If we have a fully populated product from navigation, use it directly
            if (productFromExtra != null && productFromExtra.name.isNotEmpty) {
              if (!kIsWeb && constraints.maxWidth <= 800) {
                return ProductViewScreen(product: productFromExtra);
              }
              return WebProductDetails(initialProduct: productFromExtra);
            }

            // Otherwise fetch by ID (deep link case)
            if (productId == null || productId.isEmpty) {
              if (!kIsWeb && constraints.maxWidth <= 800) {
                return const Scaffold(
                  body: Center(child: Text('Product not found')),
                );
              }
              return WebProductDetails(initialProduct: null);
            }

            return FutureBuilder<ProductItem?>(
              future: SupabaseDataService().getProductById(productId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                final product = snapshot.data;
                if (!kIsWeb && constraints.maxWidth <= 800) {
                  if (product == null) {
                    return Scaffold(
                      body: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.search_off_rounded,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Product not found or no longer available.',
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () =>
                                  GoRouter.of(context).go(AppRoutes.home),
                              child: const Text('Go to Marketplace'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ProductViewScreen(product: product);
                }
                return WebProductDetails(initialProduct: product);
              },
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.articleDetails,
        builder: (context, state) {
          final articleId = state.uri.queryParameters['id'];
          final articleExtra = state.extra is ArticleItem
              ? state.extra as ArticleItem
              : null;

          if (articleExtra != null) {
            return ArticleDetailScreen(article: articleExtra);
          }

          if (articleId != null && articleId.isNotEmpty) {
            return FutureBuilder<ArticleItem?>(
              future: SupabaseDataService().getArticleById(articleId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                final article = snapshot.data;
                if (article == null) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('Article')),
                    body: const Center(child: Text('Article not found.')),
                  );
                }
                return ArticleDetailScreen(article: article);
              },
            );
          }

          return Scaffold(
            appBar: AppBar(title: const Text('Article')),
            body: const Center(child: Text('Invalid article link.')),
          );
        },
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
                child: CircularProgressIndicator(color: Color(0xFF16A34A)),
              ),
            );
          }

          return WebCheckoutScreen(
            product: product,
            initialQuantity: quantity,
            isPreOrder: extra?['isPreOrder'] as bool? ?? false,
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

          final view = View.of(context);
          final width = view.physicalSize.width / view.devicePixelRatio;
          final isMobile = !kIsWeb && (width <= 800);

          if (isMobile) {
            return MobileOrderSuccessScreen(categoryName: categoryName);
          }
          return WebOrderSuccessScreen(categoryName: categoryName);
        },
      ),
      GoRoute(
        path: AppRoutes.customerOrders,
        builder: (context, state) {
          final tabStr = state.uri.queryParameters['tab'];
          final int tab = int.tryParse(tabStr ?? '0') ?? 0;
          return OrdersScreen(initialTab: tab);
        },
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
                  appBar: AppBar(title: const Text('Order Details')),
                  body: const Center(child: Text('Order not found')),
                );
              }
              return FarmerOrderDetailsScreen(order: order);
            },
          );
        },
      ),
      // â”€â”€ Web Call Page (full-screen, used when calling from web) â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
        path: AppRoutes.claimedVouchers,
        builder: (context, state) => const ClaimedVouchersScreen(),
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
      GoRoute(
        path: AppRoutes.accountActivity,
        builder: (context, state) => const AccountActivityScreen(),
      ),
      GoRoute(
        path: AppRoutes.manageDevice,
        builder: (context, state) => const ManageDeviceScreen(),
      ),
      GoRoute(
        path: AppRoutes.changePassword,
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.appTour,
        builder: (context, state) => const AppTourScreen(),
      ),
      GoRoute(
        path: AppRoutes.faqs,
        builder: (context, state) => const FaqsScreen(),
      ),
      GoRoute(
        path: AppRoutes.contactSupport,
        builder: (context, state) => const ContactSupportScreen(),
      ),
      GoRoute(
        path: AppRoutes.reportIssue,
        builder: (context, state) => const ReportIssueScreen(),
      ),
      GoRoute(
        path: AppRoutes.farmerGuides,
        builder: (context, state) => const FarmerGuidesScreen(),
      ),
      GoRoute(
        path: AppRoutes.kikoAiChat,
        builder: (context, state) => const KikoAiChatScreen(),
      ),

      // â”€â”€ Auth Callback (Google OAuth) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      GoRoute(
        path: AppRoutes.authCallback,
        builder: (context, state) => const WebAuthCallbackScreen(),
      ),

      // â”€â”€ Password Reset â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => const WebPasswordResetScreen(),
      ),

      // â”€â”€ Password Reset with Code â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      GoRoute(
        path: AppRoutes.resetPasswordWithCode,
        builder: (context, state) => const WebPasswordResetWithCodeScreen(),
      ),

      // â”€â”€ 2FA MFA Challenge â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      GoRoute(
        path: AppRoutes.mfaChallenge,
        builder: (context, state) => const MfaChallengeScreen(),
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
