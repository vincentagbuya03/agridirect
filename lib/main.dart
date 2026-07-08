import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'shared/styles/app_theme.dart';

import 'firebase_options.dart';
import 'shared/services/auth/auth_service.dart';
import 'shared/services/community/analytics_service.dart';
import 'shared/services/core/supabase_config.dart';
import 'shared/services/core/bootstrap_cache_service.dart';
import 'shared/services/core/database_sync_service.dart';
import 'shared/services/commerce/product_service.dart';
import 'shared/services/offline/offline_product_service.dart';
import 'shared/services/offline/offline_queue_service.dart';
import 'shared/services/community/notification_service.dart';
import 'shared/router/app_router.dart';
import 'shared/services/offline/offline_cache_service.dart';
import 'shared/utils/url_strategy.dart';
import 'mobile/screens/common/loading_screen.dart';
import 'shared/screens/messages/in_app_call_screen.dart';

// Handle background notifications
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Handling background message: ${message.messageId}');

  final data = message.data;
  final linkType = data['link_type']?.toString() ?? '';

  if (linkType == 'call') {
    try {
      final isVideo = data['is_video'] == 'true';
      final callerName = data['caller_name']?.toString() ?? 'AgriDirect User';
      final channelName = data['channel_name']?.toString() ?? '';
      // call_id is sent in both link_id and call_id fields - try both
      final callId = (data['call_id']?.toString() ?? data['link_id']?.toString() ?? '').trim();

      if (callId.isEmpty || channelName.isEmpty) {
        debugPrint('⚠️ Background call: missing callId or channelName, skipping CallKit.');
        return;
      }

      final callKitParams = CallKitParams(
        id: callId,
        nameCaller: callerName,
        appName: 'AgriDirect',
        isAccepted: false,
        handle: 'Incoming Call',
        type: isVideo ? 1 : 0,
        duration: 30000, // Ring for 30 seconds before auto-missing
        missedCallNotification: const NotificationParams(
          showNotification: true,
          isShowCallback: true,
          subtitle: 'Missed call',
          callbackText: 'Call back',
        ),
        extra: <String, dynamic>{
          'callId': callId,
          'channelName': channelName,
          'isVideo': isVideo,
        },
        android: const AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          ringtonePath: 'system_ringtone_default',
          backgroundColor: '#0955fa',
          actionColor: '#4CAF50',
          textColor: '#ffffff',
          incomingCallNotificationChannelName: "Incoming Call",
          missedCallNotificationChannelName: "Missed Call",
          isShowCallID: false,
          textAccept: 'Accept',
          textDecline: 'Decline',
        ),
        ios: const IOSParams(
          iconName: 'CallKitLogo',
          handleType: '',
          supportsVideo: true,
          maximumCallGroups: 2,
          maximumCallsPerCallGroup: 1,
          audioSessionMode: 'default',
          audioSessionActive: true,
          audioSessionPreferredSampleRate: 44100.0,
          audioSessionPreferredIOBufferDuration: 0.005,
          supportsDTMF: true,
          supportsHolding: true,
          supportsGrouping: false,
          supportsUngrouping: false,
          ringtonePath: 'system_ringtone_default',
        ),
      );

      debugPrint('📞 Background: Showing CallKit for call $callId, channel=$channelName');
      await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
    } catch (e) {
      debugPrint('Error showing background CallKit: $e');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Applies web URL strategy only on web, no-op on mobile/desktop.
  configureUrlStrategy();

  // Initialize environment, Hive, Firebase, and Supabase immediately
  try {
    final envFile = kIsWeb ? '.env.web' : '.env';
    await dotenv.load(fileName: envFile);
  } catch (e) {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {}
  }

  try {
    await Hive.initFlutter();
  } catch (_) {}

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (_) {}

  try {
    await SupabaseConfig.initialize();
  } catch (_) {}

  runApp(const _BootstrapApp());
}

class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

typedef PendingCall = ({
  String callId,
  String channelName,
  bool isVideo,
  String callerName,
  String? avatarUrl,
});

PendingCall? _globalPendingAcceptedCall;

