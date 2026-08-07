import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/commerce/voucher_service.dart';

import '../../../shared/router/app_routes.dart';

class WebClaimedVouchersContent extends StatefulWidget {
  const WebClaimedVouchersContent({super.key});

  @override
  State<WebClaimedVouchersContent> createState() => _WebClaimedVouchersContentState();
}

class _WebClaimedVouchersContentState extends State<WebClaimedVouchersContent> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _vouchers = [];
  final Color primary = const Color(0xFF10B981);
  final Color _dark = const Color(0xFF1E293B);
  final Color _muted = const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _loadVouchers();
  }

  Future<void> _loadVouchers() async {
    final userId = AuthService().userId;
    final list = await VoucherService().getUserClaimedVouchersHistory(userId);
    if (mounted) {
      setState(() {
        _vouchers = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
    }

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DefaultTabController(
        length: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'My Claimed Vouchers',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Use your claimed vouchers at checkout to get discounts',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _muted,
              ),
            ),
            const SizedBox(height: 24),
            TabBar(
              labelColor: primary,
              unselectedLabelColor: _muted,
              indicatorColor: primary,
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Active'),
                Tab(text: 'Used'),
                Tab(text: 'Expired'),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 400,
              child: TabBarView(
                children: [
                  _buildWebVouchersTab(0),
                  _buildWebVouchersTab(1),
                  _buildWebVouchersTab(2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebVouchersTab(int tabIndex) {
    final now = DateTime.now();
    final list = _vouchers.where((item) {
      final isUsed = item['is_used'] == true;
      final voucher = item['vouchers'] as Map<String, dynamic>?;
      if (voucher == null) return false;

      final endDateStr = voucher['end_date']?.toString();
      final endDate = endDateStr != null ? DateTime.tryParse(endDateStr) : null;
      final isExpired = endDate != null && endDate.isBefore(now);

      if (tabIndex == 0) return !isUsed && !isExpired;
      if (tabIndex == 1) return isUsed;
      return !isUsed && isExpired;
    }).toList();

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.confirmation_number_outlined, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No Vouchers Found',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: _dark),
            ),
            const SizedBox(height: 6),
            Text(
              'Explore farms to claim active discount vouchers.',
              style: GoogleFonts.inter(fontSize: 13, color: _muted),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.go(AppRoutes.marketplace),
              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
              label: const Text('Explore Marketplace'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 110,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final voucher = item['vouchers'] as Map<String, dynamic>;
        final code = voucher['code']?.toString() ?? '';
        final discountType = voucher['discount_type']?.toString() ?? 'fixed';
        final discountVal = (voucher['discount_value'] as num?)?.toDouble() ?? 0.0;
        final minSpend = (voucher['min_spend'] as num?)?.toDouble() ?? 0.0;
        final farmName = voucher['farm_name']?.toString() ?? 'Partner Farm';
        final endDateStr = voucher['end_date']?.toString();

        String expiryText = 'Valid Period';
        if (endDateStr != null) {
          final endDate = DateTime.tryParse(endDateStr);
          if (endDate != null) {
            expiryText = 'Expires ${endDate.month}/${endDate.day}/${endDate.year}';
          }
        }

        final isPercentage = discountType == 'percentage';
        final valueText = isPercentage ? '${discountVal.toInt()}%' : '₱${discountVal.toInt()}';
        final labelText = isPercentage ? 'Discount' : 'OFF';
        final Color themeColor = tabIndex == 0 ? primary : Colors.grey[400]!;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 90,
                decoration: BoxDecoration(
                  color: tabIndex == 0 ? primary : Colors.grey[300],
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(13)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(valueText, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24)),
                    Text(labelText, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              farmName,
                              style: GoogleFonts.plusJakartaSans(
                                color: tabIndex == 0 ? _dark : Colors.grey[600],
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: tabIndex == 0 ? primary.withValues(alpha: 0.1) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              code,
                              style: GoogleFonts.plusJakartaSans(color: themeColor, fontWeight: FontWeight.w700, fontSize: 9),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Min. Spend ₱${minSpend.toInt()}', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(expiryText, style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.w500)),
                          if (tabIndex == 0)
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => context.go(AppRoutes.marketplace),
                                child: Text('USE NOW', style: GoogleFonts.plusJakartaSans(color: primary, fontWeight: FontWeight.w800, fontSize: 10)),
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
        );
      },
    );
  }
}
