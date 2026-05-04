import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../auth/auth_service.dart';
import '../core/supabase_config.dart';
import '../community/notification_service.dart';
import '../integration/weather_service.dart';
import '../../models/weather_model.dart';

/// Service to monitor weather conditions and notify users of bad weather
class WeatherAlertService {
  static final WeatherAlertService _instance = WeatherAlertService._internal();
  factory WeatherAlertService() => _instance;
  WeatherAlertService._internal();

  final _auth = AuthService();
  final _weather = WeatherService();
  final _notifications = NotificationService();
  bool _isChecking = false;

  /// Trigger a weather check and notify the user if conditions are bad
  Future<void> checkWeatherAndNotify() async {
    if (_isChecking || !_auth.isLoggedIn) return;

    try {
      _isChecking = true;
      debugPrint('🌤️ Starting weather alert check...');

      double? lat;
      double? lon;
      String locationName = 'your area';

      if (_auth.isViewingAsFarmer || _auth.isSeller) {
        // For farmers, use their registered farm location
        final farmerProfile = await SupabaseDatabase.getFarmerProfile(_auth.userId);
        if (farmerProfile != null) {
          lat = (farmerProfile['farm_latitude'] as num?)?.toDouble();
          lon = (farmerProfile['farm_longitude'] as num?)?.toDouble();
          locationName = farmerProfile['farm_name'] ?? 'your farm';
        }
      }

      // If no farm location found or user is a consumer, use current GPS
      if (lat == null || lon == null) {
        final position = await _getCurrentPosition();
        if (position != null) {
          lat = position.latitude;
          lon = position.longitude;
          locationName = 'your current location';
        }
      }

      if (lat == null || lon == null) {
        debugPrint('⚠️ Could not determine location for weather check');
        return;
      }

      // Fetch current weather and forecast alerts
      final weatherData = await _weather.getWeatherByCoordinates(
        latitude: lat,
        longitude: lon,
      );
      final weatherForecast = await _weather.getForecastByCoordinates(
        latitude: lat,
        longitude: lon,
      );

      final combinedAlerts = _mergeAlerts(
        weatherData?.alerts ?? const [],
        weatherForecast?.alerts ?? const [],
      );

      if (combinedAlerts.isNotEmpty) {
        for (final alert in combinedAlerts) {
          if (alert.severity >= 0.65) {
            await _showWeatherNotification(alert, locationName);
          }
        }
      }

      debugPrint('🌤️ Weather alert check completed');
    } catch (e) {
      debugPrint('❌ Error in weather alert check: $e');
    } finally {
      _isChecking = false;
    }
  }

  /// Test weather notification (for development testing)
  Future<void> testWeatherNotification() async {
    final mockAlert = WeatherAlert(
      title: 'Test Storm Warning',
      description: 'This is a test notification to verify weather alerts are working.',
      type: 'rain',
      severity: 0.9,
      timestamp: DateTime.now().toString(),
      recommendation: 'Check your crops and secure loose items.',
    );
    await _showWeatherNotification(mockAlert, 'Test Location');
  }

  List<WeatherAlert> _mergeAlerts(
    List<WeatherAlert> currentAlerts,
    List<WeatherAlert> forecastAlerts,
  ) {
    final merged = <WeatherAlert>[];
    final seen = <String>{};

    void addAlert(WeatherAlert alert) {
      final key = '${alert.type}|${alert.title}|${alert.description}';
      if (seen.add(key)) {
        merged.add(alert);
      }
    }

    for (final alert in [...currentAlerts, ...forecastAlerts]) {
      addAlert(alert);
    }

    merged.sort((a, b) => b.severity.compareTo(a.severity));
    return merged;
  }

  /// Get the current GPS position with permission handling
  Future<Position?> _getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
    } catch (e) {
      debugPrint('❌ Error getting current position: $e');
      return null;
    }
  }

  /// Show a local notification for a weather alert and save to database
  Future<void> _showWeatherNotification(
    WeatherAlert alert,
    String locationName,
  ) async {
    final title = '${alert.alertIcon} ${alert.title}';
    final now = DateTime.now();
    final timeStr = '${now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour)}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
    final body = '${alert.description}\nChecked at $timeStr for $locationName.';

    // 1. Save to database for history
    if (_auth.userId.isNotEmpty) {
      await _notifications.insertNotification(
        userId: _auth.userId,
        title: title,
        content: body,
        type: 'weather',
      );
    }

    // 2. Show local notification
    await _notifications.flutterLocalNotificationsPlugin.show(
      alert.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationService.channelId,
          NotificationService.channelName,
          channelDescription: NotificationService.channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF13EC5B), // Brand green
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
