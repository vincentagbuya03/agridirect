import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/web_design_tokens.dart';

/// 4-Pillar Trust & Value Proposition Strip for AgriDirect Web
class WebTrustBadgeStrip extends StatelessWidget {
  const WebTrustBadgeStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isCompact = sw < 1024;
    final isMobile = sw < 600;

    final pillars = [
      {
        'icon': Icons.agriculture_rounded,
        'title': '100% Farm-Direct',
        'subtitle': 'Zero middleman markups. Full payouts to local growers.',
        'color': WebDesignTokens.primary,
      },
      {
        'icon': Icons.local_shipping_outlined,
        'title': 'Guaranteed Fresh Delivery',
        'subtitle': 'Morning harvests dispatched direct to your doorstep.',
        'color': WebDesignTokens.primaryDark,
      },
      {
        'icon': Icons.verified_user_outlined,
        'title': 'Accredited Cooperatives',
        'subtitle': 'Inspected & certified Pangasinan farming partners.',
        'color': WebDesignTokens.trustBlue,
      },
      {
        'icon': Icons.verified_rounded,
        'title': 'Secure COD & Pick Up',
        'subtitle': 'Pay with Cash on Delivery or Cash on Pickup upon produce inspection.',
        'color': WebDesignTokens.dealAmber,
      },
    ];

    if (isMobile) {
      return Column(
        children: pillars.map((p) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildCard(p),
          );
        }).toList(),
      );
    }

    if (isCompact) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2.8,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: pillars.length,
        itemBuilder: (context, i) => _buildCard(pillars[i]),
      );
    }

    return Row(
      children: pillars.map((p) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _buildCard(p),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final Color iconColor = item['color'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: WebDesignTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WebDesignTokens.border),
        boxShadow: WebDesignTokens.cardRest,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item['icon'], color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item['title'],
                  style: GoogleFonts.rubik(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: WebDesignTokens.dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item['subtitle'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunitoSans(
                    fontSize: 11,
                    color: WebDesignTokens.slate500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
