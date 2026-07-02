import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/router/app_routes.dart';
import 'package:agridirect/shared/widgets/image_widgets.dart';

class FarmersMapScreen extends StatefulWidget {
  const FarmersMapScreen({super.key});

  @override
  State<FarmersMapScreen> createState() => _FarmersMapScreenState();
}

class _FarmersMapScreenState extends State<FarmersMapScreen> {
  static const LatLng _defaultCenter = LatLng(10.4807, 123.4192);
  static const String _cachedFarmersKey = 'cached_farmers_map_v1';
  final MapController _mapController = MapController();
  late Future<List<Map<String, dynamic>>> _farmersFuture;
  int _selectedIndex = 0;
  bool _isSatellite = false; // Add this
  final Map<String, Future<Map<String, String>>> _addressFutureCache = {};

  @override
  void initState() {
    super.initState();
    _farmersFuture = _loadFarmersWithCoordinates();
  }

  void _reloadFarmers() {
    setState(() {
      _selectedIndex = 0;
      _farmersFuture = _loadFarmersWithCoordinates();
    });
  }

  Future<List<Map<String, dynamic>>> _loadFarmersWithCoordinates() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;

      if (!isOnline) {
        return _readCachedFarmers(prefs);
      }

      final rows = await SupabaseConfig.client
          .from('v_farmer_profiles')
          .select(
            'farmer_id, user_id, farm_name, full_name, specialty, location, farm_latitude, farm_longitude, image_url, avatar_url, badge, years_of_experience, farmer_phone, farming_history, is_verified, free_delivery_min_amount',
          )
          .not('farm_latitude', 'is', null)
          .not('farm_longitude', 'is', null)
          .eq('is_active', true);

      final source = (rows as List).cast<Map<String, dynamic>>();
      final farmers = source.where((row) {
        final lat = row['farm_latitude'];
        final lng = row['farm_longitude'];
        return lat is num && lng is num;
      }).toList();

