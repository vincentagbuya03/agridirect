import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/data/app_data.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/widgets/image_widgets.dart';
import '../../widgets/web_consumer_nav_bar.dart';

class WebPreOrderHub extends StatefulWidget {
  const WebPreOrderHub({
    super.key,
    required this.onNavigate,
    required this.currentIndex,
  });

  final Function(int) onNavigate;
  final int currentIndex;

  @override
  State<WebPreOrderHub> createState() => _WebPreOrderHubState();
}

class _WebPreOrderHubState extends State<WebPreOrderHub> {
  static const Color _primary = Color(0xFF16A34A);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);
  static const Color _white = Colors.white;

  List<ProductItem> _products = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await SupabaseDataService().getPreOrderProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 20, 32, 12),
            child: WebConsumerNavBar(
              currentIndex: widget.currentIndex,
              onNavigate: widget.onNavigate,
              onCartTap: () => context.go(AppRoutes.cart),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pre-Orders',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reserve upcoming harvests before they are available in the regular shop.',
                    style: GoogleFonts.inter(fontSize: 14, color: _muted),
                  ),
                  const SizedBox(height: 28),
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 80),
                        child: CircularProgressIndicator(color: _primary),
                      ),
                    )
                  else if (_products.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: _white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _border),
                      ),
                      child: Text(
                        'No pre-orders available right now.',
                        style: GoogleFonts.inter(fontSize: 14, color: _muted),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      children: _products.map(_buildCard).toList(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(ProductItem product) {
    final totalDays = int.tryParse(product.harvestDays ?? '') ?? 0;
    final remainingDays = product.createdAt == null
        ? totalDays
        : product.createdAt!.add(Duration(days: totalDays)).difference(DateTime.now()).inDays + 1;
    final harvestLabel = remainingDays > 0
        ? 'Harvest in $remainingDays days'
        : (remainingDays == 0 ? 'Harvesting today' : 'Harvested');

    return SizedBox(
      width: 280,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => context.push(AppRoutes.preorderDetails, extra: product),
          child: Container(
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  child: AspectRatio(
                    aspectRatio: 1.15,
                    child: SafeNetworkImage(
                      imageUrl: product.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: Container(color: Colors.grey[100]),
                      errorWidget: Container(color: Colors.grey[100]),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          harvestLabel,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _dark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        product.farm,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 13, color: _muted),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        product.price,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
