import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../constants/web_design_tokens.dart';

/// Featured Local Cooperative Spotlight Card for Web Marketplace
class WebFarmerSpotlightCard extends StatefulWidget {
  final String farmName;
  final String farmerName;
  final String barangay;
  final String rating;
  final int totalReviews;
  final String cropsSummary;
  final String? avatarUrl;
  final String? coverUrl;
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
    this.coverUrl,
    required this.onVisit,
  });

  @override
  State<WebFarmerSpotlightCard> createState() => _WebFarmerSpotlightCardState();
}

class _WebFarmerSpotlightCardState extends State<WebFarmerSpotlightCard> {
  bool _isHovered = false;

  String _getFarmInitials(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return 'AG';
    final stopWords = {'ni', 'ng', 'sa', 'to', 'the', 'of', 'and', 'de', 'la'};
    final words = clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final significant = words.where((w) => !stopWords.contains(w.toLowerCase())).toList();

    if (significant.length >= 2) {
      return '${significant[0][0]}${significant[1][0]}'.toUpperCase();
    } else if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (clean.length >= 2) {
      return clean.substring(0, 2).toUpperCase();
    }
    return clean[0].toUpperCase();
  }

  Widget _buildDefaultBanner() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(
              Icons.agriculture_rounded,
              size: 80,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            left: 14,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_user_rounded, size: 12, color: Color(0xFF34D399)),
                  const SizedBox(width: 4),
                  Text(
                    'Accredited Cooperative',
                    style: GoogleFonts.rubik(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackLogo() {
    final initials = _getFarmInitials(widget.farmName);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: -6,
            bottom: -6,
            child: Icon(
              Icons.eco_rounded,
              size: 38,
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          Text(
            initials,
            style: GoogleFonts.rubik(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoWidget() {
    final hasAvatar = widget.avatarUrl != null && widget.avatarUrl!.trim().isNotEmpty;

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 3.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: hasAvatar
            ? CachedNetworkImage(
                imageUrl: widget.avatarUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: WebDesignTokens.primary,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => _buildFallbackLogo(),
              )
            : _buildFallbackLogo(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ratingNum = double.tryParse(widget.rating) ?? 0.0;
    final hasValidReviews = widget.totalReviews > 0 && ratingNum > 0.0;
    final displayCrops = widget.cropsSummary.trim().isNotEmpty
        ? widget.cropsSummary
        : 'San Carlos Fresh Harvest';

    final hasCover = widget.coverUrl != null && widget.coverUrl!.trim().isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onVisit,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
          decoration: BoxDecoration(
            color: WebDesignTokens.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _isHovered
                  ? WebDesignTokens.primary.withValues(alpha: 0.45)
                  : WebDesignTokens.border,
              width: _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: WebDesignTokens.primary.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : WebDesignTokens.cardRest,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ─── Consistent Banner Header (Taller Cover Photo) ───
              SizedBox(
                height: 130,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    hasCover
                        ? CachedNetworkImage(
                            imageUrl: widget.coverUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => _buildDefaultBanner(),
                          )
                        : _buildDefaultBanner(),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.35),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    if (hasCover)
                      Positioned(
                        top: 12,
                        right: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF34D399)),
                              const SizedBox(width: 4),
                              Text(
                                'Local Grower',
                                style: GoogleFonts.rubik(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ─── Card Body with Overlapping Prominent Logo ───
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Transform.translate(
                          offset: const Offset(0, -32),
                          child: _buildLogoWidget(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        widget.farmName,
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
                                    const Icon(
                                      Icons.verified_rounded,
                                      size: 16,
                                      color: WebDesignTokens.trustBlue,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Led by ${widget.farmerName} • ${widget.barangay}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.nunitoSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: WebDesignTokens.slate500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Rating & Crops row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                    ? '${widget.rating} (${widget.totalReviews})'
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

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: _isHovered
                                ? WebDesignTokens.primary
                                : WebDesignTokens.primary.withValues(alpha: 0.6),
                            width: _isHovered ? 1.5 : 1.0,
                          ),
                          backgroundColor: _isHovered
                              ? WebDesignTokens.primaryLight.withValues(alpha: 0.4)
                              : Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(
                          Icons.storefront_outlined,
                          size: 16,
                          color: WebDesignTokens.primary,
                        ),
                        label: Text(
                          'Visit Cooperative Store',
                          style: GoogleFonts.rubik(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: WebDesignTokens.primary,
                          ),
                        ),
                        onPressed: widget.onVisit,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
