import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:agridirect/shared/widgets/image_widgets.dart';
import 'package:agridirect/shared/widgets/pulsing_status_indicator.dart';
import 'package:agridirect/shared/styles/app_theme.dart';
import 'package:agridirect/shared/router/app_routes.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import '../../services/communication/call_service.dart';
import 'in_app_call_screen.dart';

import '../../services/auth/auth_service.dart';
import '../../services/core/supabase_config.dart';
import '../../services/community/message_service.dart';
import '../../services/community/notification_service.dart';
import '../../services/core/supabase_data_service.dart';
import '../../data/app_data.dart';

class ConsumerMessagesScreen extends StatefulWidget {
  const ConsumerMessagesScreen({
    super.key,
    this.initialFarmerId,
    this.initialConversationId,
    this.initialProduct,
  });

  final String? initialFarmerId;
  final String? initialConversationId;
  final ProductItem? initialProduct;

  @override
  State<ConsumerMessagesScreen> createState() => _ConsumerMessagesScreenState();
}

class _ConsumerMessagesScreenState extends State<ConsumerMessagesScreen> {
  final _auth = AuthService();
  final _messageService = MessageService();
  final _composerController = TextEditingController();

  String? _selectedConversationId;
  String? _errorText;
  bool _startingInitialConversation = false;
  final List<ChatMessage> _optimisticMessages = [];
  String _conversationSearchQuery = '';

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  Future<void> _refreshInbox() async {
    // Stream refreshes automatically
  }

