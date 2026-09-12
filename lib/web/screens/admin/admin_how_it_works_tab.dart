import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/admin/admin_service.dart';
import 'admin_ui.dart';

/// AdminHowItWorksTab
/// Practical, step-by-step User Guide for administrators explaining
/// how to navigate, manage, and use every feature of the AgriDirect Admin Console.
class AdminHowItWorksTab extends StatefulWidget {
  final AdminService adminService;
  final void Function(int tabIndex)? onNavigateTab;

  const AdminHowItWorksTab({
    super.key,
    required this.adminService,
    this.onNavigateTab,
  });

  @override
  State<AdminHowItWorksTab> createState() => _AdminHowItWorksTabState();
}

class _AdminHowItWorksTabState extends State<AdminHowItWorksTab> {
  int _selectedTabFilter = 0;
  int _expandedFeatureIndex = 0;

  final List<Map<String, dynamic>> _tabsList = [
    {'name': 'All Admin Features', 'icon': Icons.apps_rounded},
    {'name': 'Dashboard', 'icon': Icons.dashboard_rounded, 'tab': 0},
    {'name': 'Farmers', 'icon': Icons.agriculture_rounded, 'tab': 1},
    {'name': 'Customers', 'icon': Icons.people_rounded, 'tab': 2},
    {'name': 'Products', 'icon': Icons.inventory_2_rounded, 'tab': 3},
    {'name': 'Content', 'icon': Icons.article_rounded, 'tab': 4},
    {'name': 'Moderation', 'icon': Icons.gavel_rounded, 'tab': 5},
    {'name': 'System Logs', 'icon': Icons.history_rounded, 'tab': 6},
    {'name': 'Push & Weather', 'icon': Icons.campaign_rounded, 'tab': 7},
    {'name': 'Support Tickets', 'icon': Icons.support_agent_rounded, 'tab': 8},
    {'name': 'Settings', 'icon': Icons.settings_rounded, 'tab': 10},
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildQuickOverviewCards(),
          const SizedBox(height: 28),
          _buildTabSelectorPills(),
          const SizedBox(height: 24),
          _buildFeatureGuidesList(),
          const SizedBox(height: 36),
          _buildAdminTipsAndBestPractices(),
          const SizedBox(height: 36),
          _buildAdminFaq(),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  // ─── 1. Header ─────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF003822), Color(0xFF005A36), Color(0xFF065F46)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AdminUi.radiusLg,
        boxShadow: AdminUi.shadowMd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.help_outline_rounded, color: Color(0xFF86EFAC), size: 14),
                      const SizedBox(width: 8),
                      Text(
                        'ADMIN USER GUIDE & FEATURE MANUAL',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF86EFAC),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'How to Use the AgriDirect Admin Console',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Learn how each tab works, how to manage farmers and customers, how to dispatch push alerts, approve products, and resolve support requests.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Container(
            width: 260,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: AdminUi.radiusMd,
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tips_and_updates_rounded, color: Color(0xFFFDE047), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Admin Daily Checklist',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildChecklistItem('1. Review pending farmer verifications'),
                _buildChecklistItem('2. Check open support tickets'),
                _buildChecklistItem('3. Resolve reported community posts'),
                _buildChecklistItem('4. Check today’s weather alerts'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: Colors.white.withValues(alpha: 0.9),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ─── 2. Quick Overview Cards ──────────────────────────────────────────────
  Widget _buildQuickOverviewCards() {
    final highlights = [
      {
        'title': 'Verify Farmers',
        'desc': 'Approve RSBSA farmer IDs and farm locations to grant verified badges.',
        'icon': Icons.agriculture_rounded,
        'color': const Color(0xFF0284C7),
        'tab': 1,
      },
      {
        'title': 'Send Push & Weather',
        'desc': 'Send instant notifications and weather storm warnings to phones.',
        'icon': Icons.campaign_rounded,
        'color': const Color(0xFF16A34A),
        'tab': 7,
      },
      {
        'title': 'Review Products',
        'desc': 'Inspect fresh produce and pre-order batches posted by farmers.',
        'icon': Icons.inventory_2_rounded,
        'color': const Color(0xFFD97706),
        'tab': 3,
      },
      {
        'title': 'Resolve Support',
        'desc': 'Help farmers and buyers with account issues and order inquiries.',
        'icon': Icons.support_agent_rounded,
        'color': const Color(0xFF7C3AED),
        'tab': 8,
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1000;
        final count = isCompact ? 2 : 4;
        final cardWidth = (constraints.maxWidth - (count - 1) * 16) / count;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: highlights.map((h) {
            final color = h['color'] as Color;
            return InkWell(
              onTap: () {
                if (widget.onNavigateTab != null) {
                  widget.onNavigateTab!(h['tab'] as int);
                }
              },
              borderRadius: AdminUi.radiusMd,
              child: Container(
                width: cardWidth,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AdminUi.radiusMd,
                  border: Border.all(color: AdminUi.border),
                  boxShadow: AdminUi.shadowSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(h['icon'] as IconData, color: color, size: 20),
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_forward_rounded, size: 16, color: AdminUi.textMuted),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      h['title'] as String,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AdminUi.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      h['desc'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AdminUi.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ─── 3. Tab Selector Pills ────────────────────────────────────────────────
  Widget _buildTabSelectorPills() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_tabsList.length, (index) {
          final isSelected = _selectedTabFilter == index;
          final item = _tabsList[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(
                item['icon'] as IconData,
                size: 16,
                color: isSelected ? Colors.white : AdminUi.textMuted,
              ),
              label: Text(
                item['name'] as String,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : AdminUi.textSecondary,
                ),
              ),
              selected: isSelected,
              selectedColor: AdminUi.brand,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: isSelected ? AdminUi.brand : AdminUi.border,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              onSelected: (selected) {
                if (selected) setState(() => _selectedTabFilter = index);
              },
            ),
          );
        }),
      ),
    );
  }

  // ─── 4. Feature Guides List ───────────────────────────────────────────────
  Widget _buildFeatureGuidesList() {
    final guides = _getFeatureGuides();
    final filtered = guides.where((g) {
      if (_selectedTabFilter == 0) return true;
      final selectedTabName = _tabsList[_selectedTabFilter]['name'];
      return g['tab_name'] == selectedTabName;
    }).toList();

    return Column(
      children: List.generate(filtered.length, (index) {
        final g = filtered[index];
        final isExpanded = _expandedFeatureIndex == index;
        final color = g['color'] as Color;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AdminUi.radiusMd,
            border: Border.all(
              color: isExpanded ? color.withValues(alpha: 0.5) : AdminUi.border,
              width: isExpanded ? 1.5 : 1.0,
            ),
            boxShadow: isExpanded ? AdminUi.shadowMd : AdminUi.shadowSm,
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _expandedFeatureIndex = isExpanded ? -1 : index;
                  });
                },
                borderRadius: AdminUi.radiusMd,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(g['icon'] as IconData, color: color, size: 24),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    g['tab_name'] as String,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '• ${g['steps_count']} easy steps',
                                  style: GoogleFonts.inter(fontSize: 12, color: AdminUi.textMuted),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              g['title'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AdminUi.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              g['subtitle'] as String,
                              style: GoogleFonts.inter(fontSize: 13, color: AdminUi.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: AdminUi.textMuted,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded) ...[
                const Divider(height: 1, color: AdminUi.border),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step-by-Step Instructions:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AdminUi.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...(g['steps'] as List<Map<String, dynamic>>).map((step) {
                        return _buildInstructionStep(step, color);
                      }),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lightbulb_outline_rounded, color: color, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                g['tip'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AdminUi.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (g['tab_index'] != null) ...[
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: () {
                                  if (widget.onNavigateTab != null) {
                                    widget.onNavigateTab!(g['tab_index'] as int);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: color,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                                label: Text(
                                  'Open ${g['tab_name']}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _buildInstructionStep(Map<String, dynamic> step, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step['num'].toString(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step['action'] as String,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AdminUi.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step['detail'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AdminUi.textSecondary,
                    height: 1.45,
                  ),
                ),
                if (step['button_click'] != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.touch_app_rounded, size: 14, color: Color(0xFF475569)),
                        const SizedBox(width: 6),
                        Text(
                          'Button: "${step['button_click']}"',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF334155),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 5. Admin Tips & Best Practices ───────────────────────────────────────
  Widget _buildAdminTipsAndBestPractices() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AdminUi.radiusLg,
        border: Border.all(color: AdminUi.border),
        boxShadow: AdminUi.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AdminUi.brand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.verified_user_rounded, color: AdminUi.brand, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin Best Practices & Safety Rules',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AdminUi.textPrimary,
                    ),
                  ),
                  Text(
                    'Follow these standard rules when managing users and broadcasting alerts.',
                    style: GoogleFonts.inter(fontSize: 12, color: AdminUi.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildBestPracticeItem(
            'Double-Check Verification Documents',
            'Before clicking "Verify", verify that the farmer photo, valid ID, and RSBSA registration number are clear and match Pangasinan municipality records.',
            Icons.document_scanner_rounded,
            const Color(0xFF0284C7),
          ),
          _buildBestPracticeItem(
            'Keep Push Broadcasts Clear & Actionable',
            'When broadcasting storm warnings or harvest alerts, specify the affected municipality and give direct advice (e.g. "Harvest ripe crops immediately, secure drainage furrows").',
            Icons.notifications_active_rounded,
            const Color(0xFF16A34A),
          ),
          _buildBestPracticeItem(
            'Handle Suspensions with Reason Notes',
            'When suspending a spammer or fraudulent account, always type a clear explanation note so other admins and support staff have context.',
            Icons.security_rounded,
            const Color(0xFFDC2626),
          ),
        ],
      ),
    );
  }

  Widget _buildBestPracticeItem(String title, String desc, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
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
                    color: AdminUi.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AdminUi.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 6. Admin FAQs ─────────────────────────────────────────────────────────
  Widget _buildAdminFaq() {
    final faqs = [
      {
        'q': 'How does Farmer Auto-Verification work?',
        'a': 'AgriDirect uses automated on-device biometric and document verification. When a farmer captures their PhilSys National ID (Front & Back) and live selfie, the system cross-checks PSA cryptographic QR data, OCR legal name, birthdate, and facial liveness in real time. If confidence is ≥ 85%, the farmer is instantly auto-verified with zero waiting time.',
      },
      {
        'q': 'What happens if a farmer fails Auto-Verification?',
        'a': 'They are not rejected. Submissions below 85% confidence (due to camera blur, nickname mismatch, or lighting) are safely routed to the "Pending Verification" queue in the Farmers tab (Tab 1). Diagnostic notes (e.g. "Name similarity 76%") are attached so you can inspect the ID and verify them with 1 click.',
      },
      {
        'q': 'How do I approve a pending farmer account?',
        'a': 'Go to the "Farmers" tab (Tab 1), select the "Pending Verification" filter pill, click on the farmer row to view their uploaded ID, selfie, and diagnostic breakdown, then click the green "Confirm Verification" button.',
      },
      {
        'q': 'How do I send a weather storm alert to all farmers?',
        'a': 'Go to "Push & Weather" (Tab 7), click "Live Weather & Typhoon AI", select Audience as "All Farmers", review the AI-suggested title and safety message, and click "Dispatch Broadcast".',
      },
      {
        'q': 'Where do I find deleted posts or admin actions?',
        'a': 'Go to the "System Logs" tab (Tab 6). Every time an admin verifies a farmer, deletes a post, sends a notification, or suspends a user, it is automatically logged here with the exact date, time, and admin name.',
      },
      {
        'q': 'How do I publish a new farming guide or Department of Agriculture article?',
        'a': 'Go to the "Content" tab (Tab 4), click the green "+ Create Article" button at the top right, fill in the title, summary, content, category, and cover image, then click "Publish Article".',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AdminUi.radiusLg,
        border: Border.all(color: AdminUi.border),
        boxShadow: AdminUi.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Frequently Asked Admin Questions',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AdminUi.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...faqs.map((faq) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AdminUi.border),
                ),
                child: ExpansionTile(
                  shape: const RoundedRectangleBorder(side: BorderSide.none),
                  collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                  title: Text(
                    faq['q']!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AdminUi.textPrimary,
                    ),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Text(
                      faq['a']!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AdminUi.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ─── 7. Feature Guides Data ────────────────────────────────────────────────
  List<Map<String, dynamic>> _getFeatureGuides() {
    return [
      {
        'tab_name': 'Farmers',
        'tab_index': 1,
        'title': 'How to Review & Verify Farmer Accounts',
        'subtitle': 'Review submitted farmer registrations, check RSBSA certifications, and approve storefronts.',
        'icon': Icons.agriculture_rounded,
        'color': const Color(0xFF0284C7),
        'steps_count': 4,
        'tip': 'Verified farmers get the green certified badge and can list crop pre-orders.',
        'steps': [
          {
            'num': 1,
            'action': 'Open the Farmers Tab',
            'detail': 'Click on "Farmers" in the left sidebar menu.',
            'button_click': 'Farmers',
          },
          {
            'num': 2,
            'action': 'Filter by Pending Verifications',
            'detail': 'Click the "Pending" pill at the top of the table to see farmers awaiting approval.',
            'button_click': 'Pending',
          },
          {
            'num': 3,
            'action': 'Inspect Farmer Credentials',
            'detail': 'Click on any farmer row to view their government ID photo, RSBSA registration number, and farm location coordinates.',
            'button_click': 'View Details',
          },
          {
            'num': 4,
            'action': 'Approve or Reject Application',
            'detail': 'Click the green "Verify Farmer" button to grant their verified badge, or click "Reject" with a custom note if details are incomplete.',
            'button_click': 'Verify Farmer',
          },
        ],
      },
      {
        'tab_name': 'Push & Weather',
        'tab_index': 7,
        'title': 'How to Send Push Notifications & Weather Alerts',
        'subtitle': 'Send instant physical phone lock screen notifications and AI-assisted weather storm warnings.',
        'icon': Icons.campaign_rounded,
        'color': const Color(0xFF16A34A),
        'steps_count': 4,
        'tip': 'You can test sending to your own device first using the "Test Me (Admin)" audience option.',
        'steps': [
          {
            'num': 1,
            'action': 'Open the Push & Weather Hub',
            'detail': 'Click "Push & Weather" in the left navigation sidebar.',
            'button_click': 'Push & Weather',
          },
          {
            'num': 2,
            'action': 'Choose Your Target Audience',
            'detail': 'Select who should receive the alert: "All Farmers", "All Customers", "Platform-Wide", or "Test Me (Admin)".',
            'button_click': 'Audience Selector',
          },
          {
            'num': 3,
            'action': 'Compose Message or Use AI Generator',
            'detail': 'Type your Title and Message, or click one of the quick AI templates (e.g., Typhoon Warning, Flash Sale, Harvest Advisory).',
            'button_click': 'Use Template',
          },
          {
            'num': 4,
            'action': 'Dispatch Broadcast',
            'detail': 'Review your live phone notification preview on the right, then click the green "Dispatch Broadcast" button.',
            'button_click': 'Dispatch Broadcast',
          },
        ],
      },
      {
        'tab_name': 'Customers',
        'tab_index': 2,
        'title': 'How to Manage Customer Accounts & Roles',
        'subtitle': 'Search users, check order history, manage admin permissions, and suspend abusive accounts.',
        'icon': Icons.people_rounded,
        'color': const Color(0xFF7C3AED),
        'steps_count': 3,
        'tip': 'You can grant or remove Admin privileges directly from the user action menu.',
        'steps': [
          {
            'num': 1,
            'action': 'Open the Customers Tab',
            'detail': 'Click "Customers" in the left sidebar menu.',
            'button_click': 'Customers',
          },
          {
            'num': 2,
            'action': 'Search for a User',
            'detail': 'Use the search bar at the top to find a customer by full name, email, or phone number.',
            'button_click': 'Search',
          },
          {
            'num': 3,
            'action': 'Perform User Actions',
            'detail': 'Click the three-dot menu on any user row to view their profile, change their role (Admin/Customer), or suspend their account if needed.',
            'button_click': 'User Actions',
          },
        ],
      },
      {
        'tab_name': 'Products',
        'tab_index': 3,
        'title': 'How to Inspect & Moderate Farm Products',
        'subtitle': 'Review crop listings, verify fair pricing, check stock levels, and delete invalid items.',
        'icon': Icons.inventory_2_rounded,
        'color': const Color(0xFFD97706),
        'steps_count': 3,
        'tip': 'Check the "Out of Stock" filter to see inventory trends across farms.',
        'steps': [
          {
            'num': 1,
            'action': 'Open the Products Tab',
            'detail': 'Click "Products" in the left sidebar.',
            'button_click': 'Products',
          },
          {
            'num': 2,
            'action': 'Filter by Category or Stock',
            'detail': 'Use the category dropdown (Vegetables, Fruits, Rice, Pre-orders) to filter product items.',
            'button_click': 'Filter Category',
          },
          {
            'num': 3,
            'action': 'Manage Listing Status',
            'detail': 'Click on a product to view details or click the trash icon to remove fraudulent/inappropriate listings.',
            'button_click': 'Delete Product',
          },
        ],
      },
      {
        'tab_name': 'Content',
        'tab_index': 4,
        'title': 'How to Publish Farming Articles & Guides',
        'subtitle': 'Author official Department of Agriculture farming tips, pest guides, and news for farmers.',
        'icon': Icons.article_rounded,
        'color': const Color(0xFF0F766E),
        'steps_count': 3,
        'tip': 'Articles appear directly on the mobile app and web DA Articles feed for all farmers.',
        'steps': [
          {
            'num': 1,
            'action': 'Open the Content Tab',
            'detail': 'Click "Content" in the left navigation sidebar.',
            'button_click': 'Content',
          },
          {
            'num': 2,
            'action': 'Click "+ Create Article"',
            'detail': 'Click the green "+ Create Article" button at the top right.',
            'button_click': '+ Create Article',
          },
          {
            'num': 3,
            'action': 'Fill in Article Details & Publish',
            'detail': 'Enter the article title, category, cover image URL, and markdown body, then click "Publish Article".',
            'button_click': 'Publish Article',
          },
        ],
      },
      {
        'tab_name': 'Moderation',
        'tab_index': 5,
        'title': 'How to Resolve Community Reports & Moderation',
        'subtitle': 'Review flagged forum posts and comments, remove harmful content, and warn offenders.',
        'icon': Icons.gavel_rounded,
        'color': const Color(0xFFDC2626),
        'steps_count': 3,
        'tip': 'Resolving a report automatically archives it and logs the decision.',
        'steps': [
          {
            'num': 1,
            'action': 'Open the Moderation Tab',
            'detail': 'Click "Moderation" in the left sidebar.',
            'button_click': 'Moderation',
          },
          {
            'num': 2,
            'action': 'Inspect Flagged Post',
            'detail': 'Click on the report to view the reported content, reason (spam, harassment, fraud), and reporter name.',
            'button_click': 'View Report',
          },
          {
            'num': 3,
            'action': 'Take Moderation Action',
            'detail': 'Click "Delete Post" to remove it from the platform or "Dismiss Report" if the content is harmless.',
            'button_click': 'Resolve Report',
          },
        ],
      },
      {
        'tab_name': 'System Logs',
        'tab_index': 6,
        'title': 'How to Audit Admin Activity & System Logs',
        'subtitle': 'View chronological records of every admin action, security event, and push broadcast.',
        'icon': Icons.history_rounded,
        'color': const Color(0xFF475569),
        'steps_count': 3,
        'tip': 'Logs are permanent and cannot be edited or deleted, ensuring full accountability.',
        'steps': [
          {
            'num': 1,
            'action': 'Open System Logs',
            'detail': 'Click "System Logs" in the left sidebar.',
            'button_click': 'System Logs',
          },
          {
            'num': 2,
            'action': 'Filter by Activity Domain',
            'detail': 'Filter logs by "All", "Security", "Users", "Products", or "System" to isolate specific events.',
            'button_click': 'Filter Logs',
          },
          {
            'num': 3,
            'action': 'View Log Details',
            'detail': 'Click any log entry to see the exact time, admin who performed it, and affected target entity.',
            'button_click': 'Expand Log Entry',
          },
        ],
      },
      {
        'tab_name': 'Support Tickets',
        'tab_index': 8,
        'title': 'How to Answer User Support Tickets',
        'subtitle': 'Help farmers and customers solve order issues, payment disputes, and app inquiries.',
        'icon': Icons.support_agent_rounded,
        'color': const Color(0xFFEA580C),
        'steps_count': 3,
        'tip': 'Set ticket status to "In Progress" while working on a solution, and "Resolved" when finished.',
        'steps': [
          {
            'num': 1,
            'action': 'Open Support Tickets',
            'detail': 'Click "Support Tickets" in the left sidebar.',
            'button_click': 'Support Tickets',
          },
          {
            'num': 2,
            'action': 'Select an Open Ticket',
            'detail': 'Click on any ticket in the list to read the user’s inquiry, attached screenshots, and contact info.',
            'button_click': 'View Ticket',
          },
          {
            'num': 3,
            'action': 'Reply and Update Status',
            'detail': 'Type your response and set the ticket status to "Resolved" to close the issue.',
            'button_click': 'Resolve Ticket',
          },
        ],
      },
      {
        'tab_name': 'Settings',
        'tab_index': 10,
        'title': 'How to Configure Platform Settings & Preferences',
        'subtitle': 'Manage admin notifications, security preferences, and view platform configuration.',
        'icon': Icons.settings_rounded,
        'color': const Color(0xFF64748B),
        'steps_count': 3,
        'tip': 'Check here to update your admin display preferences and security settings.',
        'steps': [
          {
            'num': 1,
            'action': 'Open Settings',
            'detail': 'Click "Settings" at the bottom of the left sidebar.',
            'button_click': 'Settings',
          },
          {
            'num': 2,
            'action': 'Review System Preferences',
            'detail': 'Review push notification settings, admin profile information, and security options.',
            'button_click': 'Preferences',
          },
          {
            'num': 3,
            'action': 'Save Changes',
            'detail': 'Click "Save Settings" to apply any updates to your admin preferences.',
            'button_click': 'Save Settings',
          },
        ],
      },
    ];
  }
}

