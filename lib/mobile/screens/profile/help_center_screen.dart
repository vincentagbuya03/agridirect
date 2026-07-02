import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/services/auth/auth_service.dart';

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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Contact Support',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Submit a support ticket and our team will get back to you shortly.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _subjectController,
                          decoration: InputDecoration(
                            labelText: 'Subject',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a subject.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _messageController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Message Description',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
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
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isSaving ? null : submitTicket,
                  child: Text(isSaving ? 'Submitting...' : 'Submit Request'),
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredFaqs;

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
