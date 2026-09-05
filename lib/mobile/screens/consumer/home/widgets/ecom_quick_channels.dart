import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../free_shipping_screen.dart';
import '../../flash_sale_screen.dart';
import '../../vouchers_screen.dart';
import '../../wholesale_screen.dart';
import '../../fresh_produce_screen.dart';
import '../../local_shops_screen.dart';
import '../../more_actions_bottom_sheet.dart';
import '../../../../../shared/services/core/supabase_data_service.dart';

/// Shopee/Lazada-style Service Channels & Shortcuts bar for AgriDirect.
///
/// Houses direct entrance buttons to Free Shipping, Flash Deals, Vouchers,
/// Wholesale B2B, Fresh Produce, Local Farm Shops, Pre-Orders, and More.
class EcomQuickChannels extends StatelessWidget {
  const EcomQuickChannels({super.key});

  static const List<Map<String, dynamic>> _channels = [
    {
      'id': 'free_shipping',
      'label': 'Free Shipping',
      'badge': 'FREE',
      'icon': Icons.local_shipping_rounded,
      'gradient': [Color(0xFF059669), Color(0xFF10B981)],
      'badgeColor': Color(0xFF047857),
    },
    {
      'id': 'flash_sale',
      'label': 'Flash Deals',
      'badge': '🔥 HOT',
      'icon': Icons.flash_on_rounded,
      'gradient': [Color(0xFFEA580C), Color(0xFFF97316)],
      'badgeColor': Color(0xFFC2410C),
    },
    {
      'id': 'vouchers',
      'label': 'Vouchers',
      'badge': 'CLAIM',
      'icon': Icons.card_giftcard_rounded,
      'gradient': [Color(0xFFD97706), Color(0xFFFBBF24)],
      'badgeColor': Color(0xFFB45309),
    },
    {
      'id': 'wholesale',
      'label': 'Wholesale',
      'badge': 'BULK',
      'icon': Icons.inventory_2_rounded,
      'gradient': [Color(0xFF2563EB), Color(0xFF60A5FA)],
      'badgeColor': Color(0xFF1D4ED8),
    },
    {
      'id': 'fresh_produce',
      'label': 'Fresh Crops',
      'badge': 'HARVEST',
      'icon': Icons.eco_rounded,
      'gradient': [Color(0xFF0D9488), Color(0xFF14B8A6)],
      'badgeColor': Color(0xFF0F766E),
    },
    {
      'id': 'local_shops',
      'label': 'Local Farms',
      'badge': 'VERIFIED',
      'icon': Icons.storefront_rounded,
      'gradient': [Color(0xFF7C3AED), Color(0xFFA78BFA)],
      'badgeColor': Color(0xFF6D28D9),
    },
    {
      'id': 'preorders',
      'label': 'Pre-Orders',
      'badge': 'FUTURE',
      'icon': Icons.timer_rounded,
      'gradient': [Color(0xFF0284C7), Color(0xFF38BDF8)],
      'badgeColor': Color(0xFF0369A1),
    },
    {
      'id': 'more',
      'label': 'More',
      'badge': null,
      'icon': Icons.apps_rounded,
      'gradient': [Color(0xFF475569), Color(0xFF64748B)],
      'badgeColor': Color(0xFF334155),
    },
  ];

  void _onChannelTap(BuildContext context, String id) {
    switch (id) {
      case 'free_shipping':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FreeShippingScreen()),
        );
        break;
      case 'flash_sale':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FlashSaleScreen()),
        );
        break;
      case 'vouchers':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const VouchersScreen()),
        );
        break;
      case 'wholesale':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const WholesaleScreen()),
        );
        break;
      case 'fresh_produce':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FreshProduceScreen()),
        );
        break;
      case 'local_shops':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LocalShopsScreen()),
        );
        break;
      case 'preorders':
        // Navigate to Pre-Orders Hub tab (tab index 2)
        SupabaseDataService.navigationTabNotifier.value = 2;
        break;
      case 'more':
        showMoreActionsBottomSheet(context);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _channels.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 6,
          childAspectRatio: 0.85,
        ),
        itemBuilder: (context, index) {
          final channel = _channels[index];
          final gradientColors = channel['gradient'] as List<Color>;
          final icon = channel['icon'] as IconData;
          final label = channel['label'] as String;
          final badge = channel['badge'] as String?;
          final badgeColor = channel['badgeColor'] as Color?;

          return InkWell(
            onTap: () => _onChannelTap(context, channel['id'] as String),
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: gradientColors.first.withValues(alpha: 0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    if (badge != null)
                      Positioned(
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor ?? const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 1.2),
                          ),
                          child: Text(
                            badge,
                            style: GoogleFonts.inter(
                              fontSize: 7.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
