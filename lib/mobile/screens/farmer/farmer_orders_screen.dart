import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

/// Farmer Orders Screen
class FarmerOrdersScreen extends StatefulWidget {
  const FarmerOrdersScreen({super.key});

  @override
  State<FarmerOrdersScreen> createState() => _FarmerOrdersScreenState();
}

class _FarmerOrdersScreenState extends State<FarmerOrdersScreen> {
  static const Color primary = Color(0xFF13EC5B);
  int _selectedTab = 0;
  final _tabs = ['Active', 'Completed', 'Refunds'];

  final List<Map<String, dynamic>> activeOrders = [
    {
      'customerName': 'Sarah Johnson',
      'customerImage': 'https://i.pravatar.cc/150?img=1',
      'orderId': 'AD-8842',
      'timeAgo': '10m ago',
      'items': '5.0kg Organic Roma Tomatoes',
      'total': '\$24.50',
      'status': 'PENDING HARVEST',
      'statusColor': const Color(0xFFFFA500),
    },
    {
      'customerName': 'Michael Chen',
      'customerImage': 'https://i.pravatar.cc/150?img=2',
      'orderId': 'AD-8845',
      'timeAgo': '24m ago',
      'items': '2x Fresh Sourdough Loaf, 1L Milk',
      'total': '\$18.20',
      'status': 'READY FOR PICKUP',
      'statusColor': const Color(0xFF3B82F6),
    },
    {
      'customerName': 'Emma Wilson',
      'customerImage': 'https://i.pravatar.cc/150?img=3',
      'orderId': 'AD-8839',
      'timeAgo': '1h ago',
      'items': '12x Large Brown Eggs',
      'total': '\$8.00',
      'status': 'PROCESSING',
      'statusColor': const Color(0xFF9333EA),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          Text(
            'Orders',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.search_rounded,
              color: Colors.grey[600],
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.tune_rounded, color: Colors.grey[600], size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
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
    );
  }

  Widget _buildOrdersList() {
    if (_selectedTab == 0) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          // Today's total card
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'TODAY\'S TOTAL',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.bar_chart_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '28 Orders',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFA500),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '12 Pending',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '16 In Progress',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Active orders header
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Text(
                  'ACTIVE ORDERS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  'Sort by: Earliest',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          // Order cards
          ...activeOrders.map((order) => _buildOrderCard(order)),
        ],
      );
    }

    return Center(
      child: Text(
        'No orders in this category',
        style: TextStyle(color: Colors.grey[500]),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          // Customer info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipOval(
                child: CachedNetworkImage(
                  imageUrl: order['customerImage'],
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(width: 48, height: 48, color: Colors.grey[200]),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order['customerName'],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'Order #${order['orderId']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '· ${order['timeAgo']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: order['statusColor'].withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order['status'],
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: order['statusColor'],
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.grey[200]),
          const SizedBox(height: 12),
          // Items
          Text(
            'Items',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            order['items'],
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                order['total'],
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Update status button
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      'Update Status',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
