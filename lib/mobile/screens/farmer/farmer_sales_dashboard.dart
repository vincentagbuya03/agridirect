import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../../../shared/router/app_routes.dart';
import '../../../shared/services/integration/weather_service.dart';
import '../../../shared/models/weather_model.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/services/farmer/farmer_service.dart';
import '../../../shared/services/offline/offline_product_service.dart';
import '../../../shared/services/community/notification_service.dart';
import '../../../shared/services/community/message_service.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../support/kiko_ai_chat_screen.dart';
import 'weather_detail_screen.dart';

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
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  Timer? _refreshTimer;

  Map<String, dynamic> _stats = {
    'totalRevenue': 0.0,
    'activeListings': 0,
    'followers': 0,
    'communityPosts': 0,
    'yearlySales': 0.0,
    'revenueTrend': '+0%',
    'listingsTrend': '0%',
  };
  bool _isSpeedDialOpen = false;
  int _selectedAnalyticsPeriod = 0; // 0: Week, 1: Month, 2: Year

  late Stream<int> _unreadMessagesStream;
  late Stream<int> _unreadNotificationsStream;

  @override
  void initState() {
    super.initState();
    _unreadMessagesStream = MessageService().watchTotalUnreadCount(
      asFarmer: true,
    );
    _unreadNotificationsStream = NotificationService().watchUnreadCount();
    _loadCachedDbAvatar();
    _loadFarmerProfile();
    _loadDashboardStats();
    _initializeLocationTracking();
    _startPeriodicRefresh();
    OfflineProductService().init();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      if (mounted) {
        _loadWeatherData();
        _loadDashboardStats();
      }
    });
  }

  String get _farmerDisplayName {
    final authName = _auth.userName.trim();
    if (authName.isNotEmpty) {
      return authName.split(' ').first;
    }
    final profileName = _profileName?.trim() ?? '';
    if (profileName.isNotEmpty) {
      return profileName.split(' ').first;
    }
    final metadata = _auth.client.auth.currentUser?.userMetadata;
    final metaName =
        ((metadata?['name'] ?? metadata?['full_name']) as String?)?.trim() ??
        '';
    if (metaName.isNotEmpty) {
      return metaName.split(' ').first;
    }
    return 'Farmer';
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
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

    String finalUrl = cached;
    if (!cached.startsWith('http')) {
      finalUrl = await SupabaseDatabase.getSafeUrl(
        cached,
        defaultBucket: 'uploads',
      );
    }

    if (mounted && finalUrl.isNotEmpty) {
      setState(() => _cachedDbAvatarUrl = finalUrl);
    }
  }

  Future<void> _persistDbAvatar(String? imageUrl) async {
    final url = imageUrl?.trim() ?? '';
    if (url.isEmpty) return;
    final currentUserId = _resolveCurrentUserId();
    if (currentUserId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dbAvatarCacheKey(currentUserId), url);
    if (mounted) setState(() => _cachedDbAvatarUrl = url);
  }

  Future<void> _loadFarmerProfile() async {
    final currentUserId = _resolveCurrentUserId();
    if (currentUserId.isEmpty) return;

    try {
      final farmers = await SupabaseConfig.client
          .from('farmers')
          .select('farm_name')
          .eq('user_id', currentUserId)
          .limit(1);

      String? farmName;
      if (farmers.isNotEmpty) {
        farmName = (farmers[0]['farm_name'] as String?)?.trim();
      }

      final profile = await SupabaseDatabase.getUserProfile(currentUserId);
      if (!mounted) return;

      final rawAvatarUrl = profile != null
          ? ((profile['avatar_url'] as String?)?.trim() ?? '')
          : '';
      final safeUrl = await SupabaseDatabase.getSafeUrl(
        rawAvatarUrl,
        defaultBucket: 'uploads',
      );

      if (mounted) {
        setState(() {
          _profileName = farmName ?? (profile?['name'] as String?)?.trim();
          _profileAvatarUrl = safeUrl;
        });
        await _persistDbAvatar(safeUrl);
      }
    } catch (e) {
      debugPrint('Error loading farmer profile: $e');
    }
  }

  Future<void> _initializeLocationTracking() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        try {
          final lastPosition = await Geolocator.getLastKnownPosition();
          if (lastPosition != null) {
            _currentPosition = lastPosition;
            _loadWeatherData();
          }
        } catch (_) {}

        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 12),
          );
          _currentPosition = position;
          await _loadWeatherData();
        } catch (_) {
          if (_currentPosition == null) {
            _loadWeatherData();
          }
        }

        _positionStream = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            distanceFilter: 1000,
          ),
        ).listen((Position position) {
          if (mounted) {
            setState(() => _currentPosition = position);
            _loadWeatherData();
          }
        });
      } else {
        _loadWeatherData();
      }
    } catch (e) {
      debugPrint('Location tracking init error: $e');
      _loadWeatherData();
    }
  }

  Future<void> _loadWeatherData() async {
    try {
      Position? position = _currentPosition;
      if (mounted) setState(() => _isLoadingWeather = true);

      WeatherData? weatherData;
      WeatherForecast? forecast;

      if (position != null) {
        weatherData = await WeatherService().getWeatherByCoordinates(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        forecast = await WeatherService().getForecastByCoordinates(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      } else {
        weatherData = await WeatherService().getWeatherByCity('Benguet');
        forecast = await WeatherService().getForecastByCity('Benguet');
      }

      if (mounted) {
        setState(() {
          _weatherData = weatherData;
          _weatherForecast = forecast;
          _isLoadingWeather = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingWeather = false;
        });
      }
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      final stats = await FarmerService().getFarmerStats();
      if (mounted) {
        setState(() {
          _stats = stats;
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  void _openKikoWeatherAiChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const KikoAiChatScreen(embedMode: false),
      ),
    );
  }

  void _openWeatherDetailScreen() {
    if (_weatherData == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WeatherDetailScreen(
          weatherData: _weatherData!,
          forecast: _weatherForecast,
          currentPosition: _currentPosition,
          onRefresh: () async => await _loadWeatherData(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _auth,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    _loadDashboardStats(),
                    _loadWeatherData(),
                    _loadFarmerProfile(),
                  ]);
                },
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 50, 16, 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 18),
                      _buildWeatherAiCard(),
                      const SizedBox(height: 24),
                      _buildSectionTitle(
                        'Performance Overview',
                        subtitle: 'Real-time sales & inventory metrics',
                      ),
                      const SizedBox(height: 14),
                      _buildPerformanceBento(),
                      const SizedBox(height: 24),
                      _buildSectionTitle(
                        'Quick Operations',
                        subtitle: 'Primary shortcuts for your farm',
                      ),
                      const SizedBox(height: 14),
                      _buildQuickOperationsGrid(),
                      const SizedBox(height: 24),
                      _buildSectionTitle(
                        'Sales Analytics',
                        subtitle: 'Gross revenue trajectory & trends',
                      ),
                      const SizedBox(height: 14),
                      _buildSalesAnalyticsCard(),
                    ],
                  ),
                ),
              ),

              // Floating Speed Dial Overlay
              if (_isSpeedDialOpen)
                GestureDetector(
                  onTap: () => setState(() => _isSpeedDialOpen = false),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.4),
                  ),
                ),

              // Speed Dial Items
              _buildFloatingSpeedDial(),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 1. TOP HEADER COMPONENT
  // ===========================================================================
  Widget _buildHeader() {
    final avatarUrl = _farmerAvatarUrl;

    return Row(
      children: [
        // Avatar + Emerald Online Dot
        Stack(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  width: 2,
                ),
                color: Colors.white,
              ),
              child: ClipOval(
                child: avatarUrl != null && avatarUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            _buildAvatarFallback(),
                      )
                    : _buildAvatarFallback(),
              ),
            ),
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),

        // Greeting & Name
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_greeting,',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
              Text(
                _farmerDisplayName,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Header Action Icons
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Messages
            StreamBuilder<int>(
              stream: _unreadMessagesStream,
              builder: (context, snapshot) {
                final unread = snapshot.data ?? 0;
                return _buildHeaderIconButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  badgeCount: unread,
                  onTap: () => context.push(AppRoutes.messages),
                );
              },
            ),
            const SizedBox(width: 8),

            // Notifications
            StreamBuilder<int>(
              stream: _unreadNotificationsStream,
              builder: (context, snapshot) {
                final unread = snapshot.data ?? 0;
                return _buildHeaderIconButton(
                  icon: Icons.notifications_none_rounded,
                  badgeCount: unread,
                  onTap: () => context.push(AppRoutes.notifications),
                );
              },
            ),
            const SizedBox(width: 8),

            // Settings
            _buildHeaderIconButton(
              icon: Icons.settings_outlined,
              onTap: () => context.push(AppRoutes.appSettings),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatarFallback() {
    final initials = _farmerDisplayName.isNotEmpty
        ? _farmerDisplayName[0].toUpperCase()
        : 'F';
    return Container(
      color: AppColors.primary.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    return Stack(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Icon(icon, size: 19, color: const Color(0xFF334155)),
            ),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            top: 3,
            right: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  // ===========================================================================
  // 2. AGRONOMIC WEATHER AI CARD (CLICKABLE TO WEATHER DETAILS)
  // ===========================================================================
  Widget _buildWeatherAiCard() {
    if (_isLoadingWeather && _weatherData == null) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    final weather = _weatherData;
    final temp = weather?.temperature.toStringAsFixed(0) ?? '27';
    final location = weather?.location ?? 'Benguet';
    final conditionDesc = weather?.description ?? 'Partly Cloudy';
    final isRainy = conditionDesc.toLowerCase().contains('rain') ||
        conditionDesc.toLowerCase().contains('shower') ||
        conditionDesc.toLowerCase().contains('thunder');
    final isHot = (weather?.temperature ?? 27) >= 31;
    final humidity = weather?.humidity ?? 78;
    final windSpeed = weather?.windSpeed.toStringAsFixed(1) ?? '12';

    // AI Generated Advisory Text
    String aiTitle;
    String aiAdvisory;
    IconData advisoryIcon;

    if (isRainy) {
      aiTitle = 'Rain Defense & Field Drainage';
      aiAdvisory =
          'Rainfall detected in $location. Postpone foliar spraying to prevent chemical runoff. Inspect drainage furrows for root crops like potatoes & carrots.';
      advisoryIcon = Icons.thunderstorm_rounded;
    } else if (isHot) {
      aiTitle = 'Heat Stress & Irrigation Window';
      aiAdvisory =
          'High temperature ($temp°C) forecast. Accelerate early morning irrigation (5:30–7:30 AM) and inspect mulching to conserve moisture in root zones.';
      advisoryIcon = Icons.wb_sunny_rounded;
    } else {
      aiTitle = 'Optimal Cultivation Window';
      aiAdvisory =
          'Favorable weather in $location ($temp°C). Optimal window for transplanting seedlings, weeding, and applying organic bio-stimulants.';
      advisoryIcon = Icons.eco_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF064E3B), // Emerald 900
            Color(0xFF047857), // Emerald 700
            Color(0xFF0D9488), // Teal 600
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF047857).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: AI Tag + Tappable Live Weather Capsule
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // AI Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF34D399),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'WEATHER AI',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tappable Live Capsule -> Opens WeatherDetailScreen
                  Flexible(
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: _openWeatherDetailScreen,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isRainy
                                    ? Icons.water_drop_rounded
                                    : Icons.wb_sunny_rounded,
                                size: 13,
                                color: isRainy
                                    ? const Color(0xFF38BDF8)
                                    : const Color(0xFFFBBF24),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '$location • $temp°C',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 14,
                                color: Colors.white70,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Weather Metrics Strip
              Row(
                children: [
                  _buildMicroWeatherMetric(
                    icon: Icons.thermostat_rounded,
                    label: '$temp°C',
                    sublabel: conditionDesc,
                  ),
                  const SizedBox(width: 10),
                  _buildMicroWeatherMetric(
                    icon: Icons.water_drop_outlined,
                    label: '$humidity%',
                    sublabel: 'Humidity',
                  ),
                  const SizedBox(width: 10),
                  _buildMicroWeatherMetric(
                    icon: Icons.air_rounded,
                    label: '$windSpeed km/h',
                    sublabel: 'Wind',
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // AI Agronomic Advisory Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        advisoryIcon,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            aiTitle,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            aiAdvisory,
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontSize: 11.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Bottom Actions: Consult AI & Detailed Weather Forecast
              Row(
                children: [
                  // Consult Kiko AI Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _openKikoWeatherAiChat,
                      icon: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 15,
                        color: Color(0xFFFBBF24),
                      ),
                      label: Text(
                        'Consult Kiko AI',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF064E3B),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Full Weather Details Screen Button
                  OutlinedButton.icon(
                    onPressed: _openWeatherDetailScreen,
                    icon: const Icon(
                      Icons.cloud_outlined,
                      size: 15,
                      color: Colors.white,
                    ),
                    label: Text(
                      'Radar & Details',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMicroWeatherMetric({
    required IconData icon,
    required String label,
    required String sublabel,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.white70),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    sublabel,
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 9.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. EXECUTIVE PERFORMANCE BENTO GRID
  // ===========================================================================
  Widget _buildPerformanceBento() {
    final revenue = (_stats['totalRevenue'] as num?)?.toDouble() ?? 0.0;
    final revenueTrend = _stats['revenueTrend']?.toString() ?? '+0%';
    final activeListings = _stats['activeListings'] as int? ?? 0;
    final followers = _stats['followers'] as int? ?? 0;
    final posts = _stats['communityPosts'] as int? ?? 0;

    return Column(
      children: [
        Row(
          children: [
            // Revenue Card
            Expanded(
              child: _buildBentoCard(
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFF059669),
                iconBg: const Color(0xFFECFDF5),
                title: 'TOTAL REVENUE',
                value: '₱${revenue.toStringAsFixed(2)}',
                trendText: revenueTrend,
                isPositiveTrend: !revenueTrend.startsWith('-'),
                subtitle: 'All-time gross sales',
                onTap: () {
                  SupabaseDataService.navigationTabNotifier.value = 2;
                },
              ),
            ),
            const SizedBox(width: 12),

            // Active Listings Card
            Expanded(
              child: _buildBentoCard(
                icon: Icons.inventory_2_rounded,
                iconColor: const Color(0xFF2563EB),
                iconBg: const Color(0xFFEFF6FF),
                title: 'ACTIVE LISTINGS',
                value: '$activeListings',
                trendText: '$activeListings Live',
                isPositiveTrend: activeListings > 0,
                subtitle: 'Published in store',
                onTap: () {
                  SupabaseDataService.navigationTabNotifier.value = 1;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Followers Card
            Expanded(
              child: _buildBentoCard(
                icon: Icons.people_alt_rounded,
                iconColor: const Color(0xFF7C3AED),
                iconBg: const Color(0xFFF5F3FF),
                title: 'SUBSCRIBERS',
                value: '$followers',
                trendText: 'Reach',
                isPositiveTrend: true,
                subtitle: 'Farmer store fans',
                onTap: () => context.push(AppRoutes.farmerFollowers),
              ),
            ),
            const SizedBox(width: 12),

            // Community Posts Card
            Expanded(
              child: _buildBentoCard(
                icon: Icons.forum_rounded,
                iconColor: const Color(0xFFD97706),
                iconBg: const Color(0xFFFFFBEB),
                title: 'COMMUNITY POSTS',
                value: '$posts',
                trendText: 'Engaged',
                isPositiveTrend: true,
                subtitle: 'Community updates',
                onTap: () {
                  SupabaseDataService.navigationTabNotifier.value = 3;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBentoCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String value,
    required String trendText,
    required bool isPositiveTrend,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Icon & Trend Tag
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: iconColor, size: 18),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isPositiveTrend
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        trendText,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isPositiveTrend
                              ? const Color(0xFF059669)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),

                // Value (Prominent, formatted)
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),

                // Subtitle
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 4. QUICK OPERATIONS
  // ===========================================================================
  Widget _buildQuickOperationsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildOperationTile(
            title: 'Add Produce',
            icon: Icons.add_circle_outline_rounded,
            color: const Color(0xFF059669),
            bg: const Color(0xFFECFDF5),
            onTap: () => context.push(AppRoutes.addProduct),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildOperationTile(
            title: 'Orders',
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFF2563EB),
            bg: const Color(0xFFEFF6FF),
            onTap: () {
              SupabaseDataService.navigationTabNotifier.value = 2;
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildOperationTile(
            title: 'Vouchers',
            icon: Icons.confirmation_number_outlined,
            color: const Color(0xFF7C3AED),
            bg: const Color(0xFFF5F3FF),
            onTap: () => context.push(AppRoutes.farmerVouchers),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildOperationTile(
            title: 'Community',
            icon: Icons.hub_outlined,
            color: const Color(0xFFD97706),
            bg: const Color(0xFFFFFBEB),
            onTap: () {
              SupabaseDataService.navigationTabNotifier.value = 3;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOperationTile({
    required String title,
    required IconData icon,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: bg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 5. SALES ANALYTICS CARD
  // ===========================================================================
  Widget _buildSalesAnalyticsCard() {
    final revenue = (_stats['totalRevenue'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period Selector Chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'REVENUE TRAJECTORY',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₱${revenue.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildPeriodChip(0, '7D'),
                  const SizedBox(width: 4),
                  _buildPeriodChip(1, '30D'),
                  const SizedBox(width: 4),
                  _buildPeriodChip(2, '1Y'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Chart Canvas
          SizedBox(
            height: 120,
            width: double.infinity,
            child: CustomPaint(
              painter: _AnalyticsChartPainter(
                AppColors.primary,
                [
                  revenue * 0.2,
                  revenue * 0.4,
                  revenue * 0.35,
                  revenue * 0.6,
                  revenue * 0.75,
                  revenue * 0.8,
                  revenue,
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Chart Days Axis
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildAxisLabel('Mon'),
              _buildAxisLabel('Tue'),
              _buildAxisLabel('Wed'),
              _buildAxisLabel('Thu'),
              _buildAxisLabel('Fri'),
              _buildAxisLabel('Sat'),
              _buildAxisLabel('Sun'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(int index, String label) {
    final isSelected = _selectedAnalyticsPeriod == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedAnalyticsPeriod = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildAxisLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF94A3B8),
      ),
    );
  }

  // ===========================================================================
  // 6. SPEED DIAL & FLOATING ACTION
  // ===========================================================================
  Widget _buildFloatingSpeedDial() {
    return Positioned(
      right: 16,
      bottom: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isSpeedDialOpen) ...[
            _buildSpeedDialItem(
              label: 'Add Produce',
              icon: Icons.inventory_2_outlined,
              color: AppColors.primary,
              onTap: () {
                setState(() => _isSpeedDialOpen = false);
                context.push(AppRoutes.addProduct);
              },
            ),
            const SizedBox(height: 12),
            _buildSpeedDialItem(
              label: 'New Voucher',
              icon: Icons.confirmation_number_outlined,
              color: const Color(0xFF7C3AED),
              onTap: () {
                setState(() => _isSpeedDialOpen = false);
                context.push(AppRoutes.farmerVouchers);
              },
            ),
            const SizedBox(height: 12),
            _buildSpeedDialItem(
              label: 'Weather & Radar',
              icon: Icons.cloud_outlined,
              color: const Color(0xFF0D9488),
              onTap: () {
                setState(() => _isSpeedDialOpen = false);
                _openWeatherDetailScreen();
              },
            ),
            const SizedBox(height: 12),
            _buildSpeedDialItem(
              label: 'Consult Weather AI',
              icon: Icons.auto_awesome_rounded,
              color: const Color(0xFF059669),
              onTap: () {
                setState(() => _isSpeedDialOpen = false);
                _openKikoWeatherAiChat();
              },
            ),
            const SizedBox(height: 14),
          ],

          // Main FAB Button
          FloatingActionButton(
            onPressed: () => setState(() => _isSpeedDialOpen = !_isSpeedDialOpen),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: const CircleBorder(),
            child: AnimatedRotation(
              turns: _isSpeedDialOpen ? 0.125 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.add_rounded, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedDialItem({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// CHART PAINTER
// =============================================================================
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
        colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    final maxVal = data.fold<double>(
      0,
      (prev, element) => element > prev ? element : prev,
    );
    final displayMax = maxVal == 0 ? 1.0 : maxVal;

    final points = List.generate(data.length, (i) {
      final x = (size.width / (data.length - 1)) * i;
      final y =
          size.height -
          (size.height * (data[i] / displayMax) * 0.75) -
          (size.height * 0.1);
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
