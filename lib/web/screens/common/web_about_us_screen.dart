import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../widgets/animated_components.dart';
import '../../widgets/web_footer.dart';

class WebAboutUsScreen extends StatelessWidget {
  const WebAboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildNav(context, isMobile),
            _buildHero(isMobile),
            _buildMissionStory(isMobile),
            _buildPillarsGrid(isMobile),
            _buildDaPartnershipSection(isMobile),
            _buildImpactStats(isMobile),
            _buildCta(context, isMobile),
            const AgriDirectWebFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildNav(BuildContext context, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 48,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1300),
          child: Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => context.go('/'),
                  child: BrandLogo(size: isMobile ? BrandLogoSize.small : BrandLogoSize.medium),
                ),
              ),
              const Spacer(),
              if (!isMobile) ...[
                TextButton(
                  onPressed: () => context.go('/'),
                  child: Text('Home', style: GoogleFonts.inter(color: AgriColors.dark, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: () => context.go(AppRoutes.shop),
                  child: Text('Shop', style: GoogleFonts.inter(color: AgriColors.dark, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: () => context.go(AppRoutes.community),
                  child: Text('Community', style: GoogleFonts.inter(color: AgriColors.dark, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: () => context.go(AppRoutes.articles),
                  child: Text('DA Articles', style: GoogleFonts.inter(color: AgriColors.dark, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: () {},
                  child: Text('About Us', style: GoogleFonts.inter(color: AgriColors.emerald700, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: () => context.go(AppRoutes.farmersMap),
                  child: Text('Find Farmer', style: GoogleFonts.inter(color: AgriColors.dark, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: () => context.go(AppRoutes.weatherRadar),
                  child: Text('Weather', style: GoogleFonts.inter(color: AgriColors.dark, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 14),
              ],
              ElevatedButton.icon(
                onPressed: () => context.go(AppRoutes.marketplace),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF005A36),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                icon: const Icon(Icons.storefront_rounded, size: 16),
                label: Text('Marketplace', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(bool isMobile) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF005A36), Color(0xFF044E38)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 48,
        vertical: isMobile ? 48 : 80,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AgriColors.gold400.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AgriColors.gold400.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.eco_rounded, color: AgriColors.gold300, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'FARM-TO-TABLE REVOLUTION',
                      style: GoogleFonts.inter(
                        color: AgriColors.gold200,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Direct Connections.\nZero Exploitative Middlemen.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isMobile ? 32 : 52,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.15,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'AgriDirect was founded with a singular purpose: to give hardworking Filipino farmers fair market value for their harvest while giving households access to 100% fresh, traceable, pesticide-safe produce.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: isMobile ? 14 : 17,
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.7,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissionStory(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 48,
        vertical: isMobile ? 48 : 80,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OUR STORY & MISSION',
                style: GoogleFonts.inter(
                  color: const Color(0xFF005A36),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Transforming Agricultural Trade in the Philippines',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isMobile ? 26 : 36,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'For decades, traditional agricultural supply chains have forced smallholder growers to sell at rock-bottom farm-gate rates to multi-tiered middlemen, who inflate retail prices by up to 300%. By the time produce reaches consumer tables, days have passed and nutritional value has degraded.\n\nAgriDirect changes this model through direct digital marketplaces, transparent pre-order harvest cycles, and localized cold-chain logistics. Farmers list what they plant, buyers pre-order early, and food is harvested on demand for maximum freshness.',
                style: GoogleFonts.inter(
                  fontSize: 15.5,
                  color: const Color(0xFF334155),
                  height: 1.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillarsGrid(bool isMobile) {
    final pillars = [
      {
        'icon': Icons.price_check_rounded,
        'title': 'Fair Farm-Gate Pricing',
        'desc': 'Farmers determine their own retail prices based on real production costs and fair living wages, keeping 100% of their net sales.',
      },
      {
        'icon': Icons.verified_user_rounded,
        'title': 'DA-Aligned Quality Standards',
        'desc': 'We partner with municipal agricultural officers and the Department of Agriculture to uphold Good Agricultural Practices (GAP).',
      },
      {
        'icon': Icons.bolt_rounded,
        'title': 'Harvested Fresh to Order',
        'desc': 'No long warehousing. Crops are picked at peak ripeness at dawn and delivered to urban consumers within 24 hours.',
      },
      {
        'icon': Icons.people_alt_rounded,
        'title': 'Agrarian Cooperative Support',
        'desc': 'Supporting local agricultural cooperatives with collective transport, solar tools, seed funding, and digital literacy.',
      },
    ];

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 48,
        vertical: isMobile ? 48 : 80,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              Text(
                'THE 4 PILLARS OF AGRIDIRECT',
                style: GoogleFonts.inter(
                  color: const Color(0xFF005A36),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Building a Resilient Food Future',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isMobile ? 26 : 34,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 40),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth < 700 ? 1 : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
                      childAspectRatio: isMobile ? 1.6 : 2.0,
                    ),
                    itemCount: pillars.length,
                    itemBuilder: (context, i) {
                      final p = pillars[i];
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6F4EA),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(p['icon'] as IconData, color: const Color(0xFF005A36), size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p['title'] as String,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Expanded(
                                    child: Text(
                                      p['desc'] as String,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: const Color(0xFF64748B),
                                        height: 1.5,
                                      ),
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
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDaPartnershipSection(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 48,
        vertical: isMobile ? 48 : 80,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 24 : 40),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF005A36), Color(0xFF044E38)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF005A36).withValues(alpha: 0.25),
                  blurRadius: 28,
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
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.account_balance_rounded, color: AgriColors.gold300, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Department of Agriculture (DA) Collaborative Program',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: isMobile ? 18 : 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Promoting Food Security, Agrarian Technology & Sustainable Land Use',
                            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Through integration with regional field advisories, weather monitoring radar, and technical knowledge sharing, AgriDirect acts as a digital bridge for Department of Agriculture programs. Farmers receive real-time pest mitigation alerts, while buyers gain confidence in certified harvest provenance.',
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImpactStats(bool isMobile) {
    return Container(
      color: const Color(0xFFF1FDF4),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 48,
        vertical: isMobile ? 40 : 60,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _stat('200+', 'Verified Local Farmers'),
              _stat('5,000+', 'Crates Delivered'),
              _stat('100%', 'Direct Farm-Gate Return'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String num, String label) {
    return Column(
      children: [
        Text(
          num,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF005A36),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            color: const Color(0xFF475569),
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCta(BuildContext context, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 48,
        vertical: isMobile ? 48 : 80,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              Text(
                'Ready to support local agriculture?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isMobile ? 24 : 32,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Join thousands of consumers and verified growers creating a fair, transparent food ecosystem.',
                style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF64748B), height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go(AppRoutes.marketplace),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF005A36),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: Text(
                  'Explore Marketplace',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

