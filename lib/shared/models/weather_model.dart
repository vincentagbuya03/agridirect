/// Weather Alert Model
class WeatherAlert {
  final String title;
  final String description;
  final String type; // 'frost', 'rain', 'drought', 'wind', 'pest', 'disease'
  final double severity; // 0-1, where 1 is critical
  final String timestamp;
  final String? recommendation;

  WeatherAlert({
    required this.title,
    required this.description,
    required this.type,
    required this.severity,
    required this.timestamp,
    this.recommendation,
  });

  // Map alert type to icon
  String get alertIcon {
    switch (type.toLowerCase()) {
      case 'frost':
        return '❄️';
      case 'rain':
        return '🌧️';
      case 'drought':
        return '☀️';
      case 'wind':
        return '💨';
      case 'pest':
        return '🐛';
      case 'disease':
        return '🦠';
      default:
        return '⚠️';
    }
  }

  // Get color based on severity
  String get severityColor {
    if (severity >= 0.75) return 'critical'; // Red
    if (severity >= 0.5) return 'high'; // Orange
    return 'medium'; // Yellow
  }
}

/// Forecast Data Model for individual forecast items
class ForecastData {
  final DateTime dateTime;
  final double temperature;
  final double feelsLike;
  final double humidity;
  final double windSpeed;
  final int cloudiness;
  final double pressure;
  final String description;
  final String icon;
  final double? rainProbability;
  final double? rainVolume;

  ForecastData({
    required this.dateTime,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.cloudiness,
    required this.pressure,
    required this.description,
    required this.icon,
    this.rainProbability,
    this.rainVolume,
  });

  factory ForecastData.fromJson(Map<String, dynamic> json) {
    return ForecastData(
      dateTime: DateTime.fromMillisecondsSinceEpoch(
        (json['dt'] as int) * 1000,
      ),
      temperature: (json['main']['temp'] as num).toDouble(),
      feelsLike: (json['main']['feels_like'] as num).toDouble(),
      humidity: (json['main']['humidity'] as num).toDouble(),
      windSpeed: (json['wind']['speed'] as num).toDouble(),
      cloudiness: json['clouds']['all'] as int,
      pressure: (json['main']['pressure'] as num).toDouble(),
      description: json['weather'][0]['main'] ?? 'Clear',
      icon: json['weather'][0]['icon'] ?? '01d',
      rainProbability: json['pop'] != null ? (json['pop'] as num).toDouble() : null,
      rainVolume: json['rain'] != null ? (json['rain']['3h'] as num).toDouble() : null,
    );
  }

  /// Get day name from dateTime
  String get dayName {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dateTime.weekday - 1];
  }

  /// Get formatted date string
  String get dateString {
    return '${dateTime.month}/${dateTime.day}';
  }

  /// Get formatted time string
  String get timeString {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// Weather Forecast Model for 5-day forecast
class WeatherForecast {
  final String location;
  final List<ForecastData> forecasts;

  WeatherForecast({
    required this.location,
    required this.forecasts,
  });

  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    final forecasts = <ForecastData>[];
    final list = json['list'] as List<dynamic>;

    for (final item in list) {
      forecasts.add(ForecastData.fromJson(item as Map<String, dynamic>));
    }

    return WeatherForecast(
      location: json['city']['name'] ?? 'Unknown',
      forecasts: forecasts,
    );
  }

  /// Get daily forecast (one forecast per day at noon)
  List<ForecastData> getDailyForecast() {
    final daily = <ForecastData>[];
    final processedDays = <int>{};

    for (final forecast in forecasts) {
      if (!processedDays.contains(forecast.dateTime.day) &&
          forecast.dateTime.hour >= 10 &&
          forecast.dateTime.hour <= 14) {
        daily.add(forecast);
        processedDays.add(forecast.dateTime.day);
      }
    }

    return daily;
  }

  /// Get today's hourly forecast
  List<ForecastData> getTodayHourlyForecast() {
    final now = DateTime.now();
    return forecasts
        .where((f) =>
            f.dateTime.year == now.year &&
            f.dateTime.month == now.month &&
            f.dateTime.day == now.day)
        .toList();
  }
}

/// Weather Data Model
class WeatherData {
  final String location;
  final double temperature;
  final double feelsLike;
  final double humidity;
  final double windSpeed;
  final int cloudiness;
  final double pressure;
  final String description;
  final String icon;
  final List<WeatherAlert> alerts;

  WeatherData({
    required this.location,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.cloudiness,
    required this.pressure,
    required this.description,
    required this.icon,
    required this.alerts,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      location: json['name'] ?? 'Unknown',
      temperature: (json['main']['temp'] as num).toDouble(),
      feelsLike: (json['main']['feels_like'] as num).toDouble(),
      humidity: (json['main']['humidity'] as num).toDouble(),
      windSpeed: (json['wind']['speed'] as num).toDouble(),
      cloudiness: json['clouds']['all'] as int,
      pressure: (json['main']['pressure'] as num).toDouble(),
      description: json['weather'][0]['main'] ?? 'Clear',
      icon: json['weather'][0]['icon'] ?? '01d',
      alerts: [],
    );
  }

  /// Generate alerts based on weather conditions
  List<WeatherAlert> generateAlerts() {
    final alerts = <WeatherAlert>[];
    final now = DateTime.now().toString();

    // Frost warning
    if (temperature < 4) {
      alerts.add(
        WeatherAlert(
          title: 'Frost Warning',
          description:
              'Temperature dropping to ${temperature.toStringAsFixed(1)}°C. Frost risk is high.',
          type: 'frost',
          severity: temperature < 0 ? 1.0 : 0.8,
          timestamp: now,
          recommendation:
              'Prepare protective covers for sensitive plants. Use frost protection methods.',
        ),
      );
    }

    // Heavy rain warning
    if (cloudiness > 80 && humidity > 85) {
      alerts.add(
        WeatherAlert(
          title: 'Heavy Rain Expected',
          description:
              'High cloud cover ($cloudiness%) and humidity (${humidity.toStringAsFixed(0)}%) indicate possible rain.',
          type: 'rain',
          severity: 0.7,
          timestamp: now,
          recommendation:
              'Check drainage systems. Ensure fields are not waterlogged.',
        ),
      );
    }

    // Drought warning
    if (temperature > 35 && humidity < 30 && cloudiness < 20) {
      alerts.add(
        WeatherAlert(
          title: 'Drought Risk',
          description:
              'High temperature (${temperature.toStringAsFixed(1)}°C) with low humidity. Water stress likely.',
          type: 'drought',
          severity: 0.8,
          timestamp: now,
          recommendation: 'Increase irrigation frequency. Monitor soil moisture.',
        ),
      );
    }

    // High wind warning
    if (windSpeed > 30) {
      alerts.add(
        WeatherAlert(
          title: 'Strong Wind Warning',
          description:
              'Wind speed at ${windSpeed.toStringAsFixed(1)} km/h. Crop damage risk.',
          type: 'wind',
          severity: 0.85,
          timestamp: now,
          recommendation: 'Secure loose structures. Monitor crops for wind damage.',
        ),
      );
    }

    // High humidity warning (disease risk)
    if (humidity > 90 && temperature > 20) {
      alerts.add(
        WeatherAlert(
          title: 'Disease Risk Alert',
          description:
              'High humidity (${humidity.toStringAsFixed(0)}%) and warm temperature favor fungal diseases.',
          type: 'disease',
          severity: 0.7,
          timestamp: now,
          recommendation:
              'Apply preventive fungicide. Increase air circulation.',
        ),
      );
    }

    return alerts;
  }
}
