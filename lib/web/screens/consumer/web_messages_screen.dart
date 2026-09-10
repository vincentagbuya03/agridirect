import 'dart:async';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../mobile/screens/support/kiko_ai_chat_screen.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/communication/call_service.dart';
import '../../../shared/services/community/message_service.dart';
import '../../../shared/services/community/notification_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/widgets/app_shimmer_loader.dart';
import '../../../shared/widgets/image_widgets.dart';
import '../../../shared/widgets/pulsing_status_indicator.dart';
import '../../widgets/ecom/web_ecom_header.dart';

/// WebMessagesScreen
/// Dedicated Premier E-Commerce Desktop Messenger (Shopee / Lazada / WhatsApp Web style).
/// Completely separate from the mobile APK screens.
class WebMessagesScreen extends StatefulWidget {
  final String? initialFarmerId;
  final String? initialCustomerId;
  final String? initialConversationId;
  final bool? asFarmer;
  final ProductItem? initialProduct;

  const WebMessagesScreen({
    super.key,
    this.initialFarmerId,
    this.initialCustomerId,
    this.initialConversationId,
    this.asFarmer,
    this.initialProduct,
  });

  @override
  State<WebMessagesScreen> createState() => _WebMessagesScreenState();
}

class _WebMessagesScreenState extends State<WebMessagesScreen> {
  final AuthService _auth = AuthService();
  final MessageService _messageService = MessageService();
  final TextEditingController _composerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late bool _asFarmerInbox;
  String? _selectedConversationId;
  bool _isKikoSelected = false;
  bool _showRightDrawer = true;
  bool _startingInitialConversation = false;
  final List<ChatMessage> _optimisticMessages = [];
  String _conversationSearchQuery = '';
  late Stream<List<MessageConversation>> _inboxStream;

  @override
  void initState() {
    super.initState();
    _asFarmerInbox = widget.asFarmer ??
        (widget.initialFarmerId == null ? _auth.isViewingAsFarmer : false);
    _inboxStream = _messageService.watchInbox(asFarmer: _asFarmerInbox);
    _selectedConversationId = widget.initialConversationId;
    if (_selectedConversationId != null) {
      NotificationService().setActiveConversation(_selectedConversationId);
    }
    _handleInitialConversation();
  }

  @override
  void dispose() {
    NotificationService().setActiveConversation(null);
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleInitialConversation() async {
    final farmerId = widget.initialFarmerId;
    if (farmerId == null) return;

    setState(() {
      _startingInitialConversation = true;
    });

    try {
      final conversationId =
          await _messageService.startConversationWithFarmer(farmerId);
      if (!mounted) return;

      setState(() {
        _selectedConversationId = conversationId;
        _isKikoSelected = false;
        NotificationService().setActiveConversation(conversationId);
      });

      if (widget.initialProduct != null) {
        _sendAutomaticInquiry(conversationId, widget.initialProduct!);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _startingInitialConversation = false);
      }
    }
  }

  Future<void> _sendAutomaticInquiry(
    String conversationId,
    ProductItem product,
  ) async {
    try {
      final text = '[PRODUCT_INQUIRY:${product.productId}]';
      await _messageService.sendMessage(
        conversationId: conversationId,
        messageText: text,
      );
    } catch (_) {}
  }

  void _openConversation(MessageConversation conversation) async {
    setState(() {
      _selectedConversationId = conversation.conversationId;
      _isKikoSelected = false;
      NotificationService().setActiveConversation(conversation.conversationId);
    });
    await _messageService.markConversationAsRead(conversation.conversationId);
  }

