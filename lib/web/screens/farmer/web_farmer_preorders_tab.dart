import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/services/commerce/product_service.dart';
import '../../../shared/widgets/app_shimmer_loader.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../widgets/web_hamburger_menu_button.dart';
import '../../widgets/web_consumer_nav_bar.dart';
import '../../widgets/crop_milestones_timeline.dart';
import '../../../shared/models/product/crop_milestone_model.dart';
import '../../../shared/data/app_data.dart';

class WebFarmerPreordersTab extends StatefulWidget {
  final Function(int) onNavigate;
  final int currentIndex;

  const WebFarmerPreordersTab({
    super.key,
    required this.onNavigate,
    required this.currentIndex,
  });

  @override
  State<WebFarmerPreordersTab> createState() => _WebFarmerPreordersTabState();
}

class _WebFarmerPreordersTabState extends State<WebFarmerPreordersTab> {
  // Premium Design Tokens
  static const Color _primary = Color(0xFF10B981); // Emerald
  
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  final _supabase = Supabase.instance.client;
  final _productService = ProductService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _preorders = [];
  double _totalProjectedRevenue = 0.0;
  double _totalReservations = 0.0;
  int _hoveredNav = -1;
  final Set<String> _expandedProductIds = {};

  @override
  void initState() {
    super.initState();
    _loadPreorders();
  }

