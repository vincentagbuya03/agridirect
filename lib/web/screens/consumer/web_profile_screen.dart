import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/services/commerce/voucher_service.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/widgets/image_widgets.dart';
import '../../widgets/web_consumer_nav_bar.dart';
import '../../../shared/utils/apk_downloader.dart';
import 'package:agridirect/shared/widgets/premium_confirm_dialog.dart';
import '../../../shared/services/social/follow_service.dart';
import '../../../shared/models/auth/user_address_model.dart';
import '../../../shared/services/user/user_service.dart';
import '../../../mobile/screens/profile/address_book_screen.dart';
import '../../../mobile/screens/consumer/marketplace_screen.dart';

// Web Profile screen.
/// Shows user info, "Start Selling" button, and account settings.
class WebProfileScreen extends StatefulWidget {
  final VoidCallback onModeChanged;
  final VoidCallback onLogout;
  final Function(int) onNavigate;
  final int currentIndex;

  const WebProfileScreen({
    super.key,
    required this.onModeChanged,
    required this.onLogout,
    required this.onNavigate,
    required this.currentIndex,
  });

  @override
  State<WebProfileScreen> createState() => _WebProfileScreenState();
}

class _WebProfileScreenState extends State<WebProfileScreen>
    with TickerProviderStateMixin {
  static const Color primary = Color(0xFF16A34A);
  static const Color _accent = Color(0xFF22C55E);
  static const Color _dark = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);

  // Animations
  late AnimationController _fadeInController;
  final Set<int> _hoveredButtons = {};

  String? _registrationStatus; // 'pending', 'approved', 'rejected', or null
  StreamSubscription<String?>? _registrationStatusSubscription;

  Map<String, dynamic>? _farmerProfile;
  int _totalOrdersCount = 0;
  int _followersCount = 0;

  // Inline Edit Profile controllers & state
  final _profileFormKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _specialtyController;
  late final TextEditingController _locationController;
  bool _isSavingProfile = false;
  bool _isUploadingAvatar = false;
  String _avatarUrl = '';

  Future<void> _loadFarmerProfile() async {
    final auth = AuthService();
    if (!auth.isLoggedIn) return;
    try {
      final profile = await SupabaseDataService().getFarmerProfile(auth.userId);
      if (mounted) {
        setState(() {
          _farmerProfile = profile;
          if (auth.isViewingAsFarmer && profile != null) {
            _nameController.text =
                profile['farm_name']?.toString() ?? auth.userName;
            _specialtyController.text = profile['specialty']?.toString() ?? '';
            _locationController.text = profile['location']?.toString() ?? '';
            _avatarUrl = profile['image_url']?.toString() ?? auth.userAvatarUrl;
          }
        });
      }
      if (profile != null) {
        final farmerId = profile['farmer_id']?.toString() ?? '';
        if (farmerId.isNotEmpty) {
          final ordersRes = await SupabaseConfig.client
              .from('orders')
              .select('order_id')
              .eq('farmer_id', farmerId);
          final followersCount = await FollowService().getFollowerCount(
            farmerId,
          );
          if (mounted) {
            setState(() {
              _totalOrdersCount = (ordersRes as List).length;
              _followersCount = followersCount;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading farmer profile in web_profile_screen: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    final auth = AuthService();
    _nameController = TextEditingController(text: auth.userName);
    _emailController = TextEditingController(text: auth.userEmail);
    _phoneController = TextEditingController();
    _specialtyController = TextEditingController();
    _locationController = TextEditingController();
    _avatarUrl = auth.userAvatarUrl;

    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _registrationStatusSubscription =
        SupabaseDatabase.watchFarmerRegistrationStatus(auth.userId).listen((
          status,
        ) {
          if (!mounted) return;
          setState(() {
            _registrationStatus = status;
          });
        });
    _loadFarmerProfile();
    _loadUserProfileDetails();
  }

  Future<void> _loadUserProfileDetails() async {
    try {
      final auth = AuthService();
      final users = await SupabaseConfig.client
          .from('users')
          .select()
          .eq('user_id', auth.userId)
          .limit(1);
      if (users.isNotEmpty && mounted) {
        final user = users[0];
        setState(() {
          _phoneController.text = (user['phone'] ?? user['phone_number'] ?? '')
              .toString();
        });
      }
    } catch (e) {
      debugPrint('Error loading user profile details: $e');
    }
  }

  Future<void> _pickAndUploadInlineAvatar() async {
    if (_isUploadingAvatar || _isSavingProfile) return;
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final bytes = await image.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final path = 'avatars/$fileName';

      final resultPath = await SupabaseDatabase.uploadImage(
        bucket: 'uploads',
        path: path,
        bytes: bytes,
      );

      if (resultPath != null) {
        final publicUrl = SupabaseConfig.client.storage
            .from('uploads')
            .getPublicUrl(path);

        setState(() {
          _avatarUrl = publicUrl;
        });
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _saveInlineProfileChanges() async {
    setState(() => _isSavingProfile = true);
    final auth = AuthService();
    try {
      // 1. Update basic user table info (applies to both consumer & farmer)
      await SupabaseConfig.client
          .from('users')
          .update({
            'name': _nameController.text.trim(),
            'avatar_url': _avatarUrl,
            'phone': _phoneController.text.trim(),
          })
          .eq('user_id', auth.userId);

      // 2. If farmer mode, also update the farmers table
      if (auth.isViewingAsFarmer || auth.isSeller) {
        await SupabaseConfig.client
            .from('farmers')
            .update({
              'farm_name': _nameController.text.trim(),
              'specialty': _specialtyController.text.trim(),
              'location': _locationController.text.trim(),
              'image_url': _avatarUrl,
            })
            .eq('user_id', auth.userId);
      }

      await auth.initialize();
      await _loadFarmerProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile details saved successfully!'),
            backgroundColor: primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _specialtyController.dispose();
    _locationController.dispose();
    _registrationStatusSubscription?.cancel();
    _fadeInController.dispose();
    super.dispose();
  }

  void _handleStartSelling() {
    // Show redirect dialog to mobile app as per modernization plan
    _showMobileOnlyDialog();
  }

  void _showMobileOnlyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.smartphone_rounded,
                  size: 56,
                  color: primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Farmer Registration is Mobile-Only',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'To ensure the best experience and verify your farm location, farmer registration is only available through our mobile app.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: _muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Builder(
                builder: (context) {
                  final sw = MediaQuery.of(context).size.width;
                  final isDesktop = sw > 600;

                  if (isDesktop) {
                    final apkUrl = ApkDownloader.apkUrl;
                    final qrUrl =
                        'https://api.qrserver.com/v1/create-qr-code/?size=160x160&data=${Uri.encodeComponent(apkUrl)}';
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              qrUrl,
                              width: 160,
                              height: 160,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    Icons.qr_code_2_rounded,
                                    size: 160,
                                    color: Colors.grey,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Scan with your phone to install',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _muted,
                          ),
                        ),
                      ],
                    );
                  }

                  return SizedBox(
                    width: double.infinity,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          await ApkDownloader.download();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_accent, primary],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            'Download AgriDirect App',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'Maybe Later',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const PremiumConfirmDialog(
        title: 'Confirm Logout',
        content: 'Are you sure you want to log out of AgriDirect?',
      ),
    );

    if (shouldLogout == true) {
      widget.onLogout();
    }
  }

  void _handleSwitchToFarmer() {
    AuthService().switchToFarmerMode();
    widget.onModeChanged();
  }

  void _handleSwitchToCustomer() {
    AuthService().switchToCustomerMode();
    widget.onModeChanged();
  }

  String _messagesRoute(AuthService auth) {
    return auth.isViewingAsFarmer
        ? AppRoutes.farmerMessages
        : AppRoutes.customerMessages;
  }

  int _selectedTab =
      0; // 0: Profile, 1: Addresses, 2: Vouchers, 3: Orders, 4: Notifications, 5: Privacy

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Light background for contrast
      body: Column(
        children: [
          _buildNavBar(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 36,
                vertical: isMobile ? 16 : 28,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: isMobile
                      ? Column(
                          children: [
                            _buildShopeeSidebar(auth, isMobile: true),
                            const SizedBox(height: 16),
                            _buildShopeeMainContent(auth),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Sidebar (User avatar + Nav links)
                            SizedBox(
                              width: 240,
                              child: _buildShopeeSidebar(auth, isMobile: false),
                            ),
                            const SizedBox(width: 24),

                            // Main Content Area (Card Container)
                            Expanded(child: _buildShopeeMainContent(auth)),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shopee Style Left Sidebar ───
  Widget _buildShopeeSidebar(AuthService auth, {required bool isMobile}) {
    final isFarmer = auth.isViewingAsFarmer;
    final displayName = isFarmer && _farmerProfile != null
        ? (_farmerProfile!['farm_name']?.toString() ?? auth.userName)
        : auth.userName;
    final profileImageUrl =
        isFarmer &&
            _farmerProfile != null &&
            _farmerProfile!['image_url'] != null &&
            _farmerProfile!['image_url'].toString().isNotEmpty
        ? _farmerProfile!['image_url'].toString()
        : auth.userAvatarUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              ClipOval(
                child: SafeNetworkImage(
                  imageUrl: profileImageUrl,
                  defaultBucket: 'uploads',
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  placeholder: Container(color: Colors.grey[200]),
                  errorWidget: const Icon(
                    Icons.person,
                    size: 24,
                    color: _muted,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName.isNotEmpty ? displayName : 'User',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: Row(
                        children: [
                          const Icon(Icons.edit, size: 12, color: _muted),
                          const SizedBox(width: 4),
                          Text(
                            'Edit Profile',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Sidebar Menu Card
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSidebarCategory('MY ACCOUNT'),
              _buildSidebarItem(0, Icons.person_outline_rounded, 'My Profile'),
              _buildSidebarItem(1, Icons.location_on_outlined, 'Addresses'),
              _buildSidebarItem(5, Icons.shield_outlined, 'Privacy Settings'),

              const Divider(height: 24, color: Color(0xFFF1F5F9)),

              _buildSidebarCategory('MY ACTIVITY'),
              if (isFarmer) ...[
                _buildSidebarItem(
                  3,
                  Icons.receipt_long_outlined,
                  'Farmer Orders',
                  onTap: () => widget.onNavigate(2),
                ),
                _buildSidebarItem(
                  6,
                  Icons.storefront_outlined,
                  'My Products',
                  onTap: () => widget.onNavigate(1),
                ),
              ] else ...[
                _buildSidebarItem(
                  3,
                  Icons.shopping_bag_outlined,
                  'My Purchase / Orders',
                  onTap: () => context.push(AppRoutes.customerOrders),
                ),
                _buildSidebarItem(
                  2,
                  Icons.confirmation_number_outlined,
                  'My Vouchers',
                  onTap: () => _showWebClaimedVouchersDialog(),
                ),
              ],

              const Divider(height: 24, color: Color(0xFFF1F5F9)),

              _buildSidebarCategory('PREFERENCES'),
              _buildSidebarItem(
                4,
                Icons.notifications_outlined,
                'Notifications',
                onTap: () => _showNotificationsDialog(),
              ),
              _buildSidebarItem(
                7,
                Icons.help_outline_rounded,
                'Help Center',
                onTap: () => context.push(AppRoutes.helpCenter),
              ),

              const Divider(height: 24, color: Color(0xFFF1F5F9)),

              // Mode switch item
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 2,
                ),
                leading: Icon(
                  isFarmer
                      ? Icons.shopping_bag_outlined
                      : Icons.storefront_outlined,
                  size: 18,
                  color: primary,
                ),
                title: Text(
                  isFarmer ? 'Switch to Customer' : 'Switch to Farmer',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
                onTap: isFarmer
                    ? _handleSwitchToCustomer
                    : _handleSwitchToFarmer,
              ),

              // Logout item
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 2,
                ),
                leading: Icon(
                  Icons.logout_rounded,
                  size: 18,
                  color: Colors.red.shade600,
                ),
                title: Text(
                  'Log Out',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade600,
                  ),
                ),
                onTap: _confirmLogout,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarCategory(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 8, bottom: 6),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF94A3B8),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSidebarItem(
    int index,
    IconData icon,
    String label, {
    VoidCallback? onTap,
  }) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: onTap ?? () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: isSelected ? primary : Colors.transparent,
              width: 3,
            ),
          ),
          color: isSelected
              ? primary.withValues(alpha: 0.06)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? primary : const Color(0xFF64748B),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? primary : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Shopee Style Main Content Card ───
  Widget _buildShopeeMainContent(AuthService auth) {
    if (_selectedTab == 1) {
      return _buildAddressesContent();
    } else if (_selectedTab == 5) {
      return _buildPrivacyContent();
    }

    final isFarmer = auth.isViewingAsFarmer;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFarmer ? Colors.amber.shade200 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isFarmer
                ? Colors.amber.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _profileFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Different styling for Farmer Store vs Consumer Profile
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isFarmer
                            ? Colors.amber.shade100
                            : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isFarmer
                            ? Icons.storefront_rounded
                            : Icons.person_rounded,
                        color: isFarmer ? Colors.amber.shade900 : primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isFarmer
                                  ? 'Farm Store Profile'
                                  : 'My Personal Profile',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: _dark,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isFarmer
                                    ? Colors.amber.shade100
                                    : const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                isFarmer ? 'FARMER MODE' : 'CONSUMER MODE',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isFarmer
                                      ? Colors.amber.shade900
                                      : primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isFarmer
                              ? 'Manage your public farm details, location, and store branding for buyers'
                              : 'Manage your personal buyer information and contact details',
                          style: GoogleFonts.inter(fontSize: 13, color: _muted),
                        ),
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _isSavingProfile
                      ? null
                      : _saveInlineProfileChanges,
                  icon: _isSavingProfile
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 16),
                  label: Text(
                    _isSavingProfile
                        ? 'Saving...'
                        : (isFarmer ? 'Save Store Details' : 'Save Profile'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFarmer ? Colors.amber.shade800 : primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 32, color: Color(0xFFF1F5F9)),

            // Farmer Store Performance Banner (Only in Farmer Mode)
            if (isFarmer) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildFarmerMetricItem(
                      'Total Store Orders',
                      '$_totalOrdersCount',
                      Icons.shopping_bag_outlined,
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: Colors.amber.shade200,
                    ),
                    _buildFarmerMetricItem(
                      'Store Followers',
                      '$_followersCount',
                      Icons.people_outline,
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: Colors.amber.shade200,
                    ),
                    _buildFarmerMetricItem(
                      'Store Status',
                      'Active & Verified',
                      Icons.verified_outlined,
                    ),
                  ],
                ),
              ),
            ],

            // Form fields layout (2 columns: left form fields, right avatar preview)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left form details
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      if (isFarmer) ...[
                        _buildInlineEditRow(
                          label: 'Farm Store Name',
                          controller: _nameController,
                          icon: Icons.storefront_outlined,
                        ),
                        _buildInlineEditRow(
                          label: 'Farm Specialty',
                          controller: _specialtyController,
                          icon: Icons.grass_outlined,
                        ),
                        _buildInlineEditRow(
                          label: 'Farm Location',
                          controller: _locationController,
                          icon: Icons.location_on_outlined,
                        ),
                        _buildInlineEditRow(
                          label: 'Business Phone',
                          controller: _phoneController,
                          icon: Icons.phone_outlined,
                        ),
                        _buildInlineEditRow(
                          label: 'Registered Email',
                          controller: _emailController,
                          icon: Icons.mail_outline,
                          readOnly: true,
                          badge: 'Farmer Verified',
                        ),
                      ] else ...[
                        _buildInlineEditRow(
                          label: 'Full Name',
                          controller: _nameController,
                          icon: Icons.person_outline,
                        ),
                        _buildInlineEditRow(
                          label: 'Email Address',
                          controller: _emailController,
                          icon: Icons.mail_outline,
                          readOnly: true,
                          badge: 'Verified',
                        ),
                        _buildInlineEditRow(
                          label: 'Contact Number',
                          controller: _phoneController,
                          icon: Icons.phone_outlined,
                        ),
                        _buildInlineEditRow(
                          label: 'Account Type',
                          controller: TextEditingController(
                            text: 'Consumer / Buyer Account',
                          ),
                          icon: Icons.badge_outlined,
                          readOnly: true,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 36),

                // Right avatar column with boundary line
                Container(
                  width: 1,
                  height: 240,
                  color: const Color(0xFFF1F5F9),
                ),
                const SizedBox(width: 36),

                Column(
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isFarmer ? Colors.amber.shade700 : primary,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isFarmer ? Colors.amber : primary)
                                .withValues(alpha: 0.15),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _isUploadingAvatar
                            ? Container(
                                color: Colors.grey[200],
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: isFarmer
                                        ? Colors.amber.shade800
                                        : primary,
                                    strokeWidth: 3,
                                  ),
                                ),
                              )
                            : SafeNetworkImage(
                                imageUrl: _avatarUrl,
                                defaultBucket: 'uploads',
                                fit: BoxFit.cover,
                                placeholder: Container(color: Colors.grey[200]),
                                errorWidget: Icon(
                                  isFarmer ? Icons.storefront : Icons.person,
                                  size: 48,
                                  color: _muted,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _isUploadingAvatar
                          ? null
                          : _pickAndUploadInlineAvatar,
                      icon: const Icon(Icons.upload_file_rounded, size: 16),
                      label: Text(
                        isFarmer ? 'Upload Store Logo' : 'Select Photo',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _dark,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isFarmer
                          ? 'Store Logo / Banner\nMax 1 MB (.JPEG, .PNG)'
                          : 'File size: max 1 MB\nFile extension: .JPEG, .PNG',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF94A3B8),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmerMetricItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.amber.shade900),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.amber.shade900,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInlineEditRow({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool readOnly = false,
    String? badge,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              readOnly: readOnly,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: readOnly ? const Color(0xFF64748B) : _dark,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: readOnly
                    ? const Color(0xFFF8FAFC)
                    : const Color(0xFFF9FAFB),
                prefixIcon: Icon(
                  icon,
                  size: 18,
                  color: const Color(0xFF9CA3AF),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: primary, width: 1.5),
                ),
              ),
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                badge,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddressesContent() {
    return FutureBuilder<List<UserAddress>>(
      future: UserService().getAllUserAddresses(),
      builder: (context, snapshot) {
        final addresses = snapshot.data ?? [];
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Delivery Addresses',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _dark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage your shipping addresses for fast fresh farm produce orders',
                        style: GoogleFonts.inter(fontSize: 13, color: _muted),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await showDialog(
                        context: context,
                        builder: (ctx) => Dialog(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 620),
                            child: const AddressEditorSheet(isDialog: true),
                          ),
                        ),
                      );
                      setState(() {}); // Refresh list
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('+ Add New Address'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 32, color: Color(0xFFF1F5F9)),

              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: primary,
                      strokeWidth: 3,
                    ),
                  ),
                )
              else if (addresses.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(
                        Icons.location_off_outlined,
                        size: 56,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Addresses Found',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _dark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add a delivery address to easily checkout items from local farmers.',
                        style: GoogleFonts.inter(fontSize: 13, color: _muted),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: addresses.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 24, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final addr = addresses[index];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: addr.isDefault
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.location_on_rounded,
                            size: 20,
                            color: addr.isDefault
                                ? primary
                                : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    addr.recipientName,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: _dark,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    addr.recipientPhone.isNotEmpty
                                        ? addr.recipientPhone
                                        : 'No Phone',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: _muted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (addr.isDefault) ...[
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: primary.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        'Default',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${addr.street}, ${addr.barangay}, ${addr.city}, ${addr.province} ${addr.zipCode}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF334155),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () async {
                                await showDialog(
                                  context: context,
                                  builder: (ctx) => Dialog(
                                    backgroundColor: Colors.transparent,
                                    elevation: 0,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 620,
                                      ),
                                      child: AddressEditorSheet(
                                        initialAddress: addr,
                                        isDialog: true,
                                      ),
                                    ),
                                  ),
                                );
                                setState(() {});
                              },
                              child: Text(
                                'Edit',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: primary,
                                ),
                              ),
                            ),
                            if (!addr.isDefault)
                              TextButton(
                                onPressed: () async {
                                  await UserService().deleteAddressById(
                                    addr.addressId,
                                  );
                                  setState(() {});
                                },
                                child: Text(
                                  'Delete',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red.shade600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrivacyContent() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Privacy & Security Settings',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Manage password protection, account authentication, and privacy controls',
            style: GoogleFonts.inter(fontSize: 13, color: _muted),
          ),
          const Divider(height: 32, color: Color(0xFFF1F5F9)),

          // 1. Password & Security
          _buildPrivacySettingRow(
            icon: Icons.lock_outline_rounded,
            title: 'Account Password',
            description:
                'Change your account password regularly to keep your profile secure.',
            buttonText: 'Change Password',
            onTap: () => context.push(AppRoutes.resetPassword),
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),

          // 2. Multi-factor Authentication
          _buildPrivacySettingRow(
            icon: Icons.security_rounded,
            title: 'Two-Factor Authentication (2FA)',
            description:
                'Add an extra layer of security with SMS or Email OTP verification.',
            buttonText: 'Enable 2FA',
            badge: 'Recommended',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Two-Factor Authentication is active via Supabase Email OTP!',
                  ),
                  backgroundColor: primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),

          // 3. Login Activity
          _buildPrivacySettingRow(
            icon: Icons.devices_rounded,
            title: 'Active Sessions & Devices',
            description:
                'View active web browsers and devices logged into your account.',
            buttonText: 'View Sessions',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Current Web Browser session is verified and active.',
                  ),
                  backgroundColor: primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),

          // 4. Data Privacy
          _buildPrivacySettingRow(
            icon: Icons.visibility_off_outlined,
            title: 'Data & Activity Privacy',
            description:
                'Control how your purchase history and farm interactions are visible.',
            buttonText: 'Privacy Policy',
            onTap: () => context.push(AppRoutes.helpCenter),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySettingRow({
    required IconData icon,
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: Color(0xFFF1F5F9),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF475569)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: _dark,
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: Text(
            buttonText,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _confirmLogout,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.red.shade50.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade100),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: Colors.red.shade700, size: 20),
              const SizedBox(width: 10),
              Text(
                'Log Out of Account',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Navigation Bar ───
  Widget _buildNavBar() {
    return WebConsumerNavBar(
      currentIndex: widget.currentIndex,
      onNavigate: widget.onNavigate,
      onCartTap: () => context.go(AppRoutes.cart),
    );
  }

  Widget _buildShopPerformanceMetrics(AuthService auth) {
    final ratingVal = _farmerProfile?['average_rating'] ?? 5.0;
    final ratingText = '${ratingVal.toString()} ★';

    final metrics = [
      {
        'title': 'Total Orders',
        'value': '$_totalOrdersCount',
        'icon': Icons.local_shipping_outlined,
        'color': primary,
      },
      {
        'title': 'Store Rating',
        'value': ratingText,
        'icon': Icons.star_rounded,
        'color': Colors.amber.shade700,
      },
      {
        'title': 'Followers',
        'value': '$_followersCount',
        'icon': Icons.people_outline_rounded,
        'color': Colors.blue,
      },
      {
        'title': 'Fulfillment',
        'value': '98%',
        'icon': Icons.verified_outlined,
        'color': Colors.purple,
      },
    ];

    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Store Performance',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _dark,
          ),
        ),
        const SizedBox(height: 14),
        if (isMobile)
          Row(
            children: metrics.take(2).map((m) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        m['icon'] as IconData,
                        color: m['color'] as Color,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        m['value'] as String,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _dark,
                        ),
                      ),
                      Text(
                        m['title'] as String,
                        style: GoogleFonts.inter(fontSize: 12, color: _muted),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          )
        else
          Row(
            children: metrics.map((m) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (m['color'] as Color).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          m['icon'] as IconData,
                          color: m['color'] as Color,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              m['value'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _dark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              m['title'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _muted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildProfileCard(AuthService auth) {
    final isFarmer = auth.isViewingAsFarmer;
    final displayName = isFarmer && _farmerProfile != null
        ? (_farmerProfile!['farm_name']?.toString() ?? auth.userName)
        : auth.userName;
    final displaySpecialty = isFarmer && _farmerProfile != null
        ? (_farmerProfile!['specialty']?.toString() ?? 'Fresh Produce')
        : null;
    final displayEmail = auth.userEmail;
    final displayLocation = isFarmer && _farmerProfile != null
        ? (_farmerProfile!['location']?.toString() ?? '')
        : null;

    final profileImageUrl =
        isFarmer &&
            _farmerProfile != null &&
            _farmerProfile!['image_url'] != null &&
            _farmerProfile!['image_url'].toString().isNotEmpty
        ? _farmerProfile!['image_url'].toString()
        : auth.userAvatarUrl;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: primary, width: 3),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipOval(
              child: SafeNetworkImage(
                imageUrl: profileImageUrl,
                defaultBucket: 'uploads',
                fit: BoxFit.cover,
                placeholder: Container(color: Colors.grey[200]),
                errorWidget: const Icon(Icons.person, size: 40, color: _muted),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            displayName.isNotEmpty ? displayName : 'User',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _dark,
              letterSpacing: -0.4,
            ),
            textAlign: TextAlign.center,
          ),
          if (displaySpecialty != null) ...[
            const SizedBox(height: 4),
            Text(
              displaySpecialty,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            displayEmail.isNotEmpty ? displayEmail : 'user@email.com',
            style: GoogleFonts.inter(fontSize: 13, color: _muted),
            textAlign: TextAlign.center,
          ),
          if (displayLocation != null && displayLocation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 14,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    displayLocation,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          if (auth.isSeller)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.storefront_rounded, size: 16, color: primary),
                  const SizedBox(width: 6),
                  Text(
                    'Verified Seller',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          const SizedBox(height: 16),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _showEditProfileDialog(auth),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: Color(0xFF475569),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Edit Profile',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerCard(AuthService auth) {
    if (auth.isSeller) {
      final isViewingAsFarmer = auth.isViewingAsFarmer;
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isViewingAsFarmer
                        ? Icons.storefront_rounded
                        : Icons.shopping_bag_rounded,
                    color: primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isViewingAsFarmer ? 'Farmer Mode' : 'Customer Mode',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isViewingAsFarmer
                          ? 'Manage your products & sales'
                          : 'Browse & buy farm products',
                      style: GoogleFonts.inter(fontSize: 13, color: _muted),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              isViewingAsFarmer
                  ? 'You are viewing as a farmer. Manage products, track sales, and view analytics from the Dashboard.'
                  : 'You are viewing as a customer. Switch to farmer mode to manage your products and sales.',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hoveredButtons.add(0)),
              onExit: (_) => setState(() => _hoveredButtons.remove(0)),
              child: GestureDetector(
                onTap: isViewingAsFarmer
                    ? _handleSwitchToCustomer
                    : _handleSwitchToFarmer,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isViewingAsFarmer
                          ? [const Color(0xFF3B82F6), const Color(0xFF60A5FA)]
                          : [const Color(0xFF22C55E), const Color(0xFF16A34A)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _hoveredButtons.contains(0)
                        ? [
                            BoxShadow(
                              color:
                                  (isViewingAsFarmer
                                          ? const Color(0xFF3B82F6)
                                          : primary)
                                      .withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color:
                                  (isViewingAsFarmer
                                          ? const Color(0xFF3B82F6)
                                          : primary)
                                      .withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: AnimatedScale(
                    scale: _hoveredButtons.contains(0) ? 1.05 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isViewingAsFarmer
                              ? Icons.shopping_bag_rounded
                              : Icons.storefront_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isViewingAsFarmer
                              ? 'Switch to Customer'
                              : 'Switch to Farmer',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _registrationStatus == 'pending'
              ? [
                  Colors.orange.withValues(alpha: 0.05),
                  Colors.orange.withValues(alpha: 0.02),
                ]
              : [
                  primary.withValues(alpha: 0.05),
                  primary.withValues(alpha: 0.02),
                ],
        ),
        border: Border.all(
          color: _registrationStatus == 'pending'
              ? Colors.orange.withValues(alpha: 0.2)
              : primary.withValues(alpha: 0.2),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              _registrationStatus == 'pending'
                  ? Icons.hourglass_bottom_rounded
                  : Icons.agriculture_rounded,
              size: 140,
              color: _registrationStatus == 'pending'
                  ? Colors.orange.withValues(alpha: 0.1)
                  : primary.withValues(alpha: 0.1),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _registrationStatus == 'pending'
                          ? Colors.orange.withValues(alpha: 0.1)
                          : primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _registrationStatus == 'pending'
                          ? Icons.hourglass_bottom_rounded
                          : Icons.rocket_launch_rounded,
                      color: _registrationStatus == 'pending'
                          ? Colors.orange[400]
                          : primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _registrationStatus == 'pending'
                              ? 'Registration Under Review'
                              : 'Become a Seller',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _registrationStatus == 'pending'
                              ? 'Your farmer registration is being reviewed'
                              : 'Sell your farm produce directly to customers',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                _registrationStatus == 'pending'
                    ? 'We appreciate your interest in becoming a seller. Your farmer registration is currently under admin review. '
                          'We will notify you as soon as it\'s approved so you can start selling.'
                    : 'Activate Seller Mode to unlock the Farmer Dashboard. '
                          'Manage your products, track sales analytics, get AI-powered suggestions, '
                          'and connect directly with buyers across the platform.',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.6,
                ),
              ),
              if (_registrationStatus == 'pending') ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_rounded,
                        size: 20,
                        color: Colors.orange[400],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Check back later or we\'ll send you an email notification once approved.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 24),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _hoveredButtons.add(1)),
                  onExit: (_) => setState(() => _hoveredButtons.remove(1)),
                  child: GestureDetector(
                    onTap: _handleStartSelling,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [_accent, primary]),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: _hoveredButtons.contains(1)
                            ? [
                                BoxShadow(
                                  color: primary.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: primary.withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                      ),
                      child: AnimatedScale(
                        scale: _hoveredButtons.contains(1) ? 1.05 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.storefront_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Start Selling',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGrid() {
    final auth = AuthService();
    final isFarmer = auth.isViewingAsFarmer;

    final items = [
      if (isFarmer) ...[
        _SettingsItem(
          Icons.storefront_rounded,
          'My Products',
          'Manage Listings',
          onTap: () => widget.onNavigate(1),
        ),
        _SettingsItem(
          Icons.receipt_long_rounded,
          'Farmer Orders',
          'Manage customer orders',
          onTap: () => widget.onNavigate(2),
        ),
      ] else ...[
        _SettingsItem(
          Icons.shopping_bag_outlined,
          'My Orders',
          'Track purchases',
          onTap: () => context.push(AppRoutes.customerOrders),
        ),
        _SettingsItem(
          Icons.location_on_outlined,
          'Addresses',
          'Delivery locations',
          onTap: () => context.push(AppRoutes.addressBook),
        ),
        _SettingsItem(
          Icons.confirmation_number_outlined,
          'My Vouchers',
          'Claimed shop vouchers',
          onTap: () => _showWebClaimedVouchersDialog(),
        ),
      ],
      _SettingsItem(
        Icons.chat_bubble_outline_rounded,
        'Messages',
        isFarmer ? 'Messages from customers' : 'Messages from farmers',
        onTap: () => context.push(_messagesRoute(auth)),
      ),
      _SettingsItem(
        Icons.notifications_outlined,
        'Notifications',
        'Alert preferences',
        onTap: () => _showNotificationsDialog(),
      ),
      _SettingsItem(
        Icons.shield_outlined,
        'Privacy',
        'Data & security',
        onTap: () => context.push(AppRoutes.appSettings),
      ),
      _SettingsItem(
        Icons.help_outline_rounded,
        'Help Center',
        'FAQs & customer support',
        onTap: () => context.push(AppRoutes.helpCenter),
      ),
    ];

    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Shortcuts & Settings',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _dark,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isMobile ? 1 : 2,
            mainAxisExtent: 84,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return StatefulBuilder(
              builder: (context, setCardState) {
                bool isHovered = false;
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setCardState(() => isHovered = true),
                  onExit: (_) => setCardState(() => isHovered = false),
                  child: GestureDetector(
                    onTap: item.onTap,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isHovered
                              ? primary.withValues(alpha: 0.4)
                              : const Color(0xFFE2E8F0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isHovered
                                ? primary.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.02),
                            blurRadius: isHovered ? 16 : 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isHovered
                                  ? primary.withValues(alpha: 0.12)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              item.icon,
                              size: 20,
                              color: isHovered
                                  ? primary
                                  : const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item.title,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _dark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.subtitle,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: _muted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          AnimatedPadding(
                            duration: const Duration(milliseconds: 180),
                            padding: EdgeInsets.only(left: isHovered ? 6 : 0),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              color: isHovered
                                  ? primary
                                  : const Color(0xFFCBD5E1),
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  void _showEditProfileDialog(AuthService auth) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _EditProfileDialog(
        auth: auth,
        farmerProfile: _farmerProfile,
        onSaveSuccess: () async {
          await _loadFarmerProfile();
        },
      ),
    );
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        bool emailAlerts = true;
        bool pushAlerts = true;
        bool promoAlerts = false;
        bool isSaving = false;
        bool isLoaded = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            if (!isLoaded) {
              SharedPreferences.getInstance().then((prefs) {
                setModalState(() {
                  emailAlerts =
                      prefs.getBool('notifications.email_alerts') ?? true;
                  pushAlerts =
                      prefs.getBool('notifications.push_alerts') ?? true;
                  promoAlerts =
                      prefs.getBool('notifications.promo_alerts') ?? false;
                  isLoaded = true;
                });
              });
            }

            Future<void> savePreferences() async {
              setModalState(() => isSaving = true);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('notifications.email_alerts', emailAlerts);
              await prefs.setBool('notifications.push_alerts', pushAlerts);
              await prefs.setBool('notifications.promo_alerts', promoAlerts);

              if (!dialogCtx.mounted) return;
              setModalState(() => isSaving = false);
              Navigator.of(dialogCtx).pop();

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notification preferences saved successfully!'),
                  backgroundColor: primary,
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
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.notifications_active_outlined,
                      color: primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Notification Settings',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: _dark,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: !isLoaded
                    ? const SizedBox(
                        height: 150,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: primary,
                            strokeWidth: 3,
                          ),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Customize how and when you want to receive alerts from AgriDirect.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SwitchListTile.adaptive(
                            activeTrackColor: primary.withValues(alpha: 0.5),
                            activeThumbColor: primary,
                            secondary: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.mail_outline_rounded,
                                color: Colors.blue,
                              ),
                            ),
                            title: Text(
                              'Email Notifications',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: const Text(
                              'Receive order status updates via email',
                            ),
                            value: emailAlerts,
                            onChanged: isSaving
                                ? null
                                : (val) =>
                                      setModalState(() => emailAlerts = val),
                          ),
                          const Divider(height: 16),
                          SwitchListTile.adaptive(
                            activeTrackColor: primary.withValues(alpha: 0.5),
                            activeThumbColor: primary,
                            secondary: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.phonelink_ring_rounded,
                                color: Colors.green,
                              ),
                            ),
                            title: Text(
                              'Push Notifications',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: const Text(
                              'Receive message alerts and activity updates',
                            ),
                            value: pushAlerts,
                            onChanged: isSaving
                                ? null
                                : (val) =>
                                      setModalState(() => pushAlerts = val),
                          ),
                          const Divider(height: 16),
                          SwitchListTile.adaptive(
                            activeTrackColor: primary.withValues(alpha: 0.5),
                            activeThumbColor: primary,
                            secondary: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.local_offer_outlined,
                                color: Colors.orange,
                              ),
                            ),
                            title: Text(
                              'Promotions & Offers',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: const Text(
                              'Get notified of discount codes and local deals',
                            ),
                            value: promoAlerts,
                            onChanged: isSaving
                                ? null
                                : (val) =>
                                      setModalState(() => promoAlerts = val),
                          ),
                        ],
                      ),
              ),
              actionsPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogCtx).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: (!isLoaded || isSaving) ? null : savePreferences,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Save Preferences',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showWebClaimedVouchersDialog() {
    final userId = AuthService().userId;
    showDialog(
      context: context,
      builder: (ctx) {
        bool innerLoading = true;
        List<Map<String, dynamic>> innerVouchers = [];

        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (innerLoading) {
              VoucherService().getUserClaimedVouchersHistory(userId).then((
                list,
              ) {
                setDialogState(() {
                  innerVouchers = list;
                  innerLoading = false;
                });
              });
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                width: 800,
                height: 600,
                padding: const EdgeInsets.all(32),
                color: const Color(0xFFF8FAFC),
                child: innerLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: primary),
                      )
                    : DefaultTabController(
                        length: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'My Claimed Vouchers',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: _dark,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Use your claimed vouchers at checkout to get discounts',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: _muted,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            TabBar(
                              labelColor: primary,
                              unselectedLabelColor: _muted,
                              indicatorColor: primary,
                              indicatorSize: TabBarIndicatorSize.tab,
                              labelStyle: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              tabs: const [
                                Tab(text: 'Active'),
                                Tab(text: 'Used'),
                                Tab(text: 'Expired'),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  _buildWebVouchersTab(innerVouchers, 0),
                                  _buildWebVouchersTab(innerVouchers, 1),
                                  _buildWebVouchersTab(innerVouchers, 2),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWebVouchersTab(
    List<Map<String, dynamic>> vouchers,
    int tabIndex,
  ) {
    final now = DateTime.now();
    final list = vouchers.where((item) {
      final isUsed = item['is_used'] == true;
      final voucher = item['vouchers'] as Map<String, dynamic>?;
      if (voucher == null) return false;

      final endDateStr = voucher['end_date']?.toString();
      final endDate = endDateStr != null ? DateTime.tryParse(endDateStr) : null;
      final isExpired = endDate != null && endDate.isBefore(now);

      if (tabIndex == 0) {
        return !isUsed && !isExpired;
      } else if (tabIndex == 1) {
        return isUsed;
      } else {
        return !isUsed && isExpired;
      }
    }).toList();

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.confirmation_number_outlined,
              size: 56,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No Vouchers Found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Explore farms to claim active discount vouchers.',
              style: GoogleFonts.inter(fontSize: 13, color: _muted),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.go(AppRoutes.marketplace);
              },
              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
              label: const Text('Explore Marketplace'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 110,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final voucher = item['vouchers'] as Map<String, dynamic>;
        final code = voucher['code']?.toString() ?? '';
        final discountType = voucher['discount_type']?.toString() ?? 'fixed';
        final discountVal =
            (voucher['discount_value'] as num?)?.toDouble() ?? 0.0;
        final minSpend = (voucher['min_spend'] as num?)?.toDouble() ?? 0.0;
        final farmName = voucher['farm_name']?.toString() ?? 'Partner Farm';
        final endDateStr = voucher['end_date']?.toString();

        String expiryText = 'Valid Period';
        if (endDateStr != null) {
          final endDate = DateTime.tryParse(endDateStr);
          if (endDate != null) {
            expiryText =
                'Expires ${endDate.month}/${endDate.day}/${endDate.year}';
          }
        }

        final isPercentage = discountType == 'percentage';
        final valueText = isPercentage
            ? '${discountVal.toInt()}%'
            : '₱${discountVal.toInt()}';
        final labelText = isPercentage ? 'Discount' : 'OFF';

        final Color themeColor = tabIndex == 0 ? primary : Colors.grey[400]!;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 90,
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      valueText,
                      style: GoogleFonts.plusJakartaSans(
                        color: themeColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      labelText,
                      style: GoogleFonts.plusJakartaSans(
                        color: themeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: Color(0xFFF1F5F9),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              farmName,
                              style: GoogleFonts.plusJakartaSans(
                                color: tabIndex == 0 ? _dark : Colors.grey[600],
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: tabIndex == 0
                                  ? primary.withValues(alpha: 0.1)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              code,
                              style: GoogleFonts.plusJakartaSans(
                                color: themeColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Min. Spend ₱${minSpend.toInt()}',
                        style: GoogleFonts.inter(
                          color: Colors.grey[600],
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            expiryText,
                            style: GoogleFonts.inter(
                              color: Colors.grey[400],
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (tabIndex == 0)
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                  context.go(AppRoutes.marketplace);
                                },
                                child: Text(
                                  'USE NOW',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _SettingsItem(this.icon, this.title, this.subtitle, {this.onTap});
}

class _EditProfileDialog extends StatefulWidget {
  final AuthService auth;
  final Map<String, dynamic>? farmerProfile;
  final Future<void> Function() onSaveSuccess;

  const _EditProfileDialog({
    required this.auth,
    required this.farmerProfile,
    required this.onSaveSuccess,
  });

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final bool isFarmer;
  late final TextEditingController nameController;
  late final TextEditingController specialtyController;
  late final TextEditingController locationController;
  late final TextEditingController imageController;
  late final TextEditingController bioController;
  late final TextEditingController freeDeliveryMinAmountController;
  late final TextEditingController phoneController;
  late final TextEditingController emailController;

  final formKey = GlobalKey<FormState>();
  bool isSaving = false;
  bool isUploadingImage = false;
  String imageUrl = '';

  @override
  void initState() {
    super.initState();
    isFarmer = widget.auth.isViewingAsFarmer;
    nameController = TextEditingController(
      text: isFarmer && widget.farmerProfile != null
          ? (widget.farmerProfile!['farm_name']?.toString() ??
                widget.auth.userName)
          : widget.auth.userName,
    );
    specialtyController = TextEditingController(
      text: isFarmer && widget.farmerProfile != null
          ? (widget.farmerProfile!['specialty']?.toString() ?? 'Fresh Produce')
          : '',
    );
    locationController = TextEditingController(
      text: isFarmer && widget.farmerProfile != null
          ? (widget.farmerProfile!['location']?.toString() ?? '')
          : '',
    );
    imageController = TextEditingController(
      text: isFarmer && widget.farmerProfile != null
          ? (widget.farmerProfile!['image_url']?.toString() ?? '')
          : widget.auth.userAvatarUrl,
    );
    bioController = TextEditingController(
      text: isFarmer && widget.farmerProfile != null
          ? (widget.farmerProfile!['residential_address']?.toString() ?? '')
          : '',
    );
    freeDeliveryMinAmountController = TextEditingController(
      text: isFarmer && widget.farmerProfile != null
          ? (widget.farmerProfile!['free_delivery_min_amount']?.toString() ??
                '0')
          : '',
    );
    phoneController = TextEditingController();
    emailController = TextEditingController(text: widget.auth.userEmail);

    imageUrl = imageController.text;
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userId = widget.auth.userId;
      final users = await SupabaseConfig.client
          .from('users')
          .select()
          .eq('user_id', userId)
          .limit(1);
      if (users.isNotEmpty && mounted) {
        final user = users[0];
        setState(() {
          phoneController.text = (user['phone'] ?? user['phone_number'] ?? '')
              .toString();
        });
      }
    } catch (e) {
      debugPrint('Error loading user profile details: $e');
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    specialtyController.dispose();
    locationController.dispose();
    imageController.dispose();
    bioController.dispose();
    freeDeliveryMinAmountController.dispose();
    phoneController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    if (isUploadingImage || isSaving) return;

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() => isUploadingImage = true);
    try {
      final bytes = await image.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final path = 'avatars/$fileName';

      final resultPath = await SupabaseDatabase.uploadImage(
        bucket: 'uploads',
        path: path,
        bytes: bytes,
      );

      if (resultPath != null) {
        final publicUrl = SupabaseConfig.client.storage
            .from('uploads')
            .getPublicUrl(path);

        setState(() {
          imageUrl = publicUrl;
          imageController.text = publicUrl;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload image. Please try again.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isUploadingImage = false);
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => isSaving = true);
    try {
      if (isFarmer) {
        final userId = widget.auth.userId;
        await SupabaseConfig.client
            .from('farmers')
            .update({
              'farm_name': nameController.text.trim(),
              'specialty': specialtyController.text.trim(),
              'location': locationController.text.trim(),
              'image_url': imageController.text.trim(),
              'residential_address': bioController.text.trim(),
              'free_delivery_min_amount':
                  double.tryParse(freeDeliveryMinAmountController.text) ?? 0.0,
            })
            .eq('user_id', userId);
      } else {
        final userId = widget.auth.userId;
        await SupabaseConfig.client
            .from('users')
            .update({
              'name': nameController.text.trim(),
              'avatar_url': imageController.text.trim(),
              'bio': bioController.text.trim(),
              'phone': phoneController.text.trim(),
            })
            .eq('user_id', userId);
      }

      await widget.auth.initialize();
      await widget.onSaveSuccess();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      if (mounted) {
        setState(() => isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save changes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF16A34A),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required String value,
    required String label,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
              const Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFF9CA3AF),
                size: 16,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      elevation: 12,
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: 520,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isFarmer
                              ? 'Edit Farm Profile'
                              : 'Edit Personal Profile',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isFarmer
                              ? 'Customize your farm info, location and visuals'
                              : 'Update your personal profile details',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF6B7280),
                    ),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Preview Box
                      Text(
                        isFarmer ? 'Farm Cover Preview' : 'Avatar Preview',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: isFarmer
                            ? GestureDetector(
                                onTap: _pickAndUploadImage,
                                child: Container(
                                  height: 160,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: const Color(0xFFF3F4F6),
                                    border: Border.all(
                                      color: const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: imageUrl.isNotEmpty
                                            ? Image.network(
                                                imageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => Center(
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          const Icon(
                                                            Icons
                                                                .broken_image_outlined,
                                                            size: 40,
                                                            color: Color(
                                                              0xFF9CA3AF,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 8,
                                                          ),
                                                          Text(
                                                            'Failed to load image',
                                                            style: GoogleFonts.plusJakartaSans(
                                                              color:
                                                                  const Color(
                                                                    0xFF6B7280,
                                                                  ),
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                              )
                                            : Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(
                                                      Icons.image_outlined,
                                                      size: 40,
                                                      color: Color(0xFF9CA3AF),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'No cover image provided',
                                                      style:
                                                          GoogleFonts.plusJakartaSans(
                                                            color: const Color(
                                                              0xFF6B7280,
                                                            ),
                                                            fontSize: 12,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                      ),
                                      if (isUploadingImage)
                                        Container(
                                          color: Colors.black.withValues(
                                            alpha: 0.4,
                                          ),
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 3,
                                            ),
                                          ),
                                        )
                                      else
                                        Positioned(
                                          bottom: 12,
                                          right: 12,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(
                                                alpha: 0.6,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.camera_alt_rounded,
                                                  color: Colors.white,
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Change Cover',
                                                  style:
                                                      GoogleFonts.plusJakartaSans(
                                                        color: Colors.white,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              )
                            : Column(
                                children: [
                                  Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      GestureDetector(
                                        onTap: _pickAndUploadImage,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFFE5E7EB),
                                              width: 4,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.05,
                                                ),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              CircleAvatar(
                                                radius: 60,
                                                backgroundColor: const Color(
                                                  0xFFF3F4F6,
                                                ),
                                                backgroundImage:
                                                    imageUrl.isNotEmpty
                                                    ? NetworkImage(imageUrl)
                                                    : null,
                                                child: imageUrl.isEmpty
                                                    ? const Icon(
                                                        Icons.person_rounded,
                                                        size: 60,
                                                        color: Color(
                                                          0xFF9CA3AF,
                                                        ),
                                                      )
                                                    : null,
                                              ),
                                              if (isUploadingImage)
                                                Container(
                                                  width: 120,
                                                  height: 120,
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.4),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                          color: Colors.white,
                                                          strokeWidth: 3,
                                                        ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (!isUploadingImage)
                                        GestureDetector(
                                          onTap: _pickAndUploadImage,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF16A34A),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.camera_alt_rounded,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: isUploadingImage
                                        ? null
                                        : _pickAndUploadImage,
                                    icon: const Icon(
                                      Icons.photo_library_outlined,
                                      size: 16,
                                    ),
                                    label: Text(
                                      isUploadingImage
                                          ? 'Uploading...'
                                          : 'Change Photo',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF16A34A),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 24),

                      // Fields
                      _buildTextField(
                        controller: nameController,
                        label: isFarmer ? 'Farm Name' : 'Full Name',
                        icon: Icons.person_outline_rounded,
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Please enter a name'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      if (isFarmer) ...[
                        _buildTextField(
                          controller: specialtyController,
                          label: 'Specialty',
                          icon: Icons.spa_outlined,
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Please enter farm specialty'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: locationController,
                          label: 'Farm Location Address',
                          icon: Icons.location_on_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: freeDeliveryMinAmountController,
                          label: 'Minimum Order for Free Delivery (₱)',
                          icon: Icons.local_shipping_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            final text = v?.trim() ?? '';
                            if (text.isEmpty) return null;
                            final parsed = double.tryParse(text);
                            if (parsed == null || parsed < 0) {
                              return 'Please enter a valid positive number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        _buildTextField(
                          controller: phoneController,
                          label: 'Phone Number',
                          icon: Icons.phone_rounded,
                        ),
                        const SizedBox(height: 16),
                      ],

                      _buildReadOnlyField(
                        value: emailController.text,
                        label: 'Email Address',
                        icon: Icons.email_outlined,
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: bioController,
                        label: isFarmer ? 'Farm Bio / Description' : 'Bio',
                        icon: Icons.description_outlined,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            // Actions
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF4B5563),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: isSaving ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Save Changes',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
