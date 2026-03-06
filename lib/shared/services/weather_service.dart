import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../models/weather_model.dart';

/// Weather Service using OpenWeatherMap API
class WeatherService {
  // Add your OpenWeatherMap API key here
  // Get free key from: https://openweathermap.org/api
  static const String _apiKey = 'd519e73b738173d3d9a7bd5737ea3992';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5/weather';
  static const String _forecastUrl = 'https://api.openweathermap.org/data/2.5/forecast';

  static final WeatherService _instance = WeatherService._internal();

  factory WeatherService() => _instance;

  WeatherService._internal();

  /// Fetch weather data for a location
  /// latitude: The latitude of the location
  /// longitude: The longitude of the location
  Future<WeatherData?> getWeatherByCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final url =
          '$_baseUrl?lat=$latitude&lon=$longitude&units=metric&appid=$_apiKey';
      debugPrint('Weather API URL: $url');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('Timeout', 408),
      );

      debugPrint('Weather API response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final weatherData = WeatherData.fromJson(jsonData);
        debugPrint('Successfully fetched weather: ${weatherData.temperature}°C at ${weatherData.location}');

        // Generate alerts based on weather conditions
        final weatherDataWithAlerts = WeatherData(
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

        return weatherDataWithAlerts;
      } else if (response.statusCode == 401) {
        debugPrint('Invalid API key: ${response.body}');
        return _getDefaultWeatherData();
      } else {
        debugPrint('Weather API error: ${response.statusCode} - ${response.body}');
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
      final url = '$_baseUrl?q=$cityName&units=metric&appid=$_apiKey';

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('Timeout', 408),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final weatherData = WeatherData.fromJson(jsonData);

        final weatherDataWithAlerts = WeatherData(
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

        return weatherDataWithAlerts;
      } else {
        debugPrint('Weather API error: ${response.statusCode}');
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
      final url =
          '$_forecastUrl?lat=$latitude&lon=$longitude&units=metric&appid=$_apiKey';
      debugPrint('Forecast API URL: $url');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('Timeout', 408),
      );

      debugPrint('Forecast API response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final forecast = WeatherForecast.fromJson(jsonData);
        debugPrint(
          'Successfully fetched forecast: ${forecast.forecasts.length} items for ${forecast.location}',
        );
        return forecast;
      } else if (response.statusCode == 401) {
        debugPrint('Invalid API key: ${response.body}');
        return _getDefaultForecast();
      } else {
        debugPrint('Forecast API error: ${response.statusCode} - ${response.body}');
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
      final url = '$_forecastUrl?q=$cityName&units=metric&appid=$_apiKey';
      debugPrint('Forecast by city URL: $url');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('Timeout', 408),
      );

      debugPrint('Forecast API response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final forecast = WeatherForecast.fromJson(jsonData);
        debugPrint(
          'Successfully fetched forecast: ${forecast.forecasts.length} items for ${forecast.location}',
        );
        return forecast;
      } else {
        debugPrint('Forecast API error: ${response.statusCode}');
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

    return WeatherForecast(
      location: 'Default Location',
      forecasts: forecasts,
    );
  }

  /// Get default/mock weather data (fallback when API is not available)
  WeatherData _getDefaultWeatherData() {
    final now = DateTime.now();
    // Simulate realistic daily temperature curve using sine wave
    // Temperature ranges from ~16°C at 6 AM to ~28°C at 2 PM
    final hour = now.hour.toDouble();
    final temp = 22 + 6 * math.sin((hour - 6) * math.pi / 12);

    final weatherData = WeatherData(
      location: 'Default Location',
      temperature: temp.clamp(10.0, 35.0),
      feelsLike: (temp - 1).clamp(10.0, 35.0),
      humidity: 65 + (now.second % 30),
      windSpeed: 12 + (now.minute % 20),
      cloudiness: 40 + (now.second % 40),
      pressure: 1013,
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
