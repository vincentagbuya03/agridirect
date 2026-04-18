import 'package:flutter/material.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/auth/auth_service.dart';
import '../../services/community/message_service.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
    this.initialFarmerUserId,
    this.asFarmer,
  });

  final String? initialFarmerUserId;
  final bool? asFarmer;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  static const Color primary = Color(0xFF13EC5B);

  final _auth = AuthService();
  final _messageService = MessageService();
  final _composerController = TextEditingController();

  late bool _asFarmerInbox;
  late Future<List<MessageConversation>> _inboxFuture;
  String? _selectedConversationId;
  String? _errorText;
  bool _startingInitialConversation = false;

  @override
  void initState() {
    super.initState();
    _asFarmerInbox = widget.asFarmer ?? (widget.initialFarmerUserId == null
        ? _auth.isViewingAsFarmer
        : false);
    _loadInbox();
    _handleInitialConversation();
  }

  @override
  void dispose() {
    _composerController.dispose();
    super.dispose();
  }

  void _loadInbox() {
    _inboxFuture = _messageService.getInbox(asFarmer: _asFarmerInbox);
  }

  Future<void> _refreshInbox() async {
    setState(_loadInbox);
    await _inboxFuture;
  }

  Future<void> _handleInitialConversation() async {
    final farmerUserId = widget.initialFarmerUserId;
    if (farmerUserId == null || _asFarmerInbox) {
      return;
    }

    setState(() {
      _startingInitialConversation = true;
      _errorText = null;
    });

    try {
      final conversationId = await _messageService
          .startConversationWithFarmerUser(farmerUserId);

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedConversationId = conversationId;
      });
      setState(_loadInbox);
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

  Future<void> _openConversation(MessageConversation conversation) async {
    setState(() {
      _selectedConversationId = conversation.conversationId;
      _errorText = null;
    });
    await _messageService.markConversationAsRead(conversation.conversationId);
    if (mounted) {
      setState(_loadInbox);
    }
  }

  Future<void> _sendMessage() async {
    final conversationId = _selectedConversationId;
    if (conversationId == null) {
      return;
    }

    final text = _composerController.text;
    _composerController.clear();

    try {
      await _messageService.sendMessage(
        conversationId: conversationId,
        messageText: text,
      );
      if (mounted) {
        setState(_loadInbox);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF0F172A),
        title: Text(
          'Messages',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        actions: [
          if (_asFarmerInbox)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  'Farmer',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  'Customer',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_errorText != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: Text(
                _errorText!,
                style: const TextStyle(
                  color: Color(0xFF9F1239),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<MessageConversation>>(
              future: _inboxFuture,
              builder: (context, snapshot) {
                if (_startingInitialConversation ||
                    snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: AppShimmerLoader());
                }

                final conversations =
                    snapshot.data ?? const <MessageConversation>[];

                if (snapshot.hasError) {
                  return _buildEmptyState(
                    title: 'Unable to load messages',
                    subtitle: 'Please try again in a moment.',
                    actionLabel: 'Retry',
                    onPressed: _refreshInbox,
                  );
                }

                if (conversations.isEmpty) {
                  _selectedConversationId = null;
                  return _buildEmptyState(
                    title: 'No conversations yet',
                    subtitle: _asFarmerInbox
                        ? 'Customer inquiries will show up here.'
                        : 'Start a chat from a farmer card to ask about products.',
                    actionLabel: 'Refresh',
                    onPressed: _refreshInbox,
                  );
                }

                final hasSelectedConversation = conversations.any(
                  (conversation) =>
                      conversation.conversationId == _selectedConversationId,
                );
                if (!hasSelectedConversation) {
                  _selectedConversationId = isWide
                      ? conversations.first.conversationId
                      : null;
                }

                final current = conversations.firstWhere(
                  (conversation) =>
                      conversation.conversationId == _selectedConversationId,
                  orElse: () => conversations.first,
                );

                final conversationList = _buildConversationList(conversations);
                final chatPanel = _buildChatPanel(current);

                if (isWide) {
                  return Row(
                    children: [
                      SizedBox(width: 360, child: conversationList),
                      Expanded(child: chatPanel),
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
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final conversation = conversations[index];
          final isSelected =
              conversation.conversationId == _selectedConversationId;

          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _openConversation(conversation),
            child: Ink(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFECFDF5) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? primary.withValues(alpha: 0.35)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: primary.withValues(alpha: 0.14),
                    child: Text(
                      conversation.otherDisplayName.isNotEmpty
                          ? conversation.otherDisplayName[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.plusJakartaSans(
                        color: primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          conversation.otherDisplayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          conversation.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          conversation.otherSubtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatTime(conversation.lastMessageAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (conversation.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${conversation.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemCount: conversations.length,
      ),
    );
  }

  Widget _buildChatPanel(MessageConversation conversation) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                if (MediaQuery.of(context).size.width < 900)
                  IconButton(
                    onPressed: () => setState(() {
                      _selectedConversationId = null;
                    }),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                CircleAvatar(
                  backgroundColor: primary.withValues(alpha: 0.14),
                  child: Text(
                    conversation.otherDisplayName.isNotEmpty
                        ? conversation.otherDisplayName[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.plusJakartaSans(
                      color: primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.otherDisplayName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        conversation.otherSubtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
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
                final messages = snapshot.data ?? const <ChatMessage>[];
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
                  return const Center(
                    child: Text(
                      'Say hello to start the conversation.',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - 1 - index];
                    final isMine = message.senderId == _auth.userId;

                    return Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 520),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isMine ? primary : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.messageText,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                color: isMine
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatMessageTime(message.createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: isMine
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composerController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _sendMessage,
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 32,
                color: primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), height: 1.5),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(backgroundColor: primary),
              child: Text(actionLabel),
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
}

