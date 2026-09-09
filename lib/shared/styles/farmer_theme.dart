import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens specifically crafted for high sunlight legibility,
/// large touch targets, and visual clarity for farmers.
class FarmerTheme {
  // Brand & Agriculture Color Palette
  static const Color forestGreen = Color(0xFF064E3B); // Deep Emerald 900
  static const Color primaryAction = Color(0xFF15803D); // Vibrant Green 700
  static const Color actionHover = Color(0xFF166534); // Green 800
  static const Color softMint = Color(0xFFE9F8EF); // Light Mint Surface
  static const Color goldAccent = Color(0xFFD97706); // Amber 600
  static const Color goldSoft = Color(0xFFFEF3C7); // Amber 100

  // High-Contrast Sunlight Neutrals (WCAG AAA compliant)
  static const Color textHeadline = Color(0xFF0F172A); // Slate 900 (High contrast)
  static const Color textBody = Color(0xFF1E293B); // Slate 800
  static const Color textMuted = Color(0xFF475569); // Slate 600 (Never washed out)
  static const Color backgroundLight = Color(0xFFF4F7F4); // Pale farm cream/green
  static const Color cardSurface = Colors.white;
  static const Color borderCrisp = Color(0xFFCBD5E1); // Slate 300 (1.5px crisp border)
  static const Color borderFocused = Color(0xFF15803D);

  // Status Colors
  static const Color statusSuccess = Color(0xFF15803D);
  static const Color statusError = Color(0xFFDC2626);
  static const Color statusWarning = Color(0xFFB45309);

  // Metrics
  static const double minTouchTargetHeight = 56.0;
  static const double inputHeight = 54.0;
  static const double cardBorderRadius = 24.0;
  static const double buttonBorderRadius = 16.0;

  // Typography
  static TextStyle get headline => GoogleFonts.plusJakartaSans(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: textHeadline,
        letterSpacing: -0.4,
      );

  static TextStyle get sectionTitle => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: textHeadline,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textBody,
        height: 1.45,
      );

  static TextStyle get bodyMuted => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textMuted,
        height: 1.4,
      );

  static TextStyle get buttonLabel => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      );

  static BoxDecoration get cardDecoration => BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(cardBorderRadius),
        border: Border.all(color: borderCrisp, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      );
}
