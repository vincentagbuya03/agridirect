import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/router/app_routes.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../constants/developer_assets.dart';
import '../../widgets/animated_components.dart';
import '../../widgets/web_footer.dart';

/// WebAboutUsScreen
/// Comprehensive About Us page highlighting the AgriDirect mission,
/// official Department of Agriculture (DA) & PSU partnership, and the 3-developer team.
class WebAboutUsScreen extends StatelessWidget {
  const WebAboutUsScreen({super.key});

  static const Color _primary = Color(0xFF005A36);
  static const Color _emerald = Color(0xFF16A34A);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

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
            _buildPartnershipSignatories(isMobile),
            _buildDevelopmentTeamSection(isMobile),
            _buildPillarsGrid(isMobile),
            _buildImpactStats(isMobile),
            _buildCta(context, isMobile),
            const AgriDirectWebFooter(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION BAR
  // ---------------------------------------------------------------------------
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
                  child: BrandLogo(
                    size: isMobile ? BrandLogoSize.small : BrandLogoSize.medium,
                  ),
                ),
              ),
              const Spacer(),
              if (!isMobile) ...[
                TextButton(
                  onPressed: () => context.go('/'),
                  child: Text(
                    'Home',
                    style: GoogleFonts.inter(
                      color: AgriColors.dark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: () => context.go(AppRoutes.shop),
                  child: Text(
                    'Shop',
                    style: GoogleFonts.inter(
                      color: AgriColors.dark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: () => context.go(AppRoutes.community),
                  child: Text(
                    'Community',
                    style: GoogleFonts.inter(
                      color: AgriColors.dark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: () => context.go(AppRoutes.articles),
                  child: Text(
                    'DA Articles',
                    style: GoogleFonts.inter(
                      color: AgriColors.dark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'About Us',
                    style: GoogleFonts.inter(
                      color: _primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: () => context.go(AppRoutes.farmersMap),
                  child: Text(
                    'Find Farmer',
                    style: GoogleFonts.inter(
                      color: AgriColors.dark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: () => context.go(AppRoutes.weatherRadar),
                  child: Text(
                    'Weather',
                    style: GoogleFonts.inter(
                      color: AgriColors.dark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
              ],
              ElevatedButton.icon(
                onPressed: () => context.go(AppRoutes.marketplace),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.storefront_rounded, size: 16),
                label: Text(
                  'Marketplace',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HERO SECTION
  // ---------------------------------------------------------------------------
  Widget _buildHero(bool isMobile) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF004D2E), Color(0xFF005A36), Color(0xFF065F46)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 48,
        vertical: isMobile ? 48 : 84,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AgriColors.gold400.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AgriColors.gold400.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.eco_rounded,
                      color: AgriColors.gold300,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'FARM-TO-TABLE DIGITAL REVOLUTION',
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
                'Empowering Farmers.\nConnecting Communities.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isMobile ? 32 : 54,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.15,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'AgriDirect is a digital agricultural ecosystem developed to give hardworking Filipino farmers honest market value for their harvest while providing households with 100% fresh, traceable, pesticide-safe produce.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: isMobile ? 14 : 17.5,
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.7,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MISSION & ORIGIN STORY
  // ---------------------------------------------------------------------------
  Widget _buildMissionStory(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 48,
        vertical: isMobile ? 48 : 72,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OUR ORIGIN & PURPOSE',
                style: GoogleFonts.inter(
                  color: _primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Bridging Smallholders Directly to Filipino Homes',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isMobile ? 26 : 36,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Traditional agricultural supply chains have long forced smallholder growers to sell at rock-bottom farm-gate rates to multi-layered middlemen. By the time crops reach consumers, prices are inflated and days of freshness are lost.\n\nAgriDirect solves this through an end-to-end digital marketplace with transparent pre-order harvest cycles, live farmer storefronts, and direct chat communication. Producers list what they cultivate, buyers pre-order early, and food is harvested on demand for maximum nutrition and zero wasted yield.',
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

  // ---------------------------------------------------------------------------
  // INSTITUTIONAL & GOVERNMENT PARTNERSHIP (DA + PSU)
  // ---------------------------------------------------------------------------
  Widget _buildPartnershipSignatories(bool isMobile) {
    return Container(
      color: _surface,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 48,
        vertical: isMobile ? 48 : 72,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.account_balance_rounded,
                      color: _primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'GOVERNMENT COLLABORATION',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _primary,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Department of Agriculture Leadership',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isMobile ? 24 : 34,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'AgriDirect operates in close coordination with the Department of Agriculture (San Carlos City) to advance agrarian digitalization, verified producer certifications, and local food security.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  color: _muted,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 36),

              // Single Centered Signatory Card
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: _buildSignatoryCard(
                  name: 'ESTRILLITA B. JACABAN, MDM',
                  position: 'Department Head',
                  institution: 'Department of Agriculture',
                  subUnit: 'San Carlos City, Pangasinan',
                  icon: Icons.agriculture_rounded,
                  accentColor: const Color(0xFF047857),
                  tag: 'GOVERNMENT PARTNER',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignatoryCard({
    required String name,
    required String position,
    required String institution,
    required String subUnit,
    required IconData icon,
    required Color accentColor,
    required String tag,
  }) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            name,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _dark,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            position,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$institution – $subUnit',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: _muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DEVELOPMENT TEAM (3 DEVELOPERS)
  // ---------------------------------------------------------------------------
  Widget _buildDevelopmentTeamSection(bool isMobile) {
    final developers = [
      {
        'name': 'Nick Vincent Agbuya',
        'role': 'Lead Full-Stack Developer & Architect',
        'badgeTag': 'LEAD ARCHITECT',
        'focus':
            'Full-Stack Architecture, Supabase Cloud Backend, Realtime State Synchronization & Security Services',
        'initials': 'NA',
        'imageKey': 'nick',
        'icon': Icons.terminal_rounded,
        'badgeColor': const Color(0xFF005A36),
        'lightColor': const Color(0xFFE6F4EA),
        'borderColor': const Color(0xFFA7F3D0),
        'tech': ['Flutter', 'Supabase', 'Dart', 'PostgreSQL', 'Cloud Architecture'],
      },
      {
        'name': 'John Carlo Banaag',
        'role': 'Frontend & UI/UX Developer',
        'badgeTag': 'UI/UX SPECIALIST',
        'focus':
            'Responsive Web Layouts, Design Systems, Animation Pipelines & Cross-Platform UX Engineering',
        'initials': 'JB',
        'imageKey': 'john',
        'icon': Icons.palette_rounded,
        'badgeColor': const Color(0xFF1D4ED8),
        'lightColor': const Color(0xFFEFF6FF),
        'borderColor': const Color(0xFFBFDBFE),
        'tech': ['UI/UX Design', 'Flutter Web', 'Micro-Interactions', 'Design System'],
      },
      {
        'name': 'Extra Lang',
        'role': 'Database & Infrastructure Engineer',
        'badgeTag': 'DATABASE & CLOUD',
        'focus':
            'PostgreSQL Schemas, Edge RPC Procedures, Performance Indexing, Storage & Row-Level Security',
        'initials': 'EL',
        'imageKey': 'extra',
        'icon': Icons.dns_rounded,
        'badgeColor': const Color(0xFF7C3AED),
        'lightColor': const Color(0xFFF5F3FF),
        'borderColor': const Color(0xFFDDD6FE),
        'tech': ['PostgreSQL', 'Edge RPCs', 'Cloud Storage', 'RLS Policies', 'Database Indexing'],
      },
    ];

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 48,
        vertical: isMobile ? 48 : 84,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _emerald.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.code_rounded, color: _emerald, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      'ENGINEERING & SYSTEM ARCHITECTURE',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _emerald,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'The Core Development Team',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isMobile ? 26 : 38,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Text(
                  'AgriDirect is engineered and maintained by a dedicated developer team from Pangasinan State University – San Carlos Campus, combining full-stack architecture, cross-platform UI systems, and robust database infrastructure.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: _muted,
                    height: 1.65,
                  ),
                ),
              ),
              const SizedBox(height: 48),

              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth < 740
                      ? 1
                      : (constraints.maxWidth < 1120 ? 2 : 3);

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
                      mainAxisExtent: isMobile ? 640 : 615,
                    ),
                    itemCount: developers.length,
                    itemBuilder: (context, i) {
                      final dev = developers[i];
                      final badgeColor = dev['badgeColor'] as Color;
                      final lightColor = dev['lightColor'] as Color;
                      final borderColor = dev['borderColor'] as Color;
                      final badgeTag = dev['badgeTag'] as String;
                      final imageKey = dev['imageKey'] as String? ?? '';
                      final techList = dev['tech'] as List<String>? ?? [];

                      return Container(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Centered Large Framed Portrait (270px) with Badge Overlay
                            Stack(
                              alignment: Alignment.bottomCenter,
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: borderColor,
                                      width: 4,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: badgeColor.withValues(alpha: 0.22),
                                        blurRadius: 24,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    width: 270,
                                    height: 270,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                    ),
                                    child: ClipOval(
                                      child: _buildDevAvatar(
                                        imageKey: imageKey,
                                        dev: dev,
                                        badgeColor: badgeColor,
                                        lightColor: lightColor,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: -10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: badgeColor,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.2),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          dev['icon'] as IconData,
                                          size: 13,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          badgeTag,
                                          style: GoogleFonts.inter(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),

                            // Developer Name & Role
                            Text(
                              dev['name'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _dark,
                                letterSpacing: -0.2,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              dev['role'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: badgeColor,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              dev['focus'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: _muted,
                                height: 1.45,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 14),

                            // Tech Stack Chips
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              alignment: WrapAlignment.center,
                              children: techList.map((t) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: lightColor,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: borderColor.withValues(alpha: 0.8),
                                    ),
                                  ),
                                  child: Text(
                                    t,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: badgeColor,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const Spacer(),

                            // Institutional Affiliation Bar
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.school_outlined,
                                    size: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Pangasinan State University – San Carlos',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF64748B),
                                    ),
                                    textAlign: TextAlign.center,
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

  Widget _buildDevAvatar({
    required String imageKey,
    required Map<String, dynamic> dev,
    required Color badgeColor,
    required Color lightColor,
  }) {
    // 1. Direct high-speed memory rendering with embedded bytes
    if (imageKey == 'nick') {
      return Image.memory(
        DeveloperAssets.nickVincentBytes,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        errorBuilder: (context, error, stackTrace) =>
            _buildInitialsMonogram(dev, badgeColor, lightColor),
      );
    } else if (imageKey == 'john') {
      return Image.memory(
        DeveloperAssets.johnCarloBytes,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        errorBuilder: (context, error, stackTrace) =>
            _buildInitialsMonogram(dev, badgeColor, lightColor),
      );
    }

    // 2. Default fallback for 3rd developer / other members
    return _buildInitialsMonogram(dev, badgeColor, lightColor);
  }

  Widget _buildInitialsMonogram(
    Map<String, dynamic> dev,
    Color badgeColor,
    Color lightColor,
  ) {
    return Container(
      color: lightColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              dev['icon'] as IconData? ?? Icons.person_rounded,
              color: badgeColor,
              size: 72,
            ),
            const SizedBox(height: 8),
            Text(
              dev['initials'] as String? ?? 'DEV',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                color: badgeColor,
                fontSize: 28,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4 PILLARS GRID
  // ---------------------------------------------------------------------------
  Widget _buildPillarsGrid(bool isMobile) {
    final pillars = [
      {
        'icon': Icons.price_check_rounded,
        'title': 'Fair Farm-Gate Pricing',
        'desc':
            'Farmers determine their own retail prices based on real production costs and fair living wages, keeping 100% of their net sales.',
      },
      {
        'icon': Icons.verified_user_rounded,
        'title': 'DA-Aligned Quality Standards',
        'desc':
            'We partner with municipal agricultural officers and the Department of Agriculture to uphold Good Agricultural Practices (GAP).',
      },
      {
        'icon': Icons.bolt_rounded,
        'title': 'Harvested Fresh to Order',
        'desc':
            'No long warehousing. Crops are picked at peak ripeness at dawn and delivered to urban consumers within 24 hours.',
      },
      {
        'icon': Icons.people_alt_rounded,
        'title': 'Agrarian Cooperative Support',
        'desc':
            'Supporting local agricultural cooperatives with collective transport, solar tools, seed funding, and digital literacy.',
      },
    ];

    return Container(
      color: _surface,
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
                  color: _primary,
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
                  color: _dark,
                ),
              ),
              const SizedBox(height: 36),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth < 700 ? 1 : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      mainAxisExtent: 130,
                    ),
                    itemCount: pillars.length,
                    itemBuilder: (context, i) {
                      final p = pillars[i];
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                p['icon'] as IconData,
                                color: _primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    p['title'] as String,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: _dark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    p['desc'] as String,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: _muted,
                                      height: 1.4,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
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

  // ---------------------------------------------------------------------------
  // IMPACT METRICS
  // ---------------------------------------------------------------------------
  Widget _buildImpactStats(bool isMobile) {
    return Container(
      color: const Color(0xFFECFDF5),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 48,
        vertical: isMobile ? 36 : 56,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: isMobile
              ? Column(
                  children: [
                    _stat('200+', 'Verified Local Farmers'),
                    const SizedBox(height: 20),
                    _stat('5,000+', 'Crates Delivered'),
                    const SizedBox(height: 20),
                    _stat('100%', 'Direct Farm-Gate Return'),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(child: _stat('200+', 'Verified Local Farmers')),
                    Expanded(child: _stat('5,000+', 'Crates Delivered')),
                    Expanded(child: _stat('100%', 'Direct Farm-Gate Return')),
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
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: _primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF475569),
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // CTA
  // ---------------------------------------------------------------------------
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
                  fontSize: isMobile ? 24 : 34,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Join thousands of consumers and verified growers creating a fair, transparent food ecosystem.',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: _muted,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go(AppRoutes.marketplace),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: Text(
                  'Explore Marketplace',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
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
