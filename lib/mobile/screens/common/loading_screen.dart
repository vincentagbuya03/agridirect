import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/widgets/brand_logo.dart';

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
  late final Animation<double> _taglineFade;
  late final Animation<double> _loaderFade;

  // Floating particles animation
  late final AnimationController _particleController;

  // Glow pulse animation
  late final AnimationController _glowController;
  late final Animation<double> _glowScale;
  late final Animation<double> _glowOpacity;

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
      duration: const Duration(milliseconds: 3500),
    );

    _logoFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _logoSlide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
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
      duration: const Duration(seconds: 15),
    )..repeat();

    // ---------- Glow pulse ----------
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);

    _glowScale = Tween<double>(begin: 0.9, end: 1.2).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _glowOpacity = Tween<double>(begin: 0.2, end: 0.5).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // ---------- Exit ----------
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInOutCubic),
    );

    _exitScale = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInOutCubic),
    );

    _entranceController.forward();

    // Trigger exit, then navigate
    Future.delayed(const Duration(milliseconds: 4500), () {
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
      backgroundColor: const Color(0xFF062E12),
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

                  // ---- Main content ----
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLogoWithGlow(),
                          const SizedBox(height: 32),
                          _buildTagline(),
                          const SizedBox(height: 64),
                          _buildLoader(),
                        ],
                      ),
                    ),
                  ),

                  // ---- Bottom footer text ----
                  Positioned(
                    bottom: 48,
                    left: 0,
                    right: 0,
                    child: Center(child: _buildBottomText()),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            Color(0xFF0D5C26),
            Color(0xFF0A4A1E),
            Color(0xFF062E12),
            Color(0xFF041C0B),
          ],
          stops: [0.0, 0.4, 0.8, 1.0],
        ),
      ),
    );
  }

  List<Widget> _buildParticles() {
    final random = math.Random(42);
    return List.generate(20, (i) {
      final baseX = random.nextDouble();
      final baseY = random.nextDouble();
      final particleSize = 2.0 + random.nextDouble() * 4;
      final speed = 0.2 + random.nextDouble() * 0.4;
      final phase = random.nextDouble() * 2 * math.pi;

      return Positioned.fill(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final t = _particleController.value * speed;
            final dx = math.sin(t * 2 * math.pi + phase) * 30;
            final dy = (t * constraints.maxHeight + (baseY * constraints.maxHeight)) % constraints.maxHeight;
            
            // Fade particles in and out at top/bottom
            double opacity = 0.1 + 0.2 * math.sin(t * 2 * math.pi + phase);
            if (dy < 100) opacity *= (dy / 100);
            if (dy > constraints.maxHeight - 100) opacity *= ((constraints.maxHeight - dy) / 100);

            return Stack(
              children: [
                Positioned(
                  left: (baseX * constraints.maxWidth + dx) % constraints.maxWidth,
                  top: dy,
                  child: Container(
                    width: particleSize,
                    height: particleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: opacity * 0.5),
                          blurRadius: 4,
                        ),
                      ],
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

  Widget _buildLogoWithGlow() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing glow
        ScaleTransition(
          scale: _glowScale,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF13EC5B).withValues(alpha: _glowOpacity.value),
                  blurRadius: 60,
                  spreadRadius: 10,
                ),
              ],
            ),
          ),
        ),
        
        // Logo
        SlideTransition(
          position: _logoSlide,
          child: FadeTransition(
            opacity: _logoFade,
            child: ScaleTransition(
              scale: _logoScale,
              child: const BrandLogo(
                size: BrandLogoSize.large,
                showText: true,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTagline() {
    return FadeTransition(
      opacity: _taglineFade,
      child: Column(
        children: [
          Text(
            'FARM-FRESH DIRECT',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.9),
              letterSpacing: 4.0,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 1.5,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.transparent, Color(0xFF13EC5B), Colors.transparent],
              ),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Directly from producers to your doorstep',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.5),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoader() {
    return FadeTransition(
      opacity: _loaderFade,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sleek progress bar
          Container(
            width: 200,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final progress = _entranceController.value.clamp(0.0, 1.0);
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        width: constraints.maxWidth * progress,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF059669),
                              Color(0xFF13EC5B),
                              Color(0xFF7BFFAB),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF13EC5B).withValues(alpha: 0.4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  // Shine effect on the progress bar
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _glowController,
                      builder: (context, child) {
                        return FractionallySizedBox(
                          alignment: Alignment(-1.0 + (_glowController.value * 3.0), 0),
                          widthFactor: 0.3,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: 0.2),
                                  Colors.white.withValues(alpha: 0),
                                  ],
                                ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'SECURE ECOSYSTEM',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.3),
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomText() {
    return FadeTransition(
      opacity: _loaderFade,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 14,
                  color: Color(0xFF13EC5B),
                ),
                const SizedBox(width: 8),
                Text(
                  'TRUSTED BY 10,000+ FARMERS',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.4),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