      await prefs.setString(_cachedFarmersKey, jsonEncode(farmers));
      return farmers;
    } catch (e) {
      debugPrint('Error loading farmers map data: $e');
      final cached = _readCachedFarmers(prefs);
      if (cached.isNotEmpty) return cached;
      return [];
    }
  }

  List<Map<String, dynamic>> _readCachedFarmers(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_cachedFarmersKey);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e) {
      debugPrint('Error reading cached farmers map data: $e');
      return [];
    }
  }

  Future<void> _openExternalMap(double latitude, double longitude) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open map application.')),
      );
    }
  }

  String _coordKey(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}';
  }

  String _firstNonEmpty(Map<String, dynamic> address, List<String> keys) {
    for (final key in keys) {
      final value = (address[key] as String?)?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  Future<Map<String, String>> _resolveAddress(
    double latitude,
    double longitude,
  ) {
    final key = _coordKey(latitude, longitude);
    return _addressFutureCache.putIfAbsent(key, () async {
      try {
        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$latitude&lon=$longitude&addressdetails=1',
        );

        final response = await http.get(
          uri,
          headers: {
            'User-Agent':
                'AgriDirect/1.0 (support: noreplyagridirect@gmail.com)',
            'Accept-Language': 'en',
          },
        );

        if (response.statusCode != 200) {
          return {
            'barangay': '',
            'city': '',
            'province': '',
            'full': 'Address unavailable',
          };
        }

        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final address = (json['address'] as Map<String, dynamic>?) ?? {};

        final houseNumber = _firstNonEmpty(address, ['house_number']);
        final road = _firstNonEmpty(address, [
          'road',
          'pedestrian',
          'street',
          'footway',
          'path',
        ]);
        final street = [
          houseNumber,
          road,
        ].where((part) => part.isNotEmpty).join(' ').trim();

        final sitio = _firstNonEmpty(address, [
          'hamlet',
          'isolated_dwelling',
          'allotments',
          'quarter',
          'neighbourhood',
        ]);

        final barangay = _firstNonEmpty(address, ['suburb', 'village']);
        final city = _firstNonEmpty(address, [
          'city',
          'town',
          'municipality',
          'county',
        ]);
        final province = _firstNonEmpty(address, ['state', 'region']);

        final parts = [
          street,
          sitio,
          barangay,
          city,
          province,
        ].where((part) => part.isNotEmpty).toList();

        return {
          'street': street,
          'sitio': sitio,
          'barangay': barangay,
          'city': city,
          'province': province,
          'full': parts.isEmpty ? 'Address unavailable' : parts.join(', '),
        };
      } catch (_) {
        return {
          'barangay': '',
          'city': '',
          'province': '',
          'full': 'Address unavailable',
        };
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Farmers Map'),
        actions: [
          IconButton(
            onPressed: _reloadFarmers,
            tooltip: 'Refresh farms',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _farmersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: AppShimmerLoader());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Failed to load map data: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final farmers = snapshot.data ?? const <Map<String, dynamic>>[];
          if (farmers.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No farm coordinates available yet.\nAdd latitude and longitude in farmer details first.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (_selectedIndex >= farmers.length) {
            _selectedIndex = 0;
          }

          final first = farmers.first;
          final initialCenter = LatLng(
            (first['farm_latitude'] as num).toDouble(),
            (first['farm_longitude'] as num).toDouble(),
          );

          final selected = farmers[_selectedIndex];
          final selectedLat = (selected['farm_latitude'] as num).toDouble();
          final selectedLng = (selected['farm_longitude'] as num).toDouble();

          final markers = farmers.asMap().entries.map((entry) {
            final index = entry.key;
            final farmer = entry.value;
            final latitude = (farmer['farm_latitude'] as num).toDouble();
            final longitude = (farmer['farm_longitude'] as num).toDouble();
            final farmName = (farmer['farm_name'] ?? 'Farm').toString();
            final avatarUrl = farmer['avatar_url'] ?? farmer['image_url'];
            final isSelected = index == _selectedIndex;

            return Marker(
              point: LatLng(latitude, longitude),
              width: 140,
              height: 100,
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedIndex = index);
                  _mapController.move(LatLng(latitude, longitude), 15.0);
                },
                onLongPress: () => _openFarmerInfo(farmer),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          farmName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.accent : AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: SafeNetworkImage(
                              imageUrl: avatarUrl,
                              defaultBucket: 'uploads',
                              fit: BoxFit.cover,
                              placeholder: Container(
                                color: Colors.white,
                                child: Icon(
                                  Icons.agriculture_rounded,
                                  size: 20,
                                  color: isSelected ? AppColors.accent : AppColors.primary,
                                ),
                              ),
                              errorWidget: Container(
                                color: Colors.white,
                                child: Icon(
                                  Icons.agriculture_rounded,
                                  size: 20,
                                  color: isSelected ? AppColors.accent : AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList();

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    _topBadge(
                      icon: Icons.agriculture_rounded,
                      label: '${farmers.length} active farms',
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _topBadge(
                        icon: Icons.touch_app_rounded,
                        label: 'Tap pin, long press for details',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: farmers.isNotEmpty
                                ? initialCenter
                                : _defaultCenter,
                            initialZoom: 12,
                            minZoom: 5,
                            maxZoom: 18,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: _isSatellite
                                  ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                                  : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                              subdomains: const ['a', 'b', 'c', 'd'],
                              userAgentPackageName: 'com.agridirect.app',
                              retinaMode: RetinaMode.isHighDensity(context),
                            ),
                            MarkerLayer(markers: markers),
                          ],
                        ),
                        Positioned(
                          top: 14,
                          right: 14,
                          child: Column(
                            children: [
                              Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                elevation: 3,
                                child: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _isSatellite = !_isSatellite;
                                    });
                                  },
                                  icon: Icon(
                                    _isSatellite
                                        ? Icons.map_rounded
                                        : Icons.layers_rounded,
                                    color: AppColors.primary,
                                  ),
                                  tooltip: _isSatellite
                                      ? 'Switch to Street View'
                                      : 'Switch to Satellite',
                                ),
                              ),
                              const SizedBox(height: 10),
                              Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                elevation: 3,
                                child: IconButton(
                                  onPressed: () => _mapController.move(
                                    LatLng(selectedLat, selectedLng),
                                    15.0,
                                  ),
                                  icon: const Icon(
                                    Icons.my_location_rounded,
                                    color: AppColors.primary,
                                  ),
                                  tooltip: 'Center selected farm',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: _selectedFarmCard(
                            farmer: selected,
                            latitude: selectedLat,
                            longitude: selectedLng,
                            resolvedAddressFuture: _resolveAddress(
                              selectedLat,
                              selectedLng,
                            ),
                            onOpenMap: () =>
                                _openExternalMap(selectedLat, selectedLng),
                            onViewDetails: () => _openFarmerInfo(selected),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _topBadge({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.textHeadline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textHeadline,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectedFarmCard({
    required Map<String, dynamic> farmer,
    required double latitude,
    required double longitude,
    required Future<Map<String, String>> resolvedAddressFuture,
    required VoidCallback onOpenMap,
    required VoidCallback onViewDetails,
  }) {
    final farmName = (farmer['farm_name'] ?? 'Farm').toString();
    final specialty = (farmer['specialty'] ?? 'General Farming').toString();
    final location = (farmer['location'] ?? 'Location unavailable').toString();
    final avatarUrl = farmer['avatar_url'] ?? farmer['image_url'];
    final isVerified = farmer['is_verified'] == true;
    final exp = farmer['years_of_experience']?.toString() ?? '0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1.5),
                ),
                child: ClipOval(
                  child: SafeNetworkImage(
                    imageUrl: avatarUrl,
                    defaultBucket: 'uploads',
                    fit: BoxFit.cover,
                    placeholder: Container(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      child: const Icon(Icons.person, color: AppColors.primary),
                    ),
                    errorWidget: Container(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      child: const Icon(Icons.person, color: AppColors.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            farmName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textHeadline,
                            ),
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, size: 16, color: Colors.blueAccent),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      specialty,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSubtle,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: onViewDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Details',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, String>>(
            future: resolvedAddressFuture,
            builder: (context, snapshot) {
              final address = snapshot.data?['full'];
              final resolved = (address != null && address.isNotEmpty)
                  ? address
                  : location;

              return Row(
                children: [
                  const Icon(
                    Icons.pin_drop_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      resolved,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textHeadline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (exp != '0')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$exp+ Years Exp',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: onOpenMap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.route_rounded, size: 16),
                label: Text(
                  'Navigate',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openFarmerInfo(Map<String, dynamic> farmer) {
    final farmName = (farmer['farm_name'] ?? 'Farm').toString();
    final specialty = (farmer['specialty'] ?? 'General Farming').toString();
    final history = (farmer['farming_history'] ?? '').toString().trim();
    final phone = (farmer['farmer_phone'] ?? '').toString().trim();
    final experience = farmer['years_of_experience']?.toString() ?? '0';
    final avatarUrl = farmer['avatar_url'] ?? farmer['image_url'];
    final isVerified = farmer['is_verified'] == true;
    final farmerId = (farmer['farmer_id'] ?? '').toString();
    final freeDeliveryMin = double.tryParse(farmer['free_delivery_min_amount']?.toString() ?? '0') ?? 0.0;
    final latitude = (farmer['farm_latitude'] as num).toDouble();
    final longitude = (farmer['farm_longitude'] as num).toDouble();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 16,
            left: 24,
            right: 24,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textHeadline.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 2),
                      ),
                      child: ClipOval(
                        child: SafeNetworkImage(
                          imageUrl: avatarUrl,
                          defaultBucket: 'uploads',
                          fit: BoxFit.cover,
                          placeholder: Container(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            child: const Icon(Icons.person, size: 28, color: AppColors.primary),
                          ),
                          errorWidget: Container(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            child: const Icon(Icons.person, size: 28, color: AppColors.primary),
                          ),
                        ),
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
                                  farmName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textHeadline,
                                  ),
                                ),
                              ),
                              if (isVerified) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.verified_rounded, size: 20, color: Colors.blueAccent),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            specialty,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSubtle,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),
                
                // Details Grid
                Row(
                  children: [
                    if (experience != '0') ...[
                      Expanded(
                        child: _detailTile(
                          icon: Icons.history_edu_rounded,
                          title: 'Experience',
                          value: '$experience+ Years',
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    if (freeDeliveryMin > 0)
                      Expanded(
                        child: _detailTile(
                          icon: Icons.local_shipping_rounded,
                          title: 'Free Delivery',
                          value: '₱${freeDeliveryMin.toInt()}+',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                FutureBuilder<Map<String, String>>(
                  future: _resolveAddress(latitude, longitude),
                  builder: (context, snapshot) {
                    final address = snapshot.data;
                    final fullAddress = address?['full'] ?? (farmer['location'] ?? 'Location unavailable').toString();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Farm Location',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textHeadline,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.pin_drop_rounded, size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                fullAddress,
                                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textBody),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                if (history.isNotEmpty) ...[
                  Text(
                    'About the Farm',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textHeadline,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      history,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: const Color(0xFF475569),
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                Row(
                  children: [
                    if (phone.isNotEmpty) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: const BorderSide(color: AppColors.primary),
                          ),
                          icon: const Icon(Icons.phone_rounded, color: AppColors.primary),
                          label: Text(
                            'Call Farmer',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (farmerId.isNotEmpty)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            context.push(AppRoutes.farmerProfile(farmerId));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.storefront_rounded),
                          label: Text(
                            'Visit Shop',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailTile({required IconData icon, required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: AppColors.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSubtle,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textHeadline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

