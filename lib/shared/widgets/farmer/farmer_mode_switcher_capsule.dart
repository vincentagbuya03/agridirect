import 'package:flutter/material.dart';
import '../../localization/farmer_locale_service.dart';
import '../../styles/farmer_theme.dart';

/// High-visibility capsule button that guarantees farmers can always
/// easily switch between Farmer Store (Selling) and Buyer View (Shopping).
class FarmerModeSwitcherCapsule extends StatelessWidget {
  final VoidCallback onSwitch;
  final bool isFarmerMode;
  final bool compact;

  const FarmerModeSwitcherCapsule({
    super.key,
    required this.onSwitch,
    this.isFarmerMode = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final locale = FarmerLocaleService.instance;

    return ListenableBuilder(
      listenable: locale,
      builder: (context, _) {
        final label = isFarmerMode
            ? locale.t('switch_to_consumer')
            : locale.t('switch_to_farmer');
        final icon = isFarmerMode
            ? Icons.shopping_basket_rounded
            : Icons.agriculture_rounded;
        final bg = isFarmerMode ? const Color(0xFF1E293B) : FarmerTheme.primaryAction;

        return InkWell(
          onTap: onSwitch,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 18,
              vertical: compact ? 8 : 12,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isFarmerMode
                    ? const Color(0xFF475569)
                    : const Color(0xFF166534),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: bg.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: compact ? 18 : 22, color: Colors.white),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 13 : 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
