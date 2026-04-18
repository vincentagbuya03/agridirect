import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static const String channelId = 'agridirect_channel';
  static const String channelName = 'AgrIDirect Notifications';
  static const String channelDescription =
      'Notifications for orders, messages, reviews, and updates';
  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
      );

  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final messaging = FirebaseMessaging.instance;
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  StreamSubscription<AuthState>? _authStateSubscription;

  SupabaseClient get supabase => Supabase.instance.client;
  bool get _isWeb => kIsWeb;
  bool get _isAndroid => !_isWeb && Platform.isAndroid;
  bool get _isApple => !_isWeb && (Platform.isIOS || Platform.isMacOS);

  // Initialize notifications
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    if (_isWeb) {
      _initialized = true;
      debugPrint(
        'Skipping Firebase Messaging initialization on web until a web service worker is configured.',
      );
      return;
    }

    // Request permissions
    await _requestPermissions();

    // Initialize local notifications
    await ensureLocalNotificationsInitialized();

    await messaging.setAutoInitEnabled(true);

    // Get and save FCM token
    await _getFCMToken();

    // Listen to token refresh
    messaging.onTokenRefresh.listen((newToken) {
      _saveFCMTokenToDatabase(newToken);
    });

    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Listen for notification taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle when the app is opened from a terminated state via push.
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      await _handleNotificationTap(initialMessage);
    }

    _listenToAuthChanges();

    _initialized = true;
  }

  Future<void> ensureLocalNotificationsInitialized() async {
    await _initializeLocalNotifications();
    await _createNotificationChannel();
  }

  // Request notification permissions
  Future<void> _requestPermissions() async {
    final settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('User granted permission: ${settings.authorizationStatus}');

    if (_isAndroid) {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    }

    if (_isApple) {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  // Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidInitSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosInitSettings = DarwinInitializationSettings(
      onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
    );

    const initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );
  }

  Future<void> _createNotificationChannel() async {
    if (!_isAndroid) {
      return;
    }

    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(_androidChannel);
  }

  // Get and save FCM token
  Future<void> _getFCMToken() async {
    try {
      final token = await messaging.getToken();
      if (token != null) {
        debugPrint('FCM Token: $token');
        await _saveFCMTokenToDatabase(token);
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  // Save FCM token to database
  Future<void> _saveFCMTokenToDatabase(String token) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('User not authenticated');
        return;
      }

      final deviceType = _isAndroid ? 'android' : (_isWeb ? 'web' : 'ios');

      // Check if record already exists for this user and device
      final existingRecord = await supabase
          .from('user_device_tokens')
          .select('token_id')
          .eq('user_id', userId)
          .eq('device_type', deviceType)
          .maybeSingle();

      if (existingRecord != null) {
        // Update existing token
        await supabase
            .from('user_device_tokens')
            .update({
              'fcm_token': token,
              'is_active': true,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId)
            .eq('device_type', deviceType);
      } else {
        // Insert new token
        await supabase.from('user_device_tokens').insert({
          'user_id': userId,
          'fcm_token': token,
          'device_type': deviceType,
          'is_active': true,
        });
      }

      debugPrint('FCM token saved to database');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  void _listenToAuthChanges() {
    _authStateSubscription ??=
        supabase.auth.onAuthStateChange.listen((authState) async {
      switch (authState.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
        case AuthChangeEvent.userUpdated:
        case AuthChangeEvent.initialSession:
          await _getFCMToken();
          break;
        case AuthChangeEvent.signedOut:
          final token = await messaging.getToken();
          if (token != null) {
            await deleteToken(token);
          }
          break;
        case AuthChangeEvent.passwordRecovery:
        case AuthChangeEvent.mfaChallengeVerified:
          break;
        default:
          break;
      }
    });
  }

  // Delete FCM token when user logs out
  Future<void> deleteToken(String token) async {
    try {
      await supabase
          .from('user_device_tokens')
          .delete()
          .eq('fcm_token', token);
      debugPrint('FCM token deleted from database');
    } catch (e) {
      debugPrint('Error deleting FCM token: $e');
    }
  }

  // Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Got a message whilst in the foreground!');
    debugPrint('Message data: ${message.data}');

    if (message.notification != null) {
      debugPrint('Message notification: ${message.notification}');

      // Show local notification
      await flutterLocalNotificationsPlugin.show(
        message.hashCode,
        message.notification!.title,
        message.notification!.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: _getPayload(message),
      );
    }
  }

  // Handle notification tap
  Future<void> _handleNotificationTap(RemoteMessage message) async {
    debugPrint('Notification tapped!');
    debugPrint('Message data: ${message.data}');

    final linkType = message.data['link_type'] ?? '';
    final linkId = message.data['link_id'] ?? '';

    debugPrint('Link type: $linkType, Link ID: $linkId');

    // Handle navigation based on notification type
    // This will be called from your router/navigation logic
    // For now, just print for debugging
  }

  // Local notification handlers
  static Future<void> _onDidReceiveLocalNotification(
    int id,
    String? title,
    String? body,
    String? payload,
  ) async {
    debugPrint('onDidReceiveLocalNotification: id=$id, title=$title, body=$body');
  }

  static Future<void> _onDidReceiveNotificationResponse(
    NotificationResponse notificationResponse,
  ) async {
    final payload = notificationResponse.payload;
    debugPrint('Notification tapped with payload: $payload');
    // Handle navigation here
  }

  // Helper to get payload from message
  String _getPayload(RemoteMessage message) {
    final linkType = message.data['link_type'] ?? '';
    final linkId = message.data['link_id'] ?? '';
    return '$linkType:$linkId';
  }

  // Get unread notification count
  Future<int> getUnreadNotificationCount(String userId) async {
    try {
      final count = await supabase
          .from('notifications')
          .count(CountOption.exact)
          .eq('user_id', userId)
          .eq('is_read', false);

      return count;
    } catch (e) {
      debugPrint('Error getting unread notification count: $e');
      return 0;
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('notification_id', notificationId);
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      await supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  // Get notifications for user
  Future<List<Map<String, dynamic>>> getNotifications(String userId,
      {int limit = 20, int offset = 0}) async {
    try {
      final response = await supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting notifications: $e');
      return [];
    }
  }
}