  Future<void> _loadPreorders() async {
    setState(() => _isLoading = true);
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      // Resolve user_id to farmer_id first
      final farmerResponse = await _supabase
          .from('farmers')
          .select('farmer_id')
          .eq('user_id', currentUserId)
          .maybeSingle();

      if (farmerResponse == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No farmer profile found for user: $currentUserId')),
          );
          setState(() {
            _preorders = [];
            _totalProjectedRevenue = 0.0;
            _totalReservations = 0.0;
            _isLoading = false;
          });
        }
        return;
      }

      final farmerId = farmerResponse['farmer_id'] as String;

      final productsResponse = await _supabase
          .from('products')
          .select('*, categories(name), units(name)')
          .eq('farmer_id', farmerId)
          .eq('is_preorder', true);

      final products = List<Map<String, dynamic>>.from(productsResponse as List);

      double revenue = 0.0;
      double totalRes = 0.0;

      // For each pre-order, fetch total reserved quantity from order items
      for (var product in products) {
        final productId = product['product_id'];
        
        // Sum quantities of confirmed/pending orders
        final itemsResponse = await _supabase
            .from('order_items')
            .select('quantity, orders!inner(order_statuses!inner(code))')
            .eq('product_id', productId)
            .inFilter('orders.order_statuses.code', ['pending', 'confirmed', 'PENDING', 'CONFIRMED']);
            
        final items = List<Map<String, dynamic>>.from(itemsResponse as List);
        double reserved = items.fold<double>(0.0, (sum, item) => sum + ((item['quantity'] as num?)?.toDouble() ?? 0.0));
        
        product['reserved_quantity'] = reserved;
        
        // Fetch crop milestones
        try {
          final milestones = await _productService.getCropMilestones(productId);
          product['milestones'] = milestones;
        } catch (_) {
          product['milestones'] = <CropMilestone>[];
        }
        
        final price = (product['price'] as num?)?.toDouble() ?? 0.0;
        revenue += reserved * price;
        totalRes += reserved;
      }

      if (mounted) {
        setState(() {
          _preorders = products;
          _totalProjectedRevenue = revenue;
          _totalReservations = totalRes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading farmer pre-orders: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading preorders: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showPostUpdateDialog(String productId, String cropName) async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    XFile? pickedImage;
    Uint8List? imageBytes;
    bool isPosting = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 10,
          backgroundColor: Colors.white,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.spa_rounded,
                        color: _primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Post Growth Update',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: _dark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cropName,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: isPosting ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: _muted),
                      splashRadius: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Form Fields
                Text(
                  'Milestone Title',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: titleController,
                  style: GoogleFonts.inter(fontSize: 14, color: _dark),
                  decoration: InputDecoration(
                    hintText: 'e.g., Sprouting 🌱',
                    hintStyle: GoogleFonts.inter(fontSize: 14, color: _muted.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _primary, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.title_rounded, color: _muted, size: 20),
                  ),
                ),
                const SizedBox(height: 18),

                Text(
                  'Update Description',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: descController,
                  maxLines: 4,
                  style: GoogleFonts.inter(fontSize: 14, color: _dark),
                  decoration: InputDecoration(
                    hintText: 'Tell customers about the crop growth progress...',
                    hintStyle: GoogleFonts.inter(fontSize: 14, color: _muted.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                Text(
                  'Progress Photo',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 6),
                imageBytes != null
                    ? Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _border),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(
                                imageBytes!,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      setDialogState(() {
                                        pickedImage = null;
                                        imageBytes = null;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Colors.black.withValues(alpha: 0.6),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () async {
                            final picker = ImagePicker();
                            final XFile? image = await picker.pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 1200,
                              imageQuality: 80,
                            );
                            if (image != null) {
                              final bytes = await image.readAsBytes();
                              setDialogState(() {
                                pickedImage = image;
                                imageBytes = bytes;
                              });
                            }
                          },
                          child: Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _border),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _primary.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add_a_photo_rounded,
                                    color: _primary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Click to Upload Progress Photo',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'JPEG, PNG up to 5MB',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: _muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                const SizedBox(height: 28),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: isPosting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _muted,
                        side: const BorderSide(color: _border),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: isPosting
                          ? null
                          : () async {
                              if (titleController.text.trim().isEmpty ||
                                  descController.text.trim().isEmpty) {
                                return;
                              }
                              setDialogState(() => isPosting = true);
                              try {
                                String? imageUrl;
                                if (imageBytes != null && pickedImage != null) {
                                  final fileName = '${DateTime.now().millisecondsSinceEpoch}_${pickedImage!.name}';
                                  final path = 'milestones/$fileName';
                                  final uploadResult = await SupabaseDatabase.uploadImage(
                                    bucket: 'uploads',
                                    path: path,
                                    bytes: imageBytes,
                                  );
                                  if (uploadResult != null) {
                                    imageUrl = _supabase.storage.from('uploads').getPublicUrl(path);
                                  }
                                }

                                await _productService.addCropMilestone(
                                  productId: productId,
                                  title: titleController.text.trim(),
                                  description: descController.text.trim(),
                                  imageUrl: imageUrl,
                                );
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                _loadPreorders();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Growth milestone posted successfully!')),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              } finally {
                                setDialogState(() => isPosting = false);
                              }
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_primary, Color(0xFF059669)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _primary.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          isPosting ? 'Posting...' : 'Post Update',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _markHarvestComplete(String productId, String cropName) async {
    bool confirm = await showDialog<bool>(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 10,
            backgroundColor: Colors.white,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7), // Amber 100
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFD97706), // Amber 600
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Confirm Harvest',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Are you sure the crop "$cropName" is harvested?\n\nThis will convert the pre-order listing to standard stock and notify all consumers who made reservations.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: _muted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _muted,
                            side: const BorderSide(color: _border),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context, true),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_primary, Color(0xFF059669)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: _primary.withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              'Confirm Harvest',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      // 1. Update product is_preorder to false
      await _supabase
          .from('products')
          .update({'is_preorder': false})
          .eq('product_id', productId);

      // 2. Fetch reserving customer IDs via order_items to join order_statuses correctly
      final reservationsResponse = await _supabase
          .from('order_items')
          .select('orders!inner(customer_id, order_number, order_statuses!inner(code), customers!inner(users!inner(name)))')
          .eq('product_id', productId)
          .inFilter('orders.order_statuses.code', ['pending', 'confirmed', 'PENDING', 'CONFIRMED']);

      final uniqueCustomerIds = List<Map<String, dynamic>>.from(reservationsResponse as List)
          .map((item) => item['orders']?['customer_id']?.toString())
          .whereType<String>()
          .toSet();

      // 3. Send Notification to each reserving customer
      for (final customerId in uniqueCustomerIds) {
        await _supabase.from('notifications').insert({
          'user_id': customerId,
          'title': '🍏 Crop Harvested!',
          'message': 'Your pre-ordered $cropName has been harvested and is ready for delivery/pickup!',
          'link_type': 'orders',
          'is_read': false,
        });
      }

      await _loadPreorders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$cropName" marked as harvested! Customers have been notified.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 650;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildNavBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: AppShimmerLoader())
                : SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 32,
                      vertical: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pre-Order Manager',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildAnalyticsSection(),
                        const SizedBox(height: 32),
                        _buildPreordersList(),
                      ],
                    ),
                  ),
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

    final navItems = ['Dashboard', 'Products', 'Orders', 'Community', 'Pre-Orders'];
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

  Widget _buildAnalyticsSection() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 650;

    if (isMobile) {
      return Column(
        children: [
          _analyticsCard(
            'Active Pre-orders',
            '${_preorders.length}',
            Icons.spa_rounded,
            const Color(0xFF10B981),
          ),
          const SizedBox(height: 12),
          _analyticsCard(
            'Total Reserved Qty',
            '${_totalReservations.toStringAsFixed(0)} units',
            Icons.bookmark_added_rounded,
            const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 12),
          _analyticsCard(
            'Projected Revenue',
            '₱${_totalProjectedRevenue.toStringAsFixed(2)}',
            Icons.monetization_on_rounded,
            const Color(0xFFF59E0B),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _analyticsCard(
            'Active Pre-orders',
            '${_preorders.length}',
            Icons.spa_rounded,
            const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _analyticsCard(
            'Total Reserved Qty',
            '${_totalReservations.toStringAsFixed(0)} units',
            Icons.bookmark_added_rounded,
            const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _analyticsCard(
            'Projected Revenue',
            '₱${_totalProjectedRevenue.toStringAsFixed(2)}',
            Icons.monetization_on_rounded,
            const Color(0xFFF59E0B),
          ),
        ),
      ],
    );
  }

  Widget _analyticsCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(fontSize: 22, color: const Color(0xFF1E293B), fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreordersList() {
    if (_preorders.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            const Icon(Icons.spa_outlined, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 16),
            Text(
              'No active pre-order listings',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
            ),
            const SizedBox(height: 6),
            Text(
              'Create a pre-order product inside the Products tab to see it here.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 650;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _preorders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        final product = _preorders[index];
        final reserved = product['reserved_quantity'] as double? ?? 0.0;
        final target = (product['stock_quantity'] as num?)?.toDouble() ?? 100.0;
        final percent = (reserved / (target > 0 ? target : 1.0)).clamp(0.0, 1.0);
        final unitName = product['units']?['name']?.toString() ?? 'units';
        final harvestDays = int.tryParse(product['harvest_days']?.toString() ?? '') ?? 0;
        final createdAt = product['created_at'] != null ? DateTime.parse(product['created_at'].toString()) : DateTime.now();
        final daysLeft = createdAt.add(Duration(days: harvestDays)).difference(DateTime.now()).inDays + 1;

        final productId = product['product_id']?.toString() ?? '';
        final isExpanded = _expandedProductIds.contains(productId);

        final contentWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        final productItem = ProductItem(
                          productId: product['product_id']?.toString(),
                          farmerId: product['farmer_id']?.toString(),
                          name: product['name']?.toString() ?? '',
                          price: product['price']?.toString() ?? '0',
                          unit: product['units']?['name']?.toString() ?? 'units',
                          imageUrl: product['image_url']?.toString() ?? '',
                          categoryName: product['categories']?['name']?.toString(),
                          harvestDays: product['harvest_days']?.toString(),
                          description: product['description']?.toString(),
                          reservedQuantity: reserved,
                          targetQuantity: target,
                          farm: '',
                        );
                        context.push(AppRoutes.farmerPreorderDetail, extra: productItem);
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['name']?.toString() ?? 'Crop Name',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Price: ₱${product['price']}/$unitName  •  Harvest in: ${daysLeft > 0 ? "$daysLeft days" : "Harvested"}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedProductIds.remove(productId);
                        } else {
                          _expandedProductIds.add(productId);
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: _muted,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent,
                          minHeight: 8,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF10B981),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(percent * 100).toStringAsFixed(0)}% Reserved ($reserved / $target $unitName)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF047857),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent,
                            minHeight: 8,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        '${(percent * 100).toStringAsFixed(0)}% Reserved ($reserved / $target $unitName)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
            if (isExpanded) ...[
              if (daysLeft <= 5 && daysLeft >= 0 && target > 0 && (reserved / target) < 0.5) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red[50]!,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red[100]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Under-reserved Alert: Only ${(percent * 100).toStringAsFixed(0)}% reserved with $daysLeft days remaining!',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.red[900]!,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (product['milestones'] != null && (product['milestones'] as List).isNotEmpty) ...[
                const SizedBox(height: 24),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),
                CropMilestonesTimeline(
                  milestones: List<CropMilestone>.from(product['milestones'] as List),
                ),
              ],
            ],
          ],
        );

        final actionButtons = [
          OutlinedButton.icon(
            onPressed: () => _showPostUpdateDialog(
              product['product_id'],
              product['name'],
            ),
            icon: const Icon(Icons.add_a_photo_rounded, size: 16),
            label: const Text('Post Update'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF10B981),
              side: const BorderSide(color: Color(0xFF10B981)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () => _markHarvestComplete(
              product['product_id'],
              product['name'],
            ),
            icon: const Icon(Icons.check_circle_rounded, size: 16),
            label: const Text('Mark Harvested'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ];

        if (isMobile) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                contentWidget,
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actionButtons.map((w) {
                    if (w is OutlinedButton || w is FilledButton) {
                      return Expanded(child: w);
                    }
                    return w;
                  }).toList(),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: contentWidget,
              ),
              const SizedBox(width: 24),
              Row(
                children: actionButtons,
              ),
            ],
          ),
        );
      },
    );
  }
}
