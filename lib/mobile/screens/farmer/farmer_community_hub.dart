import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../shared/styles/app_theme.dart';

/// Farmer Community Hub - Professional Social Interface
class FarmerCommunityHub extends StatefulWidget {
  const FarmerCommunityHub({super.key});

  @override
  State<FarmerCommunityHub> createState() => _FarmerCommunityHubState();
}

class _FarmerCommunityHubState extends State<FarmerCommunityHub>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildPremiumHeader(),
          _buildSearchBar(),
          _buildSleekTabs(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildForumContent(), _buildArticlesContent()],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        elevation: 6,
        icon: const Icon(Icons.edit_square, color: Colors.white, size: 20),
        label: Text(
          'POST QUESTION',
          style: AppTextStyles.labelSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader() {
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 2),
                    ),
                    child: const ClipOval(
                      child: Icon(Icons.person_rounded, color: AppColors.textSubtle),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COMMUNITY',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'AgriDirect Hub',
                        style: AppTextStyles.headline2.copyWith(fontSize: 22),
                      ),
                    ],
                  ),
                ],
              ),
              _buildNotificationBadge(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationBadge() {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.background,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.05)),
          ),
          child: const Icon(Icons.notifications_none_rounded, size: 24, color: AppColors.textHeadline),
        ),
        Positioned(
          top: 8,
          right: 8,
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
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Container(
        height: 52,
        decoration: AppDecorations.cardDecoration.copyWith(
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Search pests, crops, or topics...',
            hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSubtle),
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSubtle, size: 22),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildSleekTabs() {
    return Container(
      width: double.infinity,
      color: Colors.transparent,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSubtle,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 3,
        dividerColor: Colors.transparent,
        labelStyle: AppTextStyles.labelSmall.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
        tabs: const [
          Tab(text: 'Forum'),
          Tab(text: 'Articles'),
        ],
      ),
    );
  }

  Widget _buildForumContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildForumCard(
          userName: 'Samuel Green',
          time: '2 hours ago',
          title: 'Optimal Pest Control for Cabbage',
          body: "I've started using cold-pressed neem oil for my cabbage crop. It’s highly effective against aphids without harming beneficial insects. Best applied during dusk to prevent leaf burn.",
          imageUrl: 'https://images.unsplash.com/photo-1591857177580-dc82b9ac4e1e?auto=format&fit=crop&q=80&w=800',
          likes: 24,
          comments: 12,
          isLiked: true,
        ),
        _buildForumCard(
          userName: 'Anita Rao',
          time: '5 hours ago',
          title: 'Organic Fertilizer Subsidy Updates',
          body: 'Does anyone have experience applying for the Department of Agriculture’s new organic vermicompost subsidy? The portal seems to have updated registration requirements.',
          likes: 8,
          comments: 3,
          isLiked: false,
        ),
      ],
    );
  }

  Widget _buildArticlesContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildArticleCard(
          title: 'Sustainable Water Management in 2024',
          excerpt: 'Discover advanced drip irrigation techniques designed specifically for high-yield seasonal crops...',
          category: 'RESOURCE GUIDE',
          readTime: '5 min read',
        ),
        _buildArticleCard(
          title: 'Market Outlook: Seasonal Pricing Insights',
          excerpt: 'Analysis of upcoming market trends for primary vegetables and root crops in the central district...',
          category: 'MARKET TRENDS',
          readTime: '3 min read',
        ),
      ],
    );
  }

  Widget _buildForumCard({
    required String userName,
    required String time,
    required String title,
    required String body,
    String? imageUrl,
    required int likes,
    required int comments,
    required bool isLiked,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: AppDecorations.cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.1)),
                      ),
                      child: const Icon(Icons.person_rounded, size: 20, color: AppColors.textSubtle),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(userName, style: AppTextStyles.headline3.copyWith(fontSize: 15)),
                          Text(time, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle, fontSize: 11)),
                        ],
                      ),
                    ),
                    const Icon(Icons.more_horiz_rounded, color: AppColors.textSubtle),
                  ],
                ),
                const SizedBox(height: 16),
                Text(title, style: AppTextStyles.headline3.copyWith(fontSize: 17, height: 1.3)),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHeadline.withValues(alpha: 0.7), height: 1.5),
                ),
                if (imageUrl != null) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.textHeadline.withValues(alpha: 0.05))),
            ),
            child: Row(
              children: [
                _buildSocialAction(
                  isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                  '$likes',
                  isLiked ? AppColors.primary : AppColors.textSubtle,
                ),
                const SizedBox(width: 24),
                _buildSocialAction(Icons.chat_bubble_outline_rounded, '$comments', AppColors.textSubtle),
                const Spacer(),
                const Icon(Icons.share_outlined, size: 20, color: AppColors.textSubtle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialAction(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildArticleCard({
    required String title,
    required String excerpt,
    required String category,
    required String readTime,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: AppDecorations.cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(title, style: AppTextStyles.headline3.copyWith(fontSize: 16)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const CircleAvatar(radius: 8, backgroundColor: AppColors.primary, child: Icon(Icons.spa, size: 8, color: Colors.white)),
                      const SizedBox(width: 8),
                      Text('By AgriDirect', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle)),
                      const SizedBox(width: 8),
                      const Icon(Icons.circle, size: 3, color: AppColors.textSubtle),
                      const SizedBox(width: 8),
                      Text(readTime, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 90,
                height: 90,
                color: AppColors.background,
                child: const Icon(Icons.article_outlined, color: AppColors.textSubtle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
