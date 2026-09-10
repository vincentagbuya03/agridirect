import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../shared/data/app_data.dart';
import '../../constants/web_design_tokens.dart';

/// Multi-Vendor Farm Group Card for Web Cart (Shopee/Lazada style)
class WebMultiFarmCartGroup extends StatelessWidget {
  final String farmName;
  final String farmerId;
  final List<CartItem> items;
  final bool isSelected;
  final ValueChanged<bool?> onSelectAll;
  final void Function(CartItem, bool) onToggleItem;
  final void Function(CartItem, int) onQuantityChanged;
  final void Function(CartItem) onItemRemoved;
  final VoidCallback? onChatFarmer;

  const WebMultiFarmCartGroup({
    super.key,
    required this.farmName,
    required this.farmerId,
    required this.items,
    required this.isSelected,
    required this.onSelectAll,
    required this.onToggleItem,
    required this.onQuantityChanged,
    required this.onItemRemoved,
    this.onChatFarmer,
  });

  @override
  Widget build(BuildContext context) {
    final allSelected = items.isNotEmpty && items.every((i) => i.isSelected);

    return Container(
      decoration: BoxDecoration(
        color: WebDesignTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WebDesignTokens.border),
        boxShadow: WebDesignTokens.cardRest,
      ),
      margin: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Farm Group Header ───
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: WebDesignTokens.bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: WebDesignTokens.border)),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: allSelected,
                  activeColor: WebDesignTokens.primary,
                  onChanged: onSelectAll,
                ),
                const SizedBox(width: 4),
                const Icon(Icons.agriculture_rounded,
                    size: 18, color: WebDesignTokens.primaryDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    farmName,
                    style: GoogleFonts.rubik(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: WebDesignTokens.dark,
                    ),
                  ),
                ),
                if (onChatFarmer != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded,
                        size: 14, color: WebDesignTokens.primary),
                    label: Text(
                      'Chat',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: WebDesignTokens.primary,
                      ),
                    ),
                    onPressed: onChatFarmer,
                  ),
              ],
            ),
          ),

          // ─── Farm-Specific Voucher Strip ───
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: WebDesignTokens.dealAmber.withValues(alpha: 0.06),
              border: Border(
                bottom: BorderSide(
                  color: WebDesignTokens.dealAmber.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_offer_outlined,
                    size: 14, color: WebDesignTokens.dealAmber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Farm Voucher: ₱20 OFF on orders over ₱300 from this grower',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: WebDesignTokens.dealAmber,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Product Rows ───
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, index) =>
                Divider(height: 1, color: WebDesignTokens.border.withValues(alpha: 0.6)),
            itemBuilder: (context, index) {
              final item = items[index];
              return LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 480;

                  if (isNarrow) {
                    // Responsive compact layout for narrow screens
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: item.isSelected,
                                activeColor: WebDesignTokens.primary,
                                onChanged: (val) => onToggleItem(item, val ?? false),
                              ),
                              const SizedBox(width: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  color: WebDesignTokens.bg,
                                  child: item.imageUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: item.imageUrl,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, error, stackTrace) =>
                                              const Icon(Icons.eco,
                                                  size: 24,
                                                  color: WebDesignTokens.primary),
                                        )
                                      : const Icon(Icons.eco,
                                          size: 24, color: WebDesignTokens.primary),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.rubik(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: WebDesignTokens.dark,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '₱${item.priceValue.toStringAsFixed(0)} / ${item.unit}',
                                      style: GoogleFonts.nunitoSans(
                                        fontSize: 12,
                                        color: WebDesignTokens.slate500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 18, color: WebDesignTokens.slate400),
                                onPressed: () => onItemRemoved(item),
                                splashRadius: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(left: 48, right: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: WebDesignTokens.border),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_rounded, size: 14),
                                        onPressed: item.quantity > 1
                                            ? () => onQuantityChanged(
                                                item, item.quantity - 1)
                                            : null,
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(),
                                      ),
                                      Container(
                                        width: 32,
                                        alignment: Alignment.center,
                                        child: Text(
                                          '${item.quantity}',
                                          style: GoogleFonts.rubik(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: WebDesignTokens.dark,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_rounded, size: 14),
                                        onPressed: () => onQuantityChanged(
                                            item, item.quantity + 1),
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₱${item.total.toStringAsFixed(0)}',
                                  style: GoogleFonts.rubik(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: WebDesignTokens.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Standard wide desktop layout
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Checkbox(
                          value: item.isSelected,
                          activeColor: WebDesignTokens.primary,
                          onChanged: (val) => onToggleItem(item, val ?? false),
                        ),
                        const SizedBox(width: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 56,
                            height: 56,
                            color: WebDesignTokens.bg,
                            child: item.imageUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: item.imageUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, error, stackTrace) =>
                                        const Icon(Icons.eco,
                                            size: 24,
                                            color: WebDesignTokens.primary),
                                  )
                                : const Icon(Icons.eco,
                                    size: 24, color: WebDesignTokens.primary),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.rubik(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: WebDesignTokens.dark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₱${item.priceValue.toStringAsFixed(0)} / ${item.unit}',
                                style: GoogleFonts.nunitoSans(
                                  fontSize: 12,
                                  color: WebDesignTokens.slate500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: WebDesignTokens.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_rounded, size: 14),
                                onPressed: item.quantity > 1
                                    ? () => onQuantityChanged(
                                        item, item.quantity - 1)
                                    : null,
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                              ),
                              Container(
                                width: 32,
                                alignment: Alignment.center,
                                child: Text(
                                  '${item.quantity}',
                                  style: GoogleFonts.rubik(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: WebDesignTokens.dark,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_rounded, size: 14),
                                onPressed: () => onQuantityChanged(
                                    item, item.quantity + 1),
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        SizedBox(
                          width: 80,
                          child: Text(
                            '₱${item.total.toStringAsFixed(0)}',
                            textAlign: TextAlign.right,
                            style: GoogleFonts.rubik(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: WebDesignTokens.primaryDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18, color: WebDesignTokens.slate400),
                          onPressed: () => onItemRemoved(item),
                          splashRadius: 18,
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
