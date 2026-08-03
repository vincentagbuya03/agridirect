import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/widgets/image_widgets.dart';
import '../../widgets/web_consumer_nav_bar.dart';

/// Web-only Find Farmer Screen — Desktop-optimized 2-column layout with interactive map & farmer directory
class WebFindFarmerScreen extends StatefulWidget {
  final int currentIndex;
  final Function(int)? onNavigate;

  const WebFindFarmerScreen({
    super.key,
    this.currentIndex = 3,
    this.onNavigate,
  });

  @override
  State<WebFindFarmerScreen> createState() => _WebFindFarmerScreenState();
}

class _WebFindFarmerScreenState extends State<WebFindFarmerScreen> {
  static const Color primary = Color(0xFF16A34A);
  static const Color dark = Color(0xFF111827);
  static const Color muted = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
  static const Color background = Color(0xFFF8FAFC);

  static const LatLng _defaultCenter = LatLng(15.9260, 120.3504); // San Carlos City, Pangasinan

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  Future<List<Map<String, dynamic>>>? _farmersFuture;
  List<Map<String, dynamic>> _allFarmers = [];
  List<Map<String, dynamic>> _filteredFarmers = [];

  String _selectedCategory = 'All';
  Map<String, dynamic>? _selectedFarmer;
  bool _isSatellite = false;

  final List<String> _categories = [
    'All',
    'Vegetables',
    'Fruits',
    'Grains',
    'Poultry',
    'Organic',
  ];

  @override
  void initState() {
    super.initState();
    _farmersFuture = _loadFarmers();
    _searchController.addListener(_filterFarmers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadFarmers() async {
    try {
      final auth = AuthService();
      var query = SupabaseConfig.client.from('v_farmer_profiles').select();
      
      if (auth.isLoggedIn && auth.userId.isNotEmpty) {
        query = query.neq('user_id', auth.userId);
      }

      final response = await query.order('farm_name', ascending: true);

      final list = (response as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      if (mounted) {
        setState(() {
          _allFarmers = list;
          _filteredFarmers = list;
          if (list.isNotEmpty) {
            _selectedFarmer = list.first;
          }
        });
      }
      return list;
    } catch (e) {
      debugPrint('Error loading farmers for web find farmer screen: $e');
      return [];
    }
  }

  void _filterFarmers() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredFarmers = _allFarmers.where((farmer) {
        final name = (farmer['farm_name']?.toString() ?? '').toLowerCase();
        final location = (farmer['location']?.toString() ?? '').toLowerCase();
        final specialty = (farmer['specialty']?.toString() ?? '').toLowerCase();

        final matchesQuery = query.isEmpty ||
            name.contains(query) ||
            location.contains(query) ||
            specialty.contains(query);

        final matchesCategory = _selectedCategory == 'All' ||
            specialty.toLowerCase().contains(_selectedCategory.toLowerCase());

        return matchesQuery && matchesCategory;
      }).toList();
    });
  }

  void _focusFarmerOnMap(Map<String, dynamic> farmer) {
    setState(() {
      _selectedFarmer = farmer;
    });

    final lat = farmer['farm_latitude'];
    final lng = farmer['farm_longitude'];

    if (lat is num && lng is num) {
      _mapController.move(LatLng(lat.toDouble(), lng.toDouble()), 13);
    }
  }

