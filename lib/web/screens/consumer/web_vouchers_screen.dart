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
    _availableVouchersFuture =
        SupabaseDataService().getAvailablePlatformVouchers();
    _myVouchersFuture = SupabaseDataService().getUserVouchers('available');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _promoInputController.dispose();
    super.dispose();
  }

  List<VoucherItem> _getCuratedVouchers() {
    final now = DateTime.now();
    return [
      VoucherItem(
        id: 'curated_1',
        code: 'AGRIFREESHIP',
        title: 'Zero Shipping Fee Sitewide',
        description: 'Enjoy 100% free delivery on farm orders above ₱350.',
        discountPercentage: 100,
        minSpend: 350,
        validUntil: now.add(const Duration(days: 7)),
        status: 'available',
      ),
      VoucherItem(
        id: 'curated_2',
        code: 'HARVEST25',
        title: '25% OFF Fresh Greens & Produce',
        description: 'Direct discount on all leafy vegetables and root crops.',
        discountPercentage: 25,
        minSpend: 200,
        validUntil: now.add(const Duration(days: 4)),
        status: 'available',
      ),
      VoucherItem(
        id: 'curated_3',
        code: 'BULKDIRECT100',
        title: '₱100 OFF Wholesale Crates',
        description: 'Exclusive volume savings for bulk buyers & resellers.',
        discountPercentage: 15,
        minSpend: 1200,
        validUntil: now.add(const Duration(days: 14)),
        status: 'available',
      ),
      VoucherItem(
        id: 'curated_4',
        code: 'WELCOMEAGRI',
        title: '20% OFF First Farm Order',
        description: 'Welcome reward for new buyers supporting local farmers.',
        discountPercentage: 20,
        minSpend: 150,
        validUntil: now.add(const Duration(days: 30)),
        status: 'available',
      ),
      VoucherItem(
        id: 'curated_5',
        code: 'ORGANICVIP',
        title: '30% OFF Certified Organic Hub',
        description: 'Valid for pesticide-free harvests and specialty heirloom grains.',
        discountPercentage: 30,
        minSpend: 500,
        validUntil: now.add(const Duration(days: 10)),
        status: 'available',
      ),
      VoucherItem(
        id: 'curated_6',
        code: 'FLASHDEAL50',
        title: '₱50 Instant Cashback Voucher',
        description: 'Applicable to any instant flash sale items today.',
        discountPercentage: 10,
        minSpend: 300,
        validUntil: now.add(const Duration(days: 2)),
        status: 'available',
      ),
    ];
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
            Text('Promo code "$code" claimed and added to your wallet!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: const Color(0xFFD97706),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(24),
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
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Navigation / Back button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () => context.pop(),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
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
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Back to Marketplace',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_rounded,
                                  color: Color(0xFFFDE68A), size: 16),
                              const SizedBox(width: 6),
                              Text(
                                '100% Direct Farm Subsidy Vouchers',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),

                    // Hero Headline & Promo Input Bar
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
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
                                        size: 14, color: Color(0xFF78350F)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'VOUCHER VAULT · EXCLUSIVE HARVEST SAVINGS',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF78350F),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Voucher & Rewards Hub',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 42,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                'Claim Instant Discounts 🏷️',
                                style: GoogleFonts.playfairDisplay(
                                  color: const Color(0xFFFDE68A),
                                  fontSize: 48,
                                  fontWeight: FontWeight.w700,
                                  fontStyle: FontStyle.italic,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 14),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 620),
                                child: Text(
                                  'Collect free delivery coupons, seasonal harvest discounts, and bulk seller allowances. Apply vouchers seamlessly at checkout.',
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 15,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (MediaQuery.of(context).size.width > 900) ...[
                          const SizedBox(width: 48),
                          // Interactive Promo Redeem Card
                          Container(
                            width: 360,
                            padding: const EdgeInsets.all(24),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 46,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: TextField(
                                          controller: _promoInputController,
                                          textCapitalization:
                                              TextCapitalization.characters,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.0,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'e.g. AGRI2026',
                                            hintStyle: GoogleFonts.inter(
                                              color: const Color(0xFF94A3B8),
                                              fontWeight: FontWeight.normal,
                                              fontSize: 13,
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 14),
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
                                            horizontal: 18, vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
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
                          ),
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

  // -------------------------------------------------------------
  // MAIN BODY CONTAINER (TABS, FILTERS & CARDS)
  // -------------------------------------------------------------
  Widget _buildMainContainer() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1300),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: Modern Pill Tabs + Search
              Row(
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
                        _buildTabButton('Available Vouchers', 0),
                        _buildTabButton('My Claimed Wallet', 1),
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
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search promo code...',
                        hintStyle: GoogleFonts.inter(
                            fontSize: 13, color: const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded,
                            size: 18, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 11),
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
    final isMyVouchers = _tabController.index == 1;
    final future = isMyVouchers ? _myVouchersFuture : _availableVouchersFuture;

    return FutureBuilder<List<VoucherItem>>(
      future: future,
      builder: (context, snapshot) {
        List<VoucherItem> vouchers = [];

        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          vouchers = snapshot.data!;
        } else {
          // If Supabase returns empty, display curated platform vouchers so UI is never blank
          vouchers = _getCuratedVouchers();
        }

        // Apply Search & Category Filter
        if (_searchQuery.isNotEmpty) {
          vouchers = vouchers
              .where((v) =>
                  v.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  v.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  (v.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false))
              .toList();
        }

        if (_selectedCategory.contains('Free Shipping')) {
          vouchers = vouchers
              .where((v) =>
                  v.title.toLowerCase().contains('shipping') ||
                  v.code.toLowerCase().contains('ship'))
              .toList();
        } else if (_selectedCategory.contains('Fresh Harvest')) {
          vouchers = vouchers
              .where((v) =>
                  v.title.toLowerCase().contains('fresh') ||
                  (v.description?.toLowerCase().contains('produce') ?? false))
              .toList();
        } else if (_selectedCategory.contains('Wholesale Bulk')) {
          vouchers = vouchers
              .where((v) =>
                  v.title.toLowerCase().contains('bulk') ||
                  v.title.toLowerCase().contains('wholesale') ||
                  (v.minSpend ?? 0) >= 1000)
              .toList();
        }

        final sw = MediaQuery.of(context).size.width;
        int crossAxisCount = sw < 768 ? 1 : (sw < 1200 ? 2 : 3);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            childAspectRatio: 2.3,
          ),
          itemCount: vouchers.length,
          itemBuilder: (context, index) {
            final voucher = vouchers[index];
            final isClaimed = isMyVouchers || _claimedVoucherIds.contains(voucher.id) || _claimedVoucherIds.contains(voucher.code);
            return _WebTicketStubCard(
              voucher: voucher,
              isClaimed: isClaimed,
              onClaim: () {
                setState(() {
                  _claimedVoucherIds.add(voucher.id);
                  _claimedVoucherIds.add(voucher.code);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Text('Voucher "${voucher.code}" claimed to your wallet!',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    backgroundColor: const Color(0xFF059669),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(24),
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
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(40),
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
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Maximizing your agricultural budget has never been easier.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 40),
              Row(
                children: steps.map((s) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Frequently Asked Questions',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              ...faqs.map((faq) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.help_outline_rounded,
                              size: 18, color: Color(0xFFD97706)),
                          const SizedBox(width: 10),
                          Text(
                            faq['q']!,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
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
// DUAL-TONE TICKET STUB WIDGET
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
    final v = widget.voucher;
    final bool isFreeShipping = v.title.toLowerCase().contains('shipping') ||
        v.title.toLowerCase().contains('delivery') ||
        v.code.toLowerCase().contains('ship');

    final String discountMain = isFreeShipping
        ? 'FREE'
        : (v.discountPercentage != null
            ? '${v.discountPercentage!.toInt()}%'
            : '₱50');
    final String discountSub = isFreeShipping ? 'DELIVERY' : 'DISCOUNT';

    final Color stubGradientStart =
        isFreeShipping ? const Color(0xFF047857) : const Color(0xFFB45309);
    final Color stubGradientEnd =
        isFreeShipping ? const Color(0xFF059669) : const Color(0xFFD97706);

    final String minSpendStr =
        v.minSpend != null && v.minSpend! > 0 ? 'Min. Spend ₱${v.minSpend!.toInt()}' : 'No Min. Spend';
    final String validUntilStr = v.validUntil != null
        ? DateFormat('MMM dd, yyyy').format(v.validUntil!)
        : 'Valid for 7 days';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, _isHovered ? -5 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? stubGradientStart.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: _isHovered ? 24 : 12,
              offset: Offset(0, _isHovered ? 8 : 4),
            ),
          ],
          border: Border.all(
            color: _isHovered
                ? stubGradientStart.withValues(alpha: 0.4)
                : const Color(0xFFF1F5F9),
            width: _isHovered ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Left Stub: Discount value
            Container(
              width: 110,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(17)),
                gradient: LinearGradient(
                  colors: [stubGradientStart, stubGradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isFreeShipping
                        ? Icons.local_shipping_rounded
                        : Icons.local_offer_rounded,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 26,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    discountMain,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    discountSub,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.85),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),

            // Dashed vertical separator
            CustomPaint(
              size: const Size(1, double.infinity),
              painter: _DashedLinePainter(color: const Color(0xFFE2E8F0)),
            ),

            // Right Content Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Code + Copy button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            v.code,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              color: const Color(0xFF1E293B),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: v.code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Copied "${v.code}" to clipboard!'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          child: const Icon(Icons.copy_rounded,
                              size: 15, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),

                    // Title
                    Text(
                      v.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),

                    // Rules & Min spend
                    Row(
                      children: [
                        Text(
                          minSpendStr,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('•',
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 10)),
                        const SizedBox(width: 6),
                        Text(
                          validUntilStr,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),

                    // Action Button
                    Align(
                      alignment: Alignment.centerRight,
                      child: widget.isClaimed
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFF10B981)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_rounded,
                                      size: 14, color: Color(0xFF059669)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'CLAIMED',
                                    style: GoogleFonts.inter(
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
                                backgroundColor: stubGradientStart,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                minimumSize: const Size(70, 30),
                              ),
                              child: Text(
                                'CLAIM',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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

  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const dashHeight = 4.0;
    const dashSpace = 3.0;
    double startY = 0.0;

    while (startY < size.height) {
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
