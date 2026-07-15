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
import '../../widgets/web_consumer_nav_bar.dart';
import '../../widgets/crop_milestones_timeline.dart';
import '../../../shared/models/product/crop_milestone_model.dart';
import '../../../shared/data/app_data.dart';

class WebFarmerPreorderDetails extends StatefulWidget {
  final ProductItem product;

  const WebFarmerPreorderDetails({
    super.key,
    required this.product,
  });

  @override
  State<WebFarmerPreorderDetails> createState() => _WebFarmerPreorderDetailsState();
}

class _WebFarmerPreorderDetailsState extends State<WebFarmerPreorderDetails> {
  static const Color _primary = Color(0xFF10B981);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  final _supabase = Supabase.instance.client;
  final _productService = ProductService();

  bool _isLoading = true;
  List<CropMilestone> _milestones = [];
  List<Map<String, dynamic>> _reservations = [];
  double _reservedQuantity = 0.0;
  double _projectedRevenue = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      final productId = widget.product.productId;
      if (productId == null) return;

      // 1. Fetch Crop Milestones
      final milestones = await _productService.getCropMilestones(productId);

      // 2. Fetch Reservations
      final itemsResponse = await _supabase
          .from('order_items')
          .select('quantity, created_at, orders!inner(order_number, payment_method, created_at, order_statuses!inner(code), customers!inner(users!inner(name)))')
          .eq('product_id', productId)
          .inFilter('orders.order_statuses.code', ['pending', 'confirmed', 'PENDING', 'CONFIRMED']);

      final items = List<Map<String, dynamic>>.from(itemsResponse as List);
      
      double totalReserved = 0.0;
      List<Map<String, dynamic>> tempReservations = [];

      for (var item in items) {
        final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
        totalReserved += qty;

        final order = item['orders'] as Map<String, dynamic>?;
        final customer = order?['customers'] as Map<String, dynamic>?;
        final user = customer?['users'] as Map<String, dynamic>?;

        tempReservations.add({
          'customer_name': user?['name']?.toString() ?? 'Anonymous Customer',
          'order_number': order?['order_number']?.toString() ?? 'N/A',
          'quantity': qty,
          'date': order?['created_at'] != null ? DateTime.parse(order!['created_at'].toString()) : DateTime.now(),
          'payment_method': order?['payment_method']?.toString() ?? 'COD',
          'status': order?['order_statuses']?['code']?.toString() ?? 'pending',
        });
      }

