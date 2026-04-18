import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/supabase_config.dart';

/// Analytics Service - Tracks app usage time only
/// Only monitors session duration (hours used)
class AnalyticsService {
  // Singleton
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final _client = SupabaseConfig.client;

  // Session tracking
  String? _currentSessionId;
  String? _currentUserId;
  DateTime? _sessionStartTime;
  Timer? _sessionTimer;
  String? _cachedAppVersion;
  String? _cachedDeviceInfo;

  // Getters for monitoring
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
      if (_currentSessionId != null && _currentUserId == userId) {
        return;
      }

      // Close any existing session first
      if (_currentSessionId != null) {
        await endSession(userId: _currentUserId ?? userId);
      }

      _sessionStartTime = DateTime.now();
      _currentUserId = userId;

      final resolvedAppVersion = appVersion ?? await _resolveAppVersion();
      final resolvedDeviceInfo = deviceInfo ?? await _resolveDeviceInfo();

      // Create session record
      final response = await _client
          .from('app_sessions')
          .insert({
            'user_id': userId,
            'start_time': _sessionStartTime!.toIso8601String(),
            'platform': platform ?? _getPlatform(),
            'device_info': resolvedDeviceInfo,
            'app_version': resolvedAppVersion,
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

      // Update session record with duration only (no interaction data)
      await _client
          .from('app_sessions')
          .update({
            'end_time': endTime.toIso8601String(),
            'duration_seconds': duration,
          })
          .eq('session_id', _currentSessionId!);

      debugPrint('📊 Analytics: Session ended - Duration: ${duration}s');

      // Reset state
      _currentSessionId = null;
      _currentUserId = null;
      _sessionStartTime = null;
    } catch (e) {
      debugPrint('Analytics: Error ending session: $e');
    }
  }

  /// Sync session data periodically
  Future<void> _syncSessionData(String userId) async {
    if (_currentSessionId == null || _sessionStartTime == null) return;

    try {
      final now = DateTime.now();
      final duration = now.difference(_sessionStartTime!).inSeconds;

      // Update session with duration only
      await _client
          .from('app_sessions')
          .update({'duration_seconds': duration})
          .eq('session_id', _currentSessionId!);

      debugPrint('📊 Analytics: Session synced - ${duration}s');
    } catch (e) {
      debugPrint('Analytics: Error syncing session: $e');
    }
  }

  /// Get user's total hours used (all time)
  Future<double> getTotalHoursUsed({required String userId}) async {
    try {
      final response = await _client
          .from('app_sessions')
          .select('duration_seconds')
          .eq('user_id', userId)
          .filter('end_time', 'not.is', 'null'); // Only completed sessions

      if (response.isEmpty) return 0.0;

      final totalSeconds = (response as List).fold<int>(
        0,
        (sum, item) => sum + (item['duration_seconds'] as int? ?? 0),
      );

      return totalSeconds / 3600.0; // Convert to hours
    } catch (e) {
      debugPrint('Analytics: Error calculating total hours: $e');
      return 0.0;
    }
  }

  /// Admin: Get all users activity (total hours used, last 30 days)
  Future<List<Map<String, dynamic>>> getAllUsersActivity() async {
    try {
      // Get sessions from last 30 days grouped by user
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      final response = await _client
          .from('app_sessions')
          .select('user_id, duration_seconds')
          .gte('start_time', thirtyDaysAgo.toIso8601String())
          .filter('end_time', 'not.is', 'null');

      if (response.isEmpty) return [];

      // Aggregate by user
      final Map<String, int> userTotalSeconds = {};
      for (final session in response) {
        final userId = session['user_id'] as String;
        final duration = session['duration_seconds'] as int? ?? 0;
        userTotalSeconds[userId] = (userTotalSeconds[userId] ?? 0) + duration;
      }

      // Convert to hours and sort
      final result = userTotalSeconds.entries
          .map((e) => {'user_id': e.key, 'total_hours': e.value / 3600.0})
          .toList();

      result.sort(
        (a, b) =>
            (b['total_hours'] as double).compareTo(a['total_hours'] as double),
      );

      return result;
    } catch (e) {
      debugPrint('Analytics: Error fetching all users activity: $e');
      return [];
    }
  }

  /// Admin: Get currently active sessions
  Future<List<Map<String, dynamic>>> getActiveSessions() async {
    try {
      final response = await _client
          .from('app_sessions')
          .select()
          .filter('end_time', 'is', 'null'); // Sessions without end_time

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
    if (defaultTargetPlatform == TargetPlatform.macOS) return 'macos';
    if (defaultTargetPlatform == TargetPlatform.windows) return 'windows';
    if (defaultTargetPlatform == TargetPlatform.linux) return 'linux';
    return 'unknown';
  }

  Future<String> _resolveAppVersion() async {
    if (_cachedAppVersion != null && _cachedAppVersion!.isNotEmpty) {
      return _cachedAppVersion!;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = packageInfo.version.trim();
      final buildNumber = packageInfo.buildNumber.trim();
      _cachedAppVersion = buildNumber.isNotEmpty && buildNumber != '0'
          ? '$version+$buildNumber'
          : version;
    } catch (e) {
      debugPrint('Analytics: Error resolving app version: $e');
      _cachedAppVersion = 'unknown';
    }

    return _cachedAppVersion!;
  }

  Future<String> _resolveDeviceInfo() async {
    if (_cachedDeviceInfo != null && _cachedDeviceInfo!.isNotEmpty) {
      return _cachedDeviceInfo!;
    }

    try {
      final deviceInfo = DeviceInfoPlugin();

      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        _cachedDeviceInfo = [
          webInfo.browserName.name,
          webInfo.userAgent ?? '',
          webInfo.platform ?? '',
        ].where((part) => part.trim().isNotEmpty).join(' | ');
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        _cachedDeviceInfo = [
          'Android ${androidInfo.version.release}',
          androidInfo.model,
          androidInfo.manufacturer,
        ].where((part) => part.trim().isNotEmpty).join(' | ');
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _cachedDeviceInfo = [
          'iOS ${iosInfo.systemVersion}',
          iosInfo.utsname.machine,
          iosInfo.model,
        ].where((part) => part.trim().isNotEmpty).join(' | ');
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        _cachedDeviceInfo = [
          windowsInfo.computerName,
          windowsInfo.numberOfCores.toString(),
          windowsInfo.systemMemoryInMegabytes.toString(),
        ].where((part) => part.trim().isNotEmpty).join(' | ');
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        final macInfo = await deviceInfo.macOsInfo;
        _cachedDeviceInfo = [
          macInfo.model,
          macInfo.osRelease,
          macInfo.computerName,
        ].where((part) => part.trim().isNotEmpty).join(' | ');
      } else if (defaultTargetPlatform == TargetPlatform.linux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        _cachedDeviceInfo = [
          linuxInfo.prettyName,
          linuxInfo.name,
          linuxInfo.version,
        ].where((part) => (part ?? '').trim().isNotEmpty).join(' | ');
      }

      _cachedDeviceInfo = (_cachedDeviceInfo ?? '').trim();
      if (_cachedDeviceInfo!.isEmpty) {
        _cachedDeviceInfo = _getPlatform();
      }
    } catch (e) {
      debugPrint('Analytics: Error resolving device info: $e');
      _cachedDeviceInfo = _getPlatform();
    }

    return _cachedDeviceInfo!;
  }

  /// Clean up on app dispose
  void dispose() {
    _sessionTimer?.cancel();
  }
}
