import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../shared/services/auth/auth_service.dart';

class KikoAiChatScreen extends StatefulWidget {
  final bool embedMode;
  const KikoAiChatScreen({super.key, this.embedMode = false});

  @override
  State<KikoAiChatScreen> createState() => _KikoAiChatScreenState();
}

class _KikoAiChatScreenState extends State<KikoAiChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final List<Map<String, dynamic>> _messages;
  bool _isTyping = false;
  String _currentKikoMood = 'assets/images/kiko_happy.png';

  final AuthService _auth = AuthService();

  // Categorized Discovery Prompts
  List<Map<String, dynamic>> get _discoveryCategories {
    final isFarmer = _auth.isViewingAsFarmer;
    if (isFarmer) {
      return [
        {
          'category': 'FARMING',
          'icon': Icons.eco_rounded,
          'color': const Color(0xFF059669),
          'bg': const Color(0xFFECFDF5),
          'prompts': [
            '🌾 How to list & price new crops?',
            '🌱 Best weather window for planting?',
            '🌧️ How to protect crops from heavy rain?',
          ],
        },
        {
          'category': 'SALES & ORDERS',
          'icon': Icons.receipt_long_rounded,
          'color': const Color(0xFF2563EB),
          'bg': const Color(0xFFEFF6FF),
          'prompts': [
            '📊 How to view my daily & monthly sales?',
            '📦 How do harvest pre-orders work?',
            '🎟️ How to create shop vouchers for fans?',
          ],
        },
      ];
    } else {
      return [
        {
          'category': 'SHOPPING',
          'icon': Icons.shopping_basket_rounded,
          'color': const Color(0xFF059669),
          'bg': const Color(0xFFECFDF5),
          'prompts': [
            '🛒 How to order fresh produce directly?',
            '🎟️ How to claim discount vouchers?',
            '🚚 How do pre-orders work?',
          ],
        },
        {
          'category': 'PAYMENT & SUPPORT',
          'icon': Icons.payments_rounded,
          'color': const Color(0xFF7C3AED),
          'bg': const Color(0xFFF5F3FF),
          'prompts': [
            '💳 Supported payment & delivery methods?',
            '📍 How to track my order status?',
            '🎧 Contact direct customer support',
          ],
        },
      ];
    }
  }

  @override
  void initState() {
    super.initState();
    final nowStr = DateFormat('h:mm a').format(DateTime.now());
    _messages = [
      {
        'isUser': false,
        'text':
            'Moo! Hello! I\'m Kiko, your official AgriDirect Carabao AI Assistant 🌾.\n\nAsk me anything about farming schedules, weather advisories, marketplace orders, or voucher discounts!',
        'time': nowStr,
        'followUps': <String>[
          '🌾 How to list new crops?',
          '🌦️ Weather & Rain Advice',
          '🎟️ Vouchers & Discounts',
        ],
      },
    ];
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage([String? promptText]) async {
    final text = promptText ?? _messageController.text.trim();
    if (text.isEmpty) return;

    if (promptText == null) {
      _messageController.clear();
    }

    final nowStr = DateFormat('h:mm a').format(DateTime.now());

    setState(() {
      _messages.add({
        'isUser': true,
        'text': text,
        'time': nowStr,
      });
      _isTyping = true;
      _currentKikoMood = 'assets/images/kiko_cloudy.png'; // Thinking state
    });

    _scrollToBottom();

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final Map<String, dynamic> replyData = _generateKikoAiReply(text);
    final replyTimeStr = DateFormat('h:mm a').format(DateTime.now());

    setState(() {
      _isTyping = false;
      _currentKikoMood = replyData['mood'] as String? ?? 'assets/images/kiko_happy.png';
      _messages.add({
        'isUser': false,
        'text': replyData['text'] as String,
        'time': replyTimeStr,
        'followUps': replyData['followUps'] as List<String>?,
      });
    });

    _scrollToBottom();
  }

  Map<String, dynamic> _generateKikoAiReply(String userQuery) {
    final lower = userQuery.toLowerCase();

    // 1. Greetings
    if (lower.contains('hello') ||
        lower.contains('hi') ||
        lower.contains('kumusta') ||
        lower.contains('kamusta') ||
        lower.contains('gandang') ||
        lower.contains('sino ka') ||
        lower.contains('hey') ||
        lower.contains('oy') ||
        lower.contains('morning') ||
        lower.contains('afternoon')) {
      return {
        'text':
            'Moo! 🐮 Magandang araw po! Ako si Kiko, ang inyong opisyal na AgriDirect Carabao AI Assistant 🌾.\n\nHanda akong tumulong sa inyo—mula sa pag-order ng sariwang gulay at prutas, pag-preorder ng ani, hanggang sa pagbebenta at pag-track ng inyong orders.',
        'mood': 'assets/images/kiko_happy.png',
        'followUps': ['🌾 How to list crops?', '🛒 How to order?', '🌦️ Weather tips'],
      };
    }

    // 2. Listing Crops & Selling (Farmer Support)
    if (lower.contains('list') ||
        lower.contains('crop') ||
        lower.contains('sell') ||
        lower.contains('magbenta') ||
        lower.contains('product') ||
        lower.contains('tindahan') ||
        lower.contains('upload') ||
        lower.contains('gulay')) {
      return {
        'text':
            'Moo! 🌱 Para mag-list at magbenta ng ani bilang magsasaka:\n\n'
            '1️⃣ Pumunta sa Profile o gamitin ang top toggle para mag-switch sa **Farmer Mode**.\n'
            '2️⃣ I-tap ang **"+ Add Product"** button sa inyong dashboard.\n'
            '3️⃣ Mag-upload ng malinaw na larawan ng ani, ilagay ang presyo (per kg/bundle), at ilagay ang dami ng stock.\n'
            '4️⃣ Kung paparating pa lang ang ani, maaari mong i-toggle ang **Pre-Order** at ilagay ang estimated harvest date.\n'
            '5️⃣ I-tap ang **Publish** para makita agad ng mga buyers sa marketplace!',
        'mood': 'assets/images/kiko_happy.png',
        'followUps': ['📊 How to view my sales?', '🎟️ Create shop vouchers'],
      };
    }

    // 3. Buying & How to Order (Consumer Support)
    if (lower.contains('order') ||
        lower.contains('buy') ||
        lower.contains('bumili') ||
        lower.contains('cart') ||
        lower.contains('checkout') ||
        lower.contains('pabili')) {
      return {
        'text':
            'Moo! 🛒 Madali lang bumili ng sariwang ani sa AgriDirect:\n\n'
            '• Pumunta sa **Marketplace** tab para mag-browse ng fresh produce mula sa ating local farmers.\n'
            '• I-tap ang item na gusto mo at piliin ang **Add to Cart** o **Buy Now**.\n'
            '• Sa checkout, piliin ang inyong delivery address at payment method (Cash on Delivery / Pickup).\n'
            '• Maaari ring mag-preorder ng mga aning paparating pa lang sa ilalim ng **Pre-Orders** hub!',
        'mood': 'assets/images/kiko_happy.png',
        'followUps': ['💳 Payment methods?', '🎟️ Claim discount vouchers'],
      };
    }

    // 4. Pre-Orders & Harvest Schedules
    if (lower.contains('pre-order') ||
        lower.contains('preorder') ||
        lower.contains('reserve') ||
        lower.contains('ani') ||
        lower.contains('harvest')) {
      return {
        'text':
            'Moo! 🌾 Ang **Pre-Orders** ay paraan para ma-reserve mo ang ani habang tinatanim pa lang ng magsasaka!\n\n'
            '• Siguradong sariwa dahil diretsong ihaharvest para sa order mo.\n'
            '• Maaari mong i-track ang growth milestones ng tanim under **Orders -> Track Order**.\n'
            '• Pagka-harvest, diretso itong ipadadala sa inyong tahanan o pickup point.',
        'mood': 'assets/images/kiko_happy.png',
        'followUps': ['🛒 Browse Marketplace', '📍 Track existing orders'],
      };
    }

    // 5. Vouchers & Discounts
    if (lower.contains('voucher') ||
        lower.contains('discount') ||
        lower.contains('tipid') ||
        lower.contains('code') ||
        lower.contains('claim') ||
        lower.contains('promo') ||
        lower.contains('sale')) {
      return {
        'text':
            'Moo! 🎟️ Gusto mo ba ng karagdagang bawas sa presyo?\n\n'
            '• Bisitahin ang pampublikong profile ng inyong paboritong magsasaka para mag-claim ng exclusive shop vouchers.\n'
            '• Tingnan ang inyong claimed codes sa **Profile -> My Vouchers**.\n'
            '• Awtomatikong ma-a-apply ang discount code kapag nag-checkout ka!',
        'mood': 'assets/images/kiko_happy.png',
        'followUps': ['🛒 Go to Marketplace', '🌾 List new crops'],
      };
    }

    // 6. Weather & Climate Advisories
    if (lower.contains('weather') ||
        lower.contains('rain') ||
        lower.contains('ulan') ||
        lower.contains('bagyo') ||
        lower.contains('panahon') ||
        lower.contains('init') ||
        lower.contains('forecast') ||
        lower.contains('spraying')) {
      return {
        'text':
            'Moo! 🌧️ Narito ang live agronomic weather guidance mula kay Kiko:\n\n'
            '• **Spraying Advisory**: Kung may banta ng ulan o hangin higit sa 15 km/h, ipagpaliban ang pag-spray ng foliar fertilizers para maiwasan ang wash-off.\n'
            '• **Irrigation Window**: Sa mainit na araw (higit sa 30°C), magdilig nang maaga sa umaga (5:30–7:30 AM) para mabawasan ang evaporation.\n'
            '• Buksan ang **Weather & Farm Intelligence** screen para sa live radar map at 24-hour temperature curve!',
        'mood': 'assets/images/kiko_rainy.jpg',
        'followUps': ['🌾 Crop care tips', '📦 Pre-orders status'],
      };
    }

    // 7. Payment Methods & Shipping
    if (lower.contains('payment') ||
        lower.contains('cod') ||
        lower.contains('cop') ||
        lower.contains('bayad') ||
        lower.contains('deliver') ||
        lower.contains('shipping') ||
        lower.contains('gcash')) {
      return {
        'text':
            'Moo! 💳 Suportado ng AgriDirect ang dalawang ligtas na paraan ng pagbabayad:\n\n'
            '1️⃣ **Cash on Delivery (COD)** – Magbayad pagkarating ng sariwang gulay at prutas sa inyong pintuan.\n'
            '2️⃣ **Cash on Pickup (COP)** – Magbayad kapag kinuha ang order sa mismong farm hub ng magsasaka.\n\n'
            'Maaari mong i-manage ang inyong addresses sa **Profile -> Address Book**.',
        'mood': 'assets/images/kiko_happy.png',
        'followUps': ['🛒 Start Shopping', '🎟️ Claim Vouchers'],
      };
    }

    // Default Friendly Response
    return {
      'text':
          'Moo! 🌾 Salamat sa pagtatanong tungkol sa "$userQuery"!\n\n'
          'Maaari mong i-explore ang **Marketplace** para sa mga sariwang gulay, tingnan ang **Weather & Farm Intelligence** para sa agronomic forecasts, o mag-reach out sa **Contact Support** para sa direktang tulong.',
      'mood': 'assets/images/kiko_happy.png',
      'followUps': ['🌾 Listing crops guide', '🌦️ Weather Advisory', '🛒 How to order'],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isTyping) {
                    return _buildTypingIndicator();
                  }

                  final msg = _messages[index];
                  final bool isUser = msg['isUser'] as bool;
                  final followUps = msg['followUps'] as List<String>?;

                  return _buildMessageBubble(
                    text: msg['text'].toString(),
                    time: msg['time'].toString(),
                    isUser: isUser,
                    followUps: followUps,
                  );
                },
              ),
            ),

            // Discovery Topic Horizontal Carousel (if not typing)
            if (!_isTyping) _buildTopicCarousel(),

            // Message Input Bar
            _buildInputComposer(),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. APP BAR & EMBED HEADER
  // ===========================================================================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE2E8F0), height: 1),
      ),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Color(0xFF0F172A),
          size: 18,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          // Dynamic Kiko Avatar
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFECFDF5),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: ClipOval(
              child: Image.asset(
                _currentKikoMood,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.smart_toy_rounded,
                  color: Color(0xFF059669),
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Kiko AI Assistant',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'AI',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  _isTyping ? 'Thinking...' : 'Online • Ready to help',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _isTyping ? const Color(0xFFD97706) : const Color(0xFF059669),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: Color(0xFF64748B),
            size: 20,
          ),
          tooltip: 'Clear Chat',
          onPressed: () {
            setState(() {
              _messages.clear();
              final nowStr = DateFormat('h:mm a').format(DateTime.now());
              _messages.add({
                'isUser': false,
                'text':
                    'Moo! Chat reset. How can I help you today? Pick a topic below or type your inquiry!',
                'time': nowStr,
              });
            });
          },
        ),
      ],
    );
  }

  Widget _buildEmbedHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFECFDF5),
            ),
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kiko AI Carabao Assistant',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Online 24/7 • Agricultural & Market Intelligence',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF059669),
                    fontWeight: FontWeight.w600,
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
  // 2. MESSAGE BUBBLE BUILDER
  // ===========================================================================
  Widget _buildMessageBubble({
    required String text,
    required String time,
    required bool isUser,
    List<String>? followUps,
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
                      _currentKikoMood,
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

              // Bubble Card
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                  ),
                  padding: const EdgeInsets.all(14),
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
                          alpha: isUser ? 0.08 : 0.03,
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
                      Text(
                        text,
                        style: GoogleFonts.inter(
                          color: isUser ? Colors.white : const Color(0xFF1E293B),
                          fontSize: 13.5,
                          height: 1.45,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 6),
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
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            chipText,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF059669),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
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

  // ===========================================================================
  // 3. BOUNCING DOTS TYPING INDICATOR
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
                  'Kiko is thinking…',
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
  // 4. TOPIC DISCOVERY CAROUSEL
  // ===========================================================================
  Widget _buildTopicCarousel() {
    final categories = _discoveryCategories;

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: categories.expand((c) => c['prompts'] as List<String>).length,
        itemBuilder: (context, idx) {
          final allPrompts =
              categories.expand((c) => c['prompts'] as List<String>).toList();
          final prompt = allPrompts[idx];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => _sendMessage(prompt),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    prompt,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // 5. INPUT COMPOSER
  // ===========================================================================
  Widget _buildInputComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _messageController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: 'Ask Kiko anything…',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF94A3B8),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF047857)],
              ),
              shape: BoxShape.circle,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _sendMessage(),
                borderRadius: BorderRadius.circular(22),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
