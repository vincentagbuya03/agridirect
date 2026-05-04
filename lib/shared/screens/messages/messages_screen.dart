import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:agridirect/shared/widgets/image_widgets.dart';
import 'package:agridirect/shared/styles/app_theme.dart';

import '../../services/auth/auth_service.dart';
import '../../services/core/supabase_config.dart';
import '../../services/community/message_service.dart';
import '../../services/community/notification_service.dart';
import '../../services/core/supabase_data_service.dart';
import '../../data/app_data.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
    this.initialFarmerId,
    this.initialConversationId,
    this.asFarmer,
    this.initialProduct,
    this.initialCustomerId,
  });

  final String? initialFarmerId;
  final String? initialCustomerId;
  final String? initialConversationId;
  final bool? asFarmer;
  final ProductItem? initialProduct;


  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _auth = AuthService();
  final _messageService = MessageService();
  final _composerController = TextEditingController();

  late bool _asFarmerInbox;
  String? _selectedConversationId;
  String? _errorText;
  bool _startingInitialConversation = false;
  final List<ChatMessage> _optimisticMessages = [];

  @override
  void initState() {
    super.initState();
    _asFarmerInbox =
        widget.asFarmer ??
        (widget.initialFarmerId == null ? _auth.isViewingAsFarmer : false);
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
    final customerId = widget.initialCustomerId;

    if (_asFarmerInbox) {
      if (customerId == null) return;

      setState(() {
        _startingInitialConversation = true;
        _errorText = null;
      });

      try {
        final conversationId = await _messageService.startConversationWithCustomer(
          customerId,
        );

        if (!mounted) return;

        setState(() {
          _selectedConversationId = conversationId;
          NotificationService().setActiveConversation(conversationId);
        });
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
      return;
    }

    // Customer inbox flow (starting chat with farmer)
    if (farmerId == null) {
      return;
    }

    setState(() {
      _startingInitialConversation = true;
      _errorText = null;
    });

    try {
      final conversationId = await _messageService.startConversationWithFarmer(
        farmerId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedConversationId = conversationId;
        NotificationService().setActiveConversation(conversationId);
      });

      // 🔴 AUTO-SEND PRODUCT INQUIRY (if not already sent)
      if (widget.initialProduct != null) {
        _sendAutomaticInquiry(conversationId, widget.initialProduct!);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

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
      // 1. Get recent messages for this conversation
      final messages = await _messageService.getMessages(conversationId: conversationId);
      
      // 2. Check if an inquiry for THIS product already exists
      final tag = '[PRODUCT_INQUIRY:${product.productId}]';
      final alreadySent = messages.any((m) => m.messageText.contains(tag));
      
      if (!alreadySent) {
        // 3. Send the special inquiry tag
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
      // We don't remove it here yet; the StreamBuilder will handle the cleanup
      // when it sees the message from the server.
      if (mounted) {
        // No manual refresh needed as watchInbox stream handles it
      }
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
              backgroundColor: AppColors.primaryLight,
              child: Text(
                conversation.otherDisplayName.isNotEmpty
                    ? conversation.otherDisplayName[0].toUpperCase()
                    : '?',
                style: AppTextStyles.headline1.copyWith(
                  color: AppColors.primary,
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
                // Navigate to profile feature to be added
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Messages',
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
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (_asFarmerInbox ? AppColors.primary : AppColors.accent)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (_asFarmerInbox ? AppColors.primary : AppColors.accent)
                    .withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _asFarmerInbox
                      ? Icons.agriculture_rounded
                      : Icons.person_outline_rounded,
                  size: 14,
                  color: _asFarmerInbox
                      ? AppColors.primaryDark
                      : AppColors.warning,
                ),
                const SizedBox(width: 6),
                Text(
                  _asFarmerInbox ? 'FARMER' : 'CUSTOMER',
                  style: AppTextStyles.labelSmall.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: _asFarmerInbox
                        ? AppColors.primaryDark
                        : AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_errorText != null)
            Padding(
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
            ),
          Expanded(
            child: StreamBuilder<List<MessageConversation>>(
              stream: _messageService.watchInbox(asFarmer: _asFarmerInbox),
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
                  return _buildEmptyState(
                    title: 'Your inbox is empty',
                    subtitle: _asFarmerInbox
                        ? 'Customer inquiries will show up here when they message your farm.'
                        : 'Start a conversation from any product or farm profile to ask questions.',
                    actionLabel: 'Refresh Inbox',
                    onPressed: _refreshInbox,
                  );
                }

                final isWide = MediaQuery.of(context).size.width >= 900;

                final hasSelectedConversation = conversations.any(
                  (conversation) =>
                      conversation.conversationId == _selectedConversationId,
                );

                // Only auto-select or reset if we don't have a valid selection
                // and we aren't currently waiting for a new conversation to initialize.
                if (!hasSelectedConversation && !_startingInitialConversation) {
                  if (isWide && conversations.isNotEmpty) {
                    _selectedConversationId = conversations.first.conversationId;
                    NotificationService().setActiveConversation(
                      _selectedConversationId,
                    );
                  } else if (!isWide) {
                    // On mobile, if the selected ID is no longer in the list,
                    // we only reset to null if it wasn't a brand new conversation
                    // being initialized.
                    _selectedConversationId = null;
                  }
                }

                // If we have a selected ID but it's not in the list yet (brand new),
                // we might need a fallback or a mock "current" for the chat panel.
                MessageConversation? current;
                if (_selectedConversationId != null) {
                  final found = conversations.where(
                    (c) => c.conversationId == _selectedConversationId,
                  );
                  if (found.isNotEmpty) {
                    current = found.first;
                  }
                }

                // Fallback for wide screen if still null
                if (current == null && isWide && conversations.isNotEmpty) {
                  current = conversations.first;
                  _selectedConversationId = current.conversationId;
                }

                if (current == null && _selectedConversationId == null) {
                  return _buildConversationList(conversations);
                }

                // If we have a selected ID but it hasn't hit the inbox list yet,
                // we show a loading state for the chat panel or a mock state.
                if (current == null && _selectedConversationId != null) {
                  return const Center(child: AppShimmerLoader());
                }

                final conversationList = _buildConversationList(conversations);
                final chatPanel = _buildChatPanel(current!);

                if (isWide) {
                  return Row(
                    children: [
                      Container(
                        width: 380,
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: AppColors.textSubtle.withValues(
                                alpha: 0.1,
                              ),
                            ),
                          ),
                        ),
                        child: conversationList,
                      ),
                      Expanded(
                        child: Container(color: Colors.white, child: chatPanel),
                      ),
                    ],
                  );
                }

                if (_selectedConversationId == null) {
                  return conversationList;
                }

                return chatPanel;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList(List<MessageConversation> conversations) {
    return RefreshIndicator(
      onRefresh: _refreshInbox,
      displacement: 20,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemBuilder: (context, index) {
          final conversation = conversations[index];
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
                      ? AppColors.primary.withValues(alpha: 0.3)
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
                            ? AppColors.primaryLight
                            : AppColors.textSubtle.withValues(alpha: 0.1),
                        child: Text(
                          conversation.otherDisplayName.isNotEmpty
                              ? conversation.otherDisplayName[0].toUpperCase()
                              : '?',
                          style: AppTextStyles.headline3.copyWith(
                            color: isSelected
                                ? AppColors.primary
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
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
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
                                    ? AppColors.primary
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
                                conversation.lastMessage,
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
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
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
        itemCount: conversations.length,
      ),
    );
  }

  Widget _buildChatPanel(MessageConversation conversation) {
    return Column(
      children: [
        // Chat Header
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
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    conversation.otherDisplayName.isNotEmpty
                        ? conversation.otherDisplayName[0].toUpperCase()
                        : '?',
                    style: AppTextStyles.headline3.copyWith(
                      color: AppColors.primary,
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
                            return Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isOnline
                                    ? AppColors.success
                                    : AppColors.textSubtle.withValues(
                                        alpha: 0.2,
                                      ),
                                shape: BoxShape.circle,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        ValueListenableBuilder<Set<String>>(
                          valueListenable:
                              NotificationService().onlineUsersNotifier,
                          builder: (context, onlineUsers, _) {
                            final isOnline = onlineUsers.contains(
                              conversation.otherUserId,
                            );
                            return Text(
                              isOnline ? 'Active now' : 'Offline',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.textSubtle,
                                fontSize: 11,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
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

                // Merge optimistic messages for this conversation
                final localForThisChat = _optimisticMessages
                    .where(
                      (m) => m.conversationId == conversation.conversationId,
                    )
                    .toList();

                if (localForThisChat.isNotEmpty) {
                  final merged = List<ChatMessage>.from(messages);
                  for (final local in localForThisChat) {
                    // Avoid duplicates if the stream already caught up
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
                      // Cleanup optimistic list if it's already in the DB stream
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
                  // Sort merged list by time (oldest first for reverse builder)
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
                                    ? AppColors.primaryGradient
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
                                      color: AppColors.primary,
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
        Container(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            MediaQuery.of(context).padding.bottom + 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.textSubtle.withValues(alpha: 0.2),
                    ),
                  ),
                  child: TextField(
                    controller: _composerController,
                    minLines: 1,
                    maxLines: 5,
                    style: AppTextStyles.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Write a message...',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSubtle,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      border: InputBorder.none,
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.emoji_emotions_outlined,
                          size: 20,
                        ),
                        color: AppColors.textSubtle,
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
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary,
                        blurRadius: 12,
                        spreadRadius: -4,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_rounded,
                    size: 40,
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                  const Icon(
                    Icons.mail_outline_rounded,
                    size: 24,
                    color: AppColors.primary,
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
                style: AppDecorations.primaryButton.copyWith(
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(vertical: 16),
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

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) {
      return '';
    }

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

  String _formatMessageTime(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
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
        color: isMine ? Colors.white.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMine ? Colors.white24 : AppColors.primary.withValues(alpha: 0.1),
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
                  color: isMine ? Colors.white24 : AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  size: 18,
                  color: isMine ? Colors.white : AppColors.primary,
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
                        color: isMine ? Colors.white70 : AppColors.primary,
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
                if (_asFarmerInbox) {
                  context.push('/farmer/orders/$orderId');
                } else {
                  context.push('/orders/$orderId');
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
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
                            color: isMine ? Colors.white70 : AppColors.primary,
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
                            color: isMine ? Colors.white : AppColors.primary,
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
                    backgroundColor: isMine ? Colors.white : AppColors.primary,
                    foregroundColor: isMine ? AppColors.primary : Colors.white,
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
}
