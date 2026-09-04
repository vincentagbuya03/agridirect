import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../../shared/router/app_router.dart';
import '../../../../../shared/services/commerce/cart_service.dart';
import '../../../../../shared/services/community/notification_service.dart';
import '../../cart_screen.dart';
import '../../search_screen.dart';
import '../../../auth/qr_scanner_screen.dart';

/// Sticky Shopee/Lazada-style collapsible Sliver App Bar for AgriDirect.
class EcomSliverAppBar extends StatelessWidget {
  final String displayCity;
  final VoidCallback onLocationTap;
  final Stream<int>? unreadMessagesStream;

  const EcomSliverAppBar({
    super.key,
    required this.displayCity,
    required this.onLocationTap,
    this.unreadMessagesStream,
  });

  Widget _buildActionButton({
    required Widget iconWidget,
    required VoidCallback onTap,
    int badgeCount = 0,
    bool showDotOnly = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: iconWidget,
          ),
          if (showDotOnly && badgeCount > 0)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            )
          else if (badgeCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Center(
                  child: Text(
                    badgeCount > 99 ? '99+' : badgeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      elevation: 0,
      toolbarHeight: 110,
      backgroundColor: const Color(0xFF047857),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF047857), Color(0xFF059669), Color(0xFF10B981)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── ROW 1: LOCATION PILL & COMPACT ACTIONS ──
                Row(
                  children: [
                    // Delivery Location Pill
                    Expanded(
                      child: GestureDetector(
                        onTap: onLocationTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                color: Color(0xFFFDE047),
                                size: 15,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: RichText(
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Deliver to: ',
                                        style: GoogleFonts.inter(
                                          color: Colors.white.withValues(alpha: 0.85),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      TextSpan(
                                        text: displayCity,
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Chat Action with Unread Stream
                    if (unreadMessagesStream != null)
                      StreamBuilder<int>(
                        stream: unreadMessagesStream,
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? 0;
                          return _buildActionButton(
                            iconWidget: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                            badgeCount: count,
                            showDotOnly: true,
                            onTap: () => context.push(AppRoutes.customerMessages),
                          );
                        },
                      )
                    else
                      _buildActionButton(
                        iconWidget: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                        onTap: () => context.push(AppRoutes.customerMessages),
                      ),
                    const SizedBox(width: 8),

                    // Notifications Action
                    ValueListenableBuilder<int>(
                      valueListenable: NotificationService().unreadCountNotifier,
                      builder: (context, count, _) {
                        return _buildActionButton(
                          iconWidget: const Icon(
                            Icons.notifications_none_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          badgeCount: count,
                          showDotOnly: true,
                          onTap: () => context.push(AppRoutes.notifications),
                        );
                      },
                    ),
                    const SizedBox(width: 8),

                    // Shopping Cart with Live Item Count
                    ListenableBuilder(
                      listenable: CartService(),
                      builder: (context, _) {
                        final count = CartService().itemCount;
                        return _buildActionButton(
                          iconWidget: const Icon(
                            Icons.shopping_cart_outlined,
                            color: Colors.white,
                            size: 19,
                          ),
                          badgeCount: count,
                          showDotOnly: false,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CartScreen(),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ── ROW 2: INTEGRATED SHOPEE-STYLE SEARCH PILL ──
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SearchScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF059669),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Search fresh crops, fruits, vegetables...',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF94A3B8),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            height: 18,
                            width: 1,
                            color: const Color(0xFFE2E8F0),
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const QRScannerScreen(
                                    title: 'Scan QR / Product',
                                    instruction: 'Scan produce batch QR code',
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.qr_code_scanner_rounded,
                                color: Color(0xFF059669),
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
