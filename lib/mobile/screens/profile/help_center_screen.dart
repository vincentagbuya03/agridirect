import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../web/widgets/web_consumer_nav_bar.dart';
import '../../../shared/router/app_routes.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, dynamic>> _faqs = [
    {
      'icon': Icons.lock_reset_rounded,
      'category': 'Account',
      'title': 'How do I change my password?',
      'body': 'Open Profile > App Settings > Change Password to update your password while logged in. Enter your current password for security verification first, then set your new password.',
    },
    {
      'icon': Icons.person_outline_rounded,
      'category': 'Account',
      'title': 'How do I update my profile details?',
      'body': 'Go to your Profile tab and open My Details to edit your name, photo, phone number, farm details, or location details.',
    },
    {
      'icon': Icons.location_on_outlined,
      'category': 'Delivery',
      'title': 'How do I manage my delivery addresses?',
      'body': 'Use the Address Book option under your profile settings to add, edit, delete, or choose your default delivery address for checkout.',
    },
    {
      'icon': Icons.favorite_outline_rounded,
      'category': 'Shopping',
      'title': 'What are Favorites?',
      'body': 'Products you save or mark as favorite are stored in your Favorites. These are synced locally so you can quickly access and view them offline.',
    },
    {
      'icon': Icons.agriculture_rounded,
      'category': 'Farmer',
      'title': 'How do I become a seller?',
      'body': 'In your profile, scroll to the "Become a Seller" section and click "Start Selling" to submit your farmer registration. Once approved by an admin, you can access the Farmer Dashboard.',
    },
    {
      'icon': Icons.payment_rounded,
      'category': 'Shopping',
      'title': 'What payment options are supported?',
      'body': 'AgriDirect currently supports Cash on Delivery (COD) and GCash transfer methods directly arranged between farmers and customers.',
    },
  ];

  List<Map<String, dynamic>> get _filteredFaqs {
    if (_searchQuery.isEmpty) return _faqs;
    return _faqs.where((faq) {
      final title = faq['title'].toString().toLowerCase();
      final body = faq['body'].toString().toLowerCase();
      final category = faq['category'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return title.contains(query) || body.contains(query) || category.contains(query);
    }).toList();
  }

  Future<void> _openContactSupportDialog() async {
    final formKey = GlobalKey<FormState>();
    _subjectController.clear();
    _messageController.clear();
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> submitTicket() async {
              if (!formKey.currentState!.validate()) return;

              setModalState(() => isSaving = true);
              
              final authService = AuthService();
              final userEmail = authService.userEmail.isNotEmpty
                  ? authService.userEmail
                  : 'anonymous@agridirect.com';
              final userName = authService.userName.isNotEmpty
                  ? authService.userName
                  : 'Anonymous User';

              bool success = false;
              // Try to store in Supabase support_tickets database table
              try {
                await authService.client.from('support_tickets').insert({
                  'user_email': userEmail,
                  'user_name': userName,
                  'subject': _subjectController.text.trim(),
                  'message_text': _messageController.text.trim(),
                });
                success = true;
              } catch (e) {
                debugPrint('Failed to save support ticket to Supabase table: $e');
              }
              
              if (!dialogCtx.mounted) return;
              setModalState(() => isSaving = false);
              Navigator.of(dialogCtx).pop();

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(success 
                      ? 'Support request submitted successfully! We will contact you soon.'
                      : 'Failed to send support request. Please try again later.'),
                  backgroundColor: success ? AppColors.success : Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              titlePadding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
              contentPadding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
              actionsPadding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Contact Support',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Submit a support ticket and our team will get back to you shortly.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _subjectController,
                          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1E293B)),
                          decoration: InputDecoration(
                            labelText: 'Subject',
                            labelStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
                            prefixIcon: const Icon(Icons.title_rounded, color: Color(0xFF94A3B8), size: 20),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.primary, width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.red, width: 1),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.red, width: 2),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a subject.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _messageController,
                          maxLines: 5,
                          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1E293B)),
                          decoration: InputDecoration(
                            labelText: 'Message Description',
                            labelStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 80),
                              child: Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                            ),
                            alignLabelWithHint: true,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.primary, width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.red, width: 1),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.red, width: 2),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a description.';
                            }
                            if (value.trim().length < 10) {
                              return 'Please explain in at least 10 characters.';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(dialogCtx).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: isSaving ? null : submitTicket,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isSaving
                            ? [Colors.grey[400]!, Colors.grey[400]!]
                            : [const Color(0xFF22C55E), const Color(0xFF16A34A)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isSaving
                          ? []
                          : [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSaving) ...[
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          isSaving ? 'Submitting...' : 'Submit Request',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
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
  void dispose() {
    _searchController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Widget _buildWebLayout(List<Map<String, dynamic>> filtered) {
    final isFarmer = AuthService().isViewingAsFarmer;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          WebConsumerNavBar(
            currentIndex: -1,
            onNavigate: (index) {
              if (isFarmer) {
                context.go(AppRoutes.farmerDashboard);
              } else {
                context.go(AppRoutes.webTabRoute(index));
              }
            },
            onCartTap: () => context.go(AppRoutes.cart),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Navigation, Search, and Contact Support Ticket (35% width)
                Container(
                  width: 360,
                  color: Colors.white,
                  padding: const EdgeInsets.all(28),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => context.pop(),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back_rounded,
                                    size: 20,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Help Center',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'How can we help?',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Search Input Bar
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Search help topics...',
                              hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                              prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          _searchController.clear();
                                          _searchQuery = '';
                                        });
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Contact Support Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Still need help?',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: AppColors.textHeadline,
                                        ),
                                      ),
                                      const Text(
                                        'Support active 24/7',
                                        style: TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Submit a ticket explaining your issue and we will get back to you soon.',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSubtle,
                                  height: 1.4,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: _openContactSupportDialog,
                                  child: const Text('Contact Support', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Divider
                Container(
                  width: 1,
                  color: const Color(0xFFE2E8F0),
                ),
                // Right Column: FAQs
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Frequently Asked Questions',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Find answers to common questions about AgriDirect features.',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 60),
                            child: Center(
                              child: Column(
                                children: [
                                  const Icon(Icons.help_outline_rounded, size: 48, color: Colors.grey),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No results found for "$_searchQuery"',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...filtered.map((faq) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  dividerColor: Colors.transparent,
                                ),
                                child: ExpansionTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(faq['icon'] as IconData, color: AppColors.primary, size: 18),
                                  ),
                                  title: Text(
                                    faq['title'].toString(),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppColors.textHeadline,
                                    ),
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(left: 58, right: 18, bottom: 18),
                                      child: Text(
                                        faq['body'].toString(),
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textSubtle,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredFaqs;

    if (kIsWeb && MediaQuery.of(context).size.width >= 650) {
      return _buildWebLayout(filtered);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Help Center'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // Search Input Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search help topics...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text('Frequently Asked Questions', style: AppTextStyles.headline3),
          const SizedBox(height: 12),

          // FAQ List
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.help_outline_rounded, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(
                      'No results found for "$_searchQuery"',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filtered.map((faq) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: AppDecorations.cardDecoration.copyWith(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(faq['icon'] as IconData, color: AppColors.primary, size: 20),
                    ),
                    title: Text(
                      faq['title'].toString(),
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textHeadline,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 58, right: 18, bottom: 18),
                        child: Text(
                          faq['body'].toString(),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSubtle,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 24),

          // Contact Support Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppDecorations.cardDecoration.copyWith(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.05),
                  AppColors.primary.withValues(alpha: 0.02),
                ],
              ),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.support_agent_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Still need help?', style: AppTextStyles.headline3),
                        const SizedBox(height: 2),
                        const Text(
                          'Our support team is active 24/7',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Submit a support ticket explaining your issue and we will get back to you as soon as possible.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSubtle,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _openContactSupportDialog,
                    child: const Text('Contact Support'),
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
