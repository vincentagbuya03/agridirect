// ============================================================================
// lib/mobile/screens/farmer/farmer_vouchers_screen.dart
// Mobile screen for farmers to manage discount vouchers.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/commerce/voucher_service.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/widgets/app_shimmer_loader.dart';

class FarmerVouchersScreen extends StatefulWidget {
  const FarmerVouchersScreen({super.key});

  @override
  State<FarmerVouchersScreen> createState() => _FarmerVouchersScreenState();
}

class _FarmerVouchersScreenState extends State<FarmerVouchersScreen> {
  final VoucherService _voucherService = VoucherService();
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _vouchers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchVouchers();
  }

  Future<void> _fetchVouchers() async {
    setState(() => _isLoading = true);
    try {
      final userId = _authService.userId;
      if (userId.isNotEmpty) {
        final list = await _voucherService.getFarmerVouchers(userId);
        setState(() {
          _vouchers = list;
        });
      }
    } catch (e) {
      debugPrint('Error loading vouchers: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  int get _activeVouchersCount {
    final now = DateTime.now();
    return _vouchers.where((v) {
      final endDate = DateTime.tryParse(v['end_date'] ?? '') ?? now;
      final used = (v['used_count'] as num?)?.toInt() ?? 0;
      final limit = (v['usage_limit'] as num?)?.toInt() ?? 1;
      return endDate.isAfter(now) && used < limit;
    }).length;
  }

  int get _totalClaimsCount {
    return _vouchers.fold(0, (sum, v) {
      final used = (v['used_count'] as num?)?.toInt() ?? 0;
      return sum + used;
    });
  }

  int get _expiredCount {
    final now = DateTime.now();
    return _vouchers.where((v) {
      final endDate = DateTime.tryParse(v['end_date'] ?? '') ?? now;
      return endDate.isBefore(now);
    }).length;
  }

  Future<void> _handleDeleteVoucher(String voucherId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Delete Voucher',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this voucher? Customers will no longer be able to claim or use it.',
          style: GoogleFonts.inter(color: AppColors.textSubtle, fontSize: 14, height: 1.5),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSubtle,
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _voucherService.deleteVoucher(voucherId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  const Text('Voucher deleted successfully'),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              margin: const EdgeInsets.all(16),
            ),
          );
          _fetchVouchers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete voucher: $e'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    }
  }

  void _openCreateVoucherSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateVoucherBottomSheet(
        onCreated: () {
          _fetchVouchers();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: _buildAppBar(),
      floatingActionButton: _buildFAB(),
      body: RefreshIndicator(
        onRefresh: _fetchVouchers,
        color: AppColors.primary,
        backgroundColor: Colors.white,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildStatsHeader()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  'Your Vouchers',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textHeadline,
                  ),
                ),
              ),
            ),
            if (_isLoading)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.builder(
                  itemCount: 3,
                  itemBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: SizedBox(height: 120, child: AppShimmerLoader.rectangle(borderRadius: 20)),
                  ),
                ),
              )
            else if (_vouchers.isEmpty)
              SliverFillRemaining(child: _buildEmptyState())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList.builder(
                  itemCount: _vouchers.length,
                  itemBuilder: (context, index) => _buildVoucherCard(_vouchers[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: const Color(0xFFE2E8F0),
        ),
      ),
      title: Text(
        'Voucher Manager',
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800,
          fontSize: 17,
          color: AppColors.textHeadline,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textHeadline, size: 20),
        onPressed: () => context.pop(),
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _openCreateVoucherSheet,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      icon: const Icon(Icons.add_rounded, size: 22),
      label: Text(
        'New Voucher',
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Overview',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _buildStatCell(
                icon: Icons.local_offer_rounded,
                label: 'Active',
                value: '$_activeVouchersCount',
              ),
              _buildStatDivider(),
              _buildStatCell(
                icon: Icons.people_alt_rounded,
                label: 'Total Claims',
                value: '$_totalClaimsCount',
              ),
              _buildStatDivider(),
              _buildStatCell(
                icon: Icons.timer_off_rounded,
                label: 'Expired',
                value: '$_expiredCount',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCell({required IconData icon, required String label, required String value}) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 52,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.confirmation_number_outlined,
                size: 64,
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Vouchers Yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textHeadline,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Create store coupons and discount vouchers to encourage customers to purchase more from your farm stall.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textSubtle,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _openCreateVoucherSheet,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'Create Your First Voucher',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoucherCard(Map<String, dynamic> voucher) {
    final now = DateTime.now();
    final code = voucher['code'] ?? '';
    final discValue = (voucher['discount_value'] as num?)?.toDouble() ?? 0.0;
    final type = voucher['discount_type'] ?? 'flat';
    final minSpend = (voucher['min_spend'] as num?)?.toDouble() ?? 0.0;
    final limit = (voucher['usage_limit'] as num?)?.toInt() ?? 100;
    final used = (voucher['used_count'] as num?)?.toInt() ?? 0;
    final endDate = DateTime.tryParse(voucher['end_date'] ?? '') ?? now;

    final isExpired = endDate.isBefore(now);
    final isFullyClaimed = used >= limit;
    final isActive = !isExpired && !isFullyClaimed;

    final discountStr = type == 'percentage'
        ? '${discValue.toStringAsFixed(0)}%'
        : '₱${discValue.toStringAsFixed(0)}';

    final statusLabel = isExpired
        ? 'Expired'
        : isFullyClaimed
            ? 'Fully Claimed'
            : 'Active';

    final statusColor = isActive
        ? AppColors.success
        : isFullyClaimed
            ? AppColors.accent
            : AppColors.error;

    final statusBgColor = statusColor.withValues(alpha: 0.1);

    final progress = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // ── Left Discount Badge ──
              Container(
                width: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isActive
                        ? [
                            AppColors.primary.withValues(alpha: 0.12),
                            AppColors.primary.withValues(alpha: 0.04),
                          ]
                        : [Colors.grey.shade100, Colors.grey.shade50],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      discountStr,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: isActive ? AppColors.primary : Colors.grey.shade500,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'OFF',
                      style: GoogleFonts.inter(
                        color: isActive
                            ? AppColors.primary.withValues(alpha: 0.7)
                            : Colors.grey.shade400,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Dashed Divider ──
              CustomPaint(
                size: const Size(1, double.infinity),
                painter: _DashedLinePainter(color: Colors.grey.shade300),
              ),

              // ── Right Details ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Code + Status Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              code,
                              style: GoogleFonts.inter(
                                color: isActive ? AppColors.primary : Colors.grey.shade600,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusBgColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusLabel,
                              style: GoogleFonts.inter(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Delete button
                          GestureDetector(
                            onTap: () => _handleDeleteVoucher(voucher['voucher_id']),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: AppColors.error,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Min Spend & Expiry
                      Row(
                        children: [
                          Icon(Icons.shopping_bag_outlined, size: 13, color: AppColors.textSubtle),
                          const SizedBox(width: 4),
                          Text(
                            'Min ₱${minSpend.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                              color: AppColors.textBody,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.textSubtle),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM d, yyyy').format(endDate),
                            style: GoogleFonts.inter(
                              color: isExpired ? AppColors.error : AppColors.textSubtle,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Usage progress
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.grey.shade100,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isActive ? AppColors.primary : Colors.grey.shade400,
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$used/$limit',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSubtle,
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

// ── Dashed Line Painter ──────────────────────────────────────────────────────
class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashHeight = 5.0;
    const dashSpace = 4.0;
    double startY = 0.0;

    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Create Voucher Bottom Sheet ───────────────────────────────────────────────
class _CreateVoucherBottomSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateVoucherBottomSheet({required this.onCreated});

  @override
  State<_CreateVoucherBottomSheet> createState() => _CreateVoucherBottomSheetState();
}

class _CreateVoucherBottomSheetState extends State<_CreateVoucherBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _valController = TextEditingController();
  final _minSpendController = TextEditingController();
  final _limitController = TextEditingController();

  String _discountType = 'flat';
  DateTime? _selectedEndDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _codeController.dispose();
    _valController.dispose();
    _minSpendController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textHeadline,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedEndDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select an expiration date'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final farmerId = AuthService().userId;
      if (farmerId.isEmpty) throw Exception('Farmer session not found');

      final code = _codeController.text.trim().toUpperCase();
      final val = double.parse(_valController.text.trim());
      final minSpend = double.parse(
          _minSpendController.text.trim().isEmpty ? '0' : _minSpendController.text.trim());
      final limit = int.parse(
          _limitController.text.trim().isEmpty ? '100' : _limitController.text.trim());

      await VoucherService().createVoucher(
        farmerId: farmerId,
        code: code,
        discountType: _discountType,
        discountValue: val,
        minSpend: minSpend,
        usageLimit: limit,
        startDate: DateTime.now(),
        endDate: _selectedEndDate!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                const Text('Voucher created successfully!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.all(16),
          ),
        );
        widget.onCreated();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create voucher: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        top: 0,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sheet Handle + Header
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 20),
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.confirmation_number_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create Voucher',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: AppColors.textHeadline,
                        ),
                      ),
                      Text(
                        'Set up a discount for your customers',
                        style: GoogleFonts.inter(
                          color: AppColors.textSubtle,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Voucher Code ──
              _buildLabel('Voucher Code'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: _inputDecoration(
                  hint: 'e.g., FRESH50',
                  prefixIcon: Icons.tag_rounded,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Code is required';
                  if (val.trim().length < 3) return 'Code must be at least 3 characters';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── Discount Type ──
              _buildLabel('Discount Type'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildTypeChip(
                      label: 'Flat (₱)',
                      icon: Icons.currency_exchange_rounded,
                      isSelected: _discountType == 'flat',
                      onTap: () => setState(() => _discountType = 'flat'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTypeChip(
                      label: 'Percentage (%)',
                      icon: Icons.percent_rounded,
                      isSelected: _discountType == 'percentage',
                      onTap: () => setState(() => _discountType = 'percentage'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Value & Min Spend Row ──
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel(_discountType == 'flat' ? 'Discount Amount' : 'Percentage Value'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _valController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration(
                            hint: _discountType == 'flat' ? 'e.g., 50' : 'e.g., 10',
                            prefixIcon: _discountType == 'flat'
                                ? Icons.currency_exchange_rounded
                                : Icons.percent_rounded,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Required';
                            final parsed = double.tryParse(val.trim());
                            if (parsed == null || parsed <= 0) return 'Invalid';
                            if (_discountType == 'percentage' && parsed > 100) return 'Max 100%';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Min Spend (₱)'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _minSpendController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration(
                            hint: 'e.g., 100',
                            prefixIcon: Icons.shopping_bag_outlined,
                          ),
                          validator: (val) {
                            if (val != null && val.trim().isNotEmpty) {
                              final parsed = double.tryParse(val.trim());
                              if (parsed == null || parsed < 0) return 'Invalid';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Usage Limit & Expiry Row ──
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Usage Limit'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _limitController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration(
                            hint: 'e.g., 100',
                            prefixIcon: Icons.people_alt_outlined,
                          ),
                          validator: (val) {
                            if (val != null && val.trim().isNotEmpty) {
                              final parsed = int.tryParse(val.trim());
                              if (parsed == null || parsed <= 0) return 'Invalid';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Expiration Date'),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _pickEndDate,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _selectedEndDate != null
                                    ? AppColors.primary.withValues(alpha: 0.4)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 16,
                                  color: _selectedEndDate == null ? Colors.grey.shade400 : AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedEndDate == null
                                        ? 'Pick date'
                                        : DateFormat('MMM d, yy').format(_selectedEndDate!),
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: _selectedEndDate == null
                                          ? Colors.grey.shade400
                                          : AppColors.textHeadline,
                                      fontWeight: _selectedEndDate == null
                                          ? FontWeight.w400
                                          : FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ── Submit Button ──
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Creating...',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ],
                        )
                      : Text(
                          'Create Voucher',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: AppColors.textHeadline,
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, required IconData prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 14),
      fillColor: Colors.grey.shade50,
      filled: true,
      prefixIcon: Icon(prefixIcon, size: 18, color: Colors.grey.shade400),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildTypeChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.primary : AppColors.textSubtle,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isSelected ? AppColors.primary : AppColors.textSubtle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
