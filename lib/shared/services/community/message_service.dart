import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';

class MessageConversation {
  const MessageConversation({
    required this.conversationId,
    required this.otherUserId,
    required this.otherDisplayName,
    required this.otherSubtitle,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  final String conversationId;
  final String otherUserId;
  final String otherDisplayName;
  final String otherSubtitle;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
}

class ChatMessage {
  const ChatMessage({
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    required this.messageText,
    required this.isRead,
    required this.createdAt,
  });

  final String messageId;
  final String conversationId;
  final String senderId;
  final String messageText;
  final bool isRead;
  final DateTime createdAt;

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
                .select('farmer_id, user_id, farm_name, specialty')
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

    final userIds = <String>{
      ...farmerRows.map((row) => row['user_id'].toString()),
      ...customerRows.map((row) => row['user_id'].toString()),
    }.toList();

    final userRows = userIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _client
                .from('users')
                .select('user_id, name, email')
                .inFilter('user_id', userIds),
          );

    final messageRows = List<Map<String, dynamic>>.from(
      await _client
          .from('messages')
          .select(
            'message_id, conversation_id, sender_id, message_text, is_read, created_at',
          )
          .inFilter('conversation_id', conversationIds)
          .order('created_at', ascending: false),
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

      if (asFarmer) {
        final customerUser =
            userById[customer?['user_id']?.toString() ?? ''] ?? const {};
        otherUserId = customer?['user_id']?.toString() ?? '';
        displayName =
            (customerUser['name'] as String?)?.trim().isNotEmpty == true
            ? customerUser['name'].toString()
            : (customerUser['email'] as String?) ?? 'Customer';
        subtitle = 'Customer';
      } else {
        otherUserId = farmer?['user_id']?.toString() ?? '';
        displayName =
            (farmer?['farm_name'] as String?)?.trim().isNotEmpty == true
            ? farmer!['farm_name'].toString()
            : 'Farmer';
        subtitle = (farmer?['specialty'] as String?)?.trim().isNotEmpty == true
            ? farmer!['specialty'].toString()
            : 'Farmer';
      }

      final lastMessage = lastMessageByConversation[conversationId];

      return MessageConversation(
        conversationId: conversationId,
        otherUserId: otherUserId,
        otherDisplayName: displayName,
        otherSubtitle: subtitle,
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

  Future<String> startConversationWithFarmerUser(String farmerUserId) async {
    final context = await _resolveActorContext();
    if (context.customerId == null) {
      throw Exception(
        'A customer profile is required to start a conversation.',
      );
    }

    final farmer = await _client
        .from('farmers')
        .select('farmer_id')
        .eq('user_id', farmerUserId)
        .maybeSingle();

    if (farmer == null) {
      throw Exception('Farmer profile not found.');
    }

    final farmerId = farmer['farmer_id'].toString();

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
