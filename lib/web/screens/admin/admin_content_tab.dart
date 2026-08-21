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
  // Navigation & View Mode
  String _activeTab = 'Publications'; // 'Publications' or 'Community'
  String _activeFilter = 'All Content'; // 'All Content', 'Published', 'Drafts', 'Archived'
  String _selectedAudience = 'ALL'; // 'ALL', 'FARMER', 'CUSTOMER'
  String _sortBy = 'Newest'; // 'Newest', 'Oldest', 'Title A-Z'
  bool _isGridView = false; // Toggle between Table and Magazine Grid
  
  // Search Query
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Data & State
  late Future<List<Map<String, dynamic>>> _dataFuture;
  Map<String, dynamic> _articleStats = {
    'total': 0,
    'published': 0,
    'drafts': 0,
    'views': '0',
  };
  Map<String, dynamic> _communityStats = {
    'total': 0,
    'pinned': 0,
    'recent': 0,
  };
  late VoidCallback _dataRefreshListener;

  // Pagination
  int _currentPage = 0;
  final int _pageSize = 10;

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
    _searchController.dispose();
    widget.adminService.dataVersionListenable.removeListener(_dataRefreshListener);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      if (_activeTab == 'Publications') {
        _dataFuture = widget.adminService.getAllArticles(
          page: _currentPage,
          pageSize: _pageSize,
          status: _activeFilter,
        );
      } else {
        _dataFuture = widget.adminService.getCommunityPosts(
          page: _currentPage,
          pageSize: _pageSize,
          searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        );
      }
    });

    final articleStatsFuture = widget.adminService.getArticleStats();
    final communityStatsFuture = widget.adminService.getCommunityPostStats();

    final results = await Future.wait([articleStatsFuture, communityStatsFuture]);

    if (mounted) {
      setState(() {
        _articleStats = results[0];
        _communityStats = results[1];
      });
    }
  }

  List<Map<String, dynamic>> _filterAndSortItems(List<Map<String, dynamic>> rawItems) {
    var items = List<Map<String, dynamic>>.from(rawItems);

    // Client-side search filtering if present
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      items = items.where((item) {
        final title = (item['title'] ?? '').toString().toLowerCase();
        final summary = (item['summary'] ?? item['body'] ?? '').toString().toLowerCase();
        final category = (item['category'] ?? '').toString().toLowerCase();
        final author = (item['author_name'] ?? '').toString().toLowerCase();
        return title.contains(q) || summary.contains(q) || category.contains(q) || author.contains(q);
      }).toList();
    }

    // Audience filter for publications
    if (_activeTab == 'Publications' && _selectedAudience != 'ALL') {
      items = items.where((item) {
        final aud = (item['audience'] ?? 'ALL').toString().toUpperCase();
        return aud == _selectedAudience || aud == 'ALL' || aud == 'BOTH';
      }).toList();
    }

    // Sort order
    if (_sortBy == 'Oldest') {
      items.sort((a, b) {
        final da = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
        final db = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
        return da.compareTo(db);
      });
    } else if (_sortBy == 'Title A-Z') {
      items.sort((a, b) {
        final ta = (a['title'] ?? '').toString().toLowerCase();
        final tb = (b['title'] ?? '').toString().toLowerCase();
        return ta.compareTo(tb);
      });
    } else {
      // Default: Newest
      items.sort((a, b) {
        final da = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
        final db = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
        return db.compareTo(da);
      });
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: SingleChildScrollView(
        padding: AdminUi.pagePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildExecutiveHeader(context),
            const SizedBox(height: 24),
            _buildKpiMetricsGrid(context),
            const SizedBox(height: 28),
            _buildControlToolbar(context),
            const SizedBox(height: 20),
            _buildContentCanvas(context),
            const SizedBox(height: 16),
            _buildPaginationBar(context),
            const SizedBox(height: 36),
            _buildEditorialSpotlightAndInsights(context),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. EXECUTIVE HEADER & ACTION HUB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildExecutiveHeader(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderBadge(),
                const SizedBox(height: 12),
                Text('Content Management Hub', style: AdminUi.display(context, size: 24)),
                const SizedBox(height: 6),
                Text(
                  'Curate agricultural publications, farmer advisories, and moderate community discussions.',
                  style: AdminUi.body(size: 13, color: AdminUi.textSecondary),
                ),
                const SizedBox(height: 18),
                _buildHeaderActions(isMobile: true),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderBadge(),
                      const SizedBox(height: 8),
                      Text('Content Management Hub', style: AdminUi.display(context, size: 28)),
                      const SizedBox(height: 4),
                      Text(
                        'Curate agricultural publications, farmer advisories, and moderate community discussions.',
                        style: AdminUi.body(size: 14, color: AdminUi.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                _buildHeaderActions(isMobile: false),
              ],
            ),
    );
  }

  Widget _buildHeaderBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AdminUi.brandSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AdminUi.brand,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'EDITORIAL OPERATIONS',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AdminUi.brand,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActions({required bool isMobile}) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Refresh Button
        OutlinedButton.icon(
          onPressed: _loadData,
          style: OutlinedButton.styleFrom(
            foregroundColor: AdminUi.textPrimary,
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Refresh'),
        ),
        // Create Article Button
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
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminUi.brand,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
          label: Text(
            'Create New Article',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. TOP KPI METRICS GRID (4 Vibrant Cards)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildKpiMetricsGrid(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final int crossAxisCount = width > 1200 ? 4 : (width > 700 ? 2 : 1);

    final isArticles = _activeTab == 'Publications';

    final totalArticles = _articleStats['total']?.toString() ?? '0';
    final publishedCount = _articleStats['published']?.toString() ?? '0';
    final draftsCount = _articleStats['drafts']?.toString() ?? '0';
    final viewsCount = _articleStats['views']?.toString() ?? '0';

    final totalCommunity = _communityStats['total']?.toString() ?? '0';
    final pinnedCommunity = _communityStats['pinned']?.toString() ?? '0';
    final recentCommunity = _communityStats['recent']?.toString() ?? '0';

    final metrics = isArticles
        ? [
            _kpiCard(
              title: 'TOTAL PUBLICATIONS',
              value: totalArticles,
              subtitle: '$draftsCount in draft mode',
              icon: Icons.menu_book_rounded,
              color: AdminUi.brand,
              badge: 'Curated',
            ),
            _kpiCard(
              title: 'PUBLISHED ARTICLES',
              value: publishedCount,
              subtitle: 'Live on user feeds',
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF10B981),
              badge: 'Active',
            ),
            _kpiCard(
              title: 'READER IMPRESSIONS',
              value: viewsCount,
              subtitle: 'Total platform reads',
              icon: Icons.visibility_outlined,
              color: const Color(0xFF3B82F6),
              badge: 'Analytics',
            ),
            _kpiCard(
              title: 'TARGETED AUDIENCES',
              value: 'Farmers & Buyers',
              subtitle: 'Multi-channel delivery',
              icon: Icons.groups_outlined,
              color: const Color(0xFF8B5CF6),
              badge: 'Segments',
            ),
          ]
        : [
            _kpiCard(
              title: 'COMMUNITY DISCUSSIONS',
              value: totalCommunity,
              subtitle: 'Total farmer threads',
              icon: Icons.forum_outlined,
              color: AdminUi.brand,
              badge: 'Forum',
            ),
            _kpiCard(
              title: 'PINNED ADVISORIES',
              value: pinnedCommunity,
              subtitle: 'Sticky announcements',
              icon: Icons.push_pin_rounded,
              color: const Color(0xFFF59E0B),
              badge: 'Priority',
            ),
            _kpiCard(
              title: 'NEW THREADS (24H)',
              value: recentCommunity,
              subtitle: 'Daily participation rate',
              icon: Icons.trending_up_rounded,
              color: const Color(0xFF10B981),
              badge: 'Real-time',
            ),
            _kpiCard(
              title: 'MODERATION STATUS',
              value: '100% Monitored',
              subtitle: 'Community integrity high',
              icon: Icons.shield_outlined,
              color: const Color(0xFF3B82F6),
              badge: 'Protected',
            ),
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (crossAxisCount == 1) {
          return Column(
            children: metrics.map((m) => Padding(padding: const EdgeInsets.only(bottom: 12), child: m)).toList(),
          );
        }

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          mainAxisExtent: 144,
          children: metrics,
        );
      },
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AdminUi.textMuted,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AdminUi.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AdminUi.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. ADVANCED CONTROL TOOLBAR (Tabs + Search + Filters + View Switcher)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildControlToolbar(BuildContext context) {
    final isArticles = _activeTab == 'Publications';
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 980;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Primary Segmented Tab Switcher + View Mode Toggle
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Segmented Tab Buttons
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _segmentedTab(
                        label: 'Publications & Guides',
                        count: _articleStats['total']?.toString() ?? '0',
                        isActive: _activeTab == 'Publications',
                        onTap: () {
                          setState(() {
                            _activeTab = 'Publications';
                            _activeFilter = 'All Content';
                            _currentPage = 0;
                          });
                          _loadData();
                        },
                      ),
                      const SizedBox(width: 4),
                      _segmentedTab(
                        label: 'Community Forum',
                        count: _communityStats['total']?.toString() ?? '0',
                        isActive: _activeTab == 'Community',
                        onTap: () {
                          setState(() {
                            _activeTab = 'Community';
                            _activeFilter = 'All Content';
                            _currentPage = 0;
                          });
                          _loadData();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Right side: View Switcher (Table vs Grid)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _viewModeButton(
                        icon: Icons.table_rows_rounded,
                        tooltip: 'Table List View',
                        isActive: !_isGridView,
                        onTap: () => setState(() => _isGridView = false),
                      ),
                      const SizedBox(width: 4),
                      _viewModeButton(
                        icon: Icons.grid_view_rounded,
                        tooltip: 'Magazine Cards View',
                        isActive: _isGridView,
                        onTap: () => setState(() => _isGridView = true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),

          // Row 2: Search Input + Status Chips + Audience Filter + Sort
          isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSearchField(),
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (isArticles) ...[
                            _filterPill('All Content'),
                            const SizedBox(width: 8),
                            _filterPill('Published'),
                            const SizedBox(width: 8),
                            _filterPill('Drafts'),
                          ] else ...[
                            _filterPill('All Content'),
                            const SizedBox(width: 8),
                            _filterPill('Pinned'),
                          ],
                          const SizedBox(width: 16),
                          _buildSortDropdown(),
                        ],
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    // Search Bar
                    Expanded(
                      flex: 3,
                      child: _buildSearchField(),
                    ),
                    const SizedBox(width: 16),
                    // Filter Pills
                    if (isArticles) ...[
                      _filterPill('All Content'),
                      const SizedBox(width: 8),
                      _filterPill('Published'),
                      const SizedBox(width: 8),
                      _filterPill('Drafts'),
                    ] else ...[
                      _filterPill('All Content'),
                      const SizedBox(width: 8),
                      _filterPill('Pinned'),
                    ],
                    const SizedBox(width: 16),
                    // Audience Filter
                    if (isArticles) ...[
                      _buildAudienceDropdown(),
                      const SizedBox(width: 12),
                    ],
                    // Sort Order
                    _buildSortDropdown(),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _segmentedTab({
    required String label,
    String? count,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AdminUi.brand : AdminUi.textSecondary,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive ? AdminUi.brandSoft : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isActive ? AdminUi.brand : AdminUi.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _viewModeButton({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive ? AdminUi.brand : AdminUi.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (val) => setState(() => _searchQuery = val),
      decoration: InputDecoration(
        hintText: _activeTab == 'Publications' ? 'Search articles by title, topic, or excerpt...' : 'Search community topics or authors...',
        hintStyle: GoogleFonts.inter(fontSize: 13, color: AdminUi.textMuted),
        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AdminUi.textMuted),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 16, color: AdminUi.textMuted),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AdminUi.brand, width: 1.5),
        ),
      ),
    );
  }

  Widget _filterPill(String label) {
    final isActive = _activeFilter == label;
    return InkWell(
      onTap: () {
        setState(() => _activeFilter = label);
        _loadData();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? AdminUi.brandSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AdminUi.brand : const Color(0xFFE2E8F0),
            width: isActive ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? AdminUi.brand : AdminUi.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildAudienceDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedAudience,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AdminUi.textMuted),
          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AdminUi.textPrimary),
          items: const [
            DropdownMenuItem(value: 'ALL', child: Text('All Audiences')),
            DropdownMenuItem(value: 'FARMER', child: Text('Farmers Only')),
            DropdownMenuItem(value: 'CUSTOMER', child: Text('Customers Only')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedAudience = val);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sortBy,
          icon: const Icon(Icons.sort_rounded, size: 16, color: AdminUi.textMuted),
          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AdminUi.textPrimary),
          items: const [
            DropdownMenuItem(value: 'Newest', child: Text('Sort: Newest')),
            DropdownMenuItem(value: 'Oldest', child: Text('Sort: Oldest')),
            DropdownMenuItem(value: 'Title A-Z', child: Text('Sort: Title A-Z')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _sortBy = val);
            }
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. CONTENT CANVAS (Table or Magazine Grid View)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildContentCanvas(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingSkeleton();
        }

        final rawItems = snapshot.data ?? [];
        final items = _filterAndSortItems(rawItems);

        if (items.isEmpty) {
          return _buildEmptyState();
        }

        if (_isGridView) {
          return _buildMagazineGridView(items);
        }

        return _buildEditorialTableView(items);
      },
    );
  }

  Widget _buildLoadingSkeleton() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AdminUi.brand),
            ),
            const SizedBox(height: 16),
            Text('Loading ${_activeTab.toLowerCase()}...', style: AdminUi.body(size: 13, color: AdminUi.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isArticles = _activeTab == 'Publications';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AdminUi.brandSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isArticles ? Icons.article_outlined : Icons.forum_outlined,
                size: 36,
                color: AdminUi.brand,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No matching results for "$_searchQuery"'
                  : 'No ${_activeTab.toLowerCase()} found in this view',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AdminUi.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try adjusting your search query or removing filters.'
                  : (isArticles
                      ? 'Publish curated guides and articles to educate platform users.'
                      : 'Community discussions posted by farmers will appear here.'),
              style: GoogleFonts.inter(fontSize: 13, color: AdminUi.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (isArticles) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (context) => CreateArticleDialog(adminService: widget.adminService),
                  );
                  if (result == true && mounted) _loadData();
                },
                style: AdminUi.primaryButton,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Create First Publication'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // A. EDITORIAL TABLE VIEW
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildEditorialTableView(List<Map<String, dynamic>> items) {
    final isArticles = _activeTab == 'Publications';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 860,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Table Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: isArticles
                      ? [
                          _thCell('ARTICLE DETAILS', flex: 5),
                          _thCell('AUDIENCE', flex: 2),
                          _thCell('STATUS', flex: 2),
                          _thCell('PUBLISHED ON', flex: 2),
                          _thCell('CREATED', flex: 2),
                          _thCell('ACTIONS', flex: 2, align: TextAlign.right),
                        ]
                      : [
                          _thCell('COMMUNITY TOPIC', flex: 5),
                          _thCell('AUTHOR', flex: 2),
                          _thCell('ENGAGEMENT', flex: 2),
                          _thCell('PRIORITY', flex: 2),
                          _thCell('POSTED ON', flex: 2),
                          _thCell('ACTIONS', flex: 2, align: TextAlign.right),
                        ],
                ),
              ),
              // Table Body
              ListView.separated(
                itemCount: items.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return isArticles ? _buildArticleTableRow(item) : _buildCommunityTableRow(item);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thCell(String label, {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: align,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildArticleTableRow(Map<String, dynamic> article) {
    final isPublished = article['is_published'] == true;
    final articleId = article['article_id']?.toString() ?? '';
    final audience = (article['audience'] ?? 'ALL').toString().toUpperCase();
    final category = article['category'] ?? 'General';
    final coverUrl = article['cover_image_url'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Cover + Title + Excerpt + Category
          Expanded(
            flex: 5,
            child: Row(
              children: [
                // 16:9 Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 64,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AdminUi.brandSoft,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      image: coverUrl != null && coverUrl.isNotEmpty
                          ? DecorationImage(image: NetworkImage(coverUrl), fit: BoxFit.cover)
                          : null,
                    ),
                    child: coverUrl == null || coverUrl.isEmpty
                        ? const Icon(Icons.image_outlined, size: 20, color: AdminUi.brand)
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              article['title'] ?? 'Untitled Publication',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AdminUi.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              category,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        article['summary'] ?? 'No summary available',
                        style: GoogleFonts.inter(fontSize: 12, color: AdminUi.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Audience Badge
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _audienceBadge(audience),
            ),
          ),
          // Status Chip (Clickable toggle)
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _statusChip(
                isPublished: isPublished,
                onTap: () async {
                  final success = await widget.adminService.updateArticleStatus(articleId, !isPublished);
                  if (success && mounted) _loadData();
                },
              ),
            ),
          ),
          // Published Date
          Expanded(
            flex: 2,
            child: Text(
              _formatDate(article['published_at']),
              style: GoogleFonts.inter(fontSize: 13, color: AdminUi.textSecondary),
            ),
          ),
          // Created Date
          Expanded(
            flex: 2,
            child: Text(
              _formatDate(article['created_at']),
              style: GoogleFonts.inter(fontSize: 13, color: AdminUi.textMuted),
            ),
          ),
          // Actions
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _actionIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit Publication',
                  color: AdminUi.brand,
                  onTap: () async {
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (context) => CreateArticleDialog(
                        adminService: widget.adminService,
                        initialData: article,
                      ),
                    );
                    if (result == true && mounted) _loadData();
                  },
                ),
                const SizedBox(width: 4),
                _actionIconButton(
                  icon: isPublished ? Icons.visibility_off_outlined : Icons.publish_rounded,
                  tooltip: isPublished ? 'Unpublish' : 'Publish',
                  color: isPublished ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                  onTap: () async {
                    final success = await widget.adminService.updateArticleStatus(articleId, !isPublished);
                    if (success && mounted) _loadData();
                  },
                ),
                const SizedBox(width: 4),
                _actionIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Delete Publication',
                  color: AdminUi.danger,
                  onTap: () => _confirmDeleteArticle(articleId, article['title'] ?? 'this publication'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityTableRow(Map<String, dynamic> post) {
    final postId = post['post_id']?.toString() ?? '';
    final isPinned = post['is_pinned'] == true;
    final authorName = post['author_name'] ?? 'Anonymous';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Content
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post['title'] ?? 'Untitled Topic',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AdminUi.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  post['body'] ?? '',
                  style: GoogleFonts.inter(fontSize: 12, color: AdminUi.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Author
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AdminUi.brandSoft,
                  child: Text(
                    authorName.isNotEmpty ? authorName[0].toUpperCase() : 'U',
                    style: const TextStyle(fontSize: 10, color: AdminUi.brand, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    authorName,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AdminUi.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Engagement (Likes / Comments)
          Expanded(
            flex: 2,
            child: Row(
              children: [
                const Icon(Icons.thumb_up_alt_outlined, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text('${post['likes_count'] ?? 0}', style: GoogleFonts.inter(fontSize: 12, color: AdminUi.textSecondary)),
                const SizedBox(width: 14),
                const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text('${post['comments_count'] ?? 0}', style: GoogleFonts.inter(fontSize: 12, color: AdminUi.textSecondary)),
              ],
            ),
          ),
          // Priority / Pin
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: isPinned
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.push_pin_rounded, size: 12, color: Color(0xFFD97706)),
                          const SizedBox(width: 4),
                          Text(
                            'PINNED',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Text('Standard', style: GoogleFonts.inter(fontSize: 12, color: AdminUi.textMuted)),
            ),
          ),
          // Posted On
          Expanded(
            flex: 2,
            child: Text(
              _formatDate(post['created_at']),
              style: GoogleFonts.inter(fontSize: 13, color: AdminUi.textSecondary),
            ),
          ),
          // Actions
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _actionIconButton(
                  icon: isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  tooltip: isPinned ? 'Unpin topic' : 'Pin to top',
                  color: isPinned ? const Color(0xFFD97706) : AdminUi.textMuted,
                  onTap: () async {
                    final success = await widget.adminService.togglePinCommunityPost(postId, !isPinned);
                    if (success && mounted) _loadData();
                  },
                ),
                const SizedBox(width: 4),
                _actionIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Delete topic',
                  color: AdminUi.danger,
                  onTap: () => _confirmDeleteCommunityPost(postId, post['title'] ?? 'this topic'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // B. MAGAZINE GRID VIEW (Visual Cards)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildMagazineGridView(List<Map<String, dynamic>> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int crossAxisCount = width > 1100 ? 3 : (width > 650 ? 2 : 1);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: width > 1100 ? 0.95 : 1.05,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return _activeTab == 'Publications'
                ? _buildArticleMagazineCard(item)
                : _buildCommunityMagazineCard(item);
          },
        );
      },
    );
  }

  Widget _buildArticleMagazineCard(Map<String, dynamic> article) {
    final isPublished = article['is_published'] == true;
    final articleId = article['article_id']?.toString() ?? '';
    final audience = (article['audience'] ?? 'ALL').toString().toUpperCase();
    final category = article['category'] ?? 'Advisory';
    final coverUrl = article['cover_image_url'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Banner
          Stack(
            children: [
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AdminUi.brandDark,
                  image: coverUrl != null && coverUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(coverUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: coverUrl == null || coverUrl.isEmpty
                    ? Center(
                        child: Icon(Icons.eco_rounded, size: 40, color: Colors.white.withValues(alpha: 0.3)),
                      )
                    : null,
              ),
              // Audience Badge (Top Left)
              Positioned(
                top: 10,
                left: 10,
                child: _audienceBadge(audience, isFloating: true),
              ),
              // Status Badge (Top Right)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPublished ? const Color(0xFF059669) : const Color(0xFFD97706),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Text(
                    isPublished ? 'PUBLISHED' : 'DRAFT',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Content Details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        category.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AdminUi.brand,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        _formatDate(article['published_at'] ?? article['created_at']),
                        style: GoogleFonts.inter(fontSize: 11, color: AdminUi.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    article['title'] ?? 'Untitled Publication',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AdminUi.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      article['summary'] ?? 'No summary available.',
                      style: GoogleFonts.inter(fontSize: 12, color: AdminUi.textSecondary, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 8),
                  // Footer Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          final success = await widget.adminService.updateArticleStatus(articleId, !isPublished);
                          if (success && mounted) _loadData();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          foregroundColor: isPublished ? const Color(0xFFD97706) : const Color(0xFF059669),
                        ),
                        icon: Icon(
                          isPublished ? Icons.visibility_off_outlined : Icons.publish_rounded,
                          size: 14,
                        ),
                        label: Text(
                          isPublished ? 'Unpublish' : 'Publish',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: AdminUi.brand),
                            tooltip: 'Edit Article',
                            onPressed: () async {
                              final result = await showDialog<bool>(
                                context: context,
                                builder: (context) => CreateArticleDialog(
                                  adminService: widget.adminService,
                                  initialData: article,
                                ),
                              );
                              if (result == true && mounted) _loadData();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AdminUi.danger),
                            tooltip: 'Delete Article',
                            onPressed: () => _confirmDeleteArticle(articleId, article['title'] ?? 'this publication'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityMagazineCard(Map<String, dynamic> post) {
    final postId = post['post_id']?.toString() ?? '';
    final isPinned = post['is_pinned'] == true;
    final authorName = post['author_name'] ?? 'Anonymous';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AdminUi.brandSoft,
                    child: Text(
                      authorName.isNotEmpty ? authorName[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 10, color: AdminUi.brand, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    authorName,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AdminUi.textPrimary),
                  ),
                ],
              ),
              if (isPinned)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.push_pin_rounded, size: 11, color: Color(0xFFD97706)),
                      const SizedBox(width: 4),
                      Text('PINNED', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFD97706))),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post['title'] ?? 'Untitled Topic',
            style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: AdminUi.textPrimary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              post['body'] ?? '',
              style: GoogleFonts.inter(fontSize: 12, color: AdminUi.textSecondary, height: 1.4),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.thumb_up_alt_outlined, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text('${post['likes_count'] ?? 0}', style: GoogleFonts.inter(fontSize: 12, color: AdminUi.textSecondary)),
                  const SizedBox(width: 12),
                  const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text('${post['comments_count'] ?? 0}', style: GoogleFonts.inter(fontSize: 12, color: AdminUi.textSecondary)),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, size: 18, color: isPinned ? const Color(0xFFD97706) : AdminUi.textMuted),
                    tooltip: isPinned ? 'Unpin' : 'Pin to top',
                    onPressed: () async {
                      final success = await widget.adminService.togglePinCommunityPost(postId, !isPinned);
                      if (success && mounted) _loadData();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AdminUi.danger),
                    tooltip: 'Delete topic',
                    onPressed: () => _confirmDeleteCommunityPost(postId, post['title'] ?? 'this topic'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. HELPER COMPONENTS (Badges, Status Chips, Buttons)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _audienceBadge(String audience, {bool isFloating = false}) {
    Color bg;
    Color fg;
    String label;

    switch (audience) {
      case 'FARMER':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF065F46);
        label = 'FARMERS';
        break;
      case 'CUSTOMER':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        label = 'CUSTOMERS';
        break;
      default:
        bg = const Color(0xFFEEF2FF);
        fg = const Color(0xFF3730A3);
        label = 'ALL USERS';
        break;
    }

    if (isFloating) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: fg,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }

  Widget _statusChip({required bool isPublished, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isPublished ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isPublished ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isPublished ? const Color(0xFF059669) : const Color(0xFFD97706),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              isPublished ? 'PUBLISHED' : 'DRAFT',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isPublished ? const Color(0xFF065F46) : const Color(0xFF92400E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionIconButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. PAGINATION BAR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPaginationBar(BuildContext context) {
    final totalCount = _activeTab == 'Publications'
        ? (_articleStats['total'] ?? 0)
        : (_communityStats['total'] ?? 0);
    final startRange = totalCount == 0 ? 0 : (_currentPage * _pageSize) + 1;
    final endRange = ((_currentPage + 1) * _pageSize) > totalCount ? totalCount : ((_currentPage + 1) * _pageSize);
    final isMobile = MediaQuery.of(context).size.width < 700;

    final infoText = Text(
      totalCount > 0
          ? 'Showing $startRange–$endRange of $totalCount ${_activeTab.toLowerCase()}'
          : 'No entries available',
      style: GoogleFonts.inter(fontSize: 13, color: AdminUi.textSecondary),
    );

    final controlsRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(
          onPressed: _currentPage > 0
              ? () {
                  setState(() => _currentPage--);
                  _loadData();
                }
              : null,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: const Row(
            children: [
              Icon(Icons.chevron_left_rounded, size: 16),
              SizedBox(width: 4),
              Text('Previous'),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AdminUi.brandSoft,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Page ${_currentPage + 1}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AdminUi.brand,
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: endRange < totalCount
              ? () {
                  setState(() => _currentPage++);
                  _loadData();
                }
              : null,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: const Row(
            children: [
              Text('Next'),
              SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 16),
            ],
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                infoText,
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: controlsRow,
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                infoText,
                controlsRow,
              ],
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. EDITORIAL SPOTLIGHT & PERFORMANCE INSIGHTS FOOTER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildEditorialSpotlightAndInsights(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    final spotlightCard = Container(
      constraints: const BoxConstraints(minHeight: 200),
      decoration: BoxDecoration(
        color: AdminUi.brandDark,
        borderRadius: BorderRadius.circular(16),
        image: const DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1560493676-04071c5f467b?w=800'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Color(0x99000000), BlendMode.darken),
        ),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFBBF24)),
                    const SizedBox(width: 4),
                    Text(
                      'FEATURED SPOTLIGHT',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'ACTIVE FEED',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Organic Pest Management & Regenerative Farming',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Safe and biological crop protection techniques curated for local partner farmers.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );

    final insightCard = Container(
      constraints: const BoxConstraints(minHeight: 200),
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 16,
            offset: Offset(0, 4),
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
                  color: AdminUi.brandSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_graph_rounded, size: 20, color: AdminUi.brand),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Editorial Cadence & Recommendations',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AdminUi.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Farmer engagement is highest for weather advisories and organic pest control guides. Keep publications concise with direct actionable steps for maximum field adoption.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AdminUi.textSecondary,
              height: 1.5,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Review Content Strategy Guidelines',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AdminUi.brand,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded, size: 14, color: AdminUi.brand),
            ],
          ),
        ],
      ),
    );

    if (isMobile) {
      return Column(
        children: [
          spotlightCard,
          const SizedBox(height: 16),
          insightCard,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: spotlightCard),
        const SizedBox(width: 20),
        Expanded(child: insightCard),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. DIALOGS & CONFIRMATIONS
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _confirmDeleteArticle(String articleId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Delete Publication?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to delete "$title"? This action cannot be undone.', style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminUi.danger,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Delete Publication'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await widget.adminService.deleteArticle(articleId);
      if (success && mounted) _loadData();
    }
  }

  Future<void> _confirmDeleteCommunityPost(String postId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Delete Community Topic?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: Text('This will permanently delete "$title" and all associated comments.', style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminUi.danger,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Delete Topic'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await widget.adminService.deleteCommunityPost(postId);
      if (success && mounted) _loadData();
    }
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return '—';
    final str = dateVal.toString();
    if (str.length >= 10) return str.substring(0, 10);
    return str;
  }
}
