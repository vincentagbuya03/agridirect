import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/styles/app_theme.dart';

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
          .from('farmers')
          .select(
            'farm_name, specialty, location, farm_latitude, farm_longitude',
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
            final specialty = (farmer['specialty'] ?? 'No specialty')
                .toString();
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
                onLongPress: () => _openFarmerInfo(
                  farmName: farmName,
                  specialty: specialty,
                  latitude: latitude,
                  longitude: longitude,
                ),
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
                              color: Colors.black.withValues(alpha: 0.1),
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
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.elasticOut,
                          width: isSelected ? 48 : 36,
                          height: isSelected ? 48 : 36,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.accent : Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: (isSelected ? AppColors.accent : AppColors.primary)
                                      .withValues(alpha: 0.2),
                                  blurRadius: isSelected ? 12 : 6,
                                  spreadRadius: isSelected ? 2 : 0,
                              ),
                            ],
                            border: Border.all(
                              color: isSelected ? Colors.white : AppColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.agriculture_rounded,
                          size: isSelected ? 24 : 18,
                          color: isSelected ? Colors.white : AppColors.primary,
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
                            farmName: (selected['farm_name'] ?? 'Farm')
                                .toString(),
                            specialty: (selected['specialty'] ?? 'No specialty')
                                .toString(),
                            location:
                                (selected['location'] ?? 'Location unavailable')
                                    .toString(),
                            latitude: selectedLat,
                            longitude: selectedLng,
                            resolvedAddressFuture: _resolveAddress(
                              selectedLat,
                              selectedLng,
                            ),
                            onOpenMap: () =>
                                _openExternalMap(selectedLat, selectedLng),
                            onViewDetails: () => _openFarmerInfo(
                              farmName: (selected['farm_name'] ?? 'Farm')
                                  .toString(),
                              specialty:
                                  (selected['specialty'] ?? 'No specialty')
                                      .toString(),
                              latitude: selectedLat,
                              longitude: selectedLng,
                            ),
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
    required String farmName,
    required String specialty,
    required String location,
    required double latitude,
    required double longitude,
    required Future<Map<String, String>> resolvedAddressFuture,
    required VoidCallback onOpenMap,
    required VoidCallback onViewDetails,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 5),
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
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.agriculture_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  farmName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headline3.copyWith(fontSize: 16),
                ),
              ),
              TextButton(
                onPressed: onViewDetails,
                child: const Text('Details'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            specialty,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSubtle,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
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
                    Icons.pin_drop_outlined,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      resolved,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textHeadline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Spacer(),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onOpenMap,
                icon: const Icon(Icons.route_rounded, size: 16),
                label: const Text('Navigate'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openFarmerInfo({
    required String farmName,
    required String specialty,
    required double latitude,
    required double longitude,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<Map<String, String>>(
              future: _resolveAddress(latitude, longitude),
              builder: (context, snapshot) {
                final address = snapshot.data;
                final street = (address?['street'] ?? '').trim();
                final sitio = (address?['sitio'] ?? '').trim();
                final barangay = (address?['barangay'] ?? '').trim();
                final city = (address?['city'] ?? '').trim();
                final province = (address?['province'] ?? '').trim();

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(farmName, style: AppTextStyles.headline3),
                    const SizedBox(height: 8),
                    Text(specialty, style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 10),
                    if (street.isNotEmpty)
                      Text('Street: $street', style: AppTextStyles.bodySmall),
                    if (sitio.isNotEmpty)
                      Text(
                        'Sitio/Purok: $sitio',
                        style: AppTextStyles.bodySmall,
                      ),
                    if (barangay.isNotEmpty)
                      Text(
                        'Barangay: $barangay',
                        style: AppTextStyles.bodySmall,
                      ),
                    if (city.isNotEmpty)
                      Text(
                        'City/Municipality: $city',
                        style: AppTextStyles.bodySmall,
                      ),
                    if (province.isNotEmpty)
                      Text(
                        'Province: $province',
                        style: AppTextStyles.bodySmall,
                      ),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Resolving address from pin...',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSubtle,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openExternalMap(latitude, longitude),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Open in Maps'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

