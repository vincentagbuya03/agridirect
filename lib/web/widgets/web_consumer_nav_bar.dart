import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/services/commerce/cart_service.dart';
import '../../shared/widgets/brand_logo.dart';

class WebConsumerNavBar extends StatefulWidget {
  final int currentIndex;
  final void Function(int) onNavigate;
  final VoidCallback? onCartTap;
  final bool isCartActive;
  final EdgeInsetsGeometry margin;

  const WebConsumerNavBar({
    super.key,
    required this.currentIndex,
    required this.onNavigate,
    this.onCartTap,
    this.isCartActive = false,
    this.margin = const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
  });

  @override
  State<WebConsumerNavBar> createState() => _WebConsumerNavBarState();
}

class _WebConsumerNavBarState extends State<WebConsumerNavBar> {
  static const Color _primary = Color(0xFF16A34A);
  static const Color _dark = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);

  int _hoveredNav = -1;

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final compact = sw < 900;
    final navItems = const ['Home', 'Shop', 'Community'];

    return Container(
      margin: widget.margin,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 28,
        vertical: compact ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => widget.onNavigate(0),
              child: BrandLogo(
                size: compact ? BrandLogoSize.small : BrandLogoSize.medium,
              ),
            ),
          ),
          SizedBox(width: compact ? 20 : 48),
          ...List.generate(navItems.length, (i) {
            final isActive = i == widget.currentIndex;
            final isHovered = _hoveredNav == i;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _hoveredNav = i),
                onExit: (_) => setState(() => _hoveredNav = -1),
                child: GestureDetector(
                  onTap: () => widget.onNavigate(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 12 : 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: isActive
                          ? _primary.withValues(alpha: 0.1)
                          : isHovered
                          ? _border.withValues(alpha: 0.55)
                          : Colors.transparent,
                    ),
                    child: Text(
                      navItems[i],
                      style: GoogleFonts.inter(
                        fontSize: compact ? 13 : 14,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isActive
                            ? _primary
                            : isHovered
                            ? _dark
                            : _muted,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          ListenableBuilder(
            listenable: CartService(),
            builder: (context, _) {
              final cartCount = CartService().itemCount;
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: widget.onCartTap,
                  child: Container(
                    width: compact ? 40 : 44,
                    height: compact ? 40 : 44,
                    decoration: BoxDecoration(
                      color: widget.isCartActive
                          ? _primary.withValues(alpha: 0.12)
                          : _border.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.isCartActive
                            ? _primary.withValues(alpha: 0.35)
                            : _border,
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Center(
                          child: Icon(
                            Icons.shopping_cart_outlined,
                            color: widget.isCartActive ? _primary : _dark,
                            size: 20,
                          ),
                        ),
                        if (cartCount > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              decoration: const BoxDecoration(
                                color: _primary,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  cartCount > 99 ? '99+' : '$cartCount',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => widget.onNavigate(3),
              child: Container(
                width: compact ? 40 : 44,
                height: compact ? 40 : 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                  border: Border.all(color: _primary, width: 1.5),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: _primary,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
