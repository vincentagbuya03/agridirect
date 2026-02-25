import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Marketplace Screen matching the design mockup.
/// Product grid with filters/chips, heart icons, prices.
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  static const Color primary = Color(0xFF13EC5B);
  int _selectedFilter = 0;

  final _filters = ['All Products', 'Vegetables', 'Fruits', 'Dairy', 'Grains'];

  final _products = const [
    _ProductData(
      imageUrl:
          'https://images.unsplash.com/photo-1464965911861-746a04b4bca6?w=400',
      badge: 'ORGANIC FARM',
      name: 'Fresh Strawberries',
      farm: 'Sunnyside Acres',
      distance: '2.4mi',
      price: '\$6.50',
      unit: '/lb',
    ),
    _ProductData(
      imageUrl:
          'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?w=400',
      badge: 'PASTURE RAISED',
      name: 'Dozen Brown Eggs',
      farm: 'Maple Ridge Farm',
      distance: '4.1mi',
      price: '\$7.20',
      unit: '/dz',
    ),
    _ProductData(
      imageUrl:
          'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=400',
      badge: 'NON-GMO',
      name: 'Organic Curly Kale',
      farm: 'Green Valley',
      distance: '1.8mi',
      price: '\$3.99',
      unit: '/bn',
    ),
    _ProductData(
      imageUrl:
          'https://images.unsplash.com/photo-1587049352846-4a222e784d38?w=400',
      badge: 'LOCAL HONEY',
      name: 'Wildflower Honey',
      farm: 'Bee Happy Apiary',
      distance: '5.0mi',
      price: '\$12.00',
      unit: '/16oz',
    ),
    _ProductData(
      imageUrl:
          'https://images.unsplash.com/photo-1447175008436-054170c2e979?w=400',
      badge: 'HERITAGE',
      name: 'Rainbow Carrots',
      farm: 'Hillside Organic',
      distance: '3.2mi',
      price: '\$4.50',
      unit: '/bn',
    ),
    _ProductData(
      imageUrl:
          'https://images.unsplash.com/photo-1563636619-e9143da7973b?w=400',
      badge: 'GRASS FED',
      name: 'Whole Raw Milk',
      farm: 'Dairy Delight',
      distance: '6.7mi',
      price: '\$8.50',
      unit: '/gal',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterChips(),
            _buildLocationBar(),
            Expanded(child: _buildProductGrid()),
          ],
        ),
      ),
    );
  }

  // ── Header with title, cart, search ──
  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.bolt, color: primary, size: 26),
              const SizedBox(width: 8),
              Text(
                'AgriDirect',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              // Cart icon with badge
              Stack(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.shopping_cart_outlined,
                      size: 22,
                      color: Color(0xFF334155),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Color(0xFF13EC5B),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '3',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Search bar
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Icon(Icons.search, color: Colors.grey[400], size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Search honey, kale, eggs...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.tune, color: Colors.white, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Filter Chips ──
  Widget _buildFilterChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final isSelected = _selectedFilter == i;
            return GestureDetector(
              onTap: () => setState(() => _selectedFilter = i),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? primary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? primary : Colors.grey[300]!,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      _filters[i],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF475569),
                      ),
                    ),
                    if (!isSelected && i > 0) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 16,
                        color: Colors.grey[500],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Location bar ──
  Widget _buildLocationBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Fresh from the Source',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          Row(
            children: [
              Icon(Icons.location_on, color: primary, size: 16),
              const SizedBox(width: 4),
              Text(
                'Near Seattle, WA',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Product Grid ──
  Widget _buildProductGrid() {
    return Stack(
      children: [
        GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.62,
          ),
          itemCount: _products.length,
          itemBuilder: (_, i) => _buildProductCard(_products[i]),
        ),
        // Bottom filter pills
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFilterPill(Icons.sell, '\$2 - \$50', primary),
              const SizedBox(width: 10),
              _buildFilterPill(
                Icons.location_on,
                'Within 10 miles',
                const Color(0xFF334155),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(_ProductData product) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image with heart
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: CachedNetworkImage(
                  imageUrl: product.imageUrl,
                  height: 130,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(height: 130, color: Colors.grey[200]),
                  errorWidget: (_, __, ___) => Container(
                    height: 130,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image, color: Colors.grey),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_border,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge
                  Text(
                    product.badge,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Name
                  Text(
                    product.name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Farm + distance
                  Text(
                    '${product.farm} · ${product.distance}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  // Price + Add button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: product.price,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            TextSpan(
                              text: product.unit,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductData {
  final String imageUrl;
  final String badge;
  final String name;
  final String farm;
  final String distance;
  final String price;
  final String unit;

  const _ProductData({
    required this.imageUrl,
    required this.badge,
    required this.name,
    required this.farm,
    required this.distance,
    required this.price,
    required this.unit,
  });
}