class _BootstrapAppState extends State<_BootstrapApp> {
  late final Future<void> _initializationFuture = _initializeAppWithMinDelay();
  bool _isAnimationDone = false;
  bool _isFullyInitialized = false;
  PendingCall? _pendingCall;
  bool _callScreenLaunched = false;
  StreamSubscription<CallEvent?>? _callkitSubscription;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      // Listen in state so setState() can be called regardless of timing
      _callkitSubscription =
          FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
        if (event is CallEventActionCallAccept && mounted) {
          // If the app is already fully initialized and running, let the active
          // NotificationService push the call screen natively instead of resetting the app.
          if (_isFullyInitialized) {
            debugPrint('📞 Bootstrap: App already running, delegating to NotificationService');
            return;
          }

          final params = event.callKitParams;
          final extra = params.extra ?? {};
          final callId = extra['callId']?.toString() ?? '';
          final channelName = extra['channelName']?.toString() ?? '';
          final isVideo =
              extra['isVideo'] == true || extra['isVideo'] == 'true';
          final callerName = params.nameCaller ?? 'AgriDirect User';
          final avatarUrl = params.avatar;
          if (callId.isNotEmpty && channelName.isNotEmpty) {
            debugPrint('📞 Bootstrap: CallKit accept received during cold start, forcing rebuild');
            setState(() {
              _pendingCall = (
                callId: callId,
                channelName: channelName,
                isVideo: isVideo,
                callerName: callerName,
                avatarUrl: avatarUrl,
              );
            });
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _callkitSubscription?.cancel();
    super.dispose();
  }

  Route<dynamic> _startupRoute(Widget child) {
    return MaterialPageRoute<void>(builder: (_) => child);
  }

  Future<void> _initializeAppWithMinDelay() async {
    final startTime = DateTime.now();
    await _initializeApp();
    final elapsed = DateTime.now().difference(startTime);
    // Remove the artificial waiting delay on web, and reduce it to 1.5s on mobile
    final minDelay = kIsWeb ? Duration.zero : const Duration(milliseconds: 1500);
    final remaining = minDelay - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
  }

  Future<void> _initializeApp() async {
    // Stage 1: Load environment, initialize Hive, and initialize Firebase concurrently
    final Future<void> envLoadFuture = () async {
      try {
        final envFile = kIsWeb ? '.env.web' : '.env';
        debugPrint('🚀 Loading environment: $envFile');
        await dotenv.load(fileName: envFile);
      } catch (e) {
        try {
          await dotenv.load(fileName: '.env');
        } catch (fallbackError) {
          debugPrint('⚠️ Could not load env file: $e / $fallbackError');
        }
      }
    }();

    final Future<void> hiveInitFuture = () async {
      try {
        await Hive.initFlutter();
        debugPrint('✅ Hive initialized');
      } catch (e) {
        debugPrint('⚠️ Hive initialization error: $e');
      }
    }();

    final Future<void> firebaseInitFuture = () async {
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
          debugPrint('✅ Firebase initialized');
        } else {
          debugPrint('✅ Firebase already initialized');
        }
      } catch (e) {
        debugPrint('⚠️ Firebase initialization error: $e');
      }
    }();

    // Wait for Stage 1 concurrent tasks to complete
    await Future.wait([envLoadFuture, hiveInitFuture, firebaseInitFuture]);

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Stage 2: Initialize offline cache (needs Hive) and Supabase (needs dotenv) concurrently
    final Future<void> cacheInitFuture = () async {
      try {
        final cacheService = OfflineCacheService();
        await cacheService.init();
        debugPrint('✅ Offline cache service initialized');
      } catch (e) {
        debugPrint('⚠️ Offline cache initialization error: $e');
      }
    }();

    final Future<void> supabaseInitFuture = () async {
      try {
        await SupabaseConfig.initialize();
        debugPrint('✅ SupabaseConfig initialized');
      } catch (e) {
        debugPrint('⚠️ SupabaseConfig initialization error: $e');
      }
    }();

    await Future.wait([cacheInitFuture, supabaseInitFuture]);

    // Stage 3: Prime cache (needs Supabase) and initialize AuthService on mobile concurrently
    final Future<void> primeCacheFuture = () async {
      try {
        debugPrint('🔄 Priming product metadata cache...');
        await BootstrapCacheService().primeProductMetadataCache();
        debugPrint('✅ Product metadata cache primed');
      } catch (e) {
        debugPrint('⚠️ Bootstrap cache initialization error: $e');
      }
    }();

    final Future<void> authInitFuture = () async {
      if (!kIsWeb) {
        try {
          debugPrint('🔄 Initializing AuthService...');
          await AuthService().initialize(event: AuthChangeEvent.initialSession);
          debugPrint('✅ AuthService initialized');
        } catch (e) {
          debugPrint('⚠️ Auth initialization error: $e');
        }
      }
    }();

    await Future.wait([primeCacheFuture, authInitFuture]);

