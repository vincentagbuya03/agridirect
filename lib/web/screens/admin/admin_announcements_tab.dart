import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../../shared/services/admin/admin_service.dart';
import '../../../shared/services/ai/ai_service.dart';
import 'admin_ui.dart';

class AdminAnnouncementsTab extends StatefulWidget {
  final AdminService adminService;
  const AdminAnnouncementsTab({super.key, required this.adminService});

  @override
  State<AdminAnnouncementsTab> createState() => _AdminAnnouncementsTabState();
}

class _AdminAnnouncementsTabState extends State<AdminAnnouncementsTab> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _targetUserIdController = TextEditingController();
  final _linkIdController = TextEditingController();
  final _ai = AiService();

  String _audience = 'test_me'; // 'test_me', 'test_user', 'farmers', 'customers', 'farmers_customers'
  String _linkType = 'weather';
  String _notificationCode = 'weather_dynamic';
  bool _sending = false;
  bool _scanningWeather = false;
  bool _generatingAi = false;
  String _activeCampaignType = 'weather';
  bool _isIosPreview = false;

  static const Color _primary = Color(0xFF059669);
  static const Color _primaryDark = Color(0xFF047857);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  final List<Map<String, String>> _dynamicAiCampaigns = [
    {
      'id': 'weather',
      'label': '🌾 Live Weather & Typhoon AI',
      'audience': 'farmers',
      'linkType': 'weather',
      'code': 'weather_dynamic',
    },
    {
      'id': 'rain_promo',
      'label': '🍲 Rainy Comfort Promo AI',
      'audience': 'customers',
      'linkType': 'flash_sale',
      'code': 'promo_weather_rain',
    },
    {
      'id': 'flash_harvest',
      'label': '🌽 Flash Harvest Drop AI',
      'audience': 'customers',
      'linkType': 'flash_sale',
      'code': 'flash_sale',
    },
    {
      'id': 'market_demand',
      'label': '🍅 Market Demand Surge AI',
      'audience': 'farmers',
      'linkType': 'farmer_dashboard',
      'code': 'market_demand',
    },
    {
      'id': 'da_advisory',
      'label': '📢 DA Platform Notice AI',
      'audience': 'farmers',
      'linkType': 'announcement',
      'code': 'advisory',
    },
  ];

  final List<String> _quickEmojis = [
    '🍲',
    '🌧️',
    '☔',
    '🌽',
    '🍅',
    '🥕',
    '⚠️',
    '⚡',
    '🚜',
    '🧺',
    '💚',
    '📲',
    '🌾',
    '☀️',
    '📦',
    '🔥',
  ];

  @override
  void initState() {
    super.initState();
    // Default initial template without firing automatic API calls on tab open
    _titleController.text = '🌾 Live Weather & Harvest Advisory';
    _messageController.text =
        'Fair weather conditions across San Carlos City farms today. Ideal for early morning harvest and crop transport.';
    _imageUrlController.text =
        'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=600&auto=format&fit=crop&q=80';
    _titleController.addListener(() => setState(() {}));
    _messageController.addListener(() => setState(() {}));
    _imageUrlController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _imageUrlController.dispose();
    _targetUserIdController.dispose();
    _linkIdController.dispose();
    super.dispose();
  }

  Future<void> _triggerDynamicAiCampaign(Map<String, String> campaign) async {
    final id = campaign['id']!;
    setState(() => _activeCampaignType = id);

    if (id == 'weather') {
      await _generateWithOpenRouter();
      return;
    }

    setState(() => _generatingAi = true);
    try {
      final res = await _ai.generateCampaignPush(
        campaignType: id,
        location: 'San Carlos City, Pangasinan',
      );

      String campaignImg =
          'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80';
      if (id == 'flash_harvest') {
        campaignImg =
            'https://images.unsplash.com/photo-1551754655-cd27e38d2076?w=600&auto=format&fit=crop&q=80';
      } else if (id == 'market_demand') {
        campaignImg =
            'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=600&auto=format&fit=crop&q=80';
      } else if (id == 'da_advisory') {
        campaignImg =
            'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=600&auto=format&fit=crop&q=80';
      }

      setState(() {
        _titleController.text = res['title'] ?? '';
        _messageController.text = res['body'] ?? '';
        _imageUrlController.text = campaignImg;
        _notificationCode = campaign['code'] ?? 'announcement';
        _linkType = campaign['linkType'] ?? 'flash_sale';
        _linkIdController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _primary,
            behavior: SnackBarBehavior.floating,
            content: Text('✨ Dynamically generated ${campaign['label']} with AI!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            content: Text('AI Generation failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingAi = false);
    }
  }

  Future<void> _showApiKeyDialog() async {
    final keyCtrl = TextEditingController(
      text: AiService.effectiveOpenRouterKey,
    );
    final newKey = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.key_rounded, color: _primary),
            const SizedBox(width: 8),
            Text('OpenRouter API Key', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your OpenRouter API key (sk-or-v1-...) to generate custom, live weather push notifications with free AI models directly in this browser session:',
              style: GoogleFonts.inter(fontSize: 13, color: _muted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: keyCtrl,
              decoration: InputDecoration(
                hintText: 'sk-or-v1-...',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: _muted),
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: _muted),
                filled: true,
                fillColor: _surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primary, width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(dialogCtx, keyCtrl.text.trim()),
            child: const Text('Save Key'),
          ),
        ],
      ),
    );

    if (newKey != null && newKey.isNotEmpty && mounted) {
      AiService.runtimeOpenRouterKey = newKey;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: _primary,
          behavior: SnackBarBehavior.floating,
          content: Text('✅ OpenRouter API key saved for this session!'),
        ),
      );
    }
  }

  Future<void> _generateWithOpenRouter() async {
    setState(() => _generatingAi = true);
    try {
      String condition = 'Partly Cloudy';
      double temp = 30.0;
      double rainProb = 0.2;
      double windSpeed = 12.0;
      String alertType = 'daily_summary';
      String linkType = 'weather';
      String code = 'weather_daily_summary';
      const farmName = 'San Carlos City farms';

      const apiKey = 'd519e73b738173d3d9a7bd5737ea3992';
      try {
        final url = Uri.parse(
          'https://api.openweathermap.org/data/2.5/forecast?lat=15.9224&lon=120.3489&units=metric&appid=$apiKey',
        );
        final res = await http.get(url);
        if (res.statusCode == 200) {
          final data = jsonDecode(utf8.decode(res.bodyBytes));
          final list = (data['list'] as List?) ?? [];
          final first = list.isNotEmpty ? list[0] : null;

          if (first != null) {
            final main = first['main'] ?? {};
            final weather = (first['weather'] as List?)?.first ?? {};
            final wind = first['wind'] ?? {};

            temp = (main['temp'] as num?)?.toDouble() ?? 29.0;
            condition = weather['description']?.toString() ?? 'Partly Cloudy';
            final weatherId = (weather['id'] as num?)?.toInt() ?? 800;
            rainProb = (first['pop'] as num?)?.toDouble() ?? 0.0;
            windSpeed = ((wind['speed'] as num?)?.toDouble() ?? 3.0) * 3.6;

            double maxWind = windSpeed;
            double maxRainProb = rainProb;
            bool hasSevereStorm = (weatherId >= 200 && weatherId <= 232);
            bool isTyphoon = condition.toLowerCase().contains('typhoon') ||
                condition.toLowerCase().contains('tropical storm') ||
                condition.toLowerCase().contains('cyclone') ||
                condition.toLowerCase().contains('squall') ||
                condition.toLowerCase().contains('gale');

            for (int i = 0; i < (list.length < 12 ? list.length : 12); i++) {
              final item = list[i];
              final itemWind = ((item['wind']?['speed'] as num?)?.toDouble() ?? 0.0) * 3.6;
              final itemPop = (item['pop'] as num?)?.toDouble() ?? 0.0;
              final itemWId = (item['weather']?[0]?['id'] as num?)?.toInt() ?? 800;
              final itemDesc = (item['weather']?[0]?['description']?.toString() ?? '').toLowerCase();

              if (itemWind > maxWind) maxWind = itemWind;
              if (itemPop > maxRainProb) maxRainProb = itemPop;
              if (itemWId >= 200 && itemWId <= 232) hasSevereStorm = true;
              if (itemDesc.contains('typhoon') ||
                  itemDesc.contains('cyclone') ||
                  itemDesc.contains('tropical storm')) {
                isTyphoon = true;
              }
            }

            if (isTyphoon || maxWind >= 45.0 || hasSevereStorm) {
              alertType = 'storm';
              code = 'weather_storm_warning';
              linkType = 'weather';
            } else if (maxRainProb >= 0.6) {
              alertType = 'rain';
              code = 'weather_heavy_rain';
              linkType = 'weather';
            } else if (temp >= 36.0) {
              alertType = 'heat';
              code = 'weather_extreme_heat';
              linkType = 'weather';
            }
          }
        }
      } catch (_) {}

      final aiRes = await _ai.generateWeatherPush(
        farmName: farmName,
        condition: condition,
        temperature: temp,
        rainProbability: rainProb,
        windSpeed: windSpeed,
        alertType: alertType,
        targetAudience: 'farmers',
      );

      String aiImg =
          'https://images.unsplash.com/photo-1534088568595-a066f410bcda?w=600&auto=format&fit=crop&q=80';
      if (alertType == 'storm') {
        aiImg =
            'https://images.unsplash.com/photo-1514632595-4944383f2737?w=600&auto=format&fit=crop&q=80';
      } else if (alertType == 'rain') {
        aiImg =
            'https://images.unsplash.com/photo-1515694346937-94d85e41e6f0?w=600&auto=format&fit=crop&q=80';
      }

      setState(() {
        _titleController.text = aiRes['title'] ?? '';
        _messageController.text = aiRes['body'] ?? '';
        _imageUrlController.text = aiImg;
        _notificationCode = code;
        _linkType = linkType;
        _linkIdController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: _primary,
            behavior: SnackBarBehavior.floating,
            content: Text('✨ Live OpenWeather + AI Push copy updated!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            content: Text('OpenRouter AI generation failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingAi = false);
    }
  }

  Future<void> _sendPushNotification() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both title and message.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      final res = await widget.adminService.sendPushNotification(
        title: title,
        message: message,
        audience: _audience,
        targetUserId: _targetUserIdController.text.trim().isEmpty
            ? null
            : _targetUserIdController.text.trim(),
        imageUrl: _imageUrlController.text.trim().isEmpty
            ? null
            : _imageUrlController.text.trim(),
        linkType: _linkType,
        linkId: _linkIdController.text.trim().isEmpty
            ? null
            : _linkIdController.text.trim(),
        notificationCode: _notificationCode,
      );

      if (mounted) {
        final success = res['success'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '🚀 Notification sent! ${res['fcm_sent_count'] ?? 0} devices notified.'
                  : '⚠️ Failed: ${res['error'] ?? 'Unknown error'}',
            ),
            backgroundColor: success ? _primary : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _runWeatherScanNow() async {
    setState(() => _scanningWeather = true);
    try {
      final res = await widget.adminService.runWeatherForecastScan();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res['success'] == true
                  ? '⚡ Weather Scan Complete! ${res['alerts_dispatched'] ?? 0} farm alerts dispatched.'
                  : '⚠️ Scan error: ${res['error']}',
            ),
            backgroundColor: res['success'] == true ? _primary : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Weather Scan failed: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _scanningWeather = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isDesktop = sw >= 1080;

    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildExecutiveHeader(sw < 768),
          const SizedBox(height: 20),
          _buildOperationalKpiStrip(context),
          const SizedBox(height: 24),
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 58, child: _buildComposerCard()),
                const SizedBox(width: 24),
                Expanded(flex: 42, child: _buildPreviewAndWeatherColumn()),
              ],
            )
          else
            Column(
              children: [
                _buildComposerCard(),
                const SizedBox(height: 20),
                _buildPreviewAndWeatherColumn(),
              ],
            ),
        ],
      ),
    );
  }

  // ─── Executive Header ──────────────────────────────────────────────────────
  Widget _buildExecutiveHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cell_tower_rounded, size: 13, color: _primary),
                      const SizedBox(width: 5),
                      Text(
                        'BROADCAST STUDIO & WEATHER AUTOMATION',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _primaryDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Push Broadcast Studio & Weather Hub',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isMobile ? 20 : 26,
                    fontWeight: FontWeight.w900,
                    color: _dark,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Compose targeted push notifications, run AI-assisted campaigns, and monitor automated cloud weather forecasts.',
                  style: GoogleFonts.inter(
                    fontSize: isMobile ? 12 : 13.5,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _sending ? null : _sendPushNotification,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded, size: 16),
            label: Text(
              _sending ? 'Dispatching...' : 'Dispatch Broadcast',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 20,
                vertical: 13,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 4-Column Operational KPI Metrics Strip ────────────────────────────────
  Widget _buildOperationalKpiStrip(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;
    final isTablet = width >= 768 && width < 1100;

    final metrics = [
      _kpiMetricCard(
        title: 'CLOUD WEATHER CRON',
        value: 'Every 6 hrs',
        subtitle: '8AM, 2PM, 8PM, 2AM pg_cron',
        icon: Icons.thunderstorm_rounded,
        color: const Color(0xFF0284C7),
        bgColor: const Color(0xFFF0F9FF),
        borderColor: const Color(0xFFBAE6FD),
        badgeText: '24/7 ACTIVE',
      ),
      _kpiMetricCard(
        title: 'TARGET AUDIENCE',
        value: _audienceLabel(_audience),
        subtitle: 'Broadcast recipient scope',
        icon: Icons.groups_rounded,
        color: const Color(0xFF059669),
        bgColor: const Color(0xFFECFDF5),
        borderColor: const Color(0xFFA7F3D0),
      ),
      _kpiMetricCard(
        title: 'DEEP-LINK ACTION',
        value: _linkType.toUpperCase(),
        subtitle: 'In-app navigation destination',
        icon: Icons.open_in_browser_rounded,
        color: const Color(0xFFD97706),
        bgColor: const Color(0xFFFFFBEB),
        borderColor: const Color(0xFFFDE68A),
      ),
      _kpiMetricCard(
        title: 'FCM DELIVERY SLA',
        value: '100% Live',
        subtitle: 'Real-time push gateway',
        icon: Icons.bolt_rounded,
        color: const Color(0xFF7C3AED),
        bgColor: const Color(0xFFF5F3FF),
        borderColor: const Color(0xFFDDD6FE),
        badgeText: 'ONLINE',
      ),
    ];

    if (isMobile) {
      return SizedBox(
        height: 110,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: metrics.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (ctx, i) => SizedBox(width: 220, child: metrics[i]),
        ),
      );
    }

    if (isTablet) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: metrics[0]),
              const SizedBox(width: 14),
              Expanded(child: metrics[1]),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: metrics[2]),
              const SizedBox(width: 14),
              Expanded(child: metrics[3]),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: metrics[0]),
        const SizedBox(width: 16),
        Expanded(child: metrics[1]),
        const SizedBox(width: 16),
        Expanded(child: metrics[2]),
        const SizedBox(width: 16),
        Expanded(child: metrics[3]),
      ],
    );
  }

  Widget _kpiMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    String? badgeText,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x03000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 11, color: _muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ─── Left Column: AI Assistant & Push Composer ─────────────────────────────
  Widget _buildComposerCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dynamic AI Campaign Generators Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: _primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'On-Demand AI Campaign Generators',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _showApiKeyDialog,
                icon: const Icon(Icons.key_rounded, size: 18, color: _muted),
                tooltip: 'Configure OpenRouter API Key',
                splashRadius: 18,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Click any AI generator below to compose fresh notification copy on demand:',
            style: GoogleFonts.inter(fontSize: 12.5, color: _muted),
          ),
          const SizedBox(height: 14),

          // AI Campaign Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _dynamicAiCampaigns.map((camp) {
              final isCurrent = _activeCampaignType == camp['id'] && _generatingAi;
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _generatingAi ? null : () => _triggerDynamicAiCampaign(camp),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isCurrent) ...[
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          isCurrent ? 'Generating AI...' : camp['label']!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isCurrent ? _primaryDark : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 20),

          // Target Audience Selector
          _buildFieldLabel('Target Audience Segment'),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                {'id': 'test_me', 'label': '📱 Test Me (Admin)'},
                {'id': 'farmers', 'label': '🚜 All Farmers'},
                {'id': 'customers', 'label': '🛒 All Customers'},
                {'id': 'farmers_customers', 'label': '🌐 Platform-Wide'},
              ].map((aud) {
                final isSelected = _audience == aud['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => setState(() => _audience = aud['id']!),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? _primary : _surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSelected ? _primary : _border),
                        ),
                        child: Text(
                          aud['label']!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected ? Colors.white : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          // Notification Title
          _buildFieldLabel('Notification Title'),
          const SizedBox(height: 6),
          TextField(
            controller: _titleController,
            style: GoogleFonts.inter(fontSize: 13.5, color: _dark),
            decoration: _inputDecoration(
              hintText: 'e.g. 🌧️ Heavy Rain Warning: San Carlos City',
              prefixIcon: Icons.title_rounded,
            ),
          ),
          const SizedBox(height: 16),

          // Notification Message
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFieldLabel('Notification Message Body'),
              Text(
                '${_messageController.text.length} chars',
                style: GoogleFonts.inter(fontSize: 11, color: _muted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _messageController,
            maxLines: 3,
            style: GoogleFonts.inter(fontSize: 13.5, color: _dark),
            decoration: _inputDecoration(
              hintText: 'Compose your push notification broadcast text...',
              prefixIcon: Icons.chat_bubble_outline_rounded,
            ),
          ),
          const SizedBox(height: 10),

          // Quick Emoji Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickEmojis.map((emoji) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      _messageController.text += emoji;
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _border),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 14)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          // Media Image URL
          _buildFieldLabel('Produce / Banner Image URL (Optional)'),
          const SizedBox(height: 6),
          TextField(
            controller: _imageUrlController,
            style: GoogleFonts.inter(fontSize: 13, color: _dark),
            decoration: _inputDecoration(
              hintText: 'https://images.unsplash.com/...',
              prefixIcon: Icons.image_outlined,
            ),
          ),
          const SizedBox(height: 18),

          // Deep Link Type
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('In-App Navigation Target'),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _linkType,
                          isExpanded: true,
                          style: GoogleFonts.inter(fontSize: 13, color: _dark, fontWeight: FontWeight.w600),
                          items: const [
                            DropdownMenuItem(value: 'weather', child: Text('🌦️ Weather Radar & Forecast')),
                            DropdownMenuItem(value: 'flash_sale', child: Text('🌽 Flash Harvest Sale')),
                            DropdownMenuItem(value: 'farmer_dashboard', child: Text('🚜 Farmer Sales Dashboard')),
                            DropdownMenuItem(value: 'announcement', child: Text('📢 Platform Announcement')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _linkType = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Right Column: Interactive Phone Simulator & Weather Engine ───────────
  Widget _buildPreviewAndWeatherColumn() {
    return Column(
      children: [
        // Live Smartphone Simulator Card
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x04000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.remove_red_eye_outlined, size: 18, color: _primary),
                      const SizedBox(width: 8),
                      Text(
                        'Live Mobile Device Preview',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _dark,
                        ),
                      ),
                    ],
                  ),
                  // Android / iOS Switcher
                  Container(
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        _deviceToggle('Android', !_isIosPreview, () => setState(() => _isIosPreview = false)),
                        _deviceToggle('iOS', _isIosPreview, () => setState(() => _isIosPreview = true)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Device Screen Mockup
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Status bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '12:00 PM',
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const Row(
                          children: [
                            Icon(Icons.wifi_rounded, size: 14, color: Colors.white70),
                            SizedBox(width: 4),
                            Icon(Icons.battery_full_rounded, size: 14, color: Colors.white70),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Notification Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: _primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.spa_rounded, color: Colors.white, size: 12),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'AGRIDIRECT',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white70,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '• Just now',
                                style: GoogleFonts.inter(fontSize: 10.5, color: Colors.white38),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _titleController.text.isNotEmpty ? _titleController.text : 'AgriDirect Alert',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _messageController.text.isNotEmpty
                                ? _messageController.text
                                : 'Your fresh harvest and weather update will appear here in real-time.',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, height: 1.4),
                          ),
                          if (_imageUrlController.text.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _imageUrlController.text.trim(),
                                height: 110,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _primary.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _primary.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.touch_app_rounded, size: 12, color: Color(0xFF6EE7B7)),
                                const SizedBox(width: 5),
                                Text(
                                  'Tap to open $_linkType',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF6EE7B7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Automated Cloud Weather Monitor Card
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x04000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF0284C7), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Cloud Weather Cron Engine',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _dark,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _scanningWeather ? null : _runWeatherScanNow,
                    icon: _scanningWeather
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.bolt_rounded, size: 16),
                    label: Text(
                      _scanningWeather ? 'Scanning...' : 'Scan Now',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Supabase cloud pg_cron monitors live OpenWeather forecasts across registered Pangasinan farms every 6 hours and broadcasts typhoon & rain alerts automatically.',
                style: GoogleFonts.inter(fontSize: 12.5, color: _muted, height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: _primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Target Grid: San Carlos City (15.9224°N, 120.3489°E)',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _dark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _deviceToggle(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : _muted,
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 10,
        color: _muted,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.inter(fontSize: 13, color: _muted),
      prefixIcon: Icon(prefixIcon, color: _muted, size: 18),
      filled: true,
      fillColor: _surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
    );
  }

  String _audienceLabel(String aud) {
    switch (aud) {
      case 'farmers':
        return 'All Farmers';
      case 'customers':
        return 'All Customers';
      case 'farmers_customers':
        return 'Platform-Wide';
      default:
        return 'Admin Device';
    }
  }
}
