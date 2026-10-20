import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../shared/services/ai/ai_service.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/integration/weather_service.dart';
import '../../../shared/models/weather_model.dart';
import '../../../web/widgets/ecom/web_ecom_header.dart';

class KikoAiChatScreen extends StatefulWidget {
  final bool embedMode;
  final VoidCallback? onClose;
  final VoidCallback? onExpand;
  const KikoAiChatScreen({
    super.key,
    this.embedMode = false,
    this.onClose,
    this.onExpand,
  });

  @override
  State<KikoAiChatScreen> createState() => _KikoAiChatScreenState();
}

class _KikoAiChatScreenState extends State<KikoAiChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final AuthService _auth = AuthService();
  final AiService _aiService = AiService();
  final WeatherService _weatherService = WeatherService();

  late final List<Map<String, dynamic>> _messages;
  bool _isTyping = false;
  String _currentKikoMood = 'assets/images/kiko_happy.png';
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  WeatherData? _currentWeather;

  String get _weatherPromptLabel {
    if (_currentWeather != null) {
      final desc = _currentWeather!.description;
      final temp = _currentWeather!.temperature.toStringAsFixed(0);
      return '🌤️ Live Weather Advice ($desc, $temp°C)';
    }
    return '🌤️ Live Farm Weather Advice';
  }


  @override
  void initState() {
    super.initState();
    _messages = [];
    _fetchLiveWeather();
  }

  Future<void> _fetchLiveWeather() async {
    try {
      final weather = await _weatherService.getWeatherByCity('San Carlos City, Pangasinan');
      if (mounted && weather != null) {
        setState(() {
          _currentWeather = weather;
          // Update the first follow up if applicable
          if (_messages.isNotEmpty && _messages[0]['followUps'] != null) {
            final list = List<String>.from(_messages[0]['followUps'] as List);
            for (int i = 0; i < list.length; i++) {
              if (list[i].contains('Weather')) {
                list[i] = _weatherPromptLabel;
              }
            }
            _messages[0]['followUps'] = list;
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Pick image from camera or gallery for crop diagnosis
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = image.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load image: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Build conversation history for multi-turn LLM context
  List<Map<String, String>> _buildConversationHistory() {
    final List<Map<String, String>> history = [];
    final recentMessages = _messages.length > 8
        ? _messages.sublist(_messages.length - 8)
        : _messages;

    for (final msg in recentMessages) {
      final isUser = msg['isUser'] as bool;
      final text = msg['text'] as String;
      history.add({
        'role': isUser ? 'user' : 'assistant',
        'content': text,
      });
    }
    return history;
  }

  void _sendMessage([String? promptText]) async {
    final text = promptText ?? _messageController.text.trim();
    final imageBytes = _selectedImageBytes;

    if (text.isEmpty && imageBytes == null) return;

    if (promptText == null) {
      _messageController.clear();
    }

    final nowStr = DateFormat('h:mm a').format(DateTime.now());

    // Add user message to UI
    setState(() {
      _messages.add({
        'isUser': true,
        'text': text.isNotEmpty ? text : '📷 [Attached Photo for Crop Diagnosis]',
        'time': nowStr,
        'imageBytes': imageBytes,
      });
      _isTyping = true;
      _currentKikoMood = 'assets/images/kiko_cloudy.png'; // Thinking state
      _selectedImageBytes = null;
      _selectedImageName = null;
    });

    _scrollToBottom();

    String replyText;
    List<String> followUps = [];

    try {
      if (imageBytes != null) {
        // Vision AI diagnosis call
        replyText = await _aiService.diagnoseCropImage(
          imageBytes: imageBytes,
          additionalNotes: text.isNotEmpty ? text : null,
        );
        followUps = [
          '🌾 Paano gamutin ito nang organic?',
          '🌧️ Mag-spray ba bago umulan?',
          '📍 Kumontak sa Farm Support',
        ];
      } else {
        // Enrich prompt with live weather if asking about weather
        String effectivePrompt = text;
        final lower = text.toLowerCase();
        if (lower.contains('weather') ||
            lower.contains('ulan') ||
            lower.contains('panahon') ||
            lower.contains('rain') ||
            lower.contains('araw') ||
            lower.contains('temp')) {
          if (_currentWeather != null) {
            effectivePrompt = '$text\n\n[LIVE AGRO-WEATHER TELEMETRY FOR SAN CARLOS CITY, PANGASINAN]: '
                'Condition: ${_currentWeather!.description}, '
                'Temperature: ${_currentWeather!.temperature.toStringAsFixed(1)}°C (Feels like ${_currentWeather!.feelsLike.toStringAsFixed(0)}°C), '
                'Humidity: ${_currentWeather!.humidity}%, '
                'Wind: ${_currentWeather!.windSpeed.toStringAsFixed(1)} km/h, '
                'Precipitation Rate: ${_currentWeather!.precipitationRate} mm/h. '
                'Please provide specific, practical agronomic advice (irrigation, spraying window, crop protection) based on these EXACT current conditions right now.';
          }
        }

        // Multi-turn Conversational AI call
        final history = _buildConversationHistory();
        replyText = await _aiService.getChatResponse(
          conversationHistory: history,
          userPrompt: effectivePrompt,
        );

        followUps = _generateContextualFollowUps(text, replyText);
      }
    } catch (e) {
      // Dynamic Contextual Fallback
      final fallback = _generateKikoFallbackReply(text);
      replyText = fallback['text'] as String;
      followUps = fallback['followUps'] as List<String>? ?? [];
    }

    if (!mounted) return;

    final replyTimeStr = DateFormat('h:mm a').format(DateTime.now());

    setState(() {
      _isTyping = false;
      _currentKikoMood = 'assets/images/kiko_happy.png';
      _messages.add({
        'isUser': false,
        'text': replyText,
        'time': replyTimeStr,
        'followUps': followUps,
      });
    });

    _scrollToBottom();
  }

  List<String> _generateContextualFollowUps(String query, String response) {
    final lower = query.toLowerCase();
    if (lower.contains('pest') || lower.contains('uod') || lower.contains('sakit')) {
      return ['🌿 Organic pest spray recipe', '🌧️ Weather spraying advisory', '🌾 Crop care tips'];
    }
    if (lower.contains('presyo') || lower.contains('price') || lower.contains('benta')) {
      return ['📊 View my sales', '🎟️ Create shop vouchers', '📦 How pre-orders work'];
    }
    if (lower.contains('order') || lower.contains('bili') || lower.contains('cart')) {
      return ['🎟️ Claim discount vouchers', '💳 Payment options', '📍 Track my order'];
    }
    if (lower.contains('weather') || lower.contains('ulan') || lower.contains('panahon')) {
      return ['🌱 Best crops for this season', '💧 Irrigation advisory', '🧪 Safe spraying window'];
    }
    return ['🌾 Farming advice', _weatherPromptLabel, '🛒 Marketplace Guide'];
  }

  Map<String, dynamic> _generateKikoFallbackReply(String userQuery) {
    final lower = userQuery.toLowerCase();

    // Context-Aware Live Weather Advice Fallback
    if (lower.contains('weather') || lower.contains('ulan') || lower.contains('panahon') || lower.contains('rain')) {
      final weather = _currentWeather;
      if (weather != null) {
        final desc = weather.description.toLowerCase();
        final isStorm = desc.contains('storm') || desc.contains('thunder');
        final isRain = desc.contains('rain') || desc.contains('drizzle') || weather.precipitationRate > 0.1;
        final isCloudy = desc.contains('cloud') || desc.contains('overcast');

        if (isStorm) {
          return {
            'text':
                '### ⚡ **Live Weather Alert: Thunderstorm in San Carlos City**\n\n'
                'Kasalukuyang may **${weather.description}** (${weather.temperature.toStringAsFixed(0)}°C, Humidity: ${weather.humidity}%).\n\n'
                '• **Worker Safety**: Ihinto muna ang trabaho sa bukas na bukid at sumilong sa ligtas na lugar.\n'
                '• **Drainage Check**: Siguraduhing bukas ang mga daluyan ng tubig upang hindi malubog ang mga bagong punla.\n'
                '• **Equipment**: Ipasok ang mga pataba at makinarya sa tuyong bodega.',
            'followUps': ['🌱 Crop drainage tips', '💧 Post-storm soil care'],
          };
        } else if (isRain) {
          return {
            'text':
                '### 🌧️ **Live Weather Advisory: Ulan sa San Carlos City**\n\n'
                'Kasalukuyang may **${weather.description}** (${weather.temperature.toStringAsFixed(0)}°C, Hangin: ${weather.windSpeed} km/h).\n\n'
                '• **Spraying Advisory**: Ipagpaliban muna ang foliar spray at pesticide application upang hindi mahugasan ng ulan.\n'
                '• **Harvest Protection**: Agad ilagay sa tuyong imbakan ang mga bagong aning pananim.\n'
                '• **Irrigation**: Patayin ang automated water pumps dahil sapat ang natural na moisture.',
            'followUps': ['🧪 Kailan pwedeng mag-spray?', '🌾 Tamang pagpapatuyo ng ani'],
          };
        } else if (isCloudy) {
          return {
            'text':
                '### ⛅ **Live Weather Advisory: Maulap sa San Carlos City**\n\n'
                'Kasalukuyang **${weather.description}** (${weather.temperature.toStringAsFixed(0)}°C, Humidity: ${weather.humidity}%).\n\n'
                '• **Good for Transplanting**: Maganda ang panahon para maglipat-tanim dahil hindi matindi ang sikat ng araw.\n'
                '• **Disease Monitoring**: Dahil sa mataas na humidity (${weather.humidity}%), bantayan ang dahon laban sa fungal blight o amag.\n'
                '• **Spraying Window**: Mainam mag-spray ng organic bio-stimulants habang kalmado ang hangin (${weather.windSpeed} km/h).',
            'followUps': ['🧪 Organic fungicide recipe', '💧 Irrigation schedule'],
          };
        } else {
          return {
            'text':
                '### ☀️ **Live Weather Advisory: Maaraw sa San Carlos City**\n\n'
                'Kasalukuyang **${weather.description}** (${weather.temperature.toStringAsFixed(0)}°C, Feels like ${weather.feelsLike.toStringAsFixed(0)}°C).\n\n'
                '• **Irrigation**: Magdilig nang malalim sa maagang umaga o dapithapon bago tumindi ang init.\n'
                '• **Crop Drying**: Tamang-tama ang araw para sa pagpapatuyo ng palay, mais, at buto.\n'
                '• **Mulching**: Lagyan ng mulch (dayami) ang paligid ng pananim upang mapanatili ang moisture.',
            'followUps': ['🌾 Tips sa pagpapatuyo ng palay', '💧 Water saving tips'],
          };
        }
      }
    }

    if (lower.contains('presyo') || lower.contains('price') || lower.contains('magkano') || lower.contains('cost')) {
      return {
        'text':
            '### 🌾 **Gabay sa Pagpepresyo ng Ani (Farmer Pricing Guide)** 🐮\n\n'
            'Moo! Narito ang simpleng formula para sa patas at kumikitang presyo:\n\n'
            '1. **Kwentahin ang Production Cost (Puhunan)**:\n'
            '   • Binhi/Punla + Pataba/Pesticides + Labor/Paggawa + Tubig/Kuryente.\n'
            '2. **Magdagdag ng Makatwirang Profit Margin**:\n'
            '   • Karaniwang **25% hanggang 40%** na tubo para sa sariwang gulay at prutas.\n'
            '3. **Suriin ang Prevailing Market Price**:\n'
            '   • Tingnan ang kasalukuyang presyo sa DA Bantay Presyo at local San Carlos City markets.\n'
            '4. **Direct-to-Consumer Advantage**:\n'
            '   • Dahil walang middleman sa AgriDirect, maaari kang magpresyo nang mas abot-kaya sa mga mamimili habang mas mataas ang iyong kita!\n\n'
            '💡 *Tip: Para sa bulk orders o pre-orders bago ang harvest, magbigay ng 5-10% discount gamit ang Shop Vouchers.*',
        'followUps': ['📊 View my sales', '🎟️ Create shop vouchers', '📦 How pre-orders work'],
      };
    }

    if (lower.contains('crop') || lower.contains('sell') || lower.contains('benta') || lower.contains('list') || lower.contains('ani')) {
      return {
        'text':
            '### 🌾 **AgriDirect Harvest Listing Guide**\n\n'
            'Para mag-post ng sariwang ani sa marketplace:\n\n'
            '1. I-switch ang inyong app sa **Farmer Mode**.\n'
            '2. Pumunta sa **Products Tab** at i-tap ang **"+ LIST PRODUCT"**.\n'
            '3. Mag-upload ng malinaw na litrato ng inyong ani.\n'
            '4. Ilagay ang pangalan ng gulay/pananim, presyo kada kilo, at available quantity (kg).\n'
            '5. Piliin kung **Standard Stock (Available Now)** o **Pre-order (Paparating na Harvest)**.',
        'followUps': ['📊 View my sales', '🎟️ Create shop vouchers', '📷 I-diagnose ang pananim ko'],
      };
    }

    return {
      'text':
          'Moo! 🌾 Nandito ako para tumulong sa inyong pagsasaka at pamimili sa AgriDirect.\n\n'
          'Pumili ng tanong sa ibaba o mag-upload ng litrato ng inyong pananim para sa instant AI diagnosis!',
      'followUps': [_weatherPromptLabel, '🌾 Crop care guide', '🛒 How to order'],
    };
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Copied response to clipboard'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF059669),
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWebDesktop = kIsWeb && !widget.embedMode && screenWidth >= 800;

    if (isWebDesktop) {
      return Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: Column(
          children: [
            WebEcomHeader(
              currentIndex: -1,
              onNavigate: (index, [route]) {
                if (route != null) {
                  context.go(route);
                }
              },
            ),
            Expanded(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 880),
                  margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.07),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      children: [
                        _buildWebChatHeader(),
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                            itemCount: _messages.length + 1 + (_isTyping ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return _buildMigooHeroHeader();
                              }
                              if (index == _messages.length + 1 && _isTyping) {
                                return _buildTypingIndicator();
                              }

                              final msg = _messages[index - 1];
                              final bool isUser = msg['isUser'] as bool;
                              final followUps = msg['followUps'] as List<String>?;
                              final imageBytes = msg['imageBytes'] as Uint8List?;

                              return _buildMessageBubble(
                                text: msg['text'].toString(),
                                time: msg['time'].toString(),
                                isUser: isUser,
                                followUps: followUps,
                                imageBytes: imageBytes,
                              );
                            },
                          ),
                        ),
                        if (_selectedImageBytes != null) _buildImagePreviewBar(),
                        if (!_isTyping && _selectedImageBytes == null) _buildCategoryShortcutBar(),
                        _buildInputComposer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: widget.embedMode ? null : _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.embedMode) _buildEmbedHeader(),

            // Chat Message List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                itemCount: _messages.length + 1 + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildMigooHeroHeader();
                  }
                  if (index == _messages.length + 1 && _isTyping) {
                    return _buildTypingIndicator();
                  }

                  final msg = _messages[index - 1];
                  final bool isUser = msg['isUser'] as bool;
                  final followUps = msg['followUps'] as List<String>?;
                  final imageBytes = msg['imageBytes'] as Uint8List?;

                  return _buildMessageBubble(
                    text: msg['text'].toString(),
                    time: msg['time'].toString(),
                    isUser: isUser,
                    followUps: followUps,
                    imageBytes: imageBytes,
                  );
                },
              ),
            ),

            // Image Preview Badge (if photo is selected)
            if (_selectedImageBytes != null) _buildImagePreviewBar(),

            // Category shortcut bar (Shopping, Voucher, Inbox, Deals)
            if (!_isTyping && _selectedImageBytes == null) _buildCategoryShortcutBar(),

            // Message Input Bar (Capsule)
            _buildInputComposer(),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. APP BAR & EMBED HEADER (MIGOO MINIMALIST STYLE)
  // ===========================================================================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.person_outline_rounded,
          color: Color(0xFF1F2937),
          size: 24,
        ),
        tooltip: 'Profile',
        onPressed: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        },
      ),
      centerTitle: true,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Kiko',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: const Color(0xFF111827),
            ),
          ),
          Text(
            'Generated by AI',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.description_outlined,
            color: Color(0xFF1F2937),
            size: 22,
          ),
          tooltip: 'Options & Topics',
          onPressed: _showChatOptionsSheet,
        ),
      ],
    );
  }

  Widget _buildEmbedHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  Color(0xFFE11D48),
                  Color(0xFF9333EA),
                  Color(0xFF0284C7),
                  Color(0xFF06B6D4),
                  Color(0xFFF59E0B),
                  Color(0xFFE11D48),
                ],
              ),
            ),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              padding: const EdgeInsets.all(2),
              child: ClipOval(
                child: Image.asset(
                  _currentKikoMood,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.smart_toy_rounded,
                    color: Color(0xFF059669),
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kiko',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: const Color(0xFF111827),
                  ),
                ),
                Text(
                  'Generated by AI',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.description_outlined, size: 20, color: Color(0xFF1F2937)),
            tooltip: 'Options',
            onPressed: _showChatOptionsSheet,
          ),
          if (widget.onExpand != null)
            IconButton(
              icon: const Icon(Icons.open_in_full_rounded, size: 16, color: Color(0xFF64748B)),
              tooltip: 'Open Full Page',
              visualDensity: VisualDensity.compact,
              onPressed: widget.onExpand,
            ),
          if (widget.onClose != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
              tooltip: 'Minimize',
              visualDensity: VisualDensity.compact,
              onPressed: widget.onClose,
            ),
        ],
      ),
    );
  }

  Widget _buildWebChatHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            padding: const EdgeInsets.all(2.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  Color(0xFFE11D48),
                  Color(0xFF9333EA),
                  Color(0xFF0284C7),
                  Color(0xFF06B6D4),
                  Color(0xFFF59E0B),
                  Color(0xFFE11D48),
                ],
              ),
            ),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              padding: const EdgeInsets.all(2),
              child: ClipOval(
                child: Image.asset(
                  _currentKikoMood,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.smart_toy_rounded,
                    color: Color(0xFF059669),
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Kiko',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        'AI',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Generated by AI • AgriDirect Assistant',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.description_outlined, color: Color(0xFF1F2937), size: 22),
            tooltip: 'Options',
            onPressed: _showChatOptionsSheet,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. IMAGE PREVIEW BAR
  // ===========================================================================
  Widget _buildImagePreviewBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _selectedImageBytes!,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attached Crop Image',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  _selectedImageName ?? 'Ready for AI Diagnosis',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 18),
            onPressed: () {
              setState(() {
                _selectedImageBytes = null;
                _selectedImageName = null;
              });
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. MESSAGE BUBBLE & RICH MARKDOWN TEXT RENDERER
  // ===========================================================================
  Widget _buildMessageBubble({
    required String text,
    required String time,
    required bool isUser,
    List<String>? followUps,
    Uint8List? imageBytes,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Kiko Avatar on AI responses
              if (!isUser) ...[
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 8, bottom: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFECFDF5),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/kiko_happy.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.smart_toy_rounded,
                        color: Color(0xFF059669),
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],

              // Message Body Container
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: math.min(
                      580.0,
                      MediaQuery.of(context).size.width * 0.82,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? const LinearGradient(
                            colors: [Color(0xFF059669), Color(0xFF047857)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isUser ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    border: isUser
                        ? null
                        : Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(
                          alpha: isUser ? 0.08 : 0.04,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: isUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      // Attached image display in bubble
                      if (imageBytes != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            imageBytes,
                            width: double.infinity,
                            height: 160,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Formatted Rich Message Body
                      _buildRichMessageContent(text, isUser),
                      const SizedBox(height: 6),

                      // Time + Action Footer
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            time,
                            style: GoogleFonts.inter(
                              color: isUser
                                  ? Colors.white.withValues(alpha: 0.75)
                                  : const Color(0xFF94A3B8),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (!isUser) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _copyToClipboard(text),
                              child: const Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(
                                  Icons.copy_rounded,
                                  size: 13,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Follow-up suggestion action chips
          if (!isUser && followUps != null && followUps.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: followUps.map((chipText) {
                  return InkWell(
                    onTap: () => _sendMessage(chipText),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              chipText,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF059669),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 12,
                            color: Color(0xFF059669),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// High-End Styled Rich Text & Markdown Parser
  Widget _buildRichMessageContent(String rawText, bool isUser) {
    if (isUser) {
      return Text(
        rawText,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 13.5,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    final lines = rawText.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      // Horizontal Divider
      if (line == '---' || line == '***') {
        widgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Color(0xFFE2E8F0), height: 1, thickness: 1),
          ),
        );
        continue;
      }

      // Header 1, 2, 3 (###)
      if (line.startsWith('#')) {
        final cleanHeader = line.replaceAll(RegExp(r'^#+\s*'), '');
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 3.5,
                  height: 14,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    _parseInlineSpans(cleanHeader, isHeader: true),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Bullet points (- or • or * )
      if (line.startsWith('- ') || line.startsWith('• ') || (line.startsWith('* ') && !line.endsWith('*'))) {
        final cleanItem = line.replaceFirst(RegExp(r'^[-•*]\s*'), '');
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Color(0xFF059669),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    _parseInlineSpans(cleanItem),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Standard Paragraph
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text.rich(
            _parseInlineSpans(line),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Parse **bold** and *italic* markdown inline into styled TextSpans
  TextSpan _parseInlineSpans(String text, {bool isHeader = false}) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'(\*\*(.*?)\*\*|\*(.*?)\*|`(.*?)`)');
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: isHeader
                ? GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                    height: 1.35,
                  )
                : GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF334155),
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                  ),
          ),
        );
      }

      final boldGroup = match.group(2);
      final italicGroup = match.group(3);
      final codeGroup = match.group(4);

      if (boldGroup != null) {
        spans.add(
          TextSpan(
            text: boldGroup,
            style: GoogleFonts.inter(
              fontSize: isHeader ? 13.5 : 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
              height: 1.4,
            ),
          ),
        );
      } else if (italicGroup != null) {
        spans.add(
          TextSpan(
            text: italicGroup,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: const Color(0xFF475569),
              height: 1.4,
            ),
          ),
        );
      } else if (codeGroup != null) {
        spans.add(
          TextSpan(
            text: ' $codeGroup ',
            style: GoogleFonts.robotoMono(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF059669),
              backgroundColor: const Color(0xFFECFDF5),
            ),
          ),
        );
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: isHeader
              ? GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                  height: 1.35,
                )
              : GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF334155),
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                ),
        ),
      );
    }

    return TextSpan(children: spans);
  }

  // ===========================================================================
  // 4. TYPING INDICATOR
  // ===========================================================================
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8, bottom: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFECFDF5),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.3),
              ),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/kiko_cloudy.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF059669),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Kiko is analyzing with AI…',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. MIGOO HERO HEADER, SUGGESTION PILLS & SHORTCUTS
  // ===========================================================================
  List<String> get _migooSuggestionPrompts {
    final isFarmer = _auth.isViewingAsFarmer;
    if (isFarmer) {
      return [
        _weatherPromptLabel,
        '🌾 Gabay sa pagpepresyo ng ani',
        '🌱 Tamang planting window ng kamatis',
        '🐛 Pest and disease diagnosis guide',
        '📦 Paano gumagana ang pre-orders',
      ];
    }
    return [
      'Find best deals',
      'Snacks worth trying & fresh harvest',
      'Trending in organic produce',
      'Sun protection & farmer tools',
      'Useful kitchen storage tips',
    ];
  }

  Widget _buildMigooHeroHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          // Iridescent Mascot Avatar Halo (Migoo Style)
          Center(
            child: Container(
              width: 86,
              height: 86,
              padding: const EdgeInsets.all(3.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    Color(0xFFE11D48), // Rose / Magenta
                    Color(0xFF9333EA), // Purple
                    Color(0xFF0284C7), // Blue
                    Color(0xFF06B6D4), // Cyan
                    Color(0xFFF59E0B), // Warm Amber
                    Color(0xFFE11D48), // Wrap
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.22),
                    blurRadius: 18,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                padding: const EdgeInsets.all(4),
                child: ClipOval(
                  child: Image.asset(
                    _currentKikoMood,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.smart_toy_rounded,
                      color: Color(0xFF059669),
                      size: 38,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Welcome Message Bubble
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "Hi, I'm Kiko, your AgriDirect AI assistant. Tell me what you need, and I'll find reliable options, compare what matters, and help you choose what fits you best.",
              style: GoogleFonts.inter(
                fontSize: 14.5,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF1F2937),
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Staggered Suggestion Chips
          _buildSuggestionPills(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSuggestionPills() {
    final prompts = _migooSuggestionPrompts;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: prompts.map((prompt) {
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => _sendMessage(prompt),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Text(
                  prompt,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryShortcutBar() {
    final isFarmer = _auth.isViewingAsFarmer;
    final shortcuts = isFarmer
        ? [
            {'icon': Icons.eco_rounded, 'label': 'Farming', 'prompt': '🌾 Paano mag-list ng sariwang ani?'},
            {'icon': Icons.wb_sunny_rounded, 'label': 'Weather', 'prompt': _weatherPromptLabel},
            {'icon': Icons.receipt_long_rounded, 'label': 'Sales', 'prompt': '📊 Paano tingnan ang aking sales?'},
            {'icon': Icons.discount_rounded, 'label': 'Voucher', 'prompt': '🎟️ Paano gumawa ng shop vouchers?'},
          ]
        : [
            {'icon': Icons.shopping_bag_outlined, 'label': 'Shopping', 'prompt': '🛒 Paano mag-order ng sariwang ani?'},
            {'icon': Icons.confirmation_number_outlined, 'label': 'Voucher', 'prompt': '🎟️ Paano mag-claim ng exclusive discount vouchers?'},
            {'icon': Icons.inbox_outlined, 'label': 'Inbox', 'prompt': '📍 Paano i-track ang status ng aking order?'},
            {'icon': Icons.local_offer_outlined, 'label': 'Deals', 'prompt': 'Find best deals'},
          ];

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: shortcuts.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final item = shortcuts[idx];
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => _sendMessage(item['prompt'] as String),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item['icon'] as IconData, size: 16, color: const Color(0xFF374151)),
                    const SizedBox(width: 6),
                    Text(
                      item['label'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // 6. CAPSULE INPUT COMPOSER (MIGOO STYLE)
  // ===========================================================================
  Widget _buildInputComposer() {
    final hasText = _messageController.text.trim().isNotEmpty || _selectedImageBytes != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            // + Attachment Action (Camera / Gallery for Crop Diagnosis)
            IconButton(
              icon: const Icon(Icons.add_rounded, color: Color(0xFF1F2937), size: 24),
              tooltip: 'Attach photo for diagnosis',
              onPressed: _showAttachmentSheet,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            const SizedBox(width: 4),

            // Text Input Field
            Expanded(
              child: TextField(
                controller: _messageController,
                textInputAction: TextInputAction.send,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _sendMessage(),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF111827),
                ),
                decoration: InputDecoration(
                  hintText: 'Anything on your mind?',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF9CA3AF),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),

            // Trailing Mic or Send Action
            if (hasText)
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFF059669),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 19),
                  padding: EdgeInsets.zero,
                  onPressed: () => _sendMessage(),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.mic_none_rounded, color: Color(0xFF1F2937), size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Voice input is coming soon! You can type in the box.',
                        style: GoogleFonts.inter(fontSize: 13),
                      ),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 7. BOTTOM SHEETS (ATTACHMENT & CHAT OPTIONS)
  // ===========================================================================
  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Crop & Leaf Diagnosis',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload a clear photo of your plant or crop to identify diseases',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_camera_rounded, color: Color(0xFF059669)),
                  ),
                  title: Text(
                    'Take Photo (Camera)',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Snap a live photo of the leaf or harvest',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: Color(0xFF2563EB)),
                  ),
                  title: Text(
                    'Choose from Gallery',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Pick an existing photo from your device',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showChatOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Chat Options',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.refresh_rounded, color: Color(0xFFEF4444)),
                  ),
                  title: Text(
                    'Reset Conversation',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Clear active messages and return to fresh start',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _messages.clear();
                      _selectedImageBytes = null;
                      _selectedImageName = null;
                    });
                  },
                ),
                if (_currentWeather != null)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.wb_sunny_rounded, color: Color(0xFFD97706)),
                    ),
                    title: Text(
                      'Live Weather: ${_currentWeather!.temperature.toStringAsFixed(0)}°C',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(
                      'San Carlos City • ${_currentWeather!.description}',
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _sendMessage(_weatherPromptLabel);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
