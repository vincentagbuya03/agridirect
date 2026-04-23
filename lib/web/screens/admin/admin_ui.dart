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
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: label(color: textMuted, weight: FontWeight.w400),
      prefixIcon: prefixIcon,
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
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: AdminUi.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AdminUi.brandSoft,
                          borderRadius: AdminUi.radiusFull,
                        ),
                        child: Text(
                          eyebrow!.toUpperCase(),
                          style: AdminUi.label(
                            color: AdminUi.brand,
                            weight: FontWeight.w800,
                            size: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(title, style: AdminUi.display(context, size: 28)),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: AdminUi.body(
                        size: 15,
                        color: AdminUi.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (actions.isNotEmpty)
                Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: actions,
                ),
            ],
          ),
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 32),
            const Divider(height: 1, color: AdminUi.border),
            const SizedBox(height: 24),
            Wrap(spacing: 32, runSpacing: 24, children: metrics),
          ],
        ],
      ),
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

/// New Hero Component for the "Overview" section
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AdminUi.display(context, size: 32)),
              const SizedBox(height: 4),
              Text(subtitle, style: AdminUi.body(color: AdminUi.textSecondary)),
            ],
          ),
          if (actions.isNotEmpty)
            Row(
              children: actions
                  .map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: a,
                    ),
                  )
                  .toList(),
            ),
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
    return Expanded(
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(24),
        decoration: AdminUi.cardDecoration().copyWith(
          image: const DecorationImage(
            image: NetworkImage(
              'https://www.transparenttextures.com/patterns/cubes.png',
            ),
            opacity: 0.02,
            repeat: ImageRepeat.repeat,
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
                        color: badge == 'Urgent'
                            ? AdminUi.danger
                            : AdminUi.brand,
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
              style: AdminUi.display(
                context,
                size: 24,
                weight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
