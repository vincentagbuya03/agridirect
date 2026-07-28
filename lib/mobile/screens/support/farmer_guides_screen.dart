import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/styles/app_theme.dart';

class FarmerGuidesScreen extends StatelessWidget {
  const FarmerGuidesScreen({super.key});

  final List<Map<String, dynamic>> _guides = const [
    {
      'title': 'How to Post & Manage Products',
      'desc': 'Learn how to list crop inventory, upload photos, set pricing per bundle/kg, and manage stock.',
      'icon': Icons.inventory_2_outlined,
      'color': Color(0xFF10B981),
      'steps': [
        'Open Farmer Dashboard -> Products tab.',
        'Tap the "+ Add Product" button at the bottom right.',
        'Enter product name, description, unit price, and photos.',
        'Tap Publish to make your product visible on the marketplace.',
      ],
    },
    {
      'title': 'Setting Up Pre-Orders & Harvest Schedules',
      'desc': 'Build buyer interest before harvest by configuring harvest timelines.',
      'icon': Icons.date_range_outlined,
      'color': Color(0xFF0EA5E9),
      'steps': [
        'Select "Pre-Order" toggle when listing a crop.',
        'Set estimated harvest days or target ready date.',
        'Buyers can reserve bundles ahead of time.',
        'Update crop status milestones as the crop grows.',
      ],
    },
    {
      'title': 'Creating Shop Vouchers & Discounts',
      'desc': 'Reward your followers and boost sales by offering custom shop vouchers.',
      'icon': Icons.confirmation_number_outlined,
      'color': Color(0xFF8B5CF6),
      'steps': [
        'Navigate to Profile -> Shop Vouchers.',
        'Set voucher code name, discount percentage or flat amount.',
        'Set minimum purchase requirement.',
        'Vouchers automatically appear on your public farm page.',
      ],
    },
    {
      'title': 'Delivery & Farm Pickup Options',
      'desc': 'Manage Cash on Delivery (COD) and Cash on Pickup (COP) settings.',
      'icon': Icons.local_shipping_outlined,
      'color': Color(0xFFF59E0B),
      'steps': [
        'Configure your farm location coordinates in Settings.',
        'Enable COD or COP preferences.',
        'When orders are placed, view buyer address & contact info.',
        'Mark order as Shipped or Ready for Pickup.',
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textHeadline, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Farmer Guides & Tutorials',
          style: AppTextStyles.headline3.copyWith(fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(20.0),
          physics: const BouncingScrollPhysics(),
          itemCount: _guides.length,
          itemBuilder: (context, index) {
            final guide = _guides[index];
            final Color color = guide['color'];
            final List<String> steps = guide['steps'];

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF1F5F9)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(guide['icon'] as IconData, color: color, size: 24),
                ),
                title: Text(
                  guide['title'].toString(),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textHeadline,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    guide['desc'].toString(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSubtle,
                      height: 1.4,
                    ),
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(steps.length, (sIndex) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${sIndex + 1}',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    steps[sIndex],
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: const Color(0xFF334155),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
