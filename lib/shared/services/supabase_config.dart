import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/farmer_registration.dart';

/// Supabase Configuration & Initialization
///
/// To use this, you need to:
/// 1. Create a Supabase account at https://supabase.com
/// 2. Create a new project
/// 3. Get your API URL and Anon Key from Project Settings
/// 4. Replace SUPABASE_URL and SUPABASE_ANON_KEY below
class SupabaseConfig {
  // ============ TODO: REPLACE WITH YOUR SUPABASE CREDENTIALS ============
  //
  // Get these from https://app.supabase.com → Project Settings → API
  static const String supabaseUrl = 'https://ywfppgarzyksacgbesme.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3ZnBwZ2Fyenlrc2FjZ2Jlc21lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3NzEzMjcsImV4cCI6MjA4NzM0NzMyN30.aX1HIacJsHV8gU-9tGONnDpucE9vePWOrJbgMR4fSzs';
  // ========================================================================

  /// Initialize Supabase - call this in main() before runApp()
  static Future<void> initialize() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  /// Get the Supabase client instance
  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser => Supabase.instance.client.auth.currentUser;

  /// Check if user is logged in
  static bool get isLoggedIn => currentUser != null;
}

/// Helper class for database operations
class SupabaseDB {
  static final _client = SupabaseConfig.client;

