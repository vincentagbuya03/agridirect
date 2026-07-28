import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SeasonalCalendarDialog extends StatelessWidget {
  static const Color primary = Color(0xFF16A34A);
  static const Color dark = Color(0xFF111827);
  static const Color muted = Color(0xFF6B7280);

  const SeasonalCalendarDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const SeasonalCalendarDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final crops = [
      {'crop': 'Rice / Palay', 'season': 'October - December', 'peak': 'Peak Season', 'icon': Icons.grain_rounded},
      {'crop': 'Fresh Vegetables', 'season': 'January - May', 'peak': 'High Demand', 'icon': Icons.eco_rounded},
      {'crop': 'Mangoes', 'season': 'March - June', 'peak': 'Peak Harvest', 'icon': Icons.eco_outlined},
      {'crop': 'Corn / Yellow Corn', 'season': 'June - August', 'peak': 'Mid-Year Harvest', 'icon': Icons.grass_rounded},
      {'crop': 'Native Onions & Garlic', 'season': 'February - April', 'peak': 'Dry Season Harvest', 'icon': Icons.restaurant_rounded},
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
            child: const Icon(Icons.calendar_month_rounded, color: primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seasonal Harvest Calendar',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: dark,
                  ),
                ),
                Text(
                  'Optimal agricultural cycles in the Philippines',
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
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              ...crops.map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(item['icon'] as IconData, color: primary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['crop'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: dark,
                              ),
                            ),
                            Text(
                              item['season'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          item['peak'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: primary,
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
