import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/web_design_tokens.dart';

/// Modal dialog for choosing a delivery Barangay in San Carlos City, Pangasinan
class WebLocationModal extends StatefulWidget {
  final String currentLocation;
  final ValueChanged<String> onLocationSelected;

  const WebLocationModal({
    super.key,
    required this.currentLocation,
    required this.onLocationSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required String currentLocation,
    required ValueChanged<String> onLocationSelected,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => WebLocationModal(
        currentLocation: currentLocation,
        onLocationSelected: onLocationSelected,
      ),
    );
  }

  @override
  State<WebLocationModal> createState() => _WebLocationModalState();
}

class _WebLocationModalState extends State<WebLocationModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  late String _selected;

  // Key agricultural and residential Barangays in San Carlos City, Pangasinan
  static const List<String> _sanCarlosBarangays = [
    'Brgy. Roxas (Organic Farm Hub)',
    'Brgy. Baleyadaan (Root Crops & Corn)',
    'Brgy. Tarece (Lowland Veggies)',
    'Brgy. Malabago (Fruit Orchards)',
    'Brgy. Talence (Leafy Greens & Herbs)',
    'Brgy. Tandoc (Highland Veggies)',
    'Brgy. Pagal (Rice Terraces)',
    'Brgy. Palaming (Vegetable Fields)',
    'Brgy. Ilang (Hydroponic Hub)',
    'Brgy. Perez (Cooperative Center)',
    'Brgy. Bogaoan (Corn & Grain)',
    'Brgy. Caoayan-Kiling (Farm Direct)',
    'Brgy. Poblacion (Town Proper Market)',
  ];

  List<String> _filteredBarangays = [];

  @override
  void initState() {
    super.initState();
    _selected = widget.currentLocation;
    _filteredBarangays = List.from(_sanCarlosBarangays);
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredBarangays = List.from(_sanCarlosBarangays);
      } else {
        _filteredBarangays = _sanCarlosBarangays
            .where((b) => b.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: WebDesignTokens.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: WebDesignTokens.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.location_on_rounded,
                            color: WebDesignTokens.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose Delivery Location',
                            style: GoogleFonts.rubik(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: WebDesignTokens.dark,
                            ),
                          ),
                          Text(
                            'San Carlos City, Pangasinan',
                            style: GoogleFonts.nunitoSans(
                              fontSize: 13,
                              color: WebDesignTokens.slate500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: WebDesignTokens.slate400),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Search Box
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search barangay or cooperative...',
                  hintStyle: GoogleFonts.nunitoSans(
                    color: WebDesignTokens.slate400,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: WebDesignTokens.slate400),
                  filled: true,
                  fillColor: WebDesignTokens.bg,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: WebDesignTokens.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: WebDesignTokens.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: WebDesignTokens.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // List of Barangays
              Expanded(
                child: ListView.separated(
                  itemCount: _filteredBarangays.length,
                  separatorBuilder: (_, index) => Divider(
                    height: 1,
                    color: WebDesignTokens.border.withValues(alpha: 0.6),
                  ),
                  itemBuilder: (context, index) {
                    final item = _filteredBarangays[index];
                    final isChecked = item.contains(_selected) || _selected.contains(item.split(' ')[0]);

                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      leading: Icon(
                        isChecked
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: isChecked
                            ? WebDesignTokens.primary
                            : WebDesignTokens.slate400,
                        size: 20,
                      ),
                      title: Text(
                        item,
                        style: GoogleFonts.nunitoSans(
                          fontSize: 14,
                          fontWeight:
                              isChecked ? FontWeight.w700 : FontWeight.w500,
                          color: isChecked
                              ? WebDesignTokens.primary
                              : WebDesignTokens.dark,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: WebDesignTokens.bg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Same-Day',
                          style: GoogleFonts.rubik(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: WebDesignTokens.primary,
                          ),
                        ),
                      ),
                      onTap: () {
                        final simplified = item.split(' (')[0];
                        widget.onLocationSelected(simplified);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