  void _handleNavClick(int index) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(index);
    } else {
      switch (index) {
        case 0:
          context.go(AppRoutes.home);
          break;
        case 1:
          context.go(AppRoutes.shop);
          break;
        case 2:
          context.go(AppRoutes.community);
          break;
        case 3:
          // Already on Find Farmer
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 850;

    return Scaffold(
      backgroundColor: background,
      body: Column(
        children: [
          WebConsumerNavBar(
            currentIndex: widget.currentIndex,
            onNavigate: _handleNavClick,
            onCartTap: () => context.go(AppRoutes.cart),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeaderHero(isMobile),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1340),
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 16 : 24),
                        child: isMobile
                            ? Column(
                                children: [
                                  _buildMapCard(height: 340),
                                  const SizedBox(height: 24),
                                  _buildFarmersList(isMobile),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left side: Farmers Directory Grid (60%)
                                  Expanded(
                                    flex: 6,
                                    child: _buildFarmersList(isMobile),
                                  ),
                                  const SizedBox(width: 24),
                                  // Right side: Sticky Interactive Map (40%)
                                  Expanded(
                                    flex: 4,
                                    child: StickyHeaderMap(
                                      child: _buildMapCard(height: 640),
                                    ),
                                  ),
                                ],
                              ),
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
  }

  Widget _buildHeaderHero(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 40,
        vertical: isMobile ? 24 : 36,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withValues(alpha: 0.08),
            primary.withValues(alpha: 0.02),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: const Border(bottom: BorderSide(color: border)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1340),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.travel_explore_rounded, color: primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Find Local Farmers',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isMobile ? 22 : 28,
                          fontWeight: FontWeight.w800,
                          color: dark,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Connect directly with verified agricultural growers across the Philippines',
                        style: GoogleFonts.inter(
                          fontSize: isMobile ? 12 : 14,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Search bar and Category filter bar
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search farm name, location, or crop specialty...',
                          hintStyle: GoogleFonts.inter(color: muted, fontSize: 14),
                          icon: const Icon(Icons.search_rounded, color: primary),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Category chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;

                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          cat,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : dark,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: primary,
                        backgroundColor: Colors.white,
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? primary : border,
                          ),
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _selectedCategory = cat;
                              _filterFarmers();
                            });
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFarmersList(bool isMobile) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _farmersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 300,
            child: Center(child: CircularProgressIndicator(color: primary)),
          );
        }

        if (_filteredFarmers.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                const Icon(Icons.agriculture_outlined, size: 56, color: muted),
                const SizedBox(height: 14),
                Text(
                  'No Local Farmers Found',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: dark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Try adjusting your search criteria or category filter.',
                  style: GoogleFonts.inter(fontSize: 14, color: muted),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Verified Farmers (${_filteredFarmers.length})',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: dark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isMobile ? 1 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: 220,
              ),
              itemCount: _filteredFarmers.length,
              itemBuilder: (context, index) {
                final farmer = _filteredFarmers[index];
                return _buildFarmerCard(farmer);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildFarmerCard(Map<String, dynamic> farmer) {
    final farmName = farmer['farm_name']?.toString() ?? 'Local Farm';
    final location = farmer['location']?.toString() ?? 'Philippines';
    final specialty = farmer['specialty']?.toString() ?? 'Fresh Produce';
    final ratingVal = farmer['average_rating'] ?? 4.9;
    final farmerId = farmer['farmer_id']?.toString() ?? '';
    final imageUrl = farmer['image_url']?.toString();
    final isSelected = _selectedFarmer != null && _selectedFarmer!['farmer_id'] == farmerId;

    return GestureDetector(
      onTap: () => _focusFarmerOnMap(farmer),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? primary : border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? primary.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SafeCircleAvatar(
                  imageUrl: imageUrl,
                  radius: 26,
                  defaultBucket: 'uploads',
                  child: const Icon(Icons.agriculture_rounded, color: primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              farmName,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: dark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, size: 16, color: primary),
                        ],
                      ),
                      Text(
                        specialty,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star_rounded, size: 14, color: Colors.amber.shade700),
                      const SizedBox(width: 3),
                      Text(
                        '$ratingVal',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 15, color: muted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location,
                    style: GoogleFonts.inter(fontSize: 12, color: muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _focusFarmerOnMap(farmer),
                    icon: const Icon(Icons.pin_drop_outlined, size: 15),
                    label: const Text('Pin Map'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: dark,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (farmerId.isNotEmpty) {
                        context.go(AppRoutes.farmerProfile(farmerId));
                      }
                    },
                    icon: const Icon(Icons.storefront_rounded, size: 15),
                    label: const Text('View Farm'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapCard({required double height}) {
    LatLng center = _defaultCenter;

    if (_selectedFarmer != null) {
      final lat = _selectedFarmer!['farm_latitude'];
      final lng = _selectedFarmer!['farm_longitude'];
      if (lat is num && lng is num) {
        center = LatLng(lat.toDouble(), lng.toDouble());
      }
    }

    final markers = _filteredFarmers.map((f) {
      final lat = f['farm_latitude'];
      final lng = f['farm_longitude'];
      if (lat is! num || lng is! num) return null;

      final isSelected = _selectedFarmer != null && _selectedFarmer!['farmer_id'] == f['farmer_id'];
      final imageUrl = f['image_url']?.toString() ?? f['avatar_url']?.toString();

      return Marker(
        point: LatLng(lat.toDouble(), lng.toDouble()),
        width: isSelected ? 48 : 42,
        height: isSelected ? 48 : 42,
        child: GestureDetector(
          onTap: () => _focusFarmerOnMap(f),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? primary : Colors.white,
                width: isSelected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected ? primary.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.25),
                  blurRadius: isSelected ? 12 : 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: SafeCircleAvatar(
                imageUrl: imageUrl,
                radius: isSelected ? 20 : 18,
                defaultBucket: 'uploads',
                child: Icon(
                  Icons.agriculture_rounded,
                  color: primary,
                  size: isSelected ? 20 : 18,
                ),
              ),
            ),
          ),
        ),
      );
    }).whereType<Marker>().toList();

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 11,
              ),
              children: [
                TileLayer(
                  urlTemplate: _isSatellite
                      ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.agridirect.app',
                ),
                MarkerLayer(markers: markers),
              ],
            ),
            // Map controls overlay (Satellite toggle)
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(
                      'Satellite',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: dark,
                      ),
                    ),
                    Switch(
                      value: _isSatellite,
                      activeThumbColor: primary,
                      onChanged: (val) {
                        setState(() {
                          _isSatellite = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            // Selected farmer overlay banner
            if (_selectedFarmer != null)
              Positioned(
                bottom: 14,
                left: 14,
                right: 14,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: primary.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        SafeCircleAvatar(
                          imageUrl: _selectedFarmer!['image_url']?.toString() ?? _selectedFarmer!['avatar_url']?.toString(),
                          radius: 20,
                          defaultBucket: 'uploads',
                          child: const Icon(Icons.agriculture_rounded, color: primary, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedFarmer!['farm_name']?.toString() ?? '',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: dark,
                                ),
                              ),
                              Text(
                                _selectedFarmer!['location']?.toString() ?? '',
                                style: GoogleFonts.inter(fontSize: 11, color: muted),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            final id = _selectedFarmer!['farmer_id']?.toString();
                            if (id != null && id.isNotEmpty) {
                              context.go(AppRoutes.farmerProfile(id));
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'View Profile',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
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
}

class StickyHeaderMap extends StatelessWidget {
  final Widget child;

  const StickyHeaderMap({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
