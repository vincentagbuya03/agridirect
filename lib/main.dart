import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';

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

// Handle background notifications
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Handling background message: ${message.messageId}');

  final notificationService = NotificationService();
  await notificationService.ensureLocalNotificationsInitialized();
  if (message.notification != null) {
    await notificationService.flutterLocalNotificationsPlugin.show(
      message.hashCode,
      message.notification!.title,
      message.notification!.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationService.channelId,
          NotificationService.channelName,
          channelDescription: NotificationService.channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Applies web URL strategy only on web, no-op on mobile/desktop.
  configureUrlStrategy();

  runApp(const _BootstrapApp());
}

class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  late final Future<void> _initializationFuture = _initializeApp();

  Future<void> _initializeApp() async {
    // Keep each step non-fatal where possible so web never stays blank.
    try {
      await Hive.initFlutter();
      debugPrint('✅ Hive initialized');
    } catch (e) {
      debugPrint('⚠️ Hive initialization error: $e');
    }

    try {
      final cacheService = OfflineCacheService();
      await cacheService.init();
      debugPrint('✅ Offline cache service initialized');
    } catch (e) {
      debugPrint('⚠️ Offline cache initialization error: $e');
    }

    try {
      await dotenv.load(fileName: kIsWeb ? '.env.web' : '.env');
    } catch (e) {
      try {
        await dotenv.load(fileName: '.env');
      } catch (fallbackError) {
        debugPrint('⚠️ Could not load env file: $e / $fallbackError');
      }
    }

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized');

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await SupabaseConfig.initialize();

    try {
      await BootstrapCacheService().primeProductMetadataCache();
    } catch (e) {
      debugPrint('⚠️ Bootstrap cache initialization error: $e');
    }

    try {
      await AuthService().initialize();
    } catch (e) {
      debugPrint('⚠️ Auth initialization error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StartupLoadingScreen();
        }

        if (snapshot.hasError) {
          return _StartupErrorScreen(error: snapshot.error.toString());
        }

        return const AgriDirectApp();
      },
    );
  }
}

class _StartupLoadingScreen extends StatelessWidget {
  const _StartupLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text('Starting AgriDirect...', style: AppTextStyles.headline3),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  final String error;

  const _StartupErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
  final AnalyticsService _analyticsService = AnalyticsService();
  OfflineProductService? _offlineProductService;
  late final _AppLifecycleObserver _lifecycleObserver;
  bool _sessionStartedByLifecycle = false;

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = _AppLifecycleObserver(this);
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    _initializeNotifications();
    _initializeDatabaseSync();
    _initializeOfflineProductSync();
    _initializeAppSession();
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
      final auth = AuthService();
      if (auth.isLoggedIn) {
        // Start automatic database sync
        DatabaseSyncService().startAutoSync(
          syncProfiles: true,
          syncImages: true,
          syncRegistrations: true,
        );
        debugPrint('✅ Database sync service started');
      }
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
    } catch (e) {
      debugPrint('⚠️ Notification initialization error: $e');
    }
  }

  @override
  void dispose() {
    // Stop database sync when app closes
    DatabaseSyncService().stopAutoSync();
    _offlineProductService?.pendingProductsCount.dispose();
    _offlineProductService?.isSyncing.dispose();
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
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
