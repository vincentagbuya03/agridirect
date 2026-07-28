import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/widgets/image_widgets.dart';

class FindAFarmerDialog extends StatefulWidget {
  final VoidCallback? onExploreFarmers;

  const FindAFarmerDialog({super.key, this.onExploreFarmers});

  static Future<void> show(BuildContext context, {VoidCallback? onExploreFarmers}) {
    return showDialog(
      context: context,
      builder: (context) => FindAFarmerDialog(onExploreFarmers: onExploreFarmers),
    );
  }

  @override
  State<FindAFarmerDialog> createState() => _FindAFarmerDialogState();
}

class _FindAFarmerDialogState extends State<FindAFarmerDialog> {
  static const Color primary = Color(0xFF16A34A);
  static const Color dark = Color(0xFF111827);
  static const Color muted = Color(0xFF6B7280);

  Future<List<Map<String, dynamic>>>? _farmersFuture;

  @override
  void initState() {
    super.initState();
    _farmersFuture = _fetchLocalFarmers();
  }

  Future<List<Map<String, dynamic>>> _fetchLocalFarmers() async {
    try {
      final response = await Supabase.instance.client
          .from('v_farmer_profiles')
          .select()
          .limit(4);
      return (response as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (e) {
      debugPrint('Error fetching farmers for dialog: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.travel_explore_rounded, color: primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find Local Farmers',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: dark,
                  ),
                ),
                Text(
                  'Connect directly with agricultural producers in your area',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _farmersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: CircularProgressIndicator(color: primary),
                      ),
                    );
                  }

                  final farmers = snapshot.data ?? [];
                  if (farmers.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primary.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.storefront_rounded, size: 44, color: primary),
                          const SizedBox(height: 10),
                          Text(
                            'Explore Verified Farmers',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: dark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Discover registered local farms, view seasonal harvest offerings, and connect directly for fresh produce.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: muted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Featured Local Sellers',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...farmers.map((farmer) {
                        final farmName = farmer['farm_name']?.toString() ?? 'Local Farm';
                        final location = farmer['location']?.toString() ?? 'Philippines';
                        final specialty = farmer['specialty']?.toString() ?? 'Fresh Produce';
                        final farmerId = farmer['farmer_id']?.toString() ?? '';
                        final imageUrl = farmer['image_url']?.toString();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              SafeCircleAvatar(
                                imageUrl: imageUrl,
                                radius: 22,
                                defaultBucket: 'uploads',
                                child: const Icon(Icons.agriculture_rounded, color: primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            farmName,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: dark,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.verified_rounded, size: 15, color: primary),
                                      ],
                                    ),
                                    Text(
                                      '$specialty • $location',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: muted,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (farmerId.isNotEmpty)
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    context.go(AppRoutes.farmerProfile(farmerId));
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  ),
                                  child: Text(
                                    'Visit Farm',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Close',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: muted),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            if (widget.onExploreFarmers != null) {
              widget.onExploreFarmers!();
            } else {
              context.go(AppRoutes.farmersMap);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: Text(
            'Open Farmers Map',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
