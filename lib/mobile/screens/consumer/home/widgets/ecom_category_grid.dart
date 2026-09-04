import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../shared/data/app_data.dart';
import '../../../../../shared/services/core/supabase_data_service.dart';
import '../../../../../shared/styles/app_theme.dart';
import '../../../../../shared/widgets/app_shimmer_loader.dart';

/// 2-Row Shopee-style horizontal-scrolling category matrix for AgriDirect.
///
/// Strictly real-data driven: Directly consumes the active categories catalog
/// from the Supabase database.
class EcomCategoryGrid extends StatelessWidget {
  final Future<List<CategoryItem>> categoriesFuture;
  final void Function(String categoryName)? onCategorySelected;

  const EcomCategoryGrid({
    super.key,
    required this.categoriesFuture,
    this.onCategorySelected,
  });

  void _handleCategoryTap(BuildContext context, String categoryName) {
    if (onCategorySelected != null) {
      onCategorySelected!(categoryName);
      return;
    }
    // Default action: Navigate to Marketplace tab with category filter applied
    SupabaseDataService.marketplaceCategoryNotifier.value = categoryName;
    SupabaseDataService.navigationTabNotifier.value = 1;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CategoryItem>>(
      future: categoriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeletonLoader();
        }

        final categories = snapshot.data ?? [];
        if (categories.isEmpty) {
          return const SizedBox.shrink();
        }

        // Split into 2 rows for authentic e-commerce horizontal scroll
        final half = (categories.length / 2).ceil();
        final row1 = categories.sublist(0, half);
        final row2 = categories.sublist(half);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Categories',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      SupabaseDataService.marketplaceCategoryNotifier.value = null;
                      SupabaseDataService.navigationTabNotifier.value = 1;
                    },
                    child: Text(
                      'View All',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 176,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    // Row 1
                    Row(
                      children: row1.map((cat) => _buildCategoryItem(context, cat)).toList(),
                    ),
                    const SizedBox(height: 10),
                    // Row 2
                    Row(
                      children: row2.map((cat) => _buildCategoryItem(context, cat)).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryItem(BuildContext context, CategoryItem cat) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        onTap: () => _handleCategoryTap(context, cat.name),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 72,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(cat.bgColor),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Color(cat.iconColor).withValues(alpha: 0.15),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(cat.iconColor).withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    IconData(cat.iconCodePoint, fontFamily: 'MaterialIcons'),
                    color: Color(cat.iconColor),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                cat.name,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155),
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SizedBox(
        height: 160,
        child: Row(
          children: List.generate(
            5,
            (index) => const Padding(
              padding: EdgeInsets.only(right: 12),
              child: AppShimmerLoader(width: 60, height: 60),
            ),
          ),
        ),
      ),
    );
  }
}
