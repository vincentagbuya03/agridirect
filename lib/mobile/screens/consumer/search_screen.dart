import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/styles/app_theme.dart';
import '../auth/qr_scanner_screen.dart';
import 'search_results_screen.dart';

/// Modern AgriDirect Search Hub Screen - Designed for San Carlos City, Pangasinan
class SearchScreen extends StatefulWidget {
  final String initialQuery;
  const SearchScreen({super.key, this.initialQuery = ''});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const String _prefRecentSearchesKey = 'agridirect_recent_searches_v5';

  late TextEditingController _searchController;
  final FocusNode _searchFocus = FocusNode();

  List<String> _recentSearches = [];
  List<ProductItem> _liveCatalog = [];
  bool _isLoading = true;

  final List<String> _trendingKeywords = [
    'Carabao Mango',
    'Native Tomatoes',
    'Sweet Corn',
    'Organic Rice',
    'San Carlos Bangus',
    'Eggplant',
    'Red Onion',
    'Benguet Cabbage',
  ];

  final List<Map<String, String>> _fallbackSuggestions = [
    {
      'title': 'Carabao Mango',
      'category': 'Fresh Fruits',
      'farm': 'San Carlos Fruit Orchards',
      'price': '₱120/kg',
      'imageUrl':
          'https://images.unsplash.com/photo-1553279768-865429fa0078?auto=format&fit=crop&q=80&w=400',
    },
    {
      'title': 'Native Tomatoes',
      'category': 'Vegetables',
      'farm': 'Malacañang Organic Farm',
      'price': '₱45/kg',
      'imageUrl':
          'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?auto=format&fit=crop&q=80&w=400',
    },
    {
      'title': 'Organic Rice (Sinandomeng)',
      'category': 'Grains',
      'farm': 'Pulong Agri Cooperative',
      'price': '₱52/kg',
      'imageUrl':
          'https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&q=80&w=400',
    },
    {
      'title': 'Sweet Yellow Corn',
      'category': 'Vegetables',
      'farm': 'Magtaking Harvest Fields',
      'price': '₱35/kg',
      'imageUrl':
          'https://images.unsplash.com/photo-1551754655-cd27e38d2076?auto=format&fit=crop&q=80&w=400',
    },
    {
      'title': 'Benguet Cabbage',
      'category': 'Leafy Greens',
      'farm': 'Highland Agro Supply',
      'price': '₱60/kg',
      'imageUrl':
          'https://images.unsplash.com/photo-1594282486552-05b4d80fbb9f?auto=format&fit=crop&q=80&w=400',
    },
    {
      'title': 'Highland Broccoli',
      'category': 'Vegetables',
      'farm': 'Green Valley Growers',
      'price': '₱110/kg',
      'imageUrl':
          'https://images.unsplash.com/photo-1459411621453-7b03977f4bfc?auto=format&fit=crop&q=80&w=400',
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _loadRecentSearches();
    _loadCatalog();

    if (widget.initialQuery.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefRecentSearchesKey) ?? [];
      if (mounted) {
        setState(() {
          _recentSearches = list.isNotEmpty
              ? list
              : ['Carabao Mango', 'Native Tomatoes', 'Organic Rice', 'Sweet Corn'];
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _recentSearches = ['Carabao Mango', 'Native Tomatoes', 'Organic Rice', 'Sweet Corn'];
        });
      }
    }
  }

  Future<void> _saveRecentSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final updated = List<String>.from(_recentSearches);
    updated.removeWhere((item) => item.toLowerCase() == trimmed.toLowerCase());
    updated.insert(0, trimmed);
    if (updated.length > 10) updated.removeRange(10, updated.length);

