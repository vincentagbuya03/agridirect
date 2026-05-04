/// Weather Alert Model
class WeatherAlert {
  final String title;
  final String description;
  final String
  type; // 'frost', 'rain', 'drought', 'wind', 'storm', 'temperature', 'harvest', 'pest', 'disease'
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
      dateTime: DateTime.fromMillisecondsSinceEpoch((json['dt'] as int) * 1000),
      temperature: (json['main']['temp'] as num).toDouble(),
      feelsLike: (json['main']['feels_like'] as num).toDouble(),
      humidity: (json['main']['humidity'] as num).toDouble(),
      windSpeed: (json['wind']['speed'] as num).toDouble(),
      cloudiness: json['clouds']['all'] as int,
      pressure: (json['main']['pressure'] as num).toDouble(),
      description: json['weather'][0]['main'] ?? 'Clear',
      icon: json['weather'][0]['icon'] ?? '01d',
      rainProbability: json['pop'] != null
          ? (json['pop'] as num).toDouble()
          : null,
      rainVolume: json['rain'] != null
          ? (json['rain']['3h'] as num).toDouble()
          : null,
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
    final hour = dateTime.hour == 0 ? 12 : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    final amPm = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${dateTime.minute.toString().padLeft(2, '0')} $amPm';
  }
}

class DailyAdvisory {
  final String day;
  final String condition;
  final String message;
  final bool isSevere;

  DailyAdvisory({
    required this.day,
    required this.condition,
    required this.message,
    required this.isSevere,
  });

  factory DailyAdvisory.fromJson(Map<String, dynamic> json) {
    return DailyAdvisory(
      day: json['day'] ?? '',
      condition: json['condition'] ?? '',
      message: json['message'] ?? '',
      isSevere: json['is_severe'] ?? false,
    );
  }
}

/// Weather Forecast Model for 5-day forecast
class WeatherForecast {
  final String location;
  final List<ForecastData> forecasts;
  final List<WeatherAlert> alerts;
  final List<DailyAdvisory> dailyAdvisories;

  WeatherForecast({
    required this.location,
    required this.forecasts,
    this.alerts = const [],
    this.dailyAdvisories = const [],
  });

  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    final forecasts = <ForecastData>[];
    final list = json['list'] as List<dynamic>;

    for (final item in list) {
      forecasts.add(ForecastData.fromJson(item as Map<String, dynamic>));
    }

    final alerts = <WeatherAlert>[];
    final dailyAdvisories = <DailyAdvisory>[];

    if (json['agridirect_alerts'] != null) {
      final emergency = json['agridirect_alerts'];

      // Parse main alerts
      if (emergency['is_emergency'] == true) {
        // Only surface forecast alerts when the near-term forecast shows a
        // meaningful weather risk, not just generic cloud cover.
        final now = DateTime.now();
        final hasSevereWeather = forecasts.any((f) {
          final hoursUntilForecast = f.dateTime.difference(now).inHours;
          final isNearTerm =
              hoursUntilForecast >= 0 && hoursUntilForecast <= 24;
          final description = f.description.toLowerCase();
          final rainProbability = f.rainProbability ?? 0;
          final rainVolume = f.rainVolume ?? 0;

          if (!isNearTerm) return false;

          final hasSignificantRain =
              rainProbability >= 0.6 ||
              rainVolume >= 1.0 ||
              description.contains('thunderstorm') ||
              (description.contains('rain') && rainProbability >= 0.5);

          return hasSignificantRain || f.windSpeed > 25 || f.temperature > 38;
        });

        if (hasSevereWeather) {
          alerts.add(
            WeatherAlert(
              title: emergency['title'] ?? '⚠️ Advance Warning',
              description:
                  emergency['message'] ?? 'Upcoming weather changes detected.',
              type: emergency['category']?.toLowerCase() ?? 'wind',
              severity: 0.9,
              timestamp: emergency['check_time'] ?? DateTime.now().toString(),
              recommendation:
                  'Plan your farm activities accordingly to minimize crop loss.',
            ),
          );
        }
      }

      // Parse daily advisories
      if (emergency['daily_advisories'] != null) {
        final advisoriesList = emergency['daily_advisories'] as List<dynamic>;
        for (final item in advisoriesList) {
          dailyAdvisories.add(
            DailyAdvisory.fromJson(item as Map<String, dynamic>),
          );
        }
      }
    }

