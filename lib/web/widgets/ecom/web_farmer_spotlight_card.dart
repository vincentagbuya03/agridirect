import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../constants/web_design_tokens.dart';

/// Featured Local Cooperative Spotlight Card for Web Marketplace
class WebFarmerSpotlightCard extends StatelessWidget {
  final String farmName;
  final String farmerName;
  final String barangay;
  final String rating;
  final int totalReviews;
  final String cropsSummary;
  final String? avatarUrl;
  final VoidCallback onVisit;

  const WebFarmerSpotlightCard({
    super.key,
    required this.farmName,
    required this.farmerName,
    required this.barangay,
    required this.rating,
    required this.totalReviews,
    required this.cropsSummary,
    this.avatarUrl,
    required this.onVisit,
  });

  @override
  Widget build(BuildContext context) {
    final ratingNum = double.tryParse(rating) ?? 0.0;
    final hasValidReviews = totalReviews > 0 && ratingNum > 0.0;
    final displayCrops = cropsSummary.trim().isNotEmpty
        ? cropsSummary
        : 'San Carlos Fresh Harvest';

    return Container(
      decoration: BoxDecoration(
        color: WebDesignTokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WebDesignTokens.border),
        boxShadow: WebDesignTokens.cardRest,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: WebDesignTokens.primaryLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: WebDesignTokens.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: (avatarUrl != null && avatarUrl!.trim().isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: WebDesignTokens.primary,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.agriculture_rounded,
                            color: WebDesignTokens.primaryDark,
                            size: 26,
                          ),
                        )
                      : const Icon(
                          Icons.agriculture_rounded,
                          color: WebDesignTokens.primaryDark,
                          size: 26,
                        ),
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
                            farmName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.rubik(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: WebDesignTokens.dark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded,
                            size: 15, color: WebDesignTokens.trustBlue),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Led by $farmerName • $barangay',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunitoSans(
                        fontSize: 12,
                        color: WebDesignTokens.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Rating & Crops
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: hasValidReviews
                      ? Colors.amber.withValues(alpha: 0.15)
                      : WebDesignTokens.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasValidReviews
                          ? Icons.star_rounded
                          : Icons.verified_rounded,
                      size: 14,
                      color: hasValidReviews
                          ? Colors.amber
                          : WebDesignTokens.primaryDark,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasValidReviews
                          ? '$rating ($totalReviews)'
                          : 'Verified Grower',
                      style: GoogleFonts.rubik(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: hasValidReviews
                            ? WebDesignTokens.dark
                            : WebDesignTokens.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayCrops,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: WebDesignTokens.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Action
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: WebDesignTokens.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.storefront_outlined,
                  size: 16, color: WebDesignTokens.primary),
              label: Text(
                'Visit Cooperative Store',
                style: GoogleFonts.rubik(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: WebDesignTokens.primary,
                ),
              ),
              onPressed: onVisit,
            ),
          ),
        ],
      ),
    );
  }
}
