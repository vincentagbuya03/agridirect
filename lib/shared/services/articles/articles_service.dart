import 'package:flutter/foundation.dart';
import '../core/supabase_config.dart';
import '../auth/auth_service.dart';
import '../../../web/screens/common/web_articles_screen.dart';

class ArticlesService {
  static final ArticlesService _instance = ArticlesService._internal();
  factory ArticlesService() => _instance;
  ArticlesService._internal();

  /// Fetches published articles dynamically from Supabase `admin_articles` table.
  /// Falls back to foundational curated DA bulletins if empty or during network dropouts.
  Future<List<DAArticleData>> getPublishedArticles({
    String? category,
    String? searchQuery,
    bool? requireFarmerAudience,
  }) async {
    try {
      final isFarmer = requireFarmerAudience ?? (AuthService().isViewingAsFarmer || AuthService().isSeller);

      var query = SupabaseConfig.client
          .from('admin_articles')
          .select('*')
          .eq('is_published', true)
          .order('created_at', ascending: false);

      final response = await query;
      final List<dynamic> rows = response as List<dynamic>;

      final List<DAArticleData> dbArticles = [];
      for (final row in rows) {
        final Map<String, dynamic> data = row as Map<String, dynamic>;
        
        final audience = data['audience']?.toString().toUpperCase() ?? 'ALL';
        // Check target audience:
        if (!isFarmer && audience == 'FARMER') {
          // Public guests / consumers should not see farmer-only technical bulletins
          continue;
        }
        if (isFarmer && audience == 'CUSTOMER') {
          // Farmers should not see customer-only consumer shopping guides
          continue;
        }
        
        final id = data['article_id']?.toString() ?? UniqueKey().toString();
        final title = data['title']?.toString() ?? 'Agricultural Advisory';
        final summary = data['summary']?.toString() ?? '';
        final body = data['body']?.toString() ?? data['content']?.toString() ?? '';
        final coverImage = data['cover_image_url']?.toString();
        final rawCategory = data['category']?.toString() ?? 'DA Advisories';
        final createdAt = data['created_at']?.toString();

        String formattedDate = 'Recent';
        if (createdAt != null) {
          try {
            final dt = DateTime.parse(createdAt);
            formattedDate = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
          } catch (_) {}
        }

        // Split body into readable paragraphs
        final paragraphs = body
            .split('\n\n')
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toList();

        if (paragraphs.isEmpty && summary.isNotEmpty) {
          paragraphs.add(summary);
        }

        dbArticles.add(
          DAArticleData(
            id: id,
            title: title,
            date: formattedDate,
            category: rawCategory,
            imageUrl: (coverImage != null && coverImage.trim().isNotEmpty)
                ? coverImage
                : 'https://images.unsplash.com/photo-1592417817098-8f3d6910985b?q=80&w=1000&auto=format&fit=crop',
            summary: summary,
            paragraphs: paragraphs,
            recommendations: const [
              'Adhere to Department of Agriculture Good Agricultural Practices (GAP).',
              'Coordinate with your municipal agrarian technician for verified inputs.',
            ],
            author: 'Department of Agriculture (DA) & Admin Desk',
          ),
        );
      }

      // Return ONLY real dynamic articles published by admin
      final resultList = dbArticles;

      // Filter by category if requested
      var filtered = resultList;
      if (category != null && category != 'All Articles') {
        filtered = filtered.where((a) => a.category == category).toList();
      }

      // Filter by search query if requested
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase().trim();
        filtered = filtered.where((a) {
          return a.title.toLowerCase().contains(q) ||
              a.summary.toLowerCase().contains(q);
        }).toList();
      }

      return filtered;
    } catch (e) {
      debugPrint('ArticlesService error fetching articles: $e');
      return [];
    }
  }

  /// Increments view count for an article in Supabase
  Future<void> incrementArticleViews(String articleId) async {
    try {
      await SupabaseConfig.client.rpc('increment_article_views', params: {
        'article_id_param': articleId,
      });
    } catch (_) {
      // Non-critical metric
    }
  }
}
