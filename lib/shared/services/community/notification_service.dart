import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../router/app_router.dart';
import '../auth/auth_service.dart';

class NotificationService {
  static const String channelId = 'agridirect_channel';
  static const String channelName = 'AgriDirect Notifications';
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
  RealtimeChannel? _messageSubscription;
  RealtimeChannel? _presenceChannel;
  String? _activeConversationId;
  final ValueNotifier<Set<String>> onlineUsersNotifier = ValueNotifier({});

  /// Call this when entering a chat screen to suppress notifications for that chat
  void setActiveConversation(String? conversationId) {
    _activeConversationId = conversationId;
  }

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
    _startMessageListener();
    _startPresenceTracking();

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
            AndroidFlutterLocalNotificationsPlugin
          >();
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
          AndroidFlutterLocalNotificationsPlugin
        >();

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
    _authStateSubscription ??= supabase.auth.onAuthStateChange.listen((
      authState,
    ) async {
      final event = authState.event;
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed || event == AuthChangeEvent.initialSession) {
        _getFCMToken();
        _startMessageListener();
        _startPresenceTracking();
      } else if (event == AuthChangeEvent.signedOut) {
        _stopMessageListener();
        _stopPresenceTracking();
        final token = await messaging.getToken();
        if (token != null) {
          await deleteToken(token);
        }
      }
    });
  }

  void _startPresenceTracking() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _stopPresenceTracking();

    _presenceChannel = supabase.channel('presence-global', opts: const RealtimeChannelConfig(self: true));
    
    _presenceChannel!.onPresenceSync((payload) {
      final state = _presenceChannel!.presenceState();
      final onlineIds = <String>{};
      
      for (final presenceState in state) {
        for (final presence in presenceState.presences) {
          final userId = presence.payload['user_id']?.toString();
          if (userId != null) {
            onlineIds.add(userId);
          }
        }
      }
      
      onlineUsersNotifier.value = onlineIds;
    }).onPresenceJoin((payload) {
      debugPrint('User joined presence: ${payload.newPresences}');
    }).onPresenceLeave((payload) {
      debugPrint('User left presence: ${payload.leftPresences}');
    });

    _presenceChannel!.subscribe((status, error) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await _presenceChannel!.track({'user_id': user.id});
      }
    });
  }

  void _stopPresenceTracking() {
    _presenceChannel?.unsubscribe();
    _presenceChannel = null;
    onlineUsersNotifier.value = {};
  }

  // Delete FCM token when user logs out
  Future<void> deleteToken(String token) async {
    try {
      await supabase.from('user_device_tokens').delete().eq('fcm_token', token);
      debugPrint('FCM token deleted from database');
    } catch (e) {
      debugPrint('Error deleting FCM token: $e');
    }
  }

  void _startMessageListener() {
    _messageSubscription?.unsubscribe();

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    _messageSubscription = supabase
        .channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            final senderId = payload.newRecord['sender_id']?.toString();
            final conversationId = payload.newRecord['conversation_id']
                ?.toString();
            final text =
                payload.newRecord['message_text']?.toString() ?? 'New message';

            // Only notify if:
            // 1. Message is from someone else
            // 2. We aren't currently looking at this conversation
            if (senderId != null &&
                senderId != userId &&
                conversationId != _activeConversationId) {
              final senderName = await _resolveSenderDisplayName(senderId);
              await _showLocalMessageNotification(
                conversationId,
                text,
                senderName: senderName,
              );
            }
          },
        )
        .subscribe();
  }

  void _stopMessageListener() {
    _messageSubscription?.unsubscribe();
    _messageSubscription = null;
  }

  Future<void> _showLocalMessageNotification(
    String? conversationId,
    String text, {
    String? senderName,
  }) async {
    final title = senderName != null && senderName.trim().isNotEmpty
        ? 'New message from ${senderName.trim()}'
        : 'New Message';

    await flutterLocalNotificationsPlugin.show(
      conversationId.hashCode,
      title,
      text,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'chat:$conversationId',
    );
  }

  // Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Got a message whilst in the foreground!');
    debugPrint('Message data: ${message.data}');

    if (message.notification != null) {
      debugPrint('Message notification: ${message.notification}');

      final senderName = message.data['sender_name']?.toString().trim();
      final title = senderName != null && senderName.isNotEmpty
          ? 'New message from $senderName'
          : message.notification!.title;

      // Show local notification
      await flutterLocalNotificationsPlugin.show(
        message.hashCode,
        title,
        message.notification!.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
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

    await _navigateFromLink(
      linkType: linkType.toString(),
      linkId: linkId.toString(),
    );
  }

  // Local notification handlers
  static Future<void> _onDidReceiveLocalNotification(
    int id,
    String? title,
    String? body,
    String? payload,
  ) async {
    debugPrint(
      'onDidReceiveLocalNotification: id=$id, title=$title, body=$body',
    );
  }

  Future<void> _onDidReceiveNotificationResponse(
    NotificationResponse notificationResponse,
  ) async {
    final payload = notificationResponse.payload;
    debugPrint('Notification tapped with payload: $payload');

    final parsed = _parsePayload(payload);
    await _navigateFromLink(linkType: parsed.$1, linkId: parsed.$2);
  }

  // Helper to get payload from message
  String _getPayload(RemoteMessage message) {
    final linkType = message.data['link_type'] ?? '';
    final linkId = message.data['link_id'] ?? '';
    return '$linkType:$linkId';
  }

  (String, String) _parsePayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return ('', '');
    }

    final separator = payload.indexOf(':');
    if (separator <= 0 || separator >= payload.length - 1) {
      return (payload, '');
    }

    final rawType = payload.substring(0, separator);
    final rawId = payload.substring(separator + 1);
    final normalizedType = rawType == 'chat' ? 'conversation' : rawType;
    return (normalizedType, rawId);
  }

  Future<void> _navigateFromLink({
    required String linkType,
    required String linkId,
    int retryCount = 0,
  }) async {
    final context = appNavigatorKey.currentContext;
    if (context == null) {
      if (retryCount < 6) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await _navigateFromLink(
          linkType: linkType,
          linkId: linkId,
          retryCount: retryCount + 1,
        );
      }
      return;
    }

    if (linkType == 'conversation' && linkId.isNotEmpty) {
      final isFarmer = AuthService().isViewingAsFarmer;
      GoRouter.of(context).go(
        AppRoutes.messages,
        extra: {'conversationId': linkId, 'asFarmer': isFarmer},
      );
      setActiveConversation(linkId);
      return;
    }

    GoRouter.of(context).go(AppRoutes.messages);
  }

  Future<String?> _resolveSenderDisplayName(String senderId) async {
    try {
      final user = await supabase
          .from('users')
          .select('name, email')
          .eq('user_id', senderId)
          .maybeSingle();

      final name = (user?['name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) {
        return name;
      }

      final email = (user?['email'] as String?)?.trim();
      if (email != null && email.isNotEmpty) {
        return email;
      }
    } catch (e) {
      debugPrint('Failed to resolve sender name for local notification: $e');
    }

    return null;
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

  // Insert a notification into the database
  Future<void> insertNotification({
    required String userId,
    required String title,
    required String content,
    String type = 'system',
    String? linkType,
    String? linkId,
  }) async {
    try {
      // Use the Edge Function for consistency with the messaging feature.
      // This automatically handles notification_type_id mapping and push notifications.
      await supabase.functions.invoke(
        'send-push-notification',
        body: {
          'targetUserId': userId,
          'title': title,
          'body': content,
          'notificationCode': type,
          'linkType': linkType,
          'linkId': linkId,
        },
      );
      debugPrint('✅ Notification triggered via Edge Function');
    } catch (e) {
      debugPrint('❌ Error triggering notification via Edge Function: $e');

      // Fallback: Attempt direct insert if Edge Function fails
      try {
        await supabase.from('notifications').insert({
          'user_id': userId,
          'title': title,
          'body': content,
          'type': type,
          'link_type': linkType,
          'link_id': linkId,
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        });
        debugPrint('✅ Notification saved to database (fallback)');
      } catch (innerError) {
        debugPrint('❌ Fallback insertion failed: $innerError');
      }
    }
  }

  // Get notifications for user
  Future<List<Map<String, dynamic>>> getNotifications(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
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
