import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Home Screen matching the design mockup.
/// Delivery location, search bar, AI Market Insight, Categories, Featured Farmers.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const Color primary = Color(0xFF13EC5B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAIMarketInsight(),
                    _buildCategories(),
                    _buildFeaturedFarmers(context),
                    _buildCommunitySection(context),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header: Delivery location + Notification + Search ──
  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Delivering to
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivering to',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.location_on, color: primary, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          'San Francisco, CA',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Notification bell
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(
                        Icons.notifications_outlined,
                        size: 22,
                        color: Color(0xFF334155),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF13EC5B),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search bar
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Icon(Icons.search, color: Colors.grey[400], size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Search fresh produce or farms...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.tune, color: Colors.white, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── AI Market Insight Banner ──
  Widget _buildAIMarketInsight() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEFFFF4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: primary.withValues(alpha: 0.15)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'AI MARKET INSIGHT',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: primary,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  'Updated 5m ago',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Seasonal Tomato Alert!',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
                children: const [
                  TextSpan(text: 'Tomato prices are down '),
                  TextSpan(
                    text: '12%',
                    style: TextStyle(
                      color: Color(0xFF13EC5B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text:
                        ' this week in local farms. Best time to stock up for sauces!',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                // Shop Tomatoes button
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Shop Tomatoes',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(Icons.trending_down, color: primary, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Market Low',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Categories Section ──
  Widget _buildCategories() {
    final categories = [
      _CategoryData(Icons.bolt, 'Vegetables', const Color(0xFFE0F7F3), primary),
      _CategoryData(
        Icons.spa,
        'Fruits',
        const Color(0xFFFFF7ED),
        const Color(0xFFEA580C),
      ),
      _CategoryData(
        Icons.grass,
        'Grains',
        const Color(0xFFFFFBEB),
        const Color(0xFFD97706),
      ),
      _CategoryData(
        Icons.water_drop,
        'Dairy',
        const Color(0xFFEFF6FF),
        const Color(0xFF2563EB),
      ),
      _CategoryData(
        Icons.egg_alt,
        'Organic',
        const Color(0xFFECFDF5),
        const Color(0xFF15803D),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Categories',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                'See all',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (_, i) {
                final cat = categories[i];
                return _buildCategoryItem(
                  cat.icon,
                  cat.label,
                  cat.bgColor,
                  cat.iconColor,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(
    IconData icon,
    String label,
    Color bgColor,
    Color iconColor,
  ) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, size: 28, color: iconColor),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  // ── Featured Farmers Section ──
  Widget _buildFeaturedFarmers(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Featured Farmers',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Row(
                children: [
                  Text(
                    'View map',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 310,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (_, index) {
                final farmers = [
                  _FarmerData(
                    imageUrl:
                        'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=600',
                    name: 'Green Valley Organic',
                    distance: '2.4 miles away',
                    specialty: 'Specializes in root veggies',
                    rating: '4.9',
                    badge: 'TOP RATED',
                    tags: ['Carrots', 'Potatoes', 'Kale'],
                  ),
                  _FarmerData(
                    imageUrl:
                        'https://images.unsplash.com/photo-1464226184884-fa280b87c399?w=600',
                    name: 'Sunny Orchards',
                    distance: '5.1 miles away',
                    specialty: 'Fresh seasonal fruits',
                    rating: '4.7',
                    badge: 'ORGANIC',
                    tags: ['Strawberries', 'Apples'],
                  ),
                  _FarmerData(
                    imageUrl:
                        'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?w=600',
                    name: 'Valley Harvest',
                    distance: '3.8 miles away',
                    specialty: 'Mixed seasonal produce',
                    rating: '4.6',
                    badge: 'LOCAL PICK',
                    tags: ['Tomatoes', 'Peppers', 'Herbs'],
                  ),
                ];
                return _buildFarmerCard(farmers[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmerCard(_FarmerData farmer) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: CachedNetworkImage(
                  imageUrl: farmer.imageUrl,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(height: 150, color: Colors.grey[200]),
                  errorWidget: (_, __, ___) => Container(
                    height: 150,
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.landscape,
                      size: 40,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              // Badge
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    farmer.badge,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        farmer.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.star, size: 16, color: Color(0xFFFBBF24)),
                    const SizedBox(width: 4),
                    Text(
                      farmer.rating,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${farmer.distance} · ${farmer.specialty}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // Tags
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: farmer.tags
                      .map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tag,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Community Section ──
  Widget _buildCommunitySection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Community',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                'View all',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Quick discussions section
          Row(
            children: [
              Expanded(
                child: _buildCommunityCard(
                  icon: Icons.groups_rounded,
                  title: 'Ask Farmers',
                  subtitle: 'Get advice from local farmers',
                  bgColor: const Color(0xFFECFDF5),
                  iconColor: primary,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCommunityCard(
                  icon: Icons.lightbulb_outline,
                  title: 'Tips & Tricks',
                  subtitle: 'Learn farming best practices',
                  bgColor: const Color(0xFFFFFBEB),
                  iconColor: const Color(0xFFD97706),
                  onTap: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Community posts
          _buildCommunityPostCard(
            authorName: 'Sarah Martinez',
            authorRole: 'Vegetable Farmer',
            timeAgo: '2 hours ago',
            postContent: 'Just harvested the best tomatoes this season! 🍅',
            likes: '124',
            comments: '23',
          ),
          const SizedBox(height: 12),
          _buildCommunityPostCard(
            authorName: "John's Organic Farm",
            authorRole: 'Certified Organic',
            timeAgo: '4 hours ago',
            postContent:
                'Who else is preparing for the spring planting season? Tips welcome!',
            likes: '89',
            comments: '15',
          ),
          const SizedBox(height: 16),
          // View full community hub button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: primary),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, color: primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'View Full Community Hub',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: primary,
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

  Widget _buildCommunityCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: iconColor),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityPostCard({
    required String authorName,
    required String authorRole,
    required String timeAgo,
    required String postContent,
    required String likes,
    required String comments,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author info
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person, color: primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authorName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          authorRole,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '· $timeAgo',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Post content
          Text(
            postContent,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          // Engagement metrics
          Row(
            children: [
              Icon(Icons.favorite_outline, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                likes,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              const SizedBox(width: 16),
              Icon(Icons.message_outlined, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                comments,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryData {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color iconColor;
  const _CategoryData(this.icon, this.label, this.bgColor, this.iconColor);
}

class _FarmerData {
  final String imageUrl;
  final String name;
  final String distance;
  final String specialty;
  final String rating;
  final String badge;
  final List<String> tags;
  const _FarmerData({
    required this.imageUrl,
    required this.name,
    required this.distance,
    required this.specialty,
    required this.rating,
    required this.badge,
    required this.tags,
  });
}
