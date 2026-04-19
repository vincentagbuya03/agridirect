import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';

class MessageConversation {
  const MessageConversation({
    required this.conversationId,
    required this.otherUserId,
    required this.otherDisplayName,
    required this.otherSubtitle,
    required this.otherAvatarUrl,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  final String conversationId;
  final String otherUserId;
  final String otherDisplayName;
  final String otherSubtitle;
  final String? otherAvatarUrl;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
}

enum MessageStatus { sending, sent, error }

class ChatMessage {
  const ChatMessage({
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    required this.messageText,
    required this.isRead,
    required this.createdAt,
    this.status = MessageStatus.sent,
  });

  final String messageId;
  final String conversationId;
  final String senderId;
  final String messageText;
  final bool isRead;
  final DateTime createdAt;
  final MessageStatus status;

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      messageId: map['message_id'].toString(),
      conversationId: map['conversation_id'].toString(),
      senderId: map['sender_id'].toString(),
      messageText: (map['message_text'] as String?) ?? '',
      isRead: map['is_read'] == true,
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      status: MessageStatus.sent,
    );
  }
}

class MessageService {
  MessageService._internal();

  static final MessageService _instance = MessageService._internal();

  factory MessageService() => _instance;

  final SupabaseClient _client = SupabaseConfig.client;

  Future<List<MessageConversation>> getInbox({required bool asFarmer}) async {
    final context = await _resolveActorContext();
    final actorId = asFarmer ? context.farmerId : context.customerId;

    if (actorId == null) {
      return [];
    }

    final rows = await _client
        .from('conversations')
        .select()
        .eq(asFarmer ? 'farmer_id' : 'customer_id', actorId)
        .order('last_message_at', ascending: false);

    final conversations = List<Map<String, dynamic>>.from(rows);
    if (conversations.isEmpty) {
      return [];
    }

    final conversationIds = conversations
        .map((row) => row['conversation_id'].toString())
        .toList();

    final messageRows = List<Map<String, dynamic>>.from(
      await _client
          .from('messages')
          .select(
            'message_id, conversation_id, sender_id, message_text, is_read, created_at',
          )
          .inFilter('conversation_id', conversationIds)
          .order('created_at', ascending: false),
    );

    final farmerIds = conversations
        .map((row) => row['farmer_id'].toString())
        .toSet()
        .toList();
    final customerIds = conversations
        .map((row) => row['customer_id'].toString())
        .toSet()
        .toList();

    final farmerRows = farmerIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _client
                .from('farmers')
                .select('farmer_id, user_id, farm_name, specialty, image_url')
                .inFilter('farmer_id', farmerIds),
          );

