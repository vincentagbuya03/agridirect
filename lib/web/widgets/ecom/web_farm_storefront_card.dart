import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../constants/web_design_tokens.dart';

/// Official Farmer Storefront Card for Web Product Details
class WebFarmStorefrontCard extends StatelessWidget {
  final String farmerName;
  final String farmName;
  final String barangay;
  final double rating;
  final String responseRate;
  final String soldKg;
  final String? avatarUrl;
  final VoidCallback onChat;
  final VoidCallback onVisitStore;

  const WebFarmStorefrontCard({
    super.key,
    required this.farmerName,
    required this.farmName,
    required this.barangay,
    required this.rating,
    required this.responseRate,
    required this.soldKg,
    this.avatarUrl,
    required this.onChat,
    required this.onVisitStore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WebDesignTokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WebDesignTokens.border),
        boxShadow: WebDesignTokens.cardRest,
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Avatar, Names, Verified Badge
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 54,
                  height: 54,
                  color: WebDesignTokens.primaryLight,
                  child: (avatarUrl != null && avatarUrl!.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, error, stackTrace) => const Icon(
                            Icons.agriculture_rounded,
                            color: WebDesignTokens.primaryDark,
                            size: 30,
                          ),
                        )
                      : const Icon(
                          Icons.agriculture_rounded,
                          color: WebDesignTokens.primaryDark,
                          size: 30,
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
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: WebDesignTokens.dark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded,
                            size: 16, color: WebDesignTokens.trustBlue),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$farmerName • $barangay',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunitoSans(
                        fontSize: 13,
                        color: WebDesignTokens.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 3 Metric Counters
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: WebDesignTokens.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: WebDesignTokens.border),
            ),
            child: Row(
              children: [
                _buildMetric(
                  icon: Icons.star_rounded,
                  iconColor: Colors.amber,
                  value: rating.toStringAsFixed(1),
                  label: 'Farm Rating',
                ),
                _buildMetricDivider(),
                _buildMetric(
                  icon: Icons.bolt_rounded,
                  iconColor: WebDesignTokens.dealAmber,
                  value: responseRate,
                  label: 'Chat Response',
                ),
                _buildMetricDivider(),
                _buildMetric(
                  icon: Icons.eco_rounded,
                  iconColor: WebDesignTokens.primary,
                  value: soldKg,
                  label: 'Harvests Sold',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: WebDesignTokens.primary.withValues(alpha: 0.8)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded,
                      size: 16, color: WebDesignTokens.primary),
                  label: Text(
                    'Chat Farmer',
                    style: GoogleFonts.rubik(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: WebDesignTokens.primary,
                    ),
                  ),
                  onPressed: onChat,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WebDesignTokens.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.storefront_rounded, size: 16),
                  label: Text(
                    'Visit Storefront',
                    style: GoogleFonts.rubik(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: onVisitStore,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 4),
              Text(
                value,
                style: GoogleFonts.rubik(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: WebDesignTokens.dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.nunitoSans(
              fontSize: 11,
              color: WebDesignTokens.slate500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricDivider() {
    return Container(
      height: 24,
      width: 1,
      color: WebDesignTokens.border,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
