import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/services/commerce/cart_service.dart';
import 'package:geolocator/geolocator.dart';
import 'product_view_screen.dart';
import 'cart_screen.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/social/follow_service.dart';
import '../../../shared/widgets/image_widgets.dart';
import '../../../shared/widgets/share_bottom_sheet.dart';
import '../../../shared/utils/share_util.dart';
import '../../../shared/widgets/flying_icon_animation.dart';

/// Full-screen public profile for a farmer, with Products & Posts tabs.
class FarmerPublicProfileScreen extends StatefulWidget {
  final Map<String, dynamic> farmer;

  const FarmerPublicProfileScreen({super.key, required this.farmer});

  @override
  State<FarmerPublicProfileScreen> createState() =>
      _FarmerPublicProfileScreenState();
}

class _FarmerPublicProfileScreenState extends State<FarmerPublicProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final GlobalKey _cartKey = GlobalKey();
  final List<OverlayEntry> _flyingOverlayEntries = [];
  String _calculatedDistance = 'Nearby';
  final FollowService _followService = FollowService();
  bool _isFollowing = false;
  bool _isFollowBusy = false;
  int _followerCount = 0;
  int _followingCount = 0;
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

      final userId = AuthService().userId;
      if (userId.isNotEmpty) {
        await SupabaseConfig.client
            .from('farmers')
            .update({
              'image_url': publicUrl,
            })
            .eq('user_id', userId);
      }

      if (!mounted) return;

      setState(() {
        _customCoverUrl = publicUrl;
        _isUploadingCover = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Farm cover photo updated successfully!'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      debugPrint('Error uploading cover photo: $e');
      if (!mounted) return;
      setState(() => _isUploadingCover = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload cover photo: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Map<String, dynamic> get f => widget.farmer;
  bool get _isOwnProfile =>
      AuthService().userId.isNotEmpty &&
      AuthService().userId == (f['farmerUserId']?.toString() ?? '');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _calculateDistance();
    _loadFollowState();
  }

  Future<void> _loadFollowState() async {
    final farmerId = f['farmerId']?.toString() ?? '';
    if (farmerId.isEmpty || _isOwnProfile) return;

    try {
      final state = await _followService.getFollowState(farmerId);
      if (!mounted) return;
      setState(() {
        _isFollowing = state['isFollowing'] as bool? ?? false;
        _followerCount = state['followers'] as int? ?? 0;
        _followingCount = state['following'] as int? ?? 0;
      });
    } catch (e) {
      debugPrint('Error loading follow state: $e');
    }
  }

  Future<void> _toggleFollow() async {
    if (_isFollowBusy || _isOwnProfile) return;

    final farmerId = f['farmerId']?.toString() ?? '';
    if (farmerId.isEmpty) return;

    setState(() => _isFollowBusy = true);
    try {
      final isNowFollowing = await _followService.toggleFollowFarmer(
        farmerId: farmerId,
        farmerUserId: f['farmerUserId']?.toString(),
        farmName: f['name']?.toString(),
      );
      if (!mounted) return;

      setState(() {
        _isFollowing = isNowFollowing;
        _followerCount += isNowFollowing ? 1 : -1;
        if (_followerCount < 0) _followerCount = 0;
        _followingCount += isNowFollowing ? 1 : -1;
        if (_followingCount < 0) _followingCount = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNowFollowing
                ? 'You are now following ${f['name'] ?? 'this farm'}.'
                : 'Unfollowed ${f['name'] ?? 'this farm'}.',
          ),
          backgroundColor:
              isNowFollowing ? AppColors.success : AppColors.textHeadline,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isFollowBusy = false);
      }
    }
  }

  Future<void> _calculateDistance() async {
    try {
      final double? farmLat = f['latitude'] as double?;
      final double? farmLon = f['longitude'] as double?;

      if (farmLat == null || farmLon == null) return;

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      
      if (permission == LocationPermission.deniedForever) return;

      final Position position = await Geolocator.getCurrentPosition();
      
      final double distanceInMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        farmLat,
        farmLon,
      );

      if (mounted) {
        setState(() {
          if (distanceInMeters < 1000) {
            _calculatedDistance = '${distanceInMeters.toStringAsFixed(0)}m';
          } else {
            _calculatedDistance = '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
          }
        });
      }
    } catch (e) {
      debugPrint('Error calculating distance: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final entry in _flyingOverlayEntries) {
      if (entry.mounted) {
        entry.remove();
      }
    }
    _flyingOverlayEntries.clear();
    _tabController.dispose();
    super.dispose();
  }

  Widget _imagePlaceholder() {
    return Container(
      color: AppColors.primaryLight,
      child: const Center(
        child: Icon(
          Icons.agriculture_rounded,
          size: 48,
          color: AppColors.primary,
        ),
      ),
    );
  }


  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'F';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length > 1 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }



  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 56, color: AppColors.textSubtle.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(title,
                style: AppTextStyles.headline3
                    .copyWith(color: AppColors.textHeadline)),
            const SizedBox(height: 8),
            Text(subtitle,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSubtle),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(context, innerBoxIsScrolled),
          _buildTabBarHeader(context),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _ProductsTab(
              farmerId: f['farmerId']?.toString() ?? '',
              searchQuery: _searchQuery,
            ),
            _PostsTab(farmerUserId: f['farmerUserId']?.toString() ?? ''),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(BuildContext context, bool innerBoxIsScrolled) {
    final imageUrl = f['imageUrl']?.toString();
    final avatarUrl = (f['avatar_url'] ?? f['avatarUrl'] ?? f['face_photo_path'])?.toString();

    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      stretch: true,
      backgroundColor: const Color(0xFF0F172A),
      elevation: 0,
      leading: IconButton(
        onPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            GoRouter.of(context).go(AppRoutes.home);
          }
        },
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
      ),
      title: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 16, color: Colors.white70),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                },
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: InputBorder.none,
                  hintText: 'Search in shop...',
                  hintStyle: GoogleFonts.inter(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                child: const Icon(Icons.close_rounded, size: 16, color: Colors.white70),
              ),
          ],
        ),
      ),
      actions: [
        ListenableBuilder(
          listenable: CartService(),
          builder: (context, _) {
            final count = CartService().itemCount;
            return IconButton(
              key: _cartKey,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CartScreen()),
              ),
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_cart_outlined, size: 20, color: Colors.white),
                  if (count > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        if (_isOwnProfile)
          IconButton(
            onPressed: _pickAndUploadCoverPhoto,
            icon: _isUploadingCover
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.camera_alt_outlined, size: 20, color: Colors.white),
            tooltip: 'Change Cover Photo',
          ),
        IconButton(
          onPressed: () {
            final farmerId = f['farmerId']?.toString();
            if (farmerId == null || farmerId.isEmpty) return;
            final shareUrl = ShareUtil.generateFarmerShareLink(farmerId);
            final farmerName = f['name'] ?? f['farm_name'] ?? 'Farm';

            ShareBottomSheet.show(
              context: context,
              shareUrl: shareUrl,
              title: 'Share Farm Store',
              subtitle: 'Let others scan this QR code or share the link to $farmerName.',
              shareSubject: 'Check out $farmerName on AgriDirect!',
            );
          },
          icon: const Icon(Icons.share_outlined, size: 20, color: Colors.white),
          tooltip: 'Share Farm',
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'farmer_${f['farmerId']}',
              child: SafeNetworkImage(
                imageUrl: _customCoverUrl ?? imageUrl,
                defaultBucket: 'uploads',
                fit: BoxFit.cover,
                placeholder: _imagePlaceholder(),
                errorWidget: _imagePlaceholder(),
              ),
            ),
            // Dark Gradient Scrim (Shopee style)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.65),
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
            // Integrated Farm Identity & Action Row (Positioned at bottom of header)
            Positioned(
              left: 14,
              right: 14,
              bottom: 10,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Circular Farm Logo
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: avatarUrl != null && avatarUrl.isNotEmpty
                          ? SafeNetworkImage(
                              imageUrl: avatarUrl,
                              defaultBucket: 'uploads',
                              fit: BoxFit.cover,
                              errorWidget: _buildLogoFallback(),
                            )
                          : _buildLogoFallback(),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Store Title & Meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _titleCase(f['name'] ?? 'Farm'),
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (f['badge'] == 'VERIFIED' || f['is_verified'] == true) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified_rounded,
                                color: Color(0xFF10B981),
                                size: 16,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFBBF24)),
                            const SizedBox(width: 2),
                            Text(
                              f['rating']?.toString() ?? '5.0',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                ' | $_followerCount Followers${_calculatedDistance.isNotEmpty ? ' | $_calculatedDistance' : ''}',
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 10.5,
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

                  // Compact Action Buttons (Shopee Style)
                  if (!_isOwnProfile) ...[
                    const SizedBox(width: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 28,
                          child: OutlinedButton(
                            onPressed: _isFollowBusy ? null : _toggleFollow,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _isFollowing ? Colors.white.withValues(alpha: 0.15) : Colors.white,
                              foregroundColor: _isFollowing ? Colors.white : const Color(0xFF0F172A),
                              side: BorderSide(
                                color: _isFollowing ? Colors.white.withValues(alpha: 0.4) : Colors.white,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 7),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isFollowBusy
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _isFollowing ? Icons.check_rounded : Icons.add_rounded,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        _isFollowing ? 'Following' : 'Follow',
                                        style: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        SizedBox(
                          height: 28,
                          child: OutlinedButton(
                            onPressed: () {
                              final farmerId = f['farmerId']?.toString();
                              if (farmerId != null) {
                                context.push(AppRoutes.customerMessages, extra: {'farmerId': farmerId});
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.black.withValues(alpha: 0.3),
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                              padding: const EdgeInsets.symmetric(horizontal: 7),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.chat_bubble_outline_rounded, size: 12),
                                const SizedBox(width: 3),
                                Text(
                                  'Chat',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          _getInitials(f['name'] ?? 'Farm'),
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  void _runFlyToCartAnimation(GlobalKey startKey, String imageUrl) {
    final startCtx = startKey.currentContext;
    final cartCtx = _cartKey.currentContext;
    if (startCtx == null || cartCtx == null) return;

    final RenderBox? buttonBox = startCtx.findRenderObject() as RenderBox?;
    final RenderBox? cartBox = cartCtx.findRenderObject() as RenderBox?;

    if (buttonBox == null || cartBox == null) return;
    if (!buttonBox.attached || !cartBox.attached) return;
    if (!buttonBox.hasSize || !cartBox.hasSize) return;

    final startPosition = buttonBox.localToGlobal(Offset.zero);
    final endPosition = cartBox.localToGlobal(Offset.zero);

    if (!startPosition.dx.isFinite ||
        !startPosition.dy.isFinite ||
        !endPosition.dx.isFinite ||
        !endPosition.dy.isFinite) {
      return;
    }

    final screenSize = MediaQuery.of(context).size;
    if (startPosition.dx < 0 ||
        startPosition.dx > screenSize.width ||
        startPosition.dy < 0 ||
        startPosition.dy > screenSize.height) {
      return;
    }
    if (endPosition.dx < 0 ||
        endPosition.dx > screenSize.width ||
        endPosition.dy < 0 ||
        endPosition.dy > screenSize.height) {
      return;
    }

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => FlyingIconAnimation(
        startPosition: startPosition,
        endPosition: endPosition,
        imageUrl: imageUrl,
        onComplete: () {
          _flyingOverlayEntries.remove(overlayEntry);
          if (overlayEntry.mounted) {
            overlayEntry.remove();
          }
        },
      ),
    );

    _flyingOverlayEntries.add(overlayEntry);
    final overlay = Overlay.maybeOf(context);
    if (overlay != null) {
      overlay.insert(overlayEntry);
    }
  }

  Widget _buildTabBarHeader(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverTabBarDelegate(
        child: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF059669),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF059669),
              indicatorWeight: 2.5,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
              unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Products'),
                Tab(text: 'Posts & Updates'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final PreferredSize child;

  _SliverTabBarDelegate({required this.child});

  @override
  double get minExtent => child.preferredSize.height;

  @override
  double get maxExtent => child.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

String _titleCase(String text) {
  if (text.isEmpty) return text;
  return text.split(' ').map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

// ─── Products Tab with Shopee Sub-Filter & E-Commerce Grid ───
class _ProductsTab extends StatefulWidget {
  final String farmerId;
  final String searchQuery;
  const _ProductsTab({required this.farmerId, this.searchQuery = ''});

  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab> {
  int _activeSortIndex = 0;
  bool _priceAscending = true;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductItem>>(
      future: SupabaseDataService().getProductsByFarmerId(widget.farmerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final rawProducts = snapshot.data ?? [];
        if (rawProducts.isEmpty) {
          return (context.findAncestorStateOfType<_FarmerPublicProfileScreenState>()!)
              ._emptyState(
            Icons.storefront_rounded,
            'No Products Yet',
            'This farmer hasn\'t listed any products.',
          );
        }

        // Apply real-time search filtering
        final filtered = rawProducts.where((p) {
          if (widget.searchQuery.isEmpty) return true;
          final q = widget.searchQuery.toLowerCase();
          return p.name.toLowerCase().contains(q) ||
                 p.farm.toLowerCase().contains(q);
        }).toList();

        if (filtered.isEmpty && widget.searchQuery.isNotEmpty) {
          return (context.findAncestorStateOfType<_FarmerPublicProfileScreenState>()!)
              ._emptyState(
            Icons.search_off_rounded,
            'No Items Found',
            'No products matching "${widget.searchQuery}".',
          );
        }

        // Apply sorting
        final products = List<ProductItem>.from(filtered);
        if (_activeSortIndex == 1) {
          // Latest
          products.sort((a, b) => b.name.compareTo(a.name));
        } else if (_activeSortIndex == 3) {
          // Price
          products.sort((a, b) {
            final pa = double.tryParse(a.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
            final pb = double.tryParse(b.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
            return _priceAscending ? pa.compareTo(pb) : pb.compareTo(pa);
          });
        }

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Sub-filter row (Popular | Latest | Top Sales | Price ↕)
            SliverToBoxAdapter(
              child: Container(
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    _buildSortTab(0, 'Popular'),
                    _buildDivider(),
                    _buildSortTab(1, 'Latest'),
                    _buildDivider(),
                    _buildSortTab(2, 'Top Sales'),
                    _buildDivider(),
                    _buildSortTab(3, _activeSortIndex == 3 ? (_priceAscending ? 'Price ↑' : 'Price ↓') : 'Price ↕'),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(10),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.62,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildShopeeProductCard(context, products[index]),
                  childCount: products.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 14,
      color: const Color(0xFFE2E8F0),
    );
  }

  Widget _buildSortTab(int index, String label) {
    final isActive = _activeSortIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            if (index == 3 && _activeSortIndex == 3) {
              _priceAscending = !_priceAscending;
            } else {
              _activeSortIndex = index;
            }
          });
        },
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
              color: isActive ? const Color(0xFF059669) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShopeeProductCard(BuildContext context, ProductItem product) {
    final buttonKey = GlobalKey();
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => ProductViewScreen(product: product)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              AspectRatio(
                aspectRatio: 1.0,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: product.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: const Color(0xFFF8FAFC),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: const Color(0xFFF0FDF4),
                        child: const Center(
                          child: Icon(Icons.eco_outlined,
                              size: 32, color: Color(0xFF059669)),
                        ),
                      ),
                    ),
                    // Direct Grower Tag
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Direct Farm',
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Title (2 lines max)
                      Text(
                        product.name,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      // Price Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            product.price,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF059669),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (product.unit.isNotEmpty) ...[
                            const SizedBox(width: 2),
                            Text(
                              '/${product.unit}',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF94A3B8),
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Rating & Action Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 11, color: Color(0xFFFBBF24)),
                              const SizedBox(width: 2),
                              Text(
                                '5.0',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                '  |  Fresh',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                          if (AuthService().userId.isEmpty || product.farmerId != AuthService().userId)
                            GestureDetector(
                              key: buttonKey,
                              onTap: () async {
                                final parentState = context.findAncestorStateOfType<_FarmerPublicProfileScreenState>();
                                if (parentState != null) {
                                  parentState._runFlyToCartAnimation(buttonKey, product.imageUrl);
                                }
                                final errorMsg = await CartService().addItem(product);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(errorMsg ?? '${product.name} added to cart'),
                                    duration: const Duration(seconds: 1),
                                    backgroundColor: const Color(0xFF059669),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFD1FAE5)),
                                ),
                                child: const Icon(
                                  Icons.add_shopping_cart_rounded,
                                  size: 13,
                                  color: Color(0xFF059669),
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
}

// â”€â”€ Posts Tab â”€â”€
class _PostsTab extends StatelessWidget {
  final String farmerUserId;
  const _PostsTab({required this.farmerUserId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ForumPostItem>>(
      future: SupabaseDataService().getForumPostsByUserId(farmerUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return (context.findAncestorStateOfType<_FarmerPublicProfileScreenState>()!)
              ._emptyState(
            Icons.article_outlined,
            'No Posts Yet',
            'This farmer hasn\'t shared any posts.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          physics: const BouncingScrollPhysics(),
          itemCount: posts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (_, i) => _buildPostCard(posts[i]),
        );
      },
    );
  }

  Widget _buildPostCard(ForumPostItem post) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.userName,
                      style: AppTextStyles.headline3.copyWith(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      post.time,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSubtle, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (post.title.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              post.title,
              style: AppTextStyles.headline3.copyWith(fontSize: 16),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Text(
            post.body,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textHeadline.withValues(alpha: 0.85),
              height: 1.5,
            ),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CachedNetworkImage(
                imageUrl: post.imageUrl!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Engagement row
          Row(
            children: [
              Icon(
                post.isLiked
                    ? Icons.thumb_up_alt_rounded
                    : Icons.thumb_up_alt_outlined,
                size: 18,
                color:
                    post.isLiked ? AppColors.primary : AppColors.textSubtle,
              ),
              const SizedBox(width: 6),
              Text(
                '${post.likes}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSubtle,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 20),
              const Icon(Icons.chat_bubble_outline_rounded,
                  size: 18, color: AppColors.textSubtle),
              const SizedBox(width: 6),
              Text(
                '${post.comments}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSubtle,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
