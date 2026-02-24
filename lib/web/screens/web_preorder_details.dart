import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../shared/data/app_data.dart';

/// Web-only Pre-order Product Details — two-column layout.
/// Completely separate UI from the mobile product details.
class WebPreorderDetails extends StatefulWidget {
  const WebPreorderDetails({super.key});

  @override
  State<WebPreorderDetails> createState() => _WebPreorderDetailsState();
}

class _WebPreorderDetailsState extends State<WebPreorderDetails> {
  static const Color _primary = Color(0xFF10B981);
  static const Color _accent = Color(0xFF13EC5B);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  bool _downpaymentEnabled = true;
  int _quantity = 10;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: Column(
        children: [
          _buildTopBar(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBreadcrumbs(),
                  const SizedBox(height: 24),
                  _buildMainContent(),
                  const SizedBox(height: 48),
                  _buildFarmSection(),
                  const SizedBox(height: 48),
                  _buildRelatedProducts(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Top Bar ───
  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: const Icon(Icons.arrow_back_rounded, size: 18, color: _dark),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Product Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _dark),
          ),
          const Spacer(),
          _buildHeaderButton(Icons.share_rounded, 'Share'),
          const SizedBox(width: 12),
          _buildHeaderButton(Icons.favorite_border_rounded, 'Save'),
        ],
      ),
    );
  }

  Widget _buildHeaderButton(IconData icon, String label) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: _dark),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _dark)),
          ],
        ),
      ),
    );
  }

  // ─── Breadcrumbs ───
  Widget _buildBreadcrumbs() {
    return Row(
      children: [
        Text('Marketplace', style: TextStyle(fontSize: 13, color: _muted)),
        Icon(Icons.chevron_right_rounded, size: 18, color: _muted),
        Text('Pre-Order', style: TextStyle(fontSize: 13, color: _muted)),
        Icon(Icons.chevron_right_rounded, size: 18, color: _muted),
        const Text('Organic Carrots', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _dark)),
      ],
    );
  }

  // ─── Two-column Main Content ───
  Widget _buildMainContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image column
        Expanded(
          flex: 5,
          child: _buildImageSection(),
        ),
        const SizedBox(width: 40),
        // Details column
        Expanded(
          flex: 4,
          child: _buildDetailsSection(),
        ),
      ],
    );
  }

  Widget _buildImageSection() {
    return Column(
      children: [
        // Main image
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: AppData.carrotsHeroImageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (_, __) => Container(color: Colors.grey[100]),
                  errorWidget: (_, __, ___) => Container(color: Colors.grey[100], child: const Icon(Icons.image, size: 48)),
                ),
                // Pre-order badge
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'PRE-ORDER ACTIVE',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Thumbnail row
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 3 ? 12 : 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        border: i == 0 ? Border.all(color: _primary, width: 2) : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(i == 0 ? 10 : 12),
                        child: CachedNetworkImage(
                          imageUrl: AppData.carrotsHeroImageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: Colors.grey[100]),
                          errorWidget: (_, __, ___) => Container(color: Colors.grey[100]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Farm tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_rounded, size: 14, color: _primary),
              const SizedBox(width: 6),
              Text('Green Valley Organic Farm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _primary)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Title
        const Text(
          'Organic Carrots',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: _dark, letterSpacing: -0.5),
        ),
        const SizedBox(height: 12),
        // Price
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              '\$4.50',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _dark),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('per kg', style: TextStyle(fontSize: 15, color: _muted)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Info cards
        Row(
          children: [
            Expanded(child: _buildInfoChip(Icons.calendar_today_rounded, 'Harvest', 'Oct 25')),
            const SizedBox(width: 12),
            Expanded(child: _buildInfoChip(Icons.inventory_2_rounded, 'Stock Left', '50kg')),
          ],
        ),
        const SizedBox(height: 24),
        // Quantity selector
        _buildQuantitySelector(),
        const SizedBox(height: 20),
        // Downpayment toggle
        _buildDownpaymentToggle(),
        const SizedBox(height: 28),
        // Total & CTA
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Price', style: TextStyle(fontSize: 14, color: _muted)),
                  Text(
                    '\$${(_quantity * 4.5).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _dark),
                  ),
                ],
              ),
              if (_downpaymentEnabled) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Downpayment (25%)', style: TextStyle(fontSize: 13, color: _muted)),
                    Text(
                      '\$${(_quantity * 4.5 * 0.25).toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _primary),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Pre-order Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.notifications_active_rounded, size: 18, color: _primary),
                  label: Text('Notify me on harvest', style: TextStyle(fontWeight: FontWeight.w600, color: _primary)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _primary),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _primary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _dark)),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(Icons.scale_rounded, size: 20, color: _dark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Quantity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _dark)),
                Text('Min order: 1 kg', style: TextStyle(fontSize: 12, color: _muted)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                _buildQtyButton(Icons.remove_rounded, () {
                  if (_quantity > 1) setState(() => _quantity--);
                }),
                Container(
                  width: 50,
                  alignment: Alignment.center,
                  child: Text('$_quantity', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _dark)),
                ),
                _buildQtyButton(Icons.add_rounded, () {
                  if (_quantity < 50) setState(() => _quantity++);
                }),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('kg', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _muted)),
        ],
      ),
    );
  }

  Widget _buildQtyButton(IconData icon, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: _dark),
        ),
      ),
    );
  }

  Widget _buildDownpaymentToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.payments_rounded, color: _primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('25% Downpayment', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _dark)),
                Text('Secure price, pay the rest on delivery', style: TextStyle(fontSize: 12, color: _muted)),
              ],
            ),
          ),
          Switch(
            value: _downpaymentEnabled,
            onChanged: (v) => setState(() => _downpaymentEnabled = v),
            activeColor: _primary,
          ),
        ],
      ),
    );
  }

  // ─── Farm Section ───
  Widget _buildFarmSection() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Farm story
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.yard_rounded, color: _primary, size: 22),
                    const SizedBox(width: 10),
                    const Text('Farm Story', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _dark)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _primary.withValues(alpha: 0.3), width: 2),
                      ),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: AppData.farmStoryAvatarUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: Colors.grey[100]),
                          errorWidget: (_, __, ___) => const Icon(Icons.person),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Farmer John Doe', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _dark)),
                        Text('"Grown with love since 1994"', style: TextStyle(fontSize: 13, color: _muted, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Our carrots are grown without pesticides in the rich mineral soils of the highland valley. We use traditional crop rotation techniques ensuring the best organic quality for your family.',
                  style: TextStyle(fontSize: 14, color: _muted, height: 1.7),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          // Farm map
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, color: _primary, size: 22),
                    const SizedBox(width: 10),
                    const Text('Farm Location', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _dark)),
                  ],
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 10,
                        child: CachedNetworkImage(
                          imageUrl: AppData.farmMapImageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (_, __) => Container(color: Colors.grey[100], height: 180),
                          errorWidget: (_, __, ___) => Container(color: Colors.grey[100], height: 180),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.15),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on_rounded, color: _primary, size: 16),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Highland Valley Farm',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _dark),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Related Products ───
  Widget _buildRelatedProducts() {
    final products = AppData.preOrderProducts.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'You might also like',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _dark),
        ),
        const SizedBox(height: 20),
        GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.1,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          itemBuilder: (context, i) {
            final p = products[i];
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        child: CachedNetworkImage(
                          imageUrl: p.imageUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: Colors.grey[100]),
                          errorWidget: (_, __, ___) => Container(color: Colors.grey[100]),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _dark), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('${p.price}${p.unit}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _primary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
