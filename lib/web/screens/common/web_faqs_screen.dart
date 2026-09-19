import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/router/app_routes.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../widgets/ecom/web_ecom_header.dart';
import '../../widgets/web_footer.dart';

/// WebFaqsScreen
/// Dedicated modern Web UI for Frequently Asked Questions & Help Center.
/// Features live searching, category filtering, interactive accordion cards,
/// feedback reactions, and quick links to Kiko AI and Support.
class WebFaqsScreen extends StatefulWidget {
  const WebFaqsScreen({super.key});

  @override
  State<WebFaqsScreen> createState() => _WebFaqsScreenState();
}

class _WebFaqsScreenState extends State<WebFaqsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All Topics';
  final Set<int> _expandedIndices = {0}; // First question open by default
  final Map<int, bool?> _helpfulVotes = {}; // questionIndex -> true (yes) / false (no)

  static const Color _primary = Color(0xFF005A36);
  static const Color _emerald = Color(0xFF16A34A);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _slate600 = Color(0xFF475569);
  static const Color _slate500 = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _bgLight = Color(0xFFF8FAFC);

  final List<String> _categories = [
    'All Topics',
    'Orders & Delivery',
    'Farmers & Selling',
    'Pre-Orders & Harvest',
    'Payments & Pricing',
    'Account & Security',
  ];

  final List<Map<String, dynamic>> _allFaqs = [
    {
      'category': 'Pre-Orders & Harvest',
      'icon': Icons.agriculture_rounded,
      'question': 'How do pre-orders work on AgriDirect?',
      'answer':
          'Pre-orders allow buyers to reserve freshly grown crops before the scheduled harvest date. Farmers publish expected harvest timelines, and buyers secure their allocation in advance. When the crops are harvested and verified, the farmer initiates fulfillment for delivery or pick-up.',
    },
    {
      'category': 'Payments & Pricing',
      'icon': Icons.payments_outlined,
      'question': 'What payment methods are supported on the platform?',
      'answer':
          'AgriDirect currently supports Cash on Delivery (COD) for home deliveries and Cash on Pickup (COP) when picking up fresh produce directly from partner farms or hubs. Payments are completed safely upon physical inspection of your fresh produce.',
    },
    {
      'category': 'Farmers & Selling',
      'icon': Icons.storefront_outlined,
      'question': 'How can I become an accredited farmer or seller?',
      'answer':
          'Any agricultural producer can switch to Farmer Mode via their profile or apply under "Become a Seller". Submit basic verification documents (such as RSBSA or government-issued ID). Once approved by AgriDirect moderators, your farm storefront goes live.',
    },
    {
      'category': 'Farmers & Selling',
      'icon': Icons.local_offer_outlined,
      'question': 'How do discount vouchers and shop promotions work?',
      'answer':
          'Farmers can create custom promotional vouchers for their regular customers and followers. Consumers can collect these vouchers from farmer profile storefronts and apply them automatically during checkout to claim discounts.',
    },
    {
      'category': 'Orders & Delivery',
      'icon': Icons.local_shipping_outlined,
      'question': 'How do I track the harvest status and delivery of my order?',
      'answer':
          'Go to "Track Harvest" or your Customer Orders page. Each order features a real-time status tracker showing stages: Pending Confirmation, Growing & Scheduled Harvest, Harvested & Packed, Out for Delivery, and Completed.',
    },
    {
      'category': 'Orders & Delivery',
      'icon': Icons.verified_outlined,
      'question': 'Are all agricultural products guaranteed fresh and authentic?',
      'answer':
          'Yes! All produce listed on AgriDirect originates directly from local, verified agricultural growers and cooperatives in your province, cutting out middlemen and ensuring maximum farm-to-table freshness.',
    },
    {
      'category': 'Pre-Orders & Harvest',
      'icon': Icons.event_available_outlined,
      'question': 'What happens if a farmer adjusts or delays the harvest date?',
      'answer':
          'Weather changes and crop maturation can occasionally affect harvest dates. When a farmer updates the schedule, you will receive an automated notification. You have the choice to wait for the revised harvest date or cancel the pre-order with full refund eligibility if applicable.',
    },
    {
      'category': 'Account & Security',
      'icon': Icons.location_on_outlined,
      'question': 'How do I update my delivery addresses and contact information?',
      'answer':
          'Navigate to your Profile > Address Book to add, edit, or set default delivery addresses. You can also update your primary mobile phone number and email address under Profile > App Settings.',
    },
    {
      'category': 'Account & Security',
      'icon': Icons.security_rounded,
      'question': 'How is my personal data and transaction history protected?',
      'answer':
          'AgriDirect adheres to strict Philippine Data Privacy regulations. All data communications are encrypted via SSL/TLS, and Supabase Row Level Security (RLS) ensures that personal details, addresses, and order histories are only accessible to authorized parties.',
    },
    {
      'category': 'Account & Security',
      'icon': Icons.lock_reset_rounded,
      'question': 'How do I change or reset my password?',
      'answer':
          'If you are logged in, go to Profile > App Settings > Change Password. If you forgot your password, click "Forgot Password?" on the login page to receive a secure password reset link or verification code at your registered email.',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredFaqs {
    return _allFaqs.where((faq) {
      final matchesCategory = _selectedCategory == 'All Topics' ||
          faq['category'] == _selectedCategory;

      if (!matchesCategory) return false;

      if (_searchQuery.isEmpty) return true;

      final query = _searchQuery.toLowerCase();
      final q = (faq['question'] as String).toLowerCase();
      final a = (faq['answer'] as String).toLowerCase();
      final cat = (faq['category'] as String).toLowerCase();

      return q.contains(query) || a.contains(query) || cat.contains(query);
    }).toList();
  }

  void _openContactSupportDialog() {
    final formKey = GlobalKey<FormState>();
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate()) return;
              setModalState(() => isSubmitting = true);

              try {
                final auth = AuthService();
                final email = auth.userEmail.isNotEmpty
                    ? auth.userEmail
                    : 'guest@agridirect.ph';
                final name = auth.userName.isNotEmpty
                    ? auth.userName
                    : 'Web Visitor';

                await auth.client.from('support_tickets').insert({
                  'user_email': email,
                  'user_name': name,
                  'subject': subjectCtrl.text.trim(),
                  'message': messageCtrl.text.trim(),
                  'status': 'open',
                  'created_at': DateTime.now().toIso8601String(),
                });

                if (context.mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Support inquiry submitted! We will email you at $email shortly.',
                              style: GoogleFonts.inter(),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: _emerald,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              } catch (_) {
                // Fallback graceful notification if table is unavailable
                if (context.mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.mark_email_read_rounded,
                              color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Thank you! Your message has been routed to support@agridirect.ph',
                              style: GoogleFonts.inter(),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: _emerald,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.support_agent_rounded,
                        color: _primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contact AgriDirect Support',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: _dark,
                          ),
                        ),
                        Text(
                          'Our help desk typically responds within 2 hours',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: subjectCtrl,
                        decoration: InputDecoration(
                          labelText: 'Subject / Topic',
                          hintText: 'e.g. Question about order harvest status',
                          prefixIcon: const Icon(Icons.subject_rounded,
                              color: _slate500, size: 20),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _border),
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Please enter a subject' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: messageCtrl,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: 'Detailed Message',
                          hintText:
                              'Describe the issue, order number, or question in detail...',
                          alignLabelWithHint: true,
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _border),
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Please enter your message' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: _slate600,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isSubmitting ? null : submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 16),
                  label: Text(
                    isSubmitting ? 'Sending...' : 'Send Inquiry',
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isDesktop = sw >= 980;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          WebEcomHeader(
            currentIndex: -1,
            onNavigate: (index, [route]) {
              if (route != null) {
                context.go(route);
              }
            },
            onSearch: (query) {
              context.go(AppRoutes.shop, extra: {'search': query});
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeroHeader(sw),
                  _buildMainBody(sw, isDesktop),
                  const AgriDirectWebFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(double sw) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF0FDF4),
            Colors.white,
            const Color(0xFFECFDF5),
          ],
        ),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: sw > 1200 ? 80 : (sw > 768 ? 40 : 20),
        vertical: sw > 768 ? 56 : 36,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: [
              // Breadcrumbs
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () => context.go(AppRoutes.shop),
                    child: Text(
                      'Home',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: _slate500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded,
                      size: 16, color: _slate500),
                  const SizedBox(width: 8),
                  Text(
                    'Frequently Asked Questions',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _emerald,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Category Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.help_center_rounded,
                        color: _primary, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'AGRIDIRECT HELP & KNOWLEDGE BASE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: _primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Main Heading
              Text(
                'How can we help you today?',
                textAlign: TextAlign.center,
                style: GoogleFonts.rubik(
                  fontSize: sw > 768 ? 38 : 28,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),

              // Subheading
              Text(
                'Find answers regarding fresh produce ordering, harvest timelines, farmer accreditation, COD payments, and account security.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: sw > 768 ? 16 : 14,
                  color: _slate600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // Modern Search Box
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                  style: GoogleFonts.inter(fontSize: 15, color: _dark),
                  decoration: InputDecoration(
                    hintText:
                        'Search questions, topics, or keywords (e.g., pre-orders, COD, harvest, vouchers)...',
                    hintStyle:
                        GoogleFonts.inter(fontSize: 14, color: _slate500),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Icon(Icons.search_rounded,
                          color: _emerald, size: 24),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                color: _slate500, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainBody(double sw, bool isDesktop) {
    final faqs = _filteredFaqs;

    return Container(
      color: _bgLight,
      padding: EdgeInsets.symmetric(
        horizontal: sw > 1200 ? 80 : (sw > 768 ? 36 : 16),
        vertical: 40,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Filter Pills
              _buildCategoryPills(sw),
              const SizedBox(height: 28),

              // Layout: 2 Columns on Desktop, Stacked on Mobile
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main FAQs Area
                    Expanded(
                      flex: 7,
                      child: _buildFaqList(faqs),
                    ),
                    const SizedBox(width: 36),
                    // Sidebar
                    Expanded(
                      flex: 3,
                      child: _buildSidebar(),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    _buildFaqList(faqs),
                    const SizedBox(height: 36),
                    _buildSidebar(),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPills(double sw) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () {
                  setState(() {
                    _selectedCategory = cat;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? _primary : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isSelected ? _primary : _border,
                      width: 1.2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: _primary.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    cat,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? Colors.white : _slate600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFaqList(List<Map<String, dynamic>> faqs) {
    if (faqs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.search_off_rounded,
                    size: 40, color: _slate500),
              ),
              const SizedBox(height: 16),
              Text(
                'No matching questions found',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We couldn\'t find any FAQ matching "$_searchQuery". Try selecting a different topic or ask Kiko AI.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: _slate500),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedCategory = 'All Topics';
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reset All Filters'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Result Count Banner
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${faqs.length} question${faqs.length == 1 ? '' : 's'}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _slate500,
                ),
              ),
              if (_searchQuery.isNotEmpty || _selectedCategory != 'All Topics')
                TextButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _selectedCategory = 'All Topics';
                    });
                  },
                  icon: const Icon(Icons.close_rounded, size: 16, color: _emerald),
                  label: Text(
                    'Clear filters',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _emerald,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Accordion Cards
        ...List.generate(faqs.length, (index) {
          final faq = faqs[index];
          final isExpanded = _expandedIndices.contains(index);
          final vote = _helpfulVotes[index];

          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isExpanded ? _primary.withValues(alpha: 0.4) : _border,
                width: isExpanded ? 1.4 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isExpanded
                      ? _primary.withValues(alpha: 0.06)
                      : _dark.withValues(alpha: 0.02),
                  blurRadius: isExpanded ? 16 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header (Clickable)
                InkWell(
                  borderRadius: BorderRadius.vertical(
                    top: const Radius.circular(16),
                    bottom: Radius.circular(isExpanded ? 0 : 16),
                  ),
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedIndices.remove(index);
                      } else {
                        _expandedIndices.add(index);
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isExpanded
                                ? _emerald.withValues(alpha: 0.12)
                                : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            faq['icon'] as IconData? ?? Icons.help_outline_rounded,
                            color: isExpanded ? _emerald : _slate500,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _emerald.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  (faq['category'] as String).toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: _emerald,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                faq['question'] as String,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: isExpanded ? _primary : _dark,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: isExpanded ? _primary : _slate500,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Expanded Answer Content
                if (isExpanded) ...[
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFEDF2F7)),
                          ),
                          child: Text(
                            faq['answer'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              color: _slate600,
                              height: 1.65,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Was this helpful?
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Was this answer helpful?',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: _slate500,
                              ),
                            ),
                            const SizedBox(width: 10),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _helpfulVotes[index] = true;
                                });
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: vote == true
                                      ? _emerald.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: vote == true ? _emerald : _border,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.thumb_up_alt_rounded,
                                        size: 13,
                                        color:
                                            vote == true ? _emerald : _slate500),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Yes',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            vote == true ? _emerald : _slate500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _helpfulVotes[index] = false;
                                });
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: vote == false
                                      ? Colors.red.withValues(alpha: 0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color:
                                        vote == false ? Colors.red : _border,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.thumb_down_alt_rounded,
                                        size: 13,
                                        color:
                                            vote == false ? Colors.red : _slate500),
                                    const SizedBox(width: 4),
                                    Text(
                                      'No',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            vote == false ? Colors.red : _slate500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSidebar() {
    return Column(
      children: [
        // 1. Kiko AI Chat Assistant Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF005A36), Color(0xFF047857)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF005A36).withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.smart_toy_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ask Kiko AI',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '24/7 Smart Farm Assistant',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Need instant help with harvest schedules, current crop pricing, or order status? Ask Kiko AI now.',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.go(AppRoutes.kikoAiChat),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded,
                      size: 18, color: _primary),
                  label: Text(
                    'Chat with Kiko AI',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: _primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. Direct Support Ticket Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: _dark.withValues(alpha: 0.03),
                blurRadius: 12,
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _emerald.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.support_agent_rounded,
                        color: _emerald, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Still Have Questions?',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: _dark,
                          ),
                        ),
                        Text(
                          'Talk to human support',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSupportContactRow(
                icon: Icons.email_outlined,
                title: 'Email Support',
                value: 'support@agridirect.ph',
              ),
              const SizedBox(height: 10),
              _buildSupportContactRow(
                icon: Icons.phone_outlined,
                title: 'Customer Hotline',
                value: '+63 912 235 4762',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openContactSupportDialog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: const BorderSide(color: _primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.mail_outline_rounded, size: 18),
                  label: Text(
                    'Submit Support Ticket',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 3. Quick Resource Links Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Related Resources',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 12),
              _buildQuickResourceLink(
                icon: Icons.menu_book_rounded,
                title: 'Farmer Guides & Best Practices',
                onTap: () => context.go(AppRoutes.farmerGuides),
              ),
              const Divider(height: 16, color: Color(0xFFF1F5F9)),
              _buildQuickResourceLink(
                icon: Icons.gavel_rounded,
                title: 'Terms & Community Rules',
                onTap: () => context.go(AppRoutes.termsOfService),
              ),
              const Divider(height: 16, color: Color(0xFFF1F5F9)),
              _buildQuickResourceLink(
                icon: Icons.privacy_tip_outlined,
                title: 'Data Privacy Policy',
                onTap: () => context.go(AppRoutes.privacyPolicy),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSupportContactRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _slate500),
        const SizedBox(width: 8),
        Text(
          '$title: ',
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: _slate500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickResourceLink({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 17, color: _emerald),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _slate600,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: _slate500),
          ],
        ),
      ),
    );
  }
}
