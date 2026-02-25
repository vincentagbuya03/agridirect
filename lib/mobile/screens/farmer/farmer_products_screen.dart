import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

/// Farmer Products/Inventory Screen
class FarmerProductsScreen extends StatefulWidget {
  const FarmerProductsScreen({super.key});

  @override
  State<FarmerProductsScreen> createState() => _FarmerProductsScreenState();
}

class _FarmerProductsScreenState extends State<FarmerProductsScreen> {
  static const Color primary = Color(0xFF13EC5B);

  // Sample products
  final List<Map<String, dynamic>> products = [
    {
      'name': 'Organic Bell Peppers',
      'price': 4.50,
      'unit': 'kg',
      'available': 50,
      'harvest': 'Oct 24, 2023',
      'status': 'IN STOCK',
      'image':
          'https://images.unsplash.com/photo-1599599810694-b5ac4dd33654?w=400',
    },
    {
      'name': 'Heirloom Tomatoes',
      'price': 6.20,
      'unit': 'kg',
      'available': 0,
      'harvest': 'Oct 20, 2023',
      'status': 'SOLD OUT',
      'image':
          'https://images.unsplash.com/photo-1592841496694-747e2d5f6c9f?w=400',
    },
    {
      'name': 'Sweet Baby Carrots',
      'price': 3.75,
      'unit': 'kg',
      'available': 12,
      'harvest': 'Oct 26, 2023',
      'status': 'LOW STOCK',
      'image':
          'https://images.unsplash.com/photo-1488459716781-31db52582fe9?w=400',
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
            _buildSearchAndFilter(),
            Expanded(child: _buildProductsList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: primary,
        child: const Icon(Icons.add, color: Colors.white),
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
            'My Inventory',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, size: 18, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  'Add Product',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
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
                  const SizedBox(width: 12),
                  Icon(Icons.search, color: Colors.grey[400], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search products...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey[400]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.tune_rounded, color: primary, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    Color statusColor = const Color(0xFF13EC5B);
    if (product['status'] == 'SOLD OUT') {
      statusColor = Colors.grey;
    } else if (product['status'] == 'LOW STOCK') {
      statusColor = const Color(0xFFFFA500);
    }

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
          // Product top row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: product['image'],
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 100,
                    height: 100,
                    color: Colors.grey[200],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name'],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        product['status'],
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${product['price']} / ${product['unit']}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF13EC5B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Product details
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.shopping_bag_rounded,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${product['available']}${product['unit']} available',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Harvest: ${product['harvest']}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.edit_rounded,
                        size: 16,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Edit',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_rounded, size: 16, color: Colors.red),
                      const SizedBox(width: 6),
                      Text(
                        'Delete',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
