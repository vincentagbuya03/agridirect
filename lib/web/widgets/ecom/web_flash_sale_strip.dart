import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/data/app_data.dart';
import '../../constants/web_design_tokens.dart';
import 'web_product_card.dart';

/// Live Flash Sale Strip with real-time countdown, claimed stock bar, and carousel
class WebFlashSaleStrip extends StatefulWidget {
  final List<ProductItem> flashProducts;
  final VoidCallback onViewAll;
  final void Function(ProductItem) onProductTap;

  const WebFlashSaleStrip({
    super.key,
    required this.flashProducts,
    required this.onViewAll,
    required this.onProductTap,
  });

  @override
  State<WebFlashSaleStrip> createState() => _WebFlashSaleStripState();
}

class _WebFlashSaleStripState extends State<WebFlashSaleStrip> {
  final ScrollController _scrollController = ScrollController();
  Timer? _ticker;
  Duration _remaining = const Duration(hours: 3, minutes: 42, seconds: 15);

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _remaining.inSeconds > 0) {
        setState(() {
          _remaining = _remaining - const Duration(seconds: 1);
        });
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scroll(bool forward) {
    final offset = _scrollController.offset + (forward ? 320 : -320);
    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Widget _buildTimeBox(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: WebDesignTokens.dark,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        value.padLeft(2, '0'),
        style: GoogleFonts.rubik(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.flashProducts.isEmpty) return const SizedBox.shrink();

    final hours = _remaining.inHours;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    return Container(
      decoration: BoxDecoration(
        color: WebDesignTokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: WebDesignTokens.dealAmber.withValues(alpha: 0.3),
        ),
        boxShadow: WebDesignTokens.cardRest,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header Bar with Countdown & View All ───
          Builder(
            builder: (context) {
              final sw = MediaQuery.of(context).size.width;
              final isCompact = sw < 900;
              final isMobile = sw < 600;

              final titleSection = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: WebDesignTokens.dealAmber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bolt_rounded,
                        color: WebDesignTokens.dealAmber, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FLASH HARVEST DEALS',
                        style: GoogleFonts.rubik(
                          fontSize: isMobile ? 15 : 18,
                          fontWeight: FontWeight.w800,
                          color: WebDesignTokens.dark,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        isMobile
                            ? 'Limited batch fresh discounts'
                            : 'Limited batch discounts direct from morning pickings',
                        style: GoogleFonts.nunitoSans(
                          fontSize: isMobile ? 11.5 : 13,
                          color: WebDesignTokens.slate500,
                        ),
                      ),
                    ],
                  ),
                ],
              );

              final timerSection = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ENDS IN: ',
                    style: GoogleFonts.rubik(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: WebDesignTokens.dealAmber,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildTimeBox('$hours', 'H'),
                  const Text(' : ',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  _buildTimeBox('$minutes', 'M'),
                  const Text(' : ',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  _buildTimeBox('$seconds', 'S'),
                ],
              );

              final actionsSection = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                    onPressed: () => _scroll(false),
                    splashRadius: 20,
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onPressed: () => _scroll(true),
                    splashRadius: 20,
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: widget.onViewAll,
                    icon: const Icon(Icons.arrow_forward_rounded,
                        size: 16, color: WebDesignTokens.dealAmber),
                    label: Text(
                      'View All Deals',
                      style: GoogleFonts.rubik(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: WebDesignTokens.dealAmber,
                      ),
                    ),
                  ),
                ],
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 16,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        titleSection,
                        timerSection,
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [actionsSection],
                    ),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      titleSection,
                      const SizedBox(width: 20),
                      timerSection,
                    ],
                  ),
                  actionsSection,
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // ─── Horizontal Products Carousel ───
          SizedBox(
            height: 380,
            child: ListView.separated(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: widget.flashProducts.length,
              separatorBuilder: (_, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final product = widget.flashProducts[index];
                final claimPct = product.claimPercentage ?? 0.72;

                return SizedBox(
                  width: 230,
                  child: Column(
                    children: [
                      Expanded(
                        child: WebProductCard(
                          product: product,
                          onTap: () => widget.onProductTap(product),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Stock Claimed Progress Meter
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '🔥 ${(claimPct * 100).toInt()}% Claimed',
                                style: GoogleFonts.rubik(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: WebDesignTokens.dealAmber,
                                ),
                              ),
                              Text(
                                'Limited Stock',
                                style: GoogleFonts.nunitoSans(
                                  fontSize: 11,
                                  color: WebDesignTokens.slate500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: claimPct,
                              minHeight: 6,
                              backgroundColor: WebDesignTokens.bg,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                WebDesignTokens.dealAmber,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