    // Check if app was launched by tapping an incoming CallKit notification
    if (!kIsWeb) {
      if (_globalPendingAcceptedCall != null) {
        _pendingCall = _globalPendingAcceptedCall;
        _globalPendingAcceptedCall = null;
      } else {
        try {
          final activeCalls = await FlutterCallkitIncoming.activeCalls();
          if (activeCalls.isNotEmpty) {
            final call = activeCalls.first;
            final extra = call.extra ?? {};
            final callId = extra['callId']?.toString() ?? call.id;
            final channelName = extra['channelName']?.toString() ?? '';
            final isVideo = extra['isVideo'] == true || extra['isVideo'] == 'true';
            final callerName = call.nameCaller ?? 'AgriDirect User';
            final avatarUrl = call.avatar;

            if (callId.isNotEmpty && channelName.isNotEmpty) {
              _pendingCall = (
                callId: callId,
                channelName: channelName,
                isVideo: isVideo,
                callerName: callerName,
                avatarUrl: avatarUrl,
              );
              debugPrint('📞 Pending CallKit call detected: $callId');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Could not check active CallKit calls: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── If launched via CallKit accept, show ONLY the call screen immediately. ──
    // This runs before FutureBuilder is even evaluated, so no loading or splash screen shows!
    if (_pendingCall != null && !kIsWeb && !_callScreenLaunched) {
      _callScreenLaunched = true;
      final call = _pendingCall!;
      debugPrint('📞 Early Launch: standalone call screen for ${call.callId}');
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: appNavigatorKey,
        theme: ThemeData.dark(),
        home: InAppCallScreen(
          name: call.callerName,
          avatarUrl: call.avatarUrl,
          callId: call.callId,
          channelName: call.channelName,
          isVideo: call.isVideo,
          isIncoming: true,
          isAlreadyAccepted: true,
          onCallEnded: () {
            if (mounted) {
              setState(() {
                _pendingCall = null;
                _callScreenLaunched = true;
              });
            }
          },
        ),
        // After call ends and screen pops, launch the real app
        onGenerateRoute: (_) => _startupRoute(const AgriDirectApp()),
      );
    }

    if (_callScreenLaunched) {
      // Call screen was shown; after popping it falls to AgriDirectApp
      return const AgriDirectApp();
    }

    return FutureBuilder<void>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        debugPrint('🎨 FutureBuilder: connectionState=${snapshot.connectionState}, hasError=${snapshot.hasError}, error=${snapshot.error}');
        if (snapshot.hasError) {
          return _StartupErrorScreen(error: snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.done) {
          _isFullyInitialized = true;
          final auth = AuthService();
          debugPrint('   auth.isLoggedIn=${auth.isLoggedIn}, _isAnimationDone=$_isAnimationDone');

          // Skip the loading animation if:
          // - Running on Web (go straight to web apps/dashboards)
          // - Not logged in (go straight to login/welcome)
          // - Animation already done
          // - Coming from OAuth callback (the callback screen handles its own transition)
          final isOAuthCallback = kIsWeb && Uri.base.path.contains('/auth/callback');

          if (kIsWeb || !auth.isLoggedIn || _isAnimationDone || isOAuthCallback) {
            debugPrint('   → Launching AgriDirectApp()');
            return const AgriDirectApp();
          }

          // If logged in, show the premium loading screen
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            onGenerateRoute: (_) => _startupRoute(
              LoadingScreen(
                onFinished: () {
                  if (mounted) {
                    setState(() {
                      _isAnimationDone = true;
                    });
                  }
                },
              ),
            ),
            home: LoadingScreen(
              onFinished: () {
                if (mounted) {
                  setState(() {
                    _isAnimationDone = true;
                  });
                }
              },
            ),
          );
        }

        // While initializing, show a simple background or short-lived splash
        return const MaterialApp(
          debugShowCheckedModeBanner: false,
          onGenerateRoute: _startupSplashRoute,
          home: Scaffold(
            backgroundColor: Color(0xFF064E3B), // Match brand green
            body: Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: Colors.white24,
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Route<dynamic> _startupSplashRoute(RouteSettings settings) {
  return MaterialPageRoute<void>(
    builder: (_) => const Scaffold(
      backgroundColor: Color(0xFF064E3B),
      body: Center(
        child: SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            color: Colors.white24,
            strokeWidth: 2,
          ),
        ),
      ),
    ),
  );
}

class _StartupErrorScreen extends StatelessWidget {
  final String error;

  const _StartupErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'App failed to start.\n\n$error',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLarge.copyWith(color: AppColors.error),
              ),
            ),
          ),
        ),
      ),
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'App failed to start.\n\n$error',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.error),
            ),
          ),
        ),
      ),
    );
  }
}

class AgriDirectApp extends StatefulWidget {
  const AgriDirectApp({super.key});

  @override
  State<AgriDirectApp> createState() => _AgriDirectAppState();
}

