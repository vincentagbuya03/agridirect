import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/services/articles/articles_service.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../widgets/animated_components.dart';
import '../../widgets/web_footer.dart';

class DAArticleData {
  final String id;
  final String title;
  final String date;
  final String category;
  final String imageUrl;
  final String summary;
  final List<String> paragraphs;
  final List<String> recommendations;
  final String author;
  final String source;

  const DAArticleData({
    required this.id,
    required this.title,
    required this.date,
    required this.category,
    required this.imageUrl,
    required this.summary,
    required this.paragraphs,
    required this.recommendations,
    required this.author,
    this.source = 'Department of Agriculture (DA) Bureau of Agricultural Research & Field Operations',
  });
}

class WebArticlesScreen extends StatefulWidget {
  final String? initialArticleId;
  const WebArticlesScreen({super.key, this.initialArticleId});

  @override
  State<WebArticlesScreen> createState() => _WebArticlesScreenState();
}

class _WebArticlesScreenState extends State<WebArticlesScreen> {
  String _selectedCategory = 'All Articles';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  DAArticleData? _activeArticle;
  List<DAArticleData> _dynamicArticles = [];
  bool _isLoading = true;

  final List<String> _categories = [
    'All Articles',
    'DA Advisories',
    'Livestock & Fodder',
    'Crop Protection',
    'Smart AgTech & Fencing',
    'Soil & Fertilizer',
  ];

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  Future<void> _loadArticles() async {
    setState(() => _isLoading = true);
    try {
      final list = await ArticlesService().getPublishedArticles();
      if (mounted) {
        setState(() {
          _dynamicArticles = list;
          _isLoading = false;
          if (widget.initialArticleId != null) {
            _activeArticle = list.firstWhere(
              (a) => a.id == widget.initialArticleId,
              orElse: () => list.first,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    final filtered = _dynamicArticles.where((article) {
      final matchesCat = _selectedCategory == 'All Articles' || article.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          article.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          article.summary.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildTopNav(isMobile),
            if (_activeArticle != null)
              _buildArticleDetailView(_activeArticle!, isMobile)
            else
              _buildArticlesListView(filtered, isMobile),
            const AgriDirectWebFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopNav(bool isMobile) {
    final isFarmerMode = AuthService().isViewingAsFarmer;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 48,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1300),
          child: Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => context.go(isFarmerMode ? AppRoutes.farmerDashboard : '/'),
                  child: BrandLogo(size: isMobile ? BrandLogoSize.small : BrandLogoSize.medium),
                ),
              ),
              const Spacer(),
              if (!isMobile) ...[
                if (isFarmerMode) ...[
                  TextButton(
                    onPressed: () => context.go(AppRoutes.farmerDashboard),
                    child: Text('Dashboard', style: GoogleFonts.inter(color: AgriColors.dark, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.community),
                    child: Text('Community', style: GoogleFonts.inter(color: AgriColors.dark, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _activeArticle = null;
                        _selectedCategory = 'All Articles';
                      });
                    },
                    child: Text('DA Articles', style: GoogleFonts.inter(color: AgriColors.emerald700, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.farmersMap),
                    child: Text('Find Farmer', style: GoogleFonts.inter(color: AgriColors.dark, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.weatherRadar),
                    child: Text('Weather', style: GoogleFonts.inter(color: AgriColors.dark, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 14),
                ] else ...[
                  TextButton(
                    onPressed: () => context.go('/'),
                    child: Text('Home', style: GoogleFonts.inter(color: AgriColors.dark, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.shop),
                    child: Text('Shop', style: GoogleFonts.inter(color: AgriColors.dark, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.community),
                    child: Text('Community', style: GoogleFonts.inter(color: AgriColors.dark, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _activeArticle = null;
                        _selectedCategory = 'All Articles';
                      });
                    },
                    child: Text('DA Articles', style: GoogleFonts.inter(color: AgriColors.emerald700, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.aboutUs),
                    child: Text('About Us', style: GoogleFonts.inter(color: AgriColors.dark, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.farmersMap),
                    child: Text('Find Farmer', style: GoogleFonts.inter(color: AgriColors.dark, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.weatherRadar),
                    child: Text('Weather', style: GoogleFonts.inter(color: AgriColors.dark, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 14),
                ],
              ],
              ElevatedButton.icon(
                onPressed: () {
                  if (isFarmerMode) {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(AppRoutes.farmerDashboard);
                    }
                  } else {
                    context.go(AppRoutes.marketplace);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF005A36),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                icon: Icon(
                  isFarmerMode ? Icons.dashboard_rounded : Icons.storefront_rounded,
                  size: 16,
                ),
                label: Text(
                  isFarmerMode ? 'Dashboard' : 'Marketplace',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArticlesListView(List<DAArticleData> articles, bool isMobile) {
    final isFarmerMode = AuthService().isViewingAsFarmer;

    return Container(
      color: const Color(0xFFFBFDFB),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 48,
        vertical: isMobile ? 28 : 48,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Breadcrumbs
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go(isFarmerMode ? AppRoutes.farmerDashboard : '/'),
                    child: Text(
                      isFarmerMode ? 'Farmer Dashboard' : 'Home',
                      style: GoogleFonts.inter(fontSize: 13, color: AgriColors.muted, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('>', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                  Text('DA Articles & Farming Blog', style: GoogleFonts.inter(fontSize: 13, color: AgriColors.emerald800, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 24),

              // Hero Banner with Title & Search
              Container(
                padding: EdgeInsets.all(isMobile ? 24 : 36),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF005A36), Color(0xFF044E38)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF005A36).withValues(alpha: 0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AgriColors.gold400.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AgriColors.gold400.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded, color: AgriColors.gold300, size: 14),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'DEPARTMENT OF AGRICULTURE (DA) KNOWLEDGE HUB',
                              style: GoogleFonts.inter(
                                color: AgriColors.gold200,
                                fontSize: isMobile ? 9.5 : 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: isMobile ? 0.4 : 1.0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'All Agricultural Articles & Technical Bulletins',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: isMobile ? 26 : 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Evidence-based farming guides, livestock advisories, seasonal planting tips, and sustainable market practices directly from certified agronomists and the Department of Agriculture.',
                      style: GoogleFonts.inter(
                        fontSize: isMobile ? 13 : 15,
                        color: Colors.white.withValues(alpha: 0.8),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Search bar
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Search articles, topics, pests, or techniques...',
                          hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 14),
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF005A36)),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Category Filter Pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
                    final isSel = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSel,
                        selectedColor: const Color(0xFF005A36),
                        backgroundColor: Colors.white,
                        labelStyle: GoogleFonts.inter(
                          color: isSel ? Colors.white : const Color(0xFF334155),
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSel ? const Color(0xFF005A36) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedCategory = cat);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 32),

              // Articles Grid
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF005A36)),
                  ),
                )
              else if (articles.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.menu_book_rounded, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No articles found',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AgriColors.dark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Try searching for another topic or resetting category filter.',
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth < 650
                        ? 1
                        : constraints.maxWidth < 1000
                            ? 2
                            : 4;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 28,
                        childAspectRatio: crossAxisCount == 1 ? 1.05 : 0.72,
                      ),
                      itemCount: articles.length,
                      itemBuilder: (context, index) {
                        final item = articles[index];
                        return _buildArticleCard(item);
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArticleCard(DAArticleData item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.network(
                    item.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFF005A36),
                      child: const Center(
                        child: Icon(Icons.agriculture_rounded, color: Colors.white24, size: 40),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF005A36).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.category,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF005A36),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.date,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        item.summary,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: const Color(0xFF64748B),
                          height: 1.45,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _activeArticle = item;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF005A36),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Text(
                          'Read more',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
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
      ),
    );
  }

  Widget _buildArticleDetailView(DAArticleData item, bool isMobile) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 48,
        vertical: isMobile ? 24 : 40,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back link & Breadcrumbs
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _activeArticle = null),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_back_rounded, size: 18, color: Color(0xFF005A36)),
                        const SizedBox(width: 6),
                        Text(
                          'Back to All Articles',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF005A36),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Category & Date Badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF005A36),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.category,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    item.date,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                item.title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isMobile ? 26 : 38,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),

              // Author & Source
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_rounded, color: Color(0xFF005A36), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.author,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: const Color(0xFF064E3B),
                            ),
                          ),
                          Text(
                            item.source,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Featured image
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    item.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(color: const Color(0xFF005A36)),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Content paragraphs
              ...item.paragraphs.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    p,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: const Color(0xFF334155),
                      height: 1.8,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Recommendations Box
              if (item.recommendations.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEFCE8),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFFEF08A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.eco_rounded, color: Color(0xFFCA8A04), size: 22),
                          const SizedBox(width: 10),
                          Text(
                            'Key Technical Recommendations from the DA',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF854D0E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...item.recommendations.map(
                        (rec) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFFCA8A04), size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  rec,
                                  style: GoogleFonts.inter(
                                    fontSize: 14.5,
                                    color: const Color(0xFF713F12),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 48),

              // Bottom back action
              Center(
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _activeArticle = null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF005A36),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text('Back to Articles List', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

