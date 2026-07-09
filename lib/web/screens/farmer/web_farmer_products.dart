import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/services/commerce/product_service.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../widgets/animated_components.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/widgets/image_widgets.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../widgets/web_consumer_nav_bar.dart';
import '../../widgets/web_hamburger_menu_button.dart';

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

class _WebFarmerProductsState extends State<WebFarmerProducts>
    with TickerProviderStateMixin {
  late AnimationController _fadeInController;
  int _hoveredNav = -1;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Future<List<Map<String, dynamic>>>? _productsFuture;

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
    _productsFuture = SupabaseDataService().getFarmerProducts();
  }

  void _refreshProducts() {
    setState(() {
      _productsFuture = SupabaseDataService().getFarmerProducts();
    });
  }

  @override
  void dispose() {
    _fadeInController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openProduct(Map<String, dynamic> productMap) {
    _showEditProductDialog(productMap);
  }

  void _showEditProductDialog(Map<String, dynamic> product) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _EditProductDialog(
        product: product,
        onSaved: _refreshProducts,
      ),
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
              painter: DotPatternPainter(
                opacity: 0.03,
                color: const Color(0xFF10B981),
              ),
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
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 16 : 40,
                    0,
                    isMobile ? 16 : 40,
                    40,
                  ),
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

    final navItems = [
      'Dashboard',
      'Products',
      'Orders',
      'Community',
      'Pre-Orders',
    ];
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
              onTap: () => widget.onNavigate(5),
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
            WebHamburgerMenuButton(
              currentIndex: widget.currentIndex,
              onNavigate: widget.onNavigate,
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
          style: GoogleFonts.inter(fontSize: isMobile ? 14 : 16, color: _muted),
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
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _muted,
                        size: 20,
                      ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: _muted,
                    size: 20,
                  ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
      future: _productsFuture,
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
                Icon(
                  Icons.inventory_2_outlined,
                  size: 64,
                  color: _muted.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No products found',
                  style: GoogleFonts.inter(fontSize: 18, color: _muted),
                ),
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
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child:
                            imageUrl != null && imageUrl.toString().isNotEmpty
                            ? SafeNetworkImage(
                                imageUrl: imageUrl.toString(),
                                defaultBucket: 'uploads',
                                fit: BoxFit.cover,
                                placeholder: Container(color: _surface),
                                errorWidget: Container(
                                  color: _surface,
                                  child: const Icon(
                                    Icons.broken_image_rounded,
                                    color: _muted,
                                  ),
                                ),
                              )
                            : Container(
                                color: _surface,
                                child: const Icon(
                                  Icons.image_outlined,
                                  color: _muted,
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
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
                            onPressed: () => _openProduct(product),
                            icon: const Icon(
                              Icons.edit_note_rounded,
                              color: _muted,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: _surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
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

class _EditProductDialog extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback onSaved;

  const _EditProductDialog({required this.product, required this.onSaved});

  @override
  State<_EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<_EditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late TextEditingController _descriptionController;
  late TextEditingController _harvestDaysController;
  bool _isPreorder = false;
  bool _isLoading = false;
  bool _isLoadingDropdowns = true;

  String? _selectedCategory;
  String? _selectedUnit;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _units = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.product['name']?.toString() ?? '',
    );
    _priceController = TextEditingController(
      text: widget.product['price']?.toString() ?? '0',
    );
    _stockController = TextEditingController(
      text:
          (widget.product['available_quantity'] ??
                  widget.product['available'] ??
                  0)
              .toString()
              .replaceAll(RegExp(r'\.0$'), ''),
    );
    _descriptionController = TextEditingController(
      text: widget.product['description']?.toString() ?? '',
    );

    final harvestVal = widget.product['harvest']?.toString() ?? '';
    _harvestDaysController = TextEditingController(
      text: harvestVal.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    _isPreorder = widget.product['is_preorder'] == true;
    _loadProductDetailsAndDropdowns();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    _harvestDaysController.dispose();
    super.dispose();
  }

  Future<void> _loadProductDetailsAndDropdowns() async {
    try {
      final client = Supabase.instance.client;
      final productData = await client
          .from('products')
          .select('category_id, unit_id, harvest_days, is_preorder')
          .eq('product_id', widget.product['id'])
          .single();

      final service = ProductService();
      final cats = await service.getCategories();
      final unts = await service.getUnits();

      if (mounted) {
        setState(() {
          _selectedCategory = productData['category_id']?.toString();
          _selectedUnit = productData['unit_id']?.toString();
          _isPreorder = productData['is_preorder'] ?? false;
          if (productData['harvest_days'] != null) {
            _harvestDaysController.text = productData['harvest_days']
                .toString();
          }

          _categories = cats
              .map((c) => {'id': c.categoryId, 'name': c.name})
              .toList();
          _units = unts.map((u) => {'id': u.unitId, 'name': u.name}).toList();
          _isLoadingDropdowns = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading categories/units: $e');
      if (mounted) {
        setState(() => _isLoadingDropdowns = false);
      }
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
      final description = _descriptionController.text.trim();
      final harvestDays = int.tryParse(_harvestDaysController.text.trim()) ?? 0;
      final stock = double.tryParse(_stockController.text.trim()) ?? 0.0;

      final client = Supabase.instance.client;

      // Update basic product details
      await client
          .from('products')
          .update({
            'name': name,
            'price': price,
            'description': description,
            'harvest_days': harvestDays,
            'is_preorder': _isPreorder,
            if (_selectedCategory != null) 'category_id': _selectedCategory,
            if (_selectedUnit != null) 'unit_id': _selectedUnit,
          })
          .eq('product_id', widget.product['id']);

      await client.from('product_inventory').upsert({
        'product_id': widget.product['id'],
        'available_quantity': stock,
      }, onConflict: 'product_id');

      widget.onSaved();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product updated successfully!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update product: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete Product?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to permanently delete "${widget.product['name']}"? This action cannot be undone.',
          style: GoogleFonts.inter(),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              'Delete',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final success = await SupabaseDataService().deleteProduct(
        widget.product['id'],
      );
      if (success) {
        widget.onSaved();
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product deleted successfully!'),
              backgroundColor: Color(0xFF16A34A),
            ),
          );
        }
      } else {
        throw 'Database deletion failed';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete product: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 16,
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Product',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        Text(
                          'Edit listing details and inventory status',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF3F4F6),
                      iconSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable Content Form
            Expanded(
              child: _isLoadingDropdowns
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF16A34A),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Name
                            _buildFieldLabel('Product Name'),
                            TextFormField(
                              controller: _nameController,
                              style: GoogleFonts.inter(fontSize: 14),
                              decoration: _buildInputDecoration(
                                'e.g. Organic Tomatoes',
                              ),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty
                                  ? 'Product name is required'
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            // Row: Category & Unit
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildFieldLabel('Category'),
                                      DropdownButtonFormField<String>(
                                        initialValue: _selectedCategory,
                                        items: _categories
                                            .map(
                                              (c) => DropdownMenuItem<String>(
                                                value: c['id'],
                                                child: Text(
                                                  c['name'],
                                                  style: GoogleFonts.inter(
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (val) => setState(
                                          () => _selectedCategory = val,
                                        ),
                                        decoration: _buildInputDecoration(
                                          'Select Category',
                                        ),
                                        validator: (val) =>
                                            val == null ? 'Required' : null,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildFieldLabel('Unit'),
                                      DropdownButtonFormField<String>(
                                        initialValue: _selectedUnit,
                                        items: _units
                                            .map(
                                              (u) => DropdownMenuItem<String>(
                                                value: u['id'],
                                                child: Text(
                                                  u['name'],
                                                  style: GoogleFonts.inter(
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (val) =>
                                            setState(() => _selectedUnit = val),
                                        decoration: _buildInputDecoration(
                                          'Select Unit',
                                        ),
                                        validator: (val) =>
                                            val == null ? 'Required' : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Row: Price & Stock
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildFieldLabel('Price (₱)'),
                                      TextFormField(
                                        controller: _priceController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        style: GoogleFonts.inter(fontSize: 14),
                                        decoration: _buildInputDecoration(
                                          '0.00',
                                        ),
                                        validator: (val) {
                                          if (val == null || val.trim().isEmpty)
                                            return 'Required';
                                          if (double.tryParse(val) == null)
                                            return 'Invalid price';
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildFieldLabel('Stock Quantity'),
                                      TextFormField(
                                        controller: _stockController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        style: GoogleFonts.inter(fontSize: 14),
                                        decoration: _buildInputDecoration('0'),
                                        validator: (val) {
                                          if (val == null || val.trim().isEmpty)
                                            return 'Required';
                                          if (double.tryParse(val) == null)
                                            return 'Invalid stock';
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Preorder details
                            Row(
                              children: [
                                Checkbox(
                                  value: _isPreorder,
                                  activeColor: const Color(0xFF16A34A),
                                  onChanged: (val) => setState(
                                    () => _isPreorder = val ?? false,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'This is a pre-order product',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF374151),
                                  ),
                                ),
                              ],
                            ),
                            if (_isPreorder) ...[
                              const SizedBox(height: 12),
                              _buildFieldLabel('Days to Harvest'),
                              TextFormField(
                                controller: _harvestDaysController,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.inter(fontSize: 14),
                                decoration: _buildInputDecoration('e.g. 30'),
                                validator: (val) {
                                  if (_isPreorder &&
                                      (val == null || val.trim().isEmpty)) {
                                    return 'Harvest days required for pre-orders';
                                  }
                                  return null;
                                },
                              ),
                            ],
                            const SizedBox(height: 16),

                            // Description
                            _buildFieldLabel('Description'),
                            TextFormField(
                              controller: _descriptionController,
                              maxLines: 4,
                              style: GoogleFonts.inter(fontSize: 14),
                              decoration: _buildInputDecoration(
                                'Product description...',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            const Divider(height: 1),

            // Actions
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _deleteProduct,
                    icon: const Icon(
                      Icons.delete_forever_rounded,
                      color: Colors.red,
                      size: 18,
                    ),
                    label: Text(
                      'Delete',
                      style: GoogleFonts.inter(
                        color: Colors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isLoading ? null : _saveProduct,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Save Changes',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF374151),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF16A34A), width: 1.5),
      ),
    );
  }
}
