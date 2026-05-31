import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/integration/weather_service.dart';
import '../../../shared/models/weather_model.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../widgets/skeleton_loaders.dart';
import '../../../shared/services/farmer/farmer_service.dart';
import '../../../shared/services/offline/offline_product_service.dart';

/// Farmer Sales Dashboard
class FarmerSalesDashboard extends StatefulWidget {
  const FarmerSalesDashboard({super.key});

  @override
  State<FarmerSalesDashboard> createState() => _FarmerSalesDashboardState();
}

class _FarmerSalesDashboardState extends State<FarmerSalesDashboard> {
  static const String _dbAvatarCacheKeyPrefix = 'farmer_dashboard_db_avatar_';

  final AuthService _auth = AuthService();
  String? _profileName;
  String? _profileAvatarUrl;
  String? _cachedDbAvatarUrl;
  WeatherData? _weatherData;
  WeatherForecast? _weatherForecast;
  bool _isLoadingWeather = true;
  String? _weatherError;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  Timer? _refreshTimer;
  Map<String, dynamic> _stats = {
    'totalRevenue': 0.0,
    'activeListings': 0,
    'yearlySales': 0.0,
    'revenueTrend': '0%',
    'listingsTrend': '0%',
  };
  bool _isLoadingStats = true;

  void _retryProfileLoadAfterStartup() {
    Future<void>.delayed(const Duration(milliseconds: 700), () async {
      if (!mounted) return;
      await _loadCachedDbAvatar();
      await _loadFarmerProfile();
    });

    Future<void>.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;
      await _loadCachedDbAvatar();
      await _loadFarmerProfile();
    });
  }

  String get _farmerDisplayName {
    // 1. Try AuthService name first (most reliable/fastest for initial load)
    final authName = _auth.userName.trim();
    if (authName.isNotEmpty) {
      return authName.split(' ').first;
    }

    // 2. Try profile name from database fetch
    final profileName = _profileName?.trim() ?? '';
    if (profileName.isNotEmpty) {
      return profileName.split(' ').first;
    }

    // 3. Fallback to metadata
    final metadata = _auth.client.auth.currentUser?.userMetadata;
    final metaName =
        ((metadata?['name'] ?? metadata?['full_name']) as String?)?.trim() ?? '';
    if (metaName.isNotEmpty) {
      return metaName.split(' ').first;
    }

    return 'Farmer';
  }

  String? get _farmerAvatarUrl {
    final profileAvatar = _profileAvatarUrl?.trim() ?? '';
    if (profileAvatar.isNotEmpty) return profileAvatar;

    final cachedDbAvatar = _cachedDbAvatarUrl?.trim() ?? '';
    if (cachedDbAvatar.isNotEmpty) return cachedDbAvatar;

    return null;
  }

  String _resolveCurrentUserId() {
    return _auth.userId.isNotEmpty
        ? _auth.userId
        : (_auth.client.auth.currentUser?.id ?? '');
  }

  String _dbAvatarCacheKey(String userId) => '$_dbAvatarCacheKeyPrefix$userId';

  Future<void> _loadCachedDbAvatar() async {
    final currentUserId = _resolveCurrentUserId();
    if (currentUserId.isEmpty || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final cached = (prefs.getString(_dbAvatarCacheKey(currentUserId)) ?? '')
        .trim();

    if (cached.isEmpty || !mounted) return;

    // Safety check: If cached URL is a relative path, resolve it
    String finalUrl = cached;
    if (!cached.startsWith('http')) {
      finalUrl = await SupabaseDatabase.getSafeUrl(
        cached,
        defaultBucket: 'uploads',
      ) ?? '';
    }

    if (mounted && finalUrl.isNotEmpty) {
      setState(() {
        _cachedDbAvatarUrl = finalUrl;
      });
    }
  }

  Future<void> _persistDbAvatar(String? imageUrl) async {
    final url = imageUrl?.trim() ?? '';
    if (url.isEmpty) return;

    final currentUserId = _resolveCurrentUserId();
    if (currentUserId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dbAvatarCacheKey(currentUserId), url);

    if (!mounted) return;
    setState(() {
      _cachedDbAvatarUrl = url;
    });
  }

  Future<void> _precacheFarmerAvatar(String? imageUrl) async {
    final url = imageUrl?.trim() ?? '';
    if (url.isEmpty || !mounted) return;

    try {
      await precacheImage(CachedNetworkImageProvider(url), context);
    } catch (e) {
      debugPrint('Error caching farmer avatar: $e');
    }
  }

  String _extractAvatarFromUserProfile(Map<String, dynamic> profile) {
    final avatarUrl = (profile['avatar_url'] as String?)?.trim() ?? '';
    if (avatarUrl.isNotEmpty) return avatarUrl;

    final imageUrl = (profile['image_url'] as String?)?.trim() ?? '';
    if (imageUrl.isNotEmpty) return imageUrl;

    return '';
  }

  Future<void> _loadFarmerProfile() async {
    final currentUserId = _resolveCurrentUserId();
    if (currentUserId.isEmpty) return;

    try {
      // Match MobileProfileScreen behavior: farmer mode prefers farmers table.
      final farmers = await SupabaseConfig.client
          .from('farmers')
          .select('farm_name, image_url')
          .eq('user_id', currentUserId)
          .limit(1);

      if (farmers.isNotEmpty) {
        final farmName = (farmers[0]['farm_name'] as String?)?.trim();
        final rawUrl = (farmers[0]['image_url'] as String?)?.trim();
        
        final safeUrl = await SupabaseDatabase.getSafeUrl(
          rawUrl,
          defaultBucket: 'uploads',
        );

        if (mounted) {
          setState(() {
            _profileName = farmName;
            _profileAvatarUrl = safeUrl;
          });
          await _persistDbAvatar(safeUrl);
          await _precacheFarmerAvatar(safeUrl);
        }

        // If farmer row exists and we found a valid image, we're done
        if ((safeUrl ?? '').isNotEmpty) {
          return;
        }
      }

      // Fallback to users table profile if no farmer row exists or farmer image is empty
      final profile = await SupabaseDatabase.getUserProfile(currentUserId);
      if (!mounted || profile == null) return;

      final rawAvatarUrl = _extractAvatarFromUserProfile(profile);
      final safeAvatarUrl = await SupabaseDatabase.getSafeUrl(
        rawAvatarUrl,
        defaultBucket: 'uploads',
      );

      setState(() {
        _profileName = (profile['name'] as String?)?.trim();
        _profileAvatarUrl = safeAvatarUrl;
      });
      await _persistDbAvatar(safeAvatarUrl);
      await _precacheFarmerAvatar(safeAvatarUrl);
    } catch (e) {
      debugPrint('Error loading farmer profile header: $e');

      // Final attempt: fallback to user profile
      try {
        final profile = await SupabaseDatabase.getUserProfile(currentUserId);
        if (!mounted || profile == null) return;

        final rawAvatarUrl = _extractAvatarFromUserProfile(profile);
        final safeAvatarUrl = await SupabaseDatabase.getSafeUrl(
          rawAvatarUrl,
          defaultBucket: 'uploads',
        );

        setState(() {
          _profileName = (profile['name'] as String?)?.trim();
          _profileAvatarUrl = safeAvatarUrl;
        });
        await _persistDbAvatar(safeAvatarUrl);
        await _precacheFarmerAvatar(safeAvatarUrl);
      } catch (innerE) {
        debugPrint('Final fallback error: $innerE');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCachedDbAvatar();
    _loadFarmerProfile();
    _loadDashboardStats();
    _retryProfileLoadAfterStartup();
    _initializeLocationTracking();
    _startPeriodicRefresh();
    OfflineProductService().init();
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
        
        // 🟢 NEW: Start with last known position for instant loading
        try {
          final lastPosition = await Geolocator.getLastKnownPosition();
          if (lastPosition != null) {
            _currentPosition = lastPosition;
            debugPrint('Using last known position: ${lastPosition.latitude}, ${lastPosition.longitude}');
            _loadWeatherData();
          }
        } catch (e) {
          debugPrint('Error getting last known position: $e');
        }

        // Get initial position with longer timeout
        try {
          debugPrint('Requesting initial position...');
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium, // Medium is faster than high for start
            timeLimit: const Duration(seconds: 15),
          );
          _currentPosition = position;
          debugPrint(
            'Initial position obtained: ${position.latitude}, ${position.longitude}',
          );

          // Load weather immediately after getting position
          await _loadWeatherData();
        } catch (e) {
          debugPrint('Initial position error: $e');
          if (_currentPosition == null) {
             _loadWeatherData(); // Still try to load with whatever we have
          }
        }

        // Listen to position changes - REMOVED strict timeLimit to prevent stream crashes
        _positionStream =
            Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                distanceFilter: 500, // Update when moved 500+ meters (save battery)
              ),
            ).listen(
              (Position position) {
                if (mounted) {
                  setState(() {
                    _currentPosition = position;
                  });
                  debugPrint(
                    'Location updated: ${position.latitude}, ${position.longitude}',
                  );
                  _loadWeatherData();
                }
              },
              onError: (error) {
                debugPrint('Location stream error (non-fatal): $error');
              },
            );
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
          debugPrint(
            'Position acquired: ${position.latitude}, ${position.longitude}',
          );
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
        debugPrint(
          'Weather data received: ${weatherData?.temperature}�C at ${weatherData?.location}',
        );

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
        debugPrint('Fallback weather data: ${weatherData?.temperature}�C');
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

  Future<void> _loadDashboardStats() async {
    try {
      if (mounted) setState(() => _isLoadingStats = true);
      final stats = await FarmerService().getFarmerStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard stats: $e');
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> _generateDynamicInsights() {
    final insights = <Map<String, dynamic>>[];
    
    // 1. Weather-based insight
    if (_weatherData != null) {
      final desc = _weatherData!.description.toLowerCase();
      if (desc.contains('rain') || desc.contains('storm') || desc.contains('cloud')) {
        insights.add({
          'title': 'Harvest Timing',
          'description': 'Upcoming precipitation detected. Consider accelerating harvest for moisture-sensitive crops.',
          'icon': Icons.opacity_rounded,
          'color': const Color(0xFF3B82F6),
        });
      } else {
        insights.add({
          'title': 'Irrigation Alert',
          'description': 'Clear weather forecast. Monitor soil moisture levels to ensure optimal growth during the dry spell.',
          'icon': Icons.water_drop_rounded,
          'color': const Color(0xFF3B82F6),
        });
      }
    }

    // 2. Sales-based insight
    final trend = _stats['revenueTrend'] as String? ?? '0%';
    if (trend.startsWith('+')) {
      insights.add({
        'title': 'Market Trend',
        'description': 'Your revenue is up $trend this week. Demand for your seasonal produce is peaking in the local market.',
        'icon': Icons.trending_up_rounded,
        'color': AppColors.success,
      });
    } else {
      insights.add({
        'title': 'Market Advice',
        'description': 'Sales are steady. Try featuring your top products to attract more weekend buyers.',
        'icon': Icons.lightbulb_outline_rounded,
        'color': AppColors.accent,
      });
    }

    // 3. Inventory-based insight
    final listings = _stats['activeListings'] as int? ?? 0;
    if (listings < 3) {
      insights.add({
        'title': 'Inventory Opportunity',
        'description': 'You only have $listings active listings. Expanding your catalog can increase visibility by up to 40%.',
        'icon': Icons.add_business_rounded,
        'color': AppColors.primary,
      });
    } else {
      insights.add({
        'title': 'Stall Performance',
        'description': 'Your $listings listings are performing well. Keep descriptions updated to maintain high conversion.',
        'icon': Icons.auto_awesome_rounded,
        'color': AppColors.primary,
      });
    }

    return insights;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _auth,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                if (_isLoadingStats)
                  const LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    minHeight: 2,
                  ),
                _buildPremiumHeader(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Performance Overview'),
                      const SizedBox(height: 16),
                      _buildMetricsGrid(),
                      const SizedBox(height: 24),
                      _buildSectionHeader('Sales Analytics'),
                      const SizedBox(height: 16),
                      _buildSalesAnalytics(),
                      const SizedBox(height: 24),
                      _buildWeatherIntelligence(),
                      const SizedBox(height: 24),
                      _buildHourlyForecast(),
                      const SizedBox(height: 24),
                      _buildForecast(),
                      const SizedBox(height: 24),
                      _buildAICropInsights(),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTextStyles.headline3.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textHeadline,
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.textHeadline.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.1),
                    AppColors.primary.withValues(alpha: 0.1),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: _farmerAvatarUrl != null
                              ? CachedNetworkImage(
                                  key: ValueKey(_farmerAvatarUrl), // 🟢 Force refresh when URL changes
                                  imageUrl: _farmerAvatarUrl!,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) => Container(
                                    width: 52,
                                    height: 52,
                                    color: Colors.grey[100],
                                  ),
                                )
                              : Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.person_rounded,
                                    color: AppColors.primary,
                                    size: 32,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Good Morning,',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSubtle,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _farmerDisplayName,
                                style: AppTextStyles.headline2.copyWith(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildHeaderAction(
                        Icons.notifications_none_rounded,
                        true,
                      ),
                      const SizedBox(width: 12),
                      _buildHeaderAction(Icons.settings_outlined, false),
                    ],
                  ),
                  if (_currentPosition != null && _weatherData != null) ...[
                    const SizedBox(height: 24),
                    _buildWeatherQuickGlance(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAction(IconData icon, bool hasNotification) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.textHeadline.withValues(alpha: 0.1),
            ),
          ),
          child: Icon(icon, color: AppColors.textHeadline, size: 22),
        ),
        if (hasNotification)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWeatherQuickGlance() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getAlertIcon(_weatherData!.description.toLowerCase()),
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _weatherData!.location,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textHeadline,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _weatherData!.description,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textSubtle,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${_weatherData!.temperature.toStringAsFixed(0)}°C',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
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
          child: _buildMetricCard(
            'Total Revenue',
            '₱${_stats['totalRevenue'].toStringAsFixed(0)}',
            _stats['revenueTrend'],
            Icons.payments_outlined,
            AppColors.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            'Active Listings',
            '${_stats['activeListings']}',
            _stats['listingsTrend'],
            Icons.inventory_2_outlined,
            const Color(0xFF3B82F6),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    String trend,
    IconData icon,
    Color color,
  ) {
    final isPositive = trend.startsWith('+');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(value, style: AppTextStyles.headline2.copyWith(fontSize: 24)),
          const SizedBox(height: 4),
          Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                trend,
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 11,
                  color: isPositive ? AppColors.success : AppColors.textSubtle,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSalesAnalytics() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppDecorations.cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(28),
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
                      'Yearly Sales',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSubtle,
                      ),
                    ),
                    Text(
                      '₱${_stats['yearlySales'].toStringAsFixed(2)}',
                      style: AppTextStyles.headline2,
                    ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _stats['revenueTrend'] ?? '0%',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 160,
            child: CustomPaint(
              size: const Size(double.infinity, 160),
              painter: _AnalyticsChartPainter(
                AppColors.primary,
                (_stats['weeklyData'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? List.filled(7, 0.0),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map(
                  (day) => Text(
                    day,
                    style: AppTextStyles.labelSmall.copyWith(
                      fontSize: 10,
                      color: AppColors.textSubtle.withValues(alpha: 0.5),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherIntelligence() {
    if (_isLoadingWeather) {
      return WeatherCardSkeleton(enabled: true);
    }

    if (_weatherError != null || _weatherData == null) {
      return Container();
    }

    final currentAlerts = _weatherData!.alerts;
    final forecastAlerts = _weatherForecast?.alerts ?? [];
    
    final isAlert = currentAlerts.isNotEmpty || forecastAlerts.isNotEmpty;
    final color = isAlert ? AppColors.warning : AppColors.primary;
    final gradientColors = isAlert 
        ? [AppColors.warning.withValues(alpha: 0.15), AppColors.warning.withValues(alpha: 0.05)]
        : [AppColors.primary.withValues(alpha: 0.15), AppColors.primary.withValues(alpha: 0.05)];

    final activeAlert = currentAlerts.isNotEmpty 
        ? currentAlerts.first 
        : (forecastAlerts.isNotEmpty ? forecastAlerts.first : null);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, ...gradientColors],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  isAlert ? Icons.auto_awesome_rounded : Icons.wb_sunny_rounded,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'FARM INTELLIGENCE',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textSubtle,
                              letterSpacing: 1.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isAlert ? AppColors.error : AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: isAlert ? AppColors.error : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      isAlert ? (activeAlert?.title ?? 'Weather Alert') : 'Optimal Conditions',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textHeadline,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loadWeatherData,
                icon: Icon(Icons.refresh_rounded, size: 20, color: AppColors.textSubtle.withValues(alpha: 0.5)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isAlert 
                  ? [color.withValues(alpha: 0.05), color.withValues(alpha: 0.02)]
                  : [AppColors.primary.withValues(alpha: 0.05), AppColors.primary.withValues(alpha: 0.01)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: color.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAlert
                      ? (activeAlert?.description ?? '')
                      : 'Current conditions are optimal for harvesting. Expect stable humidity throughout the day.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    color: AppColors.textHeadline.withValues(alpha: 0.8),
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isAlert && activeAlert!.recommendation != null) ...[
                  const SizedBox(height: 16),
                  Divider(color: color.withValues(alpha: 0.1), height: 1),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, size: 16, color: color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          activeAlert.recommendation ?? '',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textHeadline,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAICropInsights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('AI Farm Insights'),
            Text(
              'View All',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: _generateDynamicInsights().map((insight) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _buildInsightCard(
                  insight['title'],
                  insight['description'],
                  insight['icon'],
                  insight['color'],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInsightCard(
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: AppTextStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 0.5,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            children: [
              Text(
                'Full Report',
                style: AppTextStyles.labelSmall.copyWith(fontSize: 11),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 12,
                color: AppColors.textSubtle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getAlertIcon(String type) {
    if (type.contains('rain')) return Icons.umbrella_rounded;
    if (type.contains('storm')) return Icons.thunderstorm_rounded;
    if (type.contains('wind')) return Icons.air_rounded;
    if (type.contains('heat')) return Icons.thermostat_rounded;
    if (type.contains('flood')) return Icons.flood_rounded;
    return Icons.wb_cloudy_rounded;
  }

  Widget _buildHourlyForecast() {
    if (_isLoadingWeather) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Hourly Forecast'),
          const SizedBox(height: 16),
          Container(
            height: 120,
            decoration: AppDecorations.cardDecoration.copyWith(
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (_weatherForecast == null) return const SizedBox.shrink();

    // Prepare REAL TIME current weather as the first item
    final hourlyData = <ForecastData>[];
    if (_weatherData != null) {
      final now = DateTime.now();
      hourlyData.add(
        ForecastData(
          dateTime: now, // Use exact current time (hour + minute) for "Real Time"
          temperature: _weatherData!.temperature,
          feelsLike: _weatherData!.feelsLike,
          humidity: _weatherData!.humidity,
          windSpeed: _weatherData!.windSpeed,
          cloudiness: _weatherData!.cloudiness,
          pressure: _weatherData!.pressure,
          description: _weatherData!.description,
          icon: _weatherData!.icon,
          rainProbability: _weatherData!.description.toLowerCase().contains('rain') ? 1.0 : 0.0,
        ),
      );
    }

    // Add up to the next 24 hours of data (8 entries if 3-hour intervals)
    final upcomingData = _weatherForecast!.forecasts.where((f) {
      final hoursAhead = f.dateTime.difference(DateTime.now()).inHours;
      return hoursAhead >= 0 && hoursAhead <= 24;
    }).toList();

    for (final f in upcomingData) {
      // Prevent duplicates if forecast matches the current hour
      if (hourlyData.isEmpty || f.dateTime.difference(hourlyData.first.dateTime).inHours.abs() > 0) {
        hourlyData.add(f);
      }
    }

    if (hourlyData.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Hourly Forecast'),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: hourlyData.length,
            itemBuilder: (context, index) {
              final forecast = hourlyData[index];
              final isNow = index == 0;
              
              final pop = ((forecast.rainProbability ?? 0.0) * 100).round();
              final showRainChance = pop > 10;
              
              return Container(
                width: 100,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: isNow ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: isNow 
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: isNow ? null : Border.all(color: AppColors.textHeadline.withValues(alpha: 0.05)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      forecast.timeString,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isNow ? Colors.white.withValues(alpha: 0.8) : AppColors.textSubtle,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isNow ? Colors.white.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getAlertIcon(forecast.description.toLowerCase()),
                        size: 24,
                        color: isNow ? Colors.white : AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${forecast.temperature.toStringAsFixed(0)}°',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isNow ? Colors.white : AppColors.textHeadline,
                      ),
                    ),
                    if (showRainChance) ...[
                      const SizedBox(height: 4),
                      Text(
                        '🌧 $pop%',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isNow ? Colors.white.withValues(alpha: 0.8) : AppColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildForecast() {
    if (_isLoadingWeather) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Weekly Forecast'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: AppDecorations.cardDecoration.copyWith(
              borderRadius: BorderRadius.circular(32),
            ),
            child: ForecastSkeleton(itemCount: 5, enabled: true),
          ),
        ],
      );
    }

    if (_weatherForecast == null) return Container();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Weekly Forecast'),
        const SizedBox(height: 16),
        Container(
          decoration: AppDecorations.cardDecoration.copyWith(
            borderRadius: BorderRadius.circular(32),
            color: Colors.white,
          ),
          child: Column(
            children: _weatherForecast!.getDailyForecast().take(5).indexed.map((entry) {
              final index = entry.$1;
              final f = entry.$2;
              final isLast = index == 4;

              final dayAdvisory = _weatherForecast!.dailyAdvisories.firstWhere(
                (a) => a.day.startsWith(f.dayName) || f.dayName.startsWith(a.day),
                orElse: () => DailyAdvisory(day: '', condition: '', message: '', isSevere: false),
              );
              final hasAdvisory = dayAdvisory.day.isNotEmpty;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showHourlyForecastSheet(context, f.dateTime),
                  borderRadius: BorderRadius.circular(isLast ? 32 : 0),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: isLast ? null : Border(
                        bottom: BorderSide(color: AppColors.textHeadline.withValues(alpha: 0.05)),
                      ),
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
                              letterSpacing: 0.5,
                              color: hasAdvisory ? AppColors.error : AppColors.textHeadline,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: hasAdvisory 
                              ? AppColors.error.withValues(alpha: 0.1) 
                              : AppColors.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getAlertIcon(f.description.toLowerCase()),
                            size: 20,
                            color: hasAdvisory ? AppColors.error : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.description,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  color: AppColors.textHeadline,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (hasAdvisory)
                                Text(
                                  'Special Advisory Available',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
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
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textHeadline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _showHourlyForecastSheet(BuildContext context, DateTime selectedDate) {
    if (_weatherForecast == null) return;
    
    final hourlyData = _weatherForecast!.getHourlyForecastForDate(selectedDate);
    if (hourlyData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hourly data available for this date.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hourly Forecast',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textHeadline,
                          ),
                        ),
                        Text(
                          '${hourlyData.first.dayName}, ${hourlyData.first.dateString}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSubtle,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                      color: AppColors.textSubtle,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: hourlyData.length,
                  itemBuilder: (context, index) {
                    final forecast = hourlyData[index];
                    final pop = ((forecast.rainProbability ?? 0.0) * 100).round();
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.05)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 80,
                            alignment: Alignment.center,
                            child: Text(
                              forecast.timeString,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textHeadline,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getAlertIcon(forecast.description.toLowerCase()),
                              size: 20,
                              color: AppColors.primary,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  forecast.description,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textHeadline,
                                  ),
                                ),
                                if (pop > 0)
                                  Text(
                                    '$pop% chance of rain',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${forecast.temperature.toStringAsFixed(0)}°',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textHeadline,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnalyticsChartPainter extends CustomPainter {
  final Color color;
  final List<double> data;
  _AnalyticsChartPainter(this.color, this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.1)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    final maxVal = data.fold<double>(0, (prev, element) => element > prev ? element : prev);
    final displayMax = maxVal == 0 ? 1.0 : maxVal;

    final points = List.generate(data.length, (i) {
      final x = (size.width / (data.length - 1)) * i;
      // Invert Y: 0 is top, size.height is bottom. 
      // We want high values at the top (near 0) and low values at bottom (near size.height).
      final y = size.height - (size.height * (data[i] / displayMax) * 0.8) - (size.height * 0.1);
      return Offset(x, y);
    });

    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(points[0].dx, points[0].dy);

    for (var i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final controlPoint1 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p1.dy);
      final controlPoint2 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p2.dy);

      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p2.dx,
        p2.dy,
      );
      fillPath.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p2.dx,
        p2.dy,
      );
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    final lastPoint = points.last;
    canvas.drawCircle(lastPoint, 6, Paint()..color = Colors.white);
    canvas.drawCircle(lastPoint, 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
