import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/data/app_data.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/commerce/cart_service.dart';
import '../../../shared/services/commerce/voucher_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/services/social/follow_service.dart';
import '../../../shared/utils/share_util.dart';
import '../../../shared/widgets/image_widgets.dart';
import '../../../shared/widgets/share_bottom_sheet.dart';
import '../../constants/web_design_tokens.dart';
import '../../widgets/ecom/web_ecom_header.dart';
import '../../widgets/kiko/web_kiko_chatbot_widget.dart';
import '../../widgets/web_footer.dart';

/// Helper functions for safe numeric parsing from Supabase dynamic responses
double _safeDouble(dynamic val, [double fallback = 0.0]) {
  if (val == null) return fallback;
  if (val is num) return val.toDouble();
  return double.tryParse(val.toString()) ?? fallback;
}

int _safeInt(dynamic val, [int fallback = 0]) {
  if (val == null) return fallback;
  if (val is num) return val.toInt();
  return int.tryParse(val.toString()) ?? fallback;
}

/// WebFarmerPublicProfileScreen
/// Premium e-commerce flagship storefront for verified local farmers.
/// Fully dynamic: Real reviews from `farmer_ratings` and `product_reviews`,
/// dynamic ratings distribution, live inventory, dynamic followers, and direct messaging.
class WebFarmerPublicProfileScreen extends StatefulWidget {
  final String farmerId;

  const WebFarmerPublicProfileScreen({super.key, required this.farmerId});

  @override
  State<WebFarmerPublicProfileScreen> createState() =>
      _WebFarmerPublicProfileScreenState();
}