  /// Users table operations - creates user only if not already exists (safe for trigger + client)
  /// Marks email as not confirmed initially
  static Future<void> createUserIfNotExists({
    required String userId,
    required String email,
    required String name,
    String? phoneNumber,
  }) async {
    try {
      // Check if user already exists (trigger may have already inserted)
      final existing = await _client
          .from('users')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (existing == null) {
        // User doesn't exist yet, insert now
        final userData = {
          'user_id': userId,
          'email': email,
          'name': name,
          'created_at': DateTime.now().toIso8601String(),
        };
        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          userData['phone'] = phoneNumber;
        }
        await _client.from('users').insert(userData);

        // Assign default 'consumer' role
        final roleResponse = await _client
            .from('roles')
            .select('role_id')
            .eq('name', 'consumer')
            .single();
        await _client.from('user_roles').insert({
          'user_id': userId,
          'role_id': roleResponse['role_id'],
        });
      } else {
        // User exists from trigger but name/phone might be empty, update it
        final updateData = <String, String>{};
        if (name.isNotEmpty) {
          updateData['name'] = name;
        }
        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          updateData['phone'] = phoneNumber;
        }
        if (updateData.isNotEmpty) {
          await _client.from('users').update(updateData).eq('user_id', userId);
        }

        // Ensure user has at least the 'consumer' role
        final existingRoles = await _client
            .from('user_roles')
            .select('role_id')
            .eq('user_id', userId);
        if ((existingRoles as List).isEmpty) {
          final roleResponse = await _client
              .from('roles')
              .select('role_id')
              .eq('name', 'consumer')
              .single();
          await _client.from('user_roles').insert({
            'user_id': userId,
            'role_id': roleResponse['role_id'],
          });
        }
      }
    } catch (e, stack) {
      debugPrint('Error creating/updating user: $e');
      debugPrint('Stack trace: $stack');
      // Rethrow so callers can handle/report the error
      rethrow;
    }
  }

  /// Users table operations (legacy - use createUserIfNotExists instead)
  static Future<void> createUser({
    required String userId,
    required String email,
    required String name,
    String? phoneNumber,
  }) async {
    try {
      final userData = {
        'user_id': userId,
        'email': email,
        'name': name,
        'created_at': DateTime.now().toIso8601String(),
      };
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        userData['phone'] = phoneNumber;
      }
      await _client.from('users').insert(userData);

      // Assign default 'consumer' role
      final roleResponse = await _client
          .from('roles')
          .select('role_id')
          .eq('name', 'consumer')
          .single();
      await _client.from('user_roles').insert({
        'user_id': userId,
        'role_id': roleResponse['role_id'],
      });
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  /// Update user name in the users table
  static Future<void> updateUserName({
    required String userId,
    required String name,
  }) async {
    try {
      await _client
          .from('users')
          .update({'name': name})
          .eq('user_id', userId);
    } catch (e) {
      print('Error updating user name: $e');
    }
  }

  /// Check if an email is already registered in the users table
  static Future<bool> isEmailAlreadyRegistered(String email) async {
    try {
      final result = await _client
          .from('users')
          .select('user_id')
          .eq('email', email)
          .maybeSingle();
      return result != null;
    } catch (e) {
      // RLS blocks unauthenticated reads — Supabase Auth handles duplicate emails natively
      return false;
    }
  }

  /// Check if a phone number is already registered in the users table
  static Future<bool> isPhoneAlreadyRegistered(String phone) async {
    try {
      final result = await _client
          .from('users')
          .select('user_id')
          .eq('phone', phone)
          .maybeSingle();
      return result != null;
    } catch (e) {
      // RLS blocks unauthenticated reads — skip check silently
      return false;
    }
  }

  /// Get user profile
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('user_id', userId)
          .single();
      return response;
    } catch (e) {
      print('Error fetching user: $e');
      return null;
    }
  }

  /// Add role to user (e.g., 'seller', 'admin')
  static Future<void> addUserRole({
    required String userId,
    required String roleName,
  }) async {
    try {
      final roleResponse = await _client
          .from('roles')
          .select('role_id')
          .eq('name', roleName)
          .single();
      await _client.from('user_roles').upsert({
        'user_id': userId,
        'role_id': roleResponse['role_id'],
      });
    } catch (e) {
      print('Error adding user role: $e');
      rethrow;
    }
  }

  /// Remove role from user
  static Future<void> removeUserRole({
    required String userId,
    required String roleName,
  }) async {
    try {
      final roleResponse = await _client
          .from('roles')
          .select('role_id')
          .eq('name', roleName)
          .single();
      await _client
          .from('user_roles')
          .delete()
          .eq('user_id', userId)
          .eq('role_id', roleResponse['role_id']);
    } catch (e) {
      print('Error removing user role: $e');
      rethrow;
    }
  }

  /// Check if user has a specific role
  static Future<bool> hasRole({
    required String userId,
    required String roleName,
  }) async {
    try {
      final response = await _client
          .from('user_roles')
          .select('role_id, roles!inner(name)')
          .eq('user_id', userId)
          .eq('roles.name', roleName)
          .maybeSingle();
      return response != null;
    } catch (e) {
      print('Error checking user role: $e');
      return false;
    }
  }

  /// Get all roles for a user
  static Future<List<String>> getUserRoles(String userId) async {
    try {
      final response = await _client
          .from('user_roles')
          .select('roles!inner(name)')
          .eq('user_id', userId);
      return (response as List)
          .map((r) => r['roles']['name'] as String)
          .toList();
    } catch (e) {
      print('Error fetching user roles: $e');
      return [];
    }
  }

  /// Submit farmer registration (inserts into farmer_registrations + decomposed tables)
  static Future<void> submitFarmerRegistration({
    required String userId,
    required FarmerRegistration registration,
  }) async {
    try {
      final data = registration.toJson();
      data['user_id'] = userId;
      final response = await _client.from('farmer_registrations').insert(data).select('registration_id').single();
      final registrationId = response['registration_id'];

      // Insert education rows
      final educationRows = registration.toEducationRows();
      if (educationRows.isNotEmpty) {
        await _client.from('farmer_education').insert(
          educationRows.map((e) => {...e, 'registration_id': registrationId}).toList(),
        );
      }

      // Insert crop type rows
      final cropRows = registration.toCropTypeRows();
      if (cropRows.isNotEmpty) {
        await _client.from('farmer_crop_types').insert(
          cropRows.map((c) => {...c, 'registration_id': registrationId}).toList(),
        );
      }

      // Insert livestock rows
      final livestockRows = registration.toLivestockRows();
      if (livestockRows.isNotEmpty) {
        await _client.from('farmer_livestock').insert(
          livestockRows.map((l) => {...l, 'registration_id': registrationId}).toList(),
        );
      }
    } catch (e) {
      print('Error submitting farmer registration: $e');
      rethrow;
    }
  }

  /// Get farmer registration status
  static Future<Map<String, dynamic>?> getFarmerRegistration(
    String userId,
  ) async {
    try {
      final response = await _client
          .from('farmer_registrations')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return response;
    } catch (e) {
      print('Error fetching farmer registration: $e');
      return null;
    }
  }
}