      final priceVal = double.tryParse(widget.product.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;

      setState(() {
        _milestones = milestones;
        _reservations = tempReservations;
        _reservedQuantity = totalReserved;
        _projectedRevenue = totalReserved * priceVal;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading preorder details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading preorder details: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showPostUpdateDialog() async {
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
                            widget.product.name,
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
                                  productId: widget.product.productId!,
                                  title: titleController.text.trim(),
                                  description: descController.text.trim(),
                                  imageUrl: imageUrl,
                                );
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                _loadDetails();
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

  Future<void> _markHarvestComplete() async {
    final cropName = widget.product.name;
    final productId = widget.product.productId!;

    bool confirm = await showDialog<bool>(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 10,
            backgroundColor: Colors.white,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFD97706),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Confirm Harvest Complete',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _dark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Are you sure you want to mark "$cropName" as harvested?\n\nThis will convert the pre-order product into a standard shop product, and immediately notify all reserving customers that their batch is ready.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: _muted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
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
                        onTap: () => Navigator.pop(context, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD97706).withValues(alpha: 0.25),
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

      // 2. Fetch reserving customer IDs
      final reservationsResponse = await _supabase
          .from('order_items')
          .select('orders!inner(customer_id, order_number, order_statuses!inner(code))')
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$cropName" marked as harvested! Customers have been notified.')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      _loadDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: AppShimmerLoader()),
      );
    }

    final targetVal = widget.product.targetQuantity ?? 100.0;
    final percent = (_reservedQuantity / (targetVal > 0 ? targetVal : 1.0)).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _dark),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Pre-order Details',
          style: GoogleFonts.plusJakartaSans(
            color: _dark,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.product.imageUrl.isNotEmpty) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  widget.product.imageUrl,
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, o, s) => Container(
                                    width: 90,
                                    height: 90,
                                    color: _border,
                                    child: const Icon(Icons.broken_image, color: _muted),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 24),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      widget.product.categoryName ?? 'Produce',
                                      style: GoogleFonts.inter(
                                        color: _primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    widget.product.name,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: _dark,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Price: ${widget.product.price}/${widget.product.unit}  •  Harvest Period: ${widget.product.harvestDays} days',
                                    style: GoogleFonts.inter(
                                      color: _muted,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _showPostUpdateDialog,
                                  icon: const Icon(Icons.add_a_photo_rounded, size: 16),
                                  label: const Text('Post Update'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _primary,
                                    side: const BorderSide(color: _primary),
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                FilledButton.icon(
                                  onPressed: _markHarvestComplete,
                                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                                  label: const Text('Mark Harvested'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Divider(color: _border),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricTile(
                                title: 'Total Reserved',
                                value: '$_reservedQuantity / ${targetVal.toStringAsFixed(0)} ${widget.product.unit}',
                                icon: Icons.shopping_bag_outlined,
                                color: _primary,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _buildMetricTile(
                                title: 'Projected Revenue',
                                value: '₱${_projectedRevenue.toStringAsFixed(2)}',
                                icon: Icons.monetization_on_outlined,
                                color: const Color(0xFF3B82F6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percent,
                                minHeight: 10,
                                backgroundColor: const Color(0xFFE2E8F0),
                                valueColor: const AlwaysStoppedAnimation<Color>(_primary),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${(percent * 100).toStringAsFixed(0)}% of crop batch reserved',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF047857),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Active Reservations Table (Left)
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active Reservations',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: _dark,
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (_reservations.isEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.all(32),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'No reservations yet for this preorder listing.',
                                    style: GoogleFonts.inter(color: _muted),
                                  ),
                                ),
                              ] else ...[
                                Table(
                                  columnWidths: const {
                                    0: FlexColumnWidth(2),
                                    1: FlexColumnWidth(2),
                                    2: FlexColumnWidth(1.5),
                                    3: FlexColumnWidth(1.5),
                                    4: FlexColumnWidth(1.5),
                                  },
                                  children: [
                                    TableRow(
                                      decoration: const BoxDecoration(
                                        border: Border(bottom: BorderSide(color: _border, width: 1.5)),
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          child: Text('Customer', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _muted, fontSize: 13)),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          child: Text('Order No.', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _muted, fontSize: 13)),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          child: Text('Quantity', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _muted, fontSize: 13)),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          child: Text('Payment', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _muted, fontSize: 13)),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          child: Text('Status', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _muted, fontSize: 13)),
                                        ),
                                      ],
                                    ),
                                    ..._reservations.map((res) {
                                      return TableRow(
                                        decoration: const BoxDecoration(
                                          border: Border(bottom: BorderSide(color: _border)),
                                        ),
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            child: Text(res['customer_name'], style: GoogleFonts.inter(color: _dark, fontWeight: FontWeight.w600, fontSize: 13.5)),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            child: Text(res['order_number'], style: GoogleFonts.inter(color: _muted, fontSize: 13.5)),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            child: Text('${res['quantity']} ${widget.product.unit}', style: GoogleFonts.inter(color: _dark, fontWeight: FontWeight.w600, fontSize: 13.5)),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            child: Text(res['payment_method'], style: GoogleFonts.inter(color: _dark, fontSize: 13.5)),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEFF6FF),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                res['status'].toString().toUpperCase(),
                                                style: GoogleFonts.inter(color: const Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 11),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 32),
                      // Crop Milestones Timeline (Right)
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CropMilestonesTimeline(milestones: _milestones),
                            ],
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
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
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
                style: GoogleFonts.inter(fontSize: 13, color: _muted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(fontSize: 20, color: _dark, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