class _AgriDirectAppState extends State<AgriDirectApp> {
  late final _router = createAppRouter();
  final AuthService _auth = AuthService();
  final AnalyticsService _analyticsService = AnalyticsService();
  OfflineProductService? _offlineProductService;
  late final _AppLifecycleObserver _lifecycleObserver;
  StreamSubscription<AuthState>? _authStateSubscription;
  bool _sessionStartedByLifecycle = false;
  bool _isDatabaseSyncRunning = false;

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = _AppLifecycleObserver(this);
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    _auth.addListener(_handleAuthSyncState);
    _initializeNotifications();
    _initializeDatabaseSync();
    _initializeOfflineProductSync();
    _initializeAppSession();
    _authStateSubscription = SupabaseConfig.client.auth.onAuthStateChange
        .listen((data) async {
          final event = data.event;
          debugPrint('🔔 Auth State Change: $event');

          if (event == AuthChangeEvent.signedIn) {
            debugPrint('🔵 User signed in, initializing auth service...');
            await _auth.initialize(event: event);
          } else if (event == AuthChangeEvent.signedOut) {
            debugPrint('🟠 User signed out, cleaning up...');
            await _auth.initialize(event: event);
          } else if (event == AuthChangeEvent.tokenRefreshed ||
              event == AuthChangeEvent.userUpdated ||
              event == AuthChangeEvent.initialSession) {
            await _auth.initialize(event: event);
          }
        });
  }

  void _handleAuthSyncState() {
    final isLoggedIn = _auth.isLoggedIn && _auth.userId.isNotEmpty;

    if (isLoggedIn && !_isDatabaseSyncRunning) {
      DatabaseSyncService().startAutoSync(
        syncProfiles: true,
        syncImages: true,
        syncRegistrations: true,
      );
      _isDatabaseSyncRunning = true;
      debugPrint('✅ Database realtime sync started (auth state)');
      return;
    }

    if (!isLoggedIn && _isDatabaseSyncRunning) {
      DatabaseSyncService().stopAutoSync();
      _isDatabaseSyncRunning = false;
      debugPrint('🛑 Database realtime sync stopped (auth state)');
    }
  }

  Future<void> _initializeOfflineProductSync() async {
    try {
      _offlineProductService = OfflineProductService(
        queueService: OfflineQueueService(),
        productService: ProductService(),
      );
      await _offlineProductService!.init();
      debugPrint('✅ Offline product sync service initialized');
    } catch (e) {
      debugPrint('⚠️ Offline product sync initialization error: $e');
    }
  }

  Future<void> _initializeAppSession() async {
    try {
      final auth = AuthService();
      if (auth.isLoggedIn && auth.userId.isNotEmpty) {
        await _analyticsService.startSession(userId: auth.userId);
        _sessionStartedByLifecycle = true;
      }
    } catch (e) {
      debugPrint('⚠️ Analytics session initialization error: $e');
    }
  }

  Future<void> _handleAppResumed() async {
    try {
      final auth = AuthService();
      if (auth.isLoggedIn && auth.userId.isNotEmpty) {
        await _analyticsService.startSession(userId: auth.userId);
        _sessionStartedByLifecycle = true;

        // Also check weather on app resume (non-blocking)
      }
    } catch (e) {
      debugPrint('⚠️ Analytics session resume error: $e');
    }
  }

  Future<void> _handleAppPaused() async {
    try {
      final auth = AuthService();
      if (auth.userId.isNotEmpty && _sessionStartedByLifecycle) {
        await _analyticsService.endSession(userId: auth.userId);
        _sessionStartedByLifecycle = false;
      }
    } catch (e) {
      debugPrint('⚠️ Analytics session pause error: $e');
    }
  }

  Future<void> _initializeDatabaseSync() async {
    try {
      _handleAuthSyncState();
    } catch (e) {
      debugPrint('⚠️ Database sync initialization error: $e');
    }
  }

  Future<void> _initializeNotifications() async {
    try {
      // Initialize notification service
      final notificationService = NotificationService();
      await notificationService.initialize();
      debugPrint('✅ Notification service initialized');

      // Trigger a weather check on app start (non-blocking)
    } catch (e) {
      debugPrint('⚠️ Notification initialization error: $e');
    }
  }

  @override
  void dispose() {
    // Stop database sync when app closes
    _auth.removeListener(_handleAuthSyncState);
    DatabaseSyncService().stopAutoSync();
    _isDatabaseSyncRunning = false;
    _offlineProductService?.pendingProductsCount.dispose();
    _offlineProductService?.isSyncing.dispose();
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _authStateSubscription?.cancel();
    _analyticsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'AgriDirect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.dmSansTextTheme(),
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
          onSurface: AppColors.textHeadline,
          error: AppColors.error,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: AppDecorations.buttonRadius,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          hoverColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSubtle,
          ),
        ),
      ),
      routerConfig: _router,
    );
  }
}

class _AppLifecycleObserver extends WidgetsBindingObserver {
  final _AgriDirectAppState _state;

  _AppLifecycleObserver(this._state);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _state._handleAppResumed();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _state._handleAppPaused();
    }
  }
}
