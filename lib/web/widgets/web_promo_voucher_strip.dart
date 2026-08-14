import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../shared/services/core/supabase_data_service.dart';
import '../../shared/data/app_data.dart';

class WebPromoVoucherStrip extends StatefulWidget {
  final Color themeColor;
  final String ctaRoute;

  const WebPromoVoucherStrip({
    super.key,
    required this.themeColor,
    this.ctaRoute = '/vouchers',
  });

  @override
  State<WebPromoVoucherStrip> createState() => _WebPromoVoucherStripState();
}

class _WebPromoVoucherStripState extends State<WebPromoVoucherStrip> {
  late Future<List<VoucherItem>> _vouchersFuture;

  @override
  void initState() {
    super.initState();
    _vouchersFuture = SupabaseDataService().getAvailablePlatformVouchers();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<VoucherItem>>(
      future: _vouchersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
        }

        final vouchers = snapshot.data ?? [];
        if (vouchers.isEmpty) {
          return const SizedBox.shrink(); // Hide if no vouchers
        }

        // Take up to 2 vouchers for the preview strip
        final previewVouchers = vouchers.take(2).toList();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.themeColor.withValues(alpha: 0.1),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: widget.themeColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    for (int i = 0; i < previewVouchers.length; i++) ...[
                      if (i > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: widget.themeColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.add, color: widget.themeColor, size: 20),
                          ),
                        ),
                      Expanded(
                        child: _WebMiniVoucherCard(
                          voucher: previewVouchers[i],
                          themeColor: widget.themeColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Container(width: 1, height: 80, color: Colors.grey[200]),
              const SizedBox(width: 24),
              ElevatedButton(
                onPressed: () => context.push(widget.ctaRoute),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.themeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '+ SHOP VOUCHER',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'See all ${vouchers.length} deals',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WebMiniVoucherCard extends StatelessWidget {
  final VoucherItem voucher;
  final Color themeColor;

  const _WebMiniVoucherCard({
    required this.voucher,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isFreeShipping = voucher.title.toLowerCase().contains('shipping') || voucher.title.toLowerCase().contains('free');
    final Color stubColor = isFreeShipping ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    final String discountLabel = isFreeShipping
        ? 'FREE\nSHIP'
        : (voucher.discountPercentage != null
            ? '${voucher.discountPercentage!.toInt()}%'
            : '10%');

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            decoration: BoxDecoration(
              color: stubColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              border: Border(right: BorderSide(color: Colors.grey[200]!, style: BorderStyle.solid)),
            ),
            child: Center(
              child: Text(
                discountLabel,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: stubColor,
                  height: 1.1,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    voucher.code,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: const Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Min. spend ₱${voucher.minSpend}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: () => context.push('/vouchers'),
              style: TextButton.styleFrom(
                foregroundColor: themeColor,
                backgroundColor: themeColor.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: Text(
                'Use',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
