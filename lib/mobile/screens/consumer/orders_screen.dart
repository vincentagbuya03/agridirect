import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Orders Screen showing order history with tabs.
/// Active, Completed, and Cancelled orders.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const Color primary = Color(0xFF13EC5B);
  int _selectedTab = 0;

  final _tabs = ['Active', 'Completed', 'Cancelled'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildTabBar(),
            Expanded(child: _buildOrdersList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Icon(Icons.receipt_long_rounded, color: primary, size: 26),
          const SizedBox(width: 8),
          Text(
            'Order History',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const Spacer(),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.notifications_outlined,
              size: 20,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        height: 48,
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
                'Search your orders...',
                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(_tabs.length, (i) {
              final isSelected = _selectedTab == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTab = i),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _tabs[i],
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? primary : Colors.grey[400],
                          ),
                        ),
                      ),
                      if (isSelected)
                        Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        )
                      else
                        const SizedBox(height: 3),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    if (_selectedTab == 0) {
      // Active orders
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          _buildOrderCard(
            farmImage:
                'https://images.unsplash.com/photo-1464965911861-746a04b4bca6?w=400',
            farmName: 'Green Valley Organic',
            orderId: 'AD-82910',
            itemCount: 3,
            price: '\$34.50',
            status: 'Out for Delivery',
            statusColor: primary,
            estimatedTime: '2:45 PM',
            progress: 0.75,
          ),
          const SizedBox(height: 16),
          _buildOrderCard(
            farmImage:
                'https://images.unsplash.com/photo-1568702846914-96b305d2aaeb?w=400',
            farmName: 'Blue Ridge Valley',
            orderId: 'AD-82855',
            itemCount: 1,
            price: '\$12.20',
            status: 'Preparing',
            statusColor: const Color(0xFFFF9500),
            estimatedTime: 'FARMER IS PACKING',
            progress: 0.45,
          ),
        ],
      );
    } else if (_selectedTab == 1) {
      // Completed orders
      return Center(
        child: Text(
          'No completed orders',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    } else {
      // Cancelled orders
      return Center(
        child: Text(
          'No cancelled orders',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }
  }

  Widget _buildOrderCard({
    required String farmImage,
    required String farmName,
    required String orderId,
    required int itemCount,
    required String price,
    required String status,
    required Color statusColor,
    required String estimatedTime,
    required double progress,
  }) {
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
          // Top row with image, farm name, and price
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: farmImage,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(width: 80, height: 80, color: Colors.grey[200]),
                  errorWidget: (_, __, ___) => Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      farmName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Order #$orderId · $itemCount items',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Text(
                price,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Status badge
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                status,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
              const Spacer(),
              Text(
                estimatedTime,
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 14),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      'Track Order',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      'Help',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Recently ordered section (only for first order)
          if (farmName == 'Green Valley Organic')
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'RECENTLY ORDERED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[400],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'S',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Summer Strawberries',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            "John's Organic Acres",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Order Again',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}
