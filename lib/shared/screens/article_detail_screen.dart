import 'package:flutter/material.dart';
import '../../shared/styles/app_theme.dart';
import '../../shared/data/app_data.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ArticleDetailScreen extends StatelessWidget {
  final ArticleItem article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textHeadline),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: article.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 250,
                        color: AppColors.background,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else
                    Container(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      child: const Icon(Icons.article_outlined, size: 80, color: AppColors.primary),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              transform: Matrix4.translationValues(0, -32, 0),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'RESOURCE GUIDE',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(article.title, style: AppTextStyles.headline1.copyWith(fontSize: 28, height: 1.2)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.primary,
                          child: Icon(Icons.spa, size: 12, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Text('By ${article.author}', style: AppTextStyles.headline3.copyWith(fontSize: 14)),
                        const SizedBox(width: 12),
                        const Icon(Icons.circle, size: 4, color: AppColors.textSubtle),
                        const SizedBox(width: 12),
                        const Icon(Icons.access_time, size: 14, color: AppColors.textSubtle),
                        const SizedBox(width: 4),
                        Text(article.readTime, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: AppColors.background),
                    const SizedBox(height: 24),
                    Text(
                      article.excerpt, // In a real app, you'd have a 'content' field
                      style: AppTextStyles.bodyMedium.copyWith(
                        height: 1.8,
                        color: AppColors.textBody.withValues(alpha: 0.8),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Adding dummy content for visual appeal
                    Text(
                      "Modern agricultural practices are evolving rapidly. This guide explores the essential techniques every farmer needs to know to maximize yield while maintaining sustainable soil health. We'll cover everything from precision irrigation to integrated pest management (IPM) strategies that minimize chemical reliance.\n\n"
                      "Implementation of these techniques can lead to a 30% increase in crop efficiency within the first two seasons. It's not just about the technology; it's about the data-driven approach to every seed planted.",
                      style: AppTextStyles.bodyMedium.copyWith(
                        height: 1.8,
                        color: AppColors.textBody.withValues(alpha: 0.8),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.share, color: Colors.white),
        label: const Text('Share Article', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
