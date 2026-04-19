// ============================================================================
// lib/shared/services/admin/admin_service.dart
// Admin operations, moderation, and system management
// ============================================================================

import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================================
  // ADMIN VERIFICATION
  // ============================================================================

  /// Check if current user is admin
  Future<bool> isCurrentUserAdmin() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('user_roles')
          .select('role_id')
          .eq('user_id', userId);

      final roleIds = (response as List<dynamic>).map(
        (r) => r as Map<String, dynamic>,
      );

      for (var roleData in roleIds) {
        final role = await _supabase
            .from('roles')
            .select('name')
            .eq('role_id', roleData['role_id']);

        if ((role as List<dynamic>).isNotEmpty) {
          final roleName = role[0]['name'];
          if (roleName == 'admin') return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ============================================================================
  // FARMER REGISTRATION MANAGEMENT
  // ============================================================================

  /// Get pending farmer registrations
  Future<List<Map<String, dynamic>>> getPendingRegistrations() async {
    try {
      final response = await _supabase
          .from('farmer_registrations')
          .select(
            'registration_id, farmer_id, status, created_at, farmers!inner(user_id, farm_name, users!fk_farmers_user(name, email))',
          )
          .eq('status', 'pending')
          .order('created_at', ascending: true);

      return (response as List<dynamic>)
          .map(
            (row) => {
              'registration_id': row['registration_id'],
              'user_id': row['farmers']?['user_id'],
              'farm_name': row['farmers']?['farm_name'],
              'status': 'pending',
              'created_at': row['created_at'],
              'users': row['farmers']?['users'],
            },
          )
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch pending registrations: $e');
    }
  }

  /// Approve farmer registration
  Future<void> approveFarmerRegistration(
    String registrationId,
    String userId,
  ) async {
    try {
      await _supabase
          .from('farmer_registrations')
          .update({
            'status': 'approved',
            'reviewed_by': _supabase.auth.currentUser?.id,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('registration_id', registrationId);

      final reg = await _supabase
          .from('farmer_registrations')
          .select('farmer_id')
          .eq('registration_id', registrationId)
          .maybeSingle();

      final farmerId = reg?['farmer_id'];
      if (farmerId != null) {
        await _supabase
            .from('farmers')
            .update({
              'is_verified': true,
              'is_active': true,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('farmer_id', farmerId);
            
        // Sync verified full name back to the main users table
        final regData = await _supabase.from('farmer_registrations').select('full_name').eq('registration_id', registrationId).maybeSingle();
        final fullName = regData?['full_name']?.toString() ?? '';
        if (fullName.isNotEmpty) {
          await _supabase.from('users').update({'name': fullName}).eq('user_id', userId);
        }
      }

      // Add 'seller' role to user
      final roles = await _supabase
          .from('roles')
          .select('role_id')
          .eq('name', 'seller');

      if ((roles as List<dynamic>).isNotEmpty) {
        final roleId = roles[0]['role_id'];
        await _supabase.from('user_roles').insert({
          'user_id': userId,
          'role_id': roleId,
        });
      }

      // Log action
      await logAdminAction(
        'approve_farmer',
        'Approved farmer registration',
        targetUserId: userId,
      );
    } catch (e) {
      throw Exception('Failed to approve farmer registration: $e');
    }
  }

  /// Reject farmer registration
  Future<void> rejectFarmerRegistration(
    String registrationId,
    String userId, {
    String? reason,
  }) async {
    try {
      await _supabase
          .from('farmer_registrations')
          .update({
            'status': 'rejected',
            'reviewed_by': _supabase.auth.currentUser?.id,
            'review_notes': reason,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('registration_id', registrationId);

      final reg = await _supabase
          .from('farmer_registrations')
          .select('farmer_id')
          .eq('registration_id', registrationId)
          .maybeSingle();

      final farmerId = reg?['farmer_id'];
      if (farmerId != null) {
        await _supabase
            .from('farmers')
            .update({
              'is_active': false,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('farmer_id', farmerId);
      }

      await logAdminAction(
        'reject_farmer',
        reason ?? 'Rejected farmer registration',
        targetUserId: userId,
      );
    } catch (e) {
      throw Exception('Failed to reject farmer registration: $e');
    }
  }

  /// Get signed URL for a file in storage
  Future<String?> getSignedUrl(String path) async {
    try {
      // Determine bucket from path
      final parts = path.split('/');
      if (parts.isEmpty) return null;
      final bucket = parts[0];
      final fileName = parts.sublist(1).join('/');

      final response = await _supabase.storage
          .from(bucket)
          .createSignedUrl(fileName, 3600); // 1 hour

      return response;
    } catch (e) {
      return null;
    }
  }

  // ============================================================================
  // CONTENT MODERATION
  // ============================================================================

  /// Get pending reports
  Future<List<Map<String, dynamic>>> getPendingReports() async {
    try {
      final response = await _supabase
          .from('reported_content')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: true);

      return (response as List<dynamic>).cast<Map<String, dynamic>>().toList();
    } catch (e) {
      throw Exception('Failed to fetch pending reports: $e');
    }
  }

  /// Mark report as reviewing
  Future<void> markReportReviewing(String reportId) async {
    try {
      await _supabase
          .from('reported_content')
          .update({'status': 'reviewing'})
          .eq('report_id', reportId);
    } catch (e) {
      throw Exception('Failed to mark report as reviewing: $e');
    }
  }

  /// Resolve report
  Future<void> resolveReport(
    String reportId, {
    required String action,
    String? resolutionNotes,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('reported_content')
          .update({
            'status': 'resolved',
            'resolved_by': userId,
            'resolution_notes': resolutionNotes,
            'resolved_at': DateTime.now().toIso8601String(),
          })
          .eq('report_id', reportId);

      await logAdminAction(
        'resolve_report',
        'Resolved report - \$action + \$resolutionNotes',
      );
    } catch (e) {
      throw Exception('Failed to resolve report: $e');
    }
  }

  /// Dismiss report
  Future<void> dismissReport(String reportId, {String? reason}) async {
    try {
      await _supabase
          .from('reported_content')
          .update({
            'status': 'dismissed',
            'resolution_notes': reason,
            'resolved_at': DateTime.now().toIso8601String(),
          })
          .eq('report_id', reportId);

      await logAdminAction('dismiss_report', reason ?? 'Dismissed report');
    } catch (e) {
      throw Exception('Failed to dismiss report: $e');
    }
  }

  // ============================================================================
  // USER SUSPENSION
  // ============================================================================

  /// Suspend user
  Future<void> suspendUser(
    String userId, {
    required String reason,
    DateTime? expiresAt,
    required bool isPermanent,
  }) async {
    try {
      final adminId = _supabase.auth.currentUser?.id;
      if (adminId == null) throw Exception('User not authenticated');

      await _supabase.from('user_suspensions').insert({
        'user_id': userId,
        'reason': reason,
        'suspended_by': adminId,
        'expires_at': expiresAt?.toIso8601String(),
        'is_permanent': isPermanent,
      });

      await logAdminAction(
        'suspend_user',
        'User suspended: \$reason',
        targetUserId: userId,
      );
    } catch (e) {
      throw Exception('Failed to suspend user: $e');
    }
  }

  /// Lift suspension
  Future<void> liftSuspension(String userId) async {
    try {
      await _supabase.from('user_suspensions').delete().eq('user_id', userId);

      await logAdminAction(
        'lift_suspension',
        'User suspension lifted',
        targetUserId: userId,
      );
    } catch (e) {
      throw Exception('Failed to lift suspension: $e');
    }
  }

  /// Check if user is suspended
  Future<bool> isUserSuspended(String userId) async {
    try {
      final response = await _supabase
          .from('user_suspensions')
          .select()
          .eq('user_id', userId);

      if ((response as List<dynamic>).isEmpty) return false;

      final suspension = response[0];
      final expiresAt = suspension['expires_at'];
      final isPermanent = suspension['is_permanent'] as bool;

      if (isPermanent) return true;

      if (expiresAt != null) {
        return DateTime.parse(expiresAt as String).isAfter(DateTime.now());
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // ============================================================================
  // ADMIN LOGS
  // ============================================================================

  /// Log admin action
  Future<void> logAdminAction(
    String action,
    String details, {
    String? targetUserId,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      // Get the admin_id from the admins table for the current user
      final adminRecord = await _supabase
          .from('admins')
          .select('admin_id')
          .eq('user_id', currentUserId)
          .maybeSingle();

      if (adminRecord == null) {
        // User is not in admins table, skip logging
        return;
      }

      final adminId = adminRecord['admin_id'];

      await _supabase.from('admin_logs').insert({
        'admin_id': adminId,
        'action': action,
        'details': details,
        'target_user_id': targetUserId,
      });
    } catch (e) {
      // Silently fail - don't throw for logging failures
    }
  }

  /// Get admin logs
  Future<List<Map<String, dynamic>>> getAdminLogs({int limit = 50}) async {
    try {
      final response = await _supabase
          .from('admin_logs')
          .select()
          .limit(limit)
          .order('created_at', ascending: false);

      return (response as List<dynamic>).cast<Map<String, dynamic>>().toList();
    } catch (e) {
      throw Exception('Failed to fetch admin logs: $e');
    }
  }

  // ============================================================================
  // ARTICLES MANAGEMENT
  // ============================================================================

  /// Get all articles
  Future<List<Map<String, dynamic>>> getArticles({
    bool publishedOnly = false,
  }) async {
    try {
      var query = _supabase.from('admin_articles').select();

      if (publishedOnly) {
        query = query.eq('is_published', true);
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List<dynamic>).cast<Map<String, dynamic>>().toList();
    } catch (e) {
      throw Exception('Failed to fetch articles: $e');
    }
  }

  /// Create article
  Future<Map<String, dynamic>> createArticle({
    required String title,
    required String content,
    String? imageUrl,
    String? readTime,
    bool published = false,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final adminRecord = await _supabase
          .from('admins')
          .select('admin_id')
          .eq('user_id', userId)
          .maybeSingle();

      final adminId = adminRecord?['admin_id'] as String?;
      if (adminId == null) {
        throw Exception('Only admin users can create articles');
      }

      final response = await _supabase
          .from('admin_articles')
          .insert({
            'admin_id': adminId,
            'title': title,
            'summary': readTime,
            'body': content,
            'cover_image_url': imageUrl,
            'is_published': published,
            'published_at': published ? DateTime.now().toIso8601String() : null,
          })
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to create article: $e');
    }
  }

  /// Update article
  Future<void> updateArticle(
    String articleId, {
    String? title,
    String? content,
    String? imageUrl,
    String? readTime,
    bool? published,
  }) async {
    try {
      await _supabase
          .from('admin_articles')
          .update({
            'title': ?title,
            'body': ?content,
            'cover_image_url': ?imageUrl,
            'summary': ?readTime,
            'is_published': ?published,
            if (published != null)
              'published_at': published
                  ? DateTime.now().toIso8601String()
                  : null,
          })
          .eq('article_id', articleId);
    } catch (e) {
      throw Exception('Failed to update article: $e');
    }
  }

  /// Delete article
  Future<void> deleteArticle(String articleId) async {
    try {
      await _supabase
          .from('admin_articles')
          .delete()
          .eq('article_id', articleId);
    } catch (e) {
      throw Exception('Failed to delete article: $e');
    }
  }
}
