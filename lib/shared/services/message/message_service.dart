import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/message/conversation_model.dart';
import '../../models/message/message_model.dart';

class MessageService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================================
  // CONVERSATIONS
  // ============================================================================

  /// Get current user's conversations
  Future<List<Conversation>> getConversations({int limit = 30}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('v_conversations')
          .select()
          .or('participant_1_id.eq.$userId,participant_2_id.eq.$userId')
          .limit(limit)
          .order('updated_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => Conversation.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch conversations: $e');
    }
  }

  /// Get or create a conversation with another user
  Future<Conversation> getOrCreateConversation({
    required String otherUserId,
    String? orderId,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Order participant IDs to prevent duplicate conversations
      final id1 = userId.compareTo(otherUserId) < 0 ? userId : otherUserId;
      final id2 = userId.compareTo(otherUserId) < 0 ? otherUserId : userId;

      // Try to find existing conversation
      final existing = await _supabase
          .from('v_conversations')
          .select()
          .eq('participant_1_id', id1)
          .eq('participant_2_id', id2)
          .maybeSingle();

      if (existing != null) {
        return Conversation.fromJson(existing);
      }

      // Create new conversation
      final response = await _supabase.from('conversations').insert({
        'participant_1_id': id1,
        'participant_2_id': id2,
        'order_id': orderId,
      }).select().single();

      return Conversation.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get or create conversation: $e');
    }
  }

  /// Get conversation by ID
  Future<Conversation?> getConversationById(String conversationId) async {
    try {
      final response = await _supabase
          .from('v_conversations')
          .select()
          .eq('conversation_id', conversationId)
          .single();

      return Conversation.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // ============================================================================
  // MESSAGES
  // ============================================================================

  /// Get messages for a conversation
  Future<List<Message>> getMessages(String conversationId,
      {int limit = 50, int offset = 0}) async {
    try {
      final response = await _supabase
          .from('v_messages')
          .select()
          .eq('conversation_id', conversationId)
          .range(offset, offset + limit - 1)
          .order('created_at', ascending: true);

      return (response as List<dynamic>)
          .map((json) => Message.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch messages: $e');
    }
  }

  /// Send a message
  Future<Message> sendMessage({
    required String conversationId,
    required String recipientId,
    required String content,
    String? imageUrl,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': userId,
        'recipient_id': recipientId,
        'content': content,
        'image_url': imageUrl,
      }).select().single();

      final message = Message.fromJson(response);

      // Update conversation last_message_id
      await _supabase
          .from('conversations')
          .update({'last_message_id': message.messageId})
          .eq('conversation_id', conversationId);

      return message;
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  /// Mark messages as read in a conversation
  Future<void> markMessagesAsRead(String conversationId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('messages')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('conversation_id', conversationId)
          .eq('recipient_id', userId)
          .eq('is_read', false);
    } catch (e) {
      throw Exception('Failed to mark messages as read: $e');
    }
  }

  /// Get unread message count
  Future<int> getUnreadCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      final response = await _supabase
          .rpc('get_unread_message_count', params: {'user_uuid': userId});

      return (response as num?)?.toInt() ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Subscribe to new messages in a conversation
  RealtimeChannel subscribeToMessages(
    String conversationId,
    void Function(Message) onMessage,
  ) {
    return _supabase
        .channel('messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final message =
                Message.fromJson(payload.newRecord);
            onMessage(message);
          },
        )
        .subscribe();
  }

  /// Subscribe to conversation list updates
  RealtimeChannel subscribeToConversations(void Function() onUpdate) {
    final userId = _supabase.auth.currentUser?.id;
    return _supabase
        .channel('conversations:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (_) => onUpdate(),
        )
        .subscribe();
  }
}
