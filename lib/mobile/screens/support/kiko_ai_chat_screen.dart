import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../shared/services/ai/ai_service.dart';
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
  final ImagePicker _imagePicker = ImagePicker();
  final AuthService _auth = AuthService();
  final AiService _aiService = AiService();

  late final List<Map<String, dynamic>> _messages;
  bool _isTyping = false;
  String _currentKikoMood = 'assets/images/kiko_happy.png';
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  // Categorized Discovery Prompts
  List<Map<String, dynamic>> get _discoveryCategories {
    final isFarmer = _auth.isViewingAsFarmer;
    if (isFarmer) {
      return [
        {
          'category': 'FARMING',
          'icon': Icons.eco_rounded,
          'color': const Color(0xFF059669),
          'prompts': [
            '🌾 Paano mag-list at mag-presyo ng bagong ani?',
            '🌱 Kailan ang tamang planting window para sa kamatis?',
            '🌧️ Paano protektahan ang pananim sa malakas na ulan?',
            '🐛 Paano puksain ang uod at pests gamit ang organic spray?',
          ],
        },
        {
          'category': 'SALES & ORDERS',
          'icon': Icons.receipt_long_rounded,
          'color': const Color(0xFF2563EB),
          'prompts': [
            '📊 Paano tingnan ang aking daily at monthly sales?',
            '📦 Paano gumagana ang pre-orders at harvest milestones?',
            '🎟️ Paano gumawa ng shop discount vouchers?',
          ],
        },
      ];
    } else {
      return [
        {
          'category': 'SHOPPING',
          'icon': Icons.shopping_basket_rounded,
          'color': const Color(0xFF059669),
          'prompts': [
            '🛒 Paano mag-order ng sariwang gulay direkta sa magsasaka?',
            '🎟️ Paano mag-claim ng exclusive discount vouchers?',
            '🌾 Paano mag-preorder ng paparating na ani?',
            '🥬 Paano tamang pag-imbak ng leafy greens para tumagal?',
          ],
        },
        {
          'category': 'PAYMENT & TRACKING',
          'icon': Icons.payments_rounded,
          'color': const Color(0xFF7C3AED),
          'prompts': [
            '💳 Ano ang mga supported payment methods (COD/COP)?',
            '📍 Paano i-track ang status ng aking order?',
            '🎧 Paano kumontak sa direct customer support?',
          ],
        },
      ];
    }
  }

  @override
  void initState() {
    super.initState();
    final nowStr = DateFormat('h:mm a').format(DateTime.now());
    final isFarmer = _auth.isViewingAsFarmer;

    _messages = [
      {
        'isUser': false,
        'text': isFarmer
            ? 'Moo! 🌾 Mabuhay! Ako si **Kiko**, ang inyong opisyal na AgriDirect Carabao AI Advisor 🐮.\n\n'
                'Handa akong tumulong sa:\n'
                '• **Pest & Crop Diagnosis**: Mag-upload ng photo ng dahon o pananim gamit ang camera icon 📷.\n'
                '• **Farming Advice**: Tamang pataba, irrigation schedule, at weather advisories.\n'
                '• **Marketplace & Sales**: Pag-presyo ng ani, pre-orders, at voucher promotions.'
            : 'Moo! 🛒 Hello! Ako si **Kiko**, ang inyong official AgriDirect AI Assistant 🐮.\n\n'
                'Maaari mo akong tanungin tungkol sa:\n'
                '• Pag-order ng sariwang ani direkta sa local farmers 🥬.\n'
                '• Pag-preorder ng paparating na harvest 🌾.\n'
                '• Tips sa pag-imbak at pagluluto ng sariwang gulay at prutas!',
        'time': nowStr,
        'followUps': isFarmer
            ? <String>[
                '🌾 Paano mag-presyo ng ani?',
                '📷 I-diagnose ang pananim ko',
                '🌧️ Weather & Rain Advice',
              ]
            : <String>[
                '🛒 Paano mag-order?',
                '🎟️ Vouchers & Discounts',
                '📍 Paano mag-track ng order?',
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

  void _removeSelectedImage() {
    setState(() {
      _selectedImageBytes = null;
      _selectedImageName = null;
    });
  }

  /// Build conversation history for multi-turn LLM context
  List<Map<String, String>> _buildConversationHistory() {
    final List<Map<String, String>> history = [];
    // Only take the last 8 messages to keep tokens optimal
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
        // Multi-turn Conversational AI call
        final history = _buildConversationHistory();
        replyText = await _aiService.getChatResponse(
          conversationHistory: history,
          userPrompt: text,
        );

        // Derive helpful quick chips based on context
        followUps = _generateContextualFollowUps(text, replyText);
      }
    } catch (e) {
      // Offline / Error fallback
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
    return ['🌾 Farming advice', '🌦️ Weather Advisory', '🛒 Marketplace Guide'];
  }

  Map<String, dynamic> _generateKikoFallbackReply(String userQuery) {
    final lower = userQuery.toLowerCase();
    if (lower.contains('crop') || lower.contains('sell') || lower.contains('benta')) {
      return {
        'text':
            'Moo! 🌱 Para mag-list ng ani sa AgriDirect:\n\n'
            '1. I-switch ang app sa **Farmer Mode**.\n'
            '2. I-tap ang **"+ Add Product"** sa dashboard.\n'
            '3. Ilagay ang malinaw na litrato, presyo, at stock.\n'
            '4. I-tap ang **Publish**!',
        'followUps': ['📊 View my sales', '🎟️ Create vouchers'],
      };
    }
    return {
      'text':
          'Moo! 🌾 Nandito ako para tumulong sa inyong pagsasaka at pamimili sa AgriDirect.\n\n'
          'Pumili ng tanong sa ibaba o subukang mag-upload ng larawan ng inyong pananim!',
      'followUps': ['🌾 Crop care guide', '🌦️ Weather Advisory', '🛒 How to order'],
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

            // Discovery Topic Horizontal Carousel (if not typing)
            if (!_isTyping && _selectedImageBytes == null) _buildTopicCarousel(),

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
                        'Kiko AI Carabao',
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
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'AI PRO',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  _isTyping ? 'Analyzing with AI…' : 'Online • Agricultural & Market Advisor',
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
            Icons.refresh_rounded,
            color: Color(0xFF64748B),
            size: 20,
          ),
          tooltip: 'Reset Chat',
          onPressed: () {
            setState(() {
              _messages.clear();
              final nowStr = DateFormat('h:mm a').format(DateTime.now());
              _messages.add({
                'isUser': false,
                'text':
                    'Moo! 🌾 Chat reset. Paano kita matutulungan sa inyong sakahan o pamimili ngayon?',
                'time': nowStr,
                'followUps': <String>[
                  '🌾 Crop care guide',
                  '📷 I-diagnose ang pananim',
                  '🛒 Paano mag-order?',
                ],
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
                  'Kiko AI Carabao Advisor',
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
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  _selectedImageName ?? 'Ready for AI diagnosis',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
            onPressed: _removeSelectedImage,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. MESSAGE BUBBLE BUILDER
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
                    maxWidth: MediaQuery.of(context).size.width * 0.82,
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

                      // Message Body
                      Text(
                        text,
                        style: GoogleFonts.inter(
                          color: isUser ? Colors.white : const Color(0xFF1E293B),
                          fontSize: 13.5,
                          height: 1.45,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),

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
  // 5. TOPIC DISCOVERY CAROUSEL
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
  // 6. INPUT COMPOSER
  // ===========================================================================
  Widget _buildInputComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 12),
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
          // Camera / Gallery Image Attachment Button
          PopupMenuButton<ImageSource>(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Color(0xFF059669),
                size: 19,
              ),
            ),
            tooltip: 'Diagnose Crop / Leaf Photo',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: _pickImage,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: ImageSource.camera,
                child: Row(
                  children: [
                    const Icon(Icons.photo_camera_rounded, color: Color(0xFF059669), size: 20),
                    const SizedBox(width: 10),
                    Text('Take Photo (Camera)', style: GoogleFonts.inter(fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: ImageSource.gallery,
                child: Row(
                  children: [
                    const Icon(Icons.photo_library_rounded, color: Color(0xFF2563EB), size: 20),
                    const SizedBox(width: 10),
                    Text('Choose from Gallery', style: GoogleFonts.inter(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),

          // Text Field
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
                  hintText: _selectedImageBytes != null
                      ? 'Add question about this photo (optional)…'
                      : 'Ask Kiko anything (Farming, Orders, Prices)…',
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

          // Send Button
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
