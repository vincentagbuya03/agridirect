import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/web_design_tokens.dart';

/// Faceted Filter State Data Object
class WebFilterState {
  final Set<String> selectedBarangays;
  final String harvestTiming; // 'All', 'Today', '48h', 'Preorder'
  final Set<String> farmingMethods; // 'Organic', 'GAP', 'Hydroponic'
  final RangeValues priceRange;
  final double minRating;
  final bool verifiedOnly;
  final bool flashSaleOnly;
  final bool freeShippingOnly;
  final bool wholesaleOnly;

  const WebFilterState({
    this.selectedBarangays = const {},
    this.harvestTiming = 'All',
    this.farmingMethods = const {},
    this.priceRange = const RangeValues(0, 500),
    this.minRating = 0.0,
    this.verifiedOnly = false,
    this.flashSaleOnly = false,
    this.freeShippingOnly = false,
    this.wholesaleOnly = false,
  });

  bool get hasActiveFilters =>
      selectedBarangays.isNotEmpty ||
      harvestTiming != 'All' ||
      farmingMethods.isNotEmpty ||
      priceRange.start > 0 ||
      priceRange.end < 500 ||
      minRating > 0.0 ||
      verifiedOnly ||
      flashSaleOnly ||
      freeShippingOnly ||
      wholesaleOnly;

  int get activeFiltersCount {
    int count = 0;
    if (selectedBarangays.isNotEmpty) count += selectedBarangays.length;
    if (harvestTiming != 'All') count++;
    if (farmingMethods.isNotEmpty) count += farmingMethods.length;
    if (priceRange.start > 0 || priceRange.end < 500) count++;
    if (minRating > 0.0) count++;
    if (verifiedOnly) count++;
    if (flashSaleOnly) count++;
    if (freeShippingOnly) count++;
    if (wholesaleOnly) count++;
    return count;
  }

  WebFilterState copyWith({
    Set<String>? selectedBarangays,
    String? harvestTiming,
    Set<String>? farmingMethods,
    RangeValues? priceRange,
    double? minRating,
    bool? verifiedOnly,
    bool? flashSaleOnly,
    bool? freeShippingOnly,
    bool? wholesaleOnly,
  }) {
    return WebFilterState(
      selectedBarangays: selectedBarangays ?? this.selectedBarangays,
      harvestTiming: harvestTiming ?? this.harvestTiming,
      farmingMethods: farmingMethods ?? this.farmingMethods,
      priceRange: priceRange ?? this.priceRange,
      minRating: minRating ?? this.minRating,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      flashSaleOnly: flashSaleOnly ?? this.flashSaleOnly,
      freeShippingOnly: freeShippingOnly ?? this.freeShippingOnly,
      wholesaleOnly: wholesaleOnly ?? this.wholesaleOnly,
    );
  }
}

/// Amazon/Shopee-Style Faceted Filter Sidebar for Web Produce Marketplace
class WebFilterSidebar extends StatefulWidget {
  final WebFilterState state;
  final ValueChanged<WebFilterState> onChanged;
  final VoidCallback onReset;

  const WebFilterSidebar({
    super.key,
    required this.state,
    required this.onChanged,
    required this.onReset,
  });

  @override
  State<WebFilterSidebar> createState() => _WebFilterSidebarState();
}

class _WebFilterSidebarState extends State<WebFilterSidebar> {
  final TextEditingController _barangaySearch = TextEditingController();
  final TextEditingController _minPriceCtrl = TextEditingController();
  final TextEditingController _maxPriceCtrl = TextEditingController();

  static const List<String> _barangays = [
    'Brgy. Roxas',
    'Brgy. Baleyadaan',
    'Brgy. Tarece',
    'Brgy. Malabago',
    'Brgy. Talence',
    'Brgy. Tandoc',
    'Brgy. Pagal',
    'Brgy. Palaming',
    'Brgy. Ilang',
  ];

  @override
  void initState() {
    super.initState();
    _minPriceCtrl.text = widget.state.priceRange.start.toInt().toString();
    _maxPriceCtrl.text = widget.state.priceRange.end.toInt().toString();
  }

