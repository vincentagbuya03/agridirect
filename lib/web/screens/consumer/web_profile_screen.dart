import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/widgets/image_widgets.dart';
import '../../widgets/web_change_password_dialog.dart';
import '../../widgets/web_two_factor_dialog.dart';
import '../../widgets/web_consumer_nav_bar.dart';
import 'package:agridirect/shared/widgets/premium_confirm_dialog.dart';
import '../../../shared/services/social/follow_service.dart';
import '../../../shared/models/auth/user_address_model.dart';
import '../../../shared/services/user/user_service.dart';
import '../../../mobile/widgets/address_management_sheets.dart';
import '../../../mobile/screens/profile/manage_device_screen.dart';
import '../../../mobile/screens/profile/account_activity_screen.dart';
import '../../../mobile/screens/consumer/orders_screen.dart';
import '../../widgets/web_vouchers_content.dart';
import '../../widgets/web_notifications_content.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../shared/services/integration/reverse_geocoding_service.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
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
  static const Color _dark = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);

  // Animations
  late AnimationController _fadeInController;


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
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  bool _isSavingProfile = false;
  bool _isUploadingAvatar = false;
  String _avatarUrl = '';
  
  bool _hasMfaEnabled = false;

  Future<void> _checkMfaStatus() async {
    try {
      final res = await SupabaseConfig.client.auth.mfa.listFactors();
      if (mounted) {
        setState(() {
          _hasMfaEnabled = res.totp.isNotEmpty;
        });
      }
    } catch (_) {
      // Ignore
    }
  }

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
            _latitudeController.text = profile['farm_latitude']?.toString() ?? '';
            _longitudeController.text = profile['farm_longitude']?.toString() ?? '';
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
    _latitudeController = TextEditingController();
    _longitudeController = TextEditingController();
    _avatarUrl = auth.userAvatarUrl;

    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _checkMfaStatus();

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
  double? _parseCoordinate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  Future<void> _saveInlineProfileChanges() async {
    setState(() => _isSavingProfile = true);
    final auth = AuthService();
    try {
      // 1. Update basic user table info (applies to both consumer & farmer for phone and avatar)
      final Map<String, dynamic> userUpdates = {
        'avatar_url': _avatarUrl,
        'phone': _phoneController.text.trim(),
      };
      
      // Only update user's full name if in consumer mode
      if (!auth.isViewingAsFarmer) {
        userUpdates['name'] = _nameController.text.trim();
      }

      await SupabaseConfig.client
          .from('users')
          .update(userUpdates)
          .eq('user_id', auth.userId);

      // 2. If viewing as farmer, update the farmers table
      if (auth.isViewingAsFarmer) {
        await SupabaseConfig.client
            .from('farmers')
            .update({
              'farm_name': _nameController.text.trim(),
              'specialty': _specialtyController.text.trim(),
              'location': _locationController.text.trim(),
              'farm_latitude': _parseCoordinate(_latitudeController.text),
              'farm_longitude': _parseCoordinate(_longitudeController.text),
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

    _fadeInController.dispose();
    super.dispose();
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


  int _selectedTab =
      0; // 0: Profile, 1: Addresses, 2: Vouchers, 3: Orders, 4: Notifications, 5: Privacy

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          _buildNavBar(),
          Expanded(
            child: isMobile
                ? _buildMobileLayout(auth)
                : _buildDesktopLayout(auth),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Mobile Layout: compact header + tab strip + content â”€â”€â”€
  Widget _buildMobileLayout(AuthService auth) {
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
      children: [
        // â”€â”€ Compact user header â”€â”€
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              Row(
                children: [
                  ClipOval(
                    child: SafeNetworkImage(
                      imageUrl: profileImageUrl,
                      defaultBucket: 'uploads',
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      placeholder: Container(color: Colors.grey[200]),
                      errorWidget: const Icon(Icons.person, size: 22, color: _muted),
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
                        Row(
                          children: [
                            const Icon(Icons.edit, size: 11, color: _muted),
                            const SizedBox(width: 3),
                            Text(
                              'Edit Profile',
                              style: GoogleFonts.inter(fontSize: 11, color: _muted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Mode switch button
                  GestureDetector(
                    onTap: isFarmer ? _handleSwitchToCustomer : _handleSwitchToFarmer,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isFarmer ? Colors.amber.shade50 : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isFarmer ? Colors.amber.shade300 : primary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        isFarmer ? 'Farmer' : 'Consumer',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isFarmer ? Colors.amber.shade900 : primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // â”€â”€ Horizontal tab strip â”€â”€
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildMobileTab(0, 'Profile', icon: Icons.person_outline),
                    if (!isFarmer) _buildMobileTab(1, 'Addresses', icon: Icons.location_on_outlined),
                    _buildMobileTab(5, 'Privacy', icon: Icons.shield_outlined),
                    _buildMobileTab(3, 'Orders', icon: Icons.shopping_bag_outlined),
                    _buildMobileTab(2, 'Vouchers', icon: Icons.confirmation_number_outlined),
                    _buildMobileTab(4, 'Notifications', icon: Icons.notifications_outlined),
                    _buildMobileTab(7, 'Help', icon: Icons.help_outline_rounded, onTap: () => context.push(AppRoutes.helpCenter)),
                  ],
                ),
              ),
            ],
          ),
        ),
        // â”€â”€ Content scrolls below the sticky header â”€â”€
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(12),
            child: _buildShopeeMainContent(auth),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileTab(int index, String label, {required IconData icon, VoidCallback? onTap}) {
    final isSelected = _selectedTab == index && onTap == null;
    return GestureDetector(
      onTap: onTap ?? () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primary : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€ Desktop Layout: sidebar left + content right â”€â”€â”€
  Widget _buildDesktopLayout(AuthService auth) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 240,
                child: _buildShopeeSidebar(auth, isMobile: false),
              ),
              const SizedBox(width: 24),
              Expanded(child: _buildShopeeMainContent(auth)),
            ],
          ),
        ),
      ),
    );
  }

  // â”€â”€â”€ Shopee Style Left Sidebar â”€â”€â”€
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
              if (!isFarmer) _buildSidebarItem(1, Icons.location_on_outlined, 'Addresses'),
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
                ),
                _buildSidebarItem(
                  2,
                  Icons.confirmation_number_outlined,
                  'My Vouchers',
                ),
              ],

              const Divider(height: 24, color: Color(0xFFF1F5F9)),

              _buildSidebarCategory('PREFERENCES'),
              _buildSidebarItem(
                4,
                Icons.notifications_outlined,
                'Notifications',
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

  // â”€â”€â”€ Shopee Style Main Content Card â”€â”€â”€
  Widget _buildShopeeMainContent(AuthService auth) {
    if (_selectedTab == 1) {
      return _buildAddressesContent();
    } else if (_selectedTab == 5) {
      return _buildPrivacyContent();
    } else if (_selectedTab == 8) {
      return const ManageDeviceScreen(isWebEmbedded: true);
    } else if (_selectedTab == 9) {
      return const AccountActivityScreen(isWebEmbedded: true);
    } else if (_selectedTab == 3) {
      return const OrdersScreen(isWebEmbedded: true);
    } else if (_selectedTab == 2) {
      return const WebClaimedVouchersContent();
    } else if (_selectedTab == 4) {
      return const WebNotificationsContent();
    }

    final isFarmer = auth.isViewingAsFarmer;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobileLayout = constraints.maxWidth < 600;
        final cardPadding = isMobileLayout ? 16.0 : 32.0;

        return Container(
          padding: EdgeInsets.all(cardPadding),
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
                // â”€â”€ Header (responsive) â”€â”€
                if (isMobileLayout) ..._buildMobileHeader(isFarmer)
                else ..._buildDesktopHeader(isFarmer),

                const Divider(height: 32, color: Color(0xFFF1F5F9)),

                // â”€â”€ Farmer Store Performance Banner â”€â”€
                if (isFarmer) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: isMobileLayout
                        ? Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              _buildFarmerMetricItem('Orders', '$_totalOrdersCount', Icons.shopping_bag_outlined),
                              _buildFarmerMetricItem('Followers', '$_followersCount', Icons.people_outline),
                              _buildFarmerMetricItem('Status', 'Verified', Icons.verified_outlined),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildFarmerMetricItem('Total Store Orders', '$_totalOrdersCount', Icons.shopping_bag_outlined),
                              Container(width: 1, height: 32, color: Colors.amber.shade200),
                              _buildFarmerMetricItem('Store Followers', '$_followersCount', Icons.people_outline),
                              Container(width: 1, height: 32, color: Colors.amber.shade200),
                              _buildFarmerMetricItem('Store Status', 'Active & Verified', Icons.verified_outlined),
                            ],
                          ),
                  ),
                ],

                // â”€â”€ Form + Avatar (responsive) â”€â”€
                if (isMobileLayout) ..._buildMobileFormLayout(isFarmer)
                else ..._buildDesktopFormLayout(isFarmer),
              ],
            ),
          ),
        );
      },
    );
  }

  // â”€â”€ Mobile header: icon+title stacked above save button â”€â”€
  List<Widget> _buildMobileHeader(bool isFarmer) {
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isFarmer ? Colors.amber.shade100 : const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isFarmer ? Icons.storefront_rounded : Icons.person_rounded,
              color: isFarmer ? Colors.amber.shade900 : primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(
                      isFarmer ? 'Farm Store Profile' : 'My Personal Profile',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isFarmer ? Colors.amber.shade100 : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        isFarmer ? 'FARMER' : 'CONSUMER',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: isFarmer ? Colors.amber.shade900 : primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isFarmer
                      ? 'Manage your farm store details'
                      : 'Manage your buyer information',
                  style: GoogleFonts.inter(fontSize: 11, color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isSavingProfile ? null : _saveInlineProfileChanges,
          icon: _isSavingProfile
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.check_circle_rounded, size: 16),
          label: Text(_isSavingProfile ? 'Saving...' : (isFarmer ? 'Save Store Details' : 'Save Profile')),
          style: ElevatedButton.styleFrom(
            backgroundColor: isFarmer ? Colors.amber.shade800 : primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    ];
  }

  // â”€â”€ Desktop header: icon+title on left, save button on right â”€â”€
  List<Widget> _buildDesktopHeader(bool isFarmer) {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isFarmer ? Colors.amber.shade100 : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isFarmer ? Icons.storefront_rounded : Icons.person_rounded,
                    color: isFarmer ? Colors.amber.shade900 : primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        children: [
                          Text(
                            isFarmer ? 'Farm Store Profile' : 'My Personal Profile',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: _dark,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: isFarmer ? Colors.amber.shade100 : const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              isFarmer ? 'FARMER MODE' : 'CONSUMER MODE',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isFarmer ? Colors.amber.shade900 : primary,
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
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _isSavingProfile ? null : _saveInlineProfileChanges,
            icon: _isSavingProfile
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check_circle_rounded, size: 16),
            label: Text(_isSavingProfile ? 'Saving...' : (isFarmer ? 'Save Store Details' : 'Save Profile')),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFarmer ? Colors.amber.shade800 : primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    ];
  }
  LatLng _getInitialPin() {
    final lat = _parseCoordinate(_latitudeController.text);
    final lng = _parseCoordinate(_longitudeController.text);
    if (lat != null && lng != null) {
      return LatLng(lat, lng);
    }
    return const LatLng(10.3157, 123.8854);
  }

  Future<void> _openFarmPinPicker() async {
    final mapController = MapController();
    var selectedPin = _getInitialPin();
    var isLocating = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> useCurrentLocation() async {
              setModalState(() => isLocating = true);
              try {
                final serviceEnabled = await Geolocator.isLocationServiceEnabled();
                if (!serviceEnabled) throw Exception('Location services are disabled.');

                var permission = await Geolocator.checkPermission();
                if (permission == LocationPermission.denied) {
                  permission = await Geolocator.requestPermission();
                }

                if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
                  throw Exception('Location permission denied.');
                }

                final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                selectedPin = LatLng(position.latitude, position.longitude);
                mapController.move(selectedPin, 15);
                setModalState(() {});
              } catch (e) {
                if (!mounted) return;
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Unable to get current location: $e'), backgroundColor: Colors.red));
                }
              } finally {
                setModalState(() => isLocating = false);
              }
            }

            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: SizedBox(
                width: 700,
                height: 560,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Pin Farm Location',
                              style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: _dark),
                            ),
                          ),
                          IconButton(onPressed: () => Navigator.of(dialogContext).pop(), icon: const Icon(Icons.close)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Tap anywhere on the map to place your farm pin.', style: GoogleFonts.inter(fontSize: 14, color: _muted)),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: FlutterMap(
                            mapController: mapController,
                            options: MapOptions(
                              initialCenter: selectedPin,
                              initialZoom: 17,
                              minZoom: 5,
                              maxZoom: 19,
                              onTap: (_, point) => setModalState(() => selectedPin = point),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                                subdomains: const ['a', 'b', 'c', 'd'],
                                userAgentPackageName: 'com.agridirect.app',
                                retinaMode: RetinaMode.isHighDensity(context),
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    width: 48,
                                    height: 48,
                                    point: selectedPin,
                                    alignment: Alignment.bottomCenter,
                                    child: const Icon(Icons.location_on, color: primary, size: 40),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isLocating ? null : useCurrentLocation,
                                  icon: isLocating ? const SizedBox(width: 16, height: 16, child: AppShimmerLoader(strokeWidth: 2)) : const Icon(Icons.my_location),
                                  label: const Text('Use Current Location'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Selected: ${selectedPin.latitude.toStringAsFixed(6)}, ${selectedPin.longitude.toStringAsFixed(6)}',
                            style: GoogleFonts.inter(fontSize: 12, color: _muted),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final resolved = await ReverseGeocodingService.resolveFromCoordinates(
                                      latitude: selectedPin.latitude,
                                      longitude: selectedPin.longitude,
                                    );
                                    final fallbackLocation = '${selectedPin.latitude.toStringAsFixed(5)}, ${selectedPin.longitude.toStringAsFixed(5)}';
                                    setState(() {
                                      _latitudeController.text = selectedPin.latitude.toStringAsFixed(6);
                                      _longitudeController.text = selectedPin.longitude.toStringAsFixed(6);
                                      _locationController.text = resolved.hasData ? resolved.fullAddress : fallbackLocation;
                                    });
                                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                                  child: const Text('Use This Pin'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // â”€â”€ Mobile form: avatar on top center, fields below â”€â”€
  List<Widget> _buildMobileFormLayout(bool isFarmer) {
    return [
      Center(
        child: Column(
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isFarmer ? Colors.amber.shade700 : primary,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isFarmer ? Colors.amber : primary).withValues(alpha: 0.15),
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
                            color: isFarmer ? Colors.amber.shade800 : primary,
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
                          size: 40,
                          color: _muted,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isUploadingAvatar ? null : _pickAndUploadInlineAvatar,
              icon: const Icon(Icons.upload_file_rounded, size: 14),
              label: Text(isFarmer ? 'Upload Logo' : 'Select Photo', style: const TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _dark,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      // Form fields full width
      if (isFarmer) ...[
        _buildInlineEditRow(label: 'Farm Store Name', controller: _nameController, icon: Icons.storefront_outlined),
        _buildInlineEditRow(label: 'Farm Specialty', controller: _specialtyController, icon: Icons.grass_outlined),
        _buildInlineEditRow(label: 'Farm Location', controller: _locationController, icon: Icons.location_on_outlined, suffixWidget: IconButton(onPressed: _openFarmPinPicker, icon: const Icon(Icons.map_outlined, color: primary))),
        _buildInlineEditRow(label: 'Business Phone', controller: _phoneController, icon: Icons.phone_outlined),
        _buildInlineEditRow(label: 'Registered Email', controller: _emailController, icon: Icons.mail_outline, readOnly: true, badge: 'Farmer Verified'),
      ] else ...[
        _buildInlineEditRow(label: 'Full Name', controller: _nameController, icon: Icons.person_outline),
        _buildInlineEditRow(label: 'Email Address', controller: _emailController, icon: Icons.mail_outline, readOnly: true, badge: 'Verified'),
        _buildInlineEditRow(label: 'Contact Number', controller: _phoneController, icon: Icons.phone_outlined),
        _buildInlineEditRow(label: 'Account Type', controller: TextEditingController(text: 'Consumer / Buyer Account'), icon: Icons.badge_outlined, readOnly: true),
      ],
    ];
  }

  // â”€â”€ Desktop form: fields on left, avatar on right â”€â”€
  List<Widget> _buildDesktopFormLayout(bool isFarmer) {
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                if (isFarmer) ...[
                  _buildInlineEditRow(label: 'Farm Store Name', controller: _nameController, icon: Icons.storefront_outlined),
                  _buildInlineEditRow(label: 'Farm Specialty', controller: _specialtyController, icon: Icons.grass_outlined),
                  _buildInlineEditRow(label: 'Farm Location', controller: _locationController, icon: Icons.location_on_outlined, suffixWidget: IconButton(onPressed: _openFarmPinPicker, icon: const Icon(Icons.map_outlined, color: primary))),
                  _buildInlineEditRow(label: 'Business Phone', controller: _phoneController, icon: Icons.phone_outlined),
                  _buildInlineEditRow(label: 'Registered Email', controller: _emailController, icon: Icons.mail_outline, readOnly: true, badge: 'Farmer Verified'),
                ] else ...[
                  _buildInlineEditRow(label: 'Full Name', controller: _nameController, icon: Icons.person_outline),
                  _buildInlineEditRow(label: 'Email Address', controller: _emailController, icon: Icons.mail_outline, readOnly: true, badge: 'Verified'),
                  _buildInlineEditRow(label: 'Contact Number', controller: _phoneController, icon: Icons.phone_outlined),
                  _buildInlineEditRow(label: 'Account Type', controller: TextEditingController(text: 'Consumer / Buyer Account'), icon: Icons.badge_outlined, readOnly: true),
                ],
              ],
            ),
          ),
          const SizedBox(width: 36),
          Container(width: 1, height: 240, color: const Color(0xFFF1F5F9)),
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
                      color: (isFarmer ? Colors.amber : primary).withValues(alpha: 0.15),
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
                              color: isFarmer ? Colors.amber.shade800 : primary,
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
                onPressed: _isUploadingAvatar ? null : _pickAndUploadInlineAvatar,
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                label: Text(isFarmer ? 'Upload Store Logo' : 'Select Photo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _dark,
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    ];
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
    Widget? suffixWidget,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 480;

        final field = Expanded(
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
              suffixIcon: badge != null
                  ? Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        badge,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF166534),
                        ),
                      ),
                    )
                  : suffixWidget,
              suffixIconConstraints: const BoxConstraints(minHeight: 0, minWidth: 0),
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
        );

        if (isMobile) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(children: [field]),
              ],
            ),
          );
        }

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
              field,
            ],
          ),
        );
      },
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
                      if (!context.mounted) return;
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
                                if (!context.mounted) return;
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
                                    if (!context.mounted) return;
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Container(
          padding: EdgeInsets.all(isMobile ? 16 : 32),
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
                  fontSize: isMobile ? 18 : 20,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage password protection, account authentication, and privacy controls',
                style: GoogleFonts.inter(fontSize: 12, color: _muted),
              ),
              const Divider(height: 32, color: Color(0xFFF1F5F9)),

              // 1. Password & Security
              _buildPrivacySettingRow(
                icon: Icons.lock_outline_rounded,
                title: 'Account Password',
                description:
                    'Change your account password regularly to keep your profile secure.',
                buttonText: 'Change Password',
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => const WebChangePasswordDialog(),
                  );
                },
              ),
              const Divider(height: 24, color: Color(0xFFF1F5F9)),

              // 2. Multi-factor Authentication
              _buildPrivacySettingRow(
                icon: Icons.security_rounded,
                title: 'Two-Factor Authentication (2FA)',
                description:
                    'Add an extra layer of security with an Authenticator App.',
                buttonText: _hasMfaEnabled ? 'Manage 2FA' : 'Enable 2FA',
                badge: _hasMfaEnabled ? 'Active' : 'Recommended',
                onTap: () async {
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (context) => WebTwoFactorDialog(
                      initialIsActive: _hasMfaEnabled,
                    ),
                  );
                  if (result == true) {
                    _checkMfaStatus();
                  }
                },
              ),
              const Divider(height: 24, color: Color(0xFFF1F5F9)),

              // 3. Login Activity
              _buildPrivacySettingRow(
                icon: Icons.devices_rounded,
                title: 'Manage Login Device',
                description:
                    'Review the devices that you have logged in AgriDirect account.',
                buttonText: 'Manage Device',
                onTap: () => setState(() => _selectedTab = 8),
              ),
              const Divider(height: 24, color: Color(0xFFF1F5F9)),

              // 3.5. Account Activity
              _buildPrivacySettingRow(
                icon: Icons.history_rounded,
                title: 'Check Account Activity',
                description:
                    'Check your login and account changes in the last 30 days.',
                buttonText: 'View Activity',
                onTap: () => setState(() => _selectedTab = 9),
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
      },
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 500;

        final titleRow = Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            if (badge != null)
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
        );

        final btn = OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: _dark,
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          child: Text(
            buttonText,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        );

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: const Color(0xFF475569)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: titleRow),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: _muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: btn),
            ],
          );
        }

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
                  titleRow,
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
            const SizedBox(width: 12),
            btn,
          ],
        );
      },
    );
  }



  // â”€â”€â”€ Navigation Bar â”€â”€â”€
  Widget _buildNavBar() {
    return WebConsumerNavBar(
      currentIndex: widget.currentIndex,
      onNavigate: widget.onNavigate,
      onCartTap: () => context.go(AppRoutes.cart),
    );
  }
}
