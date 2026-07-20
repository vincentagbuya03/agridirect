import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'weather_map_screen.dart';
import '../../../shared/models/weather_model.dart';
import '../../../shared/styles/app_theme.dart';

class WeatherDetailScreen extends StatefulWidget {
  final WeatherData weatherData;
  final WeatherForecast? forecast;
  final Position? currentPosition;
  final Future<void> Function() onRefresh;

  const WeatherDetailScreen({
    super.key,
    required this.weatherData,
    this.forecast,
    this.currentPosition,
    required this.onRefresh,
  });

  @override
  State<WeatherDetailScreen> createState() => _WeatherDetailScreenState();
}

class _WeatherDetailScreenState extends State<WeatherDetailScreen> {
  int? _expandedIndex;
  bool _isRefreshing = false;

  void _launchWeatherMap() {
    final lat = widget.currentPosition?.latitude ?? 15.4828;
    final lon = widget.currentPosition?.longitude ?? 120.7120;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WeatherMapScreen(
          latitude: lat,
          longitude: lon,
          locationName: widget.weatherData.location,
          temperature: widget.weatherData.temperature,
          weatherDescription: widget.weatherData.description,
        ),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  IconData _getWeatherIcon(String description) {
    final desc = description.toLowerCase();
    if (desc.contains('rain')) return Icons.umbrella_rounded;
    if (desc.contains('storm')) return Icons.thunderstorm_rounded;
    if (desc.contains('wind')) return Icons.air_rounded;
    if (desc.contains('clear') || desc.contains('sun'))
      return Icons.wb_sunny_rounded;
    if (desc.contains('cloud')) return Icons.cloud_rounded;
    return Icons.wb_cloudy_rounded;
  }

  // Agronomic calculations
  String _getSprayingStatus(double windSpeed, String description) {
    final cleanDesc = description.toLowerCase();
    if (windSpeed > 25 ||
        cleanDesc.contains('rain') ||
        cleanDesc.contains('storm')) {
      return 'UNSAFE';
    }
    if (windSpeed > 15 || cleanDesc.contains('drizzle')) {
      return 'CAUTION';
    }
    return 'SAFE';
  }

  String _getHarvestingStatus(String description, double humidity) {
    final cleanDesc = description.toLowerCase();
    if (cleanDesc.contains('rain') ||
        cleanDesc.contains('storm') ||
        humidity > 85) {
      return 'POOR';
    }
    if (humidity > 70 || cleanDesc.contains('cloud')) {
      return 'FAIR';
    }
    return 'EXCELLENT';
  }

  String _getIrrigationStatus(double temperature, double humidity) {
    if (temperature > 33 && humidity < 45) {
      return 'HIGH NEED';
    }
    if (temperature > 28 && humidity < 60) {
      return 'MODERATE';
    }
    return 'NO NEED';
  }

  String _getDiseaseRiskStatus(double humidity, double temperature) {
    if (humidity > 85 && temperature > 22) {
      return 'HIGH';
    }
    if (humidity > 70 && temperature > 18) {
      return 'MEDIUM';
    }
    return 'LOW';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'SAFE':
      case 'EXCELLENT':
      case 'NO NEED':
      case 'LOW':
        return AppColors.success;
      case 'CAUTION':
      case 'FAIR':
      case 'MODERATE':
      case 'MEDIUM':
        return AppColors.warning;
      case 'UNSAFE':
      case 'POOR':
      case 'HIGH NEED':
      case 'HIGH':
      default:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final desc = widget.weatherData.description;
    final isRainy =
        desc.toLowerCase().contains('rain') ||
        desc.toLowerCase().contains('storm');

    // Dynamic Hero gradient based on weather
    final heroGradient = isRainy
        ? const LinearGradient(
            colors: [Color(0xFF3A6073), Color(0xFF3A6073)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.75),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final currentAlerts = widget.weatherData.alerts;
    final forecastAlerts = widget.forecast?.alerts ?? [];
    final activeAlert = currentAlerts.isNotEmpty
        ? currentAlerts.first
        : (forecastAlerts.isNotEmpty ? forecastAlerts.first : null);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Weather & Farm Intelligence',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppColors.textHeadline,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textHeadline,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppColors.textHeadline,
              ),
              onPressed: _handleRefresh,
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. HERO CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: heroGradient,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: (isRainy ? Colors.blueGrey : AppColors.primary)
                            .withValues(alpha: 0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.weatherData.location.toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.weatherData.temperature.toStringAsFixed(0)}°C',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 54,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getWeatherIcon(desc),
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(
                        color: Colors.white.withValues(alpha: 0.2),
                        height: 1,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildHeroMetric(
                            'Feels Like',
                            '${widget.weatherData.feelsLike.toStringAsFixed(0)}°C',
                          ),
                          _buildHeroMetric('Condition', desc),
                          _buildHeroMetric(
                            'Wind',
                            '${widget.weatherData.windSpeed.toStringAsFixed(0)} km/h',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // INTERACTIVE WEATHER MAP CARD (Zoom Earth)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _launchWeatherMap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.map_rounded,
                                  color: Color(0xFF38EF7D),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Live Wind & Rain Radar Map',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Open live Zoom Earth maps for your location',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.white.withValues(alpha: 0.5),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. ACTIVE WARNINGS (IF ANY)
                if (activeAlert != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeAlert.title,
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                activeAlert.description,
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.textHeadline,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // 3. KIKO CROP ADVISORY CARD (FULL WIDTH)
                Builder(
                  builder: (context) {
                    final spraying = _getSprayingStatus(
                      widget.weatherData.windSpeed,
                      desc,
                    );
                    final harvesting = _getHarvestingStatus(
                      desc,
                      widget.weatherData.humidity,
                    );
                    final irrigation = _getIrrigationStatus(
                      widget.weatherData.temperature,
                      widget.weatherData.humidity,
                    );
                    final disease = _getDiseaseRiskStatus(
                      widget.weatherData.humidity,
                      widget.weatherData.temperature,
                    );

                    final bool isWarning =
                        spraying == 'UNSAFE' ||
                        harvesting == 'POOR' ||
                        disease == 'HIGH' ||
                        irrigation == 'HIGH NEED';

                    String advisoryMessage = '';
                    if (spraying == 'UNSAFE') {
                      advisoryMessage =
                          "High winds or rain make spraying unsafe today. Wait for calmer weather.";
                    } else if (disease == 'HIGH') {
                      advisoryMessage =
                          "High humidity and temperature increase disease risk. Monitor crops closely.";
                    } else if (harvesting == 'POOR') {
                      advisoryMessage =
                          "Wet conditions are not ideal for harvesting. Protect harvested crops.";
                    } else if (irrigation == 'HIGH NEED') {
                      advisoryMessage =
                          "Hot and dry conditions! Ensure your fields are sufficiently irrigated.";
                    } else if (spraying == 'CAUTION' || disease == 'MEDIUM') {
                      advisoryMessage =
                          "Moderate disease risk or breezy winds. Proceed with caution.";
                    } else {
                      advisoryMessage =
                          "Great farming weather today! Ideal conditions for field activities.";
                    }

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isWarning
                              ? [
                                  const Color(0xFFFFF5F5),
                                  const Color(0xFFFFF0F0),
                                ]
                              : [
                                  const Color(0xFFECFDF5),
                                  const Color(0xFFF0FDF4),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isWarning
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFD1FAE5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Image.asset(
                            isWarning
                                ? 'assets/images/kiko_cloudy.png'
                                : 'assets/images/kiko_happy.png',
                            width: 52,
                            height: 52,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: isWarning
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.face,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isWarning
                                      ? "KIKO'S WARNING"
                                      : "KIKO'S FARM ADVICE",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: isWarning
                                        ? const Color(0xFF991B1B)
                                        : const Color(0xFF047857),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  advisoryMessage,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: isWarning
                                        ? const Color(0xFF7F1D1D)
                                        : const Color(0xFF065F46),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // 4. BENTO LAYOUT (AGRONOMIC ADVISORY & DETAILED METRICS)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT COLUMN: AGRONOMIC ADVISORY
                    Expanded(
                      flex: 11,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: AppDecorations.cardDecoration,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AGRO ADVISORY',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.textSubtle,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildAdvisoryRow(
                              'Spraying',
                              _getSprayingStatus(
                                widget.weatherData.windSpeed,
                                desc,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildAdvisoryRow(
                              'Harvesting',
                              _getHarvestingStatus(
                                desc,
                                widget.weatherData.humidity,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildAdvisoryRow(
                              'Irrigation',
                              _getIrrigationStatus(
                                widget.weatherData.temperature,
                                widget.weatherData.humidity,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildAdvisoryRow(
                              'Disease Risk',
                              _getDiseaseRiskStatus(
                                widget.weatherData.humidity,
                                widget.weatherData.temperature,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // RIGHT COLUMN: DETAILED METRICS (2x2 GRID)
                    Expanded(
                      flex: 9,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: AppDecorations.cardDecoration,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'METRICS',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.textSubtle,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildMetricGridItem(
                              Icons.water_drop_outlined,
                              'Humidity',
                              '${widget.weatherData.humidity.toStringAsFixed(0)}%',
                            ),
                            const SizedBox(height: 14),
                            _buildMetricGridItem(
                              Icons.speed_outlined,
                              'Pressure',
                              '${widget.weatherData.pressure.toStringAsFixed(0)} hPa',
                            ),
                            const SizedBox(height: 14),
                            _buildMetricGridItem(
                              Icons.cloud_outlined,
                              'Clouds',
                              '${widget.weatherData.cloudiness}%',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 4. HOURLY FORECAST CAROUSEL
                Text(
                  'Hourly Forecast',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.textHeadline,
                  ),
                ),
                const SizedBox(height: 12),
                _buildHourlyCarousel(),
                const SizedBox(height: 24),

                // 5. 5-DAY WEEKLY FORECAST
                Text(
                  'Weekly Forecast',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.textHeadline,
                  ),
                ),
                const SizedBox(height: 12),
                _buildWeeklyForecast(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildAdvisoryRow(String action, String status) {
    final statusColor = _getStatusColor(status);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            action,
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.textHeadline,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status,
            style: GoogleFonts.plusJakartaSans(
              color: statusColor,
              fontWeight: FontWeight.w900,
              fontSize: 9,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricGridItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textSubtle,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textHeadline,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHourlyCarousel() {
    if (widget.forecast == null) {
      return Container(
        height: 120,
        decoration: AppDecorations.cardDecoration,
        child: const Center(child: Text('No forecast data available.')),
      );
    }

    final hourlyData = <ForecastData>[];
    final now = DateTime.now();
    hourlyData.add(
      ForecastData(
        dateTime: now,
        temperature: widget.weatherData.temperature,
        feelsLike: widget.weatherData.feelsLike,
        humidity: widget.weatherData.humidity,
        windSpeed: widget.weatherData.windSpeed,
        cloudiness: widget.weatherData.cloudiness,
        pressure: widget.weatherData.pressure,
        description: widget.weatherData.description,
        icon: widget.weatherData.icon,
        rainProbability:
            widget.weatherData.description.toLowerCase().contains('rain')
            ? 1.0
            : 0.0,
      ),
    );

    final upcomingData = widget.forecast!.forecasts.where((f) {
      final hoursAhead = f.dateTime.difference(now).inHours;
      return hoursAhead >= 0 && hoursAhead <= 24;
    }).toList();

    for (final f in upcomingData) {
      if (hourlyData.isEmpty ||
          f.dateTime.difference(hourlyData.first.dateTime).inHours.abs() > 0) {
        hourlyData.add(f);
      }
    }

    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: hourlyData.length,
        itemBuilder: (context, index) {
          final f = hourlyData[index];
          final isNow = index == 0;
          final pop = ((f.rainProbability ?? 0.0) * 100).round();
          final showRain = pop > 10;
          final timeParts = f.timeString.split(' ');
          final timeStr = timeParts[0];
          final amPm = timeParts.length > 1 ? timeParts[1] : '';

          return Container(
            width: 95,
            margin: const EdgeInsets.only(right: 12, bottom: 8, top: 4),
            decoration: BoxDecoration(
              color: isNow ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: isNow
                      ? AppColors.primary.withValues(alpha: 0.25)
                      : const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
              border: isNow
                  ? null
                  : Border.all(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      width: 1.5,
                    ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isNow ? 'Now' : timeStr,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isNow
                        ? Colors.white.withValues(alpha: 0.9)
                        : AppColors.textHeadline,
                  ),
                ),
                if (!isNow && amPm.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    amPm,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSubtle.withValues(alpha: 0.6),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isNow
                        ? Colors.white.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getWeatherIcon(f.description),
                    size: 18,
                    color: isNow ? Colors.white : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${f.temperature.toStringAsFixed(0)}°',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isNow ? Colors.white : AppColors.textHeadline,
                  ),
                ),
                if (showRain) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isNow
                          ? Colors.white.withValues(alpha: 0.2)
                          : const Color(0xFF3B82F6).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.water_drop_rounded,
                          size: 9,
                          color: isNow ? Colors.white : const Color(0xFF3B82F6),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$pop%',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isNow
                                ? Colors.white
                                : const Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeeklyForecast() {
    if (widget.forecast == null) return const SizedBox.shrink();

    final dailyData = widget.forecast!.getDailyForecast().take(5).toList();
    if (dailyData.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: AppDecorations.cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: dailyData.indexed.map((entry) {
          final index = entry.$1;
          final f = entry.$2;
          final isLast = index == dailyData.length - 1;
          final isExpanded = _expandedIndex == index;

          final dayAdvisory = widget.forecast!.dailyAdvisories.firstWhere(
            (a) => a.day.startsWith(f.dayName) || f.dayName.startsWith(a.day),
            orElse: () => DailyAdvisory(
              day: '',
              condition: '',
              message: '',
              isSevere: false,
            ),
          );
          final hasAdvisory =
              dayAdvisory.day.isNotEmpty && dayAdvisory.message.isNotEmpty;

          return Column(
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _expandedIndex = isExpanded ? null : index;
                  });
                },
                borderRadius: BorderRadius.vertical(
                  top: index == 0 ? const Radius.circular(28) : Radius.zero,
                  bottom: isLast && !isExpanded
                      ? const Radius.circular(28)
                      : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 50,
                        child: Text(
                          f.dayName.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: hasAdvisory
                                ? AppColors.error
                                : AppColors.textHeadline,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        _getWeatherIcon(f.description),
                        size: 22,
                        color: hasAdvisory
                            ? AppColors.error
                            : AppColors.primary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              f.description,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: AppColors.textHeadline,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (hasAdvisory)
                              Text(
                                'Advisory Available',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '${f.temperature.toStringAsFixed(0)}°',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textHeadline,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppColors.textSubtle,
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: 16,
                  ),
                  child: Text(
                    hasAdvisory
                        ? dayAdvisory.message
                        : 'Conditions are expected to be stable. Plan normal irrigation and harvest schedules.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textSubtle,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              if (!isLast)
                Divider(
                  color: AppColors.textHeadline.withValues(alpha: 0.05),
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
