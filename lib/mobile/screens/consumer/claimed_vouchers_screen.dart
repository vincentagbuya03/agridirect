import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/commerce/voucher_service.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/router/app_routes.dart';

class ClaimedVouchersScreen extends StatefulWidget {
  const ClaimedVouchersScreen({super.key});

  @override
  State<ClaimedVouchersScreen> createState() => _ClaimedVouchersScreenState();
}

class _ClaimedVouchersScreenState extends State<ClaimedVouchersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final VoucherService _voucherService = VoucherService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _vouchers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadVouchers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadVouchers() async {
    setState(() => _isLoading = true);
    try {
      final userId = AuthService().userId;
      final list = await _voucherService.getUserClaimedVouchersHistory(userId);
      if (mounted) {
        setState(() {
          _vouchers = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading vouchers: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _filterVouchers(int tabIndex) {
    final now = DateTime.now();
    return _vouchers.where((item) {
      final isUsed = item['is_used'] == true;
      final voucher = item['vouchers'] as Map<String, dynamic>?;
      if (voucher == null) return false;

      final endDateStr = voucher['end_date']?.toString();
      final endDate = endDateStr != null ? DateTime.tryParse(endDateStr) : null;
      final isExpired = endDate != null && endDate.isBefore(now);

      if (tabIndex == 0) {
        // Active
        return !isUsed && !isExpired;
      } else if (tabIndex == 1) {
        // Used
        return isUsed;
      } else {
        // Expired
        return !isUsed && isExpired;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textHeadline),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'My Vouchers',
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.textHeadline,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey[500],
          indicatorColor: AppColors.primary,
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildVoucherList(0),
                _buildVoucherList(1),
                _buildVoucherList(2),
              ],
            ),
    );
  }

  Widget _buildVoucherList(int tabIndex) {
    final list = _filterVouchers(tabIndex);

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 16,
                  )
                ],
              ),
              child: Icon(
                Icons.confirmation_number_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Vouchers Found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textHeadline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tabIndex == 0
                  ? 'Claim vouchers from farmer profiles to get discounts!'
                  : 'Vouchers you used/expired will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            if (tabIndex == 0) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go(AppRoutes.home),
                icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                label: const Text('Explore Farms'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ]
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final voucher = item['vouchers'] as Map<String, dynamic>;
        return _buildVoucherTicket(voucher, tabIndex);
      },
    );
  }

  Widget _buildVoucherTicket(Map<String, dynamic> voucher, int tabIndex) {
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

    // Theme color based on tab state
    final Color primaryColor = tabIndex == 0 ? AppColors.primary : Colors.grey[400]!;
    final Color secondaryColor = tabIndex == 0 ? AppColors.accent : Colors.grey[300]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: VoucherPainter(color: primaryColor.withValues(alpha: 0.06)),
          child: Row(
            children: [
              // Left Section - Discount Info
              Container(
                width: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor,
                      secondaryColor,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      valueText,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      labelText.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),

              // Divider Line with cutout indicator
              CustomPaint(
                size: const Size(1, double.infinity),
                painter: DashedLinePainter(color: Colors.grey[200]!),
              ),

              // Right Section - Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                color: tabIndex == 0 ? AppColors.textHeadline : Colors.grey[600],
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: tabIndex == 0 ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey[200],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              code,
                              style: GoogleFonts.plusJakartaSans(
                                color: primaryColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Min. Spend ₱${minSpend.toInt()}',
                        style: GoogleFonts.inter(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            expiryText,
                            style: GoogleFonts.inter(
                              color: Colors.grey[400],
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (tabIndex == 0)
                            GestureDetector(
                              onTap: () => context.go(AppRoutes.home),
                              child: Text(
                                'USE NOW',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: 0.5,
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

class VoucherPainter extends CustomPainter {
  final Color color;
  VoucherPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DashedLinePainter extends CustomPainter {
  final Color color;
  DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashHeight = 5;
    const dashSpace = 4;
    double startY = 8;
    while (startY < size.height - 8) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }

    final cutoutPaint = Paint()
      ..color = const Color(0xFFF8FAFC)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(const Offset(0, 0), 8, cutoutPaint);
    canvas.drawCircle(Offset(0, size.height), 8, cutoutPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