  Future<void> _sendMessage() async {
    final conversationId = _selectedConversationId;
    if (conversationId == null) return;

    final text = _composerController.text.trim();
    if (text.isEmpty) return;

    _composerController.clear();

    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final currentUserId = SupabaseConfig.currentUser?.id ?? _auth.userId;
    final optimisticMsg = ChatMessage(
      messageId: tempId,
      conversationId: conversationId,
      senderId: currentUserId,
      messageText: text,
      isRead: false,
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
    );

    setState(() => _optimisticMessages.add(optimisticMsg));

    try {
      await _messageService.sendMessage(
        conversationId: conversationId,
        messageText: text,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _optimisticMessages.removeWhere((m) => m.messageId == tempId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    final conversationId = _selectedConversationId;
    if (conversationId == null) return;

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 14),
              Text('Uploading image...'),
            ],
          ),
          duration: Duration(seconds: 15),
        ),
      );

      final bytes = await image.readAsBytes();
      final path =
          'chat_attachments/$conversationId/${DateTime.now().millisecondsSinceEpoch}.jpg';

      final relativePath = await SupabaseDatabase.uploadImage(
        bucket: 'uploads',
        path: path,
        localPath: null,
        bytes: bytes,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (relativePath == null) {
        throw Exception('Failed to upload image.');
      }

      await _messageService.sendMessage(
        conversationId: conversationId,
        messageText: '[IMAGE:$relativePath]',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showCall(
    String name,
    String? avatarUrl,
    String userId, {
    bool isVideo = false,
  }) async {
    final conversationId = _selectedConversationId;
    if (conversationId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          const Center(child: CircularProgressIndicator(color: Color(0xFF059669))),
    );

    final callRecord = await CallService().initiateCall(
      conversationId: conversationId,
      receiverId: userId,
      isVideo: isVideo,
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    if (callRecord == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to initiate call. Please try again.')),
      );
      return;
    }

    final callId = callRecord['call_id']?.toString() ?? '';
    final channelName = callRecord['channel_name']?.toString() ?? '';

    context.push(
      '/call/$callId',
      extra: {
        'name': name,
        'avatarUrl': avatarUrl,
        'channelName': channelName,
        'isVideo': isVideo,
        'isIncoming': false,
      },
    );
  }

  // ===========================================================================
  // ROOT BUILD
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          // 1. Top E-Commerce Header
          WebEcomHeader(
            currentIndex: -1,
            onNavigate: (index, [route]) {
              if (route != null) {
                context.go(route);
              } else {
                context.go(AppRoutes.webTabRoute(index));
              }
            },
            onSearch: (query) {
              context.go(AppRoutes.shop, extra: {'search': query});
            },
          ),

          // 2. Main 3-Column Messenger Body
          Expanded(
            child: StreamBuilder<List<MessageConversation>>(
              stream: _inboxStream,
              builder: (context, snapshot) {
                if (_startingInitialConversation ||
                    (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData)) {
                  return const Center(child: AppShimmerLoader());
                }

                if (snapshot.hasError) {
                  return _buildEmptyState(
                    title: 'Something went wrong',
                    subtitle: 'We couldn\'t load your messages. Please try again.',
                    actionLabel: 'Retry',
                    onPressed: () => setState(() {}),
                  );
                }

                final conversations = snapshot.data ?? const <MessageConversation>[];

                MessageConversation? current;
                if (_selectedConversationId != null) {
                  final found = conversations.where(
                    (c) =>
                        c.conversationId == _selectedConversationId ||
                        c.otherUserId == _selectedConversationId,
                  );
                  if (found.isNotEmpty) {
                    current = found.first;
                    _selectedConversationId = current.conversationId;
                  }
                }

                if (current == null &&
                    conversations.isNotEmpty &&
                    !_isKikoSelected) {
                  current = conversations.first;
                  _selectedConversationId = current.conversationId;
                }

                return Row(
                  children: [
                    // Panel 1: Left Conversations Sidebar (340px)
                    _buildConversationsSidebar(conversations, current),

                    // Panel 2: Center Chat Stream (Expanded)
                    Expanded(
                      child: _isKikoSelected
                          ? const KikoAiChatScreen(embedMode: true)
                          : (current != null
                              ? _buildChatWorkspace(current)
                              : _buildNoSelectionPlaceholder()),
                    ),

                    // Panel 3: Right Details & Order Context Drawer (320px)
                    if (_showRightDrawer && current != null && !_isKikoSelected)
                      _buildRightDetailsDrawer(current),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PANEL 1: CONVERSATIONS SIDEBAR (340px)
  // ===========================================================================
  Widget _buildConversationsSidebar(
    List<MessageConversation> conversations,
    MessageConversation? current,
  ) {
    final filtered = conversations.where((c) {
      return c.otherDisplayName.toLowerCase().contains(
            _conversationSearchQuery.toLowerCase(),
          );
    }).toList();

    return Container(
      width: 340,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Search
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Chats',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    // Role Toggle Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: _asFarmerInbox
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _asFarmerInbox
                              ? const Color(0xFF10B981).withValues(alpha: 0.3)
                              : const Color(0xFF3B82F6).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_asFarmerInbox ? '🌾' : '🛒',
                              style: const TextStyle(fontSize: 11)),
                          const SizedBox(width: 4),
                          Text(
                            _asFarmerInbox ? 'SELLER INBOX' : 'BUYER CHAT',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _asFarmerInbox
                                  ? const Color(0xFF059669)
                                  : const Color(0xFF2563EB),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Search Bar
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    onChanged: (val) =>
                        setState(() => _conversationSearchQuery = val),
                    style: GoogleFonts.inter(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search conversations...',
                      hintStyle: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                        fontSize: 12.5,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF94A3B8),
                        size: 18,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Pinned Kiko AI Assistant Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: InkWell(
              onTap: () {
                setState(() {
                  _isKikoSelected = true;
                  _selectedConversationId = null;
                  NotificationService().setActiveConversation(null);
                });
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _isKikoSelected
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isKikoSelected
                        ? const Color(0xFF059669)
                        : const Color(0xFF10B981).withValues(alpha: 0.35),
                    width: _isKikoSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/kiko_happy.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
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
                              Text(
                                'Kiko AI Assistant',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  'AI',
                                  style: GoogleFonts.inter(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Moo! Ask farming & market advice 24/7',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF047857),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Divider(color: Color(0xFFF1F5F9), height: 1),
          ),

          // Conversation List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No conversations found',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 3),
                    itemBuilder: (context, index) {
                      final conversation = filtered[index];
                      final isSelected = !_isKikoSelected &&
                          conversation.conversationId == _selectedConversationId;

                      return InkWell(
                        onTap: () => _openConversation(conversation),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF059669).withValues(alpha: 0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(
                                    color: const Color(0xFF059669)
                                        .withValues(alpha: 0.2))
                                : null,
                          ),
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  SafeCircleAvatar(
                                    imageUrl: conversation.otherAvatarUrl,
                                    radius: 22,
                                    defaultBucket: 'uploads',
                                    backgroundColor: const Color(0xFFECFDF5),
                                    child: Text(
                                      conversation.otherDisplayName.isNotEmpty
                                          ? conversation.otherDisplayName[0]
                                              .toUpperCase()
                                          : '?',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF059669),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  ValueListenableBuilder<Set<String>>(
                                    valueListenable: NotificationService()
                                        .onlineUsersNotifier,
                                    builder: (context, onlineUsers, _) {
                                      final isOnline = onlineUsers
                                          .contains(conversation.otherUserId);
                                      if (!isOnline) return const SizedBox.shrink();
                                      return Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          padding: const EdgeInsets.all(1.5),
                                          child: PulsingStatusIndicator(
                                            isOnline: true,
                                            size: 8,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            conversation.otherDisplayName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.poppins(
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w600,
                                              fontSize: 13.5,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _formatTime(conversation.lastMessageAt),
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _getDisplaySnippet(
                                                conversation.lastMessage),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: isSelected
                                                  ? const Color(0xFF059669)
                                                  : const Color(0xFF64748B),
                                              fontWeight: isSelected
                                                  ? FontWeight.w500
                                                  : FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                        if (conversation.unreadCount > 0)
                                          Container(
                                            margin: const EdgeInsets.only(left: 6),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF059669),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              '${conversation.unreadCount}',
                                              style: GoogleFonts.inter(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PANEL 2: CENTER CHAT WORKSPACE (Expanded)
  // ===========================================================================
  Widget _buildChatWorkspace(MessageConversation conversation) {
    return Column(
      children: [
        // 1. Top Recipient Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              SafeCircleAvatar(
                imageUrl: conversation.otherAvatarUrl,
                radius: 20,
                defaultBucket: 'uploads',
                backgroundColor: const Color(0xFFECFDF5),
                child: Text(
                  conversation.otherDisplayName.isNotEmpty
                      ? conversation.otherDisplayName[0].toUpperCase()
                      : '?',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF059669),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
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
                          conversation.otherDisplayName,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            'DA VERIFIED',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ),
                      ],
                    ),
                    ValueListenableBuilder<Set<String>>(
                      valueListenable:
                          NotificationService().onlineUsersNotifier,
                      builder: (context, onlineUsers, _) {
                        final isOnline =
                            onlineUsers.contains(conversation.otherUserId);
                        return Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isOnline
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isOnline ? 'Active now' : 'Direct Producer • Online',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: isOnline
                                    ? const Color(0xFF059669)
                                    : const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Call & Info Actions
              IconButton(
                icon: const Icon(Icons.phone_rounded,
                    color: Color(0xFF059669), size: 20),
                tooltip: 'Voice Call',
                onPressed: () => _showCall(
                  conversation.otherDisplayName,
                  conversation.otherAvatarUrl,
                  conversation.otherUserId,
                  isVideo: false,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.videocam_rounded,
                    color: Color(0xFF059669), size: 22),
                tooltip: 'Video Call',
                onPressed: () => _showCall(
                  conversation.otherDisplayName,
                  conversation.otherAvatarUrl,
                  conversation.otherUserId,
                  isVideo: true,
                ),
              ),
              IconButton(
                icon: Icon(
                  _showRightDrawer
                      ? Icons.view_sidebar_rounded
                      : Icons.view_sidebar_outlined,
                  color: _showRightDrawer
                      ? const Color(0xFF059669)
                      : const Color(0xFF64748B),
                  size: 20,
                ),
                tooltip: _showRightDrawer ? 'Hide Details' : 'Show Details',
                onPressed: () =>
                    setState(() => _showRightDrawer = !_showRightDrawer),
              ),
            ],
          ),
        ),

        // 2. Centered Messages Stream (maxWidth: 820px)
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: _messageService.watchMessages(conversation.conversationId),
            builder: (context, snapshot) {
              var messages = snapshot.data ?? const <ChatMessage>[];

              final localForThisChat = _optimisticMessages
                  .where((m) => m.conversationId == conversation.conversationId)
                  .toList();

              if (localForThisChat.isNotEmpty) {
                final merged = List<ChatMessage>.from(messages);
                for (final local in localForThisChat) {
                  final isAlreadyInStream = messages.any(
                    (m) =>
                        m.messageText == local.messageText &&
                        m.senderId == local.senderId &&
                        m.createdAt
                                .difference(local.createdAt)
                                .inSeconds
                                .abs() <
                            10,
                  );
                  if (isAlreadyInStream) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _optimisticMessages.removeWhere(
                              (m) => m.messageId == local.messageId);
                        });
                      }
                    });
                  } else {
                    merged.add(local);
                  }
                }
                merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                messages = merged;
              }

              if (messages.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _messageService
                      .markConversationAsRead(conversation.conversationId);
                });
              }

              if (snapshot.connectionState == ConnectionState.waiting &&
                  messages.isEmpty) {
                return const Center(child: AppShimmerLoader());
              }

              if (messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 44, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'Say hello to ${conversation.otherDisplayName}!',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ask about fresh produce harvest, pre-orders, and direct delivery.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Center-constrained message stream
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[messages.length - 1 - index];
                      final currentUserId =
                          SupabaseConfig.currentUser?.id ?? _auth.userId;
                      final isMine = message.senderId == currentUserId;
                      final showTime = index == 0 ||
                          messages[messages.length - 1 - index]
                                  .createdAt
                                  .difference(
                                    messages[messages.length - index].createdAt,
                                  )
                                  .inMinutes >
                              15;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: isMine
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (showTime)
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 8, bottom: 12),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Text(
                                      _formatMessageTime(message.createdAt),
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        color: const Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            _buildMessageContent(message, isMine),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),

        // 3. Bottom Quick Replies & Composer
        _buildWebComposer(),
      ],
    );
  }

  // ===========================================================================
  // MESSAGE BUBBLES & RICH CARDS
  // ===========================================================================
  Widget _buildMessageContent(ChatMessage message, bool isMine) {
    final text = message.messageText;

    // A. Specialized Order Notice Card
    if (text.startsWith('[ORDER_NOTICE:')) {
      return Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: _buildOrderReceiptCard(text, isMine),
      );
    }

    // B. Specialized Product Inquiry Card
    if (text.startsWith('[PRODUCT_INQUIRY:')) {
      return Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: _buildProductInquiryCard(text, isMine),
      );
    }

    // C. Specialized Image Message Card
    if (text.startsWith('[IMAGE:')) {
      return Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: _buildImageMessageCard(text, isMine),
      );
    }

    // D. Regular Text Message Bubble
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          gradient: isMine
              ? const LinearGradient(
                  colors: [Color(0xFF059669), Color(0xFF047857)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isMine ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
          border: isMine ? null : Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: isMine ? 0.08 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: isMine ? Colors.white : const Color(0xFF0F172A),
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  /// Clean E-Commerce Order Receipt Card
  Widget _buildOrderReceiptCard(String text, bool isMine) {
    final parts = text
        .replaceFirst('[ORDER_NOTICE:', '')
        .replaceFirst(']', '')
        .split(':');
    final orderId = parts.isNotEmpty ? parts[0] : 'Unknown';
    final type = parts.length > 1 ? parts[1].replaceAll('_', ' ') : 'ORDER';
    final payment = parts.length > 2 ? parts[2] : 'COD';

    return Container(
      width: 290,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.shopping_bag_rounded,
                  size: 18,
                  color: Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NEW $type NOTIFICATION',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFD97706),
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      '#$orderId',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Method',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Text(
                  payment.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go('/orders/$orderId'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Text(
                'View Order Details',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Clean Product Inquiry Card
  Widget _buildProductInquiryCard(String text, bool isMine) {
    final productId = text
        .replaceFirst('[PRODUCT_INQUIRY:', '')
        .replaceFirst(']', '')
        .trim();

    return FutureBuilder<ProductItem?>(
      future: SupabaseDataService().getProductById(productId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            width: 260,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final product = snapshot.data!;
        return Container(
          width: 280,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SafeNetworkImage(
                      imageUrl: product.imageUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '₱${product.price} / ${product.unit}',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                            color: const Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () =>
                      context.go(AppRoutes.product(product.productId ?? '')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF059669),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    'View Product Details',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, fontSize: 11.5),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Clean Image Message Card
  Widget _buildImageMessageCard(String text, bool isMine) {
    final path = text.replaceFirst('[IMAGE:', '').replaceFirst(']', '').trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280, maxHeight: 220),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: SafeNetworkImage(
          imageUrl: path,
          defaultBucket: 'uploads',
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  // ===========================================================================
  // BOTTOM COMPOSER & QUICK REPLIES
  // ===========================================================================
  Widget _buildWebComposer() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              // Centered Quick Replies Carousel
              _buildQuickRepliesCarousel(),
              const SizedBox(height: 8),
              // Input Field & Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.image_outlined,
                        color: Color(0xFF059669),
                        size: 24,
                      ),
                      tooltip: 'Attach Image',
                      onPressed: _pickAndSendImage,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _composerController,
                          minLines: 1,
                          maxLines: 4,
                          style: GoogleFonts.inter(fontSize: 13.5),
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: 'Write a message to farm producer...',
                            hintStyle: GoogleFonts.inter(
                              color: const Color(0xFF94A3B8),
                              fontSize: 13,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 11,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickRepliesCarousel() {
    final replies = [
      '🌾 Is this crop still available?',
      '📍 Where is the farm / pickup location?',
      '🚚 Can I order this for delivery?',
      '📦 When is the estimated harvest date?',
      '💚 Thank you so much!',
    ];

    return SizedBox(
      height: 34,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: replies.length,
          itemBuilder: (context, index) {
            final reply = replies[index];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text(
                  reply,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                    color: const Color(0xFF059669),
                  ),
                ),
                backgroundColor: const Color(0xFFECFDF5),
                side: BorderSide(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onPressed: () {
                  _composerController.text = reply;
                  _sendMessage();
                },
              ),
            );
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // PANEL 3: RIGHT ORDER & FARM CONTEXT DRAWER (320px)
  // ===========================================================================
  Widget _buildRightDetailsDrawer(MessageConversation conversation) {
    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          // Farm / Recipient Identity Card
          Center(
            child: Column(
              children: [
                SafeCircleAvatar(
                  imageUrl: conversation.otherAvatarUrl,
                  radius: 38,
                  defaultBucket: 'uploads',
                  backgroundColor: const Color(0xFFECFDF5),
                  child: Text(
                    conversation.otherDisplayName.isNotEmpty
                        ? conversation.otherDisplayName[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF059669),
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  conversation.otherDisplayName,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: const Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'DA VERIFIED FARM PRODUCER',
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // View Store Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final profile = await SupabaseDataService()
                            .getFarmerProfile(conversation.otherUserId);
                        if (!mounted) return;
                        if (profile != null && profile['farmer_id'] != null) {
                          context.go(AppRoutes.farmerProfile(
                              profile['farmer_id'].toString()));
                        }
                      } catch (_) {}
                    },
                    icon: const Icon(Icons.storefront_rounded, size: 16),
                    label: Text(
                      'Visit Farm Storefront',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Order / Marketplace Notice Context
          Text(
            'ACTIVE TRANSACTIONS',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded,
                        color: Color(0xFF059669), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Direct Farm Orders',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Orders created in this chat are protected by AgriDirect Escrow & DA verification.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.go(AppRoutes.customerOrders),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF059669),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Check My Orders',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Privacy & Support Options
          Text(
            'CHAT OPTIONS',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_off_outlined,
                size: 18, color: Color(0xFF64748B)),
            title: Text('Mute Notifications',
                style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF334155))),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Muted notifications for ${conversation.otherDisplayName}'),
                ),
              );
            },
          ),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.help_outline_rounded,
                size: 18, color: Color(0xFF64748B)),
            title: Text('Help & Safe Trading Rules',
                style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF334155))),
            onTap: () => context.go(AppRoutes.faqs),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // EMPTY & PLACEHOLDER STATES
  // ===========================================================================
  Widget _buildNoSelectionPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Select a conversation to start messaging',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Direct messages with local farmers and buyers appear here.',
            style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 52, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================
  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inDays == 0) {
      final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }

  String _formatMessageTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _getDisplaySnippet(String message) {
    if (message.startsWith('[ORDER_NOTICE:')) return '📦 New Order Notice';
    if (message.startsWith('[PRODUCT_INQUIRY:')) return '💬 Product Inquiry';
    if (message.startsWith('[IMAGE:')) return '📷 Image Attachment';
    return message;
  }
}
