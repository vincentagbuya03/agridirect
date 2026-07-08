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

  Future<void> _handleDeleteVoucher(String voucherId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Voucher',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: const Text('Are you sure you want to delete this voucher? Customers will no longer be able to claim or use it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _voucherService.deleteVoucher(voucherId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Voucher deleted successfully'),
              backgroundColor: AppColors.success,
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Voucher Manager',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppColors.textHeadline,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textHeadline, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateVoucherSheet,
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchVouchers,
        color: AppColors.primary,
        child: Column(
          children: [
            _buildStatsHeader(),
            Expanded(
              child: _isLoading
                  ? _buildShimmerList()
                  : _vouchers.isEmpty
                      ? _buildEmptyState()
                      : _buildVouchersList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Vouchers',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$_activeVouchersCount',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Total Claims',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$_totalClaimsCount',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: 3,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: SizedBox(
          height: 120,
          child: AppShimmerLoader.rectangle(borderRadius: 20),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.confirmation_number_outlined,
              size: 72,
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
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
        const SizedBox(height: 12),
        Text(
          'Create store coupons and discount vouchers to encourage customers to purchase more from your farm stall.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSubtle,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        Center(
          child: FilledButton.icon(
            onPressed: _openCreateVoucherSheet,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create New'),
          ),
        ),
      ],
    );
  }

  Widget _buildVouchersList() {
    final now = DateTime.now();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _vouchers.length,
      itemBuilder: (context, index) {
        final voucher = _vouchers[index];
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

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.grey.shade200,
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                IntrinsicHeight(
                  child: Row(
                    children: [
                      // Left Side (Discount Badge)
                      Container(
                        width: 100,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isActive
                                ? [AppColors.primary.withValues(alpha: 0.12), AppColors.primary.withValues(alpha: 0.05)]
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
                              style: GoogleFonts.plusJakartaSans(
                                color: isActive ? AppColors.primary : Colors.grey.shade600,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'OFF',
                              style: GoogleFonts.inter(
                                color: isActive ? AppColors.primary.withValues(alpha: 0.8) : Colors.grey.shade500,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Dashed Divider simulation
                      CustomPaint(
                        size: const Size(1, double.infinity),
                        painter: _DashedLinePainter(
                          color: Colors.grey.shade300,
                        ),
                      ),
                      // Right Side (Details)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? AppColors.primary.withValues(alpha: 0.1)
                                          : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      code,
                                      style: GoogleFonts.inter(
                                        color: isActive ? AppColors.primary : Colors.grey.shade600,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Expiry status indicator
                                  Text(
                                    isExpired
                                        ? 'Expired'
                                        : isFullyClaimed
                                            ? 'Fully Claimed'
                                            : 'Active',
                                    style: GoogleFonts.inter(
                                      color: isActive
                                          ? AppColors.success
                                          : isFullyClaimed
                                              ? AppColors.accent
                                              : AppColors.error,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Min Spend: ₱${minSpend.toStringAsFixed(0)}',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textHeadline,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Expires: ${DateFormat('yMMMd').format(endDate)}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSubtle,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Progress bar
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: limit > 0 ? used / limit : 0.0,
                                        backgroundColor: Colors.grey.shade100,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          isActive ? AppColors.primary : Colors.grey.shade400,
                                        ),
                                        minHeight: 5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '$used/$limit used',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
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
                      // Actions (Delete)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                        onPressed: () => _handleDeleteVoucher(voucher['voucher_id']),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

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

  String _discountType = 'flat'; // 'flat' or 'percentage'
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
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
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
        const SnackBar(
          content: Text('Please select an expiration date'),
          backgroundColor: AppColors.error,
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
      final minSpend = double.parse(_minSpendController.text.trim().isEmpty ? '0' : _minSpendController.text.trim());
      final limit = int.parse(_limitController.text.trim().isEmpty ? '100' : _limitController.text.trim());

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
          const SnackBar(
            content: Text('Voucher created successfully!'),
            backgroundColor: AppColors.success,
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
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Create New Voucher',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: AppColors.textHeadline,
                ),
              ),
              const SizedBox(height: 24),

              // Code field
              Text(
                'Voucher Code',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textHeadline),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'e.g., FRESH50',
                  hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14),
                  fillColor: Colors.grey.shade50,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Code is required';
                  if (val.trim().length < 3) return 'Code must be at least 3 characters';
                  return null;
                },
              ),
              const SizedBox(height: 18),

              // Discount Type selector
              Text(
                'Discount Type',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textHeadline),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _discountType = 'flat'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _discountType == 'flat' ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _discountType == 'flat' ? AppColors.primary : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Flat Discount (₱)',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: _discountType == 'flat' ? AppColors.primary : AppColors.textSubtle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _discountType = 'percentage'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _discountType == 'percentage' ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _discountType == 'percentage' ? AppColors.primary : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Percentage (%)',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: _discountType == 'percentage' ? AppColors.primary : AppColors.textSubtle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Value & Min Spend Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _discountType == 'flat' ? 'Discount Amount' : 'Percentage Value',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textHeadline),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _valController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: _discountType == 'flat' ? 'e.g., 50' : 'e.g., 10',
                            hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14),
                            fillColor: Colors.grey.shade50,
                            filled: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Value required';
                            final parsed = double.tryParse(val.trim());
                            if (parsed == null || parsed <= 0) return 'Invalid amount';
                            if (_discountType == 'percentage' && parsed > 100) return 'Max is 100%';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Min Spend (₱)',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textHeadline),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _minSpendController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'e.g., 100',
                            hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14),
                            fillColor: Colors.grey.shade50,
                            filled: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          validator: (val) {
                            if (val != null && val.trim().isNotEmpty) {
                              final parsed = double.tryParse(val.trim());
                              if (parsed == null || parsed < 0) return 'Invalid spend';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Expiration & Limit Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Usage Limit',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textHeadline),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _limitController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'e.g., 100',
                            hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14),
                            fillColor: Colors.grey.shade50,
                            filled: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          validator: (val) {
                            if (val != null && val.trim().isNotEmpty) {
                              final parsed = int.tryParse(val.trim());
                              if (parsed == null || parsed <= 0) return 'Invalid limit';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expiration Date',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textHeadline),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _pickEndDate,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _selectedEndDate == null
                                  ? 'Select Expiry'
                                  : DateFormat('yMMMd').format(_selectedEndDate!),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: _selectedEndDate == null ? Colors.grey[400] : AppColors.textHeadline,
                                fontWeight: _selectedEndDate == null ? FontWeight.w400 : FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Action button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                  child: Text(
                    _isSaving ? 'Creating...' : 'Create Voucher',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
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
