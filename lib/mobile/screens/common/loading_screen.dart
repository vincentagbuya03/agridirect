import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Splash / loading screen shown when the mobile app starts.
class LoadingScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const LoadingScreen({super.key, required this.onFinished});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  // Main entrance animation
  late final AnimationController _entranceController;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _taglineFade;
  late final Animation<double> _loaderFade;

  // Floating particles animation
  late final AnimationController _particleController;

  // Glow pulse animation
  late final AnimationController _glowController;

  // Exit animation
  late final AnimationController _exitController;
  late final Animation<double> _exitFade;
  late final Animation<double> _exitScale;

  @override
  void initState() {
    super.initState();

    // ---------- Entrance ----------
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _logoFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _logoSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
          ),
        );

    _textFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.25, 0.55, curve: Curves.easeOut),
    );

    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.25, 0.55, curve: Curves.easeOutCubic),
          ),
        );

    _taglineFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
    );

    _loaderFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.55, 0.85, curve: Curves.easeOut),
    );

    // ---------- Floating particles ----------
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    // ---------- Glow pulse ----------
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // ---------- Exit ----------
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic),
    );

    _exitScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic),
    );

    _entranceController.forward();

    // Trigger exit, then navigate
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      _exitController.forward().then((_) {
        if (mounted) widget.onFinished();
      });
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _particleController.dispose();
    _glowController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _entranceController,
          _particleController,
          _glowController,
          _exitController,
        ]),
        builder: (context, _) {
          return FadeTransition(
            opacity: _exitFade,
            child: ScaleTransition(
              scale: _exitScale,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ---- Background gradient ----
                  _buildBackground(),

                  // ---- Floating particles ----
                  ..._buildParticles(),

                  // ---- Decorative soft circles ----
                  _buildDecoCircle(
                    top: -60,
                    right: -40,
                    size: 220,
                    color: const Color(0xFF13EC5B).withValues(alpha: 0.08),
                  ),
                  _buildDecoCircle(
                    bottom: -80,
                    left: -50,
                    size: 260,
                    color: const Color(0xFF13EC5B).withValues(alpha: 0.06),
                  ),

                  // ---- Main content ----
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          const Spacer(flex: 4),
                          _buildLogo(),
                          const SizedBox(height: 32),
                          _buildTitle(),
                          const SizedBox(height: 10),
                          _buildTagline(),
                          const Spacer(flex: 3),
                          _buildLoader(),
                          const SizedBox(height: 24),
                          _buildBottomText(),
                          const SizedBox(height: 36),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===================== Widgets =====================

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF062E12),
            Color(0xFF0A4A1E),
            Color(0xFF0D5C26),
            Color(0xFF0F3D1B),
          ],
          stops: [0.0, 0.35, 0.65, 1.0],
        ),
      ),
    );
  }

  Widget _buildDecoCircle({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required Color color,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }

  List<Widget> _buildParticles() {
    // Simple procedural floating dots
    final random = math.Random(42);
    return List.generate(14, (i) {
      final baseX = random.nextDouble();
      final baseY = random.nextDouble();
      final particleSize = 3.0 + random.nextDouble() * 5;
      final speed = 0.3 + random.nextDouble() * 0.7;
      final phase = random.nextDouble() * 2 * math.pi;

      return Positioned.fill(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final t = _particleController.value * speed;
            final dx = math.sin(t * 2 * math.pi + phase) * 18;
            final dy = math.cos(t * 2 * math.pi + phase * 0.7) * 22;
            final opacity = (0.15 + 0.2 * math.sin(t * 2 * math.pi + phase))
                .clamp(0.0, 1.0);

            return Stack(
              children: [
                Positioned(
                  left: baseX * constraints.maxWidth + dx,
                  top: baseY * constraints.maxHeight + dy,
                  child: Container(
                    width: particleSize,
                    height: particleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: opacity),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    });
  }

  Widget _buildLogo() {
    final glowValue = _glowController.value;
    final glowOpacity = 0.25 + glowValue * 0.2;
    final glowRadius = 40.0 + glowValue * 20;

    return SlideTransition(
      position: _logoSlide,
      child: FadeTransition(
        opacity: _logoFade,
        child: ScaleTransition(
          scale: _logoScale,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF13EC5B).withValues(alpha: glowOpacity),
                  blurRadius: glowRadius,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Subtle inner gradient overlay
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, const Color(0xFFF0FFF4)],
                    ),
                  ),
                ),
                // Leaf icon with gradient effect
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF13EC5B), Color(0xFF0ABF47)],
                  ).createShader(bounds),
                  child: const Icon(
                    Icons.eco_rounded,
                    size: 58,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return SlideTransition(
      position: _textSlide,
      child: FadeTransition(
        opacity: _textFade,
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFB8F5CC)],
          ).createShader(bounds),
          child: const Text(
            'AgriDirect',
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1.0,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTagline() {
    return FadeTransition(
      opacity: _taglineFade,
      child: Text(
        'Farm-fresh, direct to you',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Colors.white.withValues(alpha: 0.65),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return FadeTransition(
      opacity: _loaderFade,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Custom progress bar
          SizedBox(
            width: 160,
            height: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Stack(
                children: [
                  // Track
                  Container(color: Colors.white.withValues(alpha: 0.12)),
                  // Animated fill
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final progress = _entranceController.value.clamp(
                        0.0,
                        1.0,
                      );
                      return FractionallySizedBox(
                        widthFactor: progress,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF13EC5B), Color(0xFF7BFFAB)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF13EC5B,
                                ).withValues(alpha: 0.5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomText() {
    return FadeTransition(
      opacity: _loaderFade,
      child: Text(
        'Connecting farmers & consumers',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: Colors.white.withValues(alpha: 0.40),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
