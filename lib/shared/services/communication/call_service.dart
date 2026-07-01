import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';

class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  // Fallback only. Supabase's agora-token function returns the active App ID.
  static const String fallbackAgoraAppId = "9003747cc797437bb43b6dbae8be03e2";

  RtcEngine? _engine;
  bool _isInitialized = false;
  RealtimeChannel? _incomingCallChannel;
  String _agoraAppId = fallbackAgoraAppId;

  RtcEngine? get engine => _engine;
  String get agoraAppId => _agoraAppId;
  int get currentAgoraUid => _uidFromUserId(SupabaseConfig.currentUser?.id);

  /// Initialize Agora RTC Engine
  Future<void> initAgora({bool enableVideo = false, String? appId}) async {
    if (appId != null && appId.isNotEmpty) {
      _agoraAppId = appId;
    }

    if (_isInitialized) {
      if (enableVideo) {
        await _engine?.enableVideo();
      }
      await _engine?.enableAudio();
      await _engine?.enableLocalAudio(true);
      return;
    }
    try {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(
        RtcEngineContext(
          appId: _agoraAppId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      if (!kIsWeb) {
        await _engine!.setAudioProfile(
          profile: AudioProfileType.audioProfileSpeechStandard,
          scenario: AudioScenarioType.audioScenarioDefault,
        );
        await _engine!.setDefaultAudioRouteToSpeakerphone(true);
      }

      await _engine!.enableAudio();
      if (enableVideo) {
        await _engine!.enableVideo();
        await _engine!.startPreview();
      } else {
        await _engine!.disableVideo();
      }
      _isInitialized = true;
      debugPrint("Agora RTC Engine Initialized successfully.");
    } catch (e) {
      debugPrint("Error initializing Agora RTC Engine: $e");
    }
  }

  /// Fetch a signed RTC token from the Supabase Edge Function.
  /// Returns empty string if the function is unavailable (project in Testing Mode).
  Future<String> fetchAgoraToken({
    required String channelName,
    int uid = 0,
    String role = 'publisher',
  }) async {
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'agora-token',
        body: {'channelName': channelName, 'uid': uid, 'role': role},
      );
      final appId = response.data?['appId'] as String?;
      if (appId != null && appId.isNotEmpty) {
        _agoraAppId = appId;
      }
      final token = response.data?['token'] as String?;
      if (token != null && token.isNotEmpty) {
        debugPrint(
          'Agora: token fetched for channel=$channelName appId=${_maskAppId(_agoraAppId)}',
        );
        return token;
      }
      debugPrint('Agora: token fetch returned empty — using no-auth mode');
      return '';
    } catch (e) {
      debugPrint(
        'Agora: token fetch failed ($e) — falling back to no-auth mode',
      );
      return '';
    }
  }

  String _maskAppId(String appId) {
    if (appId.length <= 8) return '***';
    return '${appId.substring(0, 4)}...${appId.substring(appId.length - 4)}';
  }

  int _uidFromUserId(String? userId) {
    final source = (userId == null || userId.isEmpty)
        ? DateTime.now().millisecondsSinceEpoch.toString()
        : userId.replaceAll('-', '');
    var hash = 0x811c9dc5;
    for (final codeUnit in source.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  /// Request permissions for audio and video
  Future<bool> requestPermissions({bool requireCamera = false}) async {
    if (kIsWeb) return true; // Web uses browser permission prompts

    final permissionsToRequest = <Permission>[Permission.microphone];
    if (requireCamera) permissionsToRequest.add(Permission.camera);

    final statuses = await permissionsToRequest.request();
    if (requireCamera) {
      return statuses[Permission.microphone] == PermissionStatus.granted &&
          statuses[Permission.camera] == PermissionStatus.granted;
    }
    return statuses[Permission.microphone] == PermissionStatus.granted;
  }

  /// Initiate call session in Supabase DB
  Future<Map<String, dynamic>?> initiateCall({
    required String conversationId,
    required String receiverId,
    required bool isVideo,
  }) async {
    final callerId = SupabaseConfig.currentUser?.id;
    if (callerId == null) {
      debugPrint("Cannot initiate call: currentUser is null");
      return null;
    }

    final channelName =
        'call_${conversationId}_${DateTime.now().millisecondsSinceEpoch}';
    try {
      final response = await SupabaseConfig.client
          .from('calls')
          .insert({
            'conversation_id': conversationId,
            'caller_id': callerId,
            'receiver_id': receiverId,
            'channel_name': channelName,
            'is_video': isVideo,
            'status': 'ringing',
          })
          .select()
          .single();

      // Fetch caller's name
      String callerName = 'AgriDirect User';
      try {
        final callerProfile = await SupabaseConfig.client
            .from('users')
            .select('name')
            .eq('user_id', callerId)
            .maybeSingle();
        if (callerProfile != null && callerProfile['name'] != null) {
          callerName = callerProfile['name'].toString();
        }
      } catch (_) {}

      // Trigger push notification for the call
      try {
        await SupabaseConfig.client.functions.invoke(
          'send-push-notification',
          body: {
            'targetUserId': receiverId,
            'title': 'Incoming ${isVideo ? "Video" : "Voice"} Call',
            'body': '$callerName is calling you...',
            'notificationCode': 'incoming_call',
            'linkType': 'call',
            'linkId': response['call_id']?.toString(),
            'data': {
              'call_id': response['call_id']?.toString() ?? '',
              'channel_name': channelName,
              'caller_name': callerName,
              'is_video': isVideo.toString(),
              'conversation_id': conversationId,
            },
          },
        );
      } catch (fcmError) {
        debugPrint("Error sending call push notification: $fcmError");
      }

      return response;
    } catch (e) {
      debugPrint("Error inserting call record: $e");
      return null;
    }
  }

  /// Update call session status
  Future<void> updateCallStatus(String callId, String status) async {
    try {
      await SupabaseConfig.client
          .from('calls')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('call_id', callId);
      debugPrint("Call status updated to $status for call $callId");
    } catch (e) {
      debugPrint("Error updating call status: $e");
    }
  }

  /// Poll DB once for call status — used as polling fallback alongside Realtime.
  Future<Map<String, dynamic>?> getCallStatus(String callId) async {
    try {
      return await SupabaseConfig.client
          .from('calls')
          .select()
          .eq('call_id', callId)
          .maybeSingle();
    } catch (e) {
      debugPrint('getCallStatus poll error: $e');
      return null;
    }
  }

  /// Listen to call updates (accept, decline, end).
  /// The .where() guard prevents .first from throwing on empty list emissions,
  /// which would silently terminate the stream and stop all future updates.
  Stream<Map<String, dynamic>> listenToCall(String callId) {
    return SupabaseConfig.client
        .from('calls')
        .stream(primaryKey: ['call_id'])
        .eq('call_id', callId)
        .where((list) => list.isNotEmpty)
        .map((list) => list.first);
  }

  /// Listen to incoming call records for current user
  void subscribeToIncomingCalls({
    required Function(Map<String, dynamic> callData) onIncomingCall,
    required Function(Map<String, dynamic> callData) onCallUpdated,
  }) {
    final userId = SupabaseConfig.currentUser?.id;
    if (userId == null) return;

    if (_incomingCallChannel != null) {
      _incomingCallChannel!.unsubscribe();
    }

    _incomingCallChannel = SupabaseConfig.client
        .channel('incoming-calls')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: userId,
          ),
          callback: (payload) {
            if (payload.newRecord['status'] == 'ringing') {
              onIncomingCall(payload.newRecord);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: userId,
          ),
          callback: (payload) {
            onCallUpdated(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// Clean up realtime listener
  void unsubscribeIncomingCalls() {
    _incomingCallChannel?.unsubscribe();
    _incomingCallChannel = null;
  }

  /// Destroy/Release Agora Engine
  Future<void> releaseAgora() async {
    try {
      _isInitialized = false;
      await _engine?.leaveChannel();
      await _engine?.release();
      _engine = null;
      debugPrint("Agora RTC Engine released.");
    } catch (e) {
      debugPrint("Error releasing Agora RTC Engine: $e");
    }
  }
}
