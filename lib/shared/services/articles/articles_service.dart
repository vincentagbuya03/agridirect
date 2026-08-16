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
      final isFarmer =
          requireFarmerAudience ??
          (AuthService().isViewingAsFarmer || AuthService().isSeller);

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
        final body =
            data['body']?.toString() ?? data['content']?.toString() ?? '';
        final coverImage = data['cover_image_url']?.toString();
        final rawCategory = data['category']?.toString() ?? 'DA Advisories';
        final createdAt = data['created_at']?.toString();

        String formattedDate = 'Recent';
        if (createdAt != null) {
          try {
            final dt = DateTime.parse(createdAt);
            formattedDate =
                '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
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

      // Return dynamic articles or curated foundational bulletins if empty
      final resultList = dbArticles.isNotEmpty
          ? dbArticles
          : _getCuratedFoundationalArticles();

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
      return _getCuratedFoundationalArticles();
    }
  }

  List<DAArticleData> _getCuratedFoundationalArticles() {
    return const [
      DAArticleData(
        id: 'da_art_1',
        title: 'Seasonal Monsoon Advisory & Rice Paddy Drainage Protocols',
        date: '15/08/2026',
        category: 'DA Advisories',
        imageUrl:
            'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?q=80&w=1000&auto=format&fit=crop',
        summary:
            'Essential flood mitigation measures, drainage canal maintenance, and harvest safeguarding techniques for lowland and upland rice farmers during monsoon rains.',
        paragraphs: [
          'The Department of Agriculture Field Operations Unit has released timely technical guidelines for farmers across Central and Northern Luzon in preparation for heavy monsoon precipitation.',
          'Proper field desilting and maintenance of farm-level drainage channels are vital to preventing prolonged submergence of standing crops at vegetative and reproductive stages.',
          'Farmers are strongly advised to coordinate with municipal agrarian officers to access certified seeds and weather-indexed crop compensation facilities.',
        ],
        recommendations: [
          'Clear primary and secondary irrigation canals of silt and debris immediately.',
          'Apply potassium fertilizers to strengthen plant stalks against lodging.',
          'Report localized field flooding to the municipal agriculture office within 48 hours.',
        ],
        author: 'Bureau of Agricultural Research & Field Operations',
      ),
      DAArticleData(
        id: 'da_art_2',
        title: 'Integrated Pest Management for Fall Armyworm in Corn Fields',
        date: '12/08/2026',
        category: 'Crop Protection',
        imageUrl:
            'https://images.unsplash.com/photo-1551754655-cd27e38d2076?q=80&w=1000&auto=format&fit=crop',
        summary:
            'Comprehensive biological control protocols, pheromone trapping, and safe bio-pesticide application against Spodoptera frugiperda infestations.',
        paragraphs: [
          'Fall Armyworm (FAW) remains a critical threat to yellow and white corn cultivation. Early detection during the whorl stage is key to effective eradication before significant defoliation occurs.',
          'Agronomists recommend the release of Trichogramma parasitoids and the application of Bacillus thuringiensis (Bt) microbial formulations to prevent pesticide resistance.',
          'Intercropping corn with legumes and maintaining field sanitation drastically lowers larval populations while improving soil organic matter.',
        ],
        recommendations: [
          'Deploy pheromone monitoring traps at a density of 5 units per hectare.',
          'Spray bio-pesticides early morning or late afternoon when larvae are active.',
          'Avoid broad-spectrum chemical overuse to preserve beneficial predators like earwigs.',
        ],
        author: 'National Crop Protection Center & DA Technical Team',
      ),
      DAArticleData(
        id: 'da_art_3',
        title:
            'Sustainable Forage Production & Silage Techniques for Livestock',
        date: '10/08/2026',
        category: 'Livestock & Fodder',
        imageUrl:
            'https://images.unsplash.com/photo-1516467508483-a7212febe31a?q=80&w=1000&auto=format&fit=crop',
        summary:
            'Maximizing nutrition for cattle, goats, and carabao through Napier grass cultivation, molasses fermentation, and vacuum silage storage.',
        paragraphs: [
          'High-quality fodder is the backbone of productive dairy and beef livestock management. Cultivating high-yielding forage varieties such as Super Napier and Mombasa grass ensures steady year-round nutrition.',
          'Silage production via anaerobic fermentation allows smallholders to store nutrient-dense feed during peak rainy seasons for use during dry lean months.',
          'Supplementing forage with mineral lick blocks and clean potable water boosts milk yield and daily weight gain significantly.',
        ],
        recommendations: [
          'Harvest forage grasses at 45–60 days regrowth for optimal protein-to-fiber ratio.',
          'Compact chopped grass thoroughly in airtight drums or polyethylene bags.',
          'Incorporate 3–5% molasses solution to accelerate lactic acid fermentation.',
        ],
        author: 'Bureau of Animal Industry & Agrarian Extension Desk',
      ),
      DAArticleData(
        id: 'da_art_4',
        title: 'Solar-Powered Smart Drip Irrigation for High-Value Vegetables',
        date: '08/08/2026',
        category: 'Smart AgTech & Fencing',
        imageUrl:
            'https://images.unsplash.com/photo-1586771107445-d3ca888129ff?q=80&w=1000&auto=format&fit=crop',
        summary:
            'How precision solar water pumps and automated drip emitters cut water usage by 60% while doubling yield in tomato, pepper, and onion plots.',
        paragraphs: [
          'Modern water management technology allows vegetable growers to deliver exact moisture and dissolved soluble fertilizers directly to the root zone.',
          'Solar-powered submersible pumps eliminate diesel fuel costs, making precision fertigation economically viable even on small family farm plots.',
          'Coupling drip lines with silver-black plastic mulch suppresses weed growth, prevents soil evaporation, and keeps root zones cool.',
        ],
        recommendations: [
          'Install inline mesh filters to prevent emitter clogging from well sediment.',
          'Schedule irrigation during early morning hours to maximize root absorption.',
          'Utilize soil moisture sensor probes to automate pump cycling.',
        ],
        author: 'Bureau of Agricultural and Fisheries Engineering (BAFE)',
      ),
      DAArticleData(
        id: 'da_art_5',
        title: 'Soil Acidity Correction & Organic Compost Formulation',
        date: '05/08/2026',
        category: 'Soil & Fertilizer',
        imageUrl:
            'https://images.unsplash.com/photo-1464226184884-fa280b87c399?q=80&w=1000&auto=format&fit=crop',
        summary:
            'Step-by-step agricultural liming procedures and microbial inoculants to restore optimal pH balance and boost organic matter in exhausted crop soils.',
        paragraphs: [
          'Soil acidification reduces nutrient availability and diminishes crop response to standard NPK fertilizers. Regular soil testing allows targeted corrective lime application.',
          'Applying agricultural dolomite or calcite limestone 30 days before planting neutralizes toxic aluminum ions and supplies essential calcium and magnesium.',
          'Integrating vermicompost and Trichoderma enriched organic fertilizers revitalizes soil biology, enhancing drought resistance and root development.',
        ],
        recommendations: [
          'Conduct soil chemical analysis every 2 cropping cycles through your provincial lab.',
          'Broadcast agricultural lime evenly and incorporate thoroughly into the top 15 cm of soil.',
          'Combine organic compost at 2–5 tons per hectare with reduced inorganic fertilizer.',
        ],
        author: 'Bureau of Soils and Water Management (BSWM)',
      ),
    ];
  }
}

/// Increments view count for an article in Supabase
Future<void> incrementArticleViews(String articleId) async {
  try {
    await SupabaseConfig.client.rpc(
      'increment_article_views',
      params: {'article_id_param': articleId},
    );
  } catch (_) {
    // Non-critical metric
  }
}
