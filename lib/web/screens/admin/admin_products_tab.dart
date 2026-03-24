import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/admin_service.dart';

/// Admin Products Tab - Manage platform listings (Modern White)
class AdminProductsTab extends StatefulWidget {
  final AdminService adminService;

  const AdminProductsTab({super.key, required this.adminService});

  @override
  State<AdminProductsTab> createState() => _AdminProductsTabState();
}

class _AdminProductsTabState extends State<AdminProductsTab> {
  late Future<List<Map<String, dynamic>>> _productsFuture;
  int _currentPage = 0;

  // Modern light theme colors
  static const Color _primary = Color(0xFF10B981);
  static const Color _background = Color(0xFFFAFAFA);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _muted = Color(0xFF64748B);
  static const Color _text = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() {
    _productsFuture = widget.adminService.getAllProducts(page: _currentPage);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _background,
      child: Column(
        children: [
          // Platform Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Product Moderation',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _text,
                      ),
                    ),
                    Text(
                      'Monitor and moderate marketplace product listings',
                      style: GoogleFonts.inter(fontSize: 13, color: _muted),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _loadProducts()),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _text,
                    elevation: 0,
                    side: const BorderSide(color: _border),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _productsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _primary));
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error loading products', style: GoogleFonts.inter(color: Colors.red)));
                }

                final products = snapshot.data ?? [];

                if (products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: _muted.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        Text('No active product listings found', style: GoogleFonts.inter(color: _muted, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: products.length,
                  itemBuilder: (context, index) => _ProductCard(product: products[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final status = (product['status'] ?? 'pending').toString().toUpperCase();
    final isApproved = status == 'APPROVED' || status == 'ACTIVE';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shopping_bag_rounded, color: Color(0xFF64748B)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'] ?? 'Product Listing',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF1E293B)),
                ),
                Text(
                   '₱${product['price'] ?? 0} • ${product['category_name'] ?? 'Uncategorized'}',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (isApproved ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: GoogleFonts.inter(
                color: isApproved ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
           const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF94A3B8)),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
