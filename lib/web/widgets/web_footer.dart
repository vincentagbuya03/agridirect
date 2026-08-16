import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../shared/router/app_routes.dart';
import '../../shared/widgets/brand_logo.dart';
import 'animated_components.dart';

/// Universal Lush Green Agricultural Web Footer for AgriDirect
class AgriDirectWebFooter extends StatelessWidget {
  const AgriDirectWebFooter({super.key});

  void _showInfoModal(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFF005A36),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
                    ),
                  ),
                ),
                // Footer
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius:
                        const BorderRadius.vertical(bottom: Radius.circular(24)),
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF005A36),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        child: const Text('Got it'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTermsModal(BuildContext context) {
    _showInfoModal(
      context,
      title: 'Terms & Conditions',
      subtitle: 'Platform rules and seller-consumer agreements',
      icon: Icons.gavel_rounded,
      children: [
        _modalSection(
          '1. Acceptance of Terms',
          'By using AgriDirect, consumers, agricultural enterprises, and verified growers agree to abide by all platform rules and Department of Agriculture fair-trade guidelines.',
        ),
        _modalSection(
          '2. Farmer & Seller Integrity',
          'Registered growers must supply authentic harvest origin information, accurate weight measurements, and certified quality standard compliance. False origin claims result in immediate account de-listing.',
        ),
        _modalSection(
          '3. Orders, Pricing & Pre-Orders',
          'Prices are transparent direct-from-farm rates without middleman surcharges. Pre-orders represent forward contracts fulfilled upon scheduled crop harvesting.',
        ),
        _modalSection(
          '4. Cancellation & Quality Disputes',
          'Quality disputes submitted within 24 hours of delivery with photographic evidence are eligible for prompt replacement or instant digital wallet refunds.',
        ),
      ],
    );
  }

  void _showPrivacyModal(BuildContext context) {
    _showInfoModal(
      context,
      title: 'Privacy Policy',
      subtitle: 'Data protection and privacy compliance (RA 10173)',
      icon: Icons.shield_outlined,
      children: [
        _modalSection(
          '1. Information We Collect',
          'We collect account credentials, contact numbers, and delivery addresses strictly to execute orders, coordinate farmer pickups, and issue official digital receipts.',
        ),
        _modalSection(
          '2. Farm Location & GPS Privacy',
          'Farm coordinate mapping is utilized to compute direct delivery routes and optimize consolidated logistics clusters across Pangasinan.',
        ),
        _modalSection(
          '3. Third-Party Sharing',
          'AgriDirect never sells or rents personal data. Information is only shared with verified logistics couriers to complete active customer deliveries.',
        ),
        _modalSection(
          '4. Data Security & Storage',
          'All communication and payment logs are encrypted end-to-end via secure SSL protocols and stored in compliant cloud infrastructure.',
        ),
      ],
    );
  }

  void _showCookieModal(BuildContext context) {
    _showInfoModal(
      context,
      title: 'Cookie & Storage Policy',
      subtitle: 'Session persistence and preference management',
      icon: Icons.cookie_outlined,
      children: [
        _modalSection(
          '1. Purpose of Local Storage',
          'AgriDirect stores authentication tokens and shopping cart items locally on your device to maintain your session across browser tabs.',
        ),
        _modalSection(
          '2. Managing Preferences',
          'You may clear your browser cookies and storage at any time through standard browser privacy settings.',
        ),
      ],
    );
  }

  void _showDeliveryLogisticsModal(BuildContext context) {
    _showInfoModal(
      context,
      title: 'Delivery & Logistics',
      subtitle: 'Cold-chain dispatch & same-day harvest fulfillment',
      icon: Icons.local_shipping_outlined,
      children: [
        _modalSection(
          '1. Direct-from-Farm Dispatch',
          'Orders are harvested in early morning hours and brought to localized consolidation hubs in San Carlos City before dispatch.',
        ),
        _modalSection(
          '2. Delivery Zones & Lead Times',
          'Local deliveries within San Carlos City and nearby Pangasinan municipalities are completed within 2–6 hours of morning harvest dispatch.',
        ),
        _modalSection(
          '3. Real-Time Order Tracking',
          'Track your produce from farm packing to doorstep through the active order status dashboard.',
        ),
      ],
    );
  }

  void _showProduceGuaranteeModal(BuildContext context) {
    _showInfoModal(
      context,
      title: '100% Produce Guarantee',
      subtitle: 'Freshness, authenticity & customer assurance',
      icon: Icons.verified_outlined,
      children: [
        _modalSection(
          '1. 100% Farm-Fresh Guarantee',
          'All vegetables, fruits, and grains are harvested directly from verified local farms with documented harvest dates.',
        ),
        _modalSection(
          '2. Hassle-Free 24-Hour Refunds',
          'If any delivered crop does not meet acceptable freshness standards, upload a photo within 24 hours for an instant replacement or full credit refund.',
        ),
        _modalSection(
          '3. Certified Provenance',
          'Every crate contains batch provenance tracing back to the specific farmer and municipal agrarian cooperative.',
        ),
      ],
    );
  }

  void _showDAStandardsModal(BuildContext context) {
    _showInfoModal(
      context,
      title: 'DA Quality Standards & GAP',
      subtitle: 'Department of Agriculture safety & quality certification',
      icon: Icons.verified_user_outlined,
      children: [
        _modalSection(
          '1. Philippine Good Agricultural Practices (PhilGAP)',
          'All accredited farmers adhere to PhilGAP protocols covering soil testing, clean irrigation water sources, and biological pest management.',
        ),
        _modalSection(
          '2. Safe Chemical Withdrawal Periods',
          'Zero synthetic chemical applications within pre-harvest withdrawal windows, ensuring safe produce for every household.',
        ),
        _modalSection(
          '3. Grading & Sorting Standards',
          'Produce is graded into Premium Table Grade, Commercial Grade, and Processing Grade according to BAFS official agricultural specifications.',
        ),
      ],
    );
  }

  void _showFarmerAssistanceModal(BuildContext context) {
    _showInfoModal(
      context,
      title: 'DA Farmer Assistance Program',
      subtitle: 'Agrarian technical support, grants & subsidy linkage',
      icon: Icons.agriculture_rounded,
      children: [
        _modalSection(
          '1. Certified Seed & Seedling Subsidies',
          'Registered smallholders access high-yield vegetable seeds, inbred rice varieties, and organic bio-fertilizer allocations.',
        ),
        _modalSection(
          '2. Free Soil pH & Nutrient Testing',
          'Coordinate with the municipal agriculture desk for free laboratory soil testing and custom fertilizer recommendations.',
        ),
        _modalSection(
          '3. Crop Insurance Linkage (PCIC)',
          'Direct integration with Philippine Crop Insurance Corporation (PCIC) for automated flood, drought, and pest indemnification.',
        ),
        _modalSection(
          '4. Technical Agronomy Hotline',
          'Reach municipal agricultural technologists at (075) 955-5929 for immediate field diagnosis and pest management advice.',
        ),
      ],
    );
  }

  static Widget _modalSection(String heading, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF475569),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 800;

    return Container(
      width: double.infinity,
      color: const Color(0xFF005A36),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 64,
        vertical: isMobile ? 48 : 72,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1300),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBrandColumn(context),
                    const SizedBox(height: 36),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildFooterSection('MORE', [
                            _FooterAction('Home', () => context.go('/')),
                            _FooterAction(
                              'About Us',
                              () => context.go('/about-us'),
                            ),
                            _FooterAction(
                              'Blog & DA Articles',
                              () => context.go('/articles'),
                            ),
                            _FooterAction(
                              'Start Selling',
                              () => context.go('/register'),
                            ),
                            _FooterAction(
                              'Farmer Assistance',
                              () => _showFarmerAssistanceModal(context),
                            ),
                          ]),
                        ),
                        Expanded(
                          child: _buildFooterSection('SHOP', [
                            _FooterAction(
                              'Farm Equipment',
                              () => context.go('/shop?category=Equipment'),
                            ),
                            _FooterAction(
                              'Fresh Vegetables',
                              () => context.go(AppRoutes.freshProduce),
                            ),
                            _FooterAction(
                              'Seasonal Pre-Orders',
                              () => context.go(AppRoutes.preorders),
                            ),
                            _FooterAction(
                              'Flash Deals',
                              () => context.go(AppRoutes.flashSale),
                            ),
                            _FooterAction(
                              'Wholesale Produce',
                              () => context.go(AppRoutes.wholesale),
                            ),
                          ]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _buildFooterSection('ORDERING & POLICIES', [
                      _FooterAction(
                        'Terms & Conditions',
                        () => _showTermsModal(context),
                      ),
                      _FooterAction(
                        'Privacy Policy',
                        () => _showPrivacyModal(context),
                      ),
                      _FooterAction(
                        'Delivery & Logistics',
                        () => _showDeliveryLogisticsModal(context),
                      ),
                      _FooterAction(
                        'Produce Guarantee',
                        () => _showProduceGuaranteeModal(context),
                      ),
                      _FooterAction(
                        'DA Standards',
                        () => _showDAStandardsModal(context),
                      ),
                    ]),
                    const SizedBox(height: 28),
                    _buildContactSection(context),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand & Certification
                    Expanded(flex: 3, child: _buildBrandColumn(context)),
                    const SizedBox(width: 48),
                    // MORE
                    Expanded(
                      flex: 2,
                      child: _buildFooterSection('MORE', [
                        _FooterAction('Home', () => context.go('/')),
                        _FooterAction(
                          'About Us',
                          () => context.go('/about-us'),
                        ),
                        _FooterAction(
                          'Blog & DA Articles',
                          () => context.go('/articles'),
                        ),
                        _FooterAction(
                          'Start Selling',
                          () => context.go('/register'),
                        ),
                        _FooterAction(
                          'Farmer Assistance',
                          () => _showFarmerAssistanceModal(context),
                        ),
                        _FooterAction(
                          'Reviews & Stories',
                          () => context.go('/community'),
                        ),
                      ]),
                    ),
                    // SHOP
                    Expanded(
                      flex: 2,
                      child: _buildFooterSection('SHOP', [
                        _FooterAction(
                          'Farm Equipment',
                          () => context.go('/shop?category=Equipment'),
                        ),
                        _FooterAction(
                          'Fresh Vegetables',
                          () => context.go(AppRoutes.freshProduce),
                        ),
                        _FooterAction(
                          'Seasonal Pre-Orders',
                          () => context.go(AppRoutes.preorders),
                        ),
                        _FooterAction(
                          'Flash Harvest Deals',
                          () => context.go(AppRoutes.flashSale),
                        ),
                        _FooterAction(
                          'Wholesale Produce',
                          () => context.go(AppRoutes.wholesale),
                        ),
                        _FooterAction(
                          'Local Farm Shops',
                          () => context.go(AppRoutes.localShops),
                        ),
                      ]),
                    ),
                    // ORDERING
                    Expanded(
                      flex: 2,
                      child: _buildFooterSection('ORDERING', [
                        _FooterAction(
                          'Terms & Conditions',
                          () => _showTermsModal(context),
                        ),
                        _FooterAction(
                          'Privacy Policy',
                          () => _showPrivacyModal(context),
                        ),
                        _FooterAction(
                          'Delivery & Logistics',
                          () => _showDeliveryLogisticsModal(context),
                        ),
                        _FooterAction(
                          'Produce Guarantee',
                          () => _showProduceGuaranteeModal(context),
                        ),
                        _FooterAction(
                          'DA Standards',
                          () => _showDAStandardsModal(context),
                        ),
                      ]),
                    ),
                    // CONTACT
                    Expanded(flex: 3, child: _buildContactSection(context)),
                  ],
                ),

              const SizedBox(height: 48),
              const Divider(color: Colors.white24),
              const SizedBox(height: 20),

              // Bottom Line
              isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '© 2026 AgriDirect Inc. In partnership with Department of Agriculture (DA) & Agrarian Reform Beneficiaries.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            _buildBottomLink(
                              context,
                              'Privacy Policy',
                              () => _showPrivacyModal(context),
                            ),
                            _buildBottomLink(
                              context,
                              'Terms of Service',
                              () => _showTermsModal(context),
                            ),
                            _buildBottomLink(
                              context,
                              'Cookie Policy',
                              () => _showCookieModal(context),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '© 2026 AgriDirect Inc. In partnership with Department of Agriculture (DA) & Agrarian Reform Beneficiaries.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        Row(
                          children: [
                            _buildBottomLink(
                              context,
                              'Privacy Policy',
                              () => _showPrivacyModal(context),
                            ),
                            const SizedBox(width: 20),
                            _buildBottomLink(
                              context,
                              'Terms of Service',
                              () => _showTermsModal(context),
                            ),
                            const SizedBox(width: 20),
                            _buildBottomLink(
                              context,
                              'Cookie Policy',
                              () => _showCookieModal(context),
                            ),
                          ],
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BrandLogo(size: BrandLogoSize.medium, inverted: true),
        const SizedBox(height: 18),
        // Accreditation Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_user_rounded,
                color: AgriColors.lime300,
                size: 20,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DA Certified & Fair Trade Operator',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Verified Agrarian Partner',
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Connecting certified local farmers directly to your kitchen and enterprise for fair prices and sustainable agriculture.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.8),
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildFooterSection(String title, List<_FooterAction> actions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        ...actions.map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: a.onTap,
                child: Text(
                  a.title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AGRICULTURE HUB & CONTACT',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.location_on_rounded,
              color: AgriColors.lime300,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Department of Agriculture (DA)',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'San Carlos City, Pangasinan 2420, Philippines',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.pin_drop_rounded,
              color: AgriColors.lime300,
              size: 15,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Plus Code: W8VM+QW8, San Carlos City, Pangasinan',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AgriColors.lime300,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.phone_rounded,
              color: AgriColors.lime300,
              size: 15,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'P: (075) 955-5929 / (075) 600-1432\nE: noreplyagridirect@gmail.com',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Social Media Icons
        Row(
          children: [
            _socialIcon(
              context: context,
              icon: Icons.camera_alt_outlined,
              tooltip: 'Instagram',
              onTap: () {
                Clipboard.setData(
                    const ClipboardData(text: '@agridirect.ph'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'AgriDirect Instagram handle (@agridirect.ph) copied!'),
                    backgroundColor: Color(0xFF005A36),
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
            _socialIcon(
              context: context,
              icon: Icons.share_rounded,
              tooltip: 'Share AgriDirect',
              onTap: () {
                Clipboard.setData(
                    const ClipboardData(text: 'https://agridirect.ph'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('AgriDirect link copied to clipboard!'),
                    backgroundColor: Color(0xFF005A36),
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
            _socialIcon(
              context: context,
              icon: Icons.facebook_rounded,
              tooltip: 'Facebook',
              onTap: () {
                Clipboard.setData(const ClipboardData(
                    text: 'https://facebook.com/AgriDirectPH'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Official Facebook page link copied!'),
                    backgroundColor: Color(0xFF005A36),
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
            _socialIcon(
              context: context,
              icon: Icons.language_rounded,
              tooltip: 'Official Portal',
              onTap: () {
                _showInfoModal(
                  context,
                  title: 'Department of Agriculture Portal',
                  subtitle: 'Official agricultural resources & extension services',
                  icon: Icons.language_rounded,
                  children: [
                    _modalSection(
                      'National DA Portal',
                      'Visit https://da.gov.ph for nationwide agricultural statistics, fertilizer voucher monitoring, and trade policies.',
                    ),
                    _modalSection(
                      'San Carlos City Agriculture Office',
                      'Located at W8VM+QW8, San Carlos City, Pangasinan 2420, Philippines. In-person extension services available Monday–Friday, 8:00 AM – 5:00 PM.',
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomLink(
    BuildContext context,
    String text,
    VoidCallback onTap,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          text,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
        ),
      ),
    );
  }

  Widget _socialIcon({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _FooterAction {
  final String title;
  final VoidCallback onTap;
  const _FooterAction(this.title, this.onTap);
}
