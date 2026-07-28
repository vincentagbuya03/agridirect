import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PricingPlansDialog extends StatelessWidget {
  static const Color primary = Color(0xFF16A34A);
  static const Color dark = Color(0xFF111827);
  static const Color muted = Color(0xFF6B7280);

  const PricingPlansDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const PricingPlansDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.sell_rounded, color: primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Platform Pricing Plans',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: dark,
                  ),
                ),
                Text(
                  'Simple, transparent pricing for buyers and local farmers',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              _buildPlanCard(
                name: 'Free Buyer Account',
                price: '₱0 / forever',
                badge: 'Popular',
                features: [
                  'Direct farm-to-table access',
                  'Real-time order tracking & status',
                  'Cash on Delivery & Cash on Pickup',
                  'Direct messaging with verified farmers',
                ],
              ),
              const SizedBox(height: 16),
              _buildPlanCard(
                name: 'Farmer Partner Plan',
                price: '₱0 / month (Beta Offer)',
                badge: 'Recommended',
                isHighlighted: true,
                features: [
                  'Unlimited product listings & pre-orders',
                  'Priority search placement on marketplace',
                  'Real-time sales analytics dashboard',
                  'Direct customer inquiry notifications',
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Close',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: muted),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required String name,
    required String price,
    required String badge,
    required List<String> features,
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isHighlighted ? primary.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? primary.withValues(alpha: 0.4) : Colors.grey[200]!,
          width: isHighlighted ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: dark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isHighlighted ? primary : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isHighlighted ? Colors.white : dark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            price,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: primary,
            ),
          ),
          const SizedBox(height: 12),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: dark.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
