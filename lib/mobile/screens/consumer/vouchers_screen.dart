import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/widgets/app_shimmer_loader.dart';

class VouchersScreen extends StatefulWidget {
  const VouchersScreen({super.key});

  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<VoucherItem>> _availableFuture;
  late Future<List<VoucherItem>> _usedFuture;
  late Future<List<VoucherItem>> _expiredFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _availableFuture = SupabaseDataService().getUserVouchers('available');
    _usedFuture = SupabaseDataService().getUserVouchers('used');
    _expiredFuture = SupabaseDataService().getUserVouchers('expired');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Voucher Center',
          style: GoogleFonts.poppins(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFFD97706),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFFD97706),
              indicatorWeight: 3,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
              unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
              tabs: const [
                Tab(text: 'Available'),
                Tab(text: 'Used'),
                Tab(text: 'Expired'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVoucherList(_availableFuture, isAvailable: true),
          _buildVoucherList(_usedFuture, isUsed: true),
          _buildVoucherList(_expiredFuture, isExpired: true),
        ],
      ),
    );
  }

  Widget _buildVoucherList(Future<List<VoucherItem>> future, {bool isAvailable = false, bool isUsed = false, bool isExpired = false}) {
    return FutureBuilder<List<VoucherItem>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (_, _) => const AppShimmerLoader(height: 110),
          );
        }

        final vouchers = snapshot.data ?? [];
        if (vouchers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.confirmation_number_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  'No vouchers found.',
                  style: GoogleFonts.inter(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          itemCount: vouchers.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            return _buildVoucherTicket(vouchers[index]);
          },
        );
      },
    );
  }

  Widget _buildVoucherTicket(VoucherItem voucher) {
    final bool isExpired = voucher.status == 'expired';
    final bool isUsed = voucher.status == 'used';
    final bool isAvailable = voucher.status == 'available';
    final bool isFreeShipping = voucher.title.toLowerCase().contains('shipping');

    final Color badgeGradientStart = isExpired || isUsed
        ? const Color(0xFF64748B)
        : (isFreeShipping ? const Color(0xFF059669) : const Color(0xFFD97706));
    final Color badgeGradientEnd = isExpired || isUsed
        ? const Color(0xFF94A3B8)
        : (isFreeShipping ? const Color(0xFF10B981) : const Color(0xFFF59E0B));

    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left Banner / Ticket Stub
          Container(
            width: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [badgeGradientStart, badgeGradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isFreeShipping ? Icons.local_shipping_rounded : Icons.confirmation_number_rounded,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(height: 6),
                Text(
                  isFreeShipping ? 'FREE SHIP' : 'VOUCHER',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          // Ticket Divider Line (Dotted feel via background border)
          Container(
            width: 1,
            color: Colors.grey.withValues(alpha: 0.2),
          ),
          // Right Content Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    voucher.title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: (isExpired || isUsed) ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (voucher.minSpend != null)
                    Text(
                      'Min. spend ₱${voucher.minSpend!.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        (isExpired || isUsed)
                            ? voucher.status.toUpperCase()
                            : 'Valid till ${voucher.validUntil?.month}/${voucher.validUntil?.day}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isExpired ? Colors.red : const Color(0xFF64748B),
                        ),
                      ),
                      if (isAvailable)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [badgeGradientStart, badgeGradientEnd],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: badgeGradientStart.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'Use Now',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              color: Colors.white,
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
    );
  }
}