  Future<void> _handleInitialConversation() async {
    final farmerId = widget.initialFarmerId;
    if (farmerId == null) return;

    setState(() {
      _startingInitialConversation = true;
      _errorText = null;
    });

    try {
      final conversationId = await _messageService.startConversationWithFarmer(
        farmerId,
      );

      if (!mounted) return;

      setState(() {
        _selectedConversationId = conversationId;
        NotificationService().setActiveConversation(conversationId);
      });

      // AUTO-SEND PRODUCT INQUIRY (if not already sent)
      if (widget.initialProduct != null) {
        _sendAutomaticInquiry(conversationId, widget.initialProduct!);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _startingInitialConversation = false;
        });
      }
    }
  }

  Future<void> _sendAutomaticInquiry(String conversationId, ProductItem product) async {
    try {
      final messages = await _messageService.getMessages(conversationId: conversationId);
      final tag = '[PRODUCT_INQUIRY:${product.productId}]';
      final alreadySent = messages.any((m) => m.messageText.contains(tag));
      
      if (!alreadySent) {
        await _messageService.sendMessage(
          conversationId: conversationId,
          messageText: tag,
        );
      }
    } catch (e) {
      debugPrint('Error sending automatic inquiry: $e');
    }
  }

  Future<void> _openConversation(MessageConversation conversation) async {
    setState(() {
      _selectedConversationId = conversation.conversationId;
      NotificationService().setActiveConversation(conversation.conversationId);
      _errorText = null;
    });
    await _messageService.markConversationAsRead(conversation.conversationId);
  }

  Future<void> _sendMessage() async {
    final conversationId = _selectedConversationId;
    if (conversationId == null) {
      return;
    }

    final text = _composerController.text.trim();
    if (text.isEmpty) return;

    _composerController.clear();

    // Create optimistic message
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

    setState(() {
      _optimisticMessages.add(optimisticMsg);
    });

    try {
      await _messageService.sendMessage(
        conversationId: conversationId,
        messageText: text,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _optimisticMessages.removeWhere((m) => m.messageId == tempId);
          _errorText = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _showConversationInfo(MessageConversation conversation) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSubtle.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 32),
            SafeCircleAvatar(
              imageUrl: conversation.otherAvatarUrl,
              radius: 50,
              defaultBucket: 'uploads',
              backgroundColor: AppColors.accent.withValues(alpha: 0.1),
              child: Text(
                conversation.otherDisplayName.isNotEmpty
                    ? conversation.otherDisplayName[0].toUpperCase()
                    : '?',
                style: AppTextStyles.headline1.copyWith(
                  color: AppColors.accent,
                  fontSize: 36,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              conversation.otherDisplayName,
              style: AppTextStyles.headline2.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 4),
            Text(
              conversation.otherSubtitle,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSubtle,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            _buildInfoTile(
              icon: Icons.person_outline_rounded,
              title: 'View Profile',
              onTap: () {
                Navigator.pop(context);
              },
            ),
            _buildInfoTile(
              icon: Icons.notifications_off_outlined,
              title: 'Mute Notifications',
              onTap: () {
                Navigator.pop(context);
              },
            ),
            _buildInfoTile(
              icon: Icons.block_flipped,
              title: 'Block User',
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: isDestructive ? AppColors.error : AppColors.textHeadline,
      ),
      title: Text(
        title,
        style: AppTextStyles.bodyLarge.copyWith(
          color: isDestructive ? AppColors.error : AppColors.textHeadline,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      contentPadding: EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return PopScope(
      canPop: _selectedConversationId == null || isWide,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_selectedConversationId != null && !isWide) {
          setState(() {
            _selectedConversationId = null;
            NotificationService().setActiveConversation(null);
          });
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: isWide || _selectedConversationId != null
          ? null 
          : AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              centerTitle: false,
              leading: context.canPop()
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                      onPressed: () => context.pop(),
                    )
                  : null,
              title: Text(
                'Customer Messages',
                style: AppTextStyles.headline1.copyWith(fontSize: 24),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  color: AppColors.textSubtle.withValues(alpha: 0.1),
                  height: 1,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _buildAsFarmerBadge(),
                ),
              ],
            ),
      body: Column(
        children: [
          if (_errorText != null)
            _buildErrorBanner(),
          Expanded(
            child: StreamBuilder<List<MessageConversation>>(
              stream: _messageService.watchInbox(asFarmer: false),
              builder: (context, snapshot) {
                if (_startingInitialConversation) {
                  return const Center(child: AppShimmerLoader());
                }

                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: AppShimmerLoader());
                }

                if (snapshot.hasError) {
                  return _buildEmptyState(
                    title: 'Something went wrong',
                    subtitle:
                        'We couldn\'t load your messages. Please try again.',
                    actionLabel: 'Retry',
                    onPressed: _refreshInbox,
                  );
                }

                final conversations =
                    snapshot.data ?? const <MessageConversation>[];

                if (conversations.isEmpty) {
                  _selectedConversationId = null;
                  return Scaffold(
                    backgroundColor: AppColors.background,
                    body: _buildEmptyState(
                      title: 'Your inbox is empty',
                      subtitle: 'Start a conversation from any product or farm profile to ask questions.',
                      actionLabel: 'Refresh Inbox',
                      onPressed: _refreshInbox,
                    ),
                  );
                }

                final hasSelectedConversation = conversations.any(
                  (conversation) =>
                      conversation.conversationId == _selectedConversationId,
                );

                if (!hasSelectedConversation && !_startingInitialConversation) {
                  if (isWide && conversations.isNotEmpty) {
                    _selectedConversationId = conversations.first.conversationId;
                    NotificationService().setActiveConversation(
                      _selectedConversationId,
                    );
                  } else if (!isWide) {
                    _selectedConversationId = null;
                  }
                }

                MessageConversation? current;
                if (_selectedConversationId != null) {
                  final found = conversations.where(
                    (c) => c.conversationId == _selectedConversationId,
                  );
                  if (found.isNotEmpty) {
                    current = found.first;
                  }
                }

                if (current == null && isWide && conversations.isNotEmpty) {
                  current = conversations.first;
                  _selectedConversationId = current.conversationId;
                }

                if (current == null && _selectedConversationId == null) {
                  return _buildConversationList(conversations);
                }

                if (current == null && _selectedConversationId != null) {
                  return const Center(child: AppShimmerLoader());
                }

                if (isWide) {
                  return _buildWebMessengerLayout(conversations, current!);
                }

                return _buildChatPanel(current!);
              },
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildAsFarmerBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_outline_rounded,
            size: 14,
            color: AppColors.warning,
          ),
          const SizedBox(width: 6),
          Text(
            'CUSTOMER',
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _errorText!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebMessengerLayout(
    List<MessageConversation> conversations,
    MessageConversation current,
  ) {
    final filtered = conversations.where((c) {
      return c.otherDisplayName
          .toLowerCase()
          .contains(_conversationSearchQuery.toLowerCase());
    }).toList();

    return Row(
      children: [
        Container(
          width: 360,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              right: BorderSide(
                color: Colors.grey.shade100,
                width: 1.5,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.arrow_back_rounded, size: 24),
                          color: AppColors.textHeadline,
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go(AppRoutes.home);
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Chats',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textHeadline,
                          ),
                        ),
                        const Spacer(),
                        _buildAsFarmerBadge(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        onChanged: (val) =>
                            setState(() => _conversationSearchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Search messenger...',
                          hintStyle: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: Colors.grey.shade500,
                            size: 18,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final conversation = filtered[index];
                    final isSelected =
                        conversation.conversationId == _selectedConversationId;
                    return InkWell(
                      onTap: () => _openConversation(conversation),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accent.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                SafeCircleAvatar(
                                  imageUrl: conversation.otherAvatarUrl,
                                  radius: 24,
                                  defaultBucket: 'uploads',
                                  backgroundColor: isSelected
                                      ? AppColors.accent.withValues(alpha: 0.1)
                                      : AppColors.textSubtle.withValues(
                                          alpha: 0.1,
                                        ),
                                  child: Text(
                                    conversation.otherDisplayName.isNotEmpty
                                        ? conversation.otherDisplayName[0]
                                            .toUpperCase()
                                        : '?',
                                    style: AppTextStyles.headline3.copyWith(
                                      color: isSelected
                                          ? AppColors.accent
                                          : AppColors.textSubtle,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                ValueListenableBuilder<Set<String>>(
                                  valueListenable:
                                      NotificationService().onlineUsersNotifier,
                                  builder: (context, onlineUsers, _) {
                                    if (!onlineUsers.contains(
                                      conversation.otherUserId,
                                    )) {
                                      return const SizedBox.shrink();
                                    }
                                    return Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(2),
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
                            const SizedBox(width: 12),
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
                                          style: AppTextStyles.bodyMedium.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textHeadline,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _formatTime(conversation.lastMessageAt),
                                        style: AppTextStyles.labelSmall.copyWith(
                                          fontSize: 10,
                                          color: isSelected
                                              ? AppColors.accent
                                              : AppColors.textSubtle,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _getDisplayText(
                                            conversation.lastMessage,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.bodySmall.copyWith(
                                            color: isSelected
                                                ? AppColors.textHeadline
                                                : AppColors.textSubtle,
                                            fontWeight:
                                                conversation.unreadCount > 0
                                                    ? FontWeight.w800
                                                    : FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                      if (conversation.unreadCount > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 3,
                                          ),
                                          decoration: const BoxDecoration(
                                            color: AppColors.accent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            '${conversation.unreadCount}',
                                            style: const TextStyle(
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
        ),
        Expanded(
          child: Container(
            color: const Color(0xFFF8FAFC),
            child: _buildWebChatPanel(current),
          ),
        ),
      ],
    );
  }

  Widget _buildWebChatPanel(MessageConversation conversation) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.shade100,
                width: 1.5,
              ),
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
              SafeCircleAvatar(
                imageUrl: conversation.otherAvatarUrl,
                radius: 20,
                defaultBucket: 'uploads',
                backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                child: Text(
                  conversation.otherDisplayName.isNotEmpty
                      ? conversation.otherDisplayName[0].toUpperCase()
                      : '?',
                  style: AppTextStyles.headline3.copyWith(
                    color: AppColors.accent,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.otherDisplayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.textHeadline,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        ValueListenableBuilder<Set<String>>(
                          valueListenable:
                              NotificationService().onlineUsersNotifier,
                          builder: (context, onlineUsers, _) {
                            final isOnline = onlineUsers.contains(
                              conversation.otherUserId,
                            );
                            return PulsingStatusIndicator(
                              isOnline: isOnline,
                              size: 8,
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ValueListenableBuilder<Set<String>>(
                            valueListenable:
                                NotificationService().onlineUsersNotifier,
                            builder: (context, onlineUsers, _) {
                              final isOnline = onlineUsers.contains(
                                conversation.otherUserId,
                              );
                              if (isOnline) {
                                return Text(
                                  'Active now',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.success,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              }

                              final lastActiveLocal = NotificationService().getLastActive(conversation.otherUserId);
                              DateTime? lastActive = lastActiveLocal;
                              if (lastActive == null && conversation.otherUpdatedAt != null) {
                                lastActive = DateTime.tryParse(conversation.otherUpdatedAt!);
                              }

                              final statusText = lastActive != null ? _formatLastActive(lastActive) : 'Offline';

                              return Text(
                                statusText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textSubtle,
                                  fontSize: 11,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showCallDialog(
                  conversation.otherDisplayName,
                  conversation.otherAvatarUrl,
                  conversation.otherUserId,
                  isVideo: false,
                ),
                icon: const Icon(
                  Icons.phone_rounded,
                  color: AppColors.accent,
                ),
                tooltip: 'Voice Call',
              ),
              IconButton(
                onPressed: () => _showCallDialog(
                  conversation.otherDisplayName,
                  conversation.otherAvatarUrl,
                  conversation.otherUserId,
                  isVideo: true,
                ),
                icon: const Icon(
                  Icons.videocam_rounded,
                  color: AppColors.accent,
                ),
                tooltip: 'Video Call',
              ),
              IconButton(
                onPressed: () => _showConversationInfo(conversation),
                icon: const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.textSubtle,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: _messageService.watchMessages(
              conversation.conversationId,
            ),
            builder: (context, snapshot) {
              var messages = snapshot.data ?? const <ChatMessage>[];

              final localForThisChat = _optimisticMessages
                  .where(
                    (m) => m.conversationId == conversation.conversationId,
                  )
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
                            (m) => m.messageId == local.messageId,
                          );
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
                  _messageService.markConversationAsRead(
                    conversation.conversationId,
                  );
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
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 48,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No messages yet',
                        style: AppTextStyles.headline3.copyWith(
                          color: AppColors.textSubtle,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[messages.length - 1 - index];
                  final currentUserId = SupabaseConfig.currentUser?.id;
                  final isMine =
                      message.senderId == currentUserId ||
                      (currentUserId != null &&
                          message.senderId == _auth.userId);
                  final showTime =
                      index == 0 ||
                      messages[messages.length - 1 - index].createdAt
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
                            padding: const EdgeInsets.only(top: 8, bottom: 12),
                            child: Center(
                              child: Text(
                                _formatMessageTime(message.createdAt),
                                style: AppTextStyles.labelSmall.copyWith(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        Align(
                          alignment: isMine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.5,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              gradient: isMine
                                  ? AppColors.accentGradient
                                  : null,
                              color: isMine ? null : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(20),
                                topRight: const Radius.circular(20),
                                bottomLeft:
                                    Radius.circular(isMine ? 20 : 4),
                                bottomRight:
                                    Radius.circular(isMine ? 4 : 20),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: message.messageText
                                    .startsWith('[PRODUCT_INQUIRY:')
                                ? _buildInquiryCard(
                                    message.messageText,
                                    isMine,
                                  )
                                : message.messageText
                                        .startsWith('[ORDER_NOTICE:')
                                    ? _buildOrderNoticeCard(
                                        message.messageText,
                                        isMine,
                                      )
                                    : message.messageText
                                            .startsWith('[IMAGE:')
                                        ? _buildImageMessageCard(
                                            message.messageText,
                                            isMine,
                                          )
                                        : Text(
                                            message.messageText,
                                            style:
                                                AppTextStyles.bodyMedium.copyWith(
                                              color: isMine
                                                  ? Colors.white
                                                  : AppColors.textHeadline,
                                              height: 1.4,
                                            ),
                                          ),
                          ),
                        ),
                        if (isMine && index == 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, right: 4),
                            child: Icon(
                              message.status == MessageStatus.sending
                                  ? Icons.schedule_rounded
                                  : message.isRead
                                      ? Icons.done_all_rounded
                                      : Icons.check_rounded,
                              size: 11,
                              color: message.isRead
                                  ? AppColors.accent
                                  : Colors.grey.shade400,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        _buildWebComposer(),
      ],
    );
  }

  Widget _buildWebComposer() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        _buildQuickReplies(),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.image_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
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
                    maxLines: 5,
                    style: AppTextStyles.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Write a message...',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.grey.shade500,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.emoji_emotions_outlined,
                          size: 22,
                        ),
                        color: Colors.grey.shade500,
                        onPressed: () {},
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    gradient: AppColors.accentGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ],
);
}

  String _getDisplayText(String message) {
    if (message.startsWith('[ORDER_NOTICE:')) {
      return '📦 New Order Notice';
    }
    if (message.startsWith('[PRODUCT_INQUIRY:')) {
      return '💬 Product Inquiry';
    }
    if (message.startsWith('[IMAGE:')) {
      return '📷 Image';
    }
    return message;
  }

  Widget _buildConversationList(List<MessageConversation> conversations) {
    final filtered = conversations.where((c) {
      return c.otherDisplayName
          .toLowerCase()
          .contains(_conversationSearchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: AppColors.textSubtle.withValues(alpha: 0.1),
              ),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _conversationSearchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshInbox,
            displacement: 20,
            color: AppColors.accent,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemBuilder: (context, index) {
                final conversation = filtered[index];
                final isSelected =
                    conversation.conversationId == _selectedConversationId;

                return InkWell(
                  onTap: () => _openConversation(conversation),
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accent.withValues(alpha: 0.3)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.textHeadline.withValues(alpha: 0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            SafeCircleAvatar(
                              imageUrl: conversation.otherAvatarUrl,
                              radius: 28,
                              defaultBucket: 'uploads',
                              backgroundColor: isSelected
                                  ? AppColors.accent.withValues(alpha: 0.1)
                                  : AppColors.textSubtle.withValues(alpha: 0.1),
                              child: Text(
                                conversation.otherDisplayName.isNotEmpty
                                    ? conversation.otherDisplayName[0].toUpperCase()
                                    : '?',
                                style: AppTextStyles.headline3.copyWith(
                                  color: isSelected
                                      ? AppColors.accent
                                      : AppColors.textSubtle,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            ValueListenableBuilder<Set<String>>(
                              valueListenable:
                                  NotificationService().onlineUsersNotifier,
                              builder: (context, onlineUsers, _) {
                                final isOnline = onlineUsers.contains(
                                  conversation.otherUserId,
                                );
                                if (!isOnline) return const SizedBox.shrink();

                                return Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(2.5),
                                    child: PulsingStatusIndicator(
                                      isOnline: true,
                                      size: 11,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      conversation.otherDisplayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.bodyLarge.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textHeadline,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _formatTime(conversation.lastMessageAt),
                                    style: AppTextStyles.labelSmall.copyWith(
                                      fontSize: 11,
                                      color: isSelected
                                          ? AppColors.accent
                                          : AppColors.textSubtle,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _getDisplayText(conversation.lastMessage),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: isSelected
                                            ? AppColors.textHeadline
                                            : AppColors.textSubtle,
                                        fontWeight: conversation.unreadCount > 0
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  if (conversation.unreadCount > 0)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${conversation.unreadCount}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
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
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemCount: filtered.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatPanel(MessageConversation conversation) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              if (MediaQuery.of(context).size.width < 900)
                IconButton(
                  onPressed: () => setState(() {
                    _selectedConversationId = null;
                    NotificationService().setActiveConversation(null);
                  }),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  color: AppColors.textHeadline,
                ),
              const SizedBox(width: 4),
              Hero(
                tag: 'avatar_${conversation.conversationId}',
                child: SafeCircleAvatar(
                  imageUrl: conversation.otherAvatarUrl,
                  radius: 22,
                  defaultBucket: 'uploads',
                  backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                  child: Text(
                    conversation.otherDisplayName.isNotEmpty
                        ? conversation.otherDisplayName[0].toUpperCase()
                        : '?',
                    style: AppTextStyles.headline3.copyWith(
                      color: AppColors.accent,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.otherDisplayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: AppColors.textHeadline,
                      ),
                    ),
                    Row(
                      children: [
                        ValueListenableBuilder<Set<String>>(
                          valueListenable:
                              NotificationService().onlineUsersNotifier,
                          builder: (context, onlineUsers, _) {
                            final isOnline = onlineUsers.contains(
                              conversation.otherUserId,
                            );
                            return PulsingStatusIndicator(
                              isOnline: isOnline,
                              size: 8,
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ValueListenableBuilder<Set<String>>(
                            valueListenable:
                                NotificationService().onlineUsersNotifier,
                            builder: (context, onlineUsers, _) {
                              final isOnline = onlineUsers.contains(
                                conversation.otherUserId,
                              );
                              if (isOnline) {
                                return Text(
                                  'Active now',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.success,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              }

                              final lastActiveLocal = NotificationService().getLastActive(conversation.otherUserId);
                              DateTime? lastActive = lastActiveLocal;
                              if (lastActive == null && conversation.otherUpdatedAt != null) {
                                lastActive = DateTime.tryParse(conversation.otherUpdatedAt!);
                              }

                              final statusText = lastActive != null ? _formatLastActive(lastActive) : 'Offline';

                              return Text(
                                statusText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textSubtle,
                                  fontSize: 11,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showCallDialog(
                  conversation.otherDisplayName,
                  conversation.otherAvatarUrl,
                  conversation.otherUserId,
                  isVideo: false,
                ),
                icon: const Icon(
                  Icons.phone_rounded,
                  color: AppColors.accent,
                ),
                tooltip: 'Voice Call',
              ),
              IconButton(
                onPressed: () => _showCallDialog(
                  conversation.otherDisplayName,
                  conversation.otherAvatarUrl,
                  conversation.otherUserId,
                  isVideo: true,
                ),
                icon: const Icon(
                  Icons.videocam_rounded,
                  color: AppColors.accent,
                ),
                tooltip: 'Video Call',
              ),
              IconButton(
                onPressed: () => _showConversationInfo(conversation),
                icon: const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.textSubtle,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: Container(
            color: AppColors.background,
            child: StreamBuilder<List<ChatMessage>>(
              stream: _messageService.watchMessages(
                conversation.conversationId,
              ),
              builder: (context, snapshot) {
                var messages = snapshot.data ?? const <ChatMessage>[];

                final localForThisChat = _optimisticMessages
                    .where(
                      (m) => m.conversationId == conversation.conversationId,
                    )
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
                              (m) => m.messageId == local.messageId,
                            );
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
                    _messageService.markConversationAsRead(
                      conversation.conversationId,
                    );
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
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 48,
                          color: AppColors.textSubtle.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: AppTextStyles.headline3.copyWith(
                            color: AppColors.textSubtle,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Say hello to start the conversation!',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSubtle,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - 1 - index];
                    final currentUserId = SupabaseConfig.currentUser?.id;
                    final isMine =
                        message.senderId == currentUserId ||
                        (currentUserId != null &&
                            message.senderId == _auth.userId);
                    final showTime =
                      index == 0 ||
                      messages[messages.length - 1 - index].createdAt
                              .difference(
                                messages[messages.length - index].createdAt,
                              )
                              .inMinutes >
                          5;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: isMine
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          if (showTime)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Center(
                                child: Text(
                                  _formatMessageTime(message.createdAt),
                                  style: AppTextStyles.labelSmall.copyWith(
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                          Align(
                            alignment: isMine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                gradient: isMine
                                    ? AppColors.accentGradient
                                    : null,
                                color: isMine ? null : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(20),
                                  topRight: const Radius.circular(20),
                                  bottomLeft: Radius.circular(isMine ? 20 : 4),
                                  bottomRight: Radius.circular(isMine ? 4 : 20),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: message.messageText.startsWith('[PRODUCT_INQUIRY:')
                                  ? _buildInquiryCard(message.messageText, isMine)
                                  : message.messageText.startsWith('[ORDER_NOTICE:')
                                      ? _buildOrderNoticeCard(message.messageText, isMine)
                                      : message.messageText.startsWith('[IMAGE:')
                                          ? _buildImageMessageCard(message.messageText, isMine)
                                          : Text(
                                              message.messageText,
                                              style: AppTextStyles.bodyMedium.copyWith(
                                                color: isMine
                                                    ? Colors.white
                                                    : AppColors.textHeadline,
                                                height: 1.5,
                                              ),
                                            ),
                            ),
                          ),
                          if (isMine)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, right: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (message.status == MessageStatus.sending)
                                    const Icon(
                                      Icons.schedule_rounded,
                                      size: 10,
                                      color: AppColors.textSubtle,
                                    )
                                  else if (message.isRead)
                                    const Icon(
                                      Icons.done_all_rounded,
                                      size: 12,
                                      color: AppColors.accent,
                                    )
                                  else
                                    const Icon(
                                      Icons.check_rounded,
                                      size: 12,
                                      color: AppColors.textSubtle,
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),

        // Message Input
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _buildQuickReplies(),
            const SizedBox(height: 8),
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade100,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.image_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    onPressed: _pickAndSendImage,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _composerController,
                    minLines: 1,
                    maxLines: 5,
                    style: AppTextStyles.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Write a message...',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.grey.shade500,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.emoji_emotions_outlined,
                          size: 22,
                        ),
                        color: Colors.grey.shade500,
                        onPressed: () {},
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    gradient: AppColors.accentGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ],
);
}

  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    required String actionLabel,
    required Future<void> Function() onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_rounded,
                    size: 40,
                    color: AppColors.accent.withValues(alpha: 0.2),
                  ),
                  const Icon(
                    Icons.mail_outline_rounded,
                    size: 24,
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.headline2.copyWith(
                color: AppColors.textHeadline,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSubtle,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              child: FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  textStyle: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? dateTimeUtc) {
    if (dateTimeUtc == null) {
      return '';
    }

    final dateTime = dateTimeUtc.toLocal();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    }
    if (difference.inHours > 0) {
      return '${difference.inHours}h';
    }
    if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    }
    return 'Now';
  }

  String _formatMessageTime(DateTime dateTimeUtc) {
    final dateTime = dateTimeUtc.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $period';

    if (messageDate == today) {
      return 'Today at $timeStr';
    } else if (messageDate == yesterday) {
      return 'Yesterday at $timeStr';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dateTime.month - 1]} ${dateTime.day} at $timeStr';
    }
  }

  Widget _buildOrderNoticeCard(String text, bool isMine) {
    // Format: [ORDER_NOTICE:ORDER_ID:TYPE:PAYMENT]
    final parts = text.replaceFirst('[ORDER_NOTICE:', '').replaceFirst(']', '').split(':');
    final orderId = parts.isNotEmpty ? parts[0] : 'Unknown';
    final type = parts.length > 1 ? parts[1].replaceAll('_', ' ') : 'ORDER';
    final payment = parts.length > 2 ? parts[2] : 'COD';

    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMine ? Colors.white.withValues(alpha: 0.1) : AppColors.accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMine ? Colors.white24 : AppColors.accent.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isMine ? Colors.white24 : AppColors.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  size: 18,
                  color: isMine ? Colors.white : AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New $type',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isMine ? Colors.white70 : AppColors.accent,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '#${orderId.substring(orderId.length > 8 ? orderId.length - 8 : 0).toUpperCase()}',
                      style: AppTextStyles.headline3.copyWith(
                        fontSize: 14,
                        color: isMine ? Colors.white : AppColors.textHeadline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildNoticeDetail(
            Icons.payments_outlined,
            'Payment Method',
            payment == 'COD' ? 'Cash on Delivery' : 'Cash on Pickup',
            isMine,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                // Navigate to order details
                context.push('/orders/$orderId');
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: const Text('View Order Details', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeDetail(IconData icon, String label, String value, bool isMine) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: isMine ? Colors.white60 : AppColors.textSubtle,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isMine ? Colors.white60 : AppColors.textSubtle,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  color: isMine ? Colors.white : AppColors.textHeadline,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInquiryCard(String text, bool isMine) {
    final productId = text
        .replaceFirst('[PRODUCT_INQUIRY:', '')
        .replaceFirst(']', '')
        .trim();

    return FutureBuilder<ProductItem?>(
      future: SupabaseDataService().getProductById(productId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            width: 200,
            height: 80,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final product = snapshot.data!;
        return Container(
          width: 260,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMine ? Colors.white.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isMine ? Colors.white24 : AppColors.textHeadline.withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: CachedNetworkImage(
                        imageUrl: product.imageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product Inquiry',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: isMine ? Colors.white70 : AppColors.accent,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.name,
                          style: AppTextStyles.headline3.copyWith(
                            fontSize: 15,
                            color: isMine ? Colors.white : AppColors.textHeadline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          product.price,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w900,
                            color: isMine ? Colors.white : AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    context.push('/marketplace/product/${product.productId}');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: isMine ? Colors.white : AppColors.accent,
                    foregroundColor: isMine ? AppColors.accent : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('View Product', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
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
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 16),
              Text('Uploading image...'),
            ],
          ),
          duration: Duration(days: 1),
        ),
      );

      final bytes = await image.readAsBytes();
      final path = 'chat_attachments/$conversationId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      final relativePath = await SupabaseDatabase.uploadImage(
        bucket: 'uploads',
        path: path,
        localPath: kIsWeb ? null : image.path,
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

  Widget _buildQuickReplies() {
    final replies = [
      'Is this product still available?',
      'Where is the pickup location?',
      'Can I order this for delivery?',
      'How much is the shipping fee?',
      'Thank you so much!',
    ];

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
          physics: const BouncingScrollPhysics(),
          itemCount: replies.length,
          itemBuilder: (context, index) {
            final reply = replies[index];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text(
                  reply,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.5),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
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

  Widget _buildImageMessageCard(String text, bool isMine) {
    final path = text.replaceFirst('[IMAGE:', '').replaceFirst(']', '').trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 250,
          maxHeight: 200,
        ),
        child: SafeNetworkImage(
          imageUrl: path,
          defaultBucket: 'uploads',
          fit: BoxFit.cover,
          placeholder: Container(
            width: 200,
            height: 150,
            color: Colors.grey.shade100,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: AppShimmerLoader(strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: Container(
            width: 200,
            height: 150,
            color: Colors.grey.shade100,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image_rounded,
                  size: 32,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 8),
                Text(
                  'Failed to load image',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCallDialog(String name, String? avatarUrl, String userId, {bool isVideo = false}) async {
    final conversationId = _selectedConversationId;
    if (conversationId == null) return;
    
    // Show a loading indicator while creating call in database
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: Colors.green)),
    );

    final callRecord = await CallService().initiateCall(
      conversationId: conversationId,
      receiverId: userId,
      isVideo: isVideo,
    );

    if (!mounted) return;
    Navigator.of(context).pop(); // Dismiss loading indicator

    if (callRecord == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to initiate call. Please try again.")),
      );
      return;
    }

    final callId = callRecord['call_id']?.toString() ?? '';
    final channelName = callRecord['channel_name']?.toString() ?? '';

    // On web: navigate to a dedicated full-screen call route instead of dialog.
    // On mobile: use the dialog overlay as before.
    if (kIsWeb) {
      if (!mounted) return;
      context.push('/call/$callId', extra: {
        'name': name,
        'avatarUrl': avatarUrl,
        'channelName': channelName,
        'isVideo': isVideo,
        'isIncoming': false,
      });
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: false,
        builder: (dialogContext) => InAppCallScreen(
          name: name,
          avatarUrl: avatarUrl,
          callId: callId,
          channelName: channelName,
          isVideo: isVideo,
          isIncoming: false,
        ),
      );
    }
  }

  String _formatLastActive(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inSeconds < 60) {
      return 'Active just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return "Active $mins min${mins > 1 ? 's' : ''} ago";
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return "Active $hours hr${hours > 1 ? 's' : ''} ago";
    } else {
      final days = difference.inDays;
      return "Active $days day${days > 1 ? 's' : ''} ago";
    }
  }
}
