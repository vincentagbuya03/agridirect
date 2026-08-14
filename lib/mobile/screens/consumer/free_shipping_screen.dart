import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/widgets/app_shimmer_loader.dart';

class FreeShippingScreen extends StatefulWidget {
  const FreeShippingScreen({super.key});

  @override
  State<FreeShippingScreen> createState() => _FreeShippingScreenState();
}

class _FreeShippingScreenState extends State<FreeShippingScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<VoucherItem>> _vouchersFuture;
  final Set<String> _claimedVoucherIds = {};
  final Set<String> _claimingVoucherIds = {};
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _vouchersFuture = _getFreeShippingVouchers();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<List<VoucherItem>> _getFreeShippingVouchers() async {
    final dbVouchers = await SupabaseDataService().getAvailablePlatformVouchers();
    final fsVouchers = dbVouchers
        .where((v) =>
            v.title.toLowerCase().contains('free') ||
            v.title.toLowerCase().contains('shipping'))
        .toList();

    final userVouchers = await SupabaseDataService().getUserVouchers('available');
    for (var uv in userVouchers) {
      final matches = fsVouchers.where((fv) => fv.title == uv.title);
      for (var match in matches) {
        _claimedVoucherIds.add(match.id);
      }
    }

    return fsVouchers;
  }

  void _claimVoucher(VoucherItem voucher) async {
    if (_claimedVoucherIds.contains(voucher.id) ||
        _claimingVoucherIds.contains(voucher.id)) {
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      _claimingVoucherIds.add(voucher.id);
    });

    final success = await SupabaseDataService().claimVoucher(voucher.id);

    if (mounted) {
      setState(() {
        _claimingVoucherIds.remove(voucher.id);
        if (success) {
          _claimedVoucherIds.add(voucher.id);
        }
      });

      if (success) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text(
                'Voucher added to your wallet!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'MY VOUCHERS',
            textColor: const Color(0xFF6EE7B7),
            onPressed: () {},
          ),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              const Text('Already claimed or an error occurred.'),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: _buildHeroSection()),
          SliverToBoxAdapter(child: _buildHowItWorksSection()),
          SliverToBoxAdapter(child: _buildVoucherSectionHeader()),
          _buildVoucherList(),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: const Color(0xFFF0FDF4),
      elevation: 0,
      pinned: true,
      centerTitle: true,
      iconTheme: const IconThemeData(color: Color(0xFF065F46)),
      title: Text(
        'Free Shipping',
        style: GoogleFonts.poppins(
          color: const Color(0xFF065F46),
          fontWeight: FontWeight.w700,
          fontSize: 17,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.shopping_bag_outlined),
          onPressed: () => context.push('/cart'),
        ),
      ],
    );
  }

  Widget _buildHeroSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      height: 210,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF064E3B),
            Color(0xFF047857),
            Color(0xFF059669),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF047857).withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Decorative blurred circles
            Positioned(
              top: -60,
              right: -30,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -40,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              top: 30,
              right: 30,
              child: ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
            // Text Content
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 12, color: Color(0xFF78350F)),
                        const SizedBox(width: 5),
                        Text(
                          'EXCLUSIVE OFFER',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF78350F),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Farm-Fresh Delivery',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'On Us! 🌿',
                    style: GoogleFonts.playfairDisplay(
                      color: const Color(0xFF6EE7B7),
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      height: 1.1,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Claim vouchers below from local farmers\nand enjoy free delivery on your orders.',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11.5,
                      height: 1.5,
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

  Widget _buildHowItWorksSection() {
    final steps = [
      {
        'icon': Icons.card_giftcard_rounded,
        'color': const Color(0xFF059669),
        'bg': const Color(0xFFD1FAE5),
        'title': 'Claim Voucher',
        'desc': 'Tap Claim on any free shipping coupon below',
      },
      {
        'icon': Icons.shopping_cart_checkout_rounded,
        'color': const Color(0xFF2563EB),
        'bg': const Color(0xFFDBEAFE),
        'title': 'Shop & Checkout',
        'desc': 'Meet the minimum spend to activate',
      },
      {
        'icon': Icons.handshake_rounded,
        'color': const Color(0xFFD97706),
        'bg': const Color(0xFFFEF3C7),
        'title': 'Pay & Receive',
        'desc': 'Farmer delivers, you pay cash for products only!',
      },
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How It Works',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: steps.asMap().entries.map((entry) {
              final step = entry.value;
              final isLast = entry.key == steps.length - 1;
              return Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: step['bg'] as Color,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              step['icon'] as IconData,
                              color: step['color'] as Color,
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            step['title'] as String,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            step['desc'] as String,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              color: const Color(0xFF9CA3AF),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Padding(
                        padding: const EdgeInsets.only(top: 11),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: Colors.grey.shade300,
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available Vouchers',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF1F2937),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Tap to claim your free delivery coupon',
                style: GoogleFonts.inter(
                  color: const Color(0xFF6B7280),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF6EE7B7)),
            ),
            child: Text(
              '🚚 FREE',
              style: GoogleFonts.inter(
                color: const Color(0xFF065F46),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherList() {
    return FutureBuilder<List<VoucherItem>>(
      future: _vouchersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: AppShimmerLoader(height: 120),
              ),
              childCount: 3,
            ),
          );
        }

        final vouchers = snapshot.data ?? [];
        if (vouchers.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  const Icon(Icons.local_shipping_outlined,
                      size: 56, color: Color(0xFFD1D5DB)),
                  const SizedBox(height: 16),
                  Text(
                    'No Vouchers Available',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Check back soon! Farmers will post\nfree shipping promotions here.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9CA3AF),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildTicketVoucherCard(vouchers[index]),
            childCount: vouchers.length,
          ),
        );
      },
    );
  }

  Widget _buildTicketVoucherCard(VoucherItem voucher) {
    final isClaimed = _claimedVoucherIds.contains(voucher.id);
    final isClaiming = _claimingVoucherIds.contains(voucher.id);

    // Format expiry date
    String expiryText = 'No expiry';
    if (voucher.validUntil != null) {
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      expiryText = 'Valid until ${months[voucher.validUntil!.month - 1]} ${voucher.validUntil!.day}, ${voucher.validUntil!.year}';
    }

    return AnimatedOpacity(
      opacity: isClaimed ? 0.7 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isClaimed
                  ? Colors.black.withValues(alpha: 0.03)
                  : const Color(0xFF059669).withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: isClaimed
                ? const Color(0xFFE5E7EB)
                : const Color(0xFF6EE7B7),
            width: 1.5,
          ),
        ),
        child: Stack(
          children: [
            // Dashed divider cutout effect
            Positioned(
              left: 84,
              top: 0,
              bottom: 0,
              child: CustomPaint(
                size: const Size(1, double.infinity),
                painter: _DashedLinePainter(
                    color: isClaimed
                        ? const Color(0xFFE5E7EB)
                        : const Color(0xFF6EE7B7)),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left coupon stub
                Container(
                  width: 84,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isClaimed
                        ? const Color(0xFFF9FAFB)
                        : const Color(0xFFECFDF5),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isClaimed
                            ? Icons.check_circle_rounded
                            : Icons.local_shipping_rounded,
                        size: 30,
                        color: isClaimed
                            ? Colors.grey.shade400
                            : const Color(0xFF059669),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isClaimed ? 'CLAIMED' : 'FREE\nSHIP',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: isClaimed
                              ? Colors.grey.shade400
                              : const Color(0xFF065F46),
                          letterSpacing: 0.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),

                // Right content area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Farmer badge if applicable
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '🌾 Farmer Promo',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          voucher.title,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isClaimed
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFF1F2937),
                            height: 1.2,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (voucher.description != null &&
                            voucher.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            voucher.description!,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        // Bottom row: expiry + claim button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 11,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      expiryText,
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: Colors.grey.shade400,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: (isClaimed || isClaiming)
                                  ? null
                                  : () => _claimVoucher(voucher),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 9),
                                decoration: BoxDecoration(
                                  color: isClaimed
                                      ? Colors.grey.shade100
                                      : const Color(0xFF047857),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: isClaiming
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : Text(
                                        isClaimed ? '✓ Claimed' : 'Claim',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isClaimed
                                              ? Colors.grey.shade400
                                              : Colors.white,
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for the dashed divider line (coupon cut effect)
class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const dashHeight = 5.0;
    const dashSpace = 4.0;
    double startY = 0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}