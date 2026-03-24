import 'dart:math' as math;
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════
// AGRIDIRECT — PREMIUM ANIMATED DESIGN COMPONENTS v2.0
// Enhanced: Organic Biophilic + Harvest Gold accents, glassmorphism,
// parallax, micro-animations, shimmer, aurora gradients, ribbon painter
// ═══════════════════════════════════════════════════════════════════════

// ─── Design Tokens ───────────────────────────────────────────────────
class AgriColors {
  // Primary Emerald Scale
  static const Color emerald50 = Color(0xFFECFDF5);
  static const Color emerald100 = Color(0xFFD1FAE5);
  static const Color emerald200 = Color(0xFFA7F3D0);
  static const Color emerald300 = Color(0xFF6EE7B7);
  static const Color emerald400 = Color(0xFF34D399);
  static const Color emerald500 = Color(0xFF10B981);
  static const Color emerald600 = Color(0xFF059669);
  static const Color emerald700 = Color(0xFF047857);
  static const Color emerald800 = Color(0xFF065F46);
  static const Color emerald900 = Color(0xFF064E3B);

  // Lime accents
  static const Color lime300 = Color(0xFFBEF264);
  static const Color lime400 = Color(0xFFA3E635);
  static const Color lime500 = Color(0xFF84CC16);

  // Teal accents
  static const Color teal400 = Color(0xFF2DD4BF);
  static const Color teal500 = Color(0xFF14B8A6);

  // ── NEW: Harvest Gold / Warm accent ──
  static const Color gold50 = Color(0xFFFEFCE8);
  static const Color gold100 = Color(0xFFFEF9C3);
  static const Color gold200 = Color(0xFFFEF08A);
  static const Color gold300 = Color(0xFFFDE047);
  static const Color gold400 = Color(0xFFFACC15);
  static const Color gold500 = Color(0xFFEAB308);
  static const Color gold600 = Color(0xFFCA8A04);
  static const Color gold700 = Color(0xFFA16207);

  // ── NEW: Warm Amber ──
  static const Color amber400 = Color(0xFFFBBF24);
  static const Color amber500 = Color(0xFFF59E0B);

  // Neutrals
  static const Color dark = Color(0xFF0A0F1A);
  static const Color darkAlt = Color(0xFF0F172A);
  static const Color darkCard = Color(0xFF111827);
  static const Color darkMuted = Color(0xFF1F2937);
  static const Color muted = Color(0xFF6B7280);
  static const Color mutedLight = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color surfaceGreen = Color(0xFFF0FDF4);
  static const Color white = Color(0xFFFFFFFF);

  // Accent Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [emerald400, emerald600],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF042F2E), Color(0xFF064E3B), Color(0xFF065F46), Color(0xFF047857)],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A0F1A), Color(0xFF111827)],
  );

  static const LinearGradient glowGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [emerald400, teal400],
  );

  // ── NEW: Gold accent gradient ──
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFBBF24), Color(0xFFCA8A04)],
  );

  // ── NEW: Aurora gradient for premium bg ──
  static const LinearGradient auroraGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF042F2E), Color(0xFF064E3B), Color(0xFF0D4A3E), Color(0xFF134E38)],
  );

  // ── NEW: Warm hero gradient — green + gold tints ──
  static const LinearGradient warmHeroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF042F2E), Color(0xFF064E3B), Color(0xFF065F46), Color(0xFF0A5934)],
  );

  // ── NEW: Subtle mesh gradient colors ──
  static const Color meshA = Color(0xFF10B981);
  static const Color meshB = Color(0xFF14B8A6);
  static const Color meshC = Color(0xFFFBBF24);
}

// ─── SVG-Like Painters ─────────────────────────────────────────────

/// Animated wave background painter for hero sections
class WavePainter extends CustomPainter {
  final double animationValue;
  final Color color;
  final double amplitude;

  WavePainter({
    required this.animationValue,
    this.color = const Color(0x15FFFFFF),
    this.amplitude = 20,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.75);

    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.75 +
          math.sin((x / size.width * 4 * math.pi) + (animationValue * 2 * math.pi)) * amplitude +
          math.sin((x / size.width * 2 * math.pi) + (animationValue * math.pi)) * (amplitude * 0.5);
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}

/// Organic blob painter — creates smooth organic shapes for backgrounds
class BlobPainter extends CustomPainter {
  final double animationValue;
  final Color color;
  final Offset center;
  final double radius;

