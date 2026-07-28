import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../shared/styles/app_theme.dart';

class KikoAiChatScreen extends StatefulWidget {
  final bool embedMode;
  const KikoAiChatScreen({super.key, this.embedMode = false});

  @override
  State<KikoAiChatScreen> createState() => _KikoAiChatScreenState();
}

class _KikoAiChatScreenState extends State<KikoAiChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final List<Map<String, dynamic>> _messages;
  bool _isTyping = false;

  final List<String> _quickPrompts = [
    '🌾 How to list new crops?',
    '🌧️ How does weather alert work?',
    '🎟️ How to claim shop vouchers?',
    '🚚 How do pre-orders work?',
    '💳 Supported payment methods?',
  ];

  @override
  void initState() {
    super.initState();
    final nowStr = DateFormat('h:mm a').format(DateTime.now());
    _messages = [
      {
        'isUser': false,
        'text': 'Moo! Hello! I\'m Kiko your AgriDirect Carabao Assistant 🌾. How can I help you today? Tap a quick question below or type your inquiry!',
        'time': nowStr,
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
    });

    _scrollToBottom();

    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    final String reply = _generateKikoAiReply(text);
    final replyTimeStr = DateFormat('h:mm a').format(DateTime.now());

    setState(() {
      _isTyping = false;
      _messages.add({
        'isUser': false,
        'text': reply,
        'time': replyTimeStr,
      });
    });

    _scrollToBottom();
  }

  String _generateKikoAiReply(String userQuery) {
    final lower = userQuery.toLowerCase();

    // 1. Greetings & Personal Questions
    if (lower.contains('hello') || lower.contains('hi') || lower.contains('kumusta') || lower.contains('kamusta') || lower.contains('gandang') || lower.contains('sino ka')) {
      return 'Moo! 🐮 Magandang araw po! Ako si Kiko, ang inyong opisyal na AgriDirect Carabao AI Assistant 🌾.\n\n'
          'Handa akong tumulong sa inyo—mula sa pag-order ng sariwang gulay at prutas, pag-preorder ng ani, hanggang sa pagbebenta at pag-track ng inyong orders. Anong maipaglilingkod ko ngayon?';
    }

    // 2. Listing Crops & Selling (Farmer Support)
    if (lower.contains('paano magbenta') || lower.contains('list') || lower.contains('crop') || lower.contains('sell') || lower.contains('magbenta') || lower.contains('product') || lower.contains('tindahan')) {
      return 'Moo! 🌱 Para mag-list at magbenta ng ani bilang magsasaka:\n\n'
          '1️⃣ Pumunta sa Profile o gamitin ang top toggle para mag-switch sa **Farmer Mode**.\n'
          '2️⃣ I-tap ang **"+ Add Product"** button sa inyong dashboard.\n'
          '3️⃣ Mag-upload ng malinaw na larawan ng ani, ilagay ang presyo (per kg/bundle), at ilagay ang dami ng stock.\n'
          '4️⃣ Kung hindi pa ready ang ani, maaari mong i-toggle ang **Pre-Order** at ilagay ang estimated harvest date.\n'
          '5️⃣ I-tap ang **Publish** para makita agad ng mga buyers sa marketplace!';
    }

    // 3. Buying & How to Order (Consumer Support)
    if (lower.contains('paano bumili') || lower.contains('order') || lower.contains('buy') || lower.contains('bumili') || lower.contains('cart') || lower.contains('checkout')) {
      return 'Moo! 🛒 Madali lang bumili ng sariwang ani sa AgriDirect:\n\n'
          '• Pumunta sa **Marketplace** tab para mag-browse ng fresh produce mula sa ating local farmers.\n'
          '• I-tap ang item na gusto mo at piliin ang **Add to Cart** o **Buy Now**.\n'
          '• Sa checkout, piliin ang inyong delivery address at payment method (Cash on Delivery / Pickup).\n'
          '• Maaari ring mag-preorder ng mga aning paparating pa lang sa ilalim ng **Pre-Orders** hub!';
    }

    // 4. Pre-Orders & Harvest Schedules
    if (lower.contains('pre-order') || lower.contains('preorder') || lower.contains('reserve') || lower.contains('ani') || lower.contains('harvest')) {
      return 'Moo! 🌾 Ang **Pre-Orders** ay paraan para ma-reserve mo ang ani habang tinatanim pa lang ng magsasaka!\n\n'
          '• Siguradong sariwa dahil diretsong ihaharvest para sa order mo.\n'
          '• Maaari mong i-track ang growth milestones ng tanim under **Orders -> Track Order**.\n'
          '• Pagka-harvest, diretso itong ipadadala sa inyong tahanan o pickup point.';
    }

    // 5. Vouchers & Discounts
    if (lower.contains('voucher') || lower.contains('discount') || lower.contains('tipid') || lower.contains('code') || lower.contains('claim')) {
      return 'Moo! 🎟️ Gusto mo ba ng karagdagang bawas sa presyo?\n\n'
          '• Bisitahin ang pampublikong profile ng inyong paboritong magsasaka para mag-claim ng exclusive shop vouchers.\n'
          '• Tingnan ang inyong claimed codes sa **Profile -> My Vouchers**.\n'
          '• Awtomatikong ma-a-apply ang discount code kapag nag-checkout ka!';
    }

    // 6. Weather Alerts & Climate Analytics
    if (lower.contains('weather') || lower.contains('rain') || lower.contains('radar') || lower.contains('ulan') || lower.contains('bagyo') || lower.contains('panahon')) {
      return 'Moo! 🌧️ May live rain radar at weather alerts ang AgriDirect!\n\n'
          '• Makikita sa inyong Home Dashboard ang kasalukuyang panahon at rain probability sa inyong barangay.\n'
          '• Awtomatikong nagbibigay ng heads-up alert si Kiko kapag inaasahang uulan ngayon para ma-protektahan ang inyong ani at delivery schedule.';
    }

    // 7. Payment Methods & Shipping
    if (lower.contains('payment') || lower.contains('cod') || lower.contains('cop') || lower.contains('pay') || lower.contains('bayad') || lower.contains('deliver')) {
      return 'Moo! 💳 Suportado ng AgriDirect ang dalawang ligtas na paraan ng pagbabayad:\n\n'
          '1️⃣ **Cash on Delivery (COD)** – Magbayad pagkarating ng sariwang gulay at prutas sa inyong pintuan.\n'
          '2️⃣ **Cash on Pickup (COP)** – Magbayad kapag kinuha ang order sa mismong farm hub ng magsasaka.\n\n'
          'Maaari mong baguhin ang delivery address sa **Profile -> Address Book**.';
    }

    // 8. Support Escalation & Contact
    if (lower.contains('tulong') || lower.contains('help') || lower.contains('support') || lower.contains('tawag') || lower.contains('contact') || lower.contains('reklamo') || lower.contains('report')) {
      return 'Moo! 🎧 Kung kailangan mo ng direktang kausap o may problema sa order:\n\n'
          '• Maaari kang mag-submit ng support ticket sa **Contact Support**.\n'
          '• Mag-email sa support@agridirect.ph o tumawag sa ating hotline.\n'
          '• O gamitin ang **Report an Issue** kung may na-encounter na bug o delivery glitch.';
    }

    // Default Friendly Intelligent Response
    return 'Moo! 🌾 Salamat sa pagtatanong tungkol sa "$userQuery"!\n\n'
        'Maaari mong i-explore ang **Marketplace** para sa mga sariwang gulay, tingnan ang **FAQs** sa ilalim ng Kiko Support, o pumunta sa **Contact Support** para sa direktang tulong ng ating team. Nandidito lang ako para tumulong!';
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
      backgroundColor: AppColors.background,
      appBar: widget.embedMode
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 1,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textHeadline, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              title: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Image.asset(
                        'assets/images/kiko_happy.png',
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.support_agent_rounded,
                                color: Color(0xFF10B981), size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kiko AI Assistant',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.textHeadline,
                        ),
                      ),
                      Text(
                        'Online • Ready to help',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF10B981),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.embedMode)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade100, width: 1.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.01),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDCFCE7),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Image.asset(
                          'assets/images/kiko_happy.png',
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.support_agent_rounded,
                                  color: Color(0xFF10B981), size: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kiko AI Assistant',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.textHeadline,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Online • Ready to help',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF10B981),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isTyping) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Kiko is typing...',
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSubtle),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final msg = _messages[index];
                  final bool isUser = msg['isUser'] as bool;

                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isUser ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isUser ? 18 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 18),
                        ),
                        border: isUser ? null : Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg['text'].toString(),
                            style: GoogleFonts.plusJakartaSans(
                              color: isUser ? Colors.white : AppColors.textHeadline,
                              fontSize: 13.5,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            msg['time'].toString(),
                            style: GoogleFonts.inter(
                              color: isUser ? Colors.white70 : AppColors.textSubtle,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Quick Prompt Chips
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _quickPrompts.length,
                itemBuilder: (context, index) {
                  final prompt = _quickPrompts[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      elevation: 0,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                      label: Text(
                        prompt,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      onPressed: () => _sendMessage(prompt),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // Message Input bar with ViewInsets padding for keyboard
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                10,
                16,
                MediaQuery.of(context).viewInsets.bottom + 12,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: _messageController,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: 'Ask Kiko anything...',
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textSubtle),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _sendMessage(),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
