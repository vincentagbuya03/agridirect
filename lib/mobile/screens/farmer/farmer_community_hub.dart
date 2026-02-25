import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Mobile-only Community Hub.
/// No web/responsive branches - purely mobile UI.
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

  static const Color primary = Color(0xFF13EC5B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F6),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                // Tabs
                TabBar(
                  controller: _tabController,
                  labelColor: primary,
                  unselectedLabelColor: Colors.grey[400],
                  indicatorColor: primary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: const [
                    Tab(text: 'Forum'),
                    Tab(text: 'Articles'),
                  ],
                ),
                // Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildForumContent(), _buildArticlesContent()],
                  ),
                ),
              ],
            ),
            // FAB
            Positioned(
              bottom: 32,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_square, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Post a Question',
                      style: TextStyle(
                        fontSize: 14,
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
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F6).withValues(alpha: 0.8),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE0E7E0), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary.withValues(alpha: 0.2),
              border: Border.all(color: primary.withValues(alpha: 0.3)),
            ),
            child: Icon(Icons.account_circle, color: primary),
          ),
          const Text(
            'Community Hub',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(Icons.notifications_outlined, size: 20),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEDF2ED),
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Search pests, crops, or topics',
            hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
            prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildForumContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildForumCard(
          userName: 'Samuel Green',
          time: '2 hours ago',
          title: 'Pest control tips for Cabbage',
          body:
              "I've found that neem oil works wonders for aphids on young cabbage plants. Make sure to spray in the evening to avoid leaf burn...",
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuAU5BsZk45a4YKNRYGbLaIQtrv4SrXQisINXE6bEWrn68xyvpSXq3DGS0NIoQ6S61cLQd-k6WgXWLxteyZ6anZKx-ZZ0nYRrD4xbcEQciC1ZJE-Nx3Tkp6YKeBtp9G_uCIVYiMjp2CmFRrJw9Vgzz-Ny3lzle9oxyIc5OWEFCAkbqgeTzwA4jtitlBSWTAEKE3gntriMWx1wR2w6aENpGu7RC6EMwg1KT1IpY4zqekWP8B30sin5nEXmA4blGH07t_yood2PKglLaqQ',
          likes: 24,
          comments: 12,
          isLiked: true,
        ),
        const SizedBox(height: 16),
        _buildForumCard(
          userName: 'Anita Rao',
          time: '5 hours ago',
          title: 'New organic fertilizer subsidy?',
          body:
              'Has anyone heard about the new state-level subsidies for organic vermicompost setups? Looking for registration details.',
          likes: 8,
          comments: 3,
          isLiked: false,
        ),
      ],
    );
  }

  Widget _buildArticlesContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildArticleCard(),
        const SizedBox(height: 16),
        _buildArticleCard(
          title: 'Sustainable Water Management in Agriculture',
          excerpt:
              'Learn how to optimize water usage while maintaining crop health...',
        ),
        const SizedBox(height: 16),
        _buildArticleCard(
          title: 'Market Trends: Q4 2024',
          excerpt: 'Overview of upcoming agricultural market opportunities...',
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E7E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person, color: Colors.grey[400]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        time,
                        style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.more_horiz, color: Colors.grey[400]),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            if (imageUrl != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: Colors.grey[200]),
                    errorWidget: (_, __, ___) =>
                        Container(color: Colors.grey[200]),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[100]!)),
              ),
              child: Row(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.thumb_up,
                        size: 20,
                        color: isLiked ? primary : Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$likes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isLiked ? primary : Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 20,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$comments',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(Icons.share, size: 20, color: Colors.grey[400]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleCard({
    String title = 'Optimizing Drip Irrigation for Small Farms in 2024',
    String excerpt =
        'Learn how to maximize water efficiency while reducing operational costs in modern agriculture...',
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E7E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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
                    "FEATURED ARTICLE",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'By AgriDirect',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '4 min read',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl:
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuCEX_FGbTSlEvgcVwHHEMfPDvDPCwf1jJgoRvqWeM8YKnhq8MslvsCTDPBiEOLgf3ghqffQxCGDQaDPrUPojIs8Hun-ffZwkSQqnqYzomI0eTTnZPMnVJBbp9YWKVBJ11uHyhNV9em8FQJ4zwY1NdiWx-7XTpZ99nPgQrz7YSgBAbjFGHI-kjDVMfghvcp1_6wcRXV6PUgvLTA215YdbIKOEwxK0JE2lWioNIZ-pdZHBenPdwZi2VwpDUO-Z7_KTqbiJBgPyZTYBanU',
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(width: 100, height: 100, color: Colors.grey[200]),
                errorWidget: (_, __, ___) =>
                    Container(width: 100, height: 100, color: Colors.grey[200]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
