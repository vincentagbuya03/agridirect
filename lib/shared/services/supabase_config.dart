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
  }) async {
    try {
      // Check if user already exists (trigger may have already inserted)
      final existing = await _client
          .from('users')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (existing == null) {
        // User doesn't exist yet, insert now
        await _client.from('users').insert({
          'id': userId,
          'email': email,
          'name': name,
          'is_seller': false,
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        // User exists from trigger but name might be empty, update it
        await _client.from('users').update({'name': name}).eq('id', userId);
      }
    } catch (e) {
      debugPrint('Error creating/updating user: $e');
      // Don't rethrow — the DB trigger should handle user creation
      // This is just a fallback, so we don't want it to break registration
    }
  }

  /// Users table operations (legacy - use createUserIfNotExists instead)
  static Future<void> createUser({
    required String userId,
    required String email,
    required String name,
  }) async {
    try {
      await _client.from('users').insert({
        'id': userId,
        'email': email,
        'name': name,
        'is_seller': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  /// Get user profile
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      return response;
    } catch (e) {
      print('Error fetching user: $e');
      return null;
    }
  }

  /// Update seller status
  static Future<void> updateSellerStatus({
    required String userId,
    required bool isSeller,
  }) async {
    try {
      await _client
          .from('users')
          .update({'is_seller': isSeller})
          .eq('id', userId);
    } catch (e) {
      print('Error updating seller status: $e');
      rethrow;
    }
  }

  /// Submit farmer registration
  static Future<void> submitFarmerRegistration({
    required String userId,
    required FarmerRegistration registration,
  }) async {
    try {
      final data = registration.toJson();
      data['user_id'] = userId;
      await _client.from('farmer_registrations').insert(data);
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
