import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../shared/styles/app_theme.dart';
import '../../shared/data/app_data.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/report_content_dialog.dart';
import '../services/core/supabase_data_service.dart';
import '../utils/share_util.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/app_open_banner.dart';

class ArticleDetailScreen extends StatefulWidget {
  final ArticleItem article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  double _readingProgress = 0.0;
  bool _isBookmarked = false;
  bool? _wasHelpful;
  double _fontScale = 1.0; // 1.0 = Normal, 1.15 = Large, 1.3 = Extra Large

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateReadingProgress);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateReadingProgress);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateReadingProgress() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll <= 0) {
      if (_readingProgress != 1.0) {
        setState(() => _readingProgress = 1.0);
      }
      return;
    }
    final progress = (currentScroll / maxScroll).clamp(0.0, 1.0);
    if ((progress - _readingProgress).abs() > 0.01) {
      setState(() => _readingProgress = progress);
    }
  }

  void _cycleFontSize() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_fontScale == 1.0) {
        _fontScale = 1.15;
      } else if (_fontScale == 1.15) {
        _fontScale = 1.3;
      } else {
        _fontScale = 1.0;
      }
    });
    final sizeLabel = _fontScale == 1.0
        ? 'Standard'
        : (_fontScale == 1.15 ? 'Large' : 'Extra Large');
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.format_size_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Text size: $sizeLabel'),
          ],
        ),
      ),
    );
  }

  void _toggleBookmark() {
    HapticFeedback.lightImpact();
    setState(() => _isBookmarked = !_isBookmarked);
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(
              _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              _isBookmarked
                  ? 'Article saved to your bookmarks'
                  : 'Article removed from bookmarks',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareArticle() async {
    HapticFeedback.lightImpact();
    final shareUrl = widget.article.id != null && widget.article.id!.isNotEmpty
        ? ShareUtil.generatePostShareLink(widget.article.id!)
        : ShareUtil.baseDomain;
    final shareSubject = 'Check out this article on AgriDirect: ${widget.article.title}';
    // ignore: deprecated_member_use
    await Share.share('$shareSubject\n\n$shareUrl', subject: shareSubject);
  }

  Future<void> _copyArticleLink() async {
    HapticFeedback.lightImpact();
    final shareUrl = widget.article.id != null && widget.article.id!.isNotEmpty
        ? ShareUtil.generatePostShareLink(widget.article.id!)
        : ShareUtil.baseDomain;
    await Clipboard.setData(ClipboardData(text: shareUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF0F172A),
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
            SizedBox(width: 10),
            Text('Link copied to clipboard!'),
          ],
        ),
      ),
    );
  }

  Future<void> _openReportDialog(BuildContext context) async {
    final articleId = widget.article.id;
    if (articleId == null || articleId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This article cannot be reported right now.'),
        ),
      );
      return;
    }

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => ReportContentDialog(
        contentLabel: 'article',
        contentTitle: widget.article.title,
        onSubmit: (reason, details) {
          return SupabaseDataService().reportArticle(
            articleId: articleId,
            reason: reason,
            description: details,
          );
        },
      ),
    );

    if (submitted == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted. Our team will review it soon.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 800;

    Widget content = Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(context),
              SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: _buildContent(context),
                  ),
                ),
              ),
            ],
          ),
          // Top Reading Progress Bar (docked just below status bar / appbar)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 3,
                child: LinearProgressIndicator(
                  value: _readingProgress,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomReaderBar(context),
    );

    if (isWeb) {
      content = AppOpenBanner(
        child: Container(
          color: const Color(0xFFF1F5F9),
          alignment: Alignment.center,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 820),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: content,
          ),
        ),
      );
    }

    return content;
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 310,
      pinned: true,
      elevation: 0,
      stretch: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      leadingWidth: 64,
      leading: Padding(
        padding: const EdgeInsets.only(left: 14),
        child: Center(
          child: _buildGlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            size: 16,
            onTap: () => Navigator.pop(context),
            tooltip: 'Back',
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGlassIconButton(
                icon: _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                iconColor: _isBookmarked ? AppColors.accent : Colors.white,
                size: 19,
                onTap: _toggleBookmark,
                tooltip: _isBookmarked ? 'Saved' : 'Save article',
              ),
              const SizedBox(width: 8),
              _buildGlassIconButton(
                icon: Icons.share_rounded,
                size: 19,
                onTap: _shareArticle,
                tooltip: 'Share',
              ),
              const SizedBox(width: 8),
              _buildGlassIconButton(
                icon: Icons.more_vert_rounded,
                size: 20,
                onTap: () => _showArticleOptionsMenu(context),
                tooltip: 'More options',
              ),
            ],
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.article.imageUrl != null && widget.article.imageUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: widget.article.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: const Color(0xFFE2E8F0),
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => _buildFallbackHeroBanner(),
              )
            else
              _buildFallbackHeroBanner(),
            // Enhanced multi-stop subtle vignette gradient for optimal text & button contrast
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.65),
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  stops: const [0.0, 0.3, 0.6, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackHeroBanner() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF065F46), Color(0xFF059669), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.menu_book_rounded,
          size: 72,
          color: Colors.white.withValues(alpha: 0.25),
        ),
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
    double size = 18,
    String? tooltip,
  }) {
    Widget button = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.black.withValues(alpha: 0.35),
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 38,
              height: 38,
              child: Center(
                child: Icon(
                  icon,
                  color: iconColor ?? Colors.white,
                  size: size,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }

  void _showArticleOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.share_outlined, color: AppColors.primary),
                ),
                title: Text(
                  'Share Article',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Share link to other apps or messaging'),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareArticle();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.copy_rounded, color: Colors.blue.shade700),
                ),
                title: Text(
                  'Copy Link',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Copy public article link to clipboard'),
                onTap: () {
                  Navigator.pop(ctx);
                  _copyArticleLink();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.format_size_rounded, color: Colors.purple.shade700),
                ),
                title: Text(
                  'Adjust Font Size',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('Current size: ${_fontScale == 1.0 ? "Standard" : (_fontScale == 1.15 ? "Large" : "Extra Large")}'),
                onTap: () {
                  Navigator.pop(ctx);
                  _cycleFontSize();
                },
              ),
              const Divider(height: 24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.flag_outlined, color: Colors.red.shade700),
                ),
                title: Text(
                  'Report Inaccurate Content',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                ),
                subtitle: const Text('Help us keep AgriDirect informative and safe'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openReportDialog(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      transform: Matrix4.translationValues(0, -22, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle hint
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Metadata Badges Wrap
            _buildMetadataBadges(),
            const SizedBox(height: 18),

            // Article Title
            Text(
              widget.article.title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 26 * _fontScale,
                fontWeight: FontWeight.w800,
                color: AppColors.textHeadline,
                height: 1.25,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 22),

            // Refined Author / Source Card
            _buildAuthorSection(),
            const SizedBox(height: 28),

            // Editorial Lead Excerpt Card
            _buildExcerptCard(),
            const SizedBox(height: 28),

            // Article Body Content (Intelligently formatted)
            _buildBodyContent(),

            // Key Takeaways Section
            if (widget.article.keyInsights != null && widget.article.keyInsights!.isNotEmpty) ...[
              const SizedBox(height: 36),
              _buildKeyInsights(widget.article.keyInsights!),
            ],

            const SizedBox(height: 36),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 24),

            // "Was this helpful?" Feedback Widget
            _buildHelpfulWidget(),
            const SizedBox(height: 24),

            // Dedicated In-Flow Share Card (Non-intrusive, placed at bottom where it belongs!)
            _buildShareCard(),
            const SizedBox(height: 20),

            // Report link
            Center(
              child: TextButton.icon(
                onPressed: () => _openReportDialog(context),
                icon: const Icon(Icons.flag_outlined, size: 15, color: AppColors.textSubtle),
                label: Text(
                  'Report an issue with this article',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.textSubtle,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataBadges() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Category Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.menu_book_rounded, size: 12, color: AppColors.primary),
              const SizedBox(width: 5),
              Text(
                'GUIDE & INSIGHT',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 10.5,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),

        // Audience Pill
        if (widget.article.audience == 'FARMER')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.agriculture_rounded, size: 13, color: Color(0xFFD97706)),
                const SizedBox(width: 5),
                Text(
                  'FARMERS ONLY',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFB45309),
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          )
        else if (widget.article.audience == 'CUSTOMER')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_outline_rounded, size: 13, color: Color(0xFF2563EB)),
                const SizedBox(width: 5),
                Text(
                  'CONSUMERS',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF1D4ED8),
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),

        // Date pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textSubtle),
              const SizedBox(width: 5),
              Text(
                widget.article.time,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSubtle,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAuthorSection() {
    final isOfficial = widget.article.author == 'AgriDirect';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Author Avatar with badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: isOfficial
                  ? const Icon(Icons.eco_rounded, size: 22, color: Colors.white)
                  : const Icon(Icons.person_rounded, size: 22, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          // Author details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.article.author,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.textHeadline,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isOfficial) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isOfficial ? 'AgriDirect Verified Resource' : 'Community Agronomist',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: AppColors.textSubtle,
                  ),
                ),
              ],
            ),
          ),
          // Read Time Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 13,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  widget.article.calculatedReadTime,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExcerptCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: AppColors.primary, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.format_quote_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'OVERVIEW',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.article.excerpt,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16 * _fontScale,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF166534),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    final rawContent = widget.article.content;
    final fallbackContent =
        "Implementing eco-friendly agricultural techniques safeguards crop yields while revitalizing soil micro-biology.\n\n"
        "### Key Principles of Organic Management\n"
        "Farmers who transition toward biological pest suppression reduce chemical input costs by up to 35% within two seasons. By introducing beneficial predators like ladybugs and lacewings, aphids and whitefly infestations can be managed naturally.\n\n"
        "### Companion Planting & Trap Crops\n"
        "Intercropping aromatic herbs such as basil, mint, and marigolds disrupts pest navigation patterns and creates protective barriers around vulnerable cash crops.\n\n"
        "Regular field monitoring and timely bio-spray interventions ensure your produce remains residue-free, healthy, and commands premium market value.";

    final textToRender = (rawContent != null && rawContent.trim().isNotEmpty)
        ? rawContent
        : fallbackContent;

    // Parse into paragraphs and headers
    final blocks = textToRender.split(RegExp(r'\n\s*\n'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks.map((block) {
        final trimmed = block.trim();
        if (trimmed.isEmpty) return const SizedBox.shrink();

        // Check if block is a heading (e.g. ### Heading or ## Heading)
        if (trimmed.startsWith('### ') || trimmed.startsWith('## ') || trimmed.startsWith('# ')) {
          final headingText = trimmed.replaceFirst(RegExp(r'^#+\s*'), '');
          return Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 18 * _fontScale,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Text(
                    headingText,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18 * _fontScale,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHeadline,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Check if block is a bullet list
        if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
          final items = trimmed.split('\n');
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map((item) {
                final cleanItem = item.replaceFirst(RegExp(r'^[-*]\s*'), '');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 7, right: 10),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          cleanItem,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15 * _fontScale,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF334155),
                            height: 1.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        }

        // Regular paragraph
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Text(
            trimmed,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15.5 * _fontScale,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF334155),
              height: 1.8,
              letterSpacing: 0.1,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKeyInsights(List<String> insights) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Key Takeaways',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: AppColors.textHeadline,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Actionable summary for farmers',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: AppColors.textSubtle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...insights.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final insight = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '$index',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      insight,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5 * _fontScale,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1E293B),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHelpfulWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            _wasHelpful == null
                ? 'Did you find this guide helpful?'
                : 'Thank you for your feedback! 👍',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeadline,
            ),
          ),
          const SizedBox(height: 12),
          if (_wasHelpful == null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _wasHelpful = true);
                  },
                  icon: const Icon(Icons.thumb_up_alt_outlined, size: 16),
                  label: const Text('Yes, helpful'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _wasHelpful = false);
                  },
                  icon: const Icon(Icons.thumb_down_alt_outlined, size: 16),
                  label: const Text('Not really'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSubtle,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            )
          else
            Text(
              'Your input helps us improve farming resources on AgriDirect.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.textSubtle,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShareCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFECFDF5), Color(0xFFF0FDF4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.share_rounded, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share with fellow growers',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    Text(
                      'Help your community thrive with practical knowledge',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: const Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: _shareArticle,
                  icon: const Icon(Icons.ios_share_rounded, size: 17),
                  label: Text(
                    'Share Article',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: _copyArticleLink,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: Text(
                    'Copy Link',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    side: const BorderSide(color: Color(0xFF6EE7B7)),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomReaderBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Reading progress percentage pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.chrome_reader_mode_outlined, size: 14, color: AppColors.textSubtle),
                    const SizedBox(width: 6),
                    Text(
                      '${(_readingProgress * 100).toInt()}% read',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSubtle,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Font Size adjustment
              IconButton(
                onPressed: _cycleFontSize,
                tooltip: 'Adjust text size',
                icon: Text(
                  'Aa',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textHeadline,
                  ),
                ),
              ),
              // Bookmark Button
              IconButton(
                onPressed: _toggleBookmark,
                tooltip: _isBookmarked ? 'Bookmarked' : 'Bookmark',
                icon: Icon(
                  _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: _isBookmarked ? AppColors.accent : AppColors.textHeadline,
                  size: 22,
                ),
              ),
              // Quick Share
              IconButton(
                onPressed: _shareArticle,
                tooltip: 'Share',
                icon: const Icon(
                  Icons.share_rounded,
                  color: AppColors.primary,
                  size: 21,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
