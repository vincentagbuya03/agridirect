import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/animated_components.dart';

class DAArticleItem {
  final String id;
  final String title;
  final String date;
  final String category;
  final String imageUrl;
  final String summary;
  final List<String> contentParagraphs;
  final List<String> keyRecommendations;
  final String source;

  const DAArticleItem({
    required this.id,
    required this.title,
    required this.date,
    required this.category,
    required this.imageUrl,
    required this.summary,
    required this.contentParagraphs,
    required this.keyRecommendations,
    this.source = 'Department of Agriculture (DA) Bureau of Agricultural Research',
  });
}

class DAArticleDialog extends StatelessWidget {
  final DAArticleItem article;

  const DAArticleDialog({super.key, required this.article});

  static void show(BuildContext context, DAArticleItem article) {
    showDialog(
      context: context,
      builder: (context) => DAArticleDialog(article: article),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 700;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: isMobile ? 24 : 40,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 840,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              // Header bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF044E38),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF065F46)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AgriColors.gold400.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AgriColors.gold400.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded, color: AgriColors.gold300, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'DA OFFICIAL BULLETIN',
                            style: GoogleFonts.inter(
                              color: AgriColors.gold200,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      article.category,
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                      hoverColor: Colors.white10,
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),

              // Body content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 20 : 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Featured Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            AspectRatio(
                              aspectRatio: 16 / 8,
                              child: Image.network(
                                article.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: AgriColors.emerald900,
                                  child: const Center(
                                    child: Icon(Icons.agriculture_rounded, size: 64, color: Colors.white24),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.white70),
                                    const SizedBox(width: 6),
                                    Text(
                                      article.date,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      Text(
                        article.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isMobile ? 22 : 28,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Source attribution
                      Row(
                        children: [
                          const Icon(Icons.account_balance_rounded, size: 15, color: AgriColors.emerald700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              article.source,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AgriColors.emerald800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Divider(color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 20),

                      // Paragraphs
                      ...article.contentParagraphs.map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              p,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: const Color(0xFF334155),
                                height: 1.75,
                              ),
                            ),
                          )),

                      if (article.keyRecommendations.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AgriColors.emerald50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AgriColors.emerald200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.eco_rounded, color: AgriColors.emerald700, size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Key DA Technical Recommendations',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AgriColors.emerald900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ...article.keyRecommendations.map((rec) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: AgriColors.emerald600,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            rec,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              color: const Color(0xFF1E293B),
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Footer Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(
                    top: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Published for farmers & agriculture stakeholders',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AgriColors.muted,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF044E38),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        'Close Article',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
