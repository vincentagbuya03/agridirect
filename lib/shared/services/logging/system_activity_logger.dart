import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SystemActivityLogger {
  SystemActivityLogger({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> log({
    required String action,
    required String details,
    required String entityType,
    String? entityId,
    String severity = 'info',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      await _client.from('system_activity_logs').insert({
        'actor_user_id': userId,
        'actor_role': await _resolveActorRole(userId),
        'action': action,
        'details': details,
        'entity_type': entityType,
        'entity_id': entityId,
        'severity': severity,
        'metadata': metadata ?? <String, dynamic>{},
      });
    } catch (e) {
      debugPrint('System activity log skipped: $e');
    }
  }

  Future<String> _resolveActorRole(String userId) async {
    try {
      final admin = await _client
          .from('admins')
          .select('admin_id')
          .eq('user_id', userId)
          .maybeSingle();
      if (admin != null) return 'Admin';

      final farmer = await _client
          .from('farmers')
          .select('farmer_id')
          .eq('user_id', userId)
          .maybeSingle();
      if (farmer != null) return 'Farmer';

      final customer = await _client
          .from('customers')
          .select('customer_id')
          .eq('user_id', userId)
          .maybeSingle();
      if (customer != null) return 'Customer';
    } catch (_) {
      // Role is helpful context, but logging should never block the main flow.
    }

    return 'User';
  }
}
