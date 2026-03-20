import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../../shared/services/weather_service.dart';
import '../../../shared/models/weather_model.dart';
import '../../../shared/services/auth/auth_service.dart';
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
  StreamSubscription<Position>? _positionStream;
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
              await _loadWeatherData();
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
          if (!mounted) return; // Prevent updates after dispose
          _currentPosition = position;
          debugPrint(
            'Location updated: ${position.latitude}, ${position.longitude}',
          );
          // Refresh weather when location changes significantly
          _loadWeatherData().catchError((e) {
            debugPrint('Error updating weather on location change: $e');
          });
        }, onError: (error) {
          debugPrint('Position stream error: $error');
        });
      } else {
        // Permission denied, load with fallback
        debugPrint('Location permission denied: $permission');
        if (mounted) {
          await _loadWeatherData();
        }
      }
    } catch (e) {
      debugPrint('Location initialization error: $e');
      // Fallback: load weather without location
      if (mounted) {
        await _loadWeatherData();
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
    _positionStream?.cancel();
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
                    const SizedBox(height: 20),
                    _buildSectionLabel('Sales Analytics'),
                    const SizedBox(height: 10),
                    _buildSalesAnalytics(),
                    const SizedBox(height: 20),
                    _buildSectionLabel('Weather & Forecast'),
                    const SizedBox(height: 10),
                    _buildWeatherAlert(),
                    const SizedBox(height: 12),
                    _buildForecast(),
                    const SizedBox(height: 20),
                    _buildSectionLabel('AI Crop Insights'),
                    const SizedBox(height: 10),
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
    final auth = AuthService();
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';
    final greetingEmoji = hour < 12 ? '🌅' : hour < 17 ? '☀️' : '🌙';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF13EC5B), Color(0xFF059950)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -20,
            right: -15,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            top: 30,
            right: 50,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: avatar + greeting + notification
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl:
                              'https://lh3.googleusercontent.com/aida-public/AB6AXuA7SO8J3CebwmP_4K0nwWhDkMsWISrTpnfbOkYJ79_ZiTCLVxdvX_FJArJ1xwYsLAJx8gW_Wtk3xValGb9mDShlpRvdPIMoD9UGWJ9LwNRlF0vvmsKesjK6liNaDGy7C5HGWdOAE1hEPvF3UTq81_QK7QkgKAAMQgeICa4pykDXTF8JYtnrFYPiavyC7N-wkK4pGMGQJcdoyKpRglzbFXWGqTdoa3xP-Bm86BGxFKlWg21Mbw-FylTfHiJeJMKgLbfSJr8MhPFg1zqB',
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              Container(color: Colors.white24),
                          errorWidget: (_, _, _) => Container(
                            color: Colors.white24,
                            child: const Icon(Icons.person,
                                size: 24, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$greetingEmoji $greeting,',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            auth.userName.isNotEmpty
                                ? auth.userName
                                : 'Farmer',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Notification bell
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        children: [
                          const Icon(Icons.notifications_outlined,
                              size: 20, color: Colors.white),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF59E0B),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Bottom info bar: weather + location
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      // Weather inline
                      if (!_isLoadingWeather && _weatherData != null) ...[
                        Text(
                          _getWeatherEmoji(
                              _weatherData!.description, false),
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_weatherData!.temperature.toStringAsFixed(1)}°C',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          margin:
                              const EdgeInsets.symmetric(horizontal: 10),
                          width: 1,
                          height: 14,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ] else if (_isLoadingWeather) ...[
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Loading weather...',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                      // Location
                      const Icon(Icons.location_on_rounded,
                          size: 13, color: Colors.white70),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _weatherData?.location ??
                              (_currentPosition != null
                                  ? '${_currentPosition!.latitude.toStringAsFixed(1)}°, ${_currentPosition!.longitude.toStringAsFixed(1)}°'
                                  : 'Locating...'),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Today's Overview",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'This Week',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                label: 'Revenue',
                value: '₱1,240',
                change: '+5.2%',
                changePositive: true,
                icon: Icons.payments_rounded,
                iconColor: const Color(0xFF13EC5B),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                label: 'Orders',
                value: '8',
                change: '+2 today',
                changePositive: true,
                icon: Icons.receipt_long_rounded,
                iconColor: const Color(0xFF3B82F6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                label: 'Products',
                value: '14',
                change: 'Active items',
                changePositive: null,
                icon: Icons.inventory_2_rounded,
                iconColor: const Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                label: 'Avg. Rating',
                value: '4.8',
                change: '★ Excellent',
                changePositive: true,
                icon: Icons.star_rounded,
                iconColor: const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required String change,
    required bool? changePositive,
    required IconData icon,
    required Color iconColor,
  }) {
    final changeBgColor = changePositive == null
        ? Colors.grey[100]!
        : changePositive
            ? primary.withValues(alpha: 0.12)
            : Colors.red.withValues(alpha: 0.1);
    final changeTextColor = changePositive == null
        ? Colors.grey[500]!
        : changePositive
            ? primary
            : Colors.red;

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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: changeBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  change,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: changeTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
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
      return Skeletonizer(
        enabled: true,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F7F3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFB3E5DB)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        width: 100, height: 14, color: Colors.white),
                    const SizedBox(height: 6),
                    Container(
                        width: double.infinity, height: 11, color: Colors.white),
                    const SizedBox(height: 4),
                    Container(width: 140, height: 11, color: Colors.white),
                  ],
                ),
              ),
            ],
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
      return Skeletonizer(
        enabled: true,
        child: Container(
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
              Container(width: 80, height: 12, color: Colors.white),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 5,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, __) => Container(
                    width: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(width: 50, height: 11, color: Colors.white),
                        const SizedBox(height: 4),
                        Container(width: 40, height: 10, color: Colors.white),
                        const SizedBox(height: 8),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(width: 30, height: 16, color: Colors.white),
                        const SizedBox(height: 4),
                        Container(width: 44, height: 11, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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

  Widget _buildSectionLabel(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF0F172A),
      ),
    );
  }

  Widget _buildAICropInsights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
