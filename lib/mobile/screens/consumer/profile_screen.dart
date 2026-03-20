import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/config/supabase_config.dart';
import '../../../shared/router/app_router.dart';

/// Mobile Profile screen for customers.
/// Contains user info, settings, and the "Start Selling" button
/// that registers the user as a farmer. Once registered, they can
/// switch between customer and farmer modes.
class MobileProfileScreen extends StatefulWidget {
  final VoidCallback onModeChanged;
  final VoidCallback onLogout;

  const MobileProfileScreen({
    super.key,
    required this.onModeChanged,
    required this.onLogout,
  });

  @override
  State<MobileProfileScreen> createState() => _MobileProfileScreenState();
}

class _MobileProfileScreenState extends State<MobileProfileScreen> {
  static const Color primary = Color(0xFF13EC5B);

  String? _registrationStatus; // null, 'pending', 'approved', 'rejected'
  bool _checkingStatus = false;
  bool _isPageLoading = true;

  @override
  void initState() {
    super.initState();
    _checkRegistrationStatus();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _isPageLoading = false);
    });
  }

  Future<void> _checkRegistrationStatus() async {
    final auth = AuthService();
    if (auth.isSeller) return;

    setState(() => _checkingStatus = true);
    final reg = await SupabaseDB.getFarmerRegistration(auth.userId);
    if (mounted) {
      setState(() {
        _registrationStatus = reg?['status'] as String?;
        _checkingStatus = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        if (auth.isViewingAsFarmer) {
          return _buildFarmerScaffold(context, auth);
        }
        return Scaffold(
          backgroundColor: const Color(0xFFF6F8F6),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildProfileHeader(auth),
                  const SizedBox(height: 20),
                  Skeletonizer(
                    enabled: _isPageLoading,
                    child: _buildMenuSection(context),
                  ),
                  const SizedBox(height: 20),
                  _buildLogoutButton(),
                  const SizedBox(height: 12),
                  Text(
                    'Version 2.4.1 (Build 402)',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // =========================================================================
  // FARMER PROFILE UI
  // =========================================================================

  Widget _buildFarmerScaffold(BuildContext context, AuthService auth) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FFF4),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildFarmerHeader(auth),
              Skeletonizer(
                enabled: _isPageLoading,
                child: _buildFarmerStatsRow(),
              ),
              const SizedBox(height: 16),
              Skeletonizer(
                enabled: _isPageLoading,
                child: _buildFarmerMenuSection(context),
              ),
              const SizedBox(height: 20),
              _buildLogoutButton(),
              const SizedBox(height: 12),
              Text(
                'Version 2.4.1 (Build 402)',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFarmerHeader(AuthService auth) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF13EC5B), Color(0xFF059950)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: 40,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: title + switch button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.eco_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Farm Profile',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: _handleSwitchToCustomer,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shopping_cart_outlined, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              'Switch to Buying',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Avatar + info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl:
                                  'https://lh3.googleusercontent.com/aida-public/AB6AXuA7SO8J3CebwmP_4K0nwWhDkMsWISrTpnfbOkYJ79_ZiTCLVxdvX_FJArJ1xwYsLAJx8gW_Wtk3xValGb9mDShlpRvdPIMoD9UGWJ9LwNRlF0vvmsKesjK6liNaDGy7C5HGWdOAE1hEPvF3UTq81_QK7QkgKAAMQgeICa4pykDXTF8JYtnrFYPiavyC7N-wkK4pGMGQJcdoyKpRglzbFXWGqTdoa3xP-Bm86BGxFKlWg21Mbw-FylTfHiJeJMKgLbfSJr8MhPFg1zqB',
                              fit: BoxFit.cover,
                              placeholder: (_, _) => Container(color: Colors.white24),
                              errorWidget: (_, _, _) => Container(
                                color: Colors.white24,
                                child: const Icon(Icons.person, size: 36, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Color(0xFF059950),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, size: 10, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.userName.isNotEmpty ? auth.userName : 'Farmer',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified_rounded, size: 13, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  'Verified Farmer',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.email_outlined, size: 13, color: Colors.white70),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  auth.userEmail.isNotEmpty ? auth.userEmail : 'No email',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmerStatsRow() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF13EC5B).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatItem(Icons.inventory_2_outlined, 'Products', '—', const Color(0xFF13EC5B)),
          _buildStatDivider(),
          _buildStatItem(Icons.receipt_long_outlined, 'Orders', '—', const Color(0xFF3B82F6)),
          _buildStatDivider(),
          _buildStatItem(Icons.star_rounded, 'Rating', '—', const Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 40, color: const Color(0xFFF1F5F9));
  }

  Widget _buildFarmerMenuSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildFarmerMenuHeader('Farm Management'),
          _buildMenuItem(
            Icons.storefront_rounded,
            'My Farm Details',
            const Color(0xFF13EC5B),
          ),
          _buildDivider(),
          _buildMenuItem(
            Icons.inventory_2_rounded,
            'My Products',
            const Color(0xFF3B82F6),
          ),
          _buildDivider(),
          _buildMenuItem(
            Icons.receipt_long_rounded,
            'My Orders',
            const Color(0xFF8B5CF6),
          ),
          _buildDivider(),
          _buildMenuItem(
            Icons.payments_rounded,
            'Earnings & Payouts',
            const Color(0xFF10B981),
          ),
          _buildFarmerMenuHeader('Account'),
          _buildMenuItem(
            Icons.chat_bubble_outline_rounded,
            'Messages',
            const Color(0xFF06B6D4),
            onTap: () => context.push(AppRoutes.messages),
          ),
          _buildDivider(),
          _buildMenuItem(
            Icons.notifications_outlined,
            'Notifications',
            const Color(0xFFEF4444),
            onTap: () => context.push(AppRoutes.notifications),
          ),
          _buildDivider(),
          _buildMenuItem(
            Icons.help_rounded,
            'Help Center',
            const Color(0xFFF59E0B),
          ),
          _buildDivider(),
          _buildMenuItem(
            Icons.settings_rounded,
            'App Settings',
            const Color(0xFF6B7280),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmerMenuHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey[400],
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStartSelling() async {
    final auth = AuthService();

    // Already a seller — just switch mode
    if (auth.isSeller) {
      _handleSwitchToFarmer();
      return;
    }

    // Pending application
    if (_registrationStatus == 'pending') {
      _showPendingDialog();
      return;
    }

    // Rejected application
    if (_registrationStatus == 'rejected') {
      _showRejectedDialog();
      return;
    }

    // No application yet — go to registration
    context.push(AppRoutes.farmerRegister, extra: () {
      widget.onModeChanged();
      setState(() {});
    });
  }

  void _showPendingDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_top_rounded, size: 42, color: Color(0xFFF59E0B)),
              ),
              const SizedBox(height: 20),
              Text(
                'Application Under Review',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Your farmer registration is currently being reviewed by our team. Verification typically takes 1–3 business days.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.notifications_active_outlined, size: 14, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 6),
                    Text(
                      "We'll notify you once it's approved.",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text('Got it', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRejectedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cancel_rounded, size: 42, color: Color(0xFFEF4444)),
              ),
              const SizedBox(height: 20),
              Text(
                'Application Rejected',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Unfortunately, your farmer registration was not approved. You may review your information and try again.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        // Clear status so they can re-register
                        setState(() => _registrationStatus = null);
                        context.push(AppRoutes.farmerRegister, extra: () {
                          widget.onModeChanged();
                          setState(() {});
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text('Try Again', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700)),
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

  void _handleSwitchToFarmer() {
    AuthService().switchToFarmerMode();
    widget.onModeChanged();
  }

  void _handleSwitchToCustomer() {
    AuthService().switchToCustomerMode();
    widget.onModeChanged();
  }

  Widget _buildProfileHeader(AuthService auth) {
    // Determine button label and color based on registration status
    String buttonLabel = 'Start Selling';
    Color buttonColor = primary;
    bool isPending = _registrationStatus == 'pending';
    bool isRejected = _registrationStatus == 'rejected';

    if (isPending) {
      buttonLabel = 'Pending Review';
      buttonColor = const Color(0xFFF59E0B);
    } else if (isRejected) {
      buttonLabel = 'Rejected';
      buttonColor = const Color(0xFFEF4444);
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Profile',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              if (auth.isViewingAsFarmer)
                GestureDetector(
                  onTap: _handleSwitchToCustomer,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.compare_arrows_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text('Switch to Buying', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
                  ),
                )
              else if (auth.isSeller)
                GestureDetector(
                  onTap: _handleSwitchToFarmer,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.compare_arrows_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text('Switch to Selling', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
                  ),
                )
              else if (_checkingStatus)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
                  child: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                GestureDetector(
                  onTap: _handleStartSelling,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: buttonColor, borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        isPending ? Icons.hourglass_top_rounded : isRejected ? Icons.info_outline_rounded : Icons.compare_arrows_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(buttonLabel, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          // Profile info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: primary, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl:
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuA7SO8J3CebwmP_4K0nwWhDkMsWISrTpnfbOkYJ79_ZiTCLVxdvX_FJArJ1xwYsLAJx8gW_Wtk3xValGb9mDShlpRvdPIMoD9UGWJ9LwNRlF0vvmsKesjK6liNaDGy7C5HGWdOAE1hEPvF3UTq81_QK7QkgKAAMQgeICa4pykDXTF8JYtnrFYPiavyC7N-wkK4pGMGQJcdoyKpRglzbFXWGqTdoa3xP-Bm86BGxFKlWg21Mbw-FylTfHiJeJMKgLbfSJr8MhPFg1zqB',
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(color: Colors.grey[200]),
                    errorWidget: (_, _, _) =>
                        const Icon(Icons.person, size: 30),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auth.userName.isNotEmpty
                          ? auth.userName
                          : 'User',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            auth.userEmail.isNotEmpty
                                ? auth.userEmail
                                : 'No email',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItem(
            Icons.person_outline,
            'My Details',
            const Color(0xFF3B82F6),
          ),
          _buildDivider(),
          _buildMenuItem(
            Icons.location_on_rounded,
            'Address Book',
            const Color(0xFFFF9500),
          ),
          _buildDivider(),
          _buildMenuItem(
            Icons.credit_card_rounded,
            'Payment Methods',
            const Color(0xFF10B981),
          ),
          _buildDivider(),
          _buildMenuItem(
            Icons.favorite_rounded,
            'My Wishlist',
            const Color(0xFFEC4899),
          ),
          _buildDivider(),
          _buildMenuItem(
            Icons.people_rounded,
            'Following',
            const Color(0xFFF59E0B),
          ),
          _buildDivider(),
          _buildMenuItem(
            Icons.chat_bubble_outline_rounded,
            'Messages',
            const Color(0xFF06B6D4),
            onTap: () => context.push(AppRoutes.messages),
          ),
          _buildDivider(),
          _buildMenuItem(
            Icons.notifications_outlined,
            'Notifications',
            const Color(0xFFEF4444),
            onTap: () => context.push(AppRoutes.notifications),
          ),
          _buildDivider(),
          _buildMenuItem(
            Icons.help_rounded,
            'Help Center',
            const Color(0xFF8B5CF6),
          ),
          _buildDivider(),
          _buildMenuItem(
            Icons.settings_rounded,
            'App Settings',
            const Color(0xFF6B7280),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, Color iconBgColor, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconBgColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[300], size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: const Color(0xFFF1F5F9),
      indent: 60,
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: widget.onLogout,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text(
                'Log Out',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
