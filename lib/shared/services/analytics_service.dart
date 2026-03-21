import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

/// Analytics Service - Tracks user activity
/// Monitors clicks, keystrokes, and app usage time
class AnalyticsService {
  // Singleton
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final _client = SupabaseConfig.client;

  // Session tracking
  String? _currentSessionId;
  DateTime? _sessionStartTime;
  Timer? _sessionTimer;

  // Activity counters (for current session)
  int _clicksInSession = 0;
  int _keystrokesInSession = 0;
  final Set<String> _screensVisitedInSession = {};
  String _currentScreen = 'Unknown';

  // Getters for monitoring
  int get clicksInSession => _clicksInSession;
  int get keystrokesInSession => _keystrokesInSession;
  Duration get currentSessionDuration {
    if (_sessionStartTime == null) return Duration.zero;
    return DateTime.now().difference(_sessionStartTime!);
  }

  /// Start a new app session
  Future<void> startSession({
    required String userId,
    String? platform,
    String? deviceInfo,
    String? appVersion,
  }) async {
    try {
      // Close any existing session first
      if (_currentSessionId != null) {
        await endSession(userId: userId);
      }

      _sessionStartTime = DateTime.now();
      _clicksInSession = 0;
      _keystrokesInSession = 0;
      _screensVisitedInSession.clear();

      // Create session record
      final response = await _client
          .from('app_sessions')
          .insert({
            'user_id': userId,
            'start_time': _sessionStartTime!.toIso8601String(),
            'platform': platform ?? _getPlatform(),
            'device_info': deviceInfo,
            'app_version': appVersion,
          })
          .select('session_id')
          .single();

      _currentSessionId = response['session_id'];

      // Start periodic sync (every 30 seconds)
      _sessionTimer?.cancel();
      _sessionTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _syncSessionData(userId),
      );

      debugPrint('📊 Analytics: Session started - $_currentSessionId');
    } catch (e) {
      debugPrint('Analytics: Error starting session: $e');
    }
  }

  /// End current app session
  Future<void> endSession({required String userId}) async {
    if (_currentSessionId == null || _sessionStartTime == null) return;

    try {
      _sessionTimer?.cancel();

      final endTime = DateTime.now();
      final duration = endTime.difference(_sessionStartTime!).inSeconds;

      // Update session record with final data
      await _client
          .from('app_sessions')
          .update({
            'end_time': endTime.toIso8601String(),
            'duration_seconds': duration,
            'clicks_count': _clicksInSession,
            'keystrokes_count': _keystrokesInSession,
            'screens_visited': _screensVisitedInSession.toList(),
          })
          .eq('session_id', _currentSessionId!);

      // Update daily activity log
      await _client.rpc(
        'update_user_activity_log',
        params: {
          'p_user_id': userId,
          'p_clicks': _clicksInSession,
          'p_keystrokes': _keystrokesInSession,
          'p_session_time': duration,
        },
      );

      debugPrint(
        '📊 Analytics: Session ended - Duration: ${duration}s, Clicks: $_clicksInSession, Keystrokes: $_keystrokesInSession',
      );

      // Reset state
      _currentSessionId = null;
      _sessionStartTime = null;
      _clicksInSession = 0;
      _keystrokesInSession = 0;
      _screensVisitedInSession.clear();
    } catch (e) {
      debugPrint('Analytics: Error ending session: $e');
    }
  }

  /// Track a click/tap event
  Future<void> trackClick({
    required String userId,
    String? elementId,
    String? elementType,
  }) async {
    if (_currentSessionId == null) return;

    try {
      _clicksInSession++;

      // Log the event
      await _client.from('user_interaction_events').insert({
        'session_id': _currentSessionId,
        'user_id': userId,
        'event_type': 'click',
        'screen_name': _currentScreen,
        'element_id': elementId,
        'element_type': elementType,
      });

      debugPrint('📊 Analytics: Click tracked - Total: $_clicksInSession');
    } catch (e) {
      debugPrint('Analytics: Error tracking click: $e');
    }
  }

  /// Track keystrokes (typing)
  Future<void> trackKeystrokes({
    required String userId,
    int count = 1,
    String? elementId,
  }) async {
    if (_currentSessionId == null) return;

    try {
      _keystrokesInSession += count;

      // Log the event (batch keystrokes to reduce DB calls)
      if (_keystrokesInSession % 10 == 0) {
        await _client.from('user_interaction_events').insert({
          'session_id': _currentSessionId,
          'user_id': userId,
          'event_type': 'keystroke',
          'screen_name': _currentScreen,
          'element_id': elementId,
          'metadata': {'count': count},
        });
      }

      debugPrint(
        '📊 Analytics: Keystrokes tracked - Total: $_keystrokesInSession',
      );
    } catch (e) {
      debugPrint('Analytics: Error tracking keystrokes: $e');
    }
  }

  /// Track screen/page navigation
  Future<void> trackScreen({
    required String userId,
    required String screenName,
  }) async {
    if (_currentSessionId == null) return;

    try {
      _currentScreen = screenName;
      _screensVisitedInSession.add(screenName);

      // Log page view
      await _client.from('user_interaction_events').insert({
        'session_id': _currentSessionId,
        'user_id': userId,
        'event_type': 'page_view',
        'screen_name': screenName,
      });

      debugPrint('📊 Analytics: Screen tracked - $screenName');
    } catch (e) {
      debugPrint('Analytics: Error tracking screen: $e');
    }
  }

  /// Sync session data periodically
  Future<void> _syncSessionData(String userId) async {
    if (_currentSessionId == null || _sessionStartTime == null) return;

    try {
      final now = DateTime.now();
      final duration = now.difference(_sessionStartTime!).inSeconds;

      // Update session with current counters
      await _client
          .from('app_sessions')
          .update({
            'clicks_count': _clicksInSession,
            'keystrokes_count': _keystrokesInSession,
            'screens_visited': _screensVisitedInSession.toList(),
          })
          .eq('session_id', _currentSessionId!);

      // Update daily log
      await _client.rpc(
        'update_user_activity_log',
        params: {
          'p_user_id': userId,
          'p_clicks': _clicksInSession,
          'p_keystrokes': _keystrokesInSession,
          'p_session_time': duration,
          'p_screen_name': _currentScreen,
        },
      );

      debugPrint(
        '📊 Analytics: Session synced - ${duration}s, ${_clicksInSession} clicks',
      );
    } catch (e) {
      debugPrint('Analytics: Error syncing session: $e');
    }
  }

  /// Get user activity summary
  Future<Map<String, dynamic>?> getUserActivity({
    required String userId,
    DateTime? date,
  }) async {
    try {
      final targetDate = date ?? DateTime.now();
      final response = await _client
          .from('user_activity_logs')
          .select()
          .eq('user_id', userId)
          .eq('date', targetDate.toIso8601String().split('T')[0])
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Analytics: Error fetching activity: $e');
      return null;
    }
  }

  /// Get user's total hours used (all time)
  Future<double> getTotalHoursUsed({required String userId}) async {
    try {
      final response = await _client
          .from('user_activity_logs')
          .select('total_time_seconds')
          .eq('user_id', userId);

      if (response == null || response.isEmpty) return 0.0;

      final totalSeconds = (response as List).fold<int>(
        0,
        (sum, item) => sum + (item['total_time_seconds'] as int? ?? 0),
      );

      return totalSeconds / 3600.0; // Convert to hours
    } catch (e) {
      debugPrint('Analytics: Error calculating total hours: $e');
      return 0.0;
    }
  }

  /// Admin: Get all users activity (last 30 days)
  Future<List<Map<String, dynamic>>> getAllUsersActivity() async {
    try {
      final response = await _client
          .from('v_user_engagement_30d')
          .select()
          .order('total_hours', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Analytics: Error fetching all users activity: $e');
      return [];
    }
  }

  /// Admin: Get currently active sessions
  Future<List<Map<String, dynamic>>> getActiveSessions() async {
    try {
      final response = await _client.from('v_active_sessions').select();

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Analytics: Error fetching active sessions: $e');
      return [];
    }
  }

  String _getPlatform() {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return 'unknown';
  }

  /// Clean up on app dispose
  void dispose() {
    _sessionTimer?.cancel();
  }
}