    setState(() => _recentSearches = updated);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefRecentSearchesKey, updated);
    } catch (_) {}
  }

  Future<void> _removeRecentSearch(String item) async {
    final updated = List<String>.from(_recentSearches)..remove(item);
    setState(() => _recentSearches = updated);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefRecentSearchesKey, updated);
    } catch (_) {}
  }

  Future<void> _clearAllRecentSearches() async {
    setState(() => _recentSearches.clear());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefRecentSearchesKey);
    } catch (_) {}
  }

  Future<void> _loadCatalog() async {
    try {
      final products = await SupabaseDataService().getNearbyProducts();
      if (mounted) {
        setState(() {
          _liveCatalog = products.where((p) => p.imageUrl.isNotEmpty).take(8).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchSubmit(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    _saveRecentSearch(trimmed);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultsScreen(query: trimmed),
      ),
    );
  }

  Future<void> _openQRScanner() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const QRScannerScreen(
          title: 'Scan Produce / Farm QR',
          instruction: 'Scan QR code on produce crates or farm stalls',
        ),
      ),
    );

    if (result != null && result is String && result.isNotEmpty) {
      _onSearchSubmit(result);
    }
  }

  void _triggerVoiceSearch() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.mic_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Listening for crops (e.g. "Mango", "Rice", "Tomato")...',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildModernSearchHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. Recent Searches ──
                    if (_recentSearches.isNotEmpty) ...[
                      _buildRecentSearchesSection(),
                      const SizedBox(height: 24),
                    ],

                    // ── 2. Trending in San Carlos City ──
                    _buildTrendingSection(),
                    const SizedBox(height: 28),

                    // ── 3. Fresh Harvest Suggestions ──
                    _buildHarvestSuggestionsSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── UNIFIED MODERN SEARCH HEADER ──────────────────────────────────────────
  Widget _buildModernSearchHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textHeadline,
              size: 22,
            ),
            tooltip: 'Go back',
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _searchFocus.hasFocus
                      ? AppColors.primary
                      : const Color(0xFFE2E8F0),
                  width: _searchFocus.hasFocus ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(
                    Icons.search_rounded,
                    color: _searchFocus.hasFocus
                        ? AppColors.primary
                        : AppColors.textSubtle,
                    size: 21,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _onSearchSubmit,
                      onChanged: (_) => setState(() {}),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textHeadline,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Search fresh crops, farms, produce...',
                        hintStyle: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          Icons.cancel_rounded,
                          color: Color(0xFF94A3B8),
                          size: 18,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(
                      Icons.mic_rounded,
                      color: AppColors.textSubtle,
                      size: 20,
                    ),
                    tooltip: 'Voice Search',
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(),
                    onPressed: _triggerVoiceSearch,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    tooltip: 'Scan QR Code',
                    padding: const EdgeInsets.only(left: 4, right: 10),
                    constraints: const BoxConstraints(),
                    onPressed: _openQRScanner,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 1. RECENT SEARCHES SECTION ────────────────────────────────────────────
  Widget _buildRecentSearchesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  size: 19,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Recent Searches',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHeadline,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: _clearAllRecentSearches,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Clear all',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSubtle,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _recentSearches.map((s) {
            return InkWell(
              onTap: () => _onSearchSubmit(s),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 7, 8, 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textHeadline,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _removeRecentSearch(s),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── 2. TRENDING SECTION ───────────────────────────────────────────────────
  Widget _buildTrendingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.trending_up_rounded,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'Trending in San Carlos City',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textHeadline,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '🔥 Hot',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFD97706),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _trendingKeywords.map((tag) {
            return InkWell(
              onTap: () => _onSearchSubmit(tag),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.eco_rounded,
                      size: 13,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      tag,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── 3. FRESH HARVEST SUGGESTIONS SECTION ──────────────────────────────────
  Widget _buildHarvestSuggestionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.storefront_rounded,
                  size: 19,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Fresh Harvest Suggestions',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHeadline,
                  ),
                ),
              ],
            ),
            Text(
              'Direct from Farms',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.82,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: 4,
            itemBuilder: (context, index) => Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 12,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 10,
                          width: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.82,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _liveCatalog.isNotEmpty
                ? _liveCatalog.length
                : _fallbackSuggestions.length,
            itemBuilder: (context, index) {
              if (_liveCatalog.isNotEmpty) {
                final p = _liveCatalog[index];
                return _buildHarvestTile(
                  title: p.name,
                  farmName: p.farm.isNotEmpty ? p.farm : 'Verified Local Farm',
                  imageUrl: p.imageUrl,
                  price: p.price,
                  onTap: () => _onSearchSubmit(p.name),
                );
              } else {
                final item = _fallbackSuggestions[index];
                return _buildHarvestTile(
                  title: item['title']!,
                  farmName: item['farm'] ?? item['category']!,
                  imageUrl: item['imageUrl']!,
                  price: item['price'],
                  onTap: () => _onSearchSubmit(item['title']!),
                );
              }
            },
          ),
      ],
    );
  }

  // ── 4. MODERN SUGGESTION TILE ─────────────────────────────────────────────
  Widget _buildHarvestTile({
    required String title,
    required String farmName,
    required String imageUrl,
    String? price,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image with rounded top corners
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: const Color(0xFFF1F5F9)),
                      errorWidget: (_, _, _) => Container(
                        color: const Color(0xFFF1F5F9),
                        child: const Icon(
                          Icons.agriculture_rounded,
                          color: Color(0xFF94A3B8),
                          size: 24,
                        ),
                      ),
                    ),
                    if (price != null)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            price,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Text Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHeadline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Icons.store_rounded,
                        size: 12,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          farmName,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSubtle,
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
      ),
    );
  }
}
