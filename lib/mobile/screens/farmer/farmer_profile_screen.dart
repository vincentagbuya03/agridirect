import 'dart:async';
import 'package:agridirect/shared/services/social/follow_service.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/router/app_routes.dart';
import 'package:agridirect/shared/widgets/premium_confirm_dialog.dart';

/// Mobile Profile screen specifically for Farmers.
class FarmerProfileScreen extends StatefulWidget {
  final VoidCallback onModeChanged;
  final VoidCallback onLogout;

  const FarmerProfileScreen({
    super.key,
    required this.onModeChanged,
    required this.onLogout,
  });

  @override
  State<FarmerProfileScreen> createState() => _FarmerProfileScreenState();
}

class _FarmerProfileScreenState extends State<FarmerProfileScreen> {
  String? _farmerName;
  String? _farmerImageUrl;
  String? _farmerLocation;
  String? _farmerSpecialty;
  String? _farmerHistory;
  int? _yearsExperience;

  static const Color _primary = Color(0xFF059669);
  static const Color _muted = Color(0xFF64748B);
  static const Color _dark = Color(0xFF0F172A);

  Map<String, dynamic> _dashboardStats = {};

  @override
  void initState() {
    super.initState();
    _loadFarmerData();
    _loadDashboardStats();
  }

  Future<void> _loadDashboardStats() async {
    final auth = AuthService();
    final userId = (SupabaseConfig.currentUser?.id ?? auth.userId).trim();
    if (userId.isEmpty) return;
    try {
      final farmer = await SupabaseConfig.client
          .from('farmers')
          .select('farmer_id')
          .eq('user_id', userId)
          .maybeSingle();

      final farmerId = farmer?['farmer_id']?.toString();
      if (farmerId == null || farmerId.isEmpty) return;

      // 1. Real Followers count from farmer_follows
      final followerCount = await FollowService().getFollowerCount(farmerId);

      // 2. Real Products count from products table
      final productsRes = await SupabaseConfig.client
          .from('products')
          .select('product_id')
          .eq('farmer_id', farmerId);
      final productCount = (productsRes as List).length;

      // 3. Real Rating
      final rating = (farmer?['rating'] as num?)?.toDouble() ?? 5.0;

      if (mounted) {
        setState(() {
          _dashboardStats = {
            'activeListings': productCount,
            'followers': followerCount,
            'rating': rating.toStringAsFixed(1),
          };
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard stats: $e');
    }
  }

  Future<void> _loadFarmerData({int attempt = 0}) async {
    final auth = AuthService();
    final userId = (SupabaseConfig.currentUser?.id ?? auth.userId).trim();
    if (userId.isEmpty) {
      if (attempt < 5) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (!mounted) return;
        return _loadFarmerData(attempt: attempt + 1);
      }
      return;
    }

    try {
      final farmers = await SupabaseConfig.client
          .from('farmers')
          .select(
            'farm_name, image_url, location, specialty, farming_history, years_of_experience',
          )
          .eq('user_id', userId)
          .limit(1);

      if (farmers.isNotEmpty && mounted) {
        setState(() {
          _farmerName = farmers[0]['farm_name'] as String?;
          _farmerLocation = farmers[0]['location'] as String?;
          _farmerSpecialty = farmers[0]['specialty'] as String?;
          _farmerHistory = farmers[0]['farming_history'] as String?;
          _yearsExperience = farmers[0]['years_of_experience'] as int?;
        });
        final rawUrl = farmers[0]['image_url'] as String?;
        final safeUrl = await SupabaseDatabase.getSafeUrl(
          rawUrl,
          defaultBucket: 'uploads',
        );
        if (mounted) {
          setState(() {
            _farmerImageUrl = safeUrl;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading farmer header data: $e');
    }
  }

  Future<void> _confirmLogout() async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PremiumConfirmDialog(
        title: 'Confirm Logout',
        content: 'Are you sure you want to log out of AgriDirect?',
        confirmText: 'Log Out',
        loadingText: 'Logging out...',
        onConfirm: () async {
          await AuthService().logout();
          if (mounted) {
            context.go(AppRoutes.login);
          }
        },
      ),
    );
  }

  void _handleSwitchToCustomer() {
    AuthService().switchToCustomerMode();
    widget.onModeChanged();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          _buildHeroHeader(auth),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMySales(),
                  const SizedBox(height: 24),
                  _buildShopStats(),
                  const SizedBox(height: 24),
                  _buildExploreMore(),
                  const SizedBox(height: 24),
                  _buildAboutMyFarm(),
                  const SizedBox(height: 24),
                  _buildSupportAndLegal(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Hero Header (Green Gradient matching Customer Mode) ───
  Widget _buildHeroHeader(AuthService auth) {
    final displayName = _farmerName ?? auth.userName;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF059669), Color(0xFF10B981)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _handleSwitchToCustomer,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.swap_horiz_rounded,
                            size: 15,
                            color: _primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Buyer Mode',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.settings_outlined,
                      size: 24,
                      color: Colors.white,
                    ),
                    onPressed: () => context.push(AppRoutes.appSettings),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Farm logo avatar
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child:
                          (_farmerImageUrl != null &&
                              _farmerImageUrl!.isNotEmpty)
                          ? CachedNetworkImage(
                              key: ValueKey(_farmerImageUrl),
                              imageUrl: _farmerImageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, _) =>
                                  Container(color: Colors.white24),
                              errorWidget: (_, _, _) => const Icon(
                                Icons.agriculture,
                                size: 32,
                                color: Colors.white54,
                              ),
                            )
                          : Container(
                              color: Colors.white24,
                              child: const Icon(
                                Icons.agriculture,
                                size: 32,
                                color: Colors.white54,
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
                          displayName.isNotEmpty ? displayName : 'My Farm',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () async {
                            await context.push(AppRoutes.myDetails);
                            _loadFarmerData();
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Edit Farm Details',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Farm Stats Section ───
  Widget _buildShopStats() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                await context.push(AppRoutes.farmerFollowers);
                _loadDashboardStats();
              },
              borderRadius: BorderRadius.circular(12),
              child: _buildStatItem(
                '${_dashboardStats['followers'] ?? 0}',
                'Followers',
                Icons.groups_rounded,
                Colors.blue,
              ),
            ),
          ),
          Container(width: 1, height: 30, color: const Color(0xFFF1F5F9)),
          Expanded(
            child: _buildStatItem(
              _dashboardStats['rating']?.toString() ?? '5.0',
              'Rating',
              Icons.star_rounded,
              Colors.amber,
            ),
          ),
          Container(width: 1, height: 30, color: const Color(0xFFF1F5F9)),
          Expanded(
            child: InkWell(
              onTap: () {
                SupabaseDataService.navigationTabNotifier.value =
                    1; // Products tab
                widget.onModeChanged();
              },
              borderRadius: BorderRadius.circular(12),
              child: _buildStatItem(
                '${_dashboardStats['activeListings'] ?? 0}',
                'Products',
                Icons.inventory_2_rounded,
                Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _muted,
          ),
        ),
      ],
    );
  }

  // ─── My Sales Section ───
  Widget _buildMySales() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Sales',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              GestureDetector(
                onTap: () {
                  SupabaseDataService.navigationTabNotifier.value =
                      2; // Orders tab
                  widget.onModeChanged();
                },
                child: Row(
                  children: [
                    Text(
                      'View Sales History',
                      style: GoogleFonts.inter(fontSize: 12, color: _muted),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: _muted,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildIconAction(Icons.dashboard_rounded, 'Dashboard', () {
                SupabaseDataService.navigationTabNotifier.value = 0;
                widget.onModeChanged();
              }),
              _buildIconAction(Icons.inventory_2_outlined, 'My Products', () {
                SupabaseDataService.navigationTabNotifier.value = 1;
                widget.onModeChanged();
              }),
              _buildIconAction(
                Icons.add_circle_outline_rounded,
                'Add Product',
                () => context.push(AppRoutes.addProduct),
              ),
              _buildIconAction(
                Icons.confirmation_number_outlined,
                'Vouchers',
                () => context.push(AppRoutes.farmerVouchers),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Explore More ───
  Widget _buildExploreMore() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explore More',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.9,
            children: [
              _buildGridAction(
                Icons.groups_rounded,
                'Followers',
                Colors.blue,
                () => context.push(AppRoutes.farmerFollowers),
              ),
              _buildGridAction(
                Icons.forum_outlined,
                'Community',
                Colors.green,
                () {
                  SupabaseDataService.navigationTabNotifier.value = 3;
                  widget.onModeChanged();
                },
              ),
              _buildGridAction(
                Icons.chat_bubble_outline_rounded,
                'Messages',
                Colors.orange,
                () => context.push(AppRoutes.farmerMessages),
              ),
              _buildGridAction(
                Icons.shield_outlined,
                'Security',
                Colors.red,
                () => context.push(AppRoutes.appSettings),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── About My Farm ───
  Widget _buildAboutMyFarm() {
    final hasHistory =
        _farmerHistory != null && _farmerHistory!.trim().isNotEmpty;
    final expText = _yearsExperience != null
        ? '$_yearsExperience years'
        : 'Not configured';

    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About My Farm',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          _buildAboutRow(
            Icons.spa_outlined,
            'Specialty',
            _farmerSpecialty ?? 'Not configured',
          ),
          _buildAboutRow(
            Icons.location_on_outlined,
            'Location',
            _farmerLocation ?? 'Not configured',
          ),
          _buildAboutRow(Icons.timeline_outlined, 'Experience', expText),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          Text(
            'Farming History & Bio',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasHistory
                ? _farmerHistory!
                : 'No bio configured yet. Tap Edit Farm Details to describe your farm!',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF64748B),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Support & Legal ───
  Widget _buildSupportAndLegal() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Support & Legal',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          _buildListAction(
            Icons.help_outline_rounded,
            'Help Center',
            () => context.push(AppRoutes.helpCenter),
          ),
          _buildListAction(
            Icons.description_outlined,
            'Terms of Service',
            () => context.push(AppRoutes.termsOfService),
          ),
          _buildListAction(
            Icons.privacy_tip_outlined,
            'Privacy Policy',
            () => context.push(AppRoutes.privacyPolicy),
          ),
          _buildListAction(
            Icons.policy_outlined,
            'Community Rules',
            () => context.push(AppRoutes.communityRules),
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          InkWell(
            onTap: _confirmLogout,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Log Out',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 24, color: const Color(0xFF475569)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF334155),
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconAction(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: const Color(0xFF475569)),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF334155),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridAction(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF334155),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
