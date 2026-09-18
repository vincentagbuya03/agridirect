import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../auth/auth_service.dart';
import '../core/supabase_config.dart';
import '../community/notification_service.dart';
import '../integration/weather_service.dart';
import '../ai/ai_service.dart';
import '../../models/weather_model.dart';

/// Service to monitor weather conditions and notify users of bad weather
class WeatherAlertService {
  static final WeatherAlertService _instance = WeatherAlertService._internal();
  factory WeatherAlertService() => _instance;
  WeatherAlertService._internal();

  final _auth = AuthService();
  final _weather = WeatherService();
  final _notifications = NotificationService();
  final _ai = AiService();
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
      String? specialty;

      if (_auth.isViewingAsFarmer || _auth.isSeller) {
        // For farmers, use their registered farm location
        final farmerProfile = await SupabaseDatabase.getFarmerProfile(_auth.userId);
        if (farmerProfile != null) {
          lat = (farmerProfile['farm_latitude'] as num?)?.toDouble();
          lon = (farmerProfile['farm_longitude'] as num?)?.toDouble();
          locationName = farmerProfile['farm_name'] ?? 'your farm';
          specialty = farmerProfile['specialty']?.toString();
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
            await _showWeatherNotification(
              alert,
              locationName,
              specialty: specialty,
              weatherData: weatherData,
            );
          }
        }
      } else if (weatherData != null) {
        // Dynamic advisory for notable conditions even if no severe storm alert is active
        String alertType = 'daily_summary';
        String title = 'Daily Farm Weather Update';
        double severity = 0.5;

        if (weatherData.temperature >= 34.0) {
          alertType = 'heat';
          title = 'Extreme Heat Advisory';
          severity = 0.75;
        } else if (weatherData.windSpeed >= 28.0) {
          alertType = 'wind';
          title = 'Strong Wind Advisory';
          severity = 0.75;
        } else if (weatherData.precipitationRate > 0.5) {
          alertType = 'rain';
          title = 'Rainfall Advisory';
          severity = 0.7;
        } else if (weatherData.temperature >= 26.0 && weatherData.precipitationRate == 0) {
          alertType = 'clear';
          title = 'Optimal Harvest & Drying Advisory';
          severity = 0.6;
        }

        final dynamicAlert = WeatherAlert(
          title: title,
          description: '${weatherData.description}, ${weatherData.temperature.toStringAsFixed(0)}°C near $locationName.',
          type: alertType,
          severity: severity,
          timestamp: DateTime.now().toString(),
          recommendation: 'Monitor crop status and plan field activities accordingly.',
        );

        await _showWeatherNotification(
          dynamicAlert,
          locationName,
          specialty: specialty,
          weatherData: weatherData,
        );
      }

      debugPrint('🌤️ Weather alert check completed');
    } catch (e) {
      debugPrint('❌ Error in weather alert check: $e');
    } finally {
      _isChecking = false;
    }
  }

  /// Test dynamic weather notification powered by OpenRouter (for development and admin testing)
  Future<void> testWeatherNotification({
    String type = 'clear',
    String? customLocation,
  }) async {
    final loc = customLocation ?? 'San Carlos City Farm';
    final now = DateTime.now().toString();

    WeatherAlert alert;
    WeatherData mockData;

    switch (type.toLowerCase()) {
      case 'storm':
      case 'typhoon':
        alert = WeatherAlert(
          title: 'Severe Storm Warning',
          description: 'Tropical cyclone telemetry detected. Gusts up to 65 km/h.',
          type: 'storm',
          severity: 0.95,
          timestamp: now,
        );
        mockData = WeatherData(
          temperature: 26.0,
          feelsLike: 27.0,
          humidity: 92.0,
          windSpeed: 62.0,
          cloudiness: 95,
          description: 'Tropical Storm / Heavy Gale',
          icon: '11d',
          pressure: 988.0,
          precipitationRate: 15.0,
          location: loc,
          alerts: [alert],
        );
        break;
      case 'heat':
        alert = WeatherAlert(
          title: 'Extreme Heat Advisory',
          description: 'Temperatures peaking above 36°C with intense solar radiation.',
          type: 'heat',
          severity: 0.8,
          timestamp: now,
        );
        mockData = WeatherData(
          temperature: 36.5,
          feelsLike: 42.0,
          humidity: 55.0,
          windSpeed: 10.0,
          cloudiness: 10,
          description: 'Blistering Sun & High Heat Index',
          icon: '01d',
          pressure: 1009.0,
          precipitationRate: 0.0,
          location: loc,
          alerts: [alert],
        );
        break;
      case 'wind':
        alert = WeatherAlert(
          title: 'Strong Wind Warning',
          description: 'Brisk monsoonal gusts across open fields.',
          type: 'wind',
          severity: 0.75,
          timestamp: now,
        );
        mockData = WeatherData(
          temperature: 28.0,
          feelsLike: 29.0,
          humidity: 70.0,
          windSpeed: 38.0,
          cloudiness: 40,
          description: 'Strong Wind Gusts',
          icon: '50d',
          pressure: 1010.0,
          precipitationRate: 0.0,
          location: loc,
          alerts: [alert],
        );
        break;
      case 'rain':
        alert = WeatherAlert(
          title: 'Heavy Rain Warning',
          description: 'Persistent monsoonal rains over agrarian lowlands.',
          type: 'rain',
          severity: 0.85,
          timestamp: now,
        );
        mockData = WeatherData(
          temperature: 25.0,
          feelsLike: 26.0,
          humidity: 90.0,
          windSpeed: 18.0,
          cloudiness: 90,
          description: 'Heavy Rain Showers',
          icon: '10d',
          pressure: 1006.0,
          precipitationRate: 8.5,
          location: loc,
          alerts: [alert],
        );
        break;
      case 'clear':
      default:
        alert = WeatherAlert(
          title: 'Optimal Harvest Window',
          description: 'Clear sunny skies and dry breeze across the fields.',
          type: 'clear',
          severity: 0.6,
          timestamp: now,
        );
        mockData = WeatherData(
          temperature: 30.0,
          feelsLike: 32.0,
          humidity: 60.0,
          windSpeed: 12.0,
          cloudiness: 5,
          description: 'Clear Skies & Bright Sunshine',
          icon: '01d',
          pressure: 1012.0,
          precipitationRate: 0.0,
          location: loc,
          alerts: [alert],
        );
        break;
    }

    await _showWeatherNotification(alert, loc, weatherData: mockData);
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
    String locationName, {
    String? specialty,
    WeatherData? weatherData,
  }) async {
    String finalTitle = '${alert.alertIcon} ${alert.title}';
    String finalBody = alert.description;

    // Enhance with OpenRouter dynamic description if weather data is available
    if (weatherData != null) {
      try {
        final rainProb = alert.type == 'rain' || alert.type == 'storm'
            ? (weatherData.precipitationRate > 0 ? 0.85 : 0.65)
            : (weatherData.precipitationRate > 0 ? 0.35 : 0.05);

        final aiResult = await _ai
            .generateWeatherPushDescription(
              farmName: locationName,
              specialty: specialty,
              condition: weatherData.description,
              temperature: weatherData.temperature,
              rainProbability: rainProb,
              windSpeed: weatherData.windSpeed,
              alertType: alert.type,
            )
            .timeout(const Duration(seconds: 10));

        if (aiResult['title'] != null && aiResult['body'] != null) {
          finalTitle = AiService.sanitizeWeatherCopy(aiResult['title']!);
          finalBody = AiService.sanitizeWeatherCopy(aiResult['body']!);
        }
      } catch (e) {
        debugPrint('Dynamic weather description fallback: $e');
      }
    }

    final fullBodyText = finalBody;

    // 1. Save to database for history
    if (_auth.userId.isNotEmpty) {
      await _notifications.insertNotification(
        userId: _auth.userId,
        title: finalTitle,
        content: fullBodyText,
        type: 'weather',
        linkType: 'weather',
      );
    }

    // 2. Show local notification
    await _notifications.flutterLocalNotificationsPlugin.show(
      alert.hashCode,
      finalTitle,
      fullBodyText,
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
      payload: 'weather:radar',
    );
  }
}
