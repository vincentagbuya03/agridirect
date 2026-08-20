import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

/// Professional Terms of Service screen for AgriDirect
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

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
          'Terms of Service',
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
            // Header Hero Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF065F46), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF059669).withValues(alpha: 0.25),
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
                      'Effective Date: August 2026',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'AgriDirect Platform Terms',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Please review these terms governing the direct marketplace relationship between Filipino farmers and consumers.',
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

            _buildSectionCard(
              number: '1',
              title: 'Platform Overview & Direct Trade',
              body:
                  'AgriDirect connects local farmers directly with consumers, restaurants, and wholesale buyers. AgriDirect facilitates the connection, communication, and order workflow, while product harvest quality and delivery commitments are directly managed between farmers and buyers.',
            ),

            _buildSectionCard(
              number: '2',
              title: 'Account Registration & Verification',
              body:
                  'To use AgriDirect features, users must provide accurate and verifiable information. Mobile numbers must be verified via our SMS OTP protocol. Users are solely responsible for maintaining the confidentiality of their credentials and all activities occurring under their accounts.',
            ),

            _buildSectionCard(
              number: '3',
              title: 'Orders, Pricing & Payments',
              body:
                  'Produce prices are set independently by registered farmers. Payment arrangements include Cash on Delivery (COD) and direct mobile wallet (e.g. GCash) transfers. Buyers are expected to honor confirmed orders upon arrival to avoid food wastage for our farmers.',
            ),

            _buildSectionCard(
              number: '4',
              title: 'Produce Quality & Freshness Guarantee',
              body:
                  'Farmers must upload authentic, recent photos and accurate descriptions of their agricultural produce. If delivered goods differ substantially or are spoiled upon arrival, buyers must document the issue immediately through the Order Resolution feature.',
            ),

            _buildSectionCard(
              number: '5',
              title: 'Prohibited Conduct & Anti-Fraud',
              body:
                  'Users may not engage in price gouging, false product representation, harassment, bogus ordering, or circumventing platform verification controls. Violations will result in immediate account suspension and blacklisting.',
            ),

            _buildSectionCard(
              number: '6',
              title: 'Modifications to Terms',
              body:
                  'AgriDirect reserves the right to amend these Terms of Service at any time. Continued use of the platform after updates constitutes your agreement to the modified terms.',
            ),

            const SizedBox(height: 20),

            // Footer Notice
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_outlined, color: Color(0xFF64748B), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Questions about our Terms? Reach out via Help Center.',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF475569),
                      ),
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

  Widget _buildSectionCard({
    required String number,
    required String title,
    required String body,
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
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                alignment: Alignment.center,
                child: Text(
                  number,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF059669),
                  ),
                ),
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
            body,
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
