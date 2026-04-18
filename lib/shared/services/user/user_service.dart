// ============================================================================
// lib/shared/services/user/user_service.dart
// User profile and address operations
// ============================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/auth/user_model.dart' as user_model;
import '../../models/auth/user_address_model.dart';

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

  /// Get all user addresses
  Future<List<UserAddress>> getAllUserAddresses() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('delivery_addresses')
          .select()
          .eq('user_id', userId)
          .order('is_default', ascending: false)
          .order('updated_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => UserAddress.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get user address (default or latest)
  Future<UserAddress?> getUserAddress() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('delivery_addresses')
          .select()
          .eq('user_id', userId)
          .order('is_default', ascending: false)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      return UserAddress.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Create or update user address
  Future<UserAddress?> upsertAddress({
    String? addressId,
    required String street,
    required String barangay,
    required String city,
    required String province,
    required String zipCode,
    String? label,
    String? recipientName,
    String? recipientPhone,
    bool isDefault = false,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final currentUser = await getCurrentUser();
      final fallbackRecipientName =
          (currentUser?.name.trim().isNotEmpty ?? false)
          ? currentUser!.name.trim()
          : 'Recipient';
      final fallbackRecipientPhone =
          ((currentUser?.phone ?? '').trim().isNotEmpty)
          ? currentUser!.phone!.trim()
          : 'N/A';

      final data = {
        'user_id': userId,
        'street': street,
        'barangay': barangay,
        'city': city,
        'province': province,
        'zip_code': zipCode,
        'label': label ?? 'Home',
        'recipient_name': recipientName ?? fallbackRecipientName,
        'recipient_phone': recipientPhone ?? fallbackRecipientPhone,
        'is_default': isDefault,
        'latitude': latitude,
        'longitude': longitude,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (isDefault) {
        // Reset other addresses to not default
        await _supabase
            .from('delivery_addresses')
            .update({'is_default': false})
            .eq('user_id', userId);
      }

      if (addressId != null) {
        // Update specific
        final response = await _supabase
            .from('delivery_addresses')
            .update(data)
            .eq('address_id', addressId)
            .select()
            .single();
        return UserAddress.fromJson(response);
      } else {
        // Check if this is the first address, if so make it default
        final existing = await _supabase
            .from('delivery_addresses')
            .select('address_id')
            .eq('user_id', userId)
            .limit(1);
        
        if (existing.isEmpty) {
          data['is_default'] = true;
        }

        // Insert new
        final response = await _supabase
            .from('delivery_addresses')
            .insert(data)
            .select()
            .single();

        return UserAddress.fromJson(response);
      }
    } catch (e) {
      return null;
    }
  }

  /// Set an address as default
  Future<bool> setDefaultAddress(String addressId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      // Reset all
      await _supabase
          .from('delivery_addresses')
          .update({'is_default': false})
          .eq('user_id', userId);

      // Set default
      await _supabase
          .from('delivery_addresses')
          .update({'is_default': true})
          .eq('address_id', addressId);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete a specific user address
  Future<bool> deleteAddressById(String addressId) async {
    try {
      await _supabase
          .from('delivery_addresses')
          .delete()
          .eq('address_id', addressId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete user address
  Future<void> deleteAddress() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase.from('delivery_addresses').delete().eq('user_id', userId);
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
