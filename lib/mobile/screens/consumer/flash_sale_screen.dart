import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/services/commerce/cart_service.dart';
import '../../../shared/data/app_data.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/app_shimmer_loader.dart';

class FlashSaleScreen extends StatefulWidget {
  const FlashSaleScreen({super.key});

  @override
  State<FlashSaleScreen> createState() => _FlashSaleScreenState();
}

class _FlashSaleScreenState extends State<FlashSaleScreen> {
  late Future<List<ProductItem>> _productsFuture;
  late Timer _timer;
  Duration _timeLeft = const Duration();

  @override
  void initState() {
    super.initState();
    _productsFuture = SupabaseDataService().getFlashSaleProducts();
    _calculateTimeLeft();
    _startTimer();
  }

  void _calculateTimeLeft() {
    final now = DateTime.now();
    // Midnight tonight
    final midnight = DateTime(now.year, now.month, now.day + 1);
    setState(() {
      _timeLeft = midnight.difference(now);
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft.inSeconds > 0) {
        if (mounted) {
          setState(() {
            _timeLeft = _timeLeft - const Duration(seconds: 1);
          });
        }
      } else {
        _calculateTimeLeft(); // Reset for next day
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _addToCart(ProductItem product) async {
    final result = await CartService().addItem(product);
    if (!mounted) return;
    
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result),
        backgroundColor: Colors.red[600],
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Added to Cart!'),
        backgroundColor: Colors.green[600],
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: () {
            context.push('/cart');
          },
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F0E5), // Warm background
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: _buildRichBanner()),
          SliverToBoxAdapter(child: _buildCountdownHeader()),
          _buildProductGrid(),
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 0,
      pinned: true,
      backgroundColor: const Color(0xFF8B0000), // Deep red
      iconTheme: const IconThemeData(color: Colors.white),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flash_on_rounded, color: Color(0xFF8B0000), size: 18),
            const SizedBox(width: 6),
            Text(
              'AgriDirect Mall',
              style: GoogleFonts.poppins(
                color: const Color(0xFF8B0000),
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      centerTitle: true,
    );
  }

  // Emulating the "SIGURADONG MURA" graphic banner in pure Flutter UI
  Widget _buildRichBanner() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.5,
          colors: [
            Color(0xFFFFD700), // Gold center
            Color(0xFFB22222), // Firebrick red
            Color(0xFF8B0000), // Dark red edges
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background sunburst effect (simulated with icons/shapes)
          Positioned(
            left: -40,
            top: 20,
            child: Icon(Icons.star_rounded, size: 120, color: Colors.white.withValues(alpha: 0.1)),
          ),
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(Icons.local_offer_rounded, size: 150, color: Colors.white.withValues(alpha: 0.08)),
          ),
          
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Top badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: Text(
                  'FARMER DIRECT',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFD32F2F),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Main Title "SIGURADONG MURA" style
              Text(
                'FLASH',
                style: GoogleFonts.blackOpsOne(
                  fontSize: 48,
                  color: Colors.white,
                  height: 1,
                  shadows: [
                    const Shadow(color: Color(0xFF8B0000), offset: Offset(2, 3), blurRadius: 2),
                    Shadow(color: Colors.black.withValues(alpha: 0.3), offset: const Offset(0, 5), blurRadius: 10),
                  ],
                ),
              ),
              Text(
                'DEALS',
                style: GoogleFonts.blackOpsOne(
                  fontSize: 52,
                  color: const Color(0xFFFFD700), // Gold
                  height: 0.9,
                  shadows: [
                    const Shadow(color: Color(0xFF8B0000), offset: Offset(2, 3), blurRadius: 2),
                    Shadow(color: Colors.black.withValues(alpha: 0.5), offset: const Offset(0, 5), blurRadius: 15),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Subtitle Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 3)),
                  ],
                ),
                child: Text(
                  'LOWEST PRICE GUARANTEED',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownHeader() {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(_timeLeft.inHours);
    final minutes = twoDigits(_timeLeft.inMinutes.remainder(60));
    final seconds = twoDigits(_timeLeft.inSeconds.remainder(60));

    return Container(
      color: const Color(0xFFB22222), // Firebrick red banner background
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Ongoing',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          _buildTimeBox(hours),
          _buildColon(),
          _buildTimeBox(minutes),
          _buildColon(),
          _buildTimeBox(seconds),
        ],
      ),
    );
  }

  Widget _buildColon() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        ':',
        style: GoogleFonts.poppins(
          color: const Color(0xFFFFD700),
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildTimeBox(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700), // Gold
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        value,
        style: GoogleFonts.poppins(
          color: const Color(0xFF8B0000),
          fontSize: 16,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildProductGrid() {
    return FutureBuilder<List<ProductItem>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.58,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => const AppShimmerLoader(height: 280),
                childCount: 4,
              ),
            ),
          );
        }

        final products = snapshot.data ?? [];
        if (products.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text('No flash deals right now.', style: GoogleFonts.inter(color: Colors.grey)),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.55,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildFlashDealCard(products[index]),
              childCount: products.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFlashDealCard(ProductItem product) {
    // Generate stable mock values based on product ID
    final stableSeed = product.productId.hashCode;
    
    // Simulate a huge discount (40% to 75%)
    final double discountPct = 40.0 + (stableSeed % 35); 
    
    final double salePrice = double.tryParse(product.price) ?? 100;
    // Calculate original price based on the mock discount
    final double originalPrice = salePrice / (1 - (discountPct / 100));
    
    // Simulate stock claiming (60% to 98% sold)
    final double stockClaimed = 60.0 + (stableSeed % 38);

    return GestureDetector(
      onTap: () {
        if (product.productId != null) {
          context.push('/product/${product.productId}');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8), // Sharper corners for modern e-com
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrls.isNotEmpty ? product.imageUrls.first : product.imageUrl,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[100]),
                    errorWidget: (context, url, error) => Container(color: Colors.grey[100]),
                  ),
                ),
                // Shopee-style discount tag (Yellow top-right)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700), // Gold/Yellow
                      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 2, offset: const Offset(-1, 1)),
                      ],
                    ),
                    child: Text(
                      '-${discountPct.toInt()}%',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFD32F2F), // Red text
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // "Lowest Price Guaranteed" tiny banner below image
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFB22222), Color(0xFF1976D2)],
                  stops: [0.4, 0.4], // Hard split like in the screenshot
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      ' SIGURADONG MURA',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Text(
                      ' LOWEST PRICE GUARANTEED',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF111827),
                        height: 1.2,
                      ),
                    ),
                    const Spacer(),
                    
                    Text(
                      '₱${originalPrice.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF9CA3AF),
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₱${salePrice.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFD32F2F), // Red price
                          ),
                        ),
                        // Mini Add to Cart
                        GestureDetector(
                          onTap: () => _addToCart(product),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD32F2F),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Selling Fast Progress Bar
                    Container(
                      height: 16,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFCDD2), // Light red bg
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        children: [
                          FractionallySizedBox(
                            widthFactor: stockClaimed / 100,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFEF5350), Color(0xFFC62828)],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          Center(
                            child: Text(
                              stockClaimed > 90 ? 'ALMOST GONE' : 'SELLING FAST',
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
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
    );
  }
}