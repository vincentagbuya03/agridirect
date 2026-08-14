import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/data/app_data.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../shared/widgets/app_shimmer_loader.dart';

class PromoActionScreen extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;

  const PromoActionScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  State<PromoActionScreen> createState() => _PromoActionScreenState();
}

class _PromoActionScreenState extends State<PromoActionScreen> {
  late Future<List<ProductItem>> _productsFuture;

  @override
  void initState() {
    super.initState();
    // Fetch real products to populate this campaign screen
    _productsFuture = SupabaseDataService().getNearbyProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Light modern background
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: _buildVoucherStrip(),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Text(
                'Shop the Campaign',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
          ),
          _buildProductGrid(),
          const SliverToBoxAdapter(
            child: SizedBox(height: 60),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 220.0,
      floating: false,
      pinned: true,
      backgroundColor: widget.color,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16, right: 20),
        title: Text(
          widget.title,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.color,
                    widget.color.withValues(alpha: 0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              right: -30,
              bottom: -20,
              child: Icon(
                widget.icon,
                size: 150,
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoucherStrip() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      height: 90,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final isFreeShipping = index % 2 == 0;
          return _buildVoucherTicket(isFreeShipping);
        },
      ),
    );
  }

  Widget _buildVoucherTicket(bool isFreeShipping) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: widget.color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
            ),
            child: Center(
              child: Icon(
                isFreeShipping ? Icons.local_shipping : Icons.discount,
                color: widget.color,
                size: 32,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isFreeShipping ? 'Free Shipping' : '20% OFF',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Min. spend ₱200',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Collect',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: widget.color,
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

  Widget _buildProductGrid() {
    return FutureBuilder<List<ProductItem>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.7,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => const AppShimmerLoader(height: 200),
                childCount: 4,
              ),
            ),
          );
        }

        final products = snapshot.data ?? [];
        if (products.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'No products available for this campaign yet.',
                  style: GoogleFonts.inter(color: Colors.grey),
                ),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.72,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final product = products[index];
                return _buildProductCard(product);
              },
              childCount: products.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductCard(ProductItem product) {
    return GestureDetector(
      onTap: () {
        if (product.farmerId != null) {
          context.push('/product/${product.productId}');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  color: Colors.grey[100],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrls.isNotEmpty ? product.imageUrls.first : product.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) => const Icon(
                      Icons.image_not_supported,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '₱${product.price}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: widget.color,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.star, size: 12, color: Colors.amber[400]),
                        const SizedBox(width: 4),
                        Text(
                          '4.9',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: widget.color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.add_shopping_cart,
                            size: 14,
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
      ),
    );
  }
}