    final customerRows = customerIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _client
                .from('customers')
                .select('customer_id, user_id')
                .inFilter('customer_id', customerIds),
          );

    // Some historical rows can miss customer.user_id/farmer.user_id, so derive
    // counterpart user IDs from recent message sender IDs as a fallback.
    final otherSenderByConversation = <String, String>{};
    for (final row in messageRows) {
      final conversationId = row['conversation_id']?.toString();
      final senderId = row['sender_id']?.toString();
      if (conversationId == null || senderId == null || senderId.isEmpty) {
        continue;
      }
      if (senderId == context.userId) {
        continue;
      }
      otherSenderByConversation.putIfAbsent(conversationId, () => senderId);
    }

    final inferredOtherUserIds = conversations
        .map(
          (row) => otherSenderByConversation[row['conversation_id'].toString()],
        )
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    final userIds = <String>{
      ...farmerRows.map((row) => row['user_id'].toString()),
      ...customerRows.map((row) => row['user_id'].toString()),
      ...inferredOtherUserIds,
    }.toList();

    final userRows = userIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _client
                .from('users')
                .select('user_id, name, email, avatar_url')
                .inFilter('user_id', userIds),
          );

    final farmerById = {
      for (final row in farmerRows) row['farmer_id'].toString(): row,
    };
    final customerById = {
      for (final row in customerRows) row['customer_id'].toString(): row,
    };
    final userById = {
      for (final row in userRows) row['user_id'].toString(): row,
    };

    final lastMessageByConversation = <String, ChatMessage>{};
    final unreadCountByConversation = <String, int>{};

    for (final row in messageRows) {
      final message = ChatMessage.fromMap(row);
      lastMessageByConversation.putIfAbsent(
        message.conversationId,
        () => message,
      );

      if (!message.isRead && message.senderId != context.userId) {
        unreadCountByConversation[message.conversationId] =
            (unreadCountByConversation[message.conversationId] ?? 0) + 1;
      }
    }

    return conversations.map((row) {
      final conversationId = row['conversation_id'].toString();
      final farmer = farmerById[row['farmer_id'].toString()];
      final customer = customerById[row['customer_id'].toString()];

      late String otherUserId;
      late String displayName;
      late String subtitle;
      String? avatarUrl;

      if (asFarmer) {
        final fallbackUserId = otherSenderByConversation[conversationId];
        final resolvedUserId =
            customer?['user_id']?.toString().isNotEmpty == true
            ? customer!['user_id'].toString()
            : (fallbackUserId ?? '');
        final customerUser = userById[resolvedUserId] ?? const {};
        otherUserId = resolvedUserId;
        displayName =
            (customerUser['name'] as String?)?.trim().isNotEmpty == true
            ? customerUser['name'].toString()
            : (customerUser['email'] as String?) ?? 'Customer';
        subtitle = 'Customer';
        avatarUrl = customerUser['avatar_url'] as String?;
      } else {
        final fallbackUserId = otherSenderByConversation[conversationId];
        otherUserId = farmer?['user_id']?.toString().isNotEmpty == true
            ? farmer!['user_id'].toString()
            : (fallbackUserId ?? '');
        displayName =
            (farmer?['farm_name'] as String?)?.trim().isNotEmpty == true
            ? farmer!['farm_name'].toString()
            : 'Farmer';
        subtitle = (farmer?['specialty'] as String?)?.trim().isNotEmpty == true
            ? farmer!['specialty'].toString()
            : 'Farmer';
        avatarUrl = farmer?['image_url'] as String?;
      }

      final lastMessage = lastMessageByConversation[conversationId];

      return MessageConversation(
        conversationId: conversationId,
        otherUserId: otherUserId,
        otherDisplayName: displayName,
        otherSubtitle: subtitle,
        otherAvatarUrl: avatarUrl,
        lastMessage: lastMessage?.messageText ?? 'No messages yet',
        lastMessageAt: lastMessage?.createdAt,
        unreadCount: unreadCountByConversation[conversationId] ?? 0,
      );
    }).toList();
  }

  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['message_id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map(
          (rows) =>
              rows.map((row) => ChatMessage.fromMap(row)).toList()
                ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
        );
  }

  Stream<List<MessageConversation>> watchInbox({required bool asFarmer}) {
    return (() async* {
      // Initial fetch
      yield await getInbox(asFarmer: asFarmer);

      final context = await _resolveActorContext();
      final actorId = asFarmer ? context.farmerId : context.customerId;
      if (actorId == null) return;

      // Trigger refreshes from both conversation updates and message inserts/updates.
      final refreshController = StreamController<void>.broadcast();

      final conversationsSub = _client
          .from('conversations')
          .stream(primaryKey: ['conversation_id'])
          .eq(asFarmer ? 'farmer_id' : 'customer_id', actorId)
          .listen((_) {
            if (!refreshController.isClosed) {
              refreshController.add(null);
            }
          });

      final messagesSub = _client
          .from('messages')
          .stream(primaryKey: ['message_id'])
          .listen((_) {
            if (!refreshController.isClosed) {
              refreshController.add(null);
            }
          });

      try {
        await for (final _ in refreshController.stream) {
          yield await getInbox(asFarmer: asFarmer);
        }
      } finally {
        await conversationsSub.cancel();
        await messagesSub.cancel();
        await refreshController.close();
      }
    })();
  }

  Future<String> startConversationWithFarmer(String farmerId) async {
    final context = await _resolveActorContext();
    if (context.customerId == null) {
      throw Exception(
        'A customer profile is required to start a conversation.',
      );
    }

    final existing = await _client
        .from('conversations')
        .select('conversation_id')
        .eq('customer_id', context.customerId!)
        .eq('farmer_id', farmerId)
        .maybeSingle();

    if (existing != null) {
      return existing['conversation_id'].toString();
    }

    final inserted = await _client
        .from('conversations')
        .insert({
          'customer_id': context.customerId,
          'farmer_id': farmerId,
          'last_message_at': DateTime.now().toIso8601String(),
        })
        .select('conversation_id')
        .single();

    return inserted['conversation_id'].toString();
  }

  Future<void> sendMessage({
    required String conversationId,
    required String messageText,
  }) async {
    final trimmed = messageText.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final context = await _resolveActorContext();

    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': context.userId,
      'message_text': trimmed,
    });

    await _client
        .from('conversations')
        .update({'last_message_at': DateTime.now().toIso8601String()})
        .eq('conversation_id', conversationId);

    final senderName = await _resolveSenderDisplayName(senderContext: context);

    await _sendMessagePushNotification(
      conversationId: conversationId,
      senderContext: context,
      senderName: senderName,
      messageText: trimmed,
    );
  }

  Future<void> _sendMessagePushNotification({
    required String conversationId,
    required _ActorContext senderContext,
    required String senderName,
    required String messageText,
  }) async {
    try {
      final conversation = await _client
          .from('conversations')
          .select('customer_id, farmer_id')
          .eq('conversation_id', conversationId)
          .maybeSingle();

      final customerId = conversation?['customer_id']?.toString();
      final farmerId = conversation?['farmer_id']?.toString();

      if (customerId == null || farmerId == null) {
        return;
      }

      String? targetUserId;
      if (senderContext.customerId == customerId) {
        final farmer = await _client
            .from('farmers')
            .select('user_id')
            .eq('farmer_id', farmerId)
            .maybeSingle();
        targetUserId = farmer?['user_id']?.toString();
      } else if (senderContext.farmerId == farmerId) {
        final customer = await _client
            .from('customers')
            .select('user_id')
            .eq('customer_id', customerId)
            .maybeSingle();
        targetUserId = customer?['user_id']?.toString();
      }

      if (targetUserId == null || targetUserId.isEmpty) {
        return;
      }

      final preview = messageText.length > 120
          ? '${messageText.substring(0, 117)}...'
          : messageText;

      await _client.functions.invoke(
        'send-push-notification',
        body: {
          'targetUserId': targetUserId,
          'title': 'New message from $senderName',
          'body': preview,
          'notificationCode': 'new_message',
          'linkType': 'conversation',
          'linkId': conversationId,
          'data': {
            'conversation_id': conversationId,
            'sender_id': senderContext.userId,
            'sender_name': senderName,
          },
        },
      );
    } catch (e) {
      debugPrint('Failed to send message push notification: $e');
    }
  }

  Future<void> markConversationAsRead(String conversationId) async {
    final context = await _resolveActorContext();

    await _client
        .from('messages')
        .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
        .eq('conversation_id', conversationId)
        .neq('sender_id', context.userId)
        .eq('is_read', false);
  }

  Future<_ActorContext> _resolveActorContext() async {
    final userId = SupabaseConfig.currentUser?.id;
    if (userId == null) {
      throw Exception('You need to be logged in to use messages.');
    }

    final customer = await _client
        .from('customers')
        .select('customer_id')
        .eq('user_id', userId)
        .maybeSingle();

    final farmer = await _client
        .from('farmers')
        .select('farmer_id')
        .eq('user_id', userId)
        .maybeSingle();

    return _ActorContext(
      userId: userId,
      customerId: customer?['customer_id']?.toString(),
      farmerId: farmer?['farmer_id']?.toString(),
    );
  }

  Future<String> _resolveSenderDisplayName({
    required _ActorContext senderContext,
  }) async {
    // Prefer farm name for farmer senders; otherwise use user profile display name.
    if (senderContext.farmerId != null) {
      final farmer = await _client
          .from('farmers')
          .select('farm_name')
          .eq('farmer_id', senderContext.farmerId!)
          .maybeSingle();

      final farmName = (farmer?['farm_name'] as String?)?.trim();
      if (farmName != null && farmName.isNotEmpty) {
        return farmName;
      }
    }

    final user = await _client
        .from('users')
        .select('name, email')
        .eq('user_id', senderContext.userId)
        .maybeSingle();

    final name = (user?['name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }

    final email = (user?['email'] as String?)?.trim();
    if (email != null && email.isNotEmpty) {
      return email;
    }

    return 'Someone';
  }
}

class _ActorContext {
  const _ActorContext({
    required this.userId,
    required this.customerId,
    required this.farmerId,
  });

  final String userId;
  final String? customerId;
  final String? farmerId;
}
