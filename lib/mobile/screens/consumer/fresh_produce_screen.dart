import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/data/app_data.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../shared/widgets/app_shimmer_loader.dart';

class FreshProduceScreen extends StatefulWidget {
  const FreshProduceScreen({super.key});

  @override
  State<FreshProduceScreen> createState() => _FreshProduceScreenState();
}

class _FreshProduceScreenState extends State<FreshProduceScreen> {
  late Future<List<ProductItem>> _productsFuture;
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Vegetables', 'Fruits', 'Herbs', 'Root Crops'];

  @override
  void initState() {
    super.initState();
    _productsFuture = SupabaseDataService().getNearbyProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: _buildFilterChips()),
          _buildProductGrid(),
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 155,
      pinned: true,
      backgroundColor: const Color(0xFF0D9488),
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(Icons.eco_rounded, size: 180, color: Colors.white.withValues(alpha: 0.1)),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(60, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.eco_rounded, color: Colors.white, size: 13),
                            const SizedBox(width: 5),
                            Text(
                              'FARM-TO-TABLE',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Fresh Produce',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Freshly harvested from local farms',
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.eco_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              'Fresh Produce',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ],
        ),
        centerTitle: false,
        titlePadding: const EdgeInsetsDirectional.fromSTEB(52, 0, 0, 16),
        collapseMode: CollapseMode.pin,
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 54,
      color: Colors.white,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = filter == _selectedFilter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF14B8A6)])
                    : null,
                color: isSelected ? null : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected
                    ? [BoxShadow(color: const Color(0xFF0D9488).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]
                    : null,
              ),
              child: Text(
                filter,
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductGrid() {
    return FutureBuilder<List<ProductItem>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.63,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => const AppShimmerLoader(height: 240),
                childCount: 6,
              ),
            ),
          );
        }

        final products = snapshot.data ?? [];
        if (products.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.grass_outlined, size: 60, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text('No fresh produce available.', style: GoogleFonts.inter(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.63,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildFreshProduceCard(products[index]),
              childCount: products.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFreshProduceCard(ProductItem product) {
    final bool harvestedToday = product.productId.hashCode % 2 == 0;

    return GestureDetector(
      onTap: () {
        if (product.farmerId != null) {
          context.push('/product/${product.productId}');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrls.isNotEmpty ? product.imageUrls.first : product.imageUrl,
                    height: 145,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[100],
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[100],
                      child: const Icon(Icons.image_not_supported, color: Colors.grey),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: harvestedToday
                            ? [const Color(0xFF0F766E), const Color(0xFF14B8A6)]
                            : [const Color(0xFFD97706), const Color(0xFFF59E0B)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          harvestedToday ? Icons.eco_rounded : Icons.calendar_today_rounded,
                          size: 10,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          harvestedToday ? 'Today' : '2 days ago',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.favorite_border_rounded, size: 14, color: Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.storefront_rounded, size: 11, color: Color(0xFF64748B)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            product.farm,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '₱${product.price.replaceAll(RegExp(r'[^0-9.]'), '')}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0D9488),
                                  ),
                                ),
                                TextSpan(
                                  text: '/kg',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            if (product.farmerId != null) {
                              context.push('/product/${product.productId}');
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.add_shopping_cart_rounded, size: 16, color: Colors.white),
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