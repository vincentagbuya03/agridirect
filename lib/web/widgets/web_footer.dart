import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../shared/router/app_routes.dart';
import '../../shared/widgets/brand_logo.dart';
import 'animated_components.dart';

/// Universal Lush Green Agricultural Web Footer for AgriDirect
class AgriDirectWebFooter extends StatelessWidget {
  const AgriDirectWebFooter({super.key});

  static const String _privacyPolicyText =
      'At AgriDirect, we value your privacy. We collect basic account details (name, email, phone) to facilitate purchases and connect you with local farmers. We never share your data with third parties without your consent. By using the app, you agree to our standard data handling procedures.';
  static const String _termsOfServiceText =
      'Welcome to AgriDirect. By registering as a consumer or farmer, you agree to comply with our community guidelines. Farmers must supply authentic information and fresh, high-quality produce. Customers must complete transaction payments in good faith.';
  static const String _cookiePolicyText =
      'AgriDirect uses cookies to enhance your browsing experience, store session parameters, and analyze site metrics. Cookies are stored locally on your device and can be managed through your browser settings at any time.';

  void _showPolicyModal(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Text(
              content,
              style: GoogleFonts.inter(
                  fontSize: 13, height: 1.6, color: Colors.grey[800]),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
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
                          child: _buildFooterSection(
                            'MORE',
                            [
                              _FooterAction('Home', () => context.go('/')),
                              _FooterAction(
                                  'About Us', () => context.go('/about-us')),
                              _FooterAction('Blog & DA Articles',
                                  () => context.go('/articles')),
                              _FooterAction('Start Selling',
                                  () => context.go('/register')),
                              _FooterAction('Farmer Assistance',
                                  () => context.go('/about-us')),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _buildFooterSection(
                            'SHOP',
                            [
                              _FooterAction('Farm Equipment',
                                  () => context.go(AppRoutes.shop)),
                              _FooterAction('Fresh Vegetables',
                                  () => context.go(AppRoutes.freshProduce)),
                              _FooterAction('Seasonal Pre-Orders',
                                  () => context.go('/shop?mode=preorders')),
                              _FooterAction('Flash Deals',
                                  () => context.go(AppRoutes.flashSale)),
                              _FooterAction('Wholesale Produce',
                                  () => context.go(AppRoutes.wholesale)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _buildFooterSection(
                      'ORDERING & POLICIES',
                      [
                        _FooterAction(
                            'Terms & Conditions',
                            () => _showPolicyModal(context,
                                'Terms of Service', _termsOfServiceText)),
                        _FooterAction(
                            'Privacy Policy',
                            () => _showPolicyModal(context, 'Privacy Policy',
                                _privacyPolicyText)),
                        _FooterAction('Delivery & Logistics',
                            () => context.go('/about-us')),
                        _FooterAction('Produce Guarantee',
                            () => context.go('/about-us')),
                        _FooterAction('DA Standards',
                            () => context.go('/articles')),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _buildContactSection(context),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand & Certification
                    Expanded(
                      flex: 3,
                      child: _buildBrandColumn(context),
                    ),
                    const SizedBox(width: 48),
                    // MORE
                    Expanded(
                      flex: 2,
                      child: _buildFooterSection(
                        'MORE',
                        [
                          _FooterAction('Home', () => context.go('/')),
                          _FooterAction(
                              'About Us', () => context.go('/about-us')),
                          _FooterAction('Blog & DA Articles',
                              () => context.go('/articles')),
                          _FooterAction('Start Selling',
                              () => context.go('/register')),
                          _FooterAction('Farmer Assistance',
                              () => context.go('/about-us')),
                          _FooterAction('Reviews & Stories',
                              () => context.go('/articles')),
                        ],
                      ),
                    ),
                    // SHOP
                    Expanded(
                      flex: 2,
                      child: _buildFooterSection(
                        'SHOP',
                        [
                          _FooterAction('Farm Equipment',
                              () => context.go(AppRoutes.shop)),
                          _FooterAction('Fresh Vegetables',
                              () => context.go(AppRoutes.freshProduce)),
                          _FooterAction('Seasonal Pre-Orders',
                              () => context.go('/shop?mode=preorders')),
                          _FooterAction('Flash Harvest Deals',
                              () => context.go(AppRoutes.flashSale)),
                          _FooterAction('Wholesale Produce',
                              () => context.go(AppRoutes.wholesale)),
                          _FooterAction('Local Farm Shops',
                              () => context.go(AppRoutes.localShops)),
                        ],
                      ),
                    ),
                    // ORDERING
                    Expanded(
                      flex: 2,
                      child: _buildFooterSection(
                        'ORDERING',
                        [
                          _FooterAction(
                              'Terms & Conditions',
                              () => _showPolicyModal(context,
                                  'Terms of Service', _termsOfServiceText)),
                          _FooterAction(
                              'Privacy Policy',
                              () => _showPolicyModal(context, 'Privacy Policy',
                                  _privacyPolicyText)),
                          _FooterAction('Delivery & Logistics',
                              () => context.go('/about-us')),
                          _FooterAction('Produce Guarantee',
                              () => context.go('/about-us')),
                          _FooterAction('DA Quality Standards',
                              () => context.go('/articles')),
                        ],
                      ),
                    ),
                    // CONTACT
                    Expanded(
                      flex: 3,
                      child: _buildContactSection(context),
                    ),
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
                              () => _showPolicyModal(context, 'Privacy Policy',
                                  _privacyPolicyText),
                            ),
                            _buildBottomLink(
                              context,
                              'Terms of Service',
                              () => _showPolicyModal(context,
                                  'Terms of Service', _termsOfServiceText),
                            ),
                            _buildBottomLink(
                              context,
                              'Cookie Policy',
                              () => _showPolicyModal(context, 'Cookie Policy',
                                  _cookiePolicyText),
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
                              () => _showPolicyModal(context, 'Privacy Policy',
                                  _privacyPolicyText),
                            ),
                            const SizedBox(width: 20),
                            _buildBottomLink(
                              context,
                              'Terms of Service',
                              () => _showPolicyModal(context,
                                  'Terms of Service', _termsOfServiceText),
                            ),
                            const SizedBox(width: 20),
                            _buildBottomLink(
                              context,
                              'Cookie Policy',
                              () => _showPolicyModal(context, 'Cookie Policy',
                                  _cookiePolicyText),
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
              const Icon(Icons.verified_user_rounded,
                  color: AgriColors.lime300, size: 20),
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
        ...actions.map((a) => Padding(
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
            )),
      ],
    );
  }

  Widget _buildContactSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CONTACT',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'AgriDirect Agro-Innovation Hub\nElliptical Road, Diliman, Quezon City\nPhilippines',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.8),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'P: +63 (02) 8928-8741\nE: contact@agridirect.ph',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.8),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        // Social Media Icons
        Row(
          children: [
            _socialIcon(context, Icons.camera_alt_outlined),
            const SizedBox(width: 10),
            _socialIcon(context, Icons.share_rounded),
            const SizedBox(width: 10),
            _socialIcon(context, Icons.facebook_rounded),
            const SizedBox(width: 10),
            _socialIcon(context, Icons.language_rounded),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomLink(
      BuildContext context, String text, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _socialIcon(BuildContext context, IconData icon) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Redirecting to official social media channel...')),
          );
        },
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
    );
  }
}

class _FooterAction {
  final String title;
  final VoidCallback onTap;
  const _FooterAction(this.title, this.onTap);
}
