import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:ui';

import 'weather_map_screen.dart';
import '../../../shared/models/weather_model.dart';
import '../../../shared/styles/app_theme.dart';
import '../support/kiko_ai_chat_screen.dart';

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

  void _openKikoAiChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const KikoAiChatScreen(embedMode: false),
      ),
    );
  }

  String _getKikoMascotAsset(String description, double temp, double precipRate) {
    final desc = description.toLowerCase();
    if (desc.contains('storm') || desc.contains('thunder')) {
      return 'assets/images/kiko_stormy.png';
    }
    // Only show rainy mascot if actively precipitating
    if ((desc.contains('rain') || desc.contains('drizzle') || desc.contains('shower')) && precipRate > 0.1) {
      return 'assets/images/kiko_rainy.jpg';
    }
    if (temp <= 18 ||
        desc.contains('frost') ||
        desc.contains('cold') ||
        desc.contains('snow')) {
      return 'assets/images/kiko_frosty.png';
    }
    if (desc.contains('cloud') ||
        desc.contains('overcast') ||
        desc.contains('fog') ||
        desc.contains('mist') ||
        desc.contains('rain') ||
        desc.contains('shower')) {
      return 'assets/images/kiko_cloudy.png';
    }
    return 'assets/images/kiko_happy.png';
  }

  List<Color> _getAtmosphereGradient(String description) {
    final desc = description.toLowerCase();
    if (desc.contains('storm') || desc.contains('thunder')) {
      return const [
        Color(0xFF1E293B),
        Color(0xFF0F172A),
        Color(0xFF090D16),
      ];
    }
    if (desc.contains('rain') || desc.contains('drizzle') || desc.contains('shower')) {
      return const [
        Color(0xFF1E3A5F),
        Color(0xFF1E293B),
        Color(0xFF0F172A),
      ];
    }
    if (desc.contains('cloud') || desc.contains('overcast')) {
      return const [
        Color(0xFF334155),
        Color(0xFF1E293B),
        Color(0xFF0F172A),
      ];
    }
    // Clear / Sunny
    return const [
      Color(0xFF064E3B),
      Color(0xFF0F766E),
      Color(0xFF1E293B),
    ];
  }

  IconData _getWeatherIcon(String description) {
    final desc = description.toLowerCase();
    if (desc.contains('rain') || desc.contains('shower')) {
      return Icons.grain_rounded;
    }
    if (desc.contains('storm') || desc.contains('thunder')) {
      return Icons.thunderstorm_rounded;
    }
    if (desc.contains('cloud') || desc.contains('overcast')) {
      return Icons.cloud_rounded;
    }
    return Icons.wb_sunny_rounded;
  }

  String _getSprayingStatus(double windSpeed, double humidity, String desc) {
    final lower = desc.toLowerCase();
    final isStormOrRain = lower.contains('rain') ||
        lower.contains('storm') ||
        lower.contains('thunder') ||
        lower.contains('drizzle') ||
        lower.contains('shower');
    if (isStormOrRain || windSpeed > 15) return 'UNSAFE';
    if (windSpeed > 10 || humidity > 85) return 'CAUTION';
    return 'SAFE';
  }

  String _getIrrigationStatus(double humidity, double temperature, String desc) {
    final lower = desc.toLowerCase();
    final isStormOrRain = lower.contains('rain') ||
        lower.contains('storm') ||
        lower.contains('thunder') ||
        lower.contains('drizzle') ||
        lower.contains('shower');
    if (isStormOrRain || humidity > 80) return 'NO NEED';
    if (temperature >= 35 && humidity < 50) return 'HIGH NEED';
    if (temperature >= 30 && humidity < 65) return 'MODERATE';
    return 'LOW';
  }

  String _getDiseaseRiskStatus(double humidity, double temperature) {
    if (humidity >= 80 && temperature >= 24) return 'HIGH';
    if (humidity >= 65 && temperature >= 20) return 'MEDIUM';
    return 'LOW';
  }

  String _getHarvestingStatus(String desc, double humidity) {
    final lower = desc.toLowerCase();
    if (lower.contains('storm') || lower.contains('thunder')) return 'UNSAFE';
    if (lower.contains('rain') || lower.contains('drizzle') || lower.contains('shower')) return 'DELAY';
    if (humidity > 85) return 'CAUTION';
    return 'OPTIMAL';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'SAFE':
      case 'OPTIMAL':
      case 'NO NEED':
      case 'LOW':
        return const Color(0xFF10B981);
      case 'CAUTION':
      case 'MODERATE':
      case 'MEDIUM':
      case 'DELAY':
        return const Color(0xFFF59E0B);
      case 'UNSAFE':
      case 'HIGH NEED':
      case 'HIGH':
      case 'RESTRICTED':
      default:
        return const Color(0xFFEF4444);
    }
  }

  @override
  Widget build(BuildContext context) {
    final weather = widget.weatherData;
    final forecast = widget.forecast;
    final desc = weather.description;
    final temp = weather.temperature;
    final feelsLike = weather.feelsLike.toStringAsFixed(0);
    final humidity = weather.humidity;
    final wind = weather.windSpeed.toStringAsFixed(1);
    final location = weather.location;
    final atmosphereGradient = _getAtmosphereGradient(desc);
    final kikoAsset = _getKikoMascotAsset(desc, temp, weather.precipitationRate);

    // Hourly forecast list for temperature curve (max 7 items)
    final hourlyItems = (forecast?.forecasts ?? [])
        .take(7)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Dynamic Atmospheric Gradient Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: atmosphereGradient,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),

          // Ambient Background Glow Circles
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),

          // Main Scrollable Content
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              color: Colors.white,
              backgroundColor: const Color(0xFF1E293B),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Navigation Bar
                    _buildTopBar(location),
                    const SizedBox(height: 18),

                    // Atmospheric Hero Header with Kiko Mascot
                    _buildAtmosphericHero(
                      temp: temp,
                      desc: desc,
                      feelsLike: feelsLike,
                      wind: wind,
                      humidity: humidity,
                      kikoAsset: kikoAsset,
                    ),
                    const SizedBox(height: 22),

                    // Next 24 Hours & Temperature Wave Curve Card
                    if (hourlyItems.isNotEmpty) ...[
                      _buildHourlyTemperatureCard(hourlyItems),
                      const SizedBox(height: 20),
                    ],

                    // 5-Day Horizon Forecast Cards
                    if (forecast != null && forecast.forecasts.isNotEmpty) ...[
                      _buildMultiDayHorizonCard(forecast),
                      const SizedBox(height: 20),
                    ],

                    // Kiko's Agricultural Advisory Box
                    _buildKikoAdvisoryCard(
                      desc: desc,
                      temp: temp,
                      humidity: humidity,
                      wind: weather.windSpeed,
                      kikoAsset: kikoAsset,
                    ),
                    const SizedBox(height: 20),

                    // Agronomic Field Intelligence Bento Grid
                    _buildAgroIntelligenceGrid(
                      windSpeed: weather.windSpeed,
                      humidity: humidity.toDouble(),
                      temperature: temp,
                      desc: desc,
                    ),
                    const SizedBox(height: 20),

                    // Live Wind & Rain Radar Launcher
                    _buildRadarLauncherCard(),
                    const SizedBox(height: 20),

                    // Consult Kiko AI Bar
                    _buildConsultAiBar(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 1. TOP APP BAR
  // ===========================================================================
  Widget _buildTopBar(String location) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Back Button
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Location Title Tag (Overflow-Proof)
        Expanded(
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFF34D399),
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      location,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Refresh / Radar Action
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: _isRefreshing
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _handleRefresh,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 2. ATMOSPHERIC HERO SECTION (WITH KIKO MASCOT)
  // ===========================================================================
  Widget _buildAtmosphericHero({
    required double temp,
    required String desc,
    required String feelsLike,
    required String wind,
    required num humidity,
    required String kikoAsset,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Temperature & Condition
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${temp.toStringAsFixed(0)}°',
                      style: GoogleFonts.poppins(
                        fontSize: 64,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.0,
                        letterSpacing: -2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          _getWeatherIcon(desc),
                          color: const Color(0xFF38BDF8),
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          desc,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Feels like $feelsLike°C • Wind $wind km/h',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              // Dynamic Kiko Weather Mascot
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    kikoAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.eco_rounded,
                      color: Color(0xFF34D399),
                      size: 40,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Micro Stats Capsule Strip
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHeroStat(Icons.water_drop_outlined, '$humidity%', 'Humidity'),
                _buildStatDivider(),
                _buildHeroStat(Icons.air_rounded, '$wind km/h', 'Wind Speed'),
                _buildStatDivider(),
                _buildHeroStat(Icons.compress_rounded, '${widget.weatherData.pressure.toStringAsFixed(0)} hPa', 'Pressure'),
              ],
            ),
          ),

          // Hyper-Local Nowcast Advance Warning Strip
          if (widget.weatherData.nowcastSummary != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.radar_rounded,
                    size: 16,
                    color: Color(0xFF38BDF8),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.weatherData.nowcastSummary!,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _launchWeatherMap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Radar',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF38BDF8)),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white60,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 22,
      color: Colors.white.withValues(alpha: 0.15),
    );
  }

  // ===========================================================================
  // 3. HOURLY TIMELINE & SMOOTH TEMPERATURE WAVE CURVE
  // ===========================================================================
  Widget _buildHourlyTemperatureCard(List<ForecastData> items) {
    final todayMin = items.map((i) => i.temperature).reduce((a, b) => a < b ? a : b).toStringAsFixed(0);
    final todayMax = items.map((i) => i.temperature).reduce((a, b) => a > b ? a : b).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: "Next 24 Hours" + Today Range Capsule
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Next 24 Hours',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Range $todayMin° / $todayMax°',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Custom Temperature Bezier Wave Curve
          SizedBox(
            height: 100,
            width: double.infinity,
            child: CustomPaint(
              painter: _HourlyTemperatureCurvePainter(
                hourlyData: items,
                curveColor: const Color(0xFF38BDF8),
                dotColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Weather Icons, Rain Probability & Time Axis Strip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final timeLabel = idx == 0 ? 'Now' : item.timeString.replaceAll(':00', '');
              final pop = ((item.rainProbability ?? 0) * 100).toInt();

              return Expanded(
                child: Column(
                  children: [
                    Icon(
                      _getWeatherIcon(item.description),
                      size: 16,
                      color: Colors.white70,
                    ),
                    const SizedBox(height: 3),
                    if (pop > 0)
                      Text(
                        '$pop%',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF38BDF8),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    else
                      const SizedBox(height: 12),
                    const SizedBox(height: 3),
                    Text(
                      timeLabel,
                      style: GoogleFonts.inter(
                        color: Colors.white60,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. MULTI-DAY HORIZON FORECAST CARDS
  // ===========================================================================
  Widget _buildMultiDayHorizonCard(WeatherForecast forecast) {
    // Group forecast items by distinct day
    final distinctDays = <String, ForecastData>{};
    for (final item in forecast.forecasts) {
      final key = item.dayName;
      if (!distinctDays.containsKey(key)) {
        distinctDays[key] = item;
      }
    }
    final daysList = distinctDays.values.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                color: Colors.white70,
                size: 15,
              ),
              const SizedBox(width: 6),
              Text(
                '5-Day Extended Horizon',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Daily Horizon Rows
          ...daysList.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final dayTitle = idx == 0 ? 'Today' : item.dayName;
            final minT = (item.temperature - 2).toStringAsFixed(0);
            final maxT = (item.temperature + 3).toStringAsFixed(0);
            final pop = ((item.rainProbability ?? 0) * 100).toInt();

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  // Day Label
                  SizedBox(
                    width: 70,
                    child: Text(
                      dayTitle,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),

                  // Weather Icon
                  Icon(
                    _getWeatherIcon(item.description),
                    color: const Color(0xFF38BDF8),
                    size: 18,
                  ),
                  const SizedBox(width: 8),

                  // Rain probability (if any)
                  if (pop > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$pop%',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF38BDF8),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 32),

                  const Spacer(),

                  // Min Temp
                  Text(
                    '$minT°',
                    style: GoogleFonts.inter(
                      color: Colors.white60,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Gradient Temperature Range Bar
                  Container(
                    width: 60,
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF38BDF8), Color(0xFFFBBF24)],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Max Temp
                  Text(
                    '$maxT°',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. KIKO'S AGRICULTURAL ADVISORY SPEECH CARD
  // ===========================================================================
  Widget _buildKikoAdvisoryCard({
    required String desc,
    required double temp,
    required num humidity,
    required double wind,
    required String kikoAsset,
  }) {
    String kikoSpeech;
    final lower = desc.toLowerCase();
    if (lower.contains('storm') || lower.contains('thunder')) {
      kikoSpeech =
          'Moo! ⚡ Thunderstorm & lightning alert! Suspend open field labor immediately, secure loose tools and farm shelters, and ensure drainage canals are clear to prevent waterlogging.';
    } else if (lower.contains('rain') || lower.contains('drizzle') || lower.contains('shower')) {
      kikoSpeech =
          'Moo! 🌧️ Wet field conditions detected. Delay foliar fertilizer and pesticide spraying today to avoid wash-off. Move harvested produce to dry storage!';
    } else if (wind > 14) {
      kikoSpeech =
          'Moo! 💨 Strong wind gusts detected (${wind.toStringAsFixed(1)} km/h). Stake tall crop trellises and avoid chemical spraying due to severe drift risk.';
    } else if (temp >= 36) {
      kikoSpeech =
          'Moo! ☀️ Intense heat wave alert (${temp.toStringAsFixed(0)}°C). Irrigate early before sunrise, check mulching, and protect field workers from midday heat!';
    } else if (humidity >= 80) {
      kikoSpeech =
          'Moo! ☁️ High humidity (${humidity.toStringAsFixed(0)}%) elevates fungal blight risk. Inspect lower leaves for spots and ensure good field aeration.';
    } else {
      kikoSpeech =
          'Moo! 🌿 Great farming weather today! Ideal conditions for weeding, seedling transplanting, and routine field operations in San Carlos.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF064E3B).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF34D399).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            child: ClipOval(
              child: Image.asset(
                kikoAsset,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.smart_toy_rounded,
                  color: Color(0xFF34D399),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Kiko\'s Farm Insight',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF34D399),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF34D399).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'AI ADVICE',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF34D399),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  kikoSpeech,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 6. AGRONOMIC INTELLIGENCE BENTO GRID
  // ===========================================================================
  Widget _buildAgroIntelligenceGrid({
    required double windSpeed,
    required double humidity,
    required double temperature,
    required String desc,
  }) {
    final sprayingStatus = _getSprayingStatus(windSpeed, humidity, desc);
    final irrigationStatus = _getIrrigationStatus(humidity, temperature, desc);
    final diseaseRisk = _getDiseaseRiskStatus(humidity, temperature);
    final harvestingStatus = _getHarvestingStatus(desc, humidity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Agronomic Field Intelligence',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAgroBentoCard(
                icon: Icons.science_outlined,
                title: 'Spraying Window',
                status: sprayingStatus,
                subtitle: sprayingStatus == 'SAFE'
                    ? 'Calm wind, safe to spray'
                    : 'Risk of drift / wash-off',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAgroBentoCard(
                icon: Icons.water_drop_outlined,
                title: 'Irrigation Need',
                status: irrigationStatus,
                subtitle: irrigationStatus == 'HIGH NEED'
                    ? 'Dry soil condition'
                    : 'Adequate moisture',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAgroBentoCard(
                icon: Icons.bug_report_outlined,
                title: 'Disease & Fungal Risk',
                status: diseaseRisk,
                subtitle: diseaseRisk == 'HIGH'
                    ? 'High moisture & warm'
                    : 'Low pathogen pressure',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAgroBentoCard(
                icon: Icons.agriculture_rounded,
                title: 'Field Harvesting',
                status: harvestingStatus,
                subtitle: harvestingStatus == 'OPTIMAL'
                    ? 'Dry produce condition'
                    : 'Wet / lightning risk',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAgroBentoCard({
    required IconData icon,
    required String title,
    required String status,
    required String subtitle,
  }) {
    final statusColor = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white70, size: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.inter(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: Colors.white60,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 7. LIVE RADAR MAP LAUNCHER
  // ===========================================================================
  Widget _buildRadarLauncherCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: _launchWeatherMap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.map_rounded,
                    color: Color(0xFF38BDF8),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Wind & Rain Radar Map',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Open interactive satellite & storm radar',
                        style: GoogleFonts.inter(
                          color: Colors.white60,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white54,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 8. CONSULT KIKO AI BAR
  // ===========================================================================
  Widget _buildConsultAiBar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFFFBBF24),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ask Kiko AI about weather impact on crops…',
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ElevatedButton(
            onPressed: () => _openKikoAiChat(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Ask AI',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TEMPERATURE BEZIER CURVE PAINTER
// =============================================================================
class _HourlyTemperatureCurvePainter extends CustomPainter {
  final List<ForecastData> hourlyData;
  final Color curveColor;
  final Color dotColor;

  _HourlyTemperatureCurvePainter({
    required this.hourlyData,
    this.curveColor = Colors.white,
    this.dotColor = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (hourlyData.length < 2) return;

    final minTemp = hourlyData
        .map((d) => d.temperature)
        .reduce((a, b) => a < b ? a : b);
    final maxTemp = hourlyData
        .map((d) => d.temperature)
        .reduce((a, b) => a > b ? a : b);
    final tempRange = (maxTemp - minTemp).clamp(2.0, 50.0);

    final linePaint = Paint()
      ..color = curveColor.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          curveColor.withValues(alpha: 0.22),
          curveColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final stepX = size.width / (hourlyData.length - 1);
    final points = <Offset>[];

    for (int i = 0; i < hourlyData.length; i++) {
      final t = hourlyData[i].temperature;
      final normY = 1.0 - ((t - minTemp) / tempRange);
      final y = (normY * (size.height - 36)) + 18;
      final x = i * stepX;
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    final fillPath = Path()..moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final cx = (p0.dx + p1.dx) / 2;
      path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
      fillPath.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = dotColor;
    final dotRingPaint = Paint()
      ..color = curveColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      canvas.drawCircle(pt, 5, dotRingPaint);
      canvas.drawCircle(pt, 3, dotPaint);

      // Draw temperature text above point
      final tempStr = '${hourlyData[i].temperature.toStringAsFixed(0)}°';
      final textSpan = TextSpan(
        text: tempStr,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(pt.dx - (textPainter.width / 2), pt.dy - 18),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
