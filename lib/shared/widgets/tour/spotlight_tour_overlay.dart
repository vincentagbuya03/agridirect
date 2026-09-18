import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tour_step_model.dart';

/// The interactive spotlight overlay with animated cutout and floating coachmark card.
class SpotlightTourOverlay extends StatefulWidget {
  final List<TourStepModel> steps;
  final VoidCallback onFinish;
  final VoidCallback onSkip;
  final int initialStep;

  const SpotlightTourOverlay({
    super.key,
    required this.steps,
    required this.onFinish,
    required this.onSkip,
    this.initialStep = 0,
  });

  @override
  State<SpotlightTourOverlay> createState() => _SpotlightTourOverlayState();
}

class _SpotlightTourOverlayState extends State<SpotlightTourOverlay>
    with SingleTickerProviderStateMixin {
  late int _currentStep;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToTarget();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _scrollToTarget() {
    if (_currentStep >= widget.steps.length) return;
    final step = widget.steps[_currentStep];
    final key = step.targetKey;
    if (key != null && key.currentContext != null) {
      try {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          alignment: 0.35,
        ).then((_) {
          if (mounted) setState(() {});
        }).catchError((_) {});
      } catch (_) {}
    }
  }

  void _next() {
    if (_currentStep < widget.steps.length - 1) {
      setState(() => _currentStep++);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToTarget();
      });
    } else {
      widget.onFinish();
    }
  }

  void _previous() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToTarget();
      });
    }
  }

  Rect? _calculateTargetRect(GlobalKey? key, EdgeInsets padding) {
    if (key == null || key.currentContext == null) return null;
    try {
      final renderBox = key.currentContext!.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) return null;

      final offset = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;

      return Rect.fromLTWH(
        offset.dx - padding.left,
        offset.dy - padding.top,
        size.width + padding.horizontal,
        size.height + padding.vertical,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final step = widget.steps[_currentStep];
    final targetRect = _calculateTargetRect(step.targetKey, step.padding);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 1. Dimmed backdrop with spotlight hole & animated pulse
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, _) {
              return CustomPaint(
                size: screenSize,
                painter: _SpotlightPainter(
                  targetRect: targetRect,
                  shape: step.shape,
                  borderRadius: step.borderRadius,
                  pulseProgress: _pulseAnimation.value,
                ),
              );
            },
          ),

          // 2. Tap barrier (tapping background won't trigger underlying widgets)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {}, // Intentionally consume taps
            ),
          ),

          // 3. Floating Coachmark Card
          _buildCoachmarkCard(
            context: context,
            screenSize: screenSize,
            mediaQuery: mediaQuery,
            step: step,
            targetRect: targetRect,
          ),
        ],
      ),
    );
  }

  Widget _buildCoachmarkCard({
    required BuildContext context,
    required Size screenSize,
    required MediaQueryData mediaQuery,
    required TourStepModel step,
    required Rect? targetRect,
  }) {
    final cardWidth = math.min(screenSize.width - 32, 380.0);
    final isLastStep = _currentStep == widget.steps.length - 1;
    final badgeText = step.badge ?? '${_currentStep + 1} OF ${widget.steps.length}';

    // Position calculation
    double cardTop;
    final safeTop = mediaQuery.padding.top + 16.0;
    final safeBottom = screenSize.height - mediaQuery.padding.bottom - 16.0;
    const estimatedCardHeight = 250.0;
    final maxAllowedTop = math.max(safeTop, safeBottom - estimatedCardHeight);

    final bool isTargetOnScreen = targetRect != null &&
        targetRect.bottom > safeTop &&
        targetRect.top < safeBottom;

    if (!isTargetOnScreen) {
      // Fallback: gracefully center card if target is missing or offscreen
      cardTop = (screenSize.height - estimatedCardHeight) / 2;
    } else {
      final targetCenterY = targetRect.center.dy;
      final showBelow = step.preferredPosition == TourCardPosition.bottom ||
          (step.preferredPosition == TourCardPosition.auto &&
              targetCenterY < screenSize.height * 0.50);

      if (showBelow) {
        cardTop = targetRect.bottom + 14;
        if (cardTop + estimatedCardHeight > safeBottom) {
          cardTop = targetRect.top - estimatedCardHeight - 14;
        }
      } else {
        cardTop = targetRect.top - estimatedCardHeight - 14;
        if (cardTop < safeTop) {
          cardTop = targetRect.bottom + 14;
        }
      }
    }

    // Bulletproof clamping: card can NEVER be pushed off-screen
    cardTop = cardTop.clamp(safeTop, maxAllowedTop);

    // Horizontal centering
    final cardLeft = (screenSize.width - cardWidth) / 2;

    return Positioned(
      top: cardTop,
      left: cardLeft,
      width: cardWidth,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: Container(
          key: ValueKey<int>(_currentStep),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 36,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Step Badge + Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.eco_rounded,
                          size: 13,
                          color: Color(0xFF059669),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          badgeText,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: const Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: widget.onSkip,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 17,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title with optional icon
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (step.icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        step.icon,
                        size: 18,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      step.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        height: 1.25,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                step.description,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: const Color(0xFF475569),
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 18),

              // Bottom Actions: Back button + Step Dots + Next Button
              Row(
                children: [
                  // Previous Step Button
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: _previous,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        foregroundColor: const Color(0xFF64748B),
                      ),
                      child: Text(
                        'Back',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 4),

                  // Progress Dots
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(widget.steps.length, (index) {
                        final isCurrent = index == _currentStep;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          height: 5,
                          width: isCurrent ? 18 : 6,
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? const Color(0xFF10B981)
                                : const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Next / Get Started Button
                  ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: const Color(0xFF10B981).withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 11,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isLastStep ? 'Get Started' : 'Next',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          isLastStep
                              ? Icons.check_circle_rounded
                              : Icons.arrow_forward_rounded,
                          size: 15,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter that creates the dark dimmed overlay with a smooth cutout and pulsating glow.
class _SpotlightPainter extends CustomPainter {
  final Rect? targetRect;
  final TourSpotlightShape shape;
  final double borderRadius;
  final double pulseProgress;

  _SpotlightPainter({
    required this.targetRect,
    required this.shape,
    required this.borderRadius,
    required this.pulseProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fullScreenRect = Offset.zero & size;
    final screenPath = Path()..addRect(fullScreenRect);

    final bool isTargetVisible = targetRect != null &&
        targetRect!.bottom > 0 &&
        targetRect!.top < size.height;

    // If no target rect or completely offscreen, simply draw the dark overlay
    if (!isTargetVisible) {
      canvas.drawRect(
        fullScreenRect,
        Paint()..color = Colors.black.withValues(alpha: 0.74),
      );
      return;
    }

    // Build the cutout path
    final cutoutPath = Path();
    if (shape == TourSpotlightShape.circle) {
      final center = targetRect!.center;
      final radius = math.max(targetRect!.width, targetRect!.height) / 2;
      cutoutPath.addOval(Rect.fromCircle(center: center, radius: radius));
    } else {
      cutoutPath.addRRect(
        RRect.fromRectAndRadius(
          targetRect!,
          Radius.circular(borderRadius),
        ),
      );
    }

    // Combine paths: Screen minus Cutout
    final combinedPath = Path.combine(
      PathOperation.difference,
      screenPath,
      cutoutPath,
    );

    // Draw the dimmed backdrop
    canvas.drawPath(
      combinedPath,
      Paint()..color = Colors.black.withValues(alpha: 0.74),
    );

    // Draw pulsating glow border around the cutout
    final glowSpread = 4.0 + (pulseProgress * 3.0);
    final glowPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(
        alpha: 0.45 + (pulseProgress * 0.40),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..maskFilter = MaskFilter.blur(BlurStyle.solid, glowSpread);

    if (shape == TourSpotlightShape.circle) {
      final center = targetRect!.center;
      final radius = math.max(targetRect!.width, targetRect!.height) / 2;
      canvas.drawCircle(center, radius, glowPaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          targetRect!,
          Radius.circular(borderRadius),
        ),
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.pulseProgress != pulseProgress ||
        oldDelegate.shape != shape ||
        oldDelegate.borderRadius != borderRadius;
  }
}
