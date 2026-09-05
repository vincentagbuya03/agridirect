import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../constants/web_design_tokens.dart';
import '../../widgets/web_footer.dart';
import '../../widgets/ecom/web_ecom_header.dart';
import '../../widgets/ecom/web_filter_sidebar.dart';
import '../../widgets/ecom/web_product_card.dart';

/// Flagship E-Commerce Produce Catalog & Shop Screen for AgriDirect Web
class WebShopScreen extends StatefulWidget {
  final Function(int) onNavigate;
  final int currentIndex;
  final bool initialShowPreOrders;
  final String? initialCategory;
  final String? initialSearchQuery;

  const WebShopScreen({
    super.key,
    required this.onNavigate,
    required this.currentIndex,
    this.initialShowPreOrders = false,
    this.initialCategory,
    this.initialSearchQuery,
  });

  @override
  State<WebShopScreen> createState() => _WebShopScreenState();
}

class _WebShopScreenState extends State<WebShopScreen> {
  final SupabaseDataService _dataService = SupabaseDataService();

  List<ProductItem> _allProducts = [];
  List<ProductItem> _filteredProducts = [];
  bool _isLoading = true;

  WebFilterState _filterState = const WebFilterState();
  String _selectedCategory = 'All';
  String _sortBy = 'Popularity';
  String _searchQuery = '';
  int _densityColumns = 4; // 3, 4, or 5
  int _currentPage = 1;
  final int _itemsPerPage = 16;

  final List<String> _categories = [
    'All',
    'Vegetables',
    'Fruits',
    'Grains',
    'Root Crops',
    'Organic',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    if (widget.initialSearchQuery != null) {
      _searchQuery = widget.initialSearchQuery!;
    }
    if (widget.initialShowPreOrders) {
      _filterState = _filterState.copyWith(wholesaleOnly: true);
    }
    _loadProducts();
  }