  @override
  void dispose() {
    _barangaySearch.dispose();
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = widget.state.activeFiltersCount;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: WebDesignTokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WebDesignTokens.border),
        boxShadow: WebDesignTokens.cardRest,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Reset
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.filter_list_rounded,
                      size: 20, color: WebDesignTokens.primaryDark),
                  const SizedBox(width: 8),
                  Text(
                    'Filters',
                    style: GoogleFonts.rubik(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: WebDesignTokens.dark,
                    ),
                  ),
                  if (activeCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: WebDesignTokens.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$activeCount',
                        style: GoogleFonts.rubik(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (activeCount > 0)
                TextButton(
                  onPressed: widget.onReset,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Reset All',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: WebDesignTokens.discountRed,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 24, color: WebDesignTokens.border),

          // ─── 1. Barangay & Location ───
          _buildSectionTitle('San Carlos Barangays'),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: ListView(
              shrinkWrap: true,
              children: _barangays.map((b) {
                final isChecked = widget.state.selectedBarangays.contains(b);
                return CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: WebDesignTokens.primary,
                  title: Text(
                    b,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 13,
                      fontWeight:
                          isChecked ? FontWeight.w700 : FontWeight.w500,
                      color: isChecked
                          ? WebDesignTokens.primaryDark
                          : WebDesignTokens.dark,
                    ),
                  ),
                  value: isChecked,
                  onChanged: (val) {
                    final newSet = Set<String>.from(widget.state.selectedBarangays);
                    if (val == true) {
                      newSet.add(b);
                    } else {
                      newSet.remove(b);
                    }
                    widget.onChanged(widget.state.copyWith(selectedBarangays: newSet));
                  },
                );
              }).toList(),
            ),
          ),
          const Divider(height: 24, color: WebDesignTokens.border),

          // ─── 2. Price Range (₱) ───
          _buildSectionTitle('Price Range (₱)'),
          const SizedBox(height: 4),
          RangeSlider(
            values: widget.state.priceRange,
            min: 0,
            max: 500,
            divisions: 50,
            activeColor: WebDesignTokens.primary,
            inactiveColor: WebDesignTokens.bg,
            labels: RangeLabels(
              '₱${widget.state.priceRange.start.toInt()}',
              '₱${widget.state.priceRange.end.toInt()}',
            ),
            onChanged: (RangeValues values) {
              widget.onChanged(widget.state.copyWith(priceRange: values));
              _minPriceCtrl.text = values.start.toInt().toString();
              _maxPriceCtrl.text = values.end.toInt().toString();
            },
          ),
          Row(
            children: [
              Expanded(
                child: _buildPriceInput(
                  controller: _minPriceCtrl,
                  label: 'Min ₱',
                  onSubmitted: (val) {
                    final d = double.tryParse(val) ?? 0.0;
                    widget.onChanged(widget.state.copyWith(
                      priceRange: RangeValues(d, widget.state.priceRange.end),
                    ));
                  },
                ),
              ),
              const SizedBox(width: 8),
              const Text('–', style: TextStyle(color: WebDesignTokens.slate400)),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPriceInput(
                  controller: _maxPriceCtrl,
                  label: 'Max ₱',
                  onSubmitted: (val) {
                    final d = double.tryParse(val) ?? 500.0;
                    widget.onChanged(widget.state.copyWith(
                      priceRange: RangeValues(widget.state.priceRange.start, d),
                    ));
                  },
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: WebDesignTokens.border),

          // ─── 3. Farming Practice & Certification ───
          _buildSectionTitle('Farming Method'),
          const SizedBox(height: 6),
          ...['Organic', 'GAP-Certified', 'Hydroponic'].map((method) {
            final isChecked = widget.state.farmingMethods.contains(method);
            return CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: WebDesignTokens.primary,
              title: Text(
                method,
                style: GoogleFonts.nunitoSans(
                  fontSize: 13,
                  fontWeight: isChecked ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              value: isChecked,
              onChanged: (val) {
                final newSet = Set<String>.from(widget.state.farmingMethods);
                if (val == true) {
                  newSet.add(method);
                } else {
                  newSet.remove(method);
                }
                widget.onChanged(widget.state.copyWith(farmingMethods: newSet));
              },
            );
          }),
          const Divider(height: 24, color: WebDesignTokens.border),

          // ─── 4. Deals & Special Programs ───
          _buildSectionTitle('Programs & Deals'),
          const SizedBox(height: 6),
          _buildSwitchTile(
            title: '⚡ On Flash Sale',
            value: widget.state.flashSaleOnly,
            onChanged: (val) =>
                widget.onChanged(widget.state.copyWith(flashSaleOnly: val)),
          ),
          _buildSwitchTile(
            title: '🚚 Free Shipping Eligible',
            value: widget.state.freeShippingOnly,
            onChanged: (val) =>
                widget.onChanged(widget.state.copyWith(freeShippingOnly: val)),
          ),
          _buildSwitchTile(
            title: '📦 Wholesale / Bulk Sacks',
            value: widget.state.wholesaleOnly,
            onChanged: (val) =>
                widget.onChanged(widget.state.copyWith(wholesaleOnly: val)),
          ),
          _buildSwitchTile(
            title: '⭐ Verified Farmers Only',
            value: widget.state.verifiedOnly,
            onChanged: (val) =>
                widget.onChanged(widget.state.copyWith(verifiedOnly: val)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.rubik(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: WebDesignTokens.dark,
      ),
    );
  }

  Widget _buildPriceInput({
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onSubmitted,
  }) {
    return SizedBox(
      height: 36,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: GoogleFonts.rubik(fontSize: 12, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.nunitoSans(fontSize: 11),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: WebDesignTokens.border),
          ),
        ),
        onSubmitted: onSubmitted,
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.nunitoSans(
              fontSize: 13,
              fontWeight: value ? FontWeight.w700 : FontWeight.w500,
              color: value ? WebDesignTokens.primaryDark : WebDesignTokens.dark,
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: WebDesignTokens.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
