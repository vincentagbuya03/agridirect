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
        return 120;
    }
  }

  double get _fontSize {
    switch (size) {
      case BrandLogoSize.small:
        return 16;
      case BrandLogoSize.medium:
        return 24;
      case BrandLogoSize.large:
        return 42;
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
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.textHeadline.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(_logoSize * 0.22),
          child: Image.asset(
            'assets/icon/logo_v3.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
