import 'package:flutter/material.dart';
import '../styles/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

enum BrandLogoSize {
  small,
  medium,
  large,
}

class BrandLogo extends StatelessWidget {
  final BrandLogoSize size;
  final bool showText;
  final Color? color;
  final bool useIconOnly;
  final bool inverted; // For dark backgrounds
  final bool? vertical; // If null, auto-determined by size

  const BrandLogo({
    super.key,
    this.size = BrandLogoSize.medium,
    this.showText = true,
    this.color,
    this.useIconOnly = false,
    this.inverted = false,
    this.vertical,
  });

  bool get _isVertical => vertical ?? (size == BrandLogoSize.large);

  double get _logoSize {
    switch (size) {
      case BrandLogoSize.small:
        return 28;
      case BrandLogoSize.medium:
        return 42;
      case BrandLogoSize.large:
        return 100;
    }
  }

  double get _fontSize {
    switch (size) {
      case BrandLogoSize.small:
        return 16;
      case BrandLogoSize.medium:
        return 24;
      case BrandLogoSize.large:
        return 38;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? (inverted ? Colors.white : AppColors.textHeadline);

    if (useIconOnly) {
      return _buildLogoImage();
    }

    final logoText = Text(
      'AgriDirect',
      style: GoogleFonts.plusJakartaSans(
        fontSize: _fontSize,
        fontWeight: FontWeight.w800,
        color: textColor,
        letterSpacing: -1.2,
        height: 1.1,
      ),
    );

    if (_isVertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLogoImage(),
          if (showText) ...[
            const SizedBox(height: 16),
            logoText,
          ],
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildLogoImage(),
        if (showText) ...[
          const SizedBox(width: 14),
          logoText,
        ],
      ],
    );
  }

  Widget _buildLogoImage() {
    return Container(
      width: _logoSize,
      height: _logoSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(_logoSize * 0.3),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.1),
            blurRadius: 1,
            spreadRadius: -2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Glass shine effect
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_logoSize * 0.3),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          // Inner border
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_logoSize * 0.3),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.all(_logoSize * 0.15),
              child: Image.asset(
                'assets/icon/logo_v2.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.eco_rounded,
                    color: Colors.white,
                    size: _logoSize * 0.55,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
