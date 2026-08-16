import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/animated_components.dart';

class WelcomeInfoDialogs {
  static void showDeliveryInfo(BuildContext context) {
    _showGenericModal(
      context,
      title: 'Delivery & Logistics Information',
      icon: Icons.local_shipping_rounded,
      content: '''
AgriDirect works directly with local farmer cooperatives and temperature-controlled logistics partners to transport freshly harvested goods.

• Same-Day / Next-Day Delivery: For Metro Manila and surrounding agricultural corridors, produce ordered during morning harvest cycles arrives within 24 hours.
• Cold-Chain Packaging: Delicate vegetables, berries, and dairy are packed in insulated organic fiber coolers to preserve peak crispness and nutrient retention.
• Farm Direct Hubs: Orders are consolidated at municipal farmer hubs to minimize road travel time and prevent post-harvest shrinkage.
• Order Tracking: Real-time SMS and web dashboard notifications keep you updated as your order moves from the farm gate to your doorstep.
''',
    );
  }

  static void showReturnsGuarantee(BuildContext context) {
    _showGenericModal(
      context,
      title: '100% Farm-Fresh Quality Guarantee',
      icon: Icons.verified_rounded,
      content: '''
We stand 100% behind the harvest quality of our verified growers.

• 24-Hour Freshness Replacement: If any item arrives bruised, spoiled, or damaged during transport, snap a photo and report it via your order screen within 24 hours.
• Direct Grower Accountability: Our quality team reviews all feedback with the respective farm cooperative to continuously improve post-harvest packing standards.
• No-Fuss Credits: Instant store credit or full replacement on your next harvest shipment.
''',
    );
  }

  static void showDAStandards(BuildContext context) {
    _showGenericModal(
      context,
      title: 'DA Quality Standards & Agricultural Regulations',
      icon: Icons.account_balance_rounded,
      content: '''
AgriDirect strictly aligns with Department of Agriculture (DA) regulations and GAP (Good Agricultural Practices) guidelines:

• GAP Certification Verification: Registered farmers are verified through municipal agricultural offices (MAO) and provincial agrarian reform councils.
• Chemical Residue & MRL Compliance: Soil and pesticide records must meet maximum residue limit standards set by the Bureau of Plant Industry (BPI).
• Transparent Farm Logs: Buyers can view harvest dates, farm elevation, fertilizer type (organic compost / bio-organic), and harvest batch IDs.
• Sustainable Water Stewardship: Encouraging rain catchment and drip irrigation techniques to protect watershed basins.
''',
    );
  }

  static void showFarmerAssistanceForm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final formKey = GlobalKey<FormState>();
        final nameCtrl = TextEditingController();
        final farmLocCtrl = TextEditingController();
        final contactCtrl = TextEditingController();
        final detailsCtrl = TextEditingController();

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            width: 600,
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    color: const Color(0xFF044E38),
                    child: Row(
                      children: [
                        const Icon(Icons.support_agent_rounded, color: AgriColors.lime300, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'Farmer & DA Assistance Request',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Need assistance with crop listing, DA accreditation, soil testing, or logistics support? Fill out this quick inquiry.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF64748B),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: nameCtrl,
                            decoration: InputDecoration(
                              labelText: 'Your Name or Cooperative Name',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: farmLocCtrl,
                            decoration: InputDecoration(
                              labelText: 'Farm Location (Municipality, Province)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: contactCtrl,
                            decoration: InputDecoration(
                              labelText: 'Mobile Number / Email',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: detailsCtrl,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Inquiry / Technical Assistance Details',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.all(14),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Thank you! Your assistance request has been submitted to the DA Agro-Support Desk.'),
                                    backgroundColor: Color(0xFF044E38),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF044E38),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                'Submit Request',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static void showContactUs(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          width: 540,
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  color: const Color(0xFF044E38),
                  child: Row(
                    children: [
                      const Icon(Icons.contacts_rounded, color: AgriColors.lime300, size: 22),
                      const SizedBox(width: 12),
                      Text(
                        'Contact AgriDirect Team',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _contactTile(
                        icon: Icons.location_on_rounded,
                        title: 'Official Headquarters',
                        detail: 'AgriDirect Innovation Center, Elliptical Road, Diliman, Quezon City, Philippines',
                      ),
                      const SizedBox(height: 14),
                      _contactTile(
                        icon: Icons.phone_rounded,
                        title: 'Support & Hotline',
                        detail: '+63 (02) 8928-8741 / +63 917 123 4567\nMon - Sat: 7:00 AM - 6:00 PM',
                      ),
                      const SizedBox(height: 14),
                      _contactTile(
                        icon: Icons.email_rounded,
                        title: 'Email Correspondence',
                        detail: 'support@agridirect.ph / partnerships@agridirect.ph',
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF044E38),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _contactTile({
    required IconData icon,
    required String title,
    required String detail,
  }) {
    return Row(
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
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: const Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static void _showGenericModal(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String content,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          width: 640,
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  color: const Color(0xFF044E38),
                  child: Row(
                    children: [
                      Icon(icon, color: AgriColors.lime300, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content.trim(),
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          color: const Color(0xFF334155),
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF044E38),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
