import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../widgets/animated_components.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/widgets/image_widgets.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../widgets/web_consumer_nav_bar.dart';

class WebFarmerProducts extends StatefulWidget {
  final Function(int) onNavigate;
  final int currentIndex;

  const WebFarmerProducts({
    super.key,
    required this.onNavigate,
    required this.currentIndex,
  });

  @override
  State<WebFarmerProducts> createState() => _WebFarmerProductsState();
}

class _WebFarmerProductsState extends State<WebFarmerProducts> with TickerProviderStateMixin {
  late AnimationController _fadeInController;
  int _hoveredNav = -1;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const Color _primary = Color(0xFF16A34A);
  static const Color _dark = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _surface = Color(0xFFFAFAFA);

  @override
  void initState() {
    super.initState();
    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _fadeInController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  ProductItem _mapToProductItem(Map<String, dynamic> p) {
    return ProductItem(
      productId: p['productId']?.toString() ?? p['product_id']?.toString() ?? p['id']?.toString() ?? '',
      farmerId: p['farmerId']?.toString() ?? p['farmer_id']?.toString() ?? '',
      name: p['name']?.toString() ?? 'Product',
      farm: p['farmName']?.toString() ?? p['farm_name']?.toString() ?? 'AgriDirect Farm',
      price: p['price']?.toString() ?? '0',
      unit: p['unit']?.toString() ?? 'kg',
      imageUrl: p['image_url']?.toString() ?? p['imageUrl']?.toString() ?? p['image']?.toString() ?? '',
      description: p['description']?.toString(),
      rating: p['rating']?.toString() ?? '4.5',
      reviews: p['reviews']?.toString() ?? '0',
      categoryName: p['category_name']?.toString() ?? p['categoryName']?.toString(),
    );
  }

  void _openProduct(Map<String, dynamic> productMap) {
    final product = _mapToProductItem(productMap);
    context.push(
      AppRoutes.productDetails,
      extra: product,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 650;

    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        children: [
          // Background accents
          Positioned.fill(
            child: CustomPaint(
              painter: DotPatternPainter(opacity: 0.03, color: const Color(0xFF10B981)),
            ),
          ),
          const Positioned.fill(
            child: FloatingParticles(
              count: 15,
              maxSize: 2.0,
              color: Color(0xFF10B981),
            ),
          ),
          Column(
            children: [
              _buildNavBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(isMobile ? 16 : 40, 0, isMobile ? 16 : 40, 40),
                  child: FadeTransition(
                    opacity: _fadeInController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        SizedBox(height: isMobile ? 20 : 32),
                        _buildProductGrid(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 650;

    if (!AuthService().isViewingAsFarmer) {
      return WebConsumerNavBar(
        currentIndex: widget.currentIndex,
        onNavigate: widget.onNavigate,
        onCartTap: () => context.go(AppRoutes.cart),
        margin: isMobile
            ? const EdgeInsets.fromLTRB(16, 16, 16, 8)
            : const EdgeInsets.fromLTRB(32, 24, 32, 12),
      );
    }

    final navItems = ['Dashboard', 'Products', 'Orders', 'Community'];
    return Container(
      margin: isMobile
          ? const EdgeInsets.fromLTRB(16, 16, 16, 8)
          : const EdgeInsets.fromLTRB(32, 24, 32, 12),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 28,
        vertical: isMobile ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: _dark.withValues(alpha: 0.03),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => widget.onNavigate(0),
              child: BrandLogo(
                size: isMobile ? BrandLogoSize.small : BrandLogoSize.medium,
              ),
            ),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 48),
            ...List.generate(navItems.length, (i) {
              final isActive = i == widget.currentIndex;
              final isHovered = _hoveredNav == i;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _hoveredNav = i),
                  onExit: (_) => setState(() => _hoveredNav = -1),
                  child: GestureDetector(
                    onTap: () => widget.onNavigate(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: isActive
                            ? _primary.withValues(alpha: 0.1)
                            : isHovered
                            ? _border.withValues(alpha: 0.35)
                            : Colors.transparent,
                      ),
                      child: Text(
                        navItems[i],
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isActive
                              ? _primary
                              : isHovered
                              ? _dark
                              : _muted,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
          const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => widget.onNavigate(4),
              child: Container(
                width: isMobile ? 38 : 46,
                height: isMobile ? 38 : 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primary, Color(0xFF059669)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: Colors.white,
                  size: isMobile ? 20 : 24,
                ),
              ),
            ),
          ),
          if (isMobile) ...[
            const SizedBox(width: 8),
            PopupMenuButton<int>(
              icon: const Icon(Icons.menu, color: _primary),
              tooltip: '',
              onSelected: (index) {
                widget.onNavigate(index);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 0,
                  child: Row(
                    children: [
                      Icon(Icons.dashboard_rounded, color: widget.currentIndex == 0 ? _primary : _muted, size: 20),
                      const SizedBox(width: 8),
                      Text('Dashboard', style: GoogleFonts.inter(fontWeight: widget.currentIndex == 0 ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 1,
                  child: Row(
                    children: [
                      Icon(Icons.agriculture_rounded, color: widget.currentIndex == 1 ? _primary : _muted, size: 20),
                      const SizedBox(width: 8),
                      Text('Products', style: GoogleFonts.inter(fontWeight: widget.currentIndex == 1 ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 2,
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long_rounded, color: widget.currentIndex == 2 ? _primary : _muted, size: 20),
                      const SizedBox(width: 8),
                      Text('Orders', style: GoogleFonts.inter(fontWeight: widget.currentIndex == 2 ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 3,
                  child: Row(
                    children: [
                      Icon(Icons.people_rounded, color: widget.currentIndex == 3 ? _primary : _muted, size: 20),
                      const SizedBox(width: 8),
                      Text('Community', style: GoogleFonts.inter(fontWeight: widget.currentIndex == 3 ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 4,
                  child: Row(
                    children: [
                      Icon(Icons.person_rounded, color: widget.currentIndex == 4 ? _primary : _muted, size: 20),
                      const SizedBox(width: 8),
                      Text('Profile', style: GoogleFonts.inter(fontWeight: widget.currentIndex == 4 ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 650;

    final headerText = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product Management',
          style: GoogleFonts.plusJakartaSans(
            fontSize: isMobile ? 24 : 32,
            fontWeight: FontWeight.w800,
            color: _dark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage your inventory, prices, and listings.',
          style: GoogleFonts.inter(
            fontSize: isMobile ? 14 : 16,
            color: _muted,
          ),
        ),
      ],
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          headerText,
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      hintStyle: GoogleFonts.inter(color: _muted, fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded, color: _muted, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => context.push(AppRoutes.addProduct),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  'Add',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        headerText,
        Row(
          children: [
            Container(
              width: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  hintStyle: GoogleFonts.inter(color: _muted, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: _muted, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () => context.push(AppRoutes.addProduct),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(
                'Add New Product',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductGrid() {
    final sw = MediaQuery.of(context).size.width;
    int crossAxisCount = 4;
    double childAspectRatio = 0.82;
    if (sw < 600) {
      crossAxisCount = 1;
      childAspectRatio = 1.2;
    } else if (sw < 900) {
      crossAxisCount = 2;
      childAspectRatio = 0.82;
    } else if (sw < 1200) {
      crossAxisCount = 3;
      childAspectRatio = 0.82;
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseDataService().getFarmerProducts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const GridShimmer();
        }

        final allProducts = snapshot.data ?? [];
        final products = allProducts.where((p) {
          final name = p['name']?.toString().toLowerCase() ?? '';
          return name.contains(_searchQuery.toLowerCase());
        }).toList();

        if (products.isEmpty) {
          return Center(
            child: Column(
              children: [
                const SizedBox(height: 80),
                Icon(Icons.inventory_2_outlined, size: 64, color: _muted.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text('No products found', style: GoogleFonts.inter(fontSize: 18, color: _muted)),
              ],
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) => ScrollReveal(
            delay: Duration(milliseconds: index * 60),
            duration: const Duration(milliseconds: 600),
            child: _buildProductCard(products[index]),
          ),
        );
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final name = product['name'] ?? 'Product';
    final price = '₱${product['price'] ?? 0}';
    final stock = product['available_quantity'] ?? 0;
    final imageUrl = product['image_url'] ?? product['image'];
    final unit = product['unit'] ?? 'kg';

    return GestureDetector(
      onTap: () => _openProduct(product),
      child: HoverScaleCard(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image area
              Expanded(
                flex: 5,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: imageUrl != null && imageUrl.toString().isNotEmpty
                            ? SafeNetworkImage(
                                imageUrl: imageUrl.toString(),
                                defaultBucket: 'uploads',
                                fit: BoxFit.cover,
                                placeholder: Container(color: _surface),
                                errorWidget: Container(
                                  color: _surface,
                                  child: const Icon(Icons.broken_image_rounded, color: _muted),
                                ),
                              )
                            : Container(color: _surface, child: const Icon(Icons.image_outlined, color: _muted)),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          stock > 0 ? 'In Stock' : 'Out of Stock',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _dark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Available: $stock $unit',
                        style: GoogleFonts.inter(fontSize: 12, color: _muted),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            price,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: _primary,
                            ),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.edit_note_rounded, color: _muted),
                            style: IconButton.styleFrom(
                              backgroundColor: _surface,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      ),
    );
  }
}

class GridShimmer extends StatelessWidget {
  const GridShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.8,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      itemCount: 8,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[200]!),
        ),
      ),
    );
  }
}
