import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/admin/admin_service.dart';
import 'admin_ui.dart';

class AdminContentTab extends StatefulWidget {
  final AdminService adminService;
  const AdminContentTab({super.key, required this.adminService});

  @override
  State<AdminContentTab> createState() => _AdminContentTabState();
}

class _AdminContentTabState extends State<AdminContentTab> {
  String _activeFilter = 'All Content';
  final String _sortBy = 'Latest Published';

  // Real article data from Supabase
  late Future<List<Map<String, dynamic>>> _articlesFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _articlesFuture = widget.adminService.getAllFarmers(page: 0, pageSize: 10, isVerified: true); 
      // Note: Using verified farmers as a proxy for "Authors" until a dedicated articles table is populated
    });
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
            _buildArticlesTable(),
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
                'Manage and curate horticultural publications across the platform.',
                style: AdminUi.body(size: 15, color: AdminUi.textSecondary),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {},
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
  Widget _buildFilterAndStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AdminUi.cardDecoration(),
      child: Row(
        children: [
          // Filter by: label
          Text('Filter by:', style: AdminUi.body(size: 13, color: AdminUi.textSecondary)),
          const SizedBox(width: 16),
          // Filter tabs
          _filterTab('All Content'),
          _filterTab('Published'),
          _filterTab('Drafts'),
          _filterTab('Archived'),
          const SizedBox(width: 24),
          // Sorted by
          Text('Sorted by:', style: AdminUi.body(size: 12, color: AdminUi.textMuted)),
          const SizedBox(width: 8),
          Text(_sortBy, style: AdminUi.label(size: 13, color: AdminUi.textPrimary, weight: FontWeight.w600)),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AdminUi.textMuted),
          const Spacer(),
          // Stats badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AdminUi.brand,
              borderRadius: AdminUi.radiusMd,
            ),
            child: Row(
              children: [
                _statItem('128', 'ARTICLES'),
                Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.2), margin: const EdgeInsets.symmetric(horizontal: 16)),
                _statItem('42', 'AUTHORS'),
                Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.2), margin: const EdgeInsets.symmetric(horizontal: 16)),
                _statItem('1.2M', 'VIEWS'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterTab(String label) {
    final active = _activeFilter == label;
    return InkWell(
      onTap: () => setState(() => _activeFilter = label),
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
        Text(label, style: AdminUi.label(size: 9, color: Colors.white.withValues(alpha: 0.7), weight: FontWeight.w600, letterSpacing: 0.5)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ARTICLES TABLE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildArticlesTable() {
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
              children: [
                _headerCell('TITLE', flex: 4),
                _headerCell('AUTHOR', flex: 2),
                _headerCell('STATUS', flex: 2),
                _headerCell('PUBLISHED DATE', flex: 2),
                _headerCell('CREATED DATE', flex: 2),
                _headerCell('ACTIONS', flex: 2, align: TextAlign.right),
              ],
            ),
          ),
          // Rows
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _articlesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: Text('No articles found')),
                );
              }
              return Column(
                children: items.map((item) => _buildArticleRow({
                  'title': item['farm_name'] ?? 'Agricultural Insight',
                  'category': item['specialty'] ?? 'General',
                  'author': item['users']?['name'] ?? 'Verified Farmer',
                  'status': 'PUBLISHED',
                  'publishedDate': 'RECENT',
                  'createdDate': item['created_at']?.toString().substring(0, 10) ?? 'N/A',
                })).toList(),
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
    final isPublished = article['status'] == 'PUBLISHED';

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
                  ),
                  child: Icon(Icons.article_rounded, size: 22, color: AdminUi.brand),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(article['title'], style: AdminUi.label(size: 14, color: AdminUi.textPrimary, weight: FontWeight.w700)),
                      Text('Category: ${article['category']}', style: AdminUi.body(size: 12, color: AdminUi.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Author
          Expanded(
            flex: 2,
            child: Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 16, color: AdminUi.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(article['author'], style: AdminUi.body(size: 13, color: AdminUi.textSecondary)),
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
                    article['status'],
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
              article['publishedDate'] ?? '—',
              style: AdminUi.body(size: 13, color: AdminUi.textSecondary),
            ),
          ),
          // Created Date
          Expanded(
            flex: 2,
            child: Text(
              article['createdDate'] ?? 'N/A',
              style: AdminUi.body(size: 13, color: AdminUi.textMuted, weight: FontWeight.w500),
            ),
          ),
          // Actions
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _iconAction(Icons.edit_rounded, 'Edit'),
                _iconAction(Icons.visibility_outlined, 'Preview'),
                if (isPublished) _iconAction(Icons.visibility_off_outlined, 'Unpublish'),
                _iconAction(Icons.delete_outline_rounded, 'Delete', color: AdminUi.danger),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconAction(IconData icon, String tooltip, {Color color = AdminUi.textMuted}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {},
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
        Text('Showing 3 of 128 Curated Articles', style: AdminUi.body(size: 13, color: AdminUi.textMuted)),
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
                          Text('MOST IMPACTFUL', style: AdminUi.label(size: 9, color: Colors.white.withValues(alpha: 0.7), weight: FontWeight.w700, letterSpacing: 0.5)),
                          const SizedBox(height: 2),
                          Text('Climate Resilient Grapes', style: AdminUi.title(size: 16, color: Colors.white)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('12.4K', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                          Text('Total Engagement', style: AdminUi.label(size: 10, color: Colors.white.withValues(alpha: 0.7))),
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
                  'Articles regarding regenerative agriculture have seen a 14% increase in reader retention this month. Consider prioritizing "Soil Health" themes for the upcoming editorial cycle.',
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
