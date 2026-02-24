import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../shared/data/app_data.dart';

/// Web-only Community Hub — two-column layout with sidebar.
/// Completely separate UI from the mobile community hub.
class WebCommunityHub extends StatefulWidget {
  const WebCommunityHub({super.key});

  @override
  State<WebCommunityHub> createState() => _WebCommunityHubState();
}

class _WebCommunityHubState extends State<WebCommunityHub>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const Color _primary = Color(0xFF10B981);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

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
      backgroundColor: _surface,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main content
                Expanded(
                  flex: 3,
                  child: _buildMainContent(),
                ),
                // Right sidebar
                SizedBox(
                  width: 320,
                  child: _buildRightSidebar(),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.edit_rounded, size: 20),
        label: const Text('New Post', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ─── Top Bar ───
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          const Text(
            'Community Hub',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _dark),
          ),
          const SizedBox(width: 32),
          // Search
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search topics, pests, crops...',
                  hintStyle: TextStyle(color: _muted, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: _muted, size: 18),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Tabs
          Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: _primary,
              unselectedLabelColor: _muted,
              indicatorSize: TabBarIndicatorSize.label,
              indicatorColor: _primary,
              indicatorWeight: 2,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              dividerColor: Colors.transparent,
              tabAlignment: TabAlignment.center,
              tabs: const [
                Tab(text: 'Forum'),
                Tab(text: 'Articles'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Main Content ───
  Widget _buildMainContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildForumFeed(),
        _buildArticlesFeed(),
      ],
    );
  }

  Widget _buildForumFeed() {
    final posts = AppData.forumPosts;
    return ListView.builder(
      padding: const EdgeInsets.all(32),
      itemCount: posts.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: _buildForumCard(posts[i]),
      ),
    );
  }

  Widget _buildForumCard(ForumPostItem post) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    post.userName.split(' ').map((w) => w[0]).take(2).join(),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _primary),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.userName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _dark)),
                    Text(post.time, style: TextStyle(fontSize: 12, color: _muted)),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.more_horiz_rounded, size: 18, color: _muted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Title
          Text(post.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _dark)),
          const SizedBox(height: 8),
          Text(post.body, style: TextStyle(fontSize: 14, color: _muted, height: 1.6)),
          // Image
          if (post.imageUrl != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 8,
                child: CachedNetworkImage(
                  imageUrl: post.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.grey[100]),
                  errorWidget: (_, __, ___) => Container(color: Colors.grey[100]),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Actions
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                _buildPostAction(
                  icon: post.isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                  label: '${post.likes}',
                  active: post.isLiked,
                ),
                const SizedBox(width: 20),
                _buildPostAction(icon: Icons.chat_bubble_outline_rounded, label: '${post.comments}'),
                const Spacer(),
                _buildPostAction(icon: Icons.bookmark_border_rounded, label: 'Save'),
                const SizedBox(width: 16),
                _buildPostAction(icon: Icons.share_rounded, label: 'Share'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostAction({required IconData icon, required String label, bool active = false}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: active ? _primary : _muted),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? _primary : _muted),
          ),
        ],
      ),
    );
  }

  Widget _buildArticlesFeed() {
    final articles = AppData.articles;
    return ListView.builder(
      padding: const EdgeInsets.all(32),
      itemCount: articles.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: _buildArticleCard(articles[i]),
      ),
    );
  }

  Widget _buildArticleCard(ArticleItem article) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'FEATURED ARTICLE',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _primary, letterSpacing: 1.2),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(article.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _dark)),
                  const SizedBox(height: 6),
                  Text(article.excerpt, style: TextStyle(fontSize: 13, color: _muted, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('By ${article.author}', style: TextStyle(fontSize: 12, color: _muted)),
                      const SizedBox(width: 8),
                      Container(width: 4, height: 4, decoration: BoxDecoration(color: _muted, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(article.readTime, style: TextStyle(fontSize: 12, color: _muted)),
                    ],
                  ),
                ],
              ),
            ),
            if (article.imageUrl != null) ...[
              const SizedBox(width: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: article.imageUrl!,
                  width: 120,
                  height: 90,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(width: 120, height: 90, color: Colors.grey[100]),
                  errorWidget: (_, __, ___) => Container(width: 120, height: 90, color: Colors.grey[100]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Right Sidebar ───
  Widget _buildRightSidebar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: _border)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWeatherWidget(),
            const SizedBox(height: 24),
            _buildTrendingTopics(),
            const SizedBox(height: 24),
            _buildPopularTags(),
            const SizedBox(height: 24),
            _buildTopContributors(),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherWidget() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.cloud_rounded, color: Color(0xFF3B82F6), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('28°C', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _dark)),
                Text('Partly Cloudy · Manila', style: TextStyle(fontSize: 12, color: _muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingTopics() {
    final topics = [
      ('Pest Control Tips', 45),
      ('Organic Farming', 32),
      ('Water Management', 28),
      ('Market Prices', 19),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trending Topics', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _dark)),
          const SizedBox(height: 16),
          ...topics.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: _primary, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(t.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _dark)),
                    ),
                    Text('${t.$2} posts', style: TextStyle(fontSize: 12, color: _muted)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildPopularTags() {
    final tags = ['#organic', '#pestcontrol', '#irrigation', '#harvest', '#fertilizer', '#seedlings', '#weather', '#market'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Popular Tags', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _dark)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _border),
                ),
                child: Text(tag, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _muted)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopContributors() {
    final contributors = [
      ('Samuel Green', '45 posts', _primary),
      ('Anita Rao', '32 posts', const Color(0xFF3B82F6)),
      ('John Doe', '28 posts', const Color(0xFFF59E0B)),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Contributors', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _dark)),
          const SizedBox(height: 16),
          ...contributors.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c.$3.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          c.$1.split(' ').map((w) => w[0]).take(2).join(),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.$3),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _dark)),
                          Text(c.$2, style: TextStyle(fontSize: 11, color: _muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
