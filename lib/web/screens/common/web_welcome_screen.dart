import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/auth/onboarding_service.dart';
import '../../widgets/animated_components.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/router/app_routes.dart';
import '../../widgets/web_hamburger_menu_button.dart';
import '../../../shared/utils/apk_downloader.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/services/articles/articles_service.dart';
import '../../widgets/web_footer.dart';
import 'web_articles_screen.dart';
import 'dart:async';


/// Web Welcome Screen — Premium animated landing page
/// Features: animated wave hero, floating particles, scroll-reveal sections,
/// glassmorphism cards, custom SVG-like leaf icons, gradient text, animated counters
class WebWelcomeScreen extends StatefulWidget {
  const WebWelcomeScreen({super.key});

  @override
  State<WebWelcomeScreen> createState() => _WebWelcomeScreenState();
}

class _WebWelcomeScreenState extends State<WebWelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _heroFadeCtrl;
  late AnimationController _navCtrl;
  int _hoveredNav = -1;
  int _hoveredFeature = -1;
  int _hoveredStep = -1;
  bool _ctaHovered = false;
  bool _heroCtaHovered = false;
  bool _heroSecondaryHovered = false;
  int _activeBannerIndex = 1; // 0, 1, or 2
  bool _showMobileBanner = true;

  // Testimonials
  List<Map<String, dynamic>> _testimonials = [];
  late PageController _testimonialPageController;
  Timer? _testimonialTimer;
  int _currentTestimonialIndex = 0;
  List<DAArticleData> _liveDaArticles = [];

  @override
  void initState() {
    super.initState();
    _testimonialPageController = PageController();
    _fetchTestimonials();
    _fetchLiveArticles();
    _waveController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    _heroFadeCtrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _navCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    // Start animations
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _heroFadeCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _navCtrl.forward();
    });
  }

  Future<void> _fetchTestimonials() async {
    try {
      final res = await SupabaseConfig.client
          .from('product_reviews')
          .select('review_text, rating')
          .eq('rating', 5)
          .not('review_text', 'is', null)
          .order('created_at', ascending: false)
          .limit(5);

      if (mounted) {
        final List<dynamic> data = res as List<dynamic>;
        final validReviews = data.where((r) {
          final text = r['review_text']?.toString().trim() ?? '';
          return text.isNotEmpty;
        }).map((r) => {
          'review_text': r['review_text'],
          'rating': r['rating'],
          'users': {'name': 'Verified Customer'},
        }).toList();

        setState(() {
          _testimonials = validReviews.cast<Map<String, dynamic>>();
        });

        if (_testimonials.length > 1) {
          _startTestimonialTimer();
        }
      }
    } catch (e) {
      debugPrint('Error fetching testimonials: $e');
    }
  }

  Future<void> _fetchLiveArticles() async {
    try {
      final list = await ArticlesService().getPublishedArticles();
      if (mounted && list.isNotEmpty) {
        setState(() {
          _liveDaArticles = list;
        });
      }
    } catch (e) {
      debugPrint('Error fetching live articles: $e');
    }
  }

  void _startTestimonialTimer() {
    _testimonialTimer?.cancel();
    _testimonialTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || _testimonials.isEmpty) return;
      int next = _currentTestimonialIndex + 1;
      if (next >= _testimonials.length) {
        next = 0;
        _testimonialPageController.jumpToPage(0);
      } else {
        _testimonialPageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
      setState(() {
        _currentTestimonialIndex = next;
      });
    });
  }

  @override
  void dispose() {
    _testimonialTimer?.cancel();
    _testimonialPageController.dispose();
    _waveController.dispose();
    _heroFadeCtrl.dispose();
    _navCtrl.dispose();
    super.dispose();
  }

  Future<void> _completeWelcome() async {
    await OnboardingService.completeOnboarding();
    if (mounted) context.go(AppRoutes.marketplace);
  }

  Future<void> _downloadAndroidApk() async {
    await ApkDownloader.download();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                _buildNavBar(),

                _buildHeroSection(),

                _buildStatsBar(),

                _buildFarmingShowcaseSection(),

                _buildFeaturesSection(),

                _buildFeaturedFarmersSection(),

                _buildDaArticlesSection(),

                _buildAppDownloadSection(),
                _buildHowItWorksSection(),
                _buildTestimonialSection(),
                _buildCtaSection(),

                const AgriDirectWebFooter(),
              ],
            ),
          ),
          if (isMobile && _showMobileBanner)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildMobileAppBanner(),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileAppBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AgriColors.dark.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AgriColors.emerald500.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.android_rounded,
                  color: AgriColors.emerald400,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AgriDirect Mobile App',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Download secure APK now.',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _downloadAndroidApk,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AgriColors.emerald500,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Install',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() {
                    _showMobileBanner = false;
                  });
                },
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white60,
                  size: 18,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FLOATING NAV BAR with glassmorphism
  // ═══════════════════════════════════════════════════════════════
  Widget _buildNavBar() {
    final navItems = ['Home', 'Shop', 'Community', 'DA Articles', 'About Us', 'Find Farmer', 'Weather'];
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 650;

    final navRoutes = [
      '/',
      '/shop',
      '/community',
      '/articles',
      '/about-us',
      '/farmers-map',
      '/weather-radar',
    ];

    return FadeTransition(
      opacity: CurvedAnimation(parent: _navCtrl, curve: Curves.easeOut),
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 32,
          vertical: isMobile ? 12 : 16,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 28,
          vertical: isMobile ? 12 : 14,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AgriColors.border.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
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
                onTap: () => context.go('/shop'),
                child: BrandLogo(
                  size: isMobile ? BrandLogoSize.small : BrandLogoSize.medium,
                ),
              ),
            ),
            if (!isMobile) ...[
              const SizedBox(width: 48),
              // Nav items
              ...List.generate(navItems.length, (i) {
                final isHovered = _hoveredNav == i;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => _hoveredNav = i),
                    onExit: (_) => setState(() => _hoveredNav = -1),
                    child: GestureDetector(
                      onTap: () => context.go(navRoutes[i]),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isHovered
                              ? AgriColors.emerald50
                              : Colors.transparent,
                        ),
                        child: Text(
                          navItems[i],
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: isHovered
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isHovered
                                ? AgriColors.emerald700
                                : AgriColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
            const Spacer(),
            // Sign In / Person Icon Button
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => context.go('/login'),
                child: Container(
                  width: isMobile ? 38 : 44,
                  height: isMobile ? 38 : 44,
                  decoration: BoxDecoration(
                    color: AgriColors.emerald50,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AgriColors.emerald500,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: AgriColors.emerald600,
                    size: isMobile ? 18 : 22,
                  ),
                ),
              ),
            ),
            if (isMobile) ...[
              const SizedBox(width: 8),
              WebHamburgerMenuButton(
                currentIndex: 0,
                onNavigate: (index) {
                  if (index == 3) {
                    context.go('/login');
                  } else {
                    context.go(navRoutes[index]);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HERO SECTION with animated waves, particles, and blobs
  // ═══════════════════════════════════════════════════════════════
  Widget _buildHeroSection() {
    final sw = MediaQuery.of(context).size.width;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 640),
      child: Stack(
        children: [
          // Background gradient — warm hero
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AgriColors.warmHeroGradient,
              ),
            ),
          ),

          // Aurora glow — ambient color blobs
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) {
                return CustomPaint(
                  painter: AuroraGlowPainter(
                    animationValue: _waveController.value,
                  ),
                );
              },
            ),
          ),

          // Hex pattern overlay
          Positioned.fill(
            child: CustomPaint(
              painter: HexPatternPainter(opacity: 0.025, color: Colors.white),
            ),
          ),

          // Ribbon curves
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) {
                return CustomPaint(
                  painter: RibbonPainter(
                    animationValue: _waveController.value,
                    color: Colors.white.withValues(alpha: 0.04),
                    strokeWidth: 1.0,
                  ),
                );
              },
            ),
          ),

          // Animated blobs
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) {
                return CustomPaint(
                  painter: BlobPainter(
                    animationValue: _waveController.value,
                    color: AgriColors.emerald400.withValues(alpha: 0.08),
                    center: const Offset(0.8, 0.3),
                    radius: 280,
                  ),
                );
              },
            ),
          ),

          Positioned.fill(
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) {
                return CustomPaint(
                  painter: BlobPainter(
                    animationValue: 1 - _waveController.value,
                    color: AgriColors.teal400.withValues(alpha: 0.06),
                    center: const Offset(0.2, 0.7),
                    radius: 220,
                  ),
                );
              },
            ),
          ),

          // Gold accent blob
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) {
                return CustomPaint(
                  painter: BlobPainter(
                    animationValue: _waveController.value * 0.7,
                    color: AgriColors.gold400.withValues(alpha: 0.03),
                    center: const Offset(0.9, 0.15),
                    radius: 120,
                  ),
                );
              },
            ),
          ),

          // Floating particles — mixed green + gold
          const Positioned.fill(
            child: FloatingParticles(
              count: 35,
              maxSize: 3.5,
              color: Color(0xFF34D399),
              height: 640,
            ),
          ),
          const Positioned.fill(
            child: FloatingParticles(
              count: 6,
              maxSize: 2,
              color: Color(0xFFFBBF24),
              height: 640,
            ),
          ),

          // Animated waves at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 120,
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) {
                return CustomPaint(
                  painter: WavePainter(
                    animationValue: _waveController.value,
                    color: Colors.white.withValues(alpha: 0.06),
                    amplitude: 25,
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 80,
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) {
                return CustomPaint(
                  painter: WavePainter(
                    animationValue: 1 - _waveController.value,
                    color: Colors.white.withValues(alpha: 0.04),
                    amplitude: 15,
                  ),
                );
              },
            ),
          ),

          // Content
          Center(
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _heroFadeCtrl,
                curve: Curves.easeOut,
              ),
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _heroFadeCtrl,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1300),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: sw < 480
                          ? 16
                          : sw < 768
                          ? 24
                          : sw * 0.06,
                      vertical: sw < 480 ? 40 : 80,
                    ),
                    child: sw >= 900
                        ? Row(
                            children: [
                              Expanded(child: _heroContent(sw)),
                              const SizedBox(width: 60),
                              _heroVisual(sw),
                            ],
                          )
                        : _heroContent(sw),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroContent(double sw) {
    return Column(
      crossAxisAlignment: sw >= 900
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Badge — gold accent
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AgriColors.gold400.withValues(alpha: 0.15),
                AgriColors.emerald400.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: AgriColors.gold300.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  gradient: AgriColors.goldGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AgriColors.gold400.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'FARM-TO-TABLE MARKETPLACE',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AgriColors.gold200,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Headline
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Connect Directly\nWith ',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: sw < 768 ? 34 : 54,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.1,
                  letterSpacing: -1,
                ),
              ),
              TextSpan(
                text: 'Local Farmers',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: sw < 768 ? 34 : 54,
                  fontWeight: FontWeight.w800,
                  color: AgriColors.emerald300,
                  height: 1.1,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          textAlign: sw >= 900 ? TextAlign.left : TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Subtitle
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Text(
            'Get the freshest produce at fair prices. Pre-order upcoming harvests, receive seasonal insights, and join a thriving community of farmers and consumers.',
            textAlign: sw >= 900 ? TextAlign.left : TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.6),
              height: 1.7,
            ),
          ),
        ),
        const SizedBox(height: 40),

        // CTA Buttons
        Wrap(
          spacing: 14,
          runSpacing: 14,
          alignment: sw >= 900 ? WrapAlignment.start : WrapAlignment.center,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _heroCtaHovered = true),
              onExit: (_) => setState(() => _heroCtaHovered = false),
              child: GestureDetector(
                onTap: _completeWelcome,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(
                          alpha: _heroCtaHovered ? 0.25 : 0.1,
                        ),
                        blurRadius: _heroCtaHovered ? 28 : 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Browse Marketplace',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AgriColors.emerald700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _heroCtaHovered ? 0.05 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: AgriColors.emerald700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _heroSecondaryHovered = true),
              onExit: (_) => setState(() => _heroSecondaryHovered = false),
              child: GestureDetector(
                onTap: () => context.go('/register'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: _heroSecondaryHovered ? 0.12 : 0.05,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: _heroSecondaryHovered ? 0.5 : 0.25,
                      ),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Start Selling',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _heroVisual(double sw) {
    final visualWidth = sw < 768 ? sw * 0.8 : 380.0;
    final visualHeight = sw < 768 ? visualWidth * 1.1 : 420.0;
    return SizedBox(
      width: visualWidth,
      height: visualHeight,
      child: Stack(
        children: [
          // Main hero card
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            bottom: 40,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.04),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  children: [
                    // Background image of fresh produce
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/fresh_organic_hero.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: const BoxDecoration(
                              gradient: AgriColors.primaryGradient,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.eco_rounded,
                                color: Colors.white24,
                                size: 80,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Gradient overlay to make text readable
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.1),
                              Colors.black.withValues(alpha: 0.4),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Overlaid info
                    Positioned(
                      bottom: 24,
                      left: 24,
                      right: 24,
                      child: GlassCard(
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        borderColor: Colors.white.withValues(alpha: 0.3),
                        borderRadius: 16,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: AgriColors.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.eco_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '100% Fresh & Organic',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'Direct from verified farms',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Floating badge top-right
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: AgriColors.glowGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AgriColors.emerald400.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Trusted',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating mini stat card
          Positioned(
            bottom: 10,
            left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AgriColors.emerald50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.people_rounded,
                      size: 18,
                      color: AgriColors.emerald600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '200+ Farmers',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AgriColors.dark,
                        ),
                      ),
                      Text(
                        'Across the region',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AgriColors.muted,
                        ),
                      ),
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

  // ═══════════════════════════════════════════════════════════════
  // STATS BAR — animated counters in glassmorphism strip
  // ═══════════════════════════════════════════════════════════════
  Widget _buildStatsBar() {
    final sw = MediaQuery.of(context).size.width;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: sw < 768 ? 40 : 60),
      color: AgriColors.surface,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: sw < 768
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _statItem(
                              200,
                              '+',
                              'Farmers',
                              Icons.agriculture_rounded,
                              isMobile: true,
                            ),
                          ),
                          Expanded(
                            child: _statItem(
                              5000,
                              '+',
                              'Products',
                              Icons.inventory_2_rounded,
                              isMobile: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: _statItem(
                              24,
                              'hrs',
                              'Delivery',
                              Icons.local_shipping_rounded,
                              isMobile: true,
                            ),
                          ),
                          Expanded(
                            child: _statItem(
                              98,
                              '%',
                              'Happy',
                              Icons.thumb_up_rounded,
                              isMobile: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _statItem(
                      200,
                      '+',
                      'Local Farmers',
                      Icons.agriculture_rounded,
                    ),
                    _statDivider(),
                    _statItem(5000, '+', 'Products', Icons.inventory_2_rounded),
                    _statDivider(),
                    _statItem(
                      24,
                      'hrs',
                      'Fast Delivery',
                      Icons.local_shipping_rounded,
                    ),
                    _statDivider(),
                    _statItem(98, '%', 'Satisfaction', Icons.thumb_up_rounded),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _statItem(
    int value,
    String suffix,
    String label,
    IconData icon, {
    bool isMobile = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:
          isMobile ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        Container(
          width: isMobile ? 40 : 48,
          height: isMobile ? 40 : 48,
          decoration: BoxDecoration(
            gradient: AgriColors.primaryGradient,
            borderRadius: BorderRadius.circular(isMobile ? 12 : 14),
            boxShadow: [
              BoxShadow(
                color: AgriColors.emerald500.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: isMobile ? 18 : 22),
        ),
        SizedBox(width: isMobile ? 12 : 16),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedCounter(
                target: value,
                suffix: suffix,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isMobile ? 22 : 28,
                  fontWeight: FontWeight.w800,
                  color: AgriColors.dark,
                ),
              ),
              Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: isMobile ? 11 : 13,
                  color: AgriColors.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statDivider() {
    return Container(width: 1, height: 50, color: AgriColors.border);
  }

  // ═══════════════════════════════════════════════════════════════
  // FEATURES SECTION — hover cards with SVG leaf icons
  // ═══════════════════════════════════════════════════════════════
  Widget _buildFeaturesSection() {
    final features = [
      _Feature(
        Icons.eco_rounded,
        'Direct from Farmers',
        'Skip the middleman. Get the freshest produce at fair prices directly from verified local farms.',
        AgriColors.emerald500,
      ),
      _Feature(
        Icons.calendar_today_rounded,
        'Pre-Order Harvests',
        'Secure seasonal favorites before harvest and get exclusive early-bird pricing on premium produce.',
        const Color(0xFF3B82F6),
      ),
      _Feature(
        Icons.auto_awesome_rounded,
        'Smart Insights',
        'AI-powered weather alerts, demand predictions, and expert farming tips to optimize your experience.',
        const Color(0xFF8B5CF6),
      ),
      _Feature(
        Icons.people_rounded,
        'Community Driven',
        'Connect with consumers and farmers, share knowledge, exchange tips, and grow together.',
        const Color(0xFFF59E0B),
      ),
      _Feature(
        Icons.verified_rounded,
        'Verified Farmers',
        'Every farmer is identity-verified with transparent farm info, real reviews, and quality certificates.',
        const Color(0xFF06B6D4),
      ),
      _Feature(
        Icons.local_shipping_rounded,
        'Fast Delivery',
        'Farm-fresh produce picked and delivered to your door within 24 hours with proper care packaging.',
        const Color(0xFFEF4444),
      ),
    ];

    final sw = MediaQuery.of(context).size.width;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: sw < 480
            ? 16
            : sw < 768
            ? 24
            : 48,
        vertical: sw < 480
            ? 50
            : sw < 768
            ? 60
            : 100,
      ),
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // Section header
              const GradientDivider(width: 50, height: 4),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AgriColors.emerald50,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Text(
                  'WHY AGRIDIRECT',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AgriColors.emerald600,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Everything You Need',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: sw < 480
                      ? 28
                      : sw < 768
                      ? 32
                      : 40,
                  fontWeight: FontWeight.w800,
                  color: AgriColors.dark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'A complete ecosystem connecting farmers and consumers',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 16, color: AgriColors.muted),
              ),
              const SizedBox(height: 60),
              // Feature cards grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth < 768
                      ? 1
                      : (constraints.maxWidth < 1024 ? 2 : 3);
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
                      childAspectRatio: constraints.maxWidth < 480 
                          ? 2.0 
                          : constraints.maxWidth < 768 
                              ? 2.8 
                              : 1.3,
                    ),
                    itemCount: features.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, i) {
                      final f = features[i];
                      final isHovered = _hoveredFeature == i;
                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        onEnter: (_) => setState(() => _hoveredFeature = i),
                        onExit: (_) => setState(() => _hoveredFeature = -1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.all(28),
                          transform: Matrix4.translationValues(
                            0,
                            isHovered ? -8 : 0,
                            0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isHovered
                                  ? f.color.withValues(alpha: 0.3)
                                  : AgriColors.border,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isHovered
                                    ? f.color.withValues(alpha: 0.12)
                                    : Colors.black.withValues(alpha: 0.03),
                                blurRadius: isHovered ? 30 : 8,
                                offset: Offset(0, isHovered ? 16 : 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Icon container
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: isHovered
                                      ? f.color
                                      : f.color.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: isHovered
                                      ? [
                                          BoxShadow(
                                            color: f.color.withValues(
                                              alpha: 0.3,
                                            ),
                                            blurRadius: 16,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Icon(
                                  f.icon,
                                  color: isHovered ? Colors.white : f.color,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(height: 22),
                              Text(
                                f.title,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AgriColors.dark,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: Text(
                                  f.description,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: AgriColors.muted,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HOW IT WORKS — Numbered steps with connecting lines
  // ═══════════════════════════════════════════════════════════════
  Widget _buildHowItWorksSection() {
    final steps = [
      _Step(
        'Browse & Discover',
        'Explore fresh produce from verified local farmers. Filter by category, season, or organic certification.',
        Icons.search_rounded,
      ),
      _Step(
        'Order & Pre-Order',
        'Add items to cart or pre-order upcoming harvests. Secure the best seasonal produce before it sells out.',
        Icons.shopping_cart_rounded,
      ),
      _Step(
        'Farm-Fresh Delivery',
        'Produce is harvested and packed with care, then delivered directly to your doorstep within 24 hours.',
        Icons.local_shipping_rounded,
      ),
    ];

    final sw = MediaQuery.of(context).size.width;

    return Stack(
      children: [
        // Background with dot pattern
        Positioned.fill(child: Container(color: AgriColors.surface)),
        Positioned.fill(
          child: CustomPaint(
            painter: DotPatternPainter(
              opacity: 0.04,
              color: AgriColors.emerald600,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 100),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                children: [
                  const GradientDivider(width: 50, height: 4),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AgriColors.emerald50,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Text(
                      'HOW IT WORKS',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AgriColors.emerald600,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Simple as 1-2-3',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: sw < 480
                          ? 28
                          : sw < 768
                          ? 32
                          : 40,
                      fontWeight: FontWeight.w800,
                      color: AgriColors.dark,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 60),
                  if (sw < 768)
                    Column(
                      children: List.generate(steps.length, (i) {
                        final step = steps[i];
                        final isHovered = _hoveredStep == i;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 40),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            onEnter: (_) => setState(() => _hoveredStep = i),
                            onExit: (_) => setState(() => _hoveredStep = -1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              transform: Matrix4.translationValues(
                                0,
                                isHovered ? -8 : 0,
                                0,
                              ),
                              child: Column(
                                children: [
                                  _buildStepIcon(i, step, isHovered),
                                  const SizedBox(height: 20),
                                  Text(
                                    step.title,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: AgriColors.dark,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    step.description,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: AgriColors.muted,
                                      height: 1.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(steps.length, (i) {
                        final step = steps[i];
                        final isHovered = _hoveredStep == i;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: i == 0 ? 0 : 16,
                              right: i == steps.length - 1 ? 0 : 16,
                            ),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              onEnter: (_) => setState(() => _hoveredStep = i),
                              onExit: (_) => setState(() => _hoveredStep = -1),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                transform: Matrix4.translationValues(
                                  0,
                                  isHovered ? -8 : 0,
                                  0,
                                ),
                                child: Column(
                                  children: [
                                    _buildStepIcon(i, step, isHovered),
                                    const SizedBox(height: 28),
                                    Text(
                                      step.title,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: AgriColors.dark,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      step.description,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: AgriColors.muted,
                                        height: 1.6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TESTIMONIAL SECTION
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTestimonialSection() {
    final sw = MediaQuery.of(context).size.width;
    
    // Fallback static testimonial if no dynamic reviews exist
    final fallbackTestimonial = {
      'review_text': 'AgriDirect has completely transformed how we buy fresh produce. The quality is incomparable, and knowing exactly which farmer grew our food makes every meal special.',
      'rating': 5,
      'users': {'name': 'Sarah Jenkins'},
      'subtitle': 'Professional Chef, Manila',
    };

    final hasDynamic = _testimonials.isNotEmpty;
    final displayItems = hasDynamic ? _testimonials : [fallbackTestimonial];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: sw < 480
            ? 16
            : sw < 768
            ? 24
            : 48,
        vertical: sw < 480
            ? 50
            : sw < 768
            ? 60
            : 100,
      ),
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              const GradientDivider(width: 50, height: 4),
              const SizedBox(height: 20),
              
              // Carousel Container
              SizedBox(
                height: sw < 480 ? 420 : 380, // Adjust height based on screen size
                child: PageView.builder(
                  controller: _testimonialPageController,
                  itemCount: displayItems.length,
                  onPageChanged: (idx) {
                    setState(() {
                      _currentTestimonialIndex = idx;
                    });
                  },
                  itemBuilder: (context, index) {
                    final item = displayItems[index];
                    final text = item['review_text']?.toString() ?? '';
                    final rating = (item['rating'] as num?)?.toInt() ?? 5;
                    
                    final userData = item['users'] as Map<String, dynamic>? ?? {};
                    final name = userData['name']?.toString() ?? 'AgriDirect User';
                    final subtitle = item['subtitle']?.toString() ?? 'Verified Buyer';
                    
                    final initials = name.trim().split(' ').take(2).map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').join('');

                    return Container(
                      padding: EdgeInsets.all(sw < 480 ? 24 : 48),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: AgriColors.surface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AgriColors.border),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Quote icon
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: AgriColors.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AgriColors.emerald500.withValues(
                                    alpha: 0.25,
                                  ),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.format_quote_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Expanded(
                            child: Center(
                              child: SingleChildScrollView(
                                child: Text(
                                  '"$text"',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: sw < 480
                                        ? 16
                                        : sw < 768
                                        ? 18
                                        : 22,
                                    fontWeight: FontWeight.w600,
                                    color: AgriColors.dark,
                                    height: 1.6,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Container(height: 1, color: AgriColors.border),
                          const SizedBox(height: 24),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 14,
                            runSpacing: 14,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AgriColors.primaryGradient,
                                ),
                                child: Center(
                                  child: Text(
                                    initials,
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: sw < 480 
                                    ? CrossAxisAlignment.center 
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AgriColors.dark,
                                    ),
                                  ),
                                  Text(
                                    subtitle,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AgriColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                              if (sw >= 600) const SizedBox(width: 10),
                              // Stars
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(
                                  5,
                                  (starIdx) => Padding(
                                    padding: const EdgeInsets.only(right: 2),
                                    child: Icon(
                                      starIdx < rating
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      color: Colors.amber,
                                      size: 18,
                                    ),
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
              
              if (displayItems.length > 1) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    displayItems.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentTestimonialIndex == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentTestimonialIndex == index
                            ? AgriColors.emerald500
                            : AgriColors.emerald500.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CTA SECTION — gradient bg with animated waves
  // ═══════════════════════════════════════════════════════════════
  Widget _buildCtaSection() {
    final sw = MediaQuery.of(context).size.width;
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: sw < 480
                ? 16
                : sw < 768
                ? 24
                : 48,
            vertical: sw < 480
                ? 50
                : sw < 768
                ? 60
                : 100,
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF042F2E), Color(0xFF064E3B), Color(0xFF047857)],
            ),
          ),
          child: Stack(
            children: [
              // Floating particles
              const Positioned.fill(
                child: FloatingParticles(
                  count: 15,
                  maxSize: 2.5,
                  color: Color(0xFF34D399),
                  height: 300,
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AnimatedLeafIcon(
                            size: 48,
                            color: AgriColors.emerald300,
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: AgriColors.goldGradient,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AgriColors.gold400.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Text(
                              'JOIN FREE',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Start Your Fresh Journey Today',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: sw < 480
                              ? 28
                              : sw < 768
                              ? 32
                              : 42,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Join thousands of families enjoying farm-fresh produce delivered to their doorstep.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.6),
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 40),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        onEnter: (_) => setState(() => _ctaHovered = true),
                        onExit: (_) => setState(() => _ctaHovered = false),
                        child: GestureDetector(
                          onTap: _completeWelcome,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 44),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(
                                    alpha: _ctaHovered ? 0.25 : 0.1,
                                  ),
                                  blurRadius: _ctaHovered ? 32 : 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Explore Marketplace',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AgriColors.emerald700,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                AnimatedRotation(
                                  turns: _ctaHovered ? 0.05 : 0,
                                  duration: const Duration(milliseconds: 200),
                                  child: const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 20,
                                    color: AgriColors.emerald700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FOOTER — dark premium footer
  // ═══════════════════════════════════════════════════════════════
  Widget _buildAppDownloadSection() {
    final sw = MediaQuery.of(context).size.width;
    final isCompact = sw < 1100;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AgriColors.dark,
        gradient: AgriColors.auroraGradient,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 20 : 64,
        vertical: isCompact ? 64 : 120,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: isCompact
              ? Column(
                  children: [
                    _buildDownloadContent(isCompact: true),
                    const SizedBox(height: 64),
                    _buildBannerGallery(isCompact: true),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _buildDownloadContent(isCompact: false),
                    ),
                    const SizedBox(width: 64),
                    Expanded(
                      flex: 7,
                      child: _buildBannerGallery(isCompact: false),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildDownloadContent({required bool isCompact}) {
    return Column(
      crossAxisAlignment: isCompact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.rocket_launch_rounded,
                size: 14,
                color: AgriColors.lime400,
              ),
              const SizedBox(width: 8),
              Text(
                'GO MOBILE',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        GradientText(
          text: 'AgriDirect\nEverywhere.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: isCompact ? 48 : 72,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.0,
            letterSpacing: -2.5,
          ),
          gradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFA7F3D0)],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Connect with farmers, manage your shop, and track orders with the AgriDirect professional mobile suite.',
          textAlign: isCompact ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.inter(
            fontSize: 18,
            color: Colors.white.withValues(alpha: 0.7),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 56),
        _buildQrAndButtonDark(isCompact: isCompact),
      ],
    );
  }

  Widget _buildQrAndButtonDark({required bool isCompact}) {
    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildSmartphoneMockup(),
          const SizedBox(height: 48),
          Text(
            'Get it for Android',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '100% Safe & Verified APK Installation',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          Builder(
            builder: (context) {
              final sw = MediaQuery.of(context).size.width;
              final isDesktop = sw > 600;

              if (isDesktop) {
                final apkUrl = ApkDownloader.apkUrl;
                final qrUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=160x160&data=${Uri.encodeComponent(apkUrl)}';
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          qrUrl,
                          width: 160,
                          height: 160,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.qr_code_2_rounded,
                            size: 160,
                            color: Colors.white24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Scan to install on your phone',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                );
              }

              return _PulseDownloadButton(
                onTap: _downloadAndroidApk,
                fullWidth: true,
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_outlined, color: AgriColors.emerald400, size: 14),
              const SizedBox(width: 6),
              Text(
                'Virus-free & Malware-free guaranteed',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          _buildInstallationStepper(),
        ],
      );
    }

    final actionColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Get it for Android',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'AgriDirect APK v1.0.0\nSafe & Verified Scan',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.5),
            height: 1.5,
          ),
        ),
      ],
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Glassmorphic QR Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Builder(
                  builder: (context) {
                    final apkUrl = ApkDownloader.apkUrl;
                    final qrUrl =
                        'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${Uri.encodeComponent(apkUrl)}';
                    return Image.network(
                      qrUrl,
                      width: 280,
                      height: 280,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return SizedBox(
                          width: 280,
                          height: 280,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white24,
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.qr_code_2,
                        size: 280,
                        color: Colors.white24,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'SCAN TO INSTALL',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withValues(alpha: 0.6),
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 32),
        Flexible(child: actionColumn),
      ],
    );
  }

  Widget _buildSmartphoneMockup() {
    return Container(
      width: 280,
      height: 560,
      decoration: BoxDecoration(
        color: AgriColors.darkCard,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 8),
        boxShadow: [
          BoxShadow(
            color: AgriColors.emerald500.withValues(alpha: 0.15),
            blurRadius: 40,
            spreadRadius: 5,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: AgriColors.darkGradient,
          ),
          child: Column(
            children: [
              // Status bar simulator
              Container(
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '9:41',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: const [
                        Icon(Icons.signal_cellular_alt_rounded, color: Colors.white, size: 10),
                        SizedBox(width: 4),
                        Icon(Icons.wifi_rounded, color: Colors.white, size: 10),
                        SizedBox(width: 4),
                        Icon(Icons.battery_full_rounded, color: Colors.white, size: 10),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Notch
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 110,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // App mockup UI header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const BrandLogo(size: BrandLogoSize.small, inverted: true),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AgriColors.emerald500.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'PRO VERSION',
                        style: GoogleFonts.plusJakartaSans(
                          color: AgriColors.emerald400,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Mini features mockup
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // App main illustration/welcome
                      Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AgriColors.emerald800.withValues(alpha: 0.4),
                              AgriColors.emerald900.withValues(alpha: 0.4)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              right: -20,
                              bottom: -20,
                              child: Icon(
                                Icons.agriculture_rounded,
                                size: 120,
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Fresh from farm to table',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Direct connection, zero middle-men fees.',
                                    style: GoogleFonts.inter(
                                      color: Colors.white70,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Mock Dashboard item 1
                      _buildMockDashboardItem(
                        icon: Icons.storefront_rounded,
                        title: 'Manage Your Shop',
                        subtitle: 'List products and adjust pricing',
                        color: AgriColors.emerald400,
                      ),
                      const SizedBox(height: 10),
                      // Mock Dashboard item 2
                      _buildMockDashboardItem(
                        icon: Icons.shopping_bag_outlined,
                        title: 'Quick Purchasing',
                        subtitle: 'Secure checkout and order tracking',
                        color: AgriColors.lime400,
                      ),
                      const SizedBox(height: 10),
                      // Mock Dashboard item 3
                      _buildMockDashboardItem(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'Community Forums',
                        subtitle: 'Discuss farming practices',
                        color: AgriColors.teal400,
                      ),
                    ],
                  ),
                ),
              ),
              
              // Bottom Indicator Bar
              Container(
                height: 5,
                width: 100,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMockDashboardItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallationStepper() {
    final steps = [
      {
        'num': '1',
        'title': 'Download',
        'desc': 'Tap download button above to get the safe APK file.',
        'icon': Icons.download_rounded,
      },
      {
        'num': '2',
        'title': 'Allow Settings',
        'desc': 'Enable "Install from Unknown Sources" in your Android settings.',
        'icon': Icons.settings_suggest_rounded,
      },
      {
        'num': '3',
        'title': 'Enjoy',
        'desc': 'Open the app and log in to explore AgriDirect.',
        'icon': Icons.rocket_launch_rounded,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            'Simple 3-Step Installation',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...steps.map((s) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AgriColors.emerald500,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      s['num'] as String,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['title'] as String,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s['desc'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  s['icon'] as IconData,
                  color: AgriColors.emerald400.withValues(alpha: 0.6),
                  size: 20,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBannerGallery({required bool isCompact}) {
    final banners = [
      'assets/images/1.png',
      'assets/images/2.png',
      'assets/images/3.png',
    ];

    final galleryHeight = isCompact ? 400.0 : 600.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = galleryHeight;

        // Define banner dimensions
        final bannerWidth = isCompact ? width * 0.85 : 800.0;
        final bannerHeight = bannerWidth * (9 / 16);

        // Sort indices for Z-order
        final indices = List.generate(banners.length, (i) => i);
        indices.sort((a, b) {
          int posA = (a - _activeBannerIndex);
          if (posA < -1) posA += 3;
          if (posA > 1) posA -= 3;
          int posB = (b - _activeBannerIndex);
          if (posB < -1) posB += 3;
          if (posB > 1) posB -= 3;
          return posA.abs().compareTo(posB.abs());
        });
        final reversedIndices = indices.reversed.toList();

        return SizedBox(
          height: galleryHeight,
          width: width,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: reversedIndices.map((index) {
              int position = (index - _activeBannerIndex);
              if (position < -1) position += 3;
              if (position > 1) position -= 3;

              double scale = position == 0 ? 1.0 : 0.8;
              double opacity = position == 0 ? 1.0 : 0.4;

              // Calculate horizontal position
              double xOffset = (width - bannerWidth) / 2;
              if (position != 0) {
                xOffset += position * (isCompact ? 40 : 150);
              }

              // Calculate vertical position (center it)
              double yOffset = (height - bannerHeight) / 2;
              if (position != 0) {
                yOffset += 40; // Drop back-banners slightly
              }

              return AnimatedPositioned(
                key: ValueKey('banner_pos_$index'),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutBack,
                left: xOffset,
                top: yOffset,
                width: bannerWidth,
                height: bannerHeight,
                child: _buildBannerCard(
                  banners[index],
                  isCompact,
                  isMain: position == 0,
                  opacity: opacity,
                  scale: scale,
                  onTap: () {
                    setState(() {
                      // If clicking the front image, cycle to the next one
                      // If clicking a back image, bring it to the front
                      if (position == 0) {
                        _activeBannerIndex = (index + 1) % banners.length;
                      } else {
                        _activeBannerIndex = index;
                      }
                    });
                  },
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildBannerCard(
    String assetPath,
    bool isCompact, {
    bool isMain = false,
    double opacity = 1.0,
    double scale = 1.0,
    VoidCallback? onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutBack,
          child: AnimatedOpacity(
            opacity: opacity,
            duration: const Duration(milliseconds: 600),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isCompact ? 16 : 24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isMain ? 0.5 : 0.3),
                    blurRadius: isMain ? 60 : 40,
                    offset: Offset(0, isMain ? 30 : 20),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isCompact ? 16 : 24),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.asset(
                    assetPath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Container(color: Colors.white10),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FARMING EQUIPMENT & HARVEST BUNDLES SHOWCASE (Inspiration Screenshot 1)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildFarmingShowcaseSection() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 850;

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 48,
        vertical: isMobile ? 40 : 80,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // Spotlight 1: Farm Power Equipment & Yard Tools
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: isMobile
                      ? Column(
                          children: [
                            _buildShowcaseImage(
                              'https://images.unsplash.com/photo-1592417817098-8f3d6910985b?q=80&w=1000&auto=format&fit=crop',
                              height: 240,
                            ),
                            _buildShowcaseContent(
                              tag: 'FARM & YARD POWER MACHINERY',
                              title: 'Heavy-Duty Farming & Yard Equipment',
                              description:
                                  'Keep your farm, homestead, and crops in peak condition with certified high-durability outdoor power equipment. From motorized brushcutters and crop sprayers to solar boundary energizers, chainsaws, and water pumps. Built to withstand demanding agricultural conditions.',
                              buttonText: 'See The Full Range',
                              onTap: () => context.go(AppRoutes.shop),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: _buildShowcaseImage(
                                'https://images.unsplash.com/photo-1592417817098-8f3d6910985b?q=80&w=1000&auto=format&fit=crop',
                                height: 360,
                              ),
                            ),
                            Expanded(
                              flex: 6,
                              child: _buildShowcaseContent(
                                tag: 'FARM & YARD POWER MACHINERY',
                                title: 'Heavy-Duty Farming & Yard Equipment',
                                description:
                                    'Keep your farm, homestead, and crops in peak condition with certified high-durability outdoor power equipment. From motorized brushcutters and crop sprayers to solar boundary energizers, chainsaws, and water pumps. Built to withstand demanding agricultural conditions.',
                                buttonText: 'See The Full Range',
                                onTap: () => context.go(AppRoutes.shop),
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 36),

              // Spotlight 2: Farm-Direct Produce Bundles & Harvesting Sets
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFDCFCE7)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: isMobile
                      ? Column(
                          children: [
                            _buildShowcaseImage(
                              'https://images.unsplash.com/photo-1589923188900-85dae523342b?q=80&w=1000&auto=format&fit=crop',
                              height: 240,
                            ),
                            _buildShowcaseContent(
                              tag: 'FARM-TO-TABLE HARVEST BUNDLES',
                              title: 'Fresh Cooperative Harvest Boxes & Tools',
                              description:
                                  'Explore curated seasonal produce crates and essential farm accessories packed directly by verified agrarian cooperatives. High-nutrient organic staples, heirloom seeds, and protective gear delivered fresh at fair farm-gate pricing.',
                              buttonText: 'See Bundle Options',
                              onTap: () => context.go(AppRoutes.freshProduce),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              flex: 6,
                              child: _buildShowcaseContent(
                                tag: 'FARM-TO-TABLE HARVEST BUNDLES',
                                title: 'Fresh Cooperative Harvest Boxes & Tools',
                                description:
                                    'Explore curated seasonal produce crates and essential farm accessories packed directly by verified agrarian cooperatives. High-nutrient organic staples, heirloom seeds, and protective gear delivered fresh at fair farm-gate pricing.',
                                buttonText: 'See Bundle Options',
                                onTap: () => context.go(AppRoutes.freshProduce),
                              ),
                            ),
                            Expanded(
                              flex: 5,
                              child: _buildShowcaseImage(
                                'https://images.unsplash.com/photo-1589923188900-85dae523342b?q=80&w=1000&auto=format&fit=crop',
                                height: 360,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShowcaseImage(String url, {required double height}) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: const Color(0xFF005A36),
          child: const Center(
            child: Icon(Icons.agriculture_rounded, color: Colors.white24, size: 64),
          ),
        ),
      ),
    );
  }

  Widget _buildShowcaseContent({
    required String tag,
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF005A36).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              tag,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF005A36),
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF005A36),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 14.5,
              color: const Color(0xFF475569),
              height: 1.65,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF005A36),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              buttonText,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FEATURED LOCAL FARMERS SPOTLIGHT
  // ═══════════════════════════════════════════════════════════════
  Widget _buildFeaturedFarmersSection() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    final farmers = [
      {
        'name': 'Danilo "Mang Danny" Santos',
        'coop': 'Benguet Highland Growers Co-op',
        'location': 'La Trinidad, Benguet',
        'experience': '24 Years Farming',
        'crops': 'Highland Lettuce, Strawberries, Heirloom Carrots',
        'image': 'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?q=80&w=800&auto=format&fit=crop',
      },
      {
        'name': 'Teresa "Aling Tess" Ramos',
        'coop': 'Isabela Organic Grains Association',
        'location': 'Cauayan, Isabela',
        'experience': '19 Years Farming',
        'crops': 'Organic Dinorado, Black Rice & Sweet Corn',
        'image': 'https://images.unsplash.com/photo-1595974482597-4b8da8879bc5?q=80&w=800&auto=format&fit=crop',
      },
      {
        'name': 'Ramon Fernandez',
        'coop': 'Bukidnon Highland Orchards',
        'location': 'Malaybalay, Bukidnon',
        'experience': '16 Years Farming',
        'crops': 'Hass Avocados, Heirloom Cacao & Dragonfruit',
        'image': 'https://images.unsplash.com/photo-1523741543316-beb7fc7023d8?q=80&w=800&auto=format&fit=crop',
      },
    ];

    return Container(
      width: double.infinity,
      color: const Color(0xFFF8FAFC),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 48,
        vertical: isMobile ? 48 : 80,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              const GradientDivider(width: 50, height: 4),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AgriColors.emerald50,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Text(
                  'MEET OUR VERIFIED GROWERS',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF005A36),
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Direct from the Hands that Feed Us',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isMobile ? 26 : 36,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Every product on AgriDirect is traceable to certified local farmers receiving 100% fair farm-gate pricing.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 15, color: AgriColors.muted),
              ),
              const SizedBox(height: 48),

              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth < 768 ? 1 : 3;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
                      childAspectRatio: cols == 1 ? 1.2 : 0.82,
                    ),
                    itemCount: farmers.length,
                    itemBuilder: (context, index) {
                      final f = farmers[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AspectRatio(
                                aspectRatio: 16 / 10,
                                child: Image.network(
                                  f['image']!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(color: const Color(0xFF005A36)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.verified_rounded, color: Color(0xFF005A36), size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          f['experience']!,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF005A36),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      f['name']!,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      f['location']!,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Crops: ${f['crops']!}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        color: const Color(0xFF475569),
                                        height: 1.4,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        onPressed: () => context.go(AppRoutes.shop),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF005A36),
                                          side: const BorderSide(color: Color(0xFF005A36)),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                        ),
                                        child: Text(
                                          'Explore Farmer\'s Produce',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // DEPARTMENT OF AGRICULTURE (DA) ARTICLES SECTION (Inspiration Screenshot 2)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildDaArticlesSection() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    final previewArticles = _liveDaArticles.take(4).toList();
    if (previewArticles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 48,
        vertical: isMobile ? 48 : 80,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF005A36).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_rounded, color: Color(0xFF005A36), size: 14),
                              const SizedBox(width: 6),
                              Text(
                                'DEPARTMENT OF AGRICULTURE (DA) BULLETINS',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF005A36),
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'All Articles & Farming Guides',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: isMobile ? 26 : 36,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF005A36),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Field advisories, drought resilience insights, and technical advice from DA experts.',
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isMobile)
                    ElevatedButton.icon(
                      onPressed: () => context.go('/articles'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF005A36),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: Text(
                        'View All Articles',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 40),

              // 4 Cards Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth < 650
                      ? 1
                      : constraints.maxWidth < 1000
                          ? 2
                          : 4;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
                      childAspectRatio: crossAxisCount == 1 ? 1.05 : 0.72,
                    ),
                    itemCount: previewArticles.length,
                    itemBuilder: (context, index) {
                      final item = previewArticles[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AspectRatio(
                                aspectRatio: 16 / 10,
                                child: Image.network(
                                  item.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(color: const Color(0xFF005A36)),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF005A36),
                                          height: 1.3,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        item.date,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Expanded(
                                        child: Text(
                                          item.summary,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: const Color(0xFF64748B),
                                            height: 1.45,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () => context.go('/articles?id=${item.id}'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF005A36),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                          ),
                                          child: Text(
                                            'Read more',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

              if (isMobile) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/articles'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF005A36),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text(
                      'View All Articles',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper: Step Icon Circle ──
  Widget _buildStepIcon(int index, _Step step, bool isHovered) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        gradient: isHovered ? AgriColors.primaryGradient : null,
        color: isHovered ? null : Colors.white,
        shape: BoxShape.circle,
        border: isHovered
            ? null
            : Border.all(
                color: AgriColors.emerald200,
                width: 2,
              ),
        boxShadow: [
          BoxShadow(
            color: isHovered
                ? AgriColors.emerald500.withValues(alpha: 0.3)
                : Colors.black.withValues(
                    alpha: 0.05,
                  ),
            blurRadius: isHovered ? 24 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: isHovered
            ? Icon(
                step.icon,
                color: Colors.white,
                size: 28,
              )
            : Text(
                '${index + 1}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AgriColors.emerald600,
                ),
              ),
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  const _Feature(this.icon, this.title, this.description, this.color);
}

class _Step {
  final String title;
  final String description;
  final IconData icon;
  const _Step(this.title, this.description, this.icon);
}

class _PulseDownloadButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool fullWidth;

  const _PulseDownloadButton({
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  State<_PulseDownloadButton> createState() => _PulseDownloadButtonState();
}

class _PulseDownloadButtonState extends State<_PulseDownloadButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(begin: 8.0, end: 24.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.05 : _scaleAnimation.value,
          duration: const Duration(milliseconds: 200),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                width: widget.fullWidth ? double.infinity : null,
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AgriColors.emerald400, AgriColors.emerald600],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AgriColors.emerald500.withValues(
                        alpha: _isHovered ? 0.6 : 0.35,
                      ),
                      blurRadius: _isHovered ? 28 : _glowAnimation.value,
                      spreadRadius: _isHovered ? 2 : 0,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.android_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Download APK',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'v1.0.0',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
