import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/admin/admin_service.dart';
import '../../../shared/services/auth/auth_service.dart';
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
  final _targetUserIdController = TextEditingController();
  final _linkIdController = TextEditingController();

  String _audience = 'test_me'; // 'test_me', 'test_user', 'farmers', 'customers', 'farmers_customers'
  String _linkType = 'flash_sale';
  String _notificationCode = 'promo_weather_rain';
  bool _sending = false;
  bool _scanningWeather = false;
  Map<String, dynamic>? _lastResult;
  Map<String, dynamic>? _lastWeatherScanResult;
  String _selectedPresetId = 'rain_promo';
  bool _isIosPreview = false;

  final List<Map<String, dynamic>> _presets = [
    {
      'id': 'rain_promo',
      'title': 'Stay cozy with fresh farm soup veggies! 🍲🌧️',
      'body': '10% OFF hearty stew & root vegetable baskets today! 💚 Direct from local farms. Tap to check fresh harvest! 📲',
      'code': 'promo_weather_rain',
      'linkType': 'flash_sale',
      'label': '🍲 Rainy Day Promo',
      'category': 'Consumer Marketing',
    },
    {
      'id': 'farmer_storm',
      'title': '⚠️ Severe Storm Advisory for your farm',
      'body': 'Storm conditions detected in your area. Secure loose farm structures, verify drainage, and protect mature crops. 🚜',
      'code': 'weather_storm',
      'linkType': 'weather',
      'label': '⚠️ Storm Advisory',
      'category': 'Farmer Weather Alert',
    },
    {
      'id': 'farmer_rain',
      'title': '🌧️ Farm Rain & Drainage Advisory',
      'body': 'High chance of heavy rainfall in the next 12 hours. Ensure field drainage is clear and harvest ripe produce early.',
      'code': 'weather_rain',
      'linkType': 'weather',
      'label': '🌧️ Rain Advisory',
      'category': 'Farmer Weather Alert',
    },
    {
      'id': 'flash_harvest',
      'title': 'Fresh harvest alert! Sweet corn just arrived 🌽🚜',
      'body': 'Nueva Ecija sweet corn is freshly harvested! 15% off for early bird pre-orders today. Tap to reserve a basket!',
      'code': 'flash_sale',
      'linkType': 'flash_sale',
      'label': '🌽 Flash Harvest Drop',
      'category': 'Consumer Marketing',
    },
    {
      'id': 'market_demand',
      'title': 'High buyer demand for Tomatoes! 🍅📈',
      'body': 'Buyer inquiries in your province have surged. Tap to update your inventory and post available harvest crates.',
      'code': 'market_demand',
      'linkType': 'farmer_dashboard',
      'label': '🍅 Market Demand Surge',
      'category': 'Farmer Market Alert',
    },
    {
      'id': 'da_advisory',
      'title': '🌾 Department of Agriculture Advisory',
      'body': 'New climate-resilient seed distribution schedule is now active. Check the community hub for participating centers.',
      'code': 'advisory',
      'linkType': 'announcement',
      'label': '📢 DA Platform Notice',
      'category': 'Official Advisory',
    },
  ];

  final List<String> _quickEmojis = [
    '🍲', '🌧️', '☔', '🌽', '🍅', '🥕', '⚠️', '⚡', '🚜', '🧺', '💚', '📲', '🌾', '☀️', '📦', '🔥',
  ];

  @override
  void initState() {
    super.initState();
    _applyPreset(_presets.first);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _targetUserIdController.dispose();
    _linkIdController.dispose();
    super.dispose();
  }

  void _applyPreset(Map<String, dynamic> preset) {
    setState(() {
      _selectedPresetId = preset['id'];
      _titleController.text = preset['title'];
      _messageController.text = preset['body'];
      _notificationCode = preset['code'];
      _linkType = preset['linkType'];
      _linkIdController.clear();
    });
  }

  void _insertEmoji(String emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    if (selection.start >= 0 && selection.end >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, emoji);
      _messageController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + emoji.length),
      );
    } else {
      _messageController.text += emoji;
    }
    setState(() {});
  }

  Future<void> _triggerWeatherScan() async {
    setState(() {
      _scanningWeather = true;
      _lastWeatherScanResult = null;
    });

    try {
      final result = await widget.adminService.triggerDailyWeatherCheck();
      if (!mounted) return;
      setState(() => _lastWeatherScanResult = result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AdminUi.brand,
          content: Text(
            '✅ Weather scan completed: ${result['checked'] ?? 0} farms evaluated, ${result['sent'] ?? 0} alerts dispatched.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AdminUi.danger,
          content: Text('Weather scan failed: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _scanningWeather = false);
    }
  }

  Future<void> _sendNotification() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and message are required.')),
      );
      return;
    }

    // Confirmation if broadcasting to all or farmers
    if (_audience == 'farmers' || _audience == 'customers' || _audience == 'farmers_customers') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AdminUi.radiusMd),
          title: Row(
            children: [
              const Icon(Icons.campaign_rounded, color: AdminUi.brand),
              const SizedBox(width: 10),
              Text('Confirm Broadcast Push', style: AdminUi.title(size: 18)),
            ],
          ),
          content: Text(
            'Are you sure you want to broadcast this push notification to ${_audience.replaceAll('_', ' ').toUpperCase()}?\n\nThis will be delivered to active devices immediately.',
            style: AdminUi.body(size: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: AdminUi.body(color: AdminUi.textMuted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: AdminUi.primaryButton,
              child: const Text('Confirm & Send'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() {
      _sending = true;
      _lastResult = null;
    });

    try {
      Map<String, dynamic> result;
      if (_audience == 'test_me') {
        final currentAdminId = AuthService().userId.isNotEmpty
            ? AuthService().userId
            : Supabase.instance.client.auth.currentUser?.id;

        if (currentAdminId == null || currentAdminId.isEmpty) {
          throw Exception('Could not determine current admin user ID.');
        }

        result = await widget.adminService.sendTestPushNotification(
          targetUserId: currentAdminId,
          title: title,
          body: message,
          notificationCode: _notificationCode,
          linkType: _linkType,
          linkId: _linkIdController.text.trim().isNotEmpty ? _linkIdController.text.trim() : null,
        );
      } else if (_audience == 'test_user') {
        final targetId = _targetUserIdController.text.trim();
        if (targetId.isEmpty) {
          throw Exception('Please enter a Target User ID.');
        }
        result = await widget.adminService.sendTestPushNotification(
          targetUserId: targetId,
          title: title,
          body: message,
          notificationCode: _notificationCode,
          linkType: _linkType,
          linkId: _linkIdController.text.trim().isNotEmpty ? _linkIdController.text.trim() : null,
        );
      } else {
        result = await widget.adminService.sendCustomPushNotification(
          audience: _audience,
          title: title,
          body: message,
          notificationCode: _notificationCode,
          linkType: _linkType,
          linkId: _linkIdController.text.trim().isNotEmpty ? _linkIdController.text.trim() : null,
        );
      }

      if (!mounted) return;
      setState(() => _lastResult = result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AdminUi.brand,
          content: Text(
            _audience.startsWith('test')
                ? '✅ Test push sent successfully!'
                : '✅ Campaign push dispatched to audience.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AdminUi.danger,
          content: Text(widget.adminService.errorMessage ?? 'Failed to send: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminDashboardHeader(
          title: 'Push Studio & Weather Hub',
          subtitle: 'Automated weather notifications, contextual marketing campaigns, and real-time push testing.',
          actions: [
            OutlinedButton.icon(
              onPressed: _scanningWeather ? null : _triggerWeatherScan,
              style: OutlinedButton.styleFrom(
                foregroundColor: AdminUi.brand,
                side: const BorderSide(color: AdminUi.brand),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: AdminUi.radiusSm),
              ),
              icon: _scanningWeather
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AdminUi.brand),
                    )
                  : const Icon(Icons.cloud_sync_rounded, size: 18),
              label: Text(_scanningWeather ? 'Scanning...' : 'Trigger Weather Scan'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _sending ? null : _sendNotification,
              style: AdminUi.primaryButton,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(
                      _audience.startsWith('test') ? Icons.send_to_mobile_rounded : Icons.campaign_rounded,
                      size: 18,
                    ),
              label: Text(
                _sending
                    ? 'Processing...'
                    : _audience.startsWith('test')
                        ? 'Send Test Push'
                        : 'Broadcast Push',
              ),
            ),
          ],
        ),

        // 1. Weather Automation Cloud Engine Status Banner
        _buildWeatherAutomationBanner(),
        const SizedBox(height: 24),

        // 2. Weather Scan Result Summary (if triggered)
        if (_lastWeatherScanResult != null) ...[
          _buildWeatherScanResultCard(),
          const SizedBox(height: 24),
        ],

        // 3. Main Composition Grid & Live Phone Mockup
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1080;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildStudioForm()),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: _buildPreviewColumn()),
                ],
              );
            }
            return Column(
              children: [
                _buildStudioForm(),
                const SizedBox(height: 24),
                _buildPreviewColumn(),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildWeatherAutomationBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AdminUi.radiusMd,
        border: Border.all(color: AdminUi.border),
        boxShadow: AdminUi.shadowSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminUi.brandSoft,
              borderRadius: AdminUi.radiusSm,
            ),
            child: const Icon(Icons.bolt_rounded, color: AdminUi.brand, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Automated Cloud Weather Service',
                      style: AdminUi.title(size: 16),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AdminUi.accentSoft,
                        borderRadius: AdminUi.radiusFull,
                      ),
                      child: Text(
                        '100% AUTOMATIC • 24/7',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AdminUi.brand,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'The Supabase cloud cron scheduler automatically monitors live OpenWeather forecasts across all registered farm coordinates every 6 hours and dispatches real-time storm warnings, rain advisories, and crop safeguard alerts directly to farmers\' mobile phones.',
                  style: AdminUi.body(size: 13, color: AdminUi.textSecondary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _buildFeaturePill(Icons.schedule_rounded, 'Schedule: Every 6h (pg_cron)'),
                    _buildFeaturePill(Icons.gps_fixed_rounded, 'Hyper-local Farm GPS'),
                    _buildFeaturePill(Icons.psychology_rounded, 'Crop-Specific Logic'),
                    _buildFeaturePill(Icons.shield_outlined, 'Duplicate Cooldown Protection'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePill(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AdminUi.brandSecondary),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AdminUi.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherScanResultCard() {
    final checked = _lastWeatherScanResult?['checked'] ?? 0;
    final sent = _lastWeatherScanResult?['sent'] ?? 0;
    final errors = _lastWeatherScanResult?['errors'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: AdminUi.radiusMd,
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AdminUi.brandSecondary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Latest Live Weather Scan Diagnostics',
                  style: AdminUi.title(size: 14, color: AdminUi.brand),
                ),
                const SizedBox(height: 2),
                Text(
                  'Farms Scanned: $checked active farms • Alerts Triggered & Sent: $sent • Errors: $errors',
                  style: AdminUi.body(size: 13, color: AdminUi.brandDark),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: AdminUi.brand),
            onPressed: () => setState(() => _lastWeatherScanResult = null),
          ),
        ],
      ),
    );
  }

  Widget _buildStudioForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminUi.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preset Chips Section
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AdminUi.brand, size: 18),
              const SizedBox(width: 8),
              Text('Preset Campaign Templates', style: AdminUi.label(size: 13)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((preset) {
              final isSelected = _selectedPresetId == preset['id'];
              return ChoiceChip(
                label: Text(preset['label']),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) _applyPreset(preset);
                },
                selectedColor: AdminUi.brandSoft,
                backgroundColor: AdminUi.background,
                labelStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AdminUi.brand : AdminUi.textPrimary,
                ),
                side: BorderSide(
                  color: isSelected ? AdminUi.brand : AdminUi.border,
                ),
                shape: RoundedRectangleBorder(borderRadius: AdminUi.radiusSm),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: AdminUi.border),
          const SizedBox(height: 24),

          // Target Audience
          Text('Dispatch Mode & Audience', style: AdminUi.label(size: 12)),
          const SizedBox(height: 8),
          InputDecorator(
            decoration: AdminUi.inputDecoration(),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _audience,
                isExpanded: true,
                isDense: true,
                items: const [
                  DropdownMenuItem(
                    value: 'test_me',
                    child: Row(
                      children: [
                        Icon(Icons.phone_android_rounded, size: 18, color: AdminUi.brandSecondary),
                        SizedBox(width: 8),
                        Text('🧪 Test Push → Send directly to my Admin device'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'test_user',
                    child: Row(
                      children: [
                        Icon(Icons.person_search_rounded, size: 18, color: AdminUi.info),
                        SizedBox(width: 8),
                        Text('🎯 Targeted Test → Send to specific User ID'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'farmers',
                    child: Row(
                      children: [
                        Icon(Icons.agriculture_rounded, size: 18, color: AdminUi.brand),
                        SizedBox(width: 8),
                        Text('🚜 Broadcast → All Registered Farmers'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'customers',
                    child: Row(
                      children: [
                        Icon(Icons.shopping_basket_rounded, size: 18, color: AdminUi.warning),
                        SizedBox(width: 8),
                        Text('🧺 Broadcast → All Consumers & Buyers'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'farmers_customers',
                    child: Row(
                      children: [
                        Icon(Icons.public_rounded, size: 18, color: AdminUi.brandDark),
                        SizedBox(width: 8),
                        Text('📢 Global Broadcast → Farmers + Consumers'),
                      ],
                    ),
                  ),
                ],
                onChanged: _sending ? null : (v) => setState(() => _audience = v ?? _audience),
              ),
            ),
          ),

          if (_audience == 'test_user') ...[
            const SizedBox(height: 16),
            Text('Target User ID', style: AdminUi.label(size: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _targetUserIdController,
              enabled: !_sending,
              decoration: AdminUi.inputDecoration(
                hintText: 'Enter UUID of target user or farmer',
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Notification Title', style: AdminUi.label(size: 12)),
              Text(
                '${_titleController.text.length} chars',
                style: AdminUi.body(size: 11, color: AdminUi.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            enabled: !_sending,
            onChanged: (_) => setState(() {}),
            decoration: AdminUi.inputDecoration(
              hintText: 'e.g. Stay cozy with fresh farm soup veggies! 🍲',
            ),
          ),
          const SizedBox(height: 20),

          // Quick Emoji Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Notification Message Body', style: AdminUi.label(size: 12)),
              Text(
                '${_messageController.text.length} chars',
                style: AdminUi.body(size: 11, color: AdminUi.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AdminUi.background,
              borderRadius: BorderRadius.vertical(top: AdminUi.radiusSm.topLeft),
              border: Border.all(color: AdminUi.border),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text('Quick Emojis: ', style: AdminUi.label(size: 11, color: AdminUi.textMuted)),
                  ..._quickEmojis.map(
                    (emoji) => InkWell(
                      onTap: () => _insertEmoji(emoji),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(emoji, style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          TextField(
            controller: _messageController,
            enabled: !_sending,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Write the notification copy with emojis and promotional offer...',
              hintStyle: AdminUi.body(color: AdminUi.textMuted),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.vertical(bottom: AdminUi.radiusSm.bottomLeft),
                borderSide: const BorderSide(color: AdminUi.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.vertical(bottom: AdminUi.radiusSm.bottomLeft),
                borderSide: const BorderSide(color: AdminUi.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.vertical(bottom: AdminUi.radiusSm.bottomLeft),
                borderSide: const BorderSide(color: AdminUi.brand, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),

          const SizedBox(height: 20),

          // Deep Link Routing Destination
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('On-Tap Deep Link Action', style: AdminUi.label(size: 12)),
                    const SizedBox(height: 8),
                    InputDecorator(
                      decoration: AdminUi.inputDecoration(),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _linkType,
                          isExpanded: true,
                          isDense: true,
                          items: const [
                            DropdownMenuItem(value: 'weather', child: Text('🌦️ Weather Radar & Forecast')),
                            DropdownMenuItem(value: 'flash_sale', child: Text('⚡ Flash Harvest & Promos')),
                            DropdownMenuItem(value: 'marketplace', child: Text('🛒 Produce Marketplace')),
                            DropdownMenuItem(value: 'farmer_dashboard', child: Text('🚜 Farmer Sales Dashboard')),
                            DropdownMenuItem(value: 'announcement', child: Text('📢 Community Forum & Bulletin')),
                            DropdownMenuItem(value: 'preorder', child: Text('📦 Pre-Order Reservation')),
                            DropdownMenuItem(value: 'product', child: Text('🏷️ Specific Product Details')),
                          ],
                          onChanged: _sending ? null : (v) => setState(() => _linkType = v ?? _linkType),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_linkType == 'preorder' || _linkType == 'product') ...[
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Target Reference ID', style: AdminUi.label(size: 12)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _linkIdController,
                        enabled: !_sending,
                        decoration: AdminUi.inputDecoration(
                          hintText: 'Enter ${_linkType == "product" ? "Product" : "Preorder"} ID',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          if (_lastResult != null) ...[
            const SizedBox(height: 24),
            const Divider(height: 1, color: AdminUi.border),
            const SizedBox(height: 16),
            _ResultSummary(result: _lastResult!),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: AdminUi.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.remove_red_eye_rounded, color: AdminUi.brand, size: 18),
                      const SizedBox(width: 8),
                      Text('Live Mobile Preview', style: AdminUi.title(size: 16)),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AdminUi.background,
                      borderRadius: AdminUi.radiusSm,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      children: [
                        _buildPlatformToggle(false, 'Android'),
                        _buildPlatformToggle(true, 'iOS'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Mockup Phone Frame
              _buildPhoneMockup(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlatformToggle(bool isIos, String label) {
    final isSelected = _isIosPreview == isIos;
    return InkWell(
      onTap: () => setState(() => _isIosPreview = isIos),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected ? AdminUi.shadowSm : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AdminUi.brand : AdminUi.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneMockup() {
    final title = _titleController.text.trim().isEmpty ? 'AgriDirect Alert' : _titleController.text.trim();
    final body = _messageController.text.trim().isEmpty
        ? 'Your fresh harvest and weather update will appear here in real-time.'
        : _messageController.text.trim();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: AdminUi.shadowMd,
        border: Border.all(color: const Color(0xFF334155), width: 3),
      ),
      child: Column(
        children: [
          // Phone Status Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '12:00 PM',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: const [
                    Icon(Icons.wifi_rounded, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Icon(Icons.signal_cellular_4_bar_rounded, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Icon(Icons.battery_full_rounded, size: 14, color: Colors.white),
                  ],
                ),
              ],
            ),
          ),

          // Notification Banner Card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isIosPreview
                    ? const Color(0xFF262626).withValues(alpha: 0.92)
                    : const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Header
                  Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AdminUi.brand,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.eco_rounded, color: Colors.white, size: 14),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AGRIDIRECT',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFE2E8F0),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '•  Just now',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.expand_more_rounded, size: 16, color: Color(0xFF94A3B8)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Notification Title
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Notification Body
                  Text(
                    body,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      height: 1.4,
                      color: const Color(0xFFCBD5E1),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Action Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AdminUi.brandSoft.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AdminUi.brandSecondary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.touch_app_rounded, size: 13, color: AdminUi.brandSecondary),
                        const SizedBox(width: 6),
                        Text(
                          'Tap to open ${_linkType.replaceAll("_", " ")}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AdminUi.brandSecondary,
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
    );
  }
}

class _ResultSummary extends StatelessWidget {
  final Map<String, dynamic> result;
  const _ResultSummary({required this.result});

  @override
  Widget build(BuildContext context) {
    final users = (result['users'] as num?)?.toInt();
    final sent = (result['sent'] as num?)?.toInt();
    final total = (result['total'] as num?)?.toInt();
    final reason = result['reason']?.toString();

    final summary = [
      if (users != null) 'Users: $users',
      if (sent != null && total != null) 'Delivered: $sent/$total',
      if (reason != null && reason.isNotEmpty) reason,
    ].join(' • ');

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: (sent != null && total != null && total > 0 && sent == 0)
                ? AdminUi.warning
                : AdminUi.success,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            summary.isEmpty ? 'Dispatched successfully.' : summary,
            style: AdminUi.body(size: 13, color: AdminUi.textSecondary),
          ),
        ),
      ],
    );
  }
}