    alerts.addAll(_generateForecastAlerts(forecasts));

    return WeatherForecast(
      location: json['city']?['name'] ?? 'Unknown',
      forecasts: forecasts,
      alerts: alerts,
      dailyAdvisories: dailyAdvisories,
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
    return getHourlyForecastForDate(DateTime.now());
  }

  /// Get hourly forecast for a specific date
  List<ForecastData> getHourlyForecastForDate(DateTime date) {
    return forecasts
        .where(
          (f) =>
              f.dateTime.year == date.year &&
              f.dateTime.month == date.month &&
              f.dateTime.day == date.day,
        )
        .toList();
  }

  static List<WeatherAlert> _generateForecastAlerts(
    List<ForecastData> forecasts,
  ) {
    if (forecasts.isEmpty) return const [];

    final alerts = <WeatherAlert>[];
    final now = DateTime.now();
    final upcoming = forecasts.where((f) {
      final hoursAhead = f.dateTime.difference(now).inHours;
      return hoursAhead >= 0 && hoursAhead <= 72;
    }).toList();

    if (upcoming.isEmpty) return const [];

    final rainCandidate = _firstMatching(upcoming, _isMeaningfulRainForecast);
    if (rainCandidate != null) {
      final rawPop = (rainCandidate.rainProbability ?? 0.0).clamp(0.0, 1.0);
      // OpenWeather sometimes returns pop=1.0; show as 99% to avoid implying certainty.
      var rainChance = (rawPop * 100).round().clamp(0, 99);
      final rainVolume = rainCandidate.rainVolume ?? 0;
      alerts.add(
        WeatherAlert(
          title: 'Rain Alert',
          description:
              'Heavy rainfall is possible ${_timeUntilLabel(now, rainCandidate.dateTime)} with a $rainChance% chance of rain.',
          type: 'rain',
          severity: (rainChance >= 80 || rainVolume >= 4) ? 0.85 : 0.72,
          timestamp: rainCandidate.dateTime.toIso8601String(),
          recommendation:
              'Protect low-lying crops, clear drainage, and reschedule spraying before the rain arrives.',
        ),
      );
    }

    final stormCandidate = _firstMatching(upcoming, _isStormForecast);
    if (stormCandidate != null) {
      alerts.add(
        WeatherAlert(
          title: 'Storm Warning',
          description:
              'Storm conditions may arrive ${_timeUntilLabel(now, stormCandidate.dateTime)}. Strong winds and lightning could disrupt field work.',
          type: 'storm',
          severity: 0.9,
          timestamp: stormCandidate.dateTime.toIso8601String(),
          recommendation:
              'Secure loose farm materials and move exposed produce or tools into shelter.',
        ),
      );
    }

    final highTemp = upcoming.fold<double>(
      -999,
      (maxTemp, item) =>
          item.temperature > maxTemp ? item.temperature : maxTemp,
    );
    final lowTemp = upcoming.fold<double>(
      999,
      (minTemp, item) =>
          item.temperature < minTemp ? item.temperature : minTemp,
    );
    if (highTemp >= 36 || lowTemp <= 6) {
      final isHeat = highTemp >= 36;
      alerts.add(
        WeatherAlert(
          title: 'Temperature Monitoring',
          description: isHeat
              ? 'Temperatures may reach ${highTemp.toStringAsFixed(1)}C within the next 3 days. Heat stress can affect crops and workers.'
              : 'Temperatures may drop to ${lowTemp.toStringAsFixed(1)}C within the next 3 days. Sensitive crops may need protection.',
          type: 'temperature',
          severity: isHeat
              ? (highTemp >= 39 ? 0.86 : 0.68)
              : (lowTemp <= 3 ? 0.85 : 0.68),
          timestamp: now.toIso8601String(),
          recommendation: isHeat
              ? 'Water early, reduce midday field work, and monitor crops for heat stress.'
              : 'Cover sensitive crops and avoid exposing seedlings during the coldest hours.',
        ),
      );
    }

    final harvestRiskCandidate = _firstMatching(
      upcoming,
      _isHarvestRiskForecast,
    );
    if (harvestRiskCandidate != null) {
      alerts.add(
        WeatherAlert(
          title: 'Harvest Risk Alert',
          description:
              'Harvest conditions may worsen ${_timeUntilLabel(now, harvestRiskCandidate.dateTime)} because of wet or windy weather.',
          type: 'harvest',
          severity: 0.78,
          timestamp: harvestRiskCandidate.dateTime.toIso8601String(),
          recommendation:
              'Prioritize mature crops now and postpone tasks that depend on dry soil conditions.',
        ),
      );
    }

    return _deduplicateAlerts(alerts);
  }

