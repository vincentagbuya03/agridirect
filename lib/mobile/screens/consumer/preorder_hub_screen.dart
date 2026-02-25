import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Pre-Order Hub Screen matching the design mockup.
/// Pre-order cards with countdown days, progress bars, reserve buttons.
class PreOrderHubScreen extends StatefulWidget {
  const PreOrderHubScreen({super.key});

  @override
  State<PreOrderHubScreen> createState() => _PreOrderHubScreenState();
}

class _PreOrderHubScreenState extends State<PreOrderHubScreen> {
  static const Color primary = Color(0xFF13EC5B);
  int _selectedFilter = 0;

  final _filters = ['All Crops', 'Vegetables', 'Fruits', 'Organic', 'Grains'];

  final _preOrders = const [
    _PreOrderData(
      imageUrl:
          'https://images.unsplash.com/photo-1464965911861-746a04b4bca6?w=600',
      daysLeft: 12,
      price: '\$4.50',
      discount: '20% OFF PRE-ORDER',
      name: 'Summer Strawberries',
      farm: "Farmer John's Organic Acres",
      reserved: 80,
      target: '500 lbs',
      isAlmostGone: false,
    ),
    _PreOrderData(
      imageUrl:
          'https://images.unsplash.com/photo-1568702846914-96b305d2aaeb?w=600',
      daysLeft: 5,
      price: '\$3.20',
      discount: 'EARLY BIRD',
      name: 'Heritage Green Cabbage',
      farm: 'Blue Ridge Valley Farms',
      reserved: 92,
      target: '300 lbs',
      isAlmostGone: true,
    ),
    _PreOrderData(
      imageUrl:
          'https://images.unsplash.com/photo-1518977676601-b53f82ber630?w=600',
      daysLeft: 8,
      price: '\$5.00',
      discount: '15% OFF PRE-ORDER',
      name: 'Vine-Ripened Tomatoes',
      farm: 'Sunnyvale Farms',
      reserved: 65,
      target: '400 lbs',
      isAlmostGone: false,
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
            _buildSectionTitle(),
            Expanded(child: _buildPreOrderList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF0F172A),
        child: const Icon(Icons.bookmark_outline, color: Colors.white),
      ),
    );
  }

  // ── Header ──
  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.eco_rounded, color: primary, size: 26),
              const SizedBox(width: 8),
              Text(
                'Pre-Order Hub',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: primary, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'San Francisco, CA',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Search bar
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Icon(Icons.search, color: Colors.grey[400], size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Search crops...',
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.tune,
                  size: 20,
                  color: Color(0xFF475569),
                ),
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
        height: 38,
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
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? primary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? primary : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  _filters[i],
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Section title ──
  Widget _buildSectionTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Icon(Icons.bolt, color: primary, size: 20),
          const SizedBox(width: 6),
          Text(
            'Ending Soon',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const Spacer(),
          Text(
            'See all',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Pre-Order List ──
  Widget _buildPreOrderList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: _preOrders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (_, i) => _buildPreOrderCard(_preOrders[i]),
    );
  }

  Widget _buildPreOrderCard(_PreOrderData data) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image section
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                child: CachedNetworkImage(
                  imageUrl: data.imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(height: 200, color: Colors.grey[200]),
                  errorWidget: (_, __, ___) => Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.image,
                      size: 40,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              // Days left badge
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${data.daysLeft}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: primary,
                        ),
                      ),
                      Text(
                        'DAYS LEFT',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[500],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Price and discount badge
              Positioned(
                bottom: 14,
                left: 14,
                child: Row(
                  children: [
                    Text(
                      data.price,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        data.discount,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.storefront, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(
                      data.farm,
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Progress bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      data.isAlmostGone
                          ? '${data.reserved}% Reserved · Almost Gone'
                          : '${data.reserved}% Reserved',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: data.isAlmostGone
                            ? Colors.red[600]
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Target: ${data.target}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: data.reserved / 100,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      data.isAlmostGone ? Colors.red[500]! : primary,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // Reserve button + heart
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            'Reserve Now',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        data.isAlmostGone
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 22,
                        color: data.isAlmostGone
                            ? Colors.red[400]
                            : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreOrderData {
  final String imageUrl;
  final int daysLeft;
  final String price;
  final String discount;
  final String name;
  final String farm;
  final int reserved;
  final String target;
  final bool isAlmostGone;

  const _PreOrderData({
    required this.imageUrl,
    required this.daysLeft,
    required this.price,
    required this.discount,
    required this.name,
    required this.farm,
    required this.reserved,
    required this.target,
    required this.isAlmostGone,
  });
}