  BlobPainter({
    required this.animationValue,
    this.color = const Color(0x0AFFFFFF),
    this.center = const Offset(0.5, 0.5),
    this.radius = 150,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withOpacity(0)],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * center.dx, size.height * center.dy),
          radius: radius,
        ),
      );

    final path = Path();
    final cx = size.width * center.dx;
    final cy = size.height * center.dy;
    const points = 6;

    for (int i = 0; i <= points * 2; i++) {
      final angle = (i / (points * 2)) * 2 * math.pi;
      final r = radius +
          math.sin(angle * 3 + animationValue * 2 * math.pi) * (radius * 0.15) +
          math.cos(angle * 2 + animationValue * 4 * math.pi) * (radius * 0.08);
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(BlobPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}

/// Geometric grid pattern painter
class GridPatternPainter extends CustomPainter {
  final double opacity;
  final Color color;

  GridPatternPainter({this.opacity = 0.03, this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 40.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Dot pattern painter for subtle backgrounds
class DotPatternPainter extends CustomPainter {
  final double opacity;
  final Color color;

  DotPatternPainter({this.opacity = 0.06, this.color = const Color(0xFF10B981)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    const spacing = 28.0;
    const radius = 1.2;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ── NEW: Organic curve ribbon painter — flowing SVG-like curves ──
class RibbonPainter extends CustomPainter {
  final double animationValue;
  final Color color;
  final double strokeWidth;

  RibbonPainter({
    required this.animationValue,
    this.color = const Color(0x12FFFFFF),
    this.strokeWidth = 1.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 4; i++) {
      final path = Path();
      final yOffset = size.height * (0.25 + i * 0.2);
      final phase = animationValue * 2 * math.pi + i * 0.8;

      path.moveTo(0, yOffset);
      for (double x = 0; x <= size.width; x += 2) {
        final y = yOffset +
            math.sin(x / size.width * 3 * math.pi + phase) * 25 +
            math.cos(x / size.width * 1.5 * math.pi + phase * 0.7) * 15;
        path.lineTo(x, y);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(RibbonPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}

/// ── NEW: Hexagon pattern painter — organic farm grid ──
class HexPatternPainter extends CustomPainter {
  final double opacity;
  final Color color;

  HexPatternPainter({this.opacity = 0.04, this.color = const Color(0xFF10B981)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    const hexRadius = 24.0;
    final rowHeight = hexRadius * math.sqrt(3);
    final colWidth = hexRadius * 1.5;

    for (double col = 0; col < size.width / colWidth + 1; col++) {
      for (double row = 0; row < size.height / rowHeight + 1; row++) {
        final cx = col * colWidth;
        final cy = row * rowHeight + (col.toInt() % 2 == 1 ? rowHeight / 2 : 0);

        final path = Path();
        for (int i = 0; i < 6; i++) {
          final angle = (60 * i - 30) * math.pi / 180;
          final px = cx + hexRadius * math.cos(angle);
          final py = cy + hexRadius * math.sin(angle);
          if (i == 0) {
            path.moveTo(px, py);
          } else {
            path.lineTo(px, py);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ── NEW: Aurora glow painter — soft ambient gradient blobs ──
class AuroraGlowPainter extends CustomPainter {
  final double animationValue;

  AuroraGlowPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    // Emerald glow
    final p1 = Paint()
      ..shader = RadialGradient(
        colors: [
          AgriColors.emerald500.withOpacity(0.08),
          AgriColors.emerald500.withOpacity(0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(
          size.width * (0.3 + 0.1 * math.sin(animationValue * 2 * math.pi)),
          size.height * (0.3 + 0.05 * math.cos(animationValue * 2 * math.pi)),
        ),
        radius: size.width * 0.35,
      ));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), p1);

    // Teal glow
    final p2 = Paint()
      ..shader = RadialGradient(
        colors: [
          AgriColors.teal400.withOpacity(0.06),
          AgriColors.teal400.withOpacity(0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(
          size.width * (0.7 + 0.08 * math.cos(animationValue * 2 * math.pi)),
          size.height * (0.6 + 0.06 * math.sin(animationValue * 2 * math.pi)),
        ),
        radius: size.width * 0.3,
      ));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), p2);

    // Gold glow — warm accent
    final p3 = Paint()
      ..shader = RadialGradient(
        colors: [
          AgriColors.gold400.withOpacity(0.04),
          AgriColors.gold400.withOpacity(0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(
          size.width * (0.8 + 0.05 * math.sin(animationValue * 3 * math.pi)),
          size.height * (0.2 + 0.04 * math.cos(animationValue * 2.5 * math.pi)),
        ),
        radius: size.width * 0.2,
      ));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), p3);
  }

  @override
  bool shouldRepaint(AuroraGlowPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}

// ─── Animated Widgets ───────────────────────────────────────────────

/// Floating particle effect — small glowing dots that float around
class FloatingParticles extends StatefulWidget {
  final int count;
  final double maxSize;
  final Color color;
  final double width;
  final double height;

  const FloatingParticles({
    super.key,
    this.count = 20,
    this.maxSize = 4,
    this.color = const Color(0xFF10B981),
    this.width = double.infinity,
    this.height = 500,
  });

  @override
  State<FloatingParticles> createState() => _FloatingParticlesState();
}

class _FloatingParticlesState extends State<FloatingParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    _particles = List.generate(widget.count, (_) {
      return _Particle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: 1 + rng.nextDouble() * widget.maxSize,
        speed: 0.2 + rng.nextDouble() * 0.6,
        opacity: 0.1 + rng.nextDouble() * 0.3,
        phase: rng.nextDouble() * 2 * math.pi,
      );
    });

    _controller = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.width, widget.height),
          painter: _ParticlePainter(
            particles: _particles,
            animationValue: _controller.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class _Particle {
  final double x, y, size, speed, opacity, phase;
  const _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.phase,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double animationValue;
  final Color color;

  _ParticlePainter({
    required this.particles,
    required this.animationValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final dx = p.x * size.width +
          math.sin(animationValue * 2 * math.pi * p.speed + p.phase) * 30;
      final dy = p.y * size.height +
          math.cos(animationValue * 2 * math.pi * p.speed + p.phase) * 20;

      final paint = Paint()
        ..color = color.withValues(alpha: p.opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.8);

      canvas.drawCircle(Offset(dx, dy), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}

/// Scroll-triggered fade-in + slide-up animation wrapper
class ScrollReveal extends StatefulWidget {
  final Widget child;
  final double offset;
  final Duration duration;
  final Duration delay;
  final Curve curve;

  const ScrollReveal({
    super.key,
    required this.child,
    this.offset = 40,
    this.duration = const Duration(milliseconds: 800),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<ScrollReveal> createState() => _ScrollRevealState();
}

class _ScrollRevealState extends State<ScrollReveal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    _slide = Tween<Offset>(
      begin: Offset(0, widget.offset),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onVisibilityChanged() {
    if (!_triggered) {
      _triggered = true;
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Auto-trigger on first build
    WidgetsBinding.instance.addPostFrameCallback((_) => _onVisibilityChanged());

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: _slide.value,
          child: Opacity(
            opacity: _opacity.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// Staggered children animation — animates children one by one
class StaggeredList extends StatefulWidget {
  final List<Widget> children;
  final Duration itemDelay;
  final Duration itemDuration;
  final double slideOffset;

  const StaggeredList({
    super.key,
    required this.children,
    this.itemDelay = const Duration(milliseconds: 100),
    this.itemDuration = const Duration(milliseconds: 600),
    this.slideOffset = 30,
  });

  @override
  State<StaggeredList> createState() => _StaggeredListState();
}

class _StaggeredListState extends State<StaggeredList>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.children.length,
      (i) => AnimationController(
        duration: widget.itemDuration,
        vsync: this,
      ),
    );

    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(widget.itemDelay * i, () {
        if (mounted) _controllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(widget.children.length, (i) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: _controllers[i], curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, widget.slideOffset / 100),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: _controllers[i], curve: Curves.easeOutCubic),
            ),
            child: widget.children[i],
          ),
        );
      }),
    );
  }
}

/// Glassmorphism container — enhanced with subtle inner glow
class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double blur;
  final Color backgroundColor;
  final Color borderColor;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.all(24),
    this.blur = 12,
    this.backgroundColor = const Color(0xB3FFFFFF),
    this.borderColor = const Color(0x33FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: blur,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Animated gradient text
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Gradient gradient;

  const GradientText({
    super.key,
    required this.text,
    this.style,
    this.gradient = const LinearGradient(
      colors: [Color(0xFF10B981), Color(0xFF34D399)],
    ),
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(text, style: style),
    );
  }
}

/// Animated counter that counts up from 0 to target
class AnimatedCounter extends StatefulWidget {
  final int target;
  final String suffix;
  final TextStyle? style;
  final Duration duration;

  const AnimatedCounter({
    super.key,
    required this.target,
    this.suffix = '',
    this.style,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0,
      end: widget.target.toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Text(
          '${_animation.value.toInt()}${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}

/// Pulsing glow effect ring around a widget
class PulsingGlow extends StatefulWidget {
  final Widget child;
  final Color color;
  final double radius;

  const PulsingGlow({
    super.key,
    required this.child,
    this.color = const Color(0xFF10B981),
    this.radius = 60,
  });

  @override
  State<PulsingGlow> createState() => _PulsingGlowState();
}

class _PulsingGlowState extends State<PulsingGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.15 + _controller.value * 0.15),
                blurRadius: widget.radius * (0.8 + _controller.value * 0.4),
                spreadRadius: _controller.value * 8,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// Hover-scale card with smooth shadow transition
class HoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? hoverBorderColor;

  const HoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.all(24),
    this.hoverBorderColor,
  });

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hoverColor = widget.hoverBorderColor ?? AgriColors.emerald500;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: widget.padding,
          transform: Matrix4.translationValues(0, _hovered ? -6 : 0, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: _hovered ? hoverColor.withOpacity(0.4) : AgriColors.border,
              width: _hovered ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _hovered
                    ? hoverColor.withOpacity(0.12)
                    : Colors.black.withOpacity(0.04),
                blurRadius: _hovered ? 24 : 8,
                offset: Offset(0, _hovered ? 12 : 4),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Animated leaf SVG-like icon using CustomPaint
class AnimatedLeafIcon extends StatefulWidget {
  final double size;
  final Color color;

  const AnimatedLeafIcon({
    super.key,
    this.size = 24,
    this.color = const Color(0xFF10B981),
  });

  @override
  State<AnimatedLeafIcon> createState() => _AnimatedLeafIconState();
}

class _AnimatedLeafIconState extends State<AnimatedLeafIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Transform.rotate(
          angle: math.sin(_controller.value * 2 * math.pi) * 0.08,
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _LeafPainter(color: widget.color),
          ),
        );
      },
    );
  }
}

class _LeafPainter extends CustomPainter {
  final Color color;
  _LeafPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;

    // Leaf shape
    path.moveTo(w * 0.5, h * 0.05);
    path.cubicTo(w * 0.15, h * 0.2, w * 0.05, h * 0.55, w * 0.5, h * 0.95);
    path.cubicTo(w * 0.95, h * 0.55, w * 0.85, h * 0.2, w * 0.5, h * 0.05);
    path.close();

    canvas.drawPath(path, paint);

    // Stem
    final stemPaint = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final stemPath = Path();
    stemPath.moveTo(w * 0.5, h * 0.2);
    stemPath.quadraticBezierTo(w * 0.5, h * 0.5, w * 0.5, h * 0.9);
    canvas.drawPath(stemPath, stemPaint);

    // Veins
    final veinPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 3; i++) {
      final vein = Path();
      final yStart = h * (0.35 + i * 0.15);
      vein.moveTo(w * 0.5, yStart);
      vein.quadraticBezierTo(w * (0.3 - i * 0.03), yStart + h * 0.05, w * (0.2 - i * 0.02), yStart + h * 0.08);
      canvas.drawPath(vein, veinPaint);

      final vein2 = Path();
      vein2.moveTo(w * 0.5, yStart);
      vein2.quadraticBezierTo(w * (0.7 + i * 0.03), yStart + h * 0.05, w * (0.8 + i * 0.02), yStart + h * 0.08);
      canvas.drawPath(vein2, veinPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Gradient divider line
class GradientDivider extends StatelessWidget {
  final double height;
  final double width;

  const GradientDivider({
    super.key,
    this.height = 3,
    this.width = 60,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        gradient: AgriColors.primaryGradient,
      ),
    );
  }
}

/// Animated typing text effect
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration charDuration;

  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.charDuration = const Duration(milliseconds: 50),
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _displayed = '';
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _typeNext();
  }

  void _typeNext() {
    if (_index < widget.text.length) {
      Future.delayed(widget.charDuration, () {
        if (mounted) {
          setState(() {
            _displayed = widget.text.substring(0, _index + 1);
            _index++;
          });
          _typeNext();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(_displayed, style: widget.style);
  }
}

/// ── NEW: Shimmer loading placeholder ──
class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * _controller.value, 0),
              end: Alignment(1 + 2 * _controller.value, 0),
              colors: const [
                Color(0xFFF1F5F9),
                Color(0xFFE2E8F0),
                Color(0xFFF1F5F9),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// ── NEW: Animated gradient border card — premium hover effect ──
class GradientBorderCard extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double borderWidth;

  const GradientBorderCard({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.all(24),
    this.onTap,
    this.borderWidth = 2,
  });

  @override
  State<GradientBorderCard> createState() => _GradientBorderCardState();
}

class _GradientBorderCardState extends State<GradientBorderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                gradient: _hovered
                    ? SweepGradient(
                        center: Alignment.center,
                        startAngle: _controller.value * 2 * math.pi,
                        endAngle: _controller.value * 2 * math.pi + 2 * math.pi,
                        colors: const [
                          AgriColors.emerald400,
                          AgriColors.teal400,
                          AgriColors.gold400,
                          AgriColors.emerald400,
                        ],
                      )
                    : null,
                border: !_hovered ? Border.all(color: AgriColors.border) : null,
                boxShadow: _hovered
                    ? [
                        BoxShadow(
                          color: AgriColors.emerald500.withOpacity(0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Container(
                margin: _hovered ? EdgeInsets.all(widget.borderWidth) : EdgeInsets.zero,
                padding: widget.padding,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(
                    _hovered ? widget.borderRadius - widget.borderWidth : widget.borderRadius,
                  ),
                ),
                child: widget.child,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// ── NEW: Animated bar chart — simple vertical bars for dashboards ──
class MiniBarChart extends StatefulWidget {
  final List<double> values;
  final List<String>? labels;
  final Color barColor;
  final Color bgColor;
  final double height;
  final double barWidth;

  const MiniBarChart({
    super.key,
    required this.values,
    this.labels,
    this.barColor = const Color(0xFF10B981),
    this.bgColor = const Color(0xFFF0FDF4),
    this.height = 160,
    this.barWidth = 28,
  });

  @override
  State<MiniBarChart> createState() => _MiniBarChartState();
}

class _MiniBarChartState extends State<MiniBarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxVal = widget.values.reduce(math.max);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = Curves.easeOutCubic.transform(_controller.value);
        return SizedBox(
          height: widget.height + (widget.labels != null ? 28 : 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(widget.values.length, (i) {
              final barHeight = (widget.values[i] / maxVal) * widget.height * progress;
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: widget.barWidth,
                    height: barHeight.clamp(4, widget.height),
                    decoration: BoxDecoration(
                      color: widget.barColor.withValues(alpha: 0.2 + (i / widget.values.length) * 0.8),
                      borderRadius: BorderRadius.circular(widget.barWidth / 3),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          widget.barColor.withOpacity(0.4),
                          widget.barColor,
                        ],
                      ),
                    ),
                  ),
                  if (widget.labels != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.labels![i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AgriColors.muted,
                      ),
                    ),
                  ],
                ],
              );
            }),
          ),
        );
      },
    );
  }
}

/// ── NEW: Animated donut/ring chart ──
class MiniDonutChart extends StatefulWidget {
  final List<double> values;
  final List<Color> colors;
  final double size;
  final double strokeWidth;
  final Widget? center;

  const MiniDonutChart({
    super.key,
    required this.values,
    required this.colors,
    this.size = 140,
    this.strokeWidth = 16,
    this.center,
  });

  @override
  State<MiniDonutChart> createState() => _MiniDonutChartState();
}

class _MiniDonutChartState extends State<MiniDonutChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _DonutPainter(
                  values: widget.values,
                  colors: widget.colors,
                  strokeWidth: widget.strokeWidth,
                  progress: Curves.easeOutCubic.transform(_controller.value),
                ),
              ),
              if (widget.center != null) widget.center!,
            ],
          ),
        );
      },
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final double strokeWidth;
  final double progress;

  _DonutPainter({
    required this.values,
    required this.colors,
    required this.strokeWidth,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.reduce((a, b) => a + b);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background ring
    final bgPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    double startAngle = -math.pi / 2;
    for (int i = 0; i < values.length; i++) {
      final sweepAngle = (values[i] / total) * 2 * math.pi * progress;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// ── NEW: Subtle floating badge with icon — reusable for trust signals ──
class TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool mini;

  const TrustBadge({
    super.key,
    required this.icon,
    required this.label,
    this.color = const Color(0xFF10B981),
    this.mini = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: mini ? 10 : 14,
        vertical: mini ? 6 : 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.85)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: mini ? 12 : 14, color: Colors.white),
          SizedBox(width: mini ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              fontSize: mini ? 10 : 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
