// ============================================================================
// lib/shared/services/user_service.dart
// User profile and address operations
// ============================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/auth/user_model.dart' as user_model;
import '../models/auth/user_address_model.dart';

class UserService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================================
  // USER PROFILE OPERATIONS
  // ============================================================================

  /// Get current user profile with roles
  Future<user_model.User?> getCurrentUser() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('v_users_with_roles')
          .select()
          .eq('user_id', userId)
          .single();

      return user_model.User.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Get user by ID
  Future<user_model.User?> getUserById(String userId) async {
    try {
      final response = await _supabase
          .from('v_users_with_roles')
          .select()
          .eq('user_id', userId)
          .single();

      return user_model.User.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Update user profile
  Future<user_model.User?> updateProfile({
    String? name,
    String? phone,
    String? avatarUrl,
    String? bio,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('users')
          .update({
            if (name != null) 'name': name,
            if (phone != null) 'phone': phone,
            if (avatarUrl != null) 'avatar_url': avatarUrl,
            if (bio != null) 'bio': bio,
          })
          .eq('user_id', userId)
          .select()
          .single();

      return user_model.User.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Get user address
  Future<UserAddress?> getUserAddress() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('user_addresses')
          .select()
          .eq('user_id', userId)
          .single();

      return UserAddress.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Create or update user address
  Future<UserAddress?> upsertAddress({
    required String street,
    required String barangay,
    required String city,
    required String province,
    required String zipCode,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Check if address exists
      final existing = await _supabase
          .from('user_addresses')
          .select()
          .eq('user_id', userId);

      if ((existing as List<dynamic>).isNotEmpty) {
        // Update existing
        final response = await _supabase
            .from('user_addresses')
            .update({
              'street': street,
              'barangay': barangay,
              'city': city,
              'province': province,
              'zip_code': zipCode,
            })
            .eq('user_id', userId)
            .select()
            .single();

        return UserAddress.fromJson(response);
      } else {
        // Insert new
        final response = await _supabase.from('user_addresses').insert({
          'user_id': userId,
          'street': street,
          'barangay': barangay,
          'city': city,
          'province': province,
          'zip_code': zipCode,
        }).select().single();

        return UserAddress.fromJson(response);
      }
    } catch (e) {
      return null;
    }
  }

  /// Delete user address
  Future<void> deleteAddress() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('user_addresses')
          .delete()
          .eq('user_id', userId);
    } catch (e) {
      rethrow;
    }
  }

  /// Search users by name
  Future<List<user_model.User>> searchUsers(String query) async {
    try {
      final response = await _supabase
          .from('v_users_with_roles')
          .select()
          .ilike('name', '%$query%')
          .limit(20);

      return (response as List<dynamic>)
          .map((json) => user_model.User.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }
}
