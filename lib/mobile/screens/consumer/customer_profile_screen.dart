import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/commerce/order_service.dart';
import '../../../shared/widgets/premium_confirm_dialog.dart';

class CustomerProfileScreen extends StatefulWidget {
  final VoidCallback onModeChanged;
  final VoidCallback onLogout;

  const CustomerProfileScreen({
    super.key,
    required this.onModeChanged,
    required this.onLogout,
  });

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  String? _customerImageUrl;

  int _pendingCount = 0;
  int _toShipCount = 0;
  int _toReceiveCount = 0;
  int _toRateCount = 0;
  StreamSubscription? _orderSubscription;

  static const Color _primary = Color(0xFF059669);
  static const Color _muted = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _loadCustomerData();
    _startOrderSubscription();
  }

  void _startOrderSubscription() {
    try {
      _orderSubscription = OrderService().watchMyOrders().listen((orders) {
        if (!mounted) return;
        int pending = 0;
        int toShip = 0;
        int toReceive = 0;
        int toRate = 0;

        for (final order in orders) {
          switch (order.status) {
            case 'PENDING':
              pending++;
              break;
            case 'CONFIRMED':
            case 'PROCESSING':
              toShip++;
              break;
            case 'SHIPPED':
              toReceive++;
              break;
            case 'DELIVERED':
              toRate++; // Assuming delivered orders need rating
              break;
          }
        }

        setState(() {
          _pendingCount = pending;
          _toShipCount = toShip;
          _toReceiveCount = toReceive;
          _toRateCount = toRate;
        });
      });
    } catch (e) {
      debugPrint('Error subscribing to orders: $e');
    }
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCustomerData({int attempt = 0}) async {
    final auth = AuthService();
    final userId = (SupabaseConfig.currentUser?.id ?? auth.userId).trim();
    if (userId.isEmpty) {
      if (attempt < 5) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (!mounted) return;
        return _loadCustomerData(attempt: attempt + 1);
      }
      return;
    }

    try {
      final users = await SupabaseConfig.client
          .from('users')
          .select('avatar_url')
          .eq('user_id', userId)
          .limit(1);

      if (users.isNotEmpty && mounted) {
        final rawUrl = users[0]['avatar_url'] as String?;
        final safeUrl = await SupabaseDatabase.getSafeUrl(
          rawUrl,
          defaultBucket: 'uploads',
        );
        if (mounted) {
          setState(() {
            _customerImageUrl = safeUrl;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading customer profile data: $e');
    }
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
    final auth = AuthService();
    if (auth.isSeller) {
      auth.switchToFarmerMode();
      widget.onModeChanged();
    } else if (auth.registrationStatus == 'pending' ||
        auth.registrationStatus == 'under_review') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Your registration is pending admin review.'),
          backgroundColor: _primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      context.push(AppRoutes.farmerRegister, extra: widget.onModeChanged);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Light grey background
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeroHeader(auth),
            const SizedBox(height: 12),
            _buildMyPurchases(),
            const SizedBox(height: 12),
            _buildExploreMore(),
            const SizedBox(height: 12),
            _buildAdditionalServices(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─── Hero Header ───
  Widget _buildHeroHeader(AuthService auth) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF059669), Color(0xFF10B981)], // AgriDirect Green
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, size: 24, color: Colors.white),
                    onPressed: () => context.push(AppRoutes.appSettings),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: ClipOval(
                      child: (_customerImageUrl != null &&
                              _customerImageUrl!.isNotEmpty)
                          ? CachedNetworkImage(
                              key: ValueKey(_customerImageUrl),
                              imageUrl: _customerImageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, _) =>
                                  Container(color: Colors.white24),
                              errorWidget: (_, _, _) => const Icon(
                                  Icons.person,
                                  size: 32,
                                  color: Colors.white54),
                            )
                          : Container(
                              color: Colors.white24,
                              child: const Icon(Icons.person,
                                  size: 32, color: Colors.white54),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.userName.isNotEmpty ? auth.userName : 'User',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => context.push(AppRoutes.myDetails),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Edit Profile',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.white70),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _handleSwitchToFarmer,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        auth.isSeller
                            ? 'Farmer Mode'
                            : (auth.registrationStatus == 'pending'
                                ? 'Pending Review'
                                : 'Become a Seller'),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _primary,
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
    );
  }

  // ─── My Purchases ───
  Widget _buildMyPurchases() {
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
                'My Purchases',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              GestureDetector(
                onTap: () => context.push(AppRoutes.customerOrders),
                child: Row(
                  children: [
                    Text(
                      'View Purchase History',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _muted,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 16, color: _muted),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildIconAction(Icons.account_balance_wallet_outlined, 'Pending', () => context.push('${AppRoutes.customerOrders}?tab=0'), badgeCount: _pendingCount),
              _buildIconAction(Icons.inventory_2_outlined, 'To Ship', () => context.push('${AppRoutes.customerOrders}?tab=1'), badgeCount: _toShipCount),
              _buildIconAction(Icons.local_shipping_outlined, 'To Receive', () => context.push('${AppRoutes.customerOrders}?tab=2'), badgeCount: _toReceiveCount),
              _buildIconAction(Icons.star_outline_rounded, 'To Rate', () => context.push('${AppRoutes.customerOrders}?tab=3'), badgeCount: _toRateCount),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Explore More (Grid) ───
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
              _buildGridAction(Icons.favorite_outline_rounded, 'Favorites', Colors.red, () => context.push(AppRoutes.favorites)),
              _buildGridAction(Icons.confirmation_number_outlined, 'Vouchers', Colors.orange, () => context.push(AppRoutes.claimedVouchers)),
              _buildGridAction(Icons.location_on_outlined, 'Addresses', Colors.blue, () => context.push(AppRoutes.addressBook)),
              _buildGridAction(Icons.chat_bubble_outline_rounded, 'Messages', Colors.green, () => context.push(AppRoutes.customerMessages)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalServices() {
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
          _buildListAction(Icons.help_outline_rounded, 'Help Center', () => context.push(AppRoutes.helpCenter)),
          _buildListAction(Icons.description_outlined, 'Terms of Service', () => context.push(AppRoutes.termsOfService)),
          _buildListAction(Icons.privacy_tip_outlined, 'Privacy Policy', () => context.push(AppRoutes.privacyPolicy)),
          _buildListAction(Icons.policy_outlined, 'Community Rules', () => context.push(AppRoutes.communityRules)),
          _buildListAction(
            Icons.logout_rounded, 
            'Log Out', 
            _confirmLogout,
            color: const Color(0xFFEF4444),
          ),
        ],
      ),
    );
  }

  Widget _buildListAction(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    final effectiveColor = color ?? const Color(0xFF475569);
    final effectiveTextColor = color ?? const Color(0xFF334155);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 24, color: effectiveColor),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: effectiveTextColor,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: color ?? const Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildIconAction(IconData icon, String label, VoidCallback onTap, {int badgeCount = 0}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 26, color: const Color(0xFF475569)),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444), // Red color for badge
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridAction(IconData icon, String label, Color color, VoidCallback onTap) {
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
