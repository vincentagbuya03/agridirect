import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/localization/farmer_locale_service.dart';
import '../../../shared/styles/app_theme.dart';

class FarmerLanguageToggle extends StatelessWidget {
  final bool compact;

  const FarmerLanguageToggle({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FarmerLocaleService.instance,
      builder: (context, _) {
        final loc = FarmerLocaleService.instance;
        final isFil = loc.isFilipino;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => loc.toggleLocale(),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 6 : 8,
                vertical: compact ? 3 : 5,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFCBD5E1),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSegment(
                    label: 'EN',
                    isActive: !isFil,
                    compact: compact,
                  ),
                  const SizedBox(width: 2),
                  _buildSegment(
                    label: 'FIL',
                    isActive: isFil,
                    compact: compact,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSegment({
    required String label,
    required bool isActive,
    required bool compact,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: compact ? 10.5 : 12,
          fontWeight: FontWeight.w800,
          color: isActive ? Colors.white : const Color(0xFF64748B),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
