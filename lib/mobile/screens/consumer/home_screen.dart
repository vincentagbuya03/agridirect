import 'package:flutter/material.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/styles/app_theme.dart';

/// Home Screen - Premium Customer Interface
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildPremiumHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGlassAIMarketInsight(),
                  _buildSectionHeader('Browse Categories', 'Show all', () {}),
                  _buildCategoryGrid(),
                  const SizedBox(height: 32),
                  _buildSectionHeader(
                    'Featured Farmers',
                    'Map View',
                    () => context.push(AppRoutes.farmersMap),
                  ),
                  _buildFeaturedFarmersList(context),
                  const SizedBox(height: 32),
                  _buildSectionHeader('Community Stories', 'Join Chat', () {}),
                  _buildCommunityFeed(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    String action,
    VoidCallback onAction,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTextStyles.headline2.copyWith(fontSize: 22)),
          GestureDetector(
            onTap: onAction,
            child: Text(
              action,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.textHeadline.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DELIVERING TO',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'San Carlos City',
                            style: AppTextStyles.headline3.copyWith(
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: AppColors.textHeadline,
                          ),
                        ],
                      ),
                    ],
                  ),
                  _buildHeaderAction(
                    context,
                    Icons.chat_bubble_outline_rounded,
                    true,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.textHeadline.withValues(alpha: 0.05),
                        ),
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search fresh produce...',
                          hintStyle: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSubtle,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.textSubtle,
                            size: 22,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: Colors.white,
                      size: 22,
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

  Widget _buildHeaderAction(
    BuildContext context,
    IconData icon,
    bool hasNotification,
  ) {
    return InkWell(
      onTap: () => context.push(AppRoutes.customerMessages),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.textHeadline.withValues(alpha: 0.05),
          ),
        ),
        child: Stack(
          children: [
            Icon(icon, color: AppColors.textHeadline, size: 24),
            if (hasNotification)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassAIMarketInsight() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0369A1), Color(0xFF0EA5E9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0369A1).withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'AI MARKET SCAN',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.9),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Tomatoes are currently 12% cheaper',
              style: AppTextStyles.headline2.copyWith(
                color: Colors.white,
                fontSize: 24,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Market supply peaked this morning. Local farmers are offering fresh harvests at wholesale prices.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0369A1),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Shop Best Prices',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final categories = [
      _CategoryData(
        Icons.eco_rounded,
        'Veggies',
        const Color(0xFFDCFCE7),
        AppColors.primary,
      ),
      _CategoryData(
        Icons.apple_rounded,
        'Fruits',
        const Color(0xFFFFEDD5),
        const Color(0xFFEA580C),
      ),
      _CategoryData(
        Icons.grass_rounded,
        'Grains',
        const Color(0xFFFEF3C7),
        const Color(0xFFD97706),
      ),
      _CategoryData(
        Icons.water_drop_rounded,
        'Dairy',
        const Color(0xFFDBEAFE),
        const Color(0xFF2563EB),
      ),
      _CategoryData(
        Icons.spa_rounded,
        'Organic',
        const Color(0xFFD1FAE5),
        const Color(0xFF059669),
      ),
    ];

    return SizedBox(
      height: 110,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 20),
        itemBuilder: (_, i) {
          final cat = categories[i];
          return Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: cat.bgColor.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  border: Border.all(color: cat.bgColor, width: 2),
                ),
                child: Center(
                  child: Icon(cat.icon, size: 28, color: cat.iconColor),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                cat.label,
                style: AppTextStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHeadline,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFeaturedFarmersList(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseDataService().getFeaturedFarmers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: AppShimmerLoader());
        }

        final farmers = snapshot.data ?? [];
        return SizedBox(
          height: 344,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: farmers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 20),
            itemBuilder: (_, index) {
              final f = farmers[index];
              return _buildFarmerCard(context, f);
            },
          ),
        );
      },
    );
  }

  Widget _buildFarmerCard(BuildContext context, Map<String, dynamic> f) {
    return Container(
      width: 260,
      decoration: AppDecorations.cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: _buildFarmerImage(f['imageUrl']?.toString()),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        f['rating'] ?? '4.5',
                        style: AppTextStyles.labelSmall.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_border_rounded,
                    size: 18,
                    color: AppColors.textSubtle,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        f['name'] ?? 'Farmer Name',
                        style: AppTextStyles.headline3.copyWith(fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (f['badge'] == 'VERIFIED')
                      const Icon(
                        Icons.verified_rounded,
                        size: 18,
                        color: AppColors.secondary,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${f['distance']} • ${f['specialty']}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSubtle,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: AppTextStyles.labelSmall.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: const Text('View Profile'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityFeed(BuildContext context) {
    return StreamBuilder<List<ForumPostItem>>(
      stream: SupabaseDataService().watchForumPosts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: AppShimmerLoader()),
          );
        }

        final List<ForumPostItem> posts =
            snapshot.data ?? const <ForumPostItem>[];
        if (posts.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: AppDecorations.cardDecoration.copyWith(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'No community stories available yet.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSubtle,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final List<ForumPostItem> visiblePosts = posts
            .take(2)
            .toList(growable: false);

        return Column(
          children: [
            ...visiblePosts.map(
              (ForumPostItem post) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _buildCommunityPostCard(
                  authorName: post.userName,
                  authorRole: post.title.isEmpty ? 'Farmer' : post.title,
                  timeAgo: post.time,
                  postContent: post.body,
                  likes: post.likes.toString(),
                  comments: post.comments.toString(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.people_outline_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'VIEW COMMUNITY HUB',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFarmerImage(String? rawUrl) {
    if (_isValidNetworkUrl(rawUrl)) {
      return CachedNetworkImage(
        imageUrl: rawUrl!,
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => _farmerImagePlaceholder(),
      );
    }

    return _farmerImagePlaceholder();
  }

  Widget _farmerImagePlaceholder() {
    return Container(
      height: 150,
      width: double.infinity,
      color: AppColors.primary.withValues(alpha: 0.08),
      child: const Center(
        child: Icon(
          Icons.agriculture_rounded,
          size: 42,
          color: AppColors.primary,
        ),
      ),
    );
  }

  bool _isValidNetworkUrl(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return false;
    final uri = Uri.tryParse(text);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        (uri.host.isNotEmpty);
  }

  Widget _buildCommunityPostCard({
    required String authorName,
    required String authorRole,
    required String timeAgo,
    required String postContent,
    required String likes,
    required String comments,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(24),
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
                  color: AppColors.primary.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authorName,
                    style: AppTextStyles.headline3.copyWith(fontSize: 15),
                  ),
                  Text(
                    '$authorRole • $timeAgo',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSubtle,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            postContent,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textHeadline.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildPostAction(Icons.thumb_up_alt_outlined, likes),
              const SizedBox(width: 20),
              _buildPostAction(Icons.chat_bubble_outline_rounded, comments),
              const Spacer(),
              const Icon(
                Icons.share_outlined,
                size: 20,
                color: AppColors.textSubtle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostAction(IconData icon, String count) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSubtle),
        const SizedBox(width: 6),
        Text(
          count,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSubtle,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CategoryData {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color iconColor;
  _CategoryData(this.icon, this.label, this.bgColor, this.iconColor);
}