  @override
  void didUpdateWidget(covariant WebShopScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool shouldReapply = false;
    if (widget.initialCategory != null &&
        widget.initialCategory != _selectedCategory) {
      _selectedCategory = widget.initialCategory!;
      shouldReapply = true;
    }
    if (widget.initialSearchQuery != null &&
        widget.initialSearchQuery != _searchQuery) {
      _searchQuery = widget.initialSearchQuery!;
      shouldReapply = true;
    }
    if (shouldReapply) {
      _applyFilters();
    }
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final products = await _dataService.getNearbyProducts();
      if (mounted) {
        setState(() {
          _allProducts = products;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    List<ProductItem> results = List.from(_allProducts);

    // 1. Search Query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      results = results.where((p) {
        return p.name.toLowerCase().contains(q) ||
            p.farm.toLowerCase().contains(q) ||
            (p.farmerName?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    // 2. Category
    if (_selectedCategory != 'All') {
      results = results.where((p) {
        return (p.categoryName?.toLowerCase() ?? '') ==
            _selectedCategory.toLowerCase();
      }).toList();
    }

    // 3. Barangays
    if (_filterState.selectedBarangays.isNotEmpty) {
      results = results.where((p) {
        return _filterState.selectedBarangays.any((b) => p.farm.contains(b));
      }).toList();
    }

    // 4. Price Range
    results = results.where((p) {
      final price =
          double.tryParse(p.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
      return price >= _filterState.priceRange.start &&
          price <= _filterState.priceRange.end;
    }).toList();

    // 5. Flash Sale Only
    if (_filterState.flashSaleOnly) {
      results = results
          .where((p) =>
              p.isFlashSale ||
              (p.discountPercent != null && p.discountPercent! > 0))
          .toList();
    }

    // 6. Free Shipping
    if (_filterState.freeShippingOnly) {
      results = results.where((p) => p.isFreeShipping).toList();
    }

    // 7. Wholesale
    if (_filterState.wholesaleOnly) {
      results = results.where((p) => p.isWholesale || p.isPreorder).toList();
    }

    // 8. Sorting
    switch (_sortBy) {
      case 'Price: Low to High':
        results.sort((a, b) {
          final pa =
              double.tryParse(a.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
          final pb =
              double.tryParse(b.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
          return pa.compareTo(pb);
        });
        break;
      case 'Price: High to Low':
        results.sort((a, b) {
          final pa =
              double.tryParse(a.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
          final pb =
              double.tryParse(b.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
          return pb.compareTo(pa);
        });
        break;
      case 'Rating: High to Low':
        results.sort((a, b) {
          final ra = double.tryParse(a.rating ?? '0') ?? 0.0;
          final rb = double.tryParse(b.rating ?? '0') ?? 0.0;
          return rb.compareTo(ra);
        });
        break;
      case 'Popularity':
      default:
        results.sort((a, b) => (b.soldCount ?? 0).compareTo(a.soldCount ?? 0));
        break;
    }

    _filteredProducts = results;
    _currentPage = 1;
  }

  void _navigateToProduct(ProductItem product) {
    final prodId = product.productId ?? 'view';
    context.push(AppRoutes.product(prodId), extra: product);
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final containerWidth = WebBreakpoints.containerWidth(sw);
    final isCompact = sw < 1024;
    final isMobile = WebBreakpoints.isMobile(sw);

    final totalPages = (_filteredProducts.length / _itemsPerPage).ceil();
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage < _filteredProducts.length)
        ? startIndex + _itemsPerPage
        : _filteredProducts.length;
    final pagedItems = _filteredProducts.isEmpty
        ? <ProductItem>[]
        : _filteredProducts.sublist(startIndex, endIndex);

    return Scaffold(
      backgroundColor: WebDesignTokens.bg,
      body: Column(
        children: [
          // ─── Header ───
          WebEcomHeader(
            currentIndex: widget.currentIndex,
            onNavigate: (index, [route]) => widget.onNavigate(index),
            initialSearchQuery: _searchQuery,
            onSearch: (q) {
              setState(() {
                _searchQuery = q;
                _applyFilters();
              });
            },
          ),

          // ─── Catalog Body ───
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: containerWidth),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 12 : 24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ─── Breadcrumbs & Category Bar ───
                            _buildBreadcrumbBar(),
                            const SizedBox(height: 16),

                            // ─── Category Tabs Strip ───
                            _buildCategoryTabsStrip(),
                            const SizedBox(height: 20),

                            // ─── Toolbar (Results Count, Active Pills, Sorting, Density) ───
                            _buildToolbar(isMobile),
                            const SizedBox(height: 16),

                            // ─── Active Filter Pills ───
                            if (_filterState.hasActiveFilters ||
                                _selectedCategory != 'All' ||
                                _searchQuery.isNotEmpty) ...[
                              _buildActiveFilterChips(),
                              const SizedBox(height: 16),
                            ],

                            // ─── Main Grid + Sidebar ───
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Sidebar (Desktop only, drawer on mobile)
                                if (!isCompact) ...[
                                  WebFilterSidebar(
                                    state: _filterState,
                                    onChanged: (newState) {
                                      setState(() {
                                        _filterState = newState;
                                        _applyFilters();
                                      });
                                    },
                                    onReset: () {
                                      setState(() {
                                        _filterState = const WebFilterState();
                                        _selectedCategory = 'All';
                                        _searchQuery = '';
                                        _applyFilters();
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 24),
                                ],

                                // Products Catalog Area
                                Expanded(
                                  child: _isLoading
                                      ? const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(60.0),
                                            child: CircularProgressIndicator(
                                              color: WebDesignTokens.primary,
                                            ),
                                          ),
                                        )
                                      : pagedItems.isEmpty
                                          ? _buildEmptyState()
                                          : Column(
                                              children: [
                                                GridView.builder(
                                                  shrinkWrap: true,
                                                  physics:
                                                      const NeverScrollableScrollPhysics(),
                                                  gridDelegate:
                                                      SliverGridDelegateWithFixedCrossAxisCount(
                                                    crossAxisCount: isMobile
                                                        ? 2
                                                        : isCompact
                                                            ? 3
                                                            : _densityColumns,
                                                    childAspectRatio: 0.68,
                                                    crossAxisSpacing: 14,
                                                    mainAxisSpacing: 14,
                                                  ),
                                                  itemCount: pagedItems.length,
                                                  itemBuilder:
                                                      (context, index) {
                                                    final product =
                                                        pagedItems[index];
                                                    return WebProductCard(
                                                      product: product,
                                                      onTap: () =>
                                                          _navigateToProduct(
                                                              product),
                                                    );
                                                  },
                                                ),
                                                const SizedBox(height: 32),

                                                // Pagination Controls
                                                if (totalPages > 1)
                                                  _buildPagination(totalPages),
                                              ],
                                            ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 48),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Enterprise Footer
                  const AgriDirectWebFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbBar() {
    return Row(
      children: [
        InkWell(
          onTap: () => widget.onNavigate(0),
          child: Text(
            'Home',
            style: GoogleFonts.nunitoSans(
              fontSize: 13,
              color: WebDesignTokens.slate500,
            ),
          ),
        ),
        const Text('  /  ',
            style: TextStyle(color: WebDesignTokens.slate400, fontSize: 12)),
        Text(
          'Shop',
          style: GoogleFonts.nunitoSans(
            fontSize: 13,
            color: WebDesignTokens.slate500,
          ),
        ),
        if (_selectedCategory != 'All') ...[
          const Text('  /  ',
              style: TextStyle(color: WebDesignTokens.slate400, fontSize: 12)),
          Text(
            _selectedCategory,
            style: GoogleFonts.nunitoSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: WebDesignTokens.primaryDark,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryTabsStrip() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat),
              labelStyle: GoogleFonts.rubik(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : WebDesignTokens.dark,
              ),
              selected: isSelected,
              selectedColor: WebDesignTokens.primary,
              backgroundColor: WebDesignTokens.surface,
              side: BorderSide(
                color: isSelected
                    ? WebDesignTokens.primary
                    : WebDesignTokens.border,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              onSelected: (_) {
                setState(() {
                  _selectedCategory = cat;
                  _applyFilters();
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildToolbar(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: WebDesignTokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WebDesignTokens.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Results Count
          Text(
            'Showing ${_filteredProducts.isEmpty ? 0 : (_currentPage - 1) * _itemsPerPage + 1}–${_currentPage * _itemsPerPage > _filteredProducts.length ? _filteredProducts.length : _currentPage * _itemsPerPage} of ${_filteredProducts.length} harvests',
            style: GoogleFonts.nunitoSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: WebDesignTokens.slate600,
            ),
          ),

          // Sort Dropdown & Density Switcher
          Row(
            children: [
              Text(
                'Sort by: ',
                style: GoogleFonts.nunitoSans(
                  fontSize: 13,
                  color: WebDesignTokens.slate500,
                ),
              ),
              const SizedBox(width: 6),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _sortBy,
                  style: GoogleFonts.rubik(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: WebDesignTokens.dark,
                  ),
                  items: [
                    'Popularity',
                    'Rating: High to Low',
                    'Price: Low to High',
                    'Price: High to Low',
                  ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _sortBy = val;
                        _applyFilters();
                      });
                    }
                  },
                ),
              ),

              if (!isMobile) ...[
                const SizedBox(width: 16),
                // Density buttons
                IconButton(
                  tooltip: '4 Columns',
                  icon: Icon(
                    Icons.grid_view_rounded,
                    size: 20,
                    color: _densityColumns == 4
                        ? WebDesignTokens.primary
                        : WebDesignTokens.slate400,
                  ),
                  onPressed: () => setState(() => _densityColumns = 4),
                ),
                IconButton(
                  tooltip: '5 Columns',
                  icon: Icon(
                    Icons.view_comfy_rounded,
                    size: 20,
                    color: _densityColumns == 5
                        ? WebDesignTokens.primary
                        : WebDesignTokens.slate400,
                  ),
                  onPressed: () => setState(() => _densityColumns = 5),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_searchQuery.isNotEmpty)
          _buildPill('Search: "$_searchQuery"', () {
            setState(() {
              _searchQuery = '';
              _applyFilters();
            });
          }),
        if (_selectedCategory != 'All')
          _buildPill('Category: $_selectedCategory', () {
            setState(() {
              _selectedCategory = 'All';
              _applyFilters();
            });
          }),
        ..._filterState.selectedBarangays.map(
          (b) => _buildPill(b, () {
            final newSet = Set<String>.from(_filterState.selectedBarangays);
            newSet.remove(b);
            setState(() {
              _filterState = _filterState.copyWith(selectedBarangays: newSet);
              _applyFilters();
            });
          }),
        ),
        if (_filterState.flashSaleOnly)
          _buildPill('Flash Deals', () {
            setState(() {
              _filterState = _filterState.copyWith(flashSaleOnly: false);
              _applyFilters();
            });
          }),
        if (_filterState.freeShippingOnly)
          _buildPill('Free Shipping', () {
            setState(() {
              _filterState = _filterState.copyWith(freeShippingOnly: false);
              _applyFilters();
            });
          }),
        if (_filterState.wholesaleOnly)
          _buildPill('Wholesale', () {
            setState(() {
              _filterState = _filterState.copyWith(wholesaleOnly: false);
              _applyFilters();
            });
          }),
        InkWell(
          onTap: () {
            setState(() {
              _filterState = const WebFilterState();
              _selectedCategory = 'All';
              _searchQuery = '';
              _applyFilters();
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Text(
              'Clear All',
              style: GoogleFonts.nunitoSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: WebDesignTokens.discountRed,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPill(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: WebDesignTokens.primaryLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: WebDesignTokens.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.nunitoSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: WebDesignTokens.primaryDark,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded,
                size: 14, color: WebDesignTokens.primaryDark),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(60),
      decoration: BoxDecoration(
        color: WebDesignTokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WebDesignTokens.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded,
              size: 56, color: WebDesignTokens.slate400),
          const SizedBox(height: 16),
          Text(
            'No Produce Matches Your Filters',
            style: GoogleFonts.rubik(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: WebDesignTokens.dark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try widening your price range or clearing barangay selection.',
            style: GoogleFonts.nunitoSans(
              fontSize: 13,
              color: WebDesignTokens.slate500,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: WebDesignTokens.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              setState(() {
                _filterState = const WebFilterState();
                _selectedCategory = 'All';
                _searchQuery = '';
                _applyFilters();
              });
            },
            child: const Text('Reset All Filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination(int totalPages) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
          onPressed: _currentPage > 1
              ? () => setState(() => _currentPage--)
              : null,
        ),
        ...List.generate(totalPages, (i) {
          final pageNum = i + 1;
          final isCurrent = _currentPage == pageNum;

          return InkWell(
            onTap: () => setState(() => _currentPage = pageNum),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isCurrent
                    ? WebDesignTokens.primary
                    : WebDesignTokens.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCurrent
                      ? WebDesignTokens.primary
                      : WebDesignTokens.border,
                ),
              ),
              child: Text(
                '$pageNum',
                style: GoogleFonts.rubik(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isCurrent ? Colors.white : WebDesignTokens.dark,
                ),
              ),
            ),
          );
        }),
        IconButton(
          icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          onPressed: _currentPage < totalPages
              ? () => setState(() => _currentPage++)
              : null,
        ),
      ],
    );
  }
}
