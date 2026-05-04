import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary Brand Colors (Modern Emerald/Forest vibe)
  static const Color primary = Color(0xFF059669); // Emerald 600
  static const Color primaryLight = Color(0xFFD1FAE5); // Emerald 100
  static const Color primaryDark = Color(0xFF065F46); // Emerald 800
  static const Color secondary = Color(0xFF10B981); // Emerald 500
  static const Color accent = Color(0xFFF59E0B); // Amber 500 / CTA
  
  // Neutral Colors
  static const Color background = Color(0xFFF8FAFC); // Slate 50 (Very light cool gray)
  static const Color surface = Colors.white;
  static const Color textBody = Color(0xFF334155); // Slate 700 
  static const Color textHeadline = Color(0xFF0F172A); // Slate 900
  static const Color textSubtle = Color(0xFF64748B); // Slate 500
  
  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTextStyles {
  // Headings - Poppins
  static TextStyle get headline1 => GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.textHeadline,
        letterSpacing: -0.5,
      );

  static TextStyle get headline2 => GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.textHeadline,
        letterSpacing: -0.3,
      );

  static TextStyle get headline3 => GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textHeadline,
        letterSpacing: -0.2,
      );

  // Body - Inter
  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textBody,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textBody,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textBody,
      );

  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSubtle,
        letterSpacing: 0.2,
      );

  static TextStyle get labelLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textBody,
      );
}

class AppDecorations {
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      );

  static BoxDecoration get glassDecoration => BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static BorderRadius get buttonRadius => BorderRadius.circular(16);

  static ButtonStyle get primaryButton => FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: buttonRadius),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      );
}
