import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../router/app_router.dart';
import 'package:flutter/material.dart';
import '../../screens/messages/in_app_call_screen.dart';
import '../auth/auth_service.dart';
import '../../utils/js_helper.dart';
import '../core/supabase_data_service.dart';
import '../communication/call_service.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import '../../screens/post_detail_screen.dart';

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
  RealtimeChannel? _webNotificationsSubscription;
  RealtimeChannel? _mobileNotificationsSubscription;
  String? _activeConversationId;
  String? _activeCallId; // Guard against double incoming-call dialog
  final ValueNotifier<Set<String>> onlineUsersNotifier = ValueNotifier({});
  final Map<String, DateTime> _lastActiveCache = {};
  Timer? _activeStatusTimer;

  DateTime? getLastActive(String userId) {
    return _lastActiveCache[userId];
  }

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

    // Always listen to auth changes and track presence (Web + Mobile support)
    _listenToAuthChanges();
    _startPresenceTracking();
    if (supabase.auth.currentUser != null) {
      _startGlobalIncomingCallListener();
    }

    if (_isWeb) {
      _initialized = true;
      registerNotificationCallback((linkType, linkId) {
        navigateFromLink(linkType: linkType, linkId: linkId);
      });
      try {
        evalJs(
          """
          if (typeof Notification !== 'undefined' && Notification.permission !== 'granted' && Notification.permission !== 'denied') {
            Notification.requestPermission();
          }
          """
        );
      } catch (e) {
        debugPrint('Error requesting web notification permission: $e');
      }
      _startWebRealtimeNotifications();
      return;
    }

    // Request permissions
    await _requestPermissions();

    // Initialize local notifications
    await ensureLocalNotificationsInitialized();

    await messaging.setAutoInitEnabled(true);

    // Get and save FCM token
    await _getFCMToken();

    // Setup Native CallKit Listener
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
      if (event is CallEventActionCallAccept) {
        final params = event.callKitParams;
        final extra = params.extra ?? {};
        final callId = extra['callId']?.toString() ?? '';
        final channelName = extra['channelName']?.toString() ?? '';
        final isVideo = extra['isVideo'] == true || extra['isVideo'] == 'true';
        final callerName = params.nameCaller ?? 'AgriDirect User';
        final avatarUrl = params.avatar;

        if (callId.isNotEmpty) {
          await CallService().updateCallStatus(callId, 'connected');
        }

        if (appNavigatorKey.currentContext != null) {
          Navigator.push(
            appNavigatorKey.currentContext!,
            MaterialPageRoute(
              builder: (_) => InAppCallScreen(
                name: callerName,
                avatarUrl: avatarUrl,
                callId: callId,
                channelName: channelName,
                isVideo: isVideo,
                isIncoming: true,
                isAlreadyAccepted: true,
              ),
            ),
          );
        }
      } else if (event is CallEventActionCallDecline) {
        final params = event.callKitParams;
        final extra = params.extra ?? {};
        final callId = extra['callId']?.toString() ?? '';
        if (callId.isNotEmpty) {
          await CallService().updateCallStatus(callId, 'declined');
        }
      } else if (event is CallEventActionCallEnded) {
        final params = event.callKitParams;
        final extra = params.extra ?? {};
        final callId = extra['callId']?.toString() ?? '';
        if (callId.isNotEmpty) {
          await CallService().updateCallStatus(callId, 'declined');
        }
      }
    });

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

    _startMobileRealtimeNotifications();

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
  Future<void> _saveFCMTokenToDatabase(String token, {int retryCount = 0}) async {
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
      // If it's a foreign key error (users profile not created yet), retry once after a delay
      if (e.toString().contains('23503') && retryCount < 1) {
        debugPrint('⚠️ User profile not found yet, retrying FCM token save in 2s...');
        await Future.delayed(const Duration(seconds: 2));
        return _saveFCMTokenToDatabase(token, retryCount: retryCount + 1);
      }
      debugPrint('Error saving FCM token: $e');
    }
  }

  void _listenToAuthChanges() {
    _authStateSubscription ??= supabase.auth.onAuthStateChange.listen((
      authState,
    ) async {
      final event = authState.event;
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed || event == AuthChangeEvent.initialSession) {
        if (_isWeb) {
          _startWebRealtimeNotifications();
        } else {
          _getFCMToken();
          _startMobileRealtimeNotifications();
        }
        _startGlobalIncomingCallListener();
        _startPresenceTracking();
      } else if (event == AuthChangeEvent.signedOut) {
        if (_isWeb) {
          _stopWebRealtimeNotifications();
        } else {
          _stopMessageListener();
          _stopMobileRealtimeNotifications();
          final token = await messaging.getToken();
          if (token != null) {
            await deleteToken(token);
          }
        }
        _stopGlobalIncomingCallListener();
        _stopPresenceTracking();
      }
    });
  }

  void _startGlobalIncomingCallListener() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    CallService().subscribeToIncomingCalls(
      onIncomingCall: (callData) async {
        final callId = callData['call_id']?.toString() ?? '';

        // Prevent duplicate dialogs for the same call (Realtime + FCM race)
        if (callId.isNotEmpty && callId == _activeCallId) {
          debugPrint('📞 Duplicate incoming call ignored for $callId');
          return;
        }
        _activeCallId = callId;

        final callerId = callData['caller_id']?.toString() ?? '';
        String callerName = 'AgriDirect User';
        String? avatarUrl;

        try {
          final profile = await supabase
              .from('users')
              .select('name, avatar_url')
              .eq('user_id', callerId)
              .maybeSingle();

          if (profile != null) {
            callerName = profile['name']?.toString() ?? 'AgriDirect User';
            avatarUrl = profile['avatar_url']?.toString();
          }
        } catch (_) {}

        final channelName = callData['channel_name']?.toString() ?? '';
        final isVideo = callData['is_video'] == true;

        final ctx = appNavigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          if (_isWeb) {
            GoRouter.of(ctx).push('/call/$callId', extra: {
              'name': callerName,
              'avatarUrl': avatarUrl,
              'channelName': channelName,
              'isVideo': isVideo,
              'isIncoming': true,
            });
          } else {
            showDialog(
              context: ctx,
              barrierDismissible: false,
              useRootNavigator: false,
              builder: (dialogContext) => InAppCallScreen(
                name: callerName,
                avatarUrl: avatarUrl,
                callId: callId,
                channelName: channelName,
                isVideo: isVideo,
                isIncoming: true,
              ),
            ).whenComplete(() => _activeCallId = null); // Reset guard when dialog closes
          }
        }
      },
      onCallUpdated: (callData) {
        // Handled inside InAppCallScreen
      },
    );
  }

  void _stopGlobalIncomingCallListener() {
    CallService().unsubscribeIncomingCalls();
  }

  Future<void> _updateMyLastActive() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      await supabase.from('users').update({
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);
      debugPrint('🟢 Updated user last active timestamp in database.');
    } catch (e) {
      debugPrint('⚠️ Error updating user last active: $e');
    }
  }

  void _startPresenceTracking() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _stopPresenceTracking();

    _presenceChannel = supabase.channel('presence-global', opts: const RealtimeChannelConfig(self: true));
    
    _presenceChannel!.onPresenceSync((payload) {
      final state = _presenceChannel!.presenceState();
      final onlineIds = <String>{};
      final now = DateTime.now();
      
      for (final presenceState in state) {
        for (final presence in presenceState.presences) {
          final userId = presence.payload['user_id']?.toString();
          if (userId != null) {
            onlineIds.add(userId);
            _lastActiveCache[userId] = now;
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
        await _updateMyLastActive();
        // Periodically update last active timestamp in DB every 15 minutes
        _activeStatusTimer?.cancel();
        _activeStatusTimer = Timer.periodic(const Duration(minutes: 15), (timer) async {
          await _updateMyLastActive();
        });
      }
    });
  }

  void _stopPresenceTracking() {
    _activeStatusTimer?.cancel();
    _activeStatusTimer = null;
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


  void _stopMessageListener() {
    _messageSubscription?.unsubscribe();
    _messageSubscription = null;
  }


  // Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Got a message whilst in the foreground!');
    debugPrint('Message data: ${message.data}');

    // Skip call notifications in foreground — the Realtime path already
    // opened the InAppCallScreen dialog with a ringtone.
    final linkType =
        (message.data['link_type'] ?? _inferLinkTypeFromData(message.data))
            .toString();
    if (linkType == 'call') {
      debugPrint('Suppressed FCM call notification (handled by Realtime dialog)');
      return;
    }

    if (message.notification != null) {
      debugPrint('Message notification: ${message.notification}');

      final senderName = message.data['sender_name']?.toString().trim();
      final conversationId = message.data['conversation_id']?.toString();
      
      // Suppress notification if we are already in the conversation
      if (conversationId != null && conversationId == _activeConversationId) {
        debugPrint('Suppressed notification for active conversation: $conversationId');
        return;
      }

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

    final inferredLinkType = _inferLinkTypeFromData(message.data);
    final linkType = (message.data['link_type'] ?? inferredLinkType).toString();
    final linkId = message.data['link_id'] ?? '';

    debugPrint('Link type: $linkType, Link ID: $linkId');

    await navigateFromLink(
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
    await navigateFromLink(linkType: parsed.$1, linkId: parsed.$2);
  }

  // Helper to get payload from message
  String _getPayload(RemoteMessage message) {
    final linkType =
        (message.data['link_type'] ?? _inferLinkTypeFromData(message.data))
            .toString();
    final linkId = message.data['link_id'] ?? '';
    return '$linkType:$linkId';
  }

  String _inferLinkTypeFromData(Map<String, dynamic> data) {
    final category = data['category']?.toString().trim().toLowerCase();
    if (category == 'weather') {
      return 'weather';
    }
    return '';
  }

  (String, String) _parsePayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return ('', '');
    }

    final separator = payload.indexOf(':');
    if (separator <= 0) {
      return (payload, '');
    }

    final rawType = payload.substring(0, separator);
    final rawId = separator >= payload.length - 1
        ? ''
        : payload.substring(separator + 1);
    final normalizedType = rawType == 'chat' ? 'conversation' : rawType;
    return (normalizedType, rawId);
  }

  Future<void> navigateFromLink({
    required String linkType,
    required String linkId,
    int retryCount = 0,
  }) async {
    final initialContext = appNavigatorKey.currentContext;
    if (initialContext == null) {
      if (retryCount < 6) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await navigateFromLink(
          linkType: linkType,
          linkId: linkId,
          retryCount: retryCount + 1,
        );
      }
      return;
    }

    if (linkType == 'conversation' && linkId.isNotEmpty) {
      final isFarmer = AuthService().isViewingAsFarmer;
      final ctx = appNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        GoRouter.of(ctx).go(
          AppRoutes.messages,
          extra: {'conversationId': linkId, 'asFarmer': isFarmer},
        );
      }
      setActiveConversation(linkId);
      return;
    }

    if (linkType == 'call' && linkId.isNotEmpty) {
      try {
        final callRecord = await supabase
            .from('calls')
            .select()
            .eq('call_id', linkId)
            .maybeSingle();

        if (callRecord != null && callRecord['status'] == 'ringing') {
          final callerId = callRecord['caller_id']?.toString() ?? '';
          String callerName = 'AgriDirect User';
          String? avatarUrl;

          final profile = await supabase
              .from('users')
              .select('name, avatar_url')
              .eq('user_id', callerId)
              .maybeSingle();

          if (profile != null) {
            callerName = profile['name']?.toString() ?? 'AgriDirect User';
            avatarUrl = profile['avatar_url']?.toString();
          }

          final ctx = appNavigatorKey.currentContext;
          if (ctx != null && ctx.mounted) {
            showDialog(
              context: ctx,
              barrierDismissible: false,
              useRootNavigator: false,
              builder: (dialogContext) => InAppCallScreen(
                name: callerName,
                avatarUrl: avatarUrl,
                callId: callRecord['call_id']?.toString() ?? '',
                channelName: callRecord['channel_name']?.toString() ?? '',
                isVideo: callRecord['is_video'] == true,
                isIncoming: true,
              ),
            );
          }
          return;
        }
      } catch (e) {
        debugPrint('Error navigating to call: $e');
      }
      final ctx = appNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        GoRouter.of(ctx).go(AppRoutes.home);
      }
      return;
    }

    if (linkType == 'order' || linkType == 'orders') {
      final isFarmer = AuthService().isViewingAsFarmer;
      final ctx = appNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        if (kIsWeb) {
          if (isFarmer) {
            GoRouter.of(ctx).go('${AppRoutes.farmerDashboard}?tab=2');
          } else {
            GoRouter.of(ctx).go(AppRoutes.profile);
          }
        } else {
          if (isFarmer) {
            GoRouter.of(ctx).go(AppRoutes.home);
          } else {
            GoRouter.of(ctx).go(AppRoutes.customerOrders);
          }
        }
      }
      return;
    }

    if (linkType == 'farmer_registration' ||
        linkType == 'farmer_approved' ||
        linkType == 'farmer_verification') {
      final ctx = appNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        final authService = AuthService();
        final hasSellerRole = authService.isSeller;
        
        if (hasSellerRole) {
          authService.switchToFarmerMode();
          GoRouter.of(ctx).go(AppRoutes.farmerDashboard);
        } else {
          if (kIsWeb) {
            GoRouter.of(ctx).go(AppRoutes.profile);
          } else {
            GoRouter.of(ctx).go(AppRoutes.farmerRegister);
          }
        }
      }
      return;
    }

    final ctx = appNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      if (linkType == 'weather') {
        GoRouter.of(ctx).go(AppRoutes.home);
        return;
      }

      if (linkType == 'product') {
        GoRouter.of(ctx).go(AppRoutes.marketplace);
        return;
      }

      if (linkType == 'post' && linkId.isNotEmpty) {
        try {
          final post = await SupabaseDataService().getForumPostById(linkId);
          if (post != null) {
            final targetContext = appNavigatorKey.currentContext;
            if (targetContext != null && targetContext.mounted) {
              Navigator.of(targetContext).push(
                MaterialPageRoute(
                  builder: (_) => PostDetailScreen(post: post),
                ),
              );
              return;
            }
          }
        } catch (e) {
          debugPrint('Error navigating to post details: $e');
        }
        final finalCtx = appNavigatorKey.currentContext;
        if (finalCtx != null && finalCtx.mounted) {
          GoRouter.of(finalCtx).go(AppRoutes.home);
        }
        return;
      }

      GoRouter.of(ctx).go(AppRoutes.home);
    }
  }


  // Get unread notification count
  Future<int> getUnreadNotificationCount(String userId) async {
    try {
      final count = await supabase
          .from('notifications')
          .count(CountOption.exact)
          .eq('user_id', userId)
          .eq('is_read', false)
          .neq('link_type', 'conversation');

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

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await supabase
          .from('notifications')
          .delete()
          .eq('notification_id', notificationId);
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  // Delete all notifications for a user
  Future<void> deleteAllNotifications(String userId) async {
    try {
      await supabase
          .from('notifications')
          .delete()
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Error deleting all notifications: $e');
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
        // Query the notification_type_id first
        final typeResponse = await supabase
            .from('notification_types')
            .select('notification_type_id')
            .eq('code', type)
            .limit(1)
            .maybeSingle();
            
        final typeId = typeResponse?['notification_type_id'] ?? 1; // fallback to general (usually ID 1)

        await supabase.from('notifications').insert({
          'user_id': userId,
          'title': title,
          'body': content,
          'notification_type_id': typeId,
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
          .neq('link_type', 'conversation')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting notifications: $e');
      return [];
    }
  }

  void _startWebRealtimeNotifications() {
    if (!_isWeb) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _stopWebRealtimeNotifications();

    _webNotificationsSubscription = supabase
        .channel('web-notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            final linkType = payload.newRecord['link_type']?.toString();
            if (linkType == 'conversation') {
              return; // Skip showing HTML5 notifications for chat messages
            }
            final title = payload.newRecord['title']?.toString() ?? 'AgriDirect';
            final body = payload.newRecord['body']?.toString() ?? '';
            final linkId = payload.newRecord['link_id']?.toString() ?? '';
            _showWebNotification(title, body, linkType ?? '', linkId);
          },
        )
        .subscribe();
  }

  void _stopWebRealtimeNotifications() {
    _webNotificationsSubscription?.unsubscribe();
    _webNotificationsSubscription = null;
  }

  void _showWebNotification(String title, String body, String linkType, String linkId) {
    if (!_isWeb) return;
    try {
      final escapedTitle = jsonEncode(title);
      final escapedBody = jsonEncode(body);
      final escapedLinkType = jsonEncode(linkType);
      final escapedLinkId = jsonEncode(linkId);
      evalJs(
        """
        if (typeof Notification !== 'undefined') {
          if (Notification.permission === 'granted') {
            var notification = new Notification($escapedTitle, {
              body: $escapedBody,
              icon: '/icons/Icon-192.png'
            });
            notification.onclick = function() {
              window.focus();
              if (typeof onWebNotificationClick === 'function') {
                onWebNotificationClick($escapedLinkType, $escapedLinkId);
              }
            };
          } else if (Notification.permission !== 'denied') {
            Notification.requestPermission().then(permission => {
              if (permission === 'granted') {
                var notification = new Notification($escapedTitle, {
                  body: $escapedBody,
                  icon: '/icons/Icon-192.png'
                });
                notification.onclick = function() {
                  window.focus();
                  if (typeof onWebNotificationClick === 'function') {
                    onWebNotificationClick($escapedLinkType, $escapedLinkId);
                  }
                };
              }
            });
          }
        }
        """
      );
    } catch (e) {
      debugPrint('Error showing HTML5 Web Notification: $e');
    }
  }

  void _startMobileRealtimeNotifications() {
    if (_isWeb) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _stopMobileRealtimeNotifications();

    _mobileNotificationsSubscription = supabase
        .channel('mobile-notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) async {
            final linkType = payload.newRecord['link_type']?.toString();
            // Suppress foreground notification if we are already in the conversation
            if (linkType == 'conversation') {
              final linkId = payload.newRecord['link_id']?.toString() ?? '';
              if (linkId == _activeConversationId) {
                return;
              }
            }

            final title = payload.newRecord['title']?.toString() ?? 'AgriDirect';
            final body = payload.newRecord['body']?.toString() ?? '';
            final linkId = payload.newRecord['link_id']?.toString() ?? '';

            // Show local notification
            await flutterLocalNotificationsPlugin.show(
              payload.newRecord['notification_id'].hashCode,
              title,
              body,
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
              payload: '$linkType:$linkId',
            );
          },
        )
        .subscribe();
  }

  void _stopMobileRealtimeNotifications() {
    _mobileNotificationsSubscription?.unsubscribe();
    _mobileNotificationsSubscription = null;
  }
}
