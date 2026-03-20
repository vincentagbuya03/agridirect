import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/admin/admin_service.dart';

/// Admin Products Tab - Manage products, approve, suspend listings
class AdminProductsTab extends StatefulWidget {
  final AdminService adminService;

  const AdminProductsTab({
    super.key,
    required this.adminService,
  });

  @override
  State<AdminProductsTab> createState() => _AdminProductsTabState();
}

class _AdminProductsTabState extends State<AdminProductsTab> {
  late Future<List<Map<String, dynamic>>> _productsFuture;
  int _currentPage = 0;

  static const Color _primary = Color(0xFF16A34A);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _darker = Color(0xFF111827);
  static const Color _cardBg = Color(0xFF1E293B);
  static const Color _surface = Color(0xFF334155);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFF334155);

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
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      color: _darker,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Product Moderation',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _productsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _primary));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Failed to load products',
                        style: GoogleFonts.plusJakartaSans(color: _danger)),
                  );
                }

                final products = snapshot.data ?? [];

                if (products.isEmpty) {
                  return Center(
                    child: Text('No products found',
                        style: GoogleFonts.plusJakartaSans(color: _muted)),
                  );
                }

                return Column(
                  children: [
                    if (!isMobile)
                      _ProductsTable(products: products, onReload: () => setState(() => _loadProducts()))
                    else
                      Column(
                        children: [
                          for (final product in products)
                            _ProductCard(product: product, onReload: () => setState(() => _loadProducts())),
                        ],
                      ),
                    const SizedBox(height: 24),
                    // Pagination
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildPaginationBtn(
                          icon: Icons.arrow_back,
                          label: 'Previous',
                          onPressed: _currentPage > 0
                              ? () => setState(() { _currentPage--; _loadProducts(); })
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _border),
                          ),
                          child: Text('Page ${_currentPage + 1}',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)),
                        ),
                        const SizedBox(width: 16),
                        _buildPaginationBtn(
                          icon: Icons.arrow_forward,
                          label: 'Next',
                          onPressed: products.length >= 20
                              ? () => setState(() { _currentPage++; _loadProducts(); })
                              : null,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationBtn({required IconData icon, required String label, VoidCallback? onPressed}) {
    final enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? _cardBg : _surface.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: enabled ? _border : _surface),
        ),
        child: Row(
          children: [
            Icon(icon, color: enabled ? Colors.white : _muted, size: 16),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.plusJakartaSans(color: enabled ? Colors.white : _muted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _ProductsTable extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final VoidCallback onReload;

  static const Color _primary = Color(0xFF16A34A);
  static const Color _cardBg = Color(0xFF1E293B);
  static const Color _border = Color(0xFF334155);
  static const Color _muted = Color(0xFF6B7280);

  const _ProductsTable({required this.products, required this.onReload});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFF111827)),
            dataRowColor: WidgetStateProperty.all(_cardBg),
            dividerThickness: 0.5,
            columns: [
              DataColumn(label: Text('Product Name', style: GoogleFonts.plusJakartaSans(color: _muted, fontSize: 12, fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Farm', style: GoogleFonts.plusJakartaSans(color: _muted, fontSize: 12, fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Price', style: GoogleFonts.plusJakartaSans(color: _muted, fontSize: 12, fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Rating', style: GoogleFonts.plusJakartaSans(color: _muted, fontSize: 12, fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Pre-order', style: GoogleFonts.plusJakartaSans(color: _muted, fontSize: 12, fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Actions', style: GoogleFonts.plusJakartaSans(color: _muted, fontSize: 12, fontWeight: FontWeight.w600))),
            ],
            rows: [
              for (final product in products)
                DataRow(
                  cells: [
                    DataCell(Text(product['name'] ?? '-', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13))),
                    DataCell(Text(product['farm'] ?? '-', style: GoogleFonts.plusJakartaSans(color: _muted, fontSize: 13))),
                    DataCell(Text('₱${product['price'] ?? 0}',
                        style: GoogleFonts.plusJakartaSans(color: _primary, fontSize: 13, fontWeight: FontWeight.w600))),
                    DataCell(
                      Row(
                        children: [
                          Text('${product['rating'] ?? 0}', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13)),
                          const SizedBox(width: 4),
                          const Icon(Icons.star, color: Color(0xFFFFA500), size: 16),
                        ],
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (product['is_preorder'] == true ? _primary : _muted).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          product['is_preorder'] == true ? 'Yes' : 'No',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: product['is_preorder'] == true ? _primary : _muted,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          _buildActionIcon(Icons.visibility, const Color(0xFF06B6D4), () => _showProductDetails(context, product)),
                          const SizedBox(width: 4),
                          _buildActionIcon(Icons.check_circle, _primary, () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(backgroundColor: _primary,
                                  content: Text('Product approved', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF111827)))),
                            );
                            onReload();
                          }),
                          const SizedBox(width: 4),
                          _buildActionIcon(Icons.delete, const Color(0xFFEF4444), () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(backgroundColor: const Color(0xFFEF4444),
                                  content: Text('Product removed', style: GoogleFonts.plusJakartaSans(color: Colors.white))),
                            );
                            onReload();
                          }),
                        ],
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

  Widget _buildActionIcon(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  void _showProductDetails(BuildContext context, Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(product['name'] ?? 'Product',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Farm', product['farm'] ?? 'N/A'),
            _detailRow('Price', '₱${product['price'] ?? 0}'),
            _detailRow('Rating', '${product['rating'] ?? 0} ⭐'),
            _detailRow('Reviews', '${product['reviews'] ?? 0}'),
            _detailRow('Harvest Days', '${product['harvest_days'] ?? 'N/A'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.plusJakartaSans(color: _muted)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text('$label: ', style: GoogleFonts.plusJakartaSans(color: _muted, fontSize: 13)),
          Text(value, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onReload;

  static const Color _primary = Color(0xFF16A34A);
  static const Color _cardBg = Color(0xFF1E293B);
  static const Color _border = Color(0xFF334155);
  static const Color _muted = Color(0xFF6B7280);

  const _ProductCard({required this.product, required this.onReload});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product['name'] ?? '-',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(product['farm'] ?? '-',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _muted)),
                  ],
                ),
              ),
              Text('₱${product['price'] ?? 0}',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16, color: _primary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.star, color: Color(0xFFFFA500), size: 16),
              const SizedBox(width: 4),
              Text('${product['rating'] ?? 0}', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13)),
              const SizedBox(width: 16),
              if (product['is_preorder'] == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Pre-order',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: _primary)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(backgroundColor: _primary,
                          content: Text('Product approved', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF111827)))),
                    );
                    onReload();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: const Color(0xFF111827),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Approve', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(backgroundColor: const Color(0xFFEF4444),
                          content: Text('Product removed', style: GoogleFonts.plusJakartaSans(color: Colors.white))),
                    );
                    onReload();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _muted,
                    side: const BorderSide(color: Color(0xFF334155)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Remove', style: GoogleFonts.plusJakartaSans(fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
