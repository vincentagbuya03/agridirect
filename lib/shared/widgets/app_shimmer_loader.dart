import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Unified shimmer-based loading indicator used across mobile and web.
class AppShimmerLoader extends StatelessWidget {
  final double strokeWidth;
  final Color? color;
  final Animation<Color?>? valueColor;
  final Color? backgroundColor;
  final double? value;
  final double size;
  final StrokeCap? strokeCap;

  const AppShimmerLoader({
    super.key,
    this.strokeWidth = 3,
    this.color,
    this.valueColor,
    this.backgroundColor,
    this.value,
    this.size = 24,
    this.strokeCap,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? valueColor?.value ?? const Color(0xFF16A34A);
    final baseColor = resolvedColor.withValues(alpha: 0.1);
    final highlightColor = resolvedColor.withValues(alpha: 0.3);

    return SizedBox(
      width: size,
      height: size,
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
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
}
