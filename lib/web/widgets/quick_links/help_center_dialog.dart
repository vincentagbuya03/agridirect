import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HelpCenterDialog extends StatelessWidget {
  static const Color primary = Color(0xFF16A34A);
  static const Color dark = Color(0xFF111827);
  static const Color muted = Color(0xFF6B7280);

  const HelpCenterDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const HelpCenterDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        'q': 'How do I buy fresh products directly from local farmers?',
        'a': 'Browse our marketplace catalog, select fresh produce or pre-orders, add them to your cart, and complete your checkout via Cash on Delivery (COD) or Cash on Pickup (COP).'
      },
      {
        'q': 'Are the products guaranteed fresh and authentic?',
        'a': 'Yes! All products listed on AgriDirect originate from local verified agricultural sellers and farms in your region.'
      },
      {
        'q': 'How does Pre-Order listing work?',
        'a': 'Pre-orders allow farmers to secure buyers prior to crop harvest. You can place pre-orders in advance to guarantee fresh delivery upon harvest day.'
      },
      {
        'q': 'How can I contact customer support directly?',
        'a': 'You can reach out to our dedicated support team via email at support@agridirect.ph or call 0912-235-4762.'
      },
    ];

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
            child: const Icon(Icons.help_center_rounded, color: primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AgriDirect Help Center',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: dark,
                  ),
                ),
                Text(
                  'Frequently asked questions & customer support',
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
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              ...faqs.map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.question_answer_rounded, color: primary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item['q']!,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: dark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 26),
                        child: Text(
                          item['a']!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: muted,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
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
}
