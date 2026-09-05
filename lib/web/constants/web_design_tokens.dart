import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized E-Commerce Design Tokens for AgriDirect Web
class WebDesignTokens {
  // Brand Colors
  static const Color primary = Color(0xFF16A34A);
  static const Color primaryDark = Color(0xFF14532D);
  static const Color primaryLight = Color(0xFFF0FDF4);

  // Neutrals & Surfaces
  static const Color dark = Color(0xFF0F172A);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);
  static const Color bg = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;

  // Accents & Signals
  static const Color dealAmber = Color(0xFFEA580C);
  static const Color discountRed = Color(0xFFDC2626);
  static const Color trustBlue = Color(0xFF2563EB);
  static const Color organicGreen = Color(0xFF059669);

  // Box Shadows
  static final List<BoxShadow> cardRest = [
    BoxShadow(
      color: dark.withValues(alpha: 0.04),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  static final List<BoxShadow> cardHover = [
    BoxShadow(
      color: dark.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static final List<BoxShadow> dropdownShadow = [
    BoxShadow(
      color: dark.withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  // Typography (Google Fonts Rubik for numeric/headings, Nunito Sans for body)
  static TextStyle h1({Color color = dark}) => GoogleFonts.rubik(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.2,
      );

  static TextStyle h2({Color color = dark}) => GoogleFonts.rubik(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.25,
      );

  static TextStyle h3({Color color = dark}) => GoogleFonts.rubik(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.3,
      );

  static TextStyle priceLarge({Color color = primary}) => GoogleFonts.rubik(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle priceMedium({Color color = primary}) => GoogleFonts.rubik(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle bodyRegular({Color color = slate700}) =>
      GoogleFonts.nunitoSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.5,
      );

  static TextStyle bodyMedium({Color color = dark}) => GoogleFonts.nunitoSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle caption({Color color = slate500}) => GoogleFonts.nunitoSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle badge({Color color = Colors.white}) => GoogleFonts.rubik(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.5,
      );
}

/// Responsive Breakpoint Utility
class WebBreakpoints {
  static const double desktopWide = 1440;
  static const double desktop = 1024;
  static const double tablet = 768;

  static bool isDesktopWide(double width) => width >= desktopWide;
  static bool isDesktop(double width) => width >= desktop && width < desktopWide;
  static bool isTablet(double width) => width >= tablet && width < desktop;
  static bool isMobile(double width) => width < tablet;

  static double containerWidth(double screenWidth) {
    if (screenWidth >= 1440) return 1360;
    if (screenWidth >= 1024) return 1100;
    return screenWidth;
  }
}
