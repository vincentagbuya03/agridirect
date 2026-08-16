import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/data/app_data.dart';
import '../../widgets/web_promo_header.dart';

class WebVouchersScreen extends StatefulWidget {
  const WebVouchersScreen({super.key});

  @override
  State<WebVouchersScreen> createState() => _WebVouchersScreenState();
}

class _WebVouchersScreenState extends State<WebVouchersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<VoucherItem>> _availableVouchersFuture;
  late Future<List<VoucherItem>> _myVouchersFuture;

  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _promoInputController = TextEditingController();
  final Set<String> _claimedVoucherIds = {};

  final List<String> _categories = [
    'All',
    '🚚 Free Shipping',
    '🌾 Fresh Harvest',
    '📦 Wholesale Bulk',
    '🎁 Welcome Gifts',
    '⚡ Flash Specials',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  void _loadData() {
    setState(() {
      _availableVouchersFuture =
          SupabaseDataService().getAvailablePlatformVouchers();
      _myVouchersFuture = SupabaseDataService().getUserVouchers('available');
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _promoInputController.dispose();
    super.dispose();
  }

  void _applyManualPromoCode() {
    final code = _promoInputController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _claimedVoucherIds.add(code);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Promo code "$code" claimed and added to your wallet!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFD97706),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    _promoInputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: SingleChildScrollView(
        child: Column(
          children: [
            WebPromoHeader(
              activeTab: 'vouchers',
              searchPlaceholder: 'Search discount codes, delivery coupons & deals...',
              onSearchChanged: (q) => setState(() => _searchQuery = q.toLowerCase()),
            ),
            _buildFullWidthHeroBanner(),
            const SizedBox(height: 32),
            _buildMainContainer(),
            const SizedBox(height: 60),
            _buildHowItWorksSection(),
            const SizedBox(height: 60),
            _buildFaqSection(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // FULL-WIDTH HERO BANNER
  // -------------------------------------------------------------
  Widget _buildFullWidthHeroBanner() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF78350F), // Deep rich amber brown
            Color(0xFFB45309), // Amber 700
            Color(0xFFD97706), // Amber 600
            Color(0xFFF59E0B), // Vibrant Gold
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB45309).withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background ambient circles
          Positioned(
            top: -100,
            right: -60,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -80,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1300),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 32,
                  vertical: isMobile ? 24 : 48,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Navigation / Back button
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        InkWell(
                          onTap: () => context.pop(),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.arrow_back_rounded,
                                    color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Back to Marketplace',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_rounded,
                                  color: Color(0xFFFDE68A), size: 15),
                              const SizedBox(width: 6),
                              Text(
                                '100% Direct Farm Subsidies',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Hero Headline & Promo Input Bar
                    isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeroText(isMobile),
                              const SizedBox(height: 24),
                              _buildPromoCard(),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: _buildHeroText(isMobile)),
                              if (sw > 900) ...[
                                const SizedBox(width: 48),
                                _buildPromoCard(),
                              ],
                            ],
                          ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroText(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_offer_rounded,
                  size: 13, color: Color(0xFF78350F)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'VOUCHER VAULT · EXCLUSIVE HARVEST SAVINGS',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF78350F),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Voucher & Rewards Hub',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: isMobile ? 28 : 42,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          'Claim Instant Discounts 🏷️',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFFFDE68A),
            fontSize: isMobile ? 32 : 48,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            'Collect free delivery coupons, seasonal harvest discounts, and bulk seller allowances. Apply vouchers seamlessly at checkout.',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: isMobile ? 13.5 : 15,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPromoCard() {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 30,
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
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.confirmation_number_outlined,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Have a Promo Code?',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'Enter secret code below',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _promoInputController,
                    textCapitalization: TextCapitalization.characters,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. AGRIFREESHIP',
                      hintStyle: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                        fontWeight: FontWeight.normal,
                        fontSize: 12.5,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _applyManualPromoCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'REDEEM',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // MAIN BODY CONTAINER (TABS, FILTERS & CARDS)
  // -------------------------------------------------------------
  Widget _buildMainContainer() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1300),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: Modern Pill Tabs + Search
              isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildTabButton('Available', 0),
                              ),
                              Expanded(
                                child: _buildTabButton(
                                  'Claimed (${_claimedVoucherIds.length})',
                                  1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: TextField(
                            onChanged: (val) =>
                                setState(() => _searchQuery = val),
                            style: GoogleFonts.inter(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search promo code or farm...',
                              hintStyle: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.search_rounded,
                                  size: 18, color: Color(0xFF94A3B8)),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 11),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Tabs
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              _buildTabButton('Available Farm Vouchers', 0),
                              _buildTabButton(
                                'My Claimed Wallet (${_claimedVoucherIds.length})',
                                1,
                              ),
                            ],
                          ),
                        ),

                        // Search Box
                        Container(
                          width: 280,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            onChanged: (val) =>
                                setState(() => _searchQuery = val),
                            style: GoogleFonts.inter(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search promo code or farm...',
                              hintStyle: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.search_rounded,
                                  size: 18, color: Color(0xFF94A3B8)),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 11),
                            ),
                          ),
                        ),
                      ],
                    ),

              const SizedBox(height: 24),

              // Category Filter Pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: InkWell(
                        onTap: () => setState(() => _selectedCategory = cat),
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFD97706)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFFE2E8F0),
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFD97706)
                                          .withValues(alpha: 0.25),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            cat,
                            style: GoogleFonts.inter(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF475569),
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 32),

              // Vouchers Grid List
              _buildVouchersGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int tabIndex) {
    final isSelected = _tabController.index == tabIndex;
    return GestureDetector(
      onTap: () {
        setState(() {
          _tabController.animateTo(tabIndex);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? const Color(0xFFD97706)
                : const Color(0xFF64748B),
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // VOUCHER TICKETS GRID (WITH DUAL STUB CUTOUT)
  // -------------------------------------------------------------
  Widget _buildVouchersGrid() {
    final sw = MediaQuery.of(context).size.width;
    final isMyVouchers = _tabController.index == 1;
    final future = isMyVouchers ? _myVouchersFuture : _availableVouchersFuture;

    return FutureBuilder<List<VoucherItem>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF005A36)),
            ),
          );
        }

        // 100% Dynamic Real Data from Supabase
        final allVouchers = snapshot.data ?? [];

        List<VoucherItem> vouchers = [];
        if (isMyVouchers) {
          // Filter to claimed vouchers
          vouchers = allVouchers
              .where((v) =>
                  _claimedVoucherIds.contains(v.id) ||
                  _claimedVoucherIds.contains(v.code) ||
                  v.status == 'available' ||
                  v.status == 'claimed')
              .toList();
        } else {
          vouchers = List.from(allVouchers);
        }

        // Apply Search Filter (by code, title, description, or farm name)
        if (_searchQuery.isNotEmpty) {
          vouchers = vouchers
              .where((v) =>
                  v.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  v.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  (v.farmName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
                  (v.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false))
              .toList();
        }

        if (_selectedCategory.contains('Free Shipping')) {
          vouchers = vouchers
              .where((v) =>
                  v.discountType == 'free_shipping' ||
                  v.title.toLowerCase().contains('shipping') ||
                  v.code.toLowerCase().contains('ship'))
              .toList();
        } else if (_selectedCategory.contains('Fresh Harvest')) {
          vouchers = vouchers
              .where((v) =>
                  v.title.toLowerCase().contains('fresh') ||
                  (v.description?.toLowerCase().contains('produce') ?? false) ||
                  (v.description?.toLowerCase().contains('greens') ?? false))
              .toList();
        } else if (_selectedCategory.contains('Wholesale Bulk')) {
          vouchers = vouchers
              .where((v) =>
                  v.title.toLowerCase().contains('bulk') ||
                  v.title.toLowerCase().contains('wholesale') ||
                  (v.minSpend ?? 0) >= 1000)
              .toList();
        } else if (_selectedCategory.contains('Welcome Gifts')) {
          vouchers = vouchers
              .where((v) =>
                  v.title.toLowerCase().contains('welcome') ||
                  v.code.toLowerCase().contains('welcome'))
              .toList();
        } else if (_selectedCategory.contains('Flash Specials')) {
          vouchers = vouchers
              .where((v) =>
                  v.title.toLowerCase().contains('flash') ||
                  v.code.toLowerCase().contains('flash'))
              .toList();
        }

        if (vouchers.isEmpty) {
          return Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 24),
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF3C7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.confirmation_number_outlined,
                      size: 36,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isMyVouchers
                        ? 'No Claimed Vouchers in Wallet'
                        : 'No Active Farm Vouchers Right Now',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isMyVouchers
                        ? 'Claim vouchers from the Available tab to apply discounts at checkout.'
                        : 'Registered farmers issue custom harvest vouchers here with minimum spend protections.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (isMyVouchers)
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _tabController.animateTo(0);
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Browse Available Vouchers',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }

        int crossAxisCount = sw < 720 ? 1 : (sw < 1200 ? 2 : 3);
        double childAspectRatio = sw < 480
            ? 2.1
            : (sw < 720
                ? 2.3
                : (sw < 1200
                    ? 2.15
                    : 2.2));

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: vouchers.length,
          itemBuilder: (context, index) {
            final voucher = vouchers[index];
            final isClaimed = isMyVouchers ||
                _claimedVoucherIds.contains(voucher.id) ||
                _claimedVoucherIds.contains(voucher.code);
            return _WebTicketStubCard(
              voucher: voucher,
              isClaimed: isClaimed,
              onClaim: () async {
                setState(() {
                  _claimedVoucherIds.add(voucher.id);
                  _claimedVoucherIds.add(voucher.code);
                });

                // Persist claim in Supabase user_vouchers table
                if (voucher.id.isNotEmpty) {
                  SupabaseDataService().claimVoucher(voucher.id);
                }

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Voucher "${voucher.code}" claimed to your wallet!',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: const Color(0xFF059669),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    action: SnackBarAction(
                      label: 'SHOP NOW',
                      textColor: Colors.white,
                      onPressed: () => context.go('/marketplace'),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------
  // HOW IT WORKS 3-STEP SECTION
  // -------------------------------------------------------------
  Widget _buildHowItWorksSection() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    final steps = [
      {
        'step': '01',
        'title': 'Collect Free Tickets',
        'desc': 'Browse active vouchers above and click "CLAIM" to store them in your digital wallet.',
        'icon': Icons.touch_app_rounded,
        'color': const Color(0xFFD97706),
        'bg': const Color(0xFFFEF3C7),
      },
      {
        'step': '02',
        'title': 'Shop Fresh Harvests',
        'desc': 'Add locally grown vegetables, grains, fruits, and wholesale crates to your basket.',
        'icon': Icons.shopping_basket_rounded,
        'color': const Color(0xFF059669),
        'bg': const Color(0xFFD1FAE5),
      },
      {
        'step': '03',
        'title': 'Auto-Apply at Checkout',
        'desc': 'Select your preferred voucher at checkout and watch the price drop immediately.',
        'icon': Icons.savings_rounded,
        'color': const Color(0xFF2563EB),
        'bg': const Color(0xFFDBEAFE),
      },
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1300),
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
          padding: EdgeInsets.all(isMobile ? 24 : 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'SIMPLE 3-STEP SAVINGS',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF78350F),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'How Voucher Discounts Work',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: isMobile ? 20 : 26,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Maximizing your agricultural budget has never been easier.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: isMobile ? 13 : 14,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 32),
              isMobile
                  ? Column(
                      children: steps.map((s) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: s['bg'] as Color,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  s['icon'] as IconData,
                                  color: s['color'] as Color,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          s['title'] as String,
                                          style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF1E293B),
                                          ),
                                        ),
                                        Text(
                                          s['step'] as String,
                                          style: GoogleFonts.poppins(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFFCBD5E1),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      s['desc'] as String,
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        color: const Color(0xFF64748B),
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    )
                  : Row(
                      children: steps.map((s) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: s['bg'] as Color,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        s['icon'] as IconData,
                                        color: s['color'] as Color,
                                        size: 28,
                                      ),
                                    ),
                                    Text(
                                      s['step'] as String,
                                      style: GoogleFonts.poppins(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  s['title'] as String,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  s['desc'] as String,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: const Color(0xFF64748B),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // FAQ SECTION
  // -------------------------------------------------------------
  Widget _buildFaqSection() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    final faqs = [
      {
        'q': 'Can I stack multiple discount vouchers in one order?',
        'a': 'Yes! You can combine one Free Shipping voucher with one Store Discount or Wholesale voucher at checkout.'
      },
      {
        'q': 'Do vouchers expire if I claim them today?',
        'a': 'Each voucher has a specific expiry countdown displayed on its ticket. Make sure to place your order before the deadline.'
      },
      {
        'q': 'How do I use a promo code given by a specific farmer?',
        'a': 'Enter the secret code in the "Have a Promo Code?" redeem bar in the hero section above to immediately credit it.'
      },
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1300),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Frequently Asked Questions',
                style: GoogleFonts.poppins(
                  fontSize: isMobile ? 19 : 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              ...faqs.map((faq) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(isMobile ? 16 : 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.help_outline_rounded,
                                size: 18, color: Color(0xFFD97706)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              faq['q']!,
                              style: GoogleFonts.poppins(
                                fontSize: isMobile ? 13.5 : 15,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 28),
                        child: Text(
                          faq['a']!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// DUAL-TONE TICKET STUB WIDGET (PREMIUM HARVEST TICKET)
// -------------------------------------------------------------
class _WebTicketStubCard extends StatefulWidget {
  final VoucherItem voucher;
  final bool isClaimed;
  final VoidCallback onClaim;

  const _WebTicketStubCard({
    required this.voucher,
    required this.isClaimed,
    required this.onClaim,
  });

  @override
  State<_WebTicketStubCard> createState() => _WebTicketStubCardState();
}

class _WebTicketStubCardState extends State<_WebTicketStubCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    final v = widget.voucher;
    final bool isFreeShipping = v.discountType == 'free_shipping' ||
        v.title.toLowerCase().contains('shipping') ||
        v.title.toLowerCase().contains('delivery') ||
        v.code.toLowerCase().contains('ship');

    final bool isFlat = v.discountType == 'flat';

    final String discountMain = isFreeShipping
        ? 'FREE'
        : (isFlat
            ? '₱${(v.discountPercentage ?? 50).toInt()}'
            : (v.discountPercentage != null
                ? '${v.discountPercentage!.toInt()}%'
                : '₱50'));
    final String discountSub = isFreeShipping
        ? 'DELIVERY'
        : (isFlat ? 'DISCOUNT' : 'OFF HARVEST');

    // Rich themed gradients
    final List<Color> stubGradient = isFreeShipping
        ? const [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)]
        : (isFlat
            ? const [Color(0xFF9A3412), Color(0xFFC2410C), Color(0xFFEA580C)]
            : const [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF059669)]);

    final Color accentColor = stubGradient[1];

    final String minSpendStr = v.minSpend != null && v.minSpend! > 0
        ? 'Min. Spend ₱${v.minSpend!.toInt()}'
        : 'No Minimum';
    final String validUntilStr = v.validUntil != null
        ? DateFormat('MMM dd, yyyy').format(v.validUntil!)
        : 'Valid Season';

    final String farmDisplay = (v.farmName != null && v.farmName!.trim().isNotEmpty)
        ? v.farmName!
        : 'Local Partner Farm';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _isHovered ? -6 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? accentColor.withValues(alpha: 0.22)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: _isHovered ? 28 : 14,
              offset: Offset(0, _isHovered ? 10 : 5),
            ),
          ],
          border: Border.all(
            color: _isHovered
                ? accentColor.withValues(alpha: 0.45)
                : const Color(0xFFE2E8F0),
            width: _isHovered ? 1.5 : 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Stack(
            children: [
              Row(
                children: [
                  // ── LEFT STUB ──────────────────────────
                  Container(
                    width: isMobile ? 100 : 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: stubGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Watermark icon in background
                        Positioned(
                          right: -12,
                          bottom: -12,
                          child: Icon(
                            isFreeShipping
                                ? Icons.local_shipping_rounded
                                : (isFlat
                                    ? Icons.local_offer_rounded
                                    : Icons.eco_rounded),
                            size: 70,
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isFreeShipping
                                      ? Icons.local_shipping_rounded
                                      : (isFlat
                                          ? Icons.local_offer_rounded
                                          : Icons.percent_rounded),
                                  color: Colors.white,
                                  size: isMobile ? 18 : 22,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                discountMain,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: isMobile ? 20 : 24,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                discountSub,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: isMobile ? 9 : 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── DASHED SEPARATOR ───────────────────
                  CustomPaint(
                    size: const Size(1, double.infinity),
                    painter: _DashedLinePainter(color: const Color(0xFFCBD5E1)),
                  ),

                  // ── RIGHT TICKET BODY ──────────────────
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 16,
                        vertical: isMobile ? 10 : 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top: Farm Provenance & Code Pill
                          Row(
                            children: [
                              // Farm Avatar with real photo or initial badge
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF005A36)
                                      .withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF005A36)
                                        .withValues(alpha: 0.25),
                                    width: 1.2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: v.farmerAvatarUrl != null &&
                                          v.farmerAvatarUrl!.trim().isNotEmpty
                                      ? Image.network(
                                          v.farmerAvatarUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            debugPrint('⚠️ Voucher Card: Error loading avatar (${v.farmerAvatarUrl}): $error');
                                            return Center(
                                              child: Text(
                                                farmDisplay.isNotEmpty
                                                    ? farmDisplay[0].toUpperCase()
                                                    : 'F',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: const Color(0xFF005A36),
                                                ),
                                              ),
                                            );
                                          },
                                        )
                                      : Center(
                                          child: Text(
                                            farmDisplay.isNotEmpty
                                                ? farmDisplay[0].toUpperCase()
                                                : 'F',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF005A36),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        farmDisplay,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF005A36),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.verified_rounded,
                                      size: 14,
                                      color: Color(0xFF059669),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Code chip with copy action
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: v.code));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Copied code "${v.code}"!'),
                                      duration: const Duration(seconds: 1),
                                      behavior: SnackBarBehavior.floating,
                                      margin: const EdgeInsets.all(16),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        v.code,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 10,
                                          color: const Color(0xFF334155),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.copy_rounded,
                                          size: 11, color: Color(0xFF64748B)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Title
                          Text(
                            v.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: isMobile ? 13 : 14.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),

                          // Rules: Min Spend & Expiry
                          Row(
                            children: [
                              Icon(Icons.shopping_bag_outlined,
                                  size: 13, color: const Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  minSpendStr,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF475569),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.access_time_rounded,
                                  size: 13, color: const Color(0xFF94A3B8)),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  validUntilStr,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Bottom Row: Status / Claim Action
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isFreeShipping
                                      ? '⚡ Instant Subsidy'
                                      : '🌾 Farm Funded',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                              widget.isClaimed
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: const Color(0xFF10B981)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.check_circle_rounded,
                                              size: 14,
                                              color: Color(0xFF059669)),
                                          const SizedBox(width: 5),
                                          Text(
                                            'CLAIMED',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 11,
                                              color: const Color(0xFF059669),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ElevatedButton(
                                      onPressed: widget.onClaim,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF005A36),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        textStyle: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                      child: const Text('CLAIM TICKET'),
                                    ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ── TICKET NOTCH CUTOUTS (Top & Bottom) ──
              Positioned(
                left: (isMobile ? 100 : 120) - 7,
                top: -8,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFBFBFB), // matches scaffold background
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: (isMobile ? 100 : 120) - 7,
                bottom: -8,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFBFBFB), // matches scaffold background
                    shape: BoxShape.circle,
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

// -------------------------------------------------------------
// DASHED LINE PAINTER FOR TICKET STUB PERFORATION
// -------------------------------------------------------------
class _DashedLinePainter extends CustomPainter {
  final Color color;

  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    const dashHeight = 4.0;
    const dashSpace = 3.0;
    double startY = 8.0;

    while (startY < size.height - 8.0) {
      canvas.drawLine(
        Offset(0, startY),
        Offset(0, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
