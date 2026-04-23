import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import '../../models/weather_model.dart';
import '../core/supabase_config.dart';

/// Weather Service using OpenWeatherMap API
class WeatherService {
  /// Fetch weather data for a location
  Future<WeatherData?> getWeatherByCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      debugPrint('Fetching weather via Supabase Edge Function...');

      final response = await SupabaseConfig.client.functions.invoke(
        'get-weather',
        body: {
          'lat': latitude,
          'lon': longitude,
          'type': 'current',
          'userId': SupabaseConfig.client.auth.currentUser?.id,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.status == 200) {
        final jsonData = response.data;
        final weatherData = WeatherData.fromJson(jsonData);

        // Merge backend emergency alerts with locally generated alerts
        final allAlerts = [
          ...weatherData.alerts, // Backend alerts (Typhoon, etc)
          ...weatherData.generateAlerts(), // Local alerts (Frost, Humidity, etc)
        ];

        return WeatherData(
          location: weatherData.location,
          temperature: weatherData.temperature,
          feelsLike: weatherData.feelsLike,
          humidity: weatherData.humidity,
          windSpeed: weatherData.windSpeed,
          cloudiness: weatherData.cloudiness,
          pressure: weatherData.pressure,
          description: weatherData.description,
          icon: weatherData.icon,
          alerts: allAlerts,
        );
      } else {
        debugPrint('Weather Edge Function error: ${response.status}');
        return _getDefaultWeatherData();
      }
    } catch (e) {
      debugPrint('Weather service error: $e');
      return _getDefaultWeatherData();
    }
  }

  /// Fetch weather by city name
  Future<WeatherData?> getWeatherByCity(String cityName) async {
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'get-weather',
        body: {
          'city': cityName,
          'type': 'current',
          'userId': SupabaseConfig.client.auth.currentUser?.id,
        },
      );

      if (response.status == 200) {
        final jsonData = response.data;
        final weatherData = WeatherData.fromJson(jsonData);

        final allAlerts = [
          ...weatherData.alerts,
          ...weatherData.generateAlerts(),
        ];

        return WeatherData(
          location: weatherData.location,
          temperature: weatherData.temperature,
          feelsLike: weatherData.feelsLike,
          humidity: weatherData.humidity,
          windSpeed: weatherData.windSpeed,
          cloudiness: weatherData.cloudiness,
          pressure: weatherData.pressure,
          description: weatherData.description,
          icon: weatherData.icon,
          alerts: allAlerts,
        );
      } else {
        debugPrint('Weather API error: ${response.status}');
        return _getDefaultWeatherData();
      }
    } catch (e) {
      debugPrint('Weather service error: $e');
      return _getDefaultWeatherData();
    }
  }

  /// Fetch 5-day forecast by coordinates
  Future<WeatherForecast?> getForecastByCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'get-weather',
        body: {
          'lat': latitude,
          'lon': longitude,
          'type': 'forecast',
          'userId': SupabaseConfig.client.auth.currentUser?.id,
        },
      );

      if (response.status == 200) {
        return WeatherForecast.fromJson(response.data);
      } else {
        debugPrint('Forecast Edge Function error: ${response.status}');
        return _getDefaultForecast();
      }
    } catch (e) {
      debugPrint('Forecast service error: $e');
      return _getDefaultForecast();
    }
  }

  /// Fetch 5-day forecast by city name
  Future<WeatherForecast?> getForecastByCity(String cityName) async {
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'get-weather',
        body: {
          'city': cityName,
          'type': 'forecast',
          'userId': SupabaseConfig.client.auth.currentUser?.id,
        },
      );

      if (response.status == 200) {
        return WeatherForecast.fromJson(response.data);
      } else {
        debugPrint('Forecast API error: ${response.status}');
        return _getDefaultForecast();
      }
    } catch (e) {
      debugPrint('Forecast service error: $e');
      return _getDefaultForecast();
    }
  }

  /// Get default/mock forecast data (fallback when API is not available)
  WeatherForecast _getDefaultForecast() {
    final forecasts = <ForecastData>[];
    final now = DateTime.now();

    // Generate 40 forecast items (5 days * 8 items per day, 3-hour intervals)
    for (int i = 0; i < 40; i++) {
      final forecastTime = now.add(Duration(hours: i * 3));
      final hour = forecastTime.hour.toDouble();
      final temp = 22 + 6 * math.sin((hour - 6) * math.pi / 12);
      final rainChance = (math.sin(i * 0.5) * 0.3 + 0.3).clamp(0.0, 0.8);

      forecasts.add(
        ForecastData(
          dateTime: forecastTime,
          temperature: temp.clamp(15.0, 30.0),
          feelsLike: (temp - 1).clamp(15.0, 30.0),
          humidity: (65 + (i % 30)).toDouble(),
          windSpeed: 12 + (i % 20),
          cloudiness: (40 + (i % 40)).toInt(),
          pressure: 1013.0,
          description: 'Partly Cloudy',
          icon: '02d',
          rainProbability: rainChance,
          rainVolume: rainChance > 0.5 ? rainChance * 5 : null,
        ),
      );
    }

    return WeatherForecast(location: 'San Carlos City, Pangasinan', forecasts: forecasts);
  }

  /// Get default/mock weather data (fallback when API is not available)
  WeatherData _getDefaultWeatherData() {
    final now = DateTime.now();
    // Simulate realistic daily temperature curve using sine wave
    // Temperature ranges from ~24°C at 6 AM to ~34°C at 2 PM (Tropical)
    final hour = now.hour.toDouble();
    final temp = 29 + 5 * math.sin((hour - 6) * math.pi / 12);

    final weatherData = WeatherData(
      location: 'San Carlos City, Pangasinan',
      temperature: temp.clamp(24.0, 36.0),
      feelsLike: (temp + 2).clamp(24.0, 38.0),
      humidity: 75 + (now.second % 15),
      windSpeed: 8 + (now.minute % 10),
      cloudiness: 40 + (now.second % 40),
      pressure: 1010,
      description: 'Partly Cloudy',
      icon: '02d',
      alerts: [],
    );

    // Generate alerts
    return WeatherData(
      location: weatherData.location,
      temperature: weatherData.temperature,
      feelsLike: weatherData.feelsLike,
      humidity: weatherData.humidity,
      windSpeed: weatherData.windSpeed,
      cloudiness: weatherData.cloudiness,
      pressure: weatherData.pressure,
      description: weatherData.description,
      icon: weatherData.icon,
      alerts: weatherData.generateAlerts(),
    );
  }
}
