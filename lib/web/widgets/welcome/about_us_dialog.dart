import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/animated_components.dart';

class AboutUsDialog extends StatelessWidget {
  const AboutUsDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AboutUsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 700;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: isMobile ? 24 : 40,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 800,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF044E38), Color(0xFF065F46)],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.eco_rounded, color: AgriColors.lime300, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'About AgriDirect',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Empowering Filipino Farmers & Nourishing Communities',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                      hoverColor: Colors.white10,
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),

              // Scrollable Body
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 20 : 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mission Hero
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AgriColors.emerald50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AgriColors.emerald200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.handshake_rounded, color: AgriColors.emerald700, size: 28),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Our Vision & Core Mission',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AgriColors.emerald900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'AgriDirect is a digital agricultural ecosystem established to bridge the gap between local agrarian reform beneficiaries, independent farmers, and Filipino consumers. By eliminating unnecessary middleman layers, we ensure farmers receive honest farm-gate prices while consumers enjoy fresh, traceable harvest.',
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      color: const Color(0xFF1E293B),
                                      height: 1.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // 3 Pillars
                      Text(
                        'Our Core Pillars',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildPillar(
                        icon: Icons.verified_user_rounded,
                        title: '1. Department of Agriculture (DA) Quality Standards',
                        description: 'We adhere to DA technical guidelines on food safety, organic certifications, and sustainable soil stewardship.',
                      ),
                      const SizedBox(height: 12),
                      _buildPillar(
                        icon: Icons.price_check_rounded,
                        title: '2. Transparent Fair Trade Pricing',
                        description: 'Farmers set their own fair harvest prices. 100% of product pricing goes directly to the growers and their community cooperatives.',
                      ),
                      const SizedBox(height: 12),
                      _buildPillar(
                        icon: Icons.local_shipping_rounded,
                        title: '3. Farm-to-Table Freshness & Pre-Orders',
                        description: 'Crops are harvested only after confirmed customer orders and delivered with optimal cold-chain and ventilated care within 24 hours.',
                      ),

                      const SizedBox(height: 28),
                      // DA Collaboration note
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEFCE8),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFEF08A)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.military_tech_rounded, color: Color(0xFFCA8A04), size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Recognized as an innovative agricultural trade partner aligned with national food security and agrarian empowerment programs.',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: const Color(0xFF854D0E),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF044E38),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Close',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillar({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AgriColors.emerald50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AgriColors.emerald700, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
