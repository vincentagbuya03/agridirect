import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/auth_service.dart';
import '../auth/farmer_registration_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF6F8F6),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildProfileHeader(auth),
                  const SizedBox(height: 20),
                  _buildMenuSection(context),
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

  void _handleStartSelling() {
    final auth = AuthService();
    // If already registered as seller, just switch to farmer mode
    if (auth.isSeller) {
      _handleSwitchToFarmer();
    } else {
      // Show registration screen for new sellers
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FarmerRegistrationScreen(
            onRegistrationComplete: () {
              widget.onModeChanged();
              // Refresh profile to get updated is_seller status
              setState(() {});
            },
          ),
        ),
      );
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

  Widget _buildProfileHeader(AuthService auth) {
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.compare_arrows_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
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
                )
              else if (auth.isSeller)
                GestureDetector(
                  onTap: _handleSwitchToFarmer,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.compare_arrows_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Switch to Selling',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: _handleStartSelling,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.compare_arrows_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Start Selling',
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
                    placeholder: (_, __) => Container(color: Colors.grey[200]),
                    errorWidget: (_, __, ___) =>
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
                          : 'Alex Henderson',
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
                          Icons.location_on_rounded,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'San Francisco, CA',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'MEMBER SINCE 2022',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: primary,
                          letterSpacing: 0.3,
                        ),
                      ),
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
            'Favorites',
            const Color(0xFFEC4899),
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

  Widget _buildMenuItem(IconData icon, String title, Color iconBgColor) {
    return Padding(
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