class _WebFarmerPublicProfileScreenState
    extends State<WebFarmerPublicProfileScreen>
    with TickerProviderStateMixin {
  // Brand Color Palette
  static const Color _primary = Color(0xFF005A36);
  static const Color _emerald = Color(0xFF16A34A);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);
  static const Color _cardBg = Colors.white;

  late final Future<Map<String, dynamic>?> _profileFuture;
  late final Future<List<Map<String, dynamic>>> _reviewsFuture;
  late final TabController _tabController;
  final _followService = FollowService();
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isFollowing = false;
  bool _isFollowBusy = false;
  int _followerCount = 0;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedSort = 'Featured';

  bool _isUploadingCover = false;
  String? _customCoverUrl;

  Future<void> _pickAndUploadCoverPhoto() async {
    if (_isUploadingCover) return;
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() => _isUploadingCover = true);
    try {
      final bytes = await image.readAsBytes();
      final ext = image.name.split('.').last;
      final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = 'covers/$fileName';

      await SupabaseConfig.client.storage
          .from('uploads')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/${ext == "png" ? "png" : "jpeg"}',
              upsert: true,
            ),
          );

      final publicUrl = SupabaseConfig.client.storage
          .from('uploads')
          .getPublicUrl(path);

      // Update farmers table in database
      final userId = AuthService().userId;
      if (userId.isNotEmpty) {
        await SupabaseConfig.client
            .from('farmers')
            .update({
              'image_url': publicUrl,
            })
            .eq('user_id', userId);
      } else if (widget.farmerId.isNotEmpty) {
        await SupabaseConfig.client
            .from('farmers')
            .update({
              'image_url': publicUrl,
            })
            .eq('farmer_id', widget.farmerId);
      }

      if (!mounted) return;

      setState(() {
        _customCoverUrl = publicUrl;
        _isUploadingCover = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text('Farm cover photo updated successfully!')),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      debugPrint('Error uploading cover photo: $e');
      if (!mounted) return;
      setState(() => _isUploadingCover = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload cover photo: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _profileFuture = SupabaseDataService().getFarmerProfileByFarmerId(
      widget.farmerId,
    );
    _reviewsFuture = _fetchFarmerReviews(widget.farmerId);
    _profileFuture.then((profile) {
      if (profile != null && mounted) {
        _loadFollowState(profile);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Fetches real reviews for this farmer from both `farmer_ratings` and `product_reviews`
  Future<List<Map<String, dynamic>>> _fetchFarmerReviews(String farmerId) async {
    final List<Map<String, dynamic>> combinedReviews = [];

    // 1. Fetch store ratings from `farmer_ratings` table
    try {
      final dynamic farmerRatingsRes = await SupabaseConfig.client
          .from('farmer_ratings')
          .select('*, customers(users(name, avatar_url))')
          .eq('farmer_id', farmerId)
          .order('created_at', ascending: false);

      if (farmerRatingsRes is List) {
        for (final row in farmerRatingsRes) {
          final data = Map<String, dynamic>.from(row as Map);
          data['review_type'] = 'farmer_rating';
          combinedReviews.add(data);
        }
      }
    } catch (e) {
      debugPrint('Note: query farmer_ratings without join: $e');
      try {
        final dynamic farmerRatingsRes = await SupabaseConfig.client
            .from('farmer_ratings')
            .select('*')
            .eq('farmer_id', farmerId)
            .order('created_at', ascending: false);

        if (farmerRatingsRes is List) {
          for (final row in farmerRatingsRes) {
            final data = Map<String, dynamic>.from(row as Map);
            data['review_type'] = 'farmer_rating';
            combinedReviews.add(data);
          }
        }
      } catch (_) {}
    }

    // 2. Fetch product reviews from `product_reviews` table for products of this farmer
    try {
      final dynamic prodRes = await SupabaseConfig.client
          .from('products')
          .select('product_id, name')
          .eq('farmer_id', farmerId);

      if (prodRes is List && prodRes.isNotEmpty) {
        final productIds = prodRes.map((p) => p['product_id']).toList();
        final Map<String, String> productNames = {
          for (var p in prodRes)
            p['product_id'].toString(): p['name']?.toString() ?? 'Product',
        };

        final dynamic prodReviewsRes = await SupabaseConfig.client
            .from('product_reviews')
            .select('*, customers(users(name, avatar_url)), review_images(image_url)')
            .inFilter('product_id', productIds)
            .order('created_at', ascending: false);

        if (prodReviewsRes is List) {
          for (final row in prodReviewsRes) {
            final data = Map<String, dynamic>.from(row as Map);
            data['review_type'] = 'product_review';
            data['product_name'] = productNames[data['product_id']?.toString()];
            final imgList = (row['review_images'] as List?)
                ?.map((i) => i['image_url']?.toString() ?? '')
                .where((u) => u.isNotEmpty)
                .toList() ?? [];
            data['images'] = imgList;
            combinedReviews.add(data);
          }
        }
      }
    } catch (e) {
      debugPrint('Note: query product_reviews: $e');
    }

    // 3. Resolve customer names for entries where customer relationship didn't nest
    for (final rev in combinedReviews) {
      final nestedUser = rev['customers']?['users'];
      if (nestedUser != null && nestedUser['name'] != null) {
        rev['resolved_customer_name'] = nestedUser['name'];
        rev['resolved_customer_avatar'] = nestedUser['avatar_url'];
      } else if (rev['customer_id'] != null) {
        try {
          final custRes = await SupabaseConfig.client
              .from('customers')
              .select('users(name, avatar_url)')
              .eq('customer_id', rev['customer_id'])
              .maybeSingle();
          final u = custRes?['users'];
          if (u != null) {
            rev['resolved_customer_name'] = u['name'];
            rev['resolved_customer_avatar'] = u['avatar_url'];
          }
        } catch (_) {}
      }
    }

    // Sort combined reviews by creation timestamp descending
    combinedReviews.sort((a, b) {
      final da = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
      final db = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
      return db.compareTo(da);
    });

    return combinedReviews;
  }

  bool _isOwnProfile(Map<String, dynamic> farmer) =>
      AuthService().userId.isNotEmpty &&
      AuthService().userId == (farmer['user_id']?.toString() ?? '');

  Future<void> _loadFollowState(Map<String, dynamic> farmer) async {
    if (_isOwnProfile(farmer)) return;

    final state = await _followService.getFollowState(widget.farmerId);
    if (!mounted) return;
    setState(() {
      _isFollowing = state['isFollowing'] as bool? ?? false;
      _followerCount = _safeInt(state['followers'], 0);
    });
  }

  Future<void> _toggleFollow(Map<String, dynamic> farmer) async {
    if (_isFollowBusy || _isOwnProfile(farmer)) return;

    if (!AuthService().isLoggedIn) {
      _showLoginRequiredDialog('follow this farm');
      return;
    }

    setState(() => _isFollowBusy = true);
    try {
      final isNowFollowing = await _followService.toggleFollowFarmer(
        farmerId: widget.farmerId,
        farmerUserId: farmer['user_id']?.toString(),
        farmName: _farmName(farmer),
      );
      if (!mounted) return;

      setState(() {
        _isFollowing = isNowFollowing;
        _followerCount += isNowFollowing ? 1 : -1;
        if (_followerCount < 0) _followerCount = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _primary,
          content: Text(
            isNowFollowing
                ? 'You are now following ${_farmName(farmer)}!'
                : 'Unfollowed ${_farmName(farmer)}.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isFollowBusy = false);
      }
    }
  }

  void _handleMessageFarmer(Map<String, dynamic> farmer) {
    if (_isOwnProfile(farmer)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('You cannot start a chat with your own farm profile.'),
        ),
      );
      return;
    }

    if (!AuthService().isLoggedIn) {
      _showLoginRequiredDialog('message this farmer');
      return;
    }

    context.go('${AppRoutes.messages}?farmerId=${widget.farmerId}');
  }

  void _showLoginRequiredDialog(String actionDescription) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: _primary),
            const SizedBox(width: 10),
            Text(
              'Sign In Required',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: _dark,
              ),
            ),
          ],
        ),
        content: Text(
          'Please sign in to your AgriDirect account to $actionDescription and connect with local producers.',
          style: GoogleFonts.inter(fontSize: 14, color: _muted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: _muted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go(AppRoutes.login);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Sign In',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNav(int index) {
    context.go(AppRoutes.webTabRoute(index));
  }

  String _farmName(Map<String, dynamic> farmer) =>
      farmer['farm_name']?.toString().trim().isNotEmpty == true
          ? farmer['farm_name'].toString()
          : (farmer['farmer_name']?.toString().trim().isNotEmpty == true
              ? farmer['farmer_name'].toString()
              : (farmer['full_name']?.toString().trim().isNotEmpty == true
                  ? farmer['full_name'].toString()
                  : 'Farm'));

  String _specialty(Map<String, dynamic> farmer) =>
      farmer['specialty']?.toString().trim().isNotEmpty == true
          ? farmer['specialty'].toString()
          : 'Fresh Organic Produce & Farm Goods';

  String _location(Map<String, dynamic> farmer) {
    final loc = farmer['location']?.toString();
    if (loc != null && loc.trim().isNotEmpty) return loc.trim();
    final address = farmer['residential_address']?.toString();
    if (address != null && address.trim().isNotEmpty) return address.trim();
    return 'San Carlos City, Pangasinan';
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    return Scaffold(
      backgroundColor: _surface,
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _primary),
            );
          }

          final farmer = snapshot.data;
          if (farmer == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storefront_outlined, size: 64, color: _muted),
                  const SizedBox(height: 16),
                  Text(
                    'Farmer profile not found.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context.go(AppRoutes.marketplace),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Return to Marketplace'),
                  ),
                ],
              ),
            );
          }

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _reviewsFuture,
            builder: (context, reviewSnap) {
              final reviews = reviewSnap.data ?? [];
              final totalReviews = reviews.length;
              double sumRating = 0.0;
              for (final r in reviews) {
                sumRating += _safeDouble(r['rating'], 5.0);
              }
              final double avgRating =
                  totalReviews > 0 ? sumRating / totalReviews : 0.0;

              return Stack(
                children: [
                  SingleChildScrollView(
                    child: Column(
                      children: [
                        WebEcomHeader(
                          currentIndex: -1,
                          onNavigate: (index, [route]) {
                            if (route != null) {
                              context.go(route);
                            } else {
                              _handleNav(index);
                            }
                          },
                          onSearch: (query) {
                            context.go(AppRoutes.shop, extra: {'search': query});
                          },
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1320),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 16 : 32,
                                vertical: 12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFlagshipCoverBanner(farmer, isMobile),
                                  const SizedBox(height: 16),
                                  _buildMerchantFlagshipHeader(
                                    farmer,
                                    isMobile,
                                    avgRating,
                                    totalReviews,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildVouchersSection(farmer),
                                  const SizedBox(height: 28),
                                  _buildStoreNavigationTabs(
                                    farmer,
                                    isMobile,
                                    reviews,
                                    avgRating,
                                    totalReviews,
                                  ),
                                  const SizedBox(height: 48),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const AgriDirectWebFooter(),
                      ],
                    ),
                  ),

                  // Mobile sticky bottom CTA bar
                  if (isMobile)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildMobileBottomBar(farmer),
                    ),

                  // Floating Kiko AI Carabao Chatbot Widget on Web
                  if (!isMobile)
                    const WebKikoChatbotWidget(),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. FLAGSHIP STORE SHOWCASE BANNER
  // ---------------------------------------------------------------------------
  Widget _buildFlagshipCoverBanner(Map<String, dynamic> farmer, bool isMobile) {
    final rawAvatar = (farmer['image_url'] ??
            farmer['logo_url'] ??
            farmer['avatar_url'] ??
            farmer['profile_image_url'] ??
            farmer['profile_picture'])
        ?.toString();
    final avatarUrl = rawAvatar;

    final rawCover = (_customCoverUrl ??
            farmer['cover_url'] ??
            farmer['cover_image_url'] ??
            farmer['farm_banner_url'] ??
            farmer['banner_url'])
        ?.toString();

    String? coverImageUrl = (rawCover != null && rawCover.trim().isNotEmpty)
        ? rawCover.trim()
        : null;

    if (avatarUrl != null &&
        coverImageUrl != null &&
        (coverImageUrl == avatarUrl ||
            coverImageUrl.toLowerCase().contains('face_photo') ||
            coverImageUrl.toLowerCase().contains('avatar') ||
            coverImageUrl.toLowerCase().contains('profile_picture') ||
            coverImageUrl.toLowerCase().contains('selfie'))) {
      coverImageUrl = null;
    }

    final farmName = _farmName(farmer);
    final ownProfile = _isOwnProfile(farmer);
    final bannerHeight = isMobile ? 140.0 : 200.0;

    return Container(
      height: bannerHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: WebDesignTokens.cardRest,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (coverImageUrl != null)
              SafeNetworkImage(
                imageUrl: _customCoverUrl ?? coverImageUrl,
                defaultBucket: 'uploads',
                fit: BoxFit.cover,
                placeholder: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF064E3B), Color(0xFF047857)],
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.agriculture_rounded,
                      size: 44,
                      color: Colors.white24,
                    ),
                  ),
                ),
                errorWidget: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF064E3B), Color(0xFF047857)],
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.agriculture_rounded,
                      size: 44,
                      color: Colors.white24,
                    ),
                  ),
                ),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF064E3B),
                      Color(0xFF047857),
                      Color(0xFF10B981),
                    ],
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        color: Colors.white38,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'AgriDirect Official Farm Storefront',
                        style: GoogleFonts.rubik(
                          color: Colors.white70,
                          fontSize: isMobile ? 14 : 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Protective soft gradient overlay
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.45),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // Top action controls (Share + Banner Upload)
            Positioned(
              top: 14,
              right: 14,
              child: Row(
                children: [
                  if (ownProfile) ...[
                    _isUploadingCover
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 13,
                                  height: 13,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Uploading...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _pickAndUploadCoverPhoto,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.white,
                                      size: 15,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Change Banner',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                    const SizedBox(width: 8),
                  ],
                  _buildGlassIconButton(
                    icon: Icons.share_rounded,
                    tooltip: 'Share Store Link & QR Code',
                    onTap: () {
                      final shareUrl =
                          ShareUtil.generateFarmerShareLink(widget.farmerId);
                      ShareBottomSheet.show(
                        context: context,
                        shareUrl: shareUrl,
                        title: 'Share Store Profile',
                        subtitle:
                            'Scan QR code with your camera or copy the link below',
                        shareSubject:
                            'Check out $farmName on AgriDirect!',
                      );
                    },
                  ),
                ],
              ),
            ),

            // Bottom subtle watermark badge
            Positioned(
              bottom: 12,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.storefront_rounded,
                      color: Color(0xFF4ADE80),
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Direct Farm Producer Storefront',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. UNIFIED MERCHANT FLAGSHIP HEADER
  // ---------------------------------------------------------------------------
  Widget _buildMerchantFlagshipHeader(
    Map<String, dynamic> farmer,
    bool isMobile,
    double avgRating,
    int totalReviews,
  ) {
    final rawAvatar = (farmer['image_url'] ??
            farmer['logo_url'] ??
            farmer['avatar_url'] ??
            farmer['profile_image_url'] ??
            farmer['profile_picture'])
        ?.toString();
    final avatarUrl = rawAvatar;
    final farmName = _farmName(farmer);
    final specialty = _specialty(farmer);
    final locationText = _location(farmer);
    final isVerified = farmer['is_verified'] == true;
    final ownProfile = _isOwnProfile(farmer);

    final ratingLabel =
        totalReviews > 0 ? '${avgRating.toStringAsFixed(1)} ★' : 'New';
    final ratingSub =
        totalReviews > 0 ? '$totalReviews verified reviews' : 'Verified shop';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WebDesignTokens.border),
        boxShadow: WebDesignTokens.cardRest,
      ),
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mobile Identity Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStoreAvatar(avatarUrl, farmName, isVerified, 68),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            farmName,
                            style: GoogleFonts.rubik(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: WebDesignTokens.dark,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (isVerified) ...[
                            _buildVerifiedTag(),
                            const SizedBox(height: 6),
                          ],
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: WebDesignTokens.slate500,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  locationText,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: WebDesignTokens.slate600,
                                  ),
                                  maxLines: 1,
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
                const SizedBox(height: 14),
                // Specialty Tag
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: WebDesignTokens.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.eco_rounded,
                        size: 14,
                        color: WebDesignTokens.primary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          specialty,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: WebDesignTokens.primaryDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildChatButton(farmer, isFullWidth: true),
                    ),
                    if (!ownProfile) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildFollowButton(farmer, isFullWidth: true),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(color: WebDesignTokens.border, height: 1),
                const SizedBox(height: 16),
                // Performance Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildHeaderMetric(
                        title: 'Rating',
                        value: ratingLabel,
                        subtitle: ratingSub,
                        icon: Icons.star_rounded,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                    Expanded(
                      child: _buildHeaderMetric(
                        title: 'Followers',
                        value: '$_followerCount',
                        subtitle: 'Local consumers',
                        icon: Icons.people_alt_rounded,
                        color: const Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildHeaderMetric(
                        title: 'Response Rate',
                        value: '98%',
                        subtitle: 'Within ~1 hour',
                        icon: Icons.chat_bubble_outline_rounded,
                        color: WebDesignTokens.primary,
                      ),
                    ),
                    Expanded(
                      child: _buildHeaderMetric(
                        title: 'Sourcing',
                        value: '100% Farm',
                        subtitle: 'Direct producer',
                        icon: Icons.verified_user_rounded,
                        color: WebDesignTokens.primaryDark,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Identity & Actions
                Expanded(
                  flex: 6,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStoreAvatar(avatarUrl, farmName, isVerified, 88),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    farmName,
                                    style: GoogleFonts.rubik(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: WebDesignTokens.dark,
                                      height: 1.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isVerified) ...[
                                  const SizedBox(width: 10),
                                  _buildVerifiedTag(),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 15,
                                  color: WebDesignTokens.slate500,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    locationText,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: WebDesignTokens.slate600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: WebDesignTokens.slate400,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: WebDesignTokens.primaryLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.eco_rounded,
                                        size: 13,
                                        color: WebDesignTokens.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        specialty,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: WebDesignTokens.primaryDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                _buildChatButton(farmer),
                                if (!ownProfile) ...[
                                  const SizedBox(width: 12),
                                  _buildFollowButton(farmer),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Vertical Divider
                Container(
                  width: 1,
                  height: 110,
                  color: WebDesignTokens.border,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                ),

                // Right Column: Operational Metrics Matrix (2x2)
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildHeaderMetric(
                              title: 'Rating',
                              value: ratingLabel,
                              subtitle: ratingSub,
                              icon: Icons.star_rounded,
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                          Expanded(
                            child: _buildHeaderMetric(
                              title: 'Followers',
                              value: '$_followerCount',
                              subtitle: 'Store fans',
                              icon: Icons.people_alt_rounded,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildHeaderMetric(
                              title: 'Response Rate',
                              value: '98%',
                              subtitle: 'Within ~1 hour',
                              icon: Icons.chat_bubble_outline_rounded,
                              color: WebDesignTokens.primary,
                            ),
                          ),
                          Expanded(
                            child: _buildHeaderMetric(
                              title: 'Direct Sourcing',
                              value: '100% Farm',
                              subtitle: 'Producer to door',
                              icon: Icons.shield_rounded,
                              color: WebDesignTokens.primaryDark,
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

  Widget _buildStoreAvatar(
    String? avatarUrl,
    String farmName,
    bool isVerified,
    double size,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: WebDesignTokens.border, width: 2),
            boxShadow: WebDesignTokens.cardRest,
          ),
          child: ClipOval(
            child: SafeNetworkImage(
              imageUrl: avatarUrl,
              defaultBucket: 'avatars',
              fit: BoxFit.cover,
              placeholder: Container(
                color: _primary,
                child: Center(
                  child: Text(
                    farmName.isNotEmpty ? farmName[0].toUpperCase() : 'F',
                    style: GoogleFonts.rubik(
                      fontSize: size * 0.4,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              errorWidget: Container(
                color: _primary,
                child: Center(
                  child: Text(
                    farmName.isNotEmpty ? farmName[0].toUpperCase() : 'F',
                    style: GoogleFonts.rubik(
                      fontSize: size * 0.4,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (isVerified)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Color(0xFF16A34A),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVerifiedTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_user_rounded,
            color: Color(0xFF16A34A),
            size: 13,
          ),
          const SizedBox(width: 4),
          Text(
            'DA VERIFIED FARM',
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF15803D),
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatButton(
    Map<String, dynamic> farmer, {
    bool isFullWidth = false,
  }) {
    return ElevatedButton.icon(
      onPressed: () => _handleMessageFarmer(farmer),
      style: ElevatedButton.styleFrom(
        backgroundColor: WebDesignTokens.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(
          horizontal: isFullWidth ? 12 : 20,
          vertical: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
      label: Text(
        'Message Farmer',
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
        ),
      ),
    );
  }

  Widget _buildFollowButton(
    Map<String, dynamic> farmer, {
    bool isFullWidth = false,
  }) {
    return OutlinedButton.icon(
      onPressed: _isFollowBusy ? null : () => _toggleFollow(farmer),
      style: OutlinedButton.styleFrom(
        backgroundColor: _isFollowing
            ? WebDesignTokens.primaryLight
            : Colors.transparent,
        foregroundColor: _isFollowing
            ? WebDesignTokens.primaryDark
            : WebDesignTokens.dark,
        side: BorderSide(
          color: _isFollowing
              ? WebDesignTokens.primary
              : WebDesignTokens.border,
          width: 1.5,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isFullWidth ? 12 : 18,
          vertical: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      icon: _isFollowBusy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: WebDesignTokens.primary,
              ),
            )
          : Icon(
              _isFollowing ? Icons.check_circle_rounded : Icons.add_rounded,
              size: 17,
              color: _isFollowing ? WebDesignTokens.primary : WebDesignTokens.dark,
            ),
      label: Text(
        _isFollowing ? 'Following' : 'Follow Farm',
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
        ),
      ),
    );
  }

  Widget _buildHeaderMetric({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: GoogleFonts.rubik(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: WebDesignTokens.dark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: WebDesignTokens.slate500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  color: WebDesignTokens.slate400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: IconButton(
            onPressed: onTap,
            icon: Icon(icon, color: Colors.white, size: 18),
            tooltip: tooltip,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: const EdgeInsets.all(8),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. STORE VOUCHERS CAROUSEL
  // ---------------------------------------------------------------------------
  Widget _buildVouchersSection(Map<String, dynamic> farmer) {
    final currentUserId = AuthService().userId;
    if (currentUserId.isEmpty) return const SizedBox.shrink();
    final farmerId = farmer['user_id'] as String? ?? widget.farmerId;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: VoucherService().getFarmerVouchersForUser(
        farmerId: farmerId,
        userId: currentUserId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final vouchers = snapshot.data!;
        if (vouchers.isEmpty) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.confirmation_number_rounded,
                      color: _primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Exclusive Farm Vouchers',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Claim & Save',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: vouchers.map((v) {
                    final code = v['code']?.toString() ?? '';
                    final val = _safeDouble(v['discount_value'], 0.0);
                    final type = v['discount_type']?.toString() ?? '';
                    final minSpend = _safeDouble(v['min_spend'], 0.0);
                    bool isClaimed = v['is_claimed'] as bool? ?? false;

                    return StatefulBuilder(
                      builder: (ctx, setVoucherState) {
                        return Container(
                          margin: const EdgeInsets.only(right: 16),
                          width: 290,
                          height: 92,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _primary.withValues(alpha: 0.25),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 90,
                                decoration: BoxDecoration(
                                  color: _primary.withValues(alpha: 0.08),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(13),
                                    bottomLeft: Radius.circular(13),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      type == 'flat'
                                          ? '₱${val.toStringAsFixed(0)}'
                                          : '${val.toStringAsFixed(0)}%',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 20,
                                        color: _primary,
                                      ),
                                    ),
                                    Text(
                                      'DISCOUNT',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 10,
                                        color: _primary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              CustomPaint(
                                size: const Size(6, 92),
                                painter: TicketDottedLinePainter(
                                  color: _primary.withValues(alpha: 0.25),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        code,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: _dark,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Min. Spend ₱${minSpend.toStringAsFixed(0)}',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: _muted,
                                        ),
                                      ),
                                      const Spacer(),
                                      Align(
                                        alignment: Alignment.bottomRight,
                                        child: isClaimed
                                            ? Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFF1F5F9),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.check_rounded,
                                                      size: 12,
                                                      color: _emerald,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Claimed',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: _muted,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : ElevatedButton(
                                                onPressed: () async {
                                                  if (!AuthService().isLoggedIn) {
                                                    _showLoginRequiredDialog(
                                                      'claim discount vouchers',
                                                    );
                                                    return;
                                                  }
                                                  final ok =
                                                      await VoucherService()
                                                          .claimVoucher(
                                                            currentUserId,
                                                            v['voucher_id'],
                                                          );
                                                  if (ok) {
                                                    setVoucherState(() {
                                                      isClaimed = true;
                                                    });
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: _primary,
                                                  foregroundColor: Colors.white,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                  ),
                                                  minimumSize:
                                                      const Size(64, 28),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                  ),
                                                  elevation: 0,
                                                ),
                                                child: Text(
                                                  'Claim',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11.5,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                  ),
                                                ),
                                              ),
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
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 4. MULTI-TAB MARKETPLACE HUB
  // ---------------------------------------------------------------------------
  Widget _buildStoreNavigationTabs(
    Map<String, dynamic> farmer,
    bool isMobile,
    List<Map<String, dynamic>> reviews,
    double avgRating,
    int totalReviews,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(bottom: BorderSide(color: _border)),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.transparent,
            indicatorColor: _primary,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: _primary,
            unselectedLabelColor: _muted,
            labelStyle: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
            unselectedLabelStyle: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            tabs: [
              const Tab(
                child: Row(
                  children: [
                    Icon(Icons.storefront_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Store Home'),
                  ],
                ),
              ),
              const Tab(
                child: Row(
                  children: [
                    Icon(Icons.grid_view_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('All Products'),
                  ],
                ),
              ),
              const Tab(
                child: Row(
                  children: [
                    Icon(Icons.dynamic_feed_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Farm Story'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  children: [
                    const Icon(Icons.reviews_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      totalReviews > 0
                          ? 'Reviews ($totalReviews)'
                          : 'Reviews',
                    ),
                  ],
                ),
              ),
              const Tab(
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('About Farm'),
                  ],
                ),
              ),
            ],
          ),
        ),

        AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            switch (_tabController.index) {
              case 0:
                return _buildStoreHomeTabView(
                  farmer,
                  isMobile,
                  avgRating,
                  totalReviews,
                );
              case 1:
                return _buildProductsTabView(isMobile);
              case 2:
                return _WebFarmerPostsTab(
                  farmerUserId: farmer['user_id']?.toString() ?? '',
                );
              case 3:
                return _buildReviewsTabView(reviews, avgRating, totalReviews);
              case 4:
                return _buildAboutTabView(farmer, isMobile);
              default:
                return _buildStoreHomeTabView(
                  farmer,
                  isMobile,
                  avgRating,
                  totalReviews,
                );
            }
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 5. STORE HOME TAB VIEW (Featured Highlights & Trust Proof)
  // ---------------------------------------------------------------------------
  Widget _buildStoreHomeTabView(
    Map<String, dynamic> farmer,
    bool isMobile,
    double avgRating,
    int totalReviews,
  ) {
    return FutureBuilder<List<ProductItem>>(
      future: SupabaseDataService().getProductsByFarmerId(widget.farmerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.white,
            padding: const EdgeInsets.all(60),
            child: const Center(
              child: CircularProgressIndicator(color: _primary),
            ),
          );
        }

        final products = snapshot.data ?? [];

        return Container(
          color: Colors.white,
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Featured Today's Fresh Harvest Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: WebDesignTokens.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.local_florist_rounded,
                                color: WebDesignTokens.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                "Today's Fresh Harvest",
                                style: GoogleFonts.rubik(
                                  fontSize: isMobile ? 18 : 22,
                                  fontWeight: FontWeight.w700,
                                  color: WebDesignTokens.dark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Directly harvested from the fields of ${_farmName(farmer)}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: WebDesignTokens.slate500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (products.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _tabController.animateTo(1),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: Text(
                        'View All (${products.length})',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: WebDesignTokens.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),

              if (products.isEmpty)
                _buildEmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'No produce harvested yet',
                  subtitle:
                      'Check back soon for freshly listed farm crops and produce.',
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth >= 1100
                        ? 3
                        : constraints.maxWidth >= 700
                            ? 2
                            : 1;

                    final showcaseCount =
                        products.length > 6 ? 6 : products.length;
                    final featuredList = products.sublist(0, showcaseCount);

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 24,
                        mainAxisExtent: 355,
                      ),
                      itemCount: featuredList.length,
                      itemBuilder: (context, index) => _buildProductCard(
                        context,
                        featuredList[index],
                        index,
                      ),
                    );
                  },
                ),

              const SizedBox(height: 36),
              const Divider(color: WebDesignTokens.border),
              const SizedBox(height: 32),

              // 2. Direct Sourcing Value Proposition Ribbons
              Text(
                'Why Order Direct from ${_farmName(farmer)}?',
                style: GoogleFonts.rubik(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: WebDesignTokens.dark,
                ),
              ),
              const SizedBox(height: 16),
              isMobile
                  ? Column(
                      children: [
                        _buildTrustFeatureCard(
                          icon: Icons.electric_bolt_rounded,
                          title: 'Same-Day Field Harvest',
                          description:
                              'Produce is harvested upon order to ensure maximum peak freshness and nutritional density.',
                          color: const Color(0xFFF59E0B),
                        ),
                        const SizedBox(height: 12),
                        _buildTrustFeatureCard(
                          icon: Icons.handshake_rounded,
                          title: '100% Direct Farmer Support',
                          description:
                              'Your purchase directly supports this local grower and community agriculture without middleman markups.',
                          color: WebDesignTokens.primary,
                        ),
                        const SizedBox(height: 12),
                        _buildTrustFeatureCard(
                          icon: Icons.verified_user_rounded,
                          title: 'DA Monitored & Verified',
                          description:
                              'Registered agricultural producer compliant with local safe farming and food guidelines.',
                          color: const Color(0xFF2563EB),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _buildTrustFeatureCard(
                            icon: Icons.electric_bolt_rounded,
                            title: 'Same-Day Field Harvest',
                            description:
                                'Produce is harvested upon order to ensure maximum peak freshness and nutritional density.',
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTrustFeatureCard(
                            icon: Icons.handshake_rounded,
                            title: '100% Direct Farmer Support',
                            description:
                                'Your purchase directly supports this local grower and community agriculture without middleman markups.',
                            color: WebDesignTokens.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTrustFeatureCard(
                            icon: Icons.verified_user_rounded,
                            title: 'DA Monitored & Verified',
                            description:
                                'Registered agricultural producer compliant with local safe farming and food guidelines.',
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 32),

              // 3. Farm Story Teaser Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: WebDesignTokens.bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: WebDesignTokens.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: WebDesignTokens.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.agriculture_rounded,
                        color: WebDesignTokens.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Know Your Producer',
                            style: GoogleFonts.rubik(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: WebDesignTokens.dark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Learn how ${_farmName(farmer)} cultivates sustainable produce in ${_location(farmer)}.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: WebDesignTokens.slate600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton(
                      onPressed: () => _tabController.animateTo(4),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: WebDesignTokens.primary,
                        side: const BorderSide(color: WebDesignTokens.primary),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'About Farm',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrustFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: WebDesignTokens.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WebDesignTokens.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.rubik(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: WebDesignTokens.dark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: WebDesignTokens.slate600,
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

  // ---------------------------------------------------------------------------
  // 5. PRODUCTS TAB (With Search, Categories & Sorting)
  // ---------------------------------------------------------------------------
  Widget _buildProductsTabView(bool isMobile) {
    return FutureBuilder<List<ProductItem>>(
      future: SupabaseDataService().getProductsByFarmerId(widget.farmerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.white,
            padding: const EdgeInsets.all(60),
            child: const Center(
              child: CircularProgressIndicator(color: _primary),
            ),
          );
        }

        final rawProducts = snapshot.data ?? [];
        if (rawProducts.isEmpty) {
          return Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
            child: _buildEmptyState(
              icon: Icons.storefront_outlined,
              title: 'No products listed yet',
              subtitle: 'This farmer has not published active product listings yet.',
            ),
          );
        }

        var filtered = rawProducts.where((p) {
          final matchesSearch = _searchQuery.isEmpty ||
              p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (p.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                  false);
          final matchesCategory = _selectedCategory == 'All' ||
              (p.categoryName?.toLowerCase() ==
                  _selectedCategory.toLowerCase());
          return matchesSearch && matchesCategory;
        }).toList();

        if (_selectedSort == 'Price: Low to High') {
          filtered.sort((a, b) {
            final pa = double.tryParse(a.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
            final pb = double.tryParse(b.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
            return pa.compareTo(pb);
          });
        } else if (_selectedSort == 'Price: High to Low') {
          filtered.sort((a, b) {
            final pa = double.tryParse(a.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
            final pb = double.tryParse(b.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
            return pb.compareTo(pa);
          });
        }

        final categories = [
          'All',
          ...rawProducts
              .map((p) => p.categoryName)
              .where((c) => c != null && c.isNotEmpty)
              .cast<String>()
              .toSet(),
        ];

        return Container(
          color: Colors.white,
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProductFilterToolbar(categories, isMobile),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${filtered.length} of ${rawProducts.length} items',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (filtered.isEmpty)
                _buildEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No matching products found',
                  subtitle:
                      'Try adjusting your search query or selected category filter.',
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth >= 1100
                        ? 3
                        : constraints.maxWidth >= 700
                            ? 2
                            : 1;

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 24,
                        mainAxisExtent: 355,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) => _buildProductCard(
                        context,
                        filtered[index],
                        index,
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductFilterToolbar(List<String> categories, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  style: GoogleFonts.inter(fontSize: 13.5, color: _dark),
                  decoration: InputDecoration(
                    hintText: 'Search within this farm...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey.shade400,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: _muted,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSort,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _muted),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _dark,
                  ),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedSort = val);
                  },
                  items: const [
                    DropdownMenuItem(value: 'Featured', child: Text('Featured')),
                    DropdownMenuItem(
                      value: 'Price: Low to High',
                      child: Text('Price: Low to High'),
                    ),
                    DropdownMenuItem(
                      value: 'Price: High to Low',
                      child: Text('Price: High to Low'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (s) => setState(() => _selectedCategory = cat),
                  selectedColor: _primary,
                  backgroundColor: _surface,
                  labelStyle: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : _muted,
                  ),
                  side: BorderSide(
                    color: isSelected ? _primary : _border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  showCheckmark: false,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 6. PRODUCT CARD DESIGN
  // ---------------------------------------------------------------------------
  Widget _buildProductCard(
    BuildContext context,
    ProductItem product,
    int index,
  ) {
    final stockQty = product.targetQuantity?.toInt() ?? 50;
    final isLowStock = stockQty < 15;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          final prodId = product.productId ?? 'view';
          context.go(AppRoutes.product(prodId), extra: product);
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(19),
                    ),
                    child: SizedBox(
                      height: 170,
                      width: double.infinity,
                      child: product.imageUrl.isNotEmpty
                          ? Image.network(
                              product.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _buildImageFallback(),
                            )
                          : _buildImageFallback(),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _buildTag(product, index),
                  ),
                ],
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _dark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            product.price,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: _primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      Text(
                        product.description ??
                            'Fresh, nutrient-rich produce harvest directly from our fields.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _muted,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isLowStock
                                  ? const Color(0xFFFEF2F2)
                                  : const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isLowStock
                                        ? const Color(0xFFEF4444)
                                        : _emerald,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isLowStock
                                      ? 'Low Stock: $stockQty ${product.unit.isNotEmpty ? product.unit : "units"}'
                                      : 'In Stock: $stockQty ${product.unit.isNotEmpty ? product.unit : "units"}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isLowStock
                                        ? const Color(0xFFDC2626)
                                        : _emerald,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await CartService().addItem(product);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: _primary,
                                    content: Text(
                                      '${product.name} added to cart!',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(
                                Icons.add_shopping_cart_rounded,
                                size: 16,
                              ),
                              label: Text(
                                'Add to Cart',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
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
        ),
      ),
    );
  }

  Widget _buildTag(ProductItem product, int index) {
    String text = 'Fresh Harvest';
    Color bgColor = const Color(0xFF047857);

    final cat = product.categoryName?.toLowerCase() ?? '';
    if (product.isFeatured) {
      text = "Farmer's Choice";
      bgColor = const Color(0xFFB45309);
    } else if (cat.contains('meat') ||
        cat.contains('livestock') ||
        index % 3 == 0) {
      text = 'Fresh Today';
      bgColor = const Color(0xFFEA580C);
    } else {
      text = 'Organic';
      bgColor = const Color(0xFF16A34A);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildImageFallback() {
    return Container(
      height: 190,
      color: _surface,
      child: const Center(
        child: Icon(Icons.agriculture_rounded, color: _muted, size: 36),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 7. RATINGS & REVIEWS TAB VIEW (100% Dynamic from database)
  // ---------------------------------------------------------------------------
  Widget _buildReviewsTabView(
    List<Map<String, dynamic>> reviews,
    double avgRating,
    int totalReviews,
  ) {
    if (reviews.isEmpty) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.rate_review_outlined, size: 54, color: _muted),
              const SizedBox(height: 16),
              Text(
                'No customer reviews yet',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Reviews and verified buyer testimonials will appear here once orders are fulfilled.',
                style: GoogleFonts.inter(fontSize: 13.5, color: _muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    int getRatingInt(Map<String, dynamic> r) {
      final raw = r['rating'];
      if (raw is num) return raw.round();
      return int.tryParse(raw?.toString() ?? '') ??
          (double.tryParse(raw?.toString() ?? '')?.round() ?? 5);
    }

    final count5 = reviews.where((r) => getRatingInt(r) == 5).length;
    final count4 = reviews.where((r) => getRatingInt(r) == 4).length;
    final count3 = reviews.where((r) => getRatingInt(r) == 3).length;
    final count2 = reviews.where((r) => getRatingInt(r) == 2).length;
    final count1 = reviews.where((r) => getRatingInt(r) == 1).length;

    final double ratio5 = totalReviews > 0 ? count5 / totalReviews : 0.0;
    final double ratio4 = totalReviews > 0 ? count4 / totalReviews : 0.0;
    final double ratio3 = totalReviews > 0 ? count3 / totalReviews : 0.0;
    final double ratio2 = totalReviews > 0 ? count2 / totalReviews : 0.0;
    final double ratio1 = totalReviews > 0 ? count1 / totalReviews : 0.0;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      avgRating.toStringAsFixed(1),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: _primary,
                      ),
                    ),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < avgRating.round()
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: const Color(0xFFF59E0B),
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Based on $totalReviews ${totalReviews == 1 ? "review" : "reviews"}',
                      style: GoogleFonts.inter(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    children: [
                      _buildRatingBar('5 Stars', ratio5),
                      _buildRatingBar('4 Stars', ratio4),
                      _buildRatingBar('3 Stars', ratio3),
                      _buildRatingBar('2 Stars', ratio2),
                      _buildRatingBar('1 Star', ratio1),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          Text(
            'Verified Customer Reviews',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          const SizedBox(height: 16),

          for (var i = 0; i < reviews.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _buildDynamicReviewCard(reviews[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingBar(String label, double ratio) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, color: _muted),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFF59E0B),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicReviewCard(Map<String, dynamic> r) {
    final customerName = r['resolved_customer_name']?.toString() ??
        r['customers']?['users']?['name']?.toString() ??
        'Verified Buyer';
    final customerAvatar = r['resolved_customer_avatar']?.toString() ??
        r['customers']?['users']?['avatar_url']?.toString();
    final rawText = r['review_text']?.toString() ?? '';
    final rating = _safeDouble(r['rating'], 5.0);
    final createdAt = r['created_at']?.toString();
    final productName = r['product_name']?.toString();
    final responseText = r['response_text']?.toString();
    final List<dynamic> rawImages = r['images'] as List<dynamic>? ?? [];
    final List<String> images = rawImages
        .map((img) => img.toString())
        .where((img) => img.trim().isNotEmpty)
        .toList();

    String formattedDate = 'Recent purchase';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt);
        formattedDate = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: Container(
                  width: 36,
                  height: 36,
                  color: _primary.withValues(alpha: 0.1),
                  child: (customerAvatar != null && customerAvatar.trim().isNotEmpty)
                      ? SafeNetworkImage(
                          imageUrl: customerAvatar,
                          defaultBucket: 'avatars',
                          fit: BoxFit.cover,
                          placeholder: Center(
                            child: Text(
                              customerName.isNotEmpty
                                  ? customerName[0].toUpperCase()
                                  : 'C',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                color: _primary,
                              ),
                            ),
                          ),
                          errorWidget: Center(
                            child: Text(
                              customerName.isNotEmpty
                                  ? customerName[0].toUpperCase()
                                  : 'C',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                color: _primary,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            customerName.isNotEmpty
                                ? customerName[0].toUpperCase()
                                : 'C',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: _primary,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          customerName,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: _dark,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Verified Buyer',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _emerald,
                            ),
                          ),
                        ),
                        if (productName != null && productName.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              productName,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _muted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      formattedDate,
                      style: GoogleFonts.inter(fontSize: 11, color: _muted),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < rating.round()
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          if (rawText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              rawText,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF334155),
                height: 1.5,
              ),
            ),
          ],
          if (images.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: images.map((img) {
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => Dialog(
                          backgroundColor: Colors.transparent,
                          insetPadding: const EdgeInsets.all(20),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: SafeNetworkImage(
                                  imageUrl: img,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: CircleAvatar(
                                  backgroundColor: Colors.black54,
                                  child: IconButton(
                                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                                    onPressed: () => Navigator.pop(ctx),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: SafeNetworkImage(
                          imageUrl: img,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (responseText != null && responseText.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.reply_rounded, size: 14, color: _primary),
                      const SizedBox(width: 6),
                      Text(
                        'Farmer Response:',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    responseText,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 8. ABOUT FARM & CERTIFICATIONS TAB VIEW (100% Dynamic)
  // ---------------------------------------------------------------------------
  Widget _buildAboutTabView(Map<String, dynamic> farmer, bool isMobile) {
    final bio = farmer['farming_history']?.toString() ??
        farmer['bio']?.toString() ??
        farmer['description']?.toString() ??
        'Dedicated local agrarian producer committed to delivering farm-to-table freshness directly to the community.';
    final locationText = _location(farmer);
    final yearsExp = farmer['years_of_experience'];
    final int? yearsInt = yearsExp is num ? yearsExp.toInt() : int.tryParse(yearsExp?.toString() ?? '');
    final isVerified = farmer['is_verified'] == true;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(isMobile ? 20 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About Our Farm',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            bio,
            style: GoogleFonts.inter(
              fontSize: 14.5,
              color: const Color(0xFF334155),
              height: 1.7,
            ),
          ),
          const SizedBox(height: 32),

          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              if (isVerified)
                _buildAboutBadge(
                  icon: Icons.verified_rounded,
                  title: 'Department of Agriculture Verified',
                  subtitle: 'Registered agrarian producer and verified supplier',
                ),
              if (yearsInt != null && yearsInt > 0)
                _buildAboutBadge(
                  icon: Icons.history_edu_rounded,
                  title: '$yearsInt Years Farming Experience',
                  subtitle: 'Experienced in sustainable crop cultivation',
                ),
              _buildAboutBadge(
                icon: Icons.local_shipping_rounded,
                title: 'Direct Community Delivery',
                subtitle: 'Harvested on demand to ensure maximum freshness',
              ),
              _buildAboutBadge(
                icon: Icons.pin_drop_rounded,
                title: 'Farm Location',
                subtitle: locationText,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAboutBadge({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: 380,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _muted,
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

  // ---------------------------------------------------------------------------
  // 9. MOBILE BOTTOM STICKY BAR
  // ---------------------------------------------------------------------------
  Widget _buildMobileBottomBar(Map<String, dynamic> farmer) {
    final ownProfile = _isOwnProfile(farmer);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        border: const Border(top: BorderSide(color: _border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _handleMessageFarmer(farmer),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: Text(
                  'Message Farmer',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),

            if (!ownProfile) ...[
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _isFollowBusy ? null : () => _toggleFollow(farmer),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _isFollowing ? _dark : _primary,
                  side: BorderSide(
                    color: _isFollowing ? _border : _primary,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _isFollowing ? 'Following' : 'Follow',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: GoogleFonts.inter(fontSize: 13, color: _muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// POSTS TAB COMPONENT (100% Dynamic from Supabase)
// -----------------------------------------------------------------------------
class _WebFarmerPostsTab extends StatelessWidget {
  final String farmerUserId;

  const _WebFarmerPostsTab({required this.farmerUserId});

  static const Color _primary = Color(0xFF005A36);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    if (farmerUserId.isEmpty) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.forum_outlined, size: 48, color: _muted),
              const SizedBox(height: 16),
              Text(
                'No farm updates yet',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'This farmer has not published harvest logs or community stories yet.',
                style: GoogleFonts.inter(fontSize: 13, color: _muted),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<List<ForumPostItem>>(
      future: SupabaseDataService().getForumPostsByUserId(farmerUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.white,
            padding: const EdgeInsets.all(60),
            child: const Center(
              child: CircularProgressIndicator(color: _primary),
            ),
          );
        }

        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.forum_outlined, size: 48, color: _muted),
                  const SizedBox(height: 16),
                  Text(
                    'No farm updates yet',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This farmer has not published harvest logs or community stories yet.',
                    style: GoogleFonts.inter(fontSize: 13, color: _muted),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              for (var index = 0; index < posts.length; index++) ...[
                if (index > 0) const SizedBox(height: 20),
                _buildPostCard(posts[index]),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPostCard(ForumPostItem post) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: _primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.userName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                      ),
                    ),
                    Text(
                      post.time,
                      style: GoogleFonts.inter(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (post.title.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              post.title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            post.body,
            style: GoogleFonts.inter(fontSize: 14, color: _dark, height: 1.6),
          ),
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                post.imageUrl!,
                height: 260,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.thumb_up_alt_outlined, size: 16, color: _muted),
              const SizedBox(width: 6),
              Text(
                '${post.likes} Likes',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
              const SizedBox(width: 24),
              const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 16,
                color: _muted,
              ),
              const SizedBox(width: 6),
              Text(
                '${post.comments} Comments',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TICKET DOTTED LINE PAINTER
// -----------------------------------------------------------------------------
class TicketDottedLinePainter extends CustomPainter {
  final Color color;
  TicketDottedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    double startY = 6;
    while (startY < size.height - 6) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, startY + 4),
        paint,
      );
      startY += 8;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
