import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

/// Professional Privacy Policy screen for AgriDirect
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: const Color(0xFF0F172A),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Shield Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'RA 10173 Compliant (Data Privacy Act)',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your Privacy Matters',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'We are dedicated to safeguarding your personal data, farm location records, and mobile authentication information.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildPrivacyItem(
              icon: Icons.badge_outlined,
              title: '1. Information We Collect',
              content:
                  'We collect necessary information during account setup and usage:\n'
                  '• Personal details: Name, email address, profile picture.\n'
                  '• Mobile verification: Verified Philippine phone number used for SMS OTP security.\n'
                  '• Farm & delivery records: Farm location coordinates, residential address, and harvest listings.',
            ),

            _buildPrivacyItem(
              icon: Icons.verified_user_outlined,
              title: '2. Purpose & Use of Data',
              content:
                  'Your data is processed strictly for:\n'
                  '• Account authentication & SMS OTP verification via secured gateways.\n'
                  '• Connecting buyers with nearby local farmers on the interactive farm radar.\n'
                  '• Facilitating order placement, fulfillment, and delivery updates.\n'
                  '• Preventing duplicate accounts, scam attempts, and fraudulent activity.',
            ),

            _buildPrivacyItem(
              icon: Icons.my_location_rounded,
              title: '3. Location & GPS Data',
              content:
                  'Farmer coordinates are utilized exclusively to showcase authentic local farms on the interactive map so consumers can find fresh produce nearby. Consumer live locations are only accessed with explicit in-app permission during radius filtering and order delivery address selection.',
            ),

            _buildPrivacyItem(
              icon: Icons.lock_outline_rounded,
              title: '4. Data Security & Storage',
              content:
                  'All sensitive data is encrypted in transit (TLS/HTTPS) and securely stored within enterprise-grade Supabase Postgres infrastructure with Row Level Security (RLS) policies ensuring users only access authorized records.',
            ),

            _buildPrivacyItem(
              icon: Icons.manage_accounts_outlined,
              title: '5. Your Rights as a Data Subject',
              content:
                  'Under the Philippine Data Privacy Act of 2012 (RA 10173), you have the right to access, rectify, or request the deletion of your personal data at any time via App Settings or by submitting a support ticket.',
            ),

            const SizedBox(height: 20),

            // DPO Contact Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mail_outline_rounded, color: Color(0xFF2563EB), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Data Privacy Inquiries',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'privacy@agridirect.ph',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyItem({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: const Color(0xFF475569),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
