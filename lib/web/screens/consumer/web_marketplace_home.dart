import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

/// Web Marketplace Home — Modern Design with Animations
/// Clean, professional e-commerce marketplace with smooth transitions
class WebMarketplaceHome extends StatefulWidget {
  final Function(int) onNavigate;
  final int currentIndex;

  const WebMarketplaceHome({
    super.key,
    required this.onNavigate,
    required this.currentIndex,
  });

  @override
  State<WebMarketplaceHome> createState() => _WebMarketplaceHomeState();
}

class _WebMarketplaceHomeState extends State<WebMarketplaceHome>
    with TickerProviderStateMixin {
  static const Color _primary = Color(0xFF10B981);
  static const Color _accent = Color(0xFF00D45F);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFFAFAFA);
  static const Color _white = Color(0xFFFFFFFF);
  // ─── Animation Controllers ───
  late AnimationController _fadeInController;
  late AnimationController _slideUpController;
  late List<AnimationController> _cardControllers;
  
  // ─── Hover State ───
  final _hoveredCards = <int>{};
  final _hoveredButtons = <String>{};

  @override
  void initState() {
    super.initState();
    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _slideUpController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();

    // Create controllers for farmer cards (4 cards)
    _cardControllers = List.generate(
      4,
      (_) => AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      ),
    );

    // Stagger the card animations
    Future.delayed(const Duration(milliseconds: 300), () {
      for (int i = 0; i < _cardControllers.length; i++) {
        Future.delayed(Duration(milliseconds: i * 100), () {
          if (mounted) _cardControllers[i].forward();
        });
      }
    });
  }

  @override
  void dispose() {
    _fadeInController.dispose();
    _slideUpController.dispose();
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            _buildHeroBanner(),
            _buildCategoriesSection(),
            _buildFeaturedFarmersSection(),
            _buildTrendingProductsSection(),
            _buildMapSection(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ─── Header ───
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
      color: _white,
      child: Row(
        children: [
          // Logo
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => widget.onNavigate(0),
              child: Row(
                children: [
                  Image.asset(
                    'assets/icon/logo.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AGRIDIRECT',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 48),
          // Navigation
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeaderNavItem('Home', isActive: true, onTap: () => widget.onNavigate(0)),
              const SizedBox(width: 32),
              _buildHeaderNavItem('Shop', onTap: () => widget.onNavigate(1)),
              const SizedBox(width: 32),
              _buildHeaderNavItem('Community', onTap: () => widget.onNavigate(2)),
              const SizedBox(width: 32),
              _buildHeaderNavItem('About Us', onTap: () {}),
            ],
          ),
          const Spacer(),
          // Search bar
          Container(
            width: 280,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 18, color: _muted),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search produce',
                      hintStyle: TextStyle(color: _muted, fontSize: 13),
                      border: InputBorder.none,
                    ),
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Profile icon
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => widget.onNavigate(3),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: _border),
                ),
                child: Icon(Icons.person_outline_rounded, size: 20, color: _dark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderNavItem(String text, {bool isActive = false, required VoidCallback onTap}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? _primary : _dark,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 16,
              height: 2,
              decoration: BoxDecoration(
                color: isActive ? _primary : Colors.transparent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Hero Banner ───
  Widget _buildHeroBanner() {
    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF1B5E3D),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Fresh from the\nFarm to Your\nDoorstep.',
                    style: GoogleFonts.manrope(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Direct-to-consumer marketplace connecting you\nwith local growers and high-quality seasonal produce.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        onEnter: (_) => setState(() => _hoveredButtons.add('shop')),
                        onExit: (_) => setState(() => _hoveredButtons.remove('shop')),
                        child: AnimatedScale(
                          scale: _hoveredButtons.contains('shop') ? 1.05 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: _hoveredButtons.contains('shop') ? const Color(0xFF00D45F) : _accent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _hoveredButtons.contains('shop')
                                  ? [
                                      BoxShadow(
                                        color: _accent.withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Text(
                              'Shop Now',
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _dark,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        onEnter: (_) => setState(() => _hoveredButtons.add('farmers')),
                        onExit: (_) => setState(() => _hoveredButtons.remove('farmers')),
                        child: AnimatedScale(
                          scale: _hoveredButtons.contains('farmers') ? 1.05 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              border: Border.all(
                                color: Colors.white,
                                width: _hoveredButtons.contains('farmers') ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Meet Our Farmers',
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 48),
            Expanded(
              child: Container(
                height: 280,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Icon(
                    Icons.local_florist_rounded,
                    size: 120,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Categories Section ───
  Widget _buildCategoriesSection() {
    final categories = [
      'Vegetables',
      'Fruits',
      'Grains',
      'Dairy',
      'Eggs',
      'Honey',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
      color: _white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.eco_rounded, color: _primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Browse Categories',
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _dark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: categories
                .asMap()
                .entries
                .map((entry) {
                  final index = entry.key;
                  final cat = entry.value;
                  final isHovered = _hoveredCards.contains(index);
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => _hoveredCards.add(index)),
                    onExit: (_) => setState(() => _hoveredCards.remove(index)),
                    child: AnimatedScale(
                      scale: isHovered ? 1.08 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isHovered ? _primary.withValues(alpha: 0.1) : _surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isHovered ? _primary : _border,
                            width: isHovered ? 2 : 1,
                          ),
                          boxShadow: isHovered
                              ? [
                                  BoxShadow(
                                    color: _primary.withValues(alpha: 0.15),
                                    blurRadius: 8,
                                  ),
                                ]
                              : [],
                        ),
                        child: Text(
                          cat,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isHovered ? _primary : _dark,
                          ),
                        ),
                      ),
                    ),
                  );
                })
                .toList(),
          ),
        ],
      ),
    );
  }

  // ─── Featured Farmers Section ───
  Widget _buildFeaturedFarmersSection() {
    final farmers = [
      {
        'name': 'Green Valley Orchards',
        'location': 'Sonoma, California',
        'products': 'Apples, Peaches',
        'image': 'assets/images/farmer1.jpg',
      },
      {
        'name': "Miller's Dairy Farm",
        'location': 'Lancaster, Pennsylvania',
        'products': 'Raw Milk, Artisan Cheese',
        'image': 'assets/images/farmer2.jpg',
      },
      {
        'name': 'Sunshine Acres',
        'location': 'Heirloom Veggies',
        'products': 'Heirloom Veggies',
        'image': 'assets/images/farmer3.jpg',
      },
      {
        'name': 'Riverband Grain Co.',
        'location': 'Eugene, Oregon',
        'products': 'Sourdough Flour, Oats',
        'image': 'assets/images/farmer4.jpg',
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
      color: _surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Featured Farmers',
                    style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Support the people behind your food.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _muted,
                    ),
                  ),
                ],
              ),
              Text(
                'View All',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          GridView.count(
            crossAxisCount: 4,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.85,
            children: farmers
                .asMap()
                .entries
                .map((entry) => _buildAnimatedFarmerCard(
                      entry.key,
                      entry.value['name']!,
                      entry.value['location']!,
                      entry.value['products']!,
                      entry.value['image']!,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedFarmerCard(
    int index,
    String name,
    String location,
    String products,
    String image,
  ) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _cardControllers[index], curve: Curves.easeInOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _cardControllers[index], curve: Curves.easeOutCubic),
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hoveredCards.add(index + 100)),
          onExit: (_) => setState(() => _hoveredCards.remove(index + 100)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hoveredCards.contains(index + 100) ? _primary : _border,
              ),
              boxShadow: _hoveredCards.contains(index + 100)
                  ? [
                      BoxShadow(
                        color: _primary.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      color: Colors.grey[300],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: image,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          color: Colors.grey[300],
                        ),
                        errorWidget: (_, _, _) => Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.image),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _dark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: _muted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          products,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: _muted,
                            height: 1.4,
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
    );
  }

  // ─── Trending Products Section ───
  Widget _buildTrendingProductsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
      color: _white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trending Products',
                    style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "What's in season and popular right now.",
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _muted,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _border),
                    ),
                    child: const Icon(Icons.chevron_left, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.chevron_right, size: 20, color: _dark),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 320,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildTrendingProductCard('Organic Heirloom Carrots', '\$4.50', 'Bunch'),
                const SizedBox(width: 20),
                _buildTrendingProductCard('Wildflower Honey', '\$12.00', '500g JAR'),
                const SizedBox(width: 20),
                _buildTrendingProductCard('Fresh Strawberries', '\$6.50', '1LB BOX'),
                const SizedBox(width: 20),
                _buildTrendingProductCard('Artisan Sourdough', '\$8.00', 'PER LOAF'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingProductCard(String name, String price, String unit) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                color: Colors.grey[400],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.image,
                      size: 60,
                      color: Colors.grey[600],
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_border,
                        size: 16,
                        color: _dark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _dark,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.eco_rounded, size: 14, color: _primary),
                          const SizedBox(width: 6),
                          Text(
                            'Local Organics',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            price,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _dark,
                            ),
                          ),
                          Text(
                            unit,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add, size: 16, color: _accent),
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

  // ─── Map Section ───
  Widget _buildMapSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
      color: _surface,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEARBY',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _accent,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Find Producers in Your Area',
                  style: GoogleFonts.manrope(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'We partner with over 1,200 local farms across the country.\nUse our interactive map to find sustainable agriculture\nhappening right in your backyard.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: _muted,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBenefit('Same-day delivery in selected metro areas'),
                    const SizedBox(height: 12),
                    _buildBenefit('Carbon-neutral shipping options'),
                    const SizedBox(height: 12),
                    _buildBenefit('Direct farmer support fund contribution'),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Open Interactive Map',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
          Expanded(
            child: Container(
              height: 400,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.map,
                      size: 80,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefit(String text) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: _primary,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.check, size: 12, color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: _dark,
          ),
        ),
      ],
    );
  }

  // ─── Footer ───
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
      color: Color(0xFF0F172A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Center(
                            child: Text(
                              'A',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AGRIDIRECT',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sustainable, direct-to-consumer marketplace.\nConnecting food lovers with local producers\nthrough technology and trust.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSocialIcon(Icons.language),
                        const SizedBox(width: 12),
                        _buildSocialIcon(Icons.facebook),
                        const SizedBox(width: 12),
                        _buildSocialIcon(Icons.mail),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Marketplace',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFooterLink('Shop All Produce'),
                    _buildFooterLink('Seasonal Specials'),
                    _buildFooterLink('Bulk Orders'),
                    _buildFooterLink('Subscription Boxes'),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'For Partners',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFooterLink('Sell/Farm/Connect'),
                    _buildFooterLink('Logistics Partners'),
                    _buildFooterLink('Success Stories'),
                    _buildFooterLink('Seller Dashboard'),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subscribe',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Get weekly updates on what\'s in season.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Email address',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                                border: InputBorder.none,
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'JOIN',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _dark,
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
          const SizedBox(height: 40),
          Divider(color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '© 2024 AGRIDIRECT | Marketplace. All rights reserved.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFooterLink('Privacy Policy', small: true),
                  const SizedBox(width: 24),
                  _buildFooterLink('Terms of Service', small: true),
                  const SizedBox(width: 24),
                  _buildFooterLink('Cookie Policy', small: true),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Icon(icon, size: 14, color: Colors.white),
    );
  }

  Widget _buildFooterLink(String text, {bool small = false}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: small ? 11 : 12,
          color: Colors.white.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
