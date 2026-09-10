import 'package:flutter/material.dart';
import '../../localization/farmer_locale_service.dart';
import '../../styles/farmer_theme.dart';

/// Instant bilingual toggle pill (`🇵🇭 Filipino | 🇺🇸 English`)
/// allowing farmers to switch interface language with a single tap.
class FarmerLanguageToggle extends StatelessWidget {
  final bool compact;

  const FarmerLanguageToggle({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final service = FarmerLocaleService.instance;

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final isFil = service.isFilipino;

        return InkWell(
          onTap: () => service.toggleLanguage(),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 14,
              vertical: compact ? 4 : 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: FarmerTheme.borderCrisp, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildOption(
                  label: compact ? '🇵🇭 FIL' : '🇵🇭 Filipino',
                  isActive: isFil,
                ),
                Container(
                  width: 1,
                  height: 14,
                  color: const Color(0xFFCBD5E1),
                  margin: EdgeInsets.symmetric(horizontal: compact ? 2 : 6),
                ),
                _buildOption(
                  label: compact ? '🇺🇸 EN' : '🇺🇸 English',
                  isActive: !isFil,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOption({required String label, required bool isActive}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: isActive ? FarmerTheme.softMint : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 11.5 : 13,
          fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
          color: isActive ? FarmerTheme.primaryAction : FarmerTheme.textMuted,
        ),
      ),
    );
  }
}
