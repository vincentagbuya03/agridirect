import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/widgets/app_shimmer_loader.dart';

class LocalShopsScreen extends StatefulWidget {
  const LocalShopsScreen({super.key});

  @override
  State<LocalShopsScreen> createState() => _LocalShopsScreenState();
}

class _LocalShopsScreenState extends State<LocalShopsScreen> {
  late Future<List<Map<String, dynamic>>> _shopsFuture;

  @override
  void initState() {
    super.initState();
    _shopsFuture = SupabaseDataService().getFeaturedFarmers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: _buildCommunityHero()),
          _buildShopList(),
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: const Color(0xFFFAFAFA),
      elevation: 0,
      pinned: true,
      centerTitle: true,
      iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.storefront, color: Color(0xFF047857), size: 22),
          const SizedBox(width: 8),
          Text(
            'Local Shops',
            style: GoogleFonts.poppins(
              color: const Color(0xFF1F2937),
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityHero() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF064E3B), // Very dark green
            Color(0xFF059669), // Emerald
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.eco,
              size: 160,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24), // Organic gold
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'SUPPORT LOCAL',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF78350F),
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Community Farms',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Connecting you directly to local growers',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _shopsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: AppShimmerLoader(height: 140),
              ),
              childCount: 4,
            ),
          );
        }

        final shops = snapshot.data ?? [];
        if (shops.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text('No local shops found.', style: GoogleFonts.inter(color: Colors.grey)),
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildShopCard(shops[index]),
            childCount: shops.length,
          ),
        );
      },
    );
  }

  Widget _buildShopCard(Map<String, dynamic> shop) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Professional Store Fallback Icon (No Farmer Faces)
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5), // Light mint background
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.2), width: 2),
                ),
                child: const Center(
                  child: Icon(Icons.storefront_rounded, color: Color(0xFF059669), size: 28), // Professional icon
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            shop['name'] ?? 'Local Farm',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1F2937)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.verified, color: Color(0xFF10B981), size: 16),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFFFBBF24), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${shop['rating'] ?? '4.8'}',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF4B5563)),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.location_on, color: Color(0xFFEF4444), size: 14),
                        const SizedBox(width: 2),
                        Text(
                          '${shop['distance'] ?? '1.6 km'}',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Products', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF9CA3AF))),
                  Text('71', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1F2937))),
                ],
              ),
              ElevatedButton(
                onPressed: () {
                  if (shop['farmerId'] != null) {
                    context.push('/farmer/${shop['farmerId']}');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF047857), // Deep emerald
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Text('Visit Store', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}