  static ForecastData? _firstMatching(
    List<ForecastData> forecasts,
    bool Function(ForecastData forecast) predicate,
  ) {
    for (final forecast in forecasts) {
      if (predicate(forecast)) return forecast;
    }
    return null;
  }

  static bool _isMeaningfulRainForecast(ForecastData forecast) {
    final description = forecast.description.toLowerCase();
    final rainProbability = forecast.rainProbability ?? 0;
    final rainVolume = forecast.rainVolume ?? 0;

    return rainProbability >= 0.65 ||
        rainVolume >= 2.0 ||
        ((description.contains('rain') || description.contains('drizzle')) &&
            rainProbability >= 0.5);
  }

  static bool _isStormForecast(ForecastData forecast) {
    final description = forecast.description.toLowerCase();
    return description.contains('thunderstorm') ||
        forecast.windSpeed >= 35 ||
        (description.contains('storm') && forecast.windSpeed >= 25);
  }

  static bool _isHarvestRiskForecast(ForecastData forecast) {
    return _isMeaningfulRainForecast(forecast) ||
        _isStormForecast(forecast) ||
        forecast.windSpeed >= 28;
  }

  static String _timeUntilLabel(DateTime now, DateTime target) {
    final difference = target.difference(now);
    final hours = difference.inHours;
    
    final timeStr = '${target.hour == 0 ? 12 : (target.hour > 12 ? target.hour - 12 : target.hour)}:00 ${target.hour >= 12 ? 'PM' : 'AM'}';

    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final targetDate = DateTime(target.year, target.month, target.day);

    if (targetDate.isAtSameMomentAs(today)) {
      if (hours <= 1) return 'shortly at $timeStr';
      return 'today at $timeStr';
    }

    if (targetDate.isAtSameMomentAs(tomorrow)) {
      return 'tomorrow at $timeStr';
    }

    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return 'on ${weekdays[target.weekday - 1]} at $timeStr';
  }

  static List<WeatherAlert> _deduplicateAlerts(List<WeatherAlert> alerts) {
    final seen = <String>{};
    final deduped = <WeatherAlert>[];

    for (final alert in alerts) {
      final key = '${alert.type}|${alert.title}|${alert.description}';
      if (seen.add(key)) {
        deduped.add(alert);
      }
    }

    return deduped;
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
    final alerts = <WeatherAlert>[];

    // Check for emergency alerts from our Supabase Edge Function
    if (json['agridirect_alerts'] != null) {
      final emergency = json['agridirect_alerts'];
      if (emergency['is_emergency'] == true) {
        alerts.add(
          WeatherAlert(
            title: emergency['title'] ?? '⚠️ Weather Emergency',
            description:
                emergency['message'] ?? 'Severe weather conditions detected.',
            type: emergency['category']?.toLowerCase() ?? 'wind',
            severity: 1.0,
            timestamp: emergency['check_time'] ?? DateTime.now().toString(),
            recommendation:
                'Please follow the instructions in the description above.',
          ),
        );
      }
    }

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
      alerts: alerts,
    );
  }

  /// Generate alerts based on weather conditions
  List<WeatherAlert> generateAlerts() {
    final alerts = <WeatherAlert>[];
    final now = DateTime.now().toString();
    final normalizedDescription = description.toLowerCase();

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

    // Current rain warning
    if (normalizedDescription.contains('rain') ||
        normalizedDescription.contains('drizzle') ||
        normalizedDescription.contains('thunderstorm')) {
      alerts.add(
        WeatherAlert(
          title: 'Rain Detected',
          description:
              'Current conditions show $description. Wet field conditions may affect farm work.',
          type: 'rain',
          severity: normalizedDescription.contains('thunderstorm') ? 0.85 : 0.7,
          timestamp: now,
          recommendation:
              'Check drainage and adjust harvesting or spraying plans before working the field.',
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
          recommendation:
              'Increase irrigation frequency. Monitor soil moisture.',
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
          recommendation:
              'Secure loose structures. Monitor crops for wind damage.',
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
