import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/data/app_data.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/services/farmer/farmer_service.dart';
import '../../../shared/widgets/image_widgets.dart';
import '../../../shared/styles/app_theme.dart';

class MobileOrderSuccessScreen extends StatefulWidget {
  final String? categoryName;

  const MobileOrderSuccessScreen({
    super.key,
    required this.categoryName,
  });

  @override
  State<MobileOrderSuccessScreen> createState() => _MobileOrderSuccessScreenState();
}

class _MobileOrderSuccessScreenState extends State<MobileOrderSuccessScreen> {
  static const Color _primary = AppColors.primary;
  static const Color _dark = AppColors.textHeadline;
  static const Color _muted = AppColors.textSubtle;
  static const Color _border = Color(0xFFF1F5F9);
  static const Color _surface = AppColors.background;
  static const Color _white = Colors.white;

  List<ProductItem> _relatedProducts = const [];
  bool _isLoadingProducts = true;

  @override
  void initState() {
    super.initState();
    _loadRelatedProducts();
  }

  Future<void> _loadRelatedProducts() async {
    final cat = widget.categoryName;
    if (cat == null || cat.trim().isEmpty) {
      if (mounted) setState(() => _isLoadingProducts = false);
      return;
    }
    try {
      final uid = AuthService().userId;
      String? currentFarmerId;
      if (uid.isNotEmpty) {
        final farmerProfile = await FarmerService().getFarmerProfile(uid);
        currentFarmerId = farmerProfile?.profileId;
      }

      final products = await SupabaseDataService().getProductsByCategory(cat);
      final filtered = products
          .where((p) => currentFarmerId == null || p.farmerId != currentFarmerId)
          .toList();

      if (mounted) {
        setState(() {
          _relatedProducts = filtered.take(4).toList();
          _isLoadingProducts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          'Receipt',
          style: AppTextStyles.headline3.copyWith(fontSize: 18),
        ),
      ),
      body: Stack(
        children: [
          // Premium confetti animation running in background
          const Positioned.fill(
            child: _ConfettiOverlay(),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildSuccessCard(),
                  const SizedBox(height: 36),
                  _buildRecommendationsSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessCard() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeInOut,
            builder: (context, opacity, child) {
              return Opacity(
                opacity: opacity,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(
                        color: _dark.withValues(alpha: 0.03),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Premium Animated Checkmark with Pulsing Rings
                      const _AnimatedCheckmark(),
                      const SizedBox(height: 28),

                      // Staggered Title Animation
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 15.0, end: 0.0),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (context, slide, child) {
                          return Transform.translate(
                            offset: Offset(0, slide),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 500),
                              builder: (context, textOpacity, child) {
                                return Opacity(
                                  opacity: textOpacity,
                                  child: child,
                                );
                              },
                              child: Text(
                                'Order Placed Successfully!',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: _dark,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Staggered Description Animation
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 20.0, end: 0.0),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, slide, child) {
                          return Transform.translate(
                            offset: Offset(0, slide),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 600),
                              builder: (context, textOpacity, child) {
                                return Opacity(
                                  opacity: textOpacity,
                                  child: child,
                                );
                              },
                              child: Text(
                                'Thank you for your purchase! The farmer has been notified and will prepare your order shortly.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: _muted,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),

                      // Staggered Buttons Animation
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 25.0, end: 0.0),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder: (context, slide, child) {
                          return Transform.translate(
                            offset: Offset(0, slide),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 650),
                              builder: (context, btnOpacity, child) {
                                return Opacity(
                                  opacity: btnOpacity,
                                  child: child,
                                );
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildHomeButton(),
                                  const SizedBox(height: 12),
                                  _buildOrdersButton(),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHomeButton() {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: () => context.go(AppRoutes.marketplace),
        icon: const Icon(Icons.home_rounded, size: 20),
        label: const Text('Go to Home'),
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildOrdersButton() {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () => context.go(AppRoutes.customerOrders),
        icon: const Icon(Icons.receipt_long_rounded, size: 20),
        label: const Text('View Orders'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _dark,
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildRecommendationsSection() {
    if (_isLoadingProducts) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }

    if (_relatedProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_mall_outlined, color: _primary),
            const SizedBox(width: 8),
            Text(
              widget.categoryName != null
                  ? 'More ${widget.categoryName} Products'
                  : 'You Might Also Like',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: _relatedProducts.length.clamp(0, 4),
          itemBuilder: (context, index) {
            final item = _relatedProducts[index];
            return GestureDetector(
              onTap: () {
                final isPreOrder = item.harvestDays != null && item.harvestDays!.trim().isNotEmpty;
                final targetRoute = isPreOrder ? AppRoutes.preorderDetails : AppRoutes.productDetails;
                context.go(targetRoute, extra: item);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(
                      color: _dark.withValues(alpha: 0.01),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 1.4,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        child: item.imageUrl.isNotEmpty
                            ? SafeNetworkImage(
                                imageUrl: item.imageUrl,
                                fit: BoxFit.cover,
                                placeholder: Container(color: _surface),
                                errorWidget: Container(color: _surface),
                              )
                            : Container(color: _surface),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _dark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.farm,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: _muted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.price,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: _primary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _surface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _border),
                                ),
                                child: Text(
                                  item.unit,
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: _muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AnimatedCheckmark extends StatefulWidget {
  const _AnimatedCheckmark();

  @override
  State<_AnimatedCheckmark> createState() => _AnimatedCheckmarkState();
}

class _AnimatedCheckmarkState extends State<_AnimatedCheckmark>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double size = 80;
    return SizedBox(
      width: size * 1.5,
      height: size * 1.5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final double progress = (_controller.value + 0.5) % 1.0;
              final double scale = 1.0 + progress * 0.5;
              final double opacity = (1.0 - progress) * 0.4;
              return Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF22C55E),
                        width: 4,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final double progress = _controller.value;
              final double scale = 1.0 + progress * 0.5;
              final double opacity = (1.0 - progress) * 0.6;
              return Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF86EFAC),
                        width: 6,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (context, val, child) {
              return Transform.scale(
                scale: val,
                child: Container(
                  width: size,
                  height: size,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x2216A34A),
                        blurRadius: 15,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF16A34A),
                    size: 48,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ConfettiOverlay extends StatefulWidget {
  const _ConfettiOverlay();

  @override
  State<_ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<_ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_ConfettiParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    final List<Color> colors = [
      const Color(0xFF22C55E),
      const Color(0xFFF59E0B),
      const Color(0xFF3B82F6),
      const Color(0xFFEC4899),
      const Color(0xFFA855F7),
      const Color(0xFF14B8A6),
    ];

    for (int i = 0; i < 40; i++) {
      final double x = (i % 5) * 0.2 + (0.1 * (i % 3));
      final double y = -0.1 - (0.02 * i);
      final double rotationSpeed = 2.0 + (i % 4) * 1.5;
      final double speed = 0.05 + (i % 3) * 0.04;
      final Color color = colors[i % colors.length];

      _particles.add(
        _ConfettiParticle(
          x: x,
          y: y,
          speed: speed,
          color: color,
          rotationSpeed: rotationSpeed,
          size: 6.0 + (i % 3) * 3,
        ),
      );
    }
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
        final double delta = _controller.value;
        for (final p in _particles) {
          p.update(delta);
        }
        return CustomPaint(
          painter: _ConfettiPainter(particles: _particles),
        );
      },
    );
  }
}

class _ConfettiParticle {
  double x;
  double y;
  final double speed;
  final double size;
  final Color color;
  final double rotationSpeed;
  double rotation = 0.0;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.color,
    required this.rotationSpeed,
  });

  void update(double delta) {
    y += speed * 0.08;
    x += 0.002 * (y * 5 % 2 == 0 ? 1 : -1);
    rotation += rotationSpeed * 0.02;

    if (y > 1.1) {
      y = -0.1;
      x = (x + 0.3) % 1.0;
    }
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  _ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final double px = p.x * size.width;
      final double py = p.y * size.height;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation);

      paint.color = p.color;
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
