import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/admin/admin_service.dart';
import '../../../shared/widgets/create_article_dialog.dart';
import 'admin_ui.dart';

class AdminContentTab extends StatefulWidget {
  final AdminService adminService;
  const AdminContentTab({super.key, required this.adminService});

  @override
  State<AdminContentTab> createState() => _AdminContentTabState();
}

class _AdminContentTabState extends State<AdminContentTab> {
  String _activeTab = 'Publications'; // 'Publications' or 'Community'
  String _activeFilter = 'All Content';
  final String _sortBy = 'Latest Published';

  // Real data from Supabase
  late Future<List<Map<String, dynamic>>> _dataFuture;
  Map<String, dynamic> _stats = {'total': 0, 'published': 0, 'drafts': 0, 'pinned': 0, 'views': '0'};
  late VoidCallback _dataRefreshListener;

  @override
  void initState() {
    super.initState();
    _dataRefreshListener = () {
      if (!mounted) return;
      _loadData();
    };
    widget.adminService.dataVersionListenable.addListener(_dataRefreshListener);
    _loadData();
  }

  @override
  void dispose() {
    widget.adminService.dataVersionListenable.removeListener(_dataRefreshListener);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      if (_activeTab == 'Publications') {
        _dataFuture = widget.adminService.getAllArticles(
          page: 0, 
          pageSize: 10,
          status: _activeFilter,
        );
      } else {
        _dataFuture = widget.adminService.getCommunityPosts(
          page: 0,
          pageSize: 10,
        );
      }
    });

    final stats = _activeTab == 'Publications' 
      ? await widget.adminService.getArticleStats()
      : await widget.adminService.getCommunityPostStats();
      
    if (mounted) {
      setState(() => _stats = stats);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: SingleChildScrollView(
        padding: AdminUi.pagePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildFilterAndStats(),
            const SizedBox(height: 24),
            _buildContentTable(),
            const SizedBox(height: 16),
            _buildPaginationRow(),
            const SizedBox(height: 40),
            _buildBottomInsights(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEADER: Content Arboretum title + Create New Article button
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Content Arboretum', style: AdminUi.display(context, size: 28)),
              const SizedBox(height: 4),
              Text(
                _activeTab == 'Publications' 
                  ? 'Manage and curate horticultural publications across the platform.'
                  : 'Moderate community discussions and manage farmer-contributed content.',
                style: AdminUi.body(size: 15, color: AdminUi.textSecondary),
              ),
              const SizedBox(height: 16),
              // Tab Selector
              Row(
                children: [
                  _tabItem('Publications'),
                  const SizedBox(width: 8),
                  _tabItem('Community'),
                ],
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            final result = await showDialog<bool>(
              context: context,
              builder: (context) => CreateArticleDialog(adminService: widget.adminService),
            );
            if (result == true && mounted) {
              _loadData();
            }
          },
          style: AdminUi.primaryButton,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Create New Article'),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FILTER TABS + STATS BADGE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _tabItem(String label) {
    final active = _activeTab == label;
    return InkWell(
      onTap: () {
        setState(() {
          _activeTab = label;
          _activeFilter = 'All Content';
        });
        _loadData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AdminUi.brand : Colors.transparent,
          borderRadius: AdminUi.radiusMd,
          border: active ? null : Border.all(color: AdminUi.border),
        ),
        child: Text(
          label,
          style: AdminUi.label(
            size: 13,
            color: active ? Colors.white : AdminUi.textSecondary,
            weight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterAndStats() {
    final isArticles = _activeTab == 'Publications';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AdminUi.cardDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 900;
          return Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (isArticles) ...[
                        Text('Filter by:', style: AdminUi.body(size: 13, color: AdminUi.textSecondary)),
                        const SizedBox(width: 16),
                        _filterTab('All Content'),
                        _filterTab('Published'),
                        _filterTab('Drafts'),
                        _filterTab('Archived'),
                      ] else ...[
                        Text('Moderate:', style: AdminUi.body(size: 13, color: AdminUi.textSecondary)),
                        const SizedBox(width: 16),
                        _filterTab('All Content'),
                        _filterTab('Pinned'),
                      ],
                      const SizedBox(width: 24),
                      Text('Sorted by:', style: AdminUi.body(size: 12, color: AdminUi.textMuted)),
                      const SizedBox(width: 8),
                      Text(_sortBy, style: AdminUi.label(size: 13, color: AdminUi.textPrimary, weight: FontWeight.w600)),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AdminUi.textMuted),
                    ],
                  ),
                ),
              ),
              if (!isCompact) const SizedBox(width: 24),
              // Stats badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AdminUi.brand,
                  borderRadius: AdminUi.radiusMd,
                ),
                child: Row(
                  children: isArticles ? [
                    _statItem(_stats['total'].toString(), 'ARTICLES'), 
                    Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.2), margin: const EdgeInsets.symmetric(horizontal: 16)),
                    _statItem(_stats['published'].toString(), 'PUBLISHED'),
                    Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.2), margin: const EdgeInsets.symmetric(horizontal: 16)),
                    _statItem(_stats['views'].toString(), 'VIEWS'),
                  ] : [
                    _statItem(_stats['total'].toString(), 'POSTS'), 
                    Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.2), margin: const EdgeInsets.symmetric(horizontal: 16)),
                    _statItem(_stats['pinned'].toString(), 'PINNED'),
                    Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.2), margin: const EdgeInsets.symmetric(horizontal: 16)),
                    _statItem(_stats['recent']?.toString() ?? '0', 'NEW (24H)'),
                  ],
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _filterTab(String label) {
    final active = _activeFilter == label;
    return InkWell(
      onTap: () {
        setState(() => _activeFilter = label);
        _loadData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: AdminUi.radiusSm,
          border: active ? Border.all(color: AdminUi.border) : null,
          boxShadow: active ? AdminUi.shadowSm : null,
        ),
        child: Text(
          label,
          style: AdminUi.label(
            size: 13,
            color: active ? AdminUi.textPrimary : AdminUi.textSecondary,
            weight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
        Text(label, style: AdminUi.label(size: 9, color: Colors.white.withValues(alpha: 0.8), weight: FontWeight.w600, letterSpacing: 0.5)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ARTICLES TABLE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildContentTable() {
    return Container(
      decoration: AdminUi.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: AdminUi.panelAlt,
              border: Border(bottom: BorderSide(color: AdminUi.border)),
            ),
            child: Row(
              children: _activeTab == 'Publications' ? [
                _headerCell('TITLE', flex: 4),
                _headerCell('AUDIENCE', flex: 2),
                _headerCell('STATUS', flex: 2),
                _headerCell('PUBLISHED DATE', flex: 2),
                _headerCell('CREATED DATE', flex: 2),
                _headerCell('ACTIONS', flex: 2, align: TextAlign.right),
              ] : [
                _headerCell('COMMUNITY POST', flex: 4),
                _headerCell('AUTHOR', flex: 2),
                _headerCell('ENGAGEMENT', flex: 2),
                _headerCell('PINNED', flex: 2),
                _headerCell('POSTED ON', flex: 2),
                _headerCell('ACTIONS', flex: 2, align: TextAlign.right),
              ],
            ),
          ),
          // Rows
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _dataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(child: Text('No ${_activeTab.toLowerCase()} found.', style: AdminUi.body(color: AdminUi.textMuted))),
                );
              }
              return Column(
                children: items.map((item) => _activeTab == 'Publications' ? _buildArticleRow(item) : _buildCommunityRow(item)).toList(),
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String text, {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        style: AdminUi.label(size: 11, color: AdminUi.textMuted, weight: FontWeight.w700, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildArticleRow(Map<String, dynamic> article) {
    final isPublished = article['is_published'] == true;
    final articleId = article['article_id'].toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Row(
        children: [
          // Title + Category
          Expanded(
            flex: 4,
            child: Row(
              children: [
                // Article thumbnail
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AdminUi.brandSoft,
                    borderRadius: AdminUi.radiusSm,
                    border: Border.all(color: AdminUi.border),
                    image: article['cover_image_url'] != null ? DecorationImage(
                      image: NetworkImage(article['cover_image_url']),
                      fit: BoxFit.cover,
                    ) : null,
                  ),
                  child: article['cover_image_url'] == null ? Icon(Icons.article_rounded, size: 22, color: AdminUi.brand) : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(article['title'] ?? 'Untitled Article', style: AdminUi.label(size: 14, color: AdminUi.textPrimary, weight: FontWeight.w700)),
                      Text(article['summary'] ?? 'No summary provided', style: AdminUi.body(size: 12, color: AdminUi.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Audience
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (article['audience'] == 'FARMER') 
                      ? AdminUi.brand.withValues(alpha: 0.1) 
                      : (article['audience'] == 'CUSTOMER')
                        ? AdminUi.warning.withValues(alpha: 0.1)
                        : AdminUi.textMuted.withValues(alpha: 0.1),
                    borderRadius: AdminUi.radiusSm,
                  ),
                  child: Text(
                    (article['audience'] == 'FARMER') 
                      ? 'FARMERS' 
                      : (article['audience'] == 'CUSTOMER')
                        ? 'CUSTOMERS'
                        : 'BOTH',
                    style: AdminUi.label(
                      size: 10, 
                      color: (article['audience'] == 'FARMER') 
                        ? AdminUi.brand 
                        : (article['audience'] == 'CUSTOMER')
                          ? AdminUi.warning
                          : AdminUi.textSecondary, 
                      weight: FontWeight.w800
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Status
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isPublished ? AdminUi.success.withValues(alpha: 0.1) : AdminUi.warning.withValues(alpha: 0.1),
                    borderRadius: AdminUi.radiusSm,
                  ),
                  child: Text(
                    isPublished ? 'PUBLISHED' : 'DRAFT',
                    style: AdminUi.label(size: 10, color: isPublished ? AdminUi.success : AdminUi.warning, weight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          // Published Date
          Expanded(
            flex: 2,
            child: Text(
              article['published_at']?.toString().substring(0, 10) ?? '—',
              style: AdminUi.body(size: 13, color: AdminUi.textSecondary),
            ),
          ),
          // Created Date
          Expanded(
            flex: 2,
            child: Text(
              article['created_at']?.toString().substring(0, 10) ?? 'N/A',
              style: AdminUi.body(size: 13, color: AdminUi.textMuted, weight: FontWeight.w500),
            ),
          ),
          // Actions
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _iconAction(Icons.edit_rounded, 'Edit', onTap: () async {
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (context) => CreateArticleDialog(
                      adminService: widget.adminService,
                      initialData: article,
                    ),
                  );
                  if (result == true && mounted) {
                    _loadData();
                  }
                }),
                _iconAction(
                  isPublished ? Icons.visibility_off_outlined : Icons.publish_rounded, 
                  isPublished ? 'Unpublish' : 'Publish',
                  onTap: () async {
                    final success = await widget.adminService.updateArticleStatus(articleId, !isPublished);
                    if (success) _loadData();
                  }
                ),
                _iconAction(Icons.delete_outline_rounded, 'Delete', color: AdminUi.danger, onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Article?'),
                      content: const Text('This action cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final success = await widget.adminService.deleteArticle(articleId);
                    if (success) _loadData();
                  }
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityRow(Map<String, dynamic> post) {
    final postId = post['post_id'].toString();
    final isPinned = post['is_pinned'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Row(
        children: [
          // Content
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post['title'] ?? 'Untitled Post', style: AdminUi.label(size: 14, color: AdminUi.textPrimary, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(post['body'] ?? '', style: AdminUi.body(size: 12, color: AdminUi.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          // Author
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: AdminUi.brandSoft,
                  child: Text((post['author_name'] ?? 'U')[0], style: TextStyle(fontSize: 8, color: AdminUi.brand, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text(post['author_name'] ?? 'Unknown', style: AdminUi.body(size: 13, color: AdminUi.textPrimary, weight: FontWeight.w500)),
              ],
            ),
          ),
          // Engagement
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(Icons.thumb_up_alt_outlined, size: 12, color: AdminUi.textMuted),
                const SizedBox(width: 4),
                Text(post['likes_count']?.toString() ?? '0', style: AdminUi.body(size: 12, color: AdminUi.textSecondary)),
                const SizedBox(width: 12),
                Icon(Icons.chat_bubble_outline_rounded, size: 12, color: AdminUi.textMuted),
                const SizedBox(width: 4),
                Text(post['comments_count']?.toString() ?? '0', style: AdminUi.body(size: 12, color: AdminUi.textSecondary)),
              ],
            ),
          ),
          // Pinned Status
          Expanded(
            flex: 2,
            child: Row(
              children: [
                if (isPinned)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AdminUi.brand.withValues(alpha: 0.1),
                      borderRadius: AdminUi.radiusSm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.push_pin_rounded, size: 10, color: AdminUi.brand),
                        const SizedBox(width: 4),
                        Text('PINNED', style: AdminUi.label(size: 9, color: AdminUi.brand, weight: FontWeight.w800)),
                      ],
                    ),
                  )
                else
                  Text('—', style: AdminUi.body(size: 13, color: AdminUi.textMuted)),
              ],
            ),
          ),
          // Date
          Expanded(
            flex: 2,
            child: Text(
              post['created_at']?.toString().substring(0, 10) ?? '—',
              style: AdminUi.body(size: 13, color: AdminUi.textMuted),
            ),
          ),
          // Actions
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _iconAction(
                  isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, 
                  isPinned ? 'Unpin' : 'Pin to top',
                  color: isPinned ? AdminUi.brand : AdminUi.textMuted,
                  onTap: () async {
                    final success = await widget.adminService.togglePinCommunityPost(postId, !isPinned);
                    if (success) _loadData();
                  }
                ),
                _iconAction(Icons.delete_outline_rounded, 'Delete', color: AdminUi.danger, onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Post?'),
                      content: const Text('This will permanently remove this community post.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final success = await widget.adminService.deleteCommunityPost(postId);
                    if (success) _loadData();
                  }
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconAction(IconData icon, String tooltip, {Color color = AdminUi.textMuted, required VoidCallback onTap}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: AdminUi.radiusSm,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAGINATION
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPaginationRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Showing curated publications', style: AdminUi.body(size: 13, color: AdminUi.textMuted)),
        Row(
          children: [
            _pageButton('<', false),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AdminUi.radiusSm,
                border: Border.all(color: AdminUi.border),
              ),
              child: Text('Page 1', style: AdminUi.label(size: 12, color: AdminUi.textPrimary, weight: FontWeight.w600)),
            ),
            const SizedBox(width: 4),
            _pageButton('>', false),
          ],
        ),
      ],
    );
  }

  Widget _pageButton(String label, bool active) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: active ? AdminUi.brand : Colors.white,
        borderRadius: AdminUi.radiusSm,
        border: active ? null : Border.all(color: AdminUi.border),
      ),
      alignment: Alignment.center,
      child: Text(label, style: AdminUi.label(size: 12, color: active ? Colors.white : AdminUi.textSecondary, weight: FontWeight.w700)),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTTOM INSIGHTS (Most Impactful Article + Curator's Weekly Insight)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBottomInsights() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Most Impactful Card
        Expanded(
          flex: 1,
          child: Container(
            height: 220,
            decoration: BoxDecoration(
              color: AdminUi.brandDark,
              borderRadius: AdminUi.radiusLg,
              image: const DecorationImage(
                image: NetworkImage('https://images.unsplash.com/photo-1560493676-04071c5f467b?w=600'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Color(0x88000000), BlendMode.darken),
              ),
            ),
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: AdminUi.radiusMd,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('REALTIME', style: AdminUi.label(size: 9, color: Colors.white.withValues(alpha: 0.8), weight: FontWeight.w700, letterSpacing: 0.5)),
                          const SizedBox(height: 2),
                          Text('Featured Publication', style: AdminUi.title(size: 16, color: Colors.white)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('ACTIVE', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                          Text('Engagement Status', style: AdminUi.label(size: 10, color: Colors.white.withValues(alpha: 0.8))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        // Curator's Weekly Insight
        Expanded(
          flex: 1,
          child: Container(
            height: 220,
            padding: const EdgeInsets.all(28),
            decoration: AdminUi.cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.menu_book_rounded, size: 28, color: AdminUi.brand),
                const SizedBox(height: 12),
                Text("Curator's Weekly Insight", style: AdminUi.title(size: 20)),
                const SizedBox(height: 8),
                Text(
                  'Reader engagement trends remain stable. The platform continues to prioritize high-quality agricultural education and sustainability content.',
                  style: AdminUi.body(size: 13, color: AdminUi.textSecondary),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Row(
                  children: [
                    Text('View Editorial Strategy', style: AdminUi.label(size: 13, color: AdminUi.textPrimary, weight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 16, color: AdminUi.textPrimary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
