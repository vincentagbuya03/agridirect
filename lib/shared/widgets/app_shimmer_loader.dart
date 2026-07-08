import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

enum ShimmerType { circle, rectangle, text }

/// Unified skeletal shimmer-based loading indicator system used across mobile and web.
class AppShimmerLoader extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final ShimmerType type;
  final Color? baseColor;
  final Color? highlightColor;

  // Backwards compatibility properties
  final double strokeWidth;
  final Color? color;
  final Animation<Color?>? valueColor;
  final Color? backgroundColor;
  final double? value;
  final double size;
  final StrokeCap? strokeCap;

  const AppShimmerLoader({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.type = ShimmerType.rectangle,
    this.baseColor,
    this.highlightColor,
    this.strokeWidth = 3,
    this.color,
    this.valueColor,
    this.backgroundColor,
    this.value,
    this.size = 24,
    this.strokeCap,
  });

  // Factory methods for quick skeletal shapes
  factory AppShimmerLoader.circle({double size = 40, Color? baseColor, Color? highlightColor}) {
    return AppShimmerLoader(
      width: size,
      height: size,
      type: ShimmerType.circle,
      baseColor: baseColor,
      highlightColor: highlightColor,
    );
  }

  factory AppShimmerLoader.rectangle({double? width, double? height, double borderRadius = 8, Color? baseColor, Color? highlightColor}) {
    return AppShimmerLoader(
      width: width,
      height: height,
      borderRadius: borderRadius,
      type: ShimmerType.rectangle,
      baseColor: baseColor,
      highlightColor: highlightColor,
    );
  }

  factory AppShimmerLoader.text({double? width, double height = 14, Color? baseColor, Color? highlightColor}) {
    return AppShimmerLoader(
      width: width,
      height: height,
      borderRadius: 4,
      type: ShimmerType.text,
      baseColor: baseColor,
      highlightColor: highlightColor,
    );
  }

  // Pre-built skeleton widgets for complex layouts
  static Widget shopGrid({int count = 6}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        mainAxisExtent: 440,
      ),
      itemCount: count,
      itemBuilder: (context, index) => const AppShimmerCard(),
    );
  }

  static Widget listLines({int count = 3}) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            AppShimmerLoader.circle(size: 48),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppShimmerLoader.text(width: 150, height: 14),
                  const SizedBox(height: 8),
                  AppShimmerLoader.text(width: double.infinity, height: 11),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If they used the old circular spinner properties, preserve original look.
    final isSpinner = color != null || valueColor != null || strokeCap != null || value != null || backgroundColor != null;
    if (isSpinner) {
      final resolvedColor = color ?? valueColor?.value ?? const Color(0xFF16A34A);
      final base = resolvedColor.withValues(alpha: 0.1);
      final highlight = resolvedColor.withValues(alpha: 0.3);

      return SizedBox(
        width: size,
        height: size,
        child: Shimmer.fromColors(
          baseColor: base,
          highlightColor: highlight,
          period: const Duration(milliseconds: 1100),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: resolvedColor, width: strokeWidth),
            ),
          ),
        ),
      );
    }

    final base = baseColor ?? const Color(0xFFF1F5F9);
    final highlight = highlightColor ?? const Color(0xFFE2E8F0);

    return LayoutBuilder(
      builder: (context, constraints) {
        Widget child;
        switch (type) {
          case ShimmerType.circle:
            child = Container(
              width: width ?? size,
              height: height ?? size,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            );
            break;
          case ShimmerType.text:
            final resolvedWidth = width ??
                (constraints.maxWidth.isFinite
                    ? double.infinity
                    : 150.0);
            child = Container(
              width: resolvedWidth,
              height: height ?? 14,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            );
            break;
          case ShimmerType.rectangle:
          default:
            final resolvedWidth = width ??
                (constraints.maxWidth.isFinite
                    ? double.infinity
                    : 200.0);
            final resolvedHeight = height ??
                (constraints.maxHeight.isFinite
                    ? double.infinity
                    : 200.0);
            child = Container(
              width: resolvedWidth,
              height: resolvedHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            );
            break;
        }

        return Shimmer.fromColors(
          baseColor: base,
          highlightColor: highlight,
          child: child,
        );
      },
    );
  }
}

/// A high-fidelity card skeleton that mirrors our premium grid layout.
class AppShimmerCard extends StatelessWidget {
  const AppShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image skeleton with match border radius
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Container(
                color: const Color(0xFFF1F5F9),
                child: const AppShimmerLoader(
                  borderRadius: 0,
                  type: ShimmerType.rectangle,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge + Rating Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppShimmerLoader.rectangle(width: 80, height: 20, borderRadius: 6),
                      AppShimmerLoader.rectangle(width: 40, height: 20, borderRadius: 6),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Title
                  AppShimmerLoader.text(width: 140, height: 16),
                  const SizedBox(height: 10),
                  // Farmer row
                  Row(
                    children: [
                      AppShimmerLoader.circle(size: 20),
                      const SizedBox(width: 8),
                      AppShimmerLoader.text(width: 80, height: 11),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Progress indicator or description line
                  AppShimmerLoader.rectangle(width: double.infinity, height: 8, borderRadius: 4),
                  const Spacer(),
                  // Price and button row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppShimmerLoader.rectangle(width: 60, height: 24, borderRadius: 6),
                      AppShimmerLoader.rectangle(width: 100, height: 38, borderRadius: 12),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
