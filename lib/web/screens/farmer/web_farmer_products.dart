import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../widgets/animated_components.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/router/app_routes.dart';

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

  @override
  Widget build(BuildContext context) {
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
          Column(
            children: [
              _buildNavBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
                  child: FadeTransition(
                    opacity: _fadeInController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 32),
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
    final navItems = ['Dashboard', 'Products', 'Orders', 'Community'];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => widget.onNavigate(0),
              child: const BrandLogo(size: BrandLogoSize.medium),
            ),
          ),
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
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isActive
                          ? _primary.withValues(alpha: 0.1)
                          : isHovered
                              ? _border.withValues(alpha: 0.5)
                              : Colors.transparent,
                    ),
                    child: Text(
                      navItems[i],
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        color: isActive ? _primary : isHovered ? _dark : _muted,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => widget.onNavigate(4),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                  border: Border.all(color: _primary, width: 1.5),
                ),
                child: const Icon(Icons.person_rounded, color: _primary, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Product Management',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your inventory, prices, and listings.',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: _muted,
              ),
            ),
          ],
        ),
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
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 0.82,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) => _buildProductCard(products[index]),
        );
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final name = product['name'] ?? 'Product';
    final price = '₱${product['price'] ?? 0}';
    final stock = product['available_quantity'] ?? 0;
    final imageUrl = product['image_url'];
    final unit = product['unit'] ?? 'kg';

    return HoverScaleCard(
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
                      child: imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(color: _surface),
                              errorWidget: (context, url, error) => Container(color: _surface, child: const Icon(Icons.image_not_supported_outlined)),
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
