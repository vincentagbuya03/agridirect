import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// AgriDirect Admin Premium Design System (Digital Arboretum Edition)
class AdminUi {
  // Brand Colors
  static const Color brand = Color(0xFF064E3B); // Very Dark Forest Green
  static const Color brandSecondary = Color(0xFF10B981); // Emerald Green
  static const Color brandSoft = Color(0xFFECFDF5);
  static const Color brandDark = Color(0xFF022C22); // Near black green

  static const Color sidebarBg = Color(0xFFF8F9FE); // Very Light Blue/Grey
  static const Color accent = Color(0xFF10B981);
  static const Color accentSoft = Color(0xFFD1FAE5);

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Neutrals
  static const Color background = Color(0xFFF3F4F6);
  static const Color panel = Color(0xFFFFFFFF);
  static const Color panelAlt = Color(0xFFF9FAFB);
  static const Color border = Color(0xFFE5E7EB);

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF9CA3AF);

  // Radii
  static final BorderRadius radiusSm = BorderRadius.circular(8);
  static final BorderRadius radiusMd = BorderRadius.circular(12);
  static final BorderRadius radiusLg = BorderRadius.circular(16);
  static final BorderRadius radiusFull = BorderRadius.circular(999);

  // Animations
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 300);

  // Shadow (Extremely subtle)
  static List<BoxShadow> get shadowSm => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get shadowMd => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  // Typography
  static TextStyle display(
    BuildContext context, {
    double size = 28,
    Color? color,
    FontWeight weight = FontWeight.w800,
    double? letterSpacing,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color ?? textPrimary,
      letterSpacing: letterSpacing ?? -0.5,
    );
  }

  static TextStyle title({
    double size = 18,
    Color? color,
    FontWeight weight = FontWeight.w700,
    double? letterSpacing,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color ?? textPrimary,
      letterSpacing: letterSpacing ?? -0.3,
    );
  }

  static TextStyle body({
    double size = 14,
    Color? color,
    FontWeight weight = FontWeight.w500,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color ?? textSecondary,
    );
  }

  static TextStyle label({
    double size = 12,
    Color? color,
    FontWeight weight = FontWeight.w600,
    double? letterSpacing,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color ?? textSecondary,
      letterSpacing: letterSpacing,
    );
  }

  // Common Decorations
  static BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: panel,
      borderRadius: radiusMd,
      boxShadow: shadowSm,
    );
  }

  static ButtonStyle get primaryButton => ElevatedButton.styleFrom(
    backgroundColor: brand,
    foregroundColor: Colors.white,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: radiusSm),
    textStyle: label(size: 13, weight: FontWeight.w700),
  );

  static ButtonStyle get secondaryButton => ElevatedButton.styleFrom(
    backgroundColor: accentSoft,
    foregroundColor: brand,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: radiusSm),
    textStyle: label(size: 13, weight: FontWeight.w700),
  );

  static InputDecoration inputDecoration({
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: label(color: textMuted, weight: FontWeight.w400),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF3F4F6),
      border: OutlineInputBorder(
        borderRadius: radiusMd,
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return EdgeInsets.all(width < 900 ? 24 : 40);
  }
}

/// Standard Page Frame
class AdminPageFrame extends StatelessWidget {
  final Widget child;
  const AdminPageFrame({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(color: AdminUi.background, child: child);
  }
}

/// Standard Hero Header for Admin Tabs (Updated to match Digital Arboretum style)
class AdminHeroCard extends StatelessWidget {
  final String title;
  final String description;
  final String? eyebrow;
  final List<Widget> actions;
  final List<Widget> metrics;
  final bool useGradient;

  const AdminHeroCard({
    super.key,
    required this.title,
    required this.description,
    this.eyebrow,
    this.actions = const [],
    this.metrics = const [],
    this.useGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 640;

        return Container(
          padding: EdgeInsets.all(isMobile ? 18 : 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E9E4), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrow != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: AdminUi.brandSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          eyebrow!.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            color: AdminUi.brand,
                            fontWeight: FontWeight.w800,
                            fontSize: 9,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AdminUi.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AdminUi.textSecondary,
                      ),
                    ),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: actions,
                      ),
                    ],
                  ],
                ),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (eyebrow != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AdminUi.brandSoft,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                eyebrow!.toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  color: AdminUi.brand,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Text(
                            title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AdminUi.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            description,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AdminUi.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: actions,
                      ),
                    ],
                  ],
                ),
              ],
              if (metrics.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Divider(height: 1, color: Color(0xFFE6EDE8)),
                const SizedBox(height: 14),
                if (isMobile)
                  Wrap(
                    spacing: 12,
                    runSpacing: 14,
                    children: metrics
                        .where((m) => m is! SizedBox)
                        .map((m) {
                          final itemWidth = (constraints.maxWidth - 36 - 12) / 2;
                          return SizedBox(
                            width: itemWidth > 120 ? itemWidth : null,
                            child: m,
                          );
                        })
                        .toList(),
                  )
                else
                  Wrap(
                    spacing: 24,
                    runSpacing: 16,
                    children: metrics.where((m) => m is! SizedBox).toList(),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Mini metric displays for Hero Cards (Updated)
class AdminMiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  final bool light;

  const AdminMiniMetric({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (color ?? AdminUi.brand).withValues(alpha: 0.1),
              borderRadius: AdminUi.radiusMd,
            ),
            child: Icon(icon, size: 18, color: color ?? AdminUi.brand),
          ),
          const SizedBox(width: 16),
        ],
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AdminUi.label(size: 11, color: AdminUi.textMuted),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: AdminUi.title(size: 20, weight: FontWeight.w800),
            ),
          ],
        ),
      ],
    );
  }
}

/// Modern Hero Component for the Admin Overview section
class AdminDashboardHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> actions;

  const AdminDashboardHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 20 : 28),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AdminUi.brand.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AdminUi.brand,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'LIVE CONTROL',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AdminUi.brand,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AdminUi.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AdminUi.textSecondary,
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: actions,
                  ),
                ],
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AdminUi.brand.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AdminUi.brand,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'LIVE EXECUTIVE CONTROL',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AdminUi.brand,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AdminUi.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AdminUi.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: actions,
                  ),
                ],
              ],
            ),
    );
  }
}

/// The individual metric cards with the pattern background
class AdminMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? trend;
  final IconData icon;
  final Color iconColor;
  final String? badge;

  const AdminMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.trend,
    required this.icon,
    this.iconColor = AdminUi.brand,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(24),
      decoration: AdminUi.cardDecoration().copyWith(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, iconColor.withValues(alpha: 0.035)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: AdminUi.radiusSm,
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AdminUi.brandSoft,
                    borderRadius: AdminUi.radiusFull,
                  ),
                  child: Text(
                    trend!,
                    style: AdminUi.label(
                      size: 10,
                      color: AdminUi.brand,
                      weight: FontWeight.w700,
                    ),
                  ),
                )
              else if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badge == 'Urgent'
                        ? AdminUi.danger.withValues(alpha: 0.1)
                        : AdminUi.brandSoft,
                    borderRadius: AdminUi.radiusFull,
                  ),
                  child: Text(
                    badge!,
                    style: AdminUi.label(
                      size: 10,
                      color: badge == 'Urgent' ? AdminUi.danger : AdminUi.brand,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            label.toUpperCase(),
            style: AdminUi.label(
              size: 10,
              color: AdminUi.textMuted,
              weight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AdminUi.display(context, size: 24, weight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
