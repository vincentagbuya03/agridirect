import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/notification/app_notification_model.dart';

class NotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get user's notifications
  Future<List<AppNotification>> getNotifications(
      {int limit = 30, int offset = 0}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .range(offset, offset + limit - 1)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) =>
              AppNotification.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch notifications: $e');
    }
  }

  /// Get unread notification count
  Future<int> getUnreadCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      final response = await _supabase.rpc('get_unread_notification_count',
          params: {'user_uuid': userId});

      return (response as num?)?.toInt() ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('notification_id', notificationId);
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      throw Exception('Failed to mark all notifications as read: $e');
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('notification_id', notificationId);
    } catch (e) {
      throw Exception('Failed to delete notification: $e');
    }
  }

  /// Create a notification
  Future<AppNotification> createNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    String? relatedEntityId,
    String? relatedEntityType,
    String? actionUrl,
  }) async {
    try {
      final response = await _supabase.from('notifications').insert({
        'user_id': userId,
        'type': type,
        'title': title,
        'message': message,
        'related_entity_id': relatedEntityId,
        'related_entity_type': relatedEntityType,
        'action_url': actionUrl,
      }).select().single();

      return AppNotification.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create notification: $e');
    }
  }

  /// Subscribe to realtime notifications
  RealtimeChannel subscribeToNotifications(
    void Function(AppNotification) onNotification,
  ) {
    final userId = _supabase.auth.currentUser?.id;
    return _supabase
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId ?? '',
          ),
          callback: (payload) {
            final notification = AppNotification.fromJson(
                payload.newRecord);
            onNotification(notification);
          },
        )
        .subscribe();
  }
}
