import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/services/commerce/cart_service.dart';
import '../../../shared/data/app_data.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/app_shimmer_loader.dart';

class WholesaleScreen extends StatefulWidget {
  const WholesaleScreen({super.key});

  @override
  State<WholesaleScreen> createState() => _WholesaleScreenState();
}

class _WholesaleScreenState extends State<WholesaleScreen> {
  late Future<List<ProductItem>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = SupabaseDataService().getWholesaleProducts();
  }

  void _addToCart(ProductItem product, int minOrderQty) async {
    // Add the minimum wholesale quantity to the cart
    final result = await CartService().addItem(product, minOrderQty);
    if (!mounted) return;
    
    if (result != null && result.contains('stock')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result),
        backgroundColor: Colors.red[600],
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Added $minOrderQty units of ${product.name} to Cart!'),
        backgroundColor: const Color(0xFF1D4ED8),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: () => context.push('/cart'),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Very light gray-blue
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D4ED8), // Deep blue
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              'Wholesale Hub',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
            onPressed: () => context.push('/cart'),
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _buildWholesaleBanner(),
          ),
          _buildProductList(),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildWholesaleBanner() {
    return Container(
      width: double.infinity,
      height: 120,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(Icons.widgets_rounded, size: 100, color: Colors.white.withValues(alpha: 0.1)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Bulk Buying Savings',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    shadows: [const Shadow(color: Colors.black26, offset: Offset(1, 1))],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Up to 30% OFF for large orders',
                  style: GoogleFonts.inter(color: Colors.blue[100], fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    return FutureBuilder<List<ProductItem>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: AppShimmerLoader(height: 160),
              ),
              childCount: 4,
            ),
          );
        }

        final products = snapshot.data ?? [];
        if (products.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text('No wholesale products available.', style: GoogleFonts.inter(color: Colors.grey)),
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildWholesaleCard(products[index]),
            childCount: products.length,
          ),
        );
      },
    );
  }

  Widget _buildWholesaleCard(ProductItem product) {
    // Generate stable mock tiers
    final seed = product.productId.hashCode;
    final double basePrice = double.tryParse(product.price) ?? 100;
    
    // Tier 1: 10-49 units (5% off)
    final double t1Price = basePrice * 0.95;
    // Tier 2: 50-99 units (15% off)
    final double t2Price = basePrice * 0.85;
    // Tier 3: 100+ units (25% off)
    final double t3Price = basePrice * 0.75;
    
    // Simulate stock
    final int availableStock = 200 + (seed % 800);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Header section with Image and Basic Info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrls.isNotEmpty ? product.imageUrls.first : product.imageUrl,
                    height: 80,
                    width: 80,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'WHOLESALE',
                          style: GoogleFonts.inter(color: const Color(0xFF1D4ED8), fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.name,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'By: ${product.farm}',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Stock: $availableStock ${product.unit}',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF10B981), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          
          // Wholesale Pricing Tiers
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTierColumn('10-49 ${product.unit}', t1Price),
                Container(width: 1, height: 30, color: const Color(0xFFE2E8F0)),
                _buildTierColumn('50-99 ${product.unit}', t2Price),
                Container(width: 1, height: 30, color: const Color(0xFFE2E8F0)),
                _buildTierColumn('100+ ${product.unit}', t3Price, isBest: true),
              ],
            ),
          ),
          
          // Action Bottom Bar
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Min. Order: 10 ${product.unit}',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                ElevatedButton.icon(
                  onPressed: () => _addToCart(product, 10),
                  icon: const Icon(Icons.add_shopping_cart, size: 16, color: Colors.white),
                  label: Text('BULK BUY', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierColumn(String range, double price, {bool isBest = false}) {
    return Column(
      children: [
        if (isBest) 
          Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(2)),
            child: Text('BEST', style: GoogleFonts.inter(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        Text(
          range,
          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 2),
        Text(
          'â‚±${price.toStringAsFixed(0)}',
          style: GoogleFonts.poppins(
            fontSize: isBest ? 16 : 14, 
            fontWeight: FontWeight.bold, 
            color: isBest ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}