import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'preorder_product_details.dart';

/// Mobile-only Marketplace Home.
/// No web/responsive branches - purely mobile UI.
class ConsumerMarketplaceHome extends StatelessWidget {
  const ConsumerMarketplaceHome({super.key});

  static const Color primary = Color(0xFF13EC5B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFCFA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildAIInsightsBanner(),
                    _buildCategories(),
                    _buildPreOrderSection(context),
                    _buildFarmsNearYou(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: primary, size: 20),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DELIVER TO',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[400],
                      letterSpacing: 1.2,
                    ),
                  ),
                  Row(
                    children: [
                      const Text(
                        'San Carlos City, Pangasinan',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Icon(
                        Icons.expand_more,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(Icons.notifications_outlined, size: 20),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search produce...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey[400],
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIInsightsBanner() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primary.withValues(alpha: 0.15),
              primary.withValues(alpha: 0.05),
            ],
          ),
          border: Border.all(color: primary.withValues(alpha: 0.2)),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(
                Icons.psychology,
                size: 120,
                color: primary.withValues(alpha: 0.15),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'AI INSIGHTS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: primary,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Trending Crops: Tomatoes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tomatoes are at peak quality and 15% cheaper this week.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'View Insights',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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
  }

  Widget _buildCategories() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Shop by Category',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              Text(
                'View All',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _buildCategoryItem(
                Icons.eco,
                'Vegetables',
                const Color(0xFFECFDF5),
                const Color(0xFF059669),
              ),
              _buildCategoryItem(
                Icons.apple,
                'Fruits',
                const Color(0xFFFFF7ED),
                const Color(0xFFEA580C),
              ),
              _buildCategoryItem(
                Icons.grain,
                'Grains',
                const Color(0xFFFFFBEB),
                const Color(0xFFD97706),
              ),
              _buildCategoryItem(
                Icons.local_florist,
                'Organic',
                const Color(0xFFECFDF5),
                const Color(0xFF15803D),
              ),
            ],
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, size: 36, color: iconColor),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildPreOrderSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  'Pre-Order Special',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Text(
                    'Limited Offer',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Upcoming Harvests',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildPreOrderCard(
                  context,
                  imageUrl:
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuC3s936BvGOwFH5Pc8hRKIB2w1ylddc7XqdTh2n_z740ysBDvNPiQGq-eBGDkmN4Nv4YLrDQy5kon3ABU7rTEBhPq_8YTJabLHxNGJT8pD5PwiPsdVd_aMWZrsiO2tDr_BoHp3L2C6e1IGVNVNhnO0ewUPLxMLf03rC1tP_Kl31p2fkib4GvCE1epTRTN53gFWgqQPnYgSfvzTSDv_TOwVRzOQS-DLnnh5C6Pd7p1q0VGvBFr04swnJVDQUhNcp4FKqhUV5T_WkTeXI',
                  harvestDays: '5',
                  name: 'Premium Vine Tomatoes',
                  farm: 'Poblacion Farm, Benguet',
                  price: '120',
                  unit: '/kg',
                ),
                const SizedBox(width: 16),
                _buildPreOrderCard(
                  context,
                  imageUrl:
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuDFaQTdzl2IyUcUoH9jfP_TSPARzBFAvJbQjZzvoOUI90R72wmj1N0SWz8tRpAJXORbY4ZX1Y_MEd7edirhUW2pwMpLcSU9UQ53SgUQIepuy04PJrtUIp1PKE3Sgu4DxYdo-pi5CwQzWz-IGFRzRk-1b0WacMgkbNW-EgnkAt0EKqe-p0l2t7rlclG_rZtSn-fNIIBggUTiLr-Jn8q86JU79X3teeNt4tA4Hz-cFcy4F29m23EvZhmsCHJlvvDGias0ukkLoPZ6_c0F',
                  harvestDays: '3',
                  name: 'Organic Cauliflower',
                  farm: 'Green Valley, Batangas',
                  price: '85',
                  unit: '/pc',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreOrderCard(
    BuildContext context, {
    required String imageUrl,
    required String harvestDays,
    required String name,
    required String farm,
    required String price,
    required String unit,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PreorderProductDetails()),
        );
      },
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE8EFF5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(height: 120, color: Colors.grey[200]),
                    errorWidget: (_, __, ___) =>
                        Container(height: 120, color: Colors.grey[200]),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$harvestDays days',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    farm,
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: price,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: primary,
                              ),
                            ),
                            TextSpan(
                              text: unit,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Icon(Icons.add, size: 18, color: primary),
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
  }

  Widget _buildFarmsNearYou() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Farms Near You',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              Icon(Icons.filter_list, color: Colors.grey[400], size: 20),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildProductCard(
                  imageUrl:
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuCzaycfp36jzsWuHU3oZT7Xz3dqm0ERiWpttIP6--gPaasAI-N0F4f3b8F9Mnciub2heSQEAfkHrzCY5qT7JOvNS4_2sRHlBTrDH80hlwNUocAXAJJVpEeY1rPlOKjOgwpbHRA1GxAuVV8hkZb3dhsIe8YZhcKGjYUqgTcXeW1_yYUV6iyvEgQzTflMAGfHI5JamjQk6AIk4N1GvNHsT0ny3WJPyU4pvxa9GJ76A3-cRDTR8CZUXzGCUqv0Z3PLE6e2_WOUtHq5rAxr',
                  rating: '4.8',
                  reviews: '120',
                  name: 'Sweet Carabao Mango',
                  farm: 'Vibrant Farms',
                  price: '180',
                  unit: '/kg',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildProductCard(
                  imageUrl:
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuBACl6FiXMfquE6zNBeNtkQhdEIqZkwlURp2Xh--BjMgMWluRDSrD0FdAHwUSnj_1WglWmFfeuICooOHlBeyWkksKYez20U4E4VRpn1_HFgvdcmb4ym3thUmEJjE7w_j71FLDP09M9wTLHGdNCqUzj8ByzMCDBo_xRjljPqUHgFW0AD4GAYUQx45xU9-84M2nt4lKfvDGw4VHewq4WmunWk2KIS89kjjJ-B9fi8MMxDBl7jgn4iA3Qg9Tp2wVsdVnFfEQTeo04yWpJC',
                  rating: '4.9',
                  reviews: '86',
                  name: 'Organic Spinach',
                  farm: 'Luntian Gardens',
                  price: '45',
                  unit: '/bunch',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard({
    required String imageUrl,
    required String rating,
    required String reviews,
    required String name,
    required String farm,
    required String price,
    required String unit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 1,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.grey[200]),
                  errorWidget: (_, __, ___) =>
                      Container(color: Colors.grey[200]),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(Icons.favorite_border, size: 18),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.star, size: 14, color: Color(0xFFFBBF24)),
            const SizedBox(width: 4),
            Text(
              rating,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 4),
            Text(
              '($reviews)',
              style: TextStyle(fontSize: 10, color: Colors.grey[400]),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          farm,
          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: price,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const TextSpan(text: ' '),
              TextSpan(
                text: unit,
                style: TextStyle(fontSize: 10, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
