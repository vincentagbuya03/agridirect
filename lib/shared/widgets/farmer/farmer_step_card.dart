import 'package:flutter/material.dart';
import '../../styles/farmer_theme.dart';

/// Visual card component that groups related inputs into numbered,
/// clear steps with icons and status indicators.
class FarmerStepCard extends StatelessWidget {
  final String stepNumber;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final bool isCompleted;

  const FarmerStepCard({
    super.key,
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FarmerTheme.cardBorderRadius),
        border: Border.all(
          color: isCompleted ? FarmerTheme.primaryAction : FarmerTheme.borderCrisp,
          width: isCompleted ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isCompleted
                ? FarmerTheme.primaryAction.withValues(alpha: 0.08)
                : const Color(0x08000000),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? FarmerTheme.primaryAction
                      : FarmerTheme.softMint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isCompleted ? Icons.check_rounded : icon,
                  color: isCompleted ? Colors.white : FarmerTheme.primaryAction,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: FarmerTheme.sectionTitle.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: FarmerTheme.bodyMuted.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: FarmerTheme.softMint,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: FarmerTheme.primaryAction),
                  ),
                  child: Text(
                    'OK',
                    style: TextStyle(
                      color: FarmerTheme.primaryAction,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}
