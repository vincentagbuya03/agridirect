import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/data/app_data.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/widgets/image_widgets.dart';
import '../../widgets/web_consumer_nav_bar.dart';

class WebOrderSuccessScreen extends StatefulWidget {
  const WebOrderSuccessScreen({
    super.key,
    required this.categoryName,
  });

  final String? categoryName;

  @override
  State<WebOrderSuccessScreen> createState() => _WebOrderSuccessScreenState();
}

class _WebOrderSuccessScreenState extends State<WebOrderSuccessScreen> {
  static const Color _primary = Color(0xFF16A34A);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);
  static const Color _white = Colors.white;

  List<ProductItem> _relatedProducts = const [];
  bool _isLoadingProducts = true;

  @override
  void initState() {
    super.initState();
    _loadRelatedProducts();
  }

  Future<void> _loadRelatedProducts() async {
    final cat = widget.categoryName;
    if (cat == null || cat.trim().isEmpty) {
      if (mounted) setState(() => _isLoadingProducts = false);
      return;
    }
    try {
      final products = await SupabaseDataService().getProductsByCategory(cat);
      if (mounted) {
        setState(() {
          _relatedProducts = products.take(4).toList();
          _isLoadingProducts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  void _handleNav(int index) {
    context.go(AppRoutes.webTabRoute(index));
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isCompact = sw < 900;

    return Scaffold(
      backgroundColor: _surface,
      body: Column(
        children: [
          WebConsumerNavBar(
            currentIndex: -1,
            onNavigate: _handleNav,
            onCartTap: () => context.go(AppRoutes.cart),
            margin: EdgeInsets.fromLTRB(
              isCompact ? 16 : 32,
              20,
              isCompact ? 16 : 32,
              12,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isCompact ? 16 : 32,
                16,
                isCompact ? 16 : 32,
                48,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      _buildSuccessCard(isCompact),
                      const SizedBox(height: 48),
                      _buildRecommendationsSection(isCompact),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessCard(bool isCompact) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            builder: (context, opacity, child) {
              return Opacity(
                opacity: opacity,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isCompact ? 24 : 40),
                  decoration: BoxDecoration(
                    color: _white,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(
                        color: _dark.withValues(alpha: 0.03),
                        blurRadius: 40,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated Checkmark Icon
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.elasticOut,
                        builder: (context, val, child) {
                          return Transform.scale(
                            scale: val,
                            child: Container(
                              width: isCompact ? 80 : 96,
                              height: isCompact ? 80 : 96,
                              decoration: const BoxDecoration(
                                color: Color(0xFFDCFCE7),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_circle_rounded,
                                color: _primary,
                                size: isCompact ? 48 : 56,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Order Placed Successfully!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isCompact ? 24 : 32,
                          fontWeight: FontWeight.w800,
                          color: _dark,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Thank you for your purchase! The farmer has been notified and will prepare your order shortly.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: isCompact ? 14 : 15,
                          color: _muted,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 36),
                      // Buttons
                      isCompact
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildHomeButton(),
                                const SizedBox(height: 12),
                                _buildOrdersButton(),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildHomeButton(width: 200),
                                const SizedBox(width: 16),
                                _buildOrdersButton(width: 200),
                              ],
                            ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHomeButton({double? width}) {
    return SizedBox(
      width: width,
      height: 52,
      child: FilledButton.icon(
        onPressed: () => context.go(AppRoutes.marketplace),
        icon: const Icon(Icons.home_rounded, size: 20),
        label: const Text('Go to Home'),
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildOrdersButton({double? width}) {
    return SizedBox(
      width: width,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () => context.go(AppRoutes.customerOrders),
        icon: const Icon(Icons.receipt_long_rounded, size: 20),
        label: const Text('View Orders'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _dark,
          side: const BorderSide(color: _border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildRecommendationsSection(bool isCompact) {
    if (_isLoadingProducts) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }

    if (_relatedProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    final sw = MediaQuery.of(context).size.width;
    final int crossCount = sw < 600 ? 2 : (sw < 900 ? 2 : 4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_mall_outlined, color: _primary),
            const SizedBox(width: 8),
            Text(
              widget.categoryName != null
                  ? 'More ${widget.categoryName} Products'
                  : 'You Might Also Like',
              style: GoogleFonts.plusJakartaSans(
                fontSize: isCompact ? 18 : 22,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: isCompact ? 12 : 20,
            mainAxisSpacing: isCompact ? 12 : 20,
            childAspectRatio: isCompact ? 0.72 : 0.8,
          ),
          itemCount: _relatedProducts.length.clamp(0, crossCount),
          itemBuilder: (context, index) {
            final item = _relatedProducts[index];
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  final isPreOrder = item.harvestDays != null && item.harvestDays!.trim().isNotEmpty;
                  final targetRoute = isPreOrder ? AppRoutes.preorderDetails : AppRoutes.productDetails;
                  context.go(targetRoute, extra: item);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: _white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(
                        color: _dark.withValues(alpha: 0.01),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Area - Proportional smaller height
                      AspectRatio(
                        aspectRatio: 1.4,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(22),
                          ),
                          child: item.imageUrl.isNotEmpty
                              ? SafeNetworkImage(
                                  imageUrl: item.imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: Container(color: _surface),
                                  errorWidget: Container(color: _surface),
                                )
                              : Container(color: _surface),
                        ),
                      ),
                      // Details
                      Padding(
                        padding: EdgeInsets.all(isCompact ? 10 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: isCompact ? 13 : 16,
                                fontWeight: FontWeight.w700,
                                color: _dark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.farm,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: isCompact ? 10 : 12,
                                color: _muted,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.price,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: isCompact ? 14 : 18,
                                    fontWeight: FontWeight.w800,
                                    color: _primary,
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isCompact ? 6 : 8,
                                    vertical: isCompact ? 2 : 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _surface,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: _border),
                                  ),
                                  child: Text(
                                    item.unit,
                                    style: GoogleFonts.inter(
                                      fontSize: isCompact ? 9 : 10,
                                      fontWeight: FontWeight.w600,
                                      color: _muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
