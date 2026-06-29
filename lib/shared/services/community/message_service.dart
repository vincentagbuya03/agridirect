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
    this.otherUpdatedAt,
  });

  final String conversationId;
  final String otherUserId;
  final String otherDisplayName;
  final String otherSubtitle;
  final String? otherAvatarUrl;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final String? otherUpdatedAt;
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

    // 🔵 Use a single joined query to fetch all details at once.
    // This ensures we always get the "real name" from the linked users table.
    final query = _client.from('conversations').select('''
          conversation_id,
          customer_id,
          farmer_id,
          last_message_at,
          customer:customers (
            customer_id,
            user:users (user_id, name, email, avatar_url, updated_at)
          ),
          farmer:farmers (
            farmer_id,
            user_id,
            farm_name,
            specialty,
            image_url,
            user:users (user_id, name, email, avatar_url, updated_at)
          )
        ''');

    final response = await query.eq(asFarmer ? 'farmer_id' : 'customer_id', actorId)
                                .order('last_message_at', ascending: false);

    final conversations = List<Map<String, dynamic>>.from(response);
    if (conversations.isEmpty) return [];

    final conversationIds =
        conversations.map((row) => row['conversation_id'].toString()).toList();

    // Fetch the last message for each conversation
    final messageRows = List<Map<String, dynamic>>.from(
      await _client
          .from('messages')
          .select(
            'message_id, conversation_id, sender_id, message_text, is_read, created_at',
          )
          .inFilter('conversation_id', conversationIds)
          .order('created_at', ascending: false),
    );

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
      
      late String otherUserId;
      late String displayName;
      late String subtitle;
      String? avatarUrl;
      String? otherUpdatedAt;

      if (asFarmer) {
        // We are the farmer, the "other" is the customer
        final customerData = row['customer'] as Map<String, dynamic>?;
        final userData = customerData?['user'] as Map<String, dynamic>?;
        
        otherUserId = userData?['user_id']?.toString() ?? '';
        displayName = (userData?['name'] as String?)?.trim().isNotEmpty == true
            ? userData!['name'].toString()
            : (userData?['email'] as String?) ?? 'Customer';
        subtitle = 'Customer';
        avatarUrl = userData?['avatar_url'] as String?;
        otherUpdatedAt = userData?['updated_at'] as String?;
      } else {
        // We are the customer, the "other" is the farmer
        final farmerData = row['farmer'] as Map<String, dynamic>?;
        final userData = farmerData?['user'] as Map<String, dynamic>?;
        
        otherUserId = farmerData?['user_id']?.toString() ?? '';
        displayName = (farmerData?['farm_name'] as String?)?.trim().isNotEmpty == true
            ? farmerData!['farm_name'].toString()
            : (userData?['name'] as String?) ?? 'Farmer';
        subtitle = (farmerData?['specialty'] as String?)?.trim().isNotEmpty == true
            ? farmerData!['specialty'].toString()
            : 'Farmer';
        avatarUrl = farmerData?['image_url'] as String?;
        otherUpdatedAt = userData?['updated_at'] as String?;
      }

      final lastMessage = lastMessageByConversation[conversationId];
      String displayMessage = lastMessage?.messageText ?? 'No messages yet';
      
      if (displayMessage.startsWith('[PRODUCT_INQUIRY:')) {
        displayMessage = 'Product Inquiry';
      }

      return MessageConversation(
        conversationId: conversationId,
        otherUserId: otherUserId,
        otherDisplayName: displayName,
        otherSubtitle: subtitle,
        otherAvatarUrl: avatarUrl,
        lastMessage: displayMessage,
        lastMessageAt: lastMessage?.createdAt,
        unreadCount: unreadCountByConversation[conversationId] ?? 0,
        otherUpdatedAt: otherUpdatedAt,
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

  /// Get one-time messages for a conversation (for duplicate detection etc.)
  Future<List<ChatMessage>> getMessages({required String conversationId}) async {
    try {
      final response = await _client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      final items = response as List;
      return items.map((map) => ChatMessage.fromMap(Map<String, dynamic>.from(map))).toList();
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      return [];
    }
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

  Future<String> startConversationWithCustomer(String customerId) async {
    final context = await _resolveActorContext();
    if (context.farmerId == null) {
      throw Exception(
        'A farmer profile is required to start a conversation with a customer.',
      );
    }

    final existing = await _client
        .from('conversations')
        .select('conversation_id')
        .eq('customer_id', customerId)
        .eq('farmer_id', context.farmerId!)
        .maybeSingle();

    if (existing != null) {
      return existing['conversation_id'].toString();
    }

    final inserted = await _client
        .from('conversations')
        .insert({
          'customer_id': customerId,
          'farmer_id': context.farmerId,
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

    var customer = await _client
        .from('customers')
        .select('customer_id')
        .eq('user_id', userId)
        .maybeSingle();

    if (customer == null) {
      debugPrint('🔧 Auto-healing missing customer profile for $userId');
      try {
        await _client.from('customers').upsert({
          'user_id': userId,
          'is_active': true,
        }, onConflict: 'user_id');
        
        customer = await _client
            .from('customers')
            .select('customer_id')
            .eq('user_id', userId)
            .maybeSingle();
      } catch (e) {
        debugPrint('❌ Failed to auto-heal customer profile: $e');
      }
    }

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
