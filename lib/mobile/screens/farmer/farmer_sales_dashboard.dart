import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/weather_service.dart';
import '../../../shared/models/weather_model.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

/// Farmer Sales Dashboard
class FarmerSalesDashboard extends StatefulWidget {
  const FarmerSalesDashboard({super.key});

  @override
  State<FarmerSalesDashboard> createState() => _FarmerSalesDashboardState();
}

class _FarmerSalesDashboardState extends State<FarmerSalesDashboard> {
  WeatherData? _weatherData;
  WeatherForecast? _weatherForecast;
  bool _isLoadingWeather = true;
  String? _weatherError;
  Position? _currentPosition;
  late StreamSubscription<Position> _positionStream;
  Timer? _refreshTimer;

  static const Color primary = Color(0xFF13EC5B);

  @override
  void initState() {
    super.initState();
    _initializeLocationTracking();
    _startPeriodicRefresh();
  }

  void _startPeriodicRefresh() {
    // Refresh weather data every 10 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      if (mounted) {
        _loadWeatherData();
      }
    });
  }

  Future<void> _initializeLocationTracking() async {
    try {
      // Request location permission first
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('Initial location permission: $permission');
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        debugPrint('Requested location permission: $permission');
      }

      // If permission is granted, proceed
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // Get initial position with longer timeout
        try {
          debugPrint('Requesting initial position...');
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 20),
          );
          _currentPosition = position;
          debugPrint(
            'Initial position obtained: ${position.latitude}, ${position.longitude}',
          );
          
          // Load weather immediately after getting position
          await _loadWeatherData();
        } catch (e) {
          debugPrint('Initial position error: $e');
          // Try with lower accuracy if high accuracy fails
          try {
            final position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium,
              timeLimit: const Duration(seconds: 10),
            );
            _currentPosition = position;
            debugPrint(
              'Position obtained with medium accuracy: ${position.latitude}, ${position.longitude}',
            );
            await _loadWeatherData();
          } catch (e2) {
            debugPrint('Medium accuracy position error: $e2');
            if (mounted) {
              _loadWeatherData();
            }
          }
        }

        // Listen to position changes with higher frequency
        _positionStream = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 100, // Update when moved 100+ meters
            timeLimit: Duration(seconds: 30),
          ),
        ).listen((Position position) {
          _currentPosition = position;
          debugPrint(
            'Location updated: ${position.latitude}, ${position.longitude}',
          );
          // Refresh weather when location changes significantly
          _loadWeatherData();
        }, onError: (error) {
          debugPrint('Position stream error: $error');
        });
      } else {
        // Permission denied, load with fallback
        debugPrint('Location permission denied: $permission');
        if (mounted) {
          _loadWeatherData();
        }
      }
    } catch (e) {
      debugPrint('Location initialization error: $e');
      // Fallback: load weather without location
      if (mounted) {
        _loadWeatherData();
      }
    }
  }

  Future<void> _loadWeatherData() async {
    try {
      // Use current position if available, otherwise get new position
      Position? position = _currentPosition;

      if (position == null) {
        try {
          debugPrint('Position is null, requesting current position...');
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(const Duration(seconds: 15));
          _currentPosition = position;
          debugPrint('Position acquired: ${position.latitude}, ${position.longitude}');
        } catch (e) {
          debugPrint('Get current position error: $e');
        }
      }

      if (mounted) {
        setState(() => _isLoadingWeather = true);
      }

      WeatherData? weatherData;
      WeatherForecast? forecast;

      if (position != null) {
        debugPrint(
          'Fetching weather for: ${position.latitude}, ${position.longitude}',
        );
        weatherData = await WeatherService().getWeatherByCoordinates(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        debugPrint('Weather data received: ${weatherData?.temperature}°C at ${weatherData?.location}');
        
        // Also fetch 5-day forecast
        forecast = await WeatherService().getForecastByCoordinates(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        debugPrint('Forecast received: ${forecast?.forecasts.length} items');
      } else {
        // Default to a city if location unavailable
        debugPrint('No position available, fetching weather by city...');
        weatherData = await WeatherService().getWeatherByCity('Farm Location');
        forecast = await WeatherService().getForecastByCity('Farm Location');
        debugPrint('Fallback weather data: ${weatherData?.temperature}°C');
      }

      if (mounted) {
        setState(() {
          _weatherData = weatherData;
          _weatherForecast = forecast;
          _isLoadingWeather = false;
          _weatherError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _weatherError = 'Failed to load weather data';
          _isLoadingWeather = false;
        });
      }
      debugPrint('Weather loading error: $e');
    }
  }

  @override
  void dispose() {
    _positionStream.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF7),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMetricsGrid(),
                    const SizedBox(height: 16),
                    _buildSalesAnalytics(),
                    const SizedBox(height: 16),
                    _buildWeatherAlert(),
                    const SizedBox(height: 24),
                    _buildForecast(),
                    const SizedBox(height: 24),
                    _buildAICropInsights(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          ClipOval(
            child: CachedNetworkImage(
              imageUrl:
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuA7SO8J3CebwmP_4K0nwWhDkMsWISrTpnfbOkYJ79_ZiTCLVxdvX_FJArJ1xwYsLAJx8gW_Wtk3xValGb9mDShlpRvdPIMoD9UGWJ9LwNRlF0vvmsKesjK6liNaDGy7C5HGWdOAE1hEPvF3UTq81_QK7QkgKAAMQgeICa4pykDXTF8JYtnrFYPiavyC7N-wkK4pGMGQJcdoyKpRglzbFXWGqTdoa3xP-Bm86BGxFKlWg21Mbw-FylTfHiJeJMKgLbfSJr8MhPFg1zqB',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              placeholder: (_, _) =>
                  Container(width: 48, height: 48, color: Colors.grey[200]),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good morning,',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
                Text(
                  'Farmer Marcus',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                if (_currentPosition != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 12,
                          color: const Color(0xFF13EC5B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_currentPosition!.latitude.toStringAsFixed(2)}, ${_currentPosition!.longitude.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                Icon(
                  Icons.notifications_outlined,
                  size: 20,
                  color: Colors.grey[600],
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'REVENUE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500],
                        letterSpacing: 0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '+5.2%',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '\$1,240',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'VS. YESTERDAY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'LISTINGS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500],
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '0%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '14',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ACTIVE ITEMS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSalesAnalytics() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SALES ANALYTICS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.trending_up,
                      size: 12,
                      color: Color(0xFF13EC5B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '15%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '\$8,420',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: CustomPaint(
              size: const Size(double.infinity, 140),
              painter: _AnalyticsChartPainter(primary),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final day in [
                'Mon',
                'Tue',
                'Wed',
                'Thu',
                'Fri',
                'Sat',
                'Sun',
              ])
                Text(
                  day,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[400],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherAlert() {
    if (_isLoadingWeather) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_weatherError != null || _weatherData == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red[300]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red[500],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weather Alert',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.red[700],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Unable to load weather data. Please try again.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red[700],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _loadWeatherData,
              child: Icon(Icons.refresh, color: Colors.red[700], size: 20),
            ),
          ],
        ),
      );
    }

    // Show first alert if available, otherwise show current weather summary
    if (_weatherData!.alerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F7F3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFB3E5DB)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weather Status',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0D6B4D),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_weatherData!.temperature.toStringAsFixed(1)}°C - ${_weatherData!.description}. Humidity: ${_weatherData!.humidity.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF0D6B4D),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _loadWeatherData,
              child: const Icon(Icons.refresh, color: Color(0xFF0D6B4D), size: 20),
            ),
          ],
        ),
      );
    }

    final alert = _weatherData!.alerts.first;
    final backgroundColor =
        _getAlertBackgroundColor(alert.severity);
    final borderColor =
        _getAlertBorderColor(alert.severity);
    final iconColor = _getAlertIconColor(alert.severity);
    final textColor = _getAlertTextColor(alert.severity);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location indicator
          if (_weatherData?.location != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 14,
                    color: textColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Weather at ${_weatherData!.location}',
                    style: TextStyle(
                      fontSize: 10,
                      color: textColor.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getAlertIcon(alert.type),
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      alert.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _loadWeatherData,
                child: Icon(Icons.refresh, color: textColor, size: 20),
              ),
            ],
          ),
          if (alert.recommendation != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '💡 ${alert.recommendation}',
                style: TextStyle(
                  fontSize: 11,
                  color: textColor,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getAlertBackgroundColor(double severity) {
    if (severity >= 0.75) {
      return const Color(0xFFFFE5E5); // Red
    } else if (severity >= 0.5) {
      return const Color(0xFFFFE5D0); // Orange
    } else {
      return const Color(0xFFFFFDE5); // Yellow
    }
  }

  Color _getAlertBorderColor(double severity) {
    if (severity >= 0.75) {
      return const Color(0xFFFFB3B3); // Red
    } else if (severity >= 0.5) {
      return const Color(0xFFFFD0B3); // Orange
    } else {
      return const Color(0xFFFFFBC0); // Yellow
    }
  }

  Color _getAlertIconColor(double severity) {
    if (severity >= 0.75) {
      return Colors.red[500]!; // Red
    } else if (severity >= 0.5) {
      return Colors.orange[500]!; // Orange
    } else {
      return Colors.amber[600]!; // Yellow
    }
  }

  Color _getAlertTextColor(double severity) {
    if (severity >= 0.75) {
      return const Color(0xFF991B1B); // Dark Red
    } else if (severity >= 0.5) {
      return const Color(0xFF9D4D0D); // Dark Orange
    } else {
      return const Color(0xFF78350F); // Dark Yellow
    }
  }

  IconData _getAlertIcon(String type) {
    switch (type.toLowerCase()) {
      case 'frost':
        return Icons.ac_unit_rounded;
      case 'rain':
        return Icons.water_drop_rounded;
      case 'drought':
        return Icons.wb_sunny_rounded;
      case 'wind':
        return Icons.air_rounded;
      case 'pest':
        return Icons.bug_report_rounded;
      case 'disease':
        return Icons.sick_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  Widget _buildForecast() {
    if (_isLoadingWeather) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_weatherForecast == null || _weatherForecast!.forecasts.isEmpty) {
      return const SizedBox.shrink();
    }

    // Get daily forecast (one per day)
    final dailyForecast = _weatherForecast!.getDailyForecast();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '5-DAY FORECAST',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: dailyForecast.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final forecast = dailyForecast[index];
                return _buildForecastCard(forecast);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastCard(ForecastData forecast) {
    final isRainy = forecast.rainProbability != null && forecast.rainProbability! > 0.5;
    
    return Container(
      width: 100,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            forecast.dayName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
            ),
          ),
          Text(
            forecast.dateString,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          // Weather icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isRainy ? Colors.blue[100] : primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                _getWeatherEmoji(forecast.description, isRainy),
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Temperature
          Text(
            '${forecast.temperature.toStringAsFixed(0)}°C',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          // Humidity
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.opacity,
                size: 10,
                color: Colors.grey[400],
              ),
              const SizedBox(width: 2),
              Text(
                '${forecast.humidity.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          // Rain probability if present
          if (forecast.rainProbability != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: forecast.rainProbability! > 0.6
                      ? Colors.blue[100]
                      : Colors.orange[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${(forecast.rainProbability! * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: forecast.rainProbability! > 0.6
                        ? Colors.blue[700]
                        : Colors.orange[700],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getWeatherEmoji(String description, bool isRainy) {
    final desc = description.toLowerCase();
    
    if (desc.contains('rain') || isRainy) return '🌧️';
    if (desc.contains('cloud') || desc.contains('overcast')) return '☁️';
    if (desc.contains('clear') || desc.contains('sunny')) return '☀️';
    if (desc.contains('snow')) return '❄️';
    if (desc.contains('wind')) return '💨';
    if (desc.contains('fog') || desc.contains('mist')) return '🌫️';
    if (desc.contains('thunder') || desc.contains('storm')) return '⛈️';
    
    return '🌤️'; // Default partly cloudy
  }

  Widget _buildAICropInsights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'AI Crop Insights',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Refresh',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildInsightCard(
          icon: Icons.trending_up_rounded,
          iconColor: const Color(0xFF7C3AED),
          title: 'Market Demand Surge',
          description:
              'Local demand for organic bell peppers has spiked by 22% this week. Consider prioritizing this harvest.',
        ),
        const SizedBox(height: 12),
        _buildInsightCard(
          icon: Icons.water_drop_rounded,
          iconColor: primary,
          title: 'Irrigation Optimization',
          description:
              'Soil sensors in Sector 4 show 15% lower moisture. Automating irrigation at 9 PM is recommended.',
        ),
      ],
    );
  }

  Widget _buildInsightCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
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
}

class _AnalyticsChartPainter extends CustomPainter {
  final Color color;
  _AnalyticsChartPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final fillPath = Path();

    final points = [
      Offset(size.width * 0.1, size.height * 0.6),
      Offset(size.width * 0.25, size.height * 0.3),
      Offset(size.width * 0.4, size.height * 0.6),
      Offset(size.width * 0.55, size.height * 0.4),
      Offset(size.width * 0.7, size.height * 0.5),
      Offset(size.width * 0.85, size.height * 0.15),
      Offset(size.width, size.height * 0.25),
    ];

    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final cp1x = points[i].dx + (points[i + 1].dx - points[i].dx) / 2;
      final cp1y = points[i].dy;
      final cp2x = points[i].dx + (points[i + 1].dx - points[i].dx) / 2;
      final cp2y = points[i + 1].dy;
      path.cubicTo(cp1x, cp1y, cp2x, cp2y, points[i + 1].dx, points[i + 1].dy);
      fillPath.cubicTo(
        cp1x,
        cp1y,
        cp2x,
        cp2y,
        points[i + 1].dx,
        points[i + 1].dy,
      );
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
