import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/farmer_registration.dart';

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
  /// Uses database function to bypass RLS issues
  static Future<void> createUserIfNotExists({
    required String userId,
    required String email,
    required String name,
    String? phoneNumber,
  }) async {
    try {
      // Call the database function which handles insert/update with proper permissions
      final result = await _client.rpc(
        'ensure_user_profile',
        params: {
          'p_user_id': userId,
          'p_email': email,
          'p_name': name,
          'p_phone': phoneNumber,
        },
      );

      if (result != true) {
        throw Exception('Failed to ensure user profile');
      }

      debugPrint('User profile ensured for $userId');
    } catch (e, stack) {
      debugPrint('Error creating/updating user: $e');
      debugPrint('Stack trace: $stack');
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
      await _client.from('users').update({'name': name}).eq('user_id', userId);
    } catch (e) {
      print('Error updating user name: $e');
    }
  }

  /// Check if an email is already registered.
  /// Uses a DB function to check auth.users (most reliable source).
  /// Falls back to checking public.users if the function is unavailable.
  static Future<bool> isEmailAlreadyRegistered(String email) async {
    // Primary check: use DB function that checks auth.users directly
    try {
      final result = await _client.rpc(
        'check_email_exists',
        params: {'check_email': email},
      );
      if (result == true) return true;
    } catch (_) {
      // Function not created yet — fall through to table check
    }

    // Fallback check: query public.users table
    try {
      final result = await _client
          .from('users')
          .select('user_id')
          .eq('email', email)
          .maybeSingle();
      return result != null;
    } catch (e) {
      debugPrint('Email check error: $e');
      return false;
    }
  }

  /// Check if a phone number is already registered in the users table
  /// Uses SECURITY DEFINER RPC to bypass RLS
  static Future<bool> isPhoneAlreadyRegistered(String phone) async {
    try {
      final result = await _client.rpc(
        'check_phone_exists',
        params: {'p_phone': phone},
      );
      return result == true;
    } catch (e) {
      debugPrint('Phone check error: $e');
      return false;
    }
  }

  /// Create a customer row in the customers table (if not already exists)
  /// Must be called AFTER createUserIfNotExists()
  /// Uses SECURITY DEFINER RPC to bypass RLS
  static Future<void> createCustomerIfNotExists(String userId) async {
    try {
      final result = await _client.rpc(
        'ensure_customer_row',
        params: {'p_user_id': userId},
      );
      if (result != true) {
        throw Exception('Failed to ensure customer row');
      }
      debugPrint('Customer row ensured for $userId');
    } catch (e) {
      debugPrint('Error creating customer row: $e');
      rethrow;
    }
  }

  /// Get user profile
  /// Uses SECURITY DEFINER RPC to bypass RLS
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _client.rpc(
        'get_user_profile',
        params: {'p_user_id': userId},
      );
      if (response == null) return null;
      // RPC returning TABLE gives a List
      if (response is List && response.isNotEmpty) {
        return Map<String, dynamic>.from(response.first as Map);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
    }
  }

  /// Add role to user ('seller' = create farmer profile, 'admin' = create admin profile)
  /// Uses SECURITY DEFINER RPC for seller; direct insert (non-fatal) for admin
  static Future<void> addUserRole({
    required String userId,
    required String roleName,
  }) async {
    try {
      if (roleName == 'seller') {
        // Use SECURITY DEFINER RPC to bypass RLS
        try {
          await _client.rpc('ensure_farmer_row', params: {'p_user_id': userId});
          debugPrint('Farmer role added for $userId');
        } catch (e) {
          debugPrint('Note: Could not create farmer row via RPC: $e');
        }
      } else if (roleName == 'admin') {
        // Try to create admin record for this user
        try {
          await _client.from('admins').insert({'admin_id': userId});
          debugPrint('Admin role added for $userId');
        } catch (e) {
          // RLS may block this — that's ok, continue anyway
          debugPrint('Note: Could not create admin row (RLS may block): $e');
        }
      }
    } catch (e) {
      debugPrint('Error adding user role: $e');
      // Don't rethrow - role addition is non-critical
    }
  }

  /// Remove role from user
  static Future<void> removeUserRole({
    required String userId,
    required String roleName,
  }) async {
    try {
      if (roleName == 'seller') {
        // Delete farmer record for this user
        await _client.from('farmers').delete().eq('farmer_id', userId);
      } else if (roleName == 'admin') {
        // Delete admin record for this user
        await _client.from('admins').delete().eq('admin_id', userId);
      }
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
      if (roleName == 'seller') {
        final response = await _client
            .from('farmers')
            .select('farmer_id')
            .eq('farmer_id', userId)
            .maybeSingle();
        return response != null;
      } else if (roleName == 'admin') {
        final response = await _client
            .from('admins')
            .select('admin_id')
            .eq('admin_id', userId)
            .maybeSingle();
        return response != null;
      }
      return false;
    } catch (e) {
      print('Error checking user role: $e');
      return false;
    }
  }

  /// Get all roles for a user (checks farmers, admins tables)
  /// Uses SECURITY DEFINER RPC to bypass RLS
  static Future<List<String>> getUserRoles(String userId) async {
    try {
      final result = await _client.rpc(
        'get_user_roles',
        params: {'p_user_id': userId},
      );
      if (result == null) return ['consumer'];
      if (result is List) {
        return result.map((e) => e.toString()).toList();
      }
      return ['consumer'];
    } catch (e) {
      debugPrint('Error fetching user roles: $e');
      return ['consumer'];
    }
  }

  /// Submit farmer registration (inserts into farmer_registrations + decomposed tables)
  /// Uses SECURITY DEFINER RPCs to bypass RLS for all table operations
  static Future<void> submitFarmerRegistration({
    required String userId,
    required FarmerRegistration registration,
  }) async {
    try {
      // Build livestock list from comma-separated string
      final livestockTypes = registration.livestock.isNotEmpty
          ? registration.livestock
                .split(',')
                .map((l) => l.trim())
                .where((l) => l.isNotEmpty)
                .toList()
          : <String>[];

      // Submit all registration data via SECURITY DEFINER RPC
      // NOTE: Does NOT create a farmers row — that only happens on admin approval
      await _client.rpc(
        'submit_farmer_registration',
        params: {
          'p_user_id': userId,
          'p_birth_date': registration.birthDate.isNotEmpty
              ? registration.birthDate
              : null,
          'p_years_of_experience':
              int.tryParse(registration.yearsOfExperience) ??
              int.tryParse(registration.yearsInFarming) ??
              0,
          'p_residential_address': registration.residentialAddress.isNotEmpty
              ? registration.residentialAddress
              : null,
          'p_face_photo_path': registration.facePhotoPath,
          'p_valid_id_path': registration.validIdPath,
          'p_farming_history': registration.farmingHistory.isNotEmpty
              ? registration.farmingHistory
              : null,
          'p_certification_accepted': registration.certificationAccepted,
          'p_crop_types': registration.cropTypes
              .where((c) => c.isNotEmpty)
              .toList(),
          'p_livestock_types': livestockTypes,
          'p_education_elementary': registration.elementary.isNotEmpty
              ? registration.elementary
              : null,
          'p_education_high_school': registration.highSchool.isNotEmpty
              ? registration.highSchool
              : null,
          'p_education_college': registration.college.isNotEmpty
              ? registration.college
              : null,
        },
      );

      debugPrint('Farmer registration submitted for $userId');
    } catch (e) {
      debugPrint('Error submitting farmer registration: $e');
      rethrow;
    }
  }

  /// Get farmer registration status for the current user
  static Future<Map<String, dynamic>?> getFarmerRegistration(
    String userId,
  ) async {
    try {
      // Use SECURITY DEFINER RPC to bypass RLS
      final response = await _client.rpc('get_my_farmer_registration');
      if (response == null || response is! List || response.isEmpty) {
        return null;
      }
      return Map<String, dynamic>.from(response.first as Map);
    } catch (e) {
      print('Error fetching farmer registration: $e');
      return null;
    }
  }

  /// Upload a file to Supabase Storage
  /// Returns the public URL of the uploaded file
  static Future<String?> uploadFarmerDocument({
    required String userId,
    required String filePath,
    required String documentType, // 'face_photo' or 'valid_id'
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }

      // Create unique filename
      final fileName =
          '$userId/${documentType}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload to Supabase Storage
      await _client.storage
          .from('farmer-documents')
          .upload(
            fileName,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      // Get public URL
      final publicUrl = _client.storage
          .from('farmer-documents')
          .getPublicUrl(fileName);

      debugPrint('File uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading file: $e');
      return null;
    }
  }

  /// Upload farmer registration with file uploads
  static Future<void> submitFarmerRegistrationWithFiles({
    required String userId,
    required FarmerRegistration registration,
  }) async {
    try {
      // Upload files first (if they exist)
      String? facePhotoUrl;
      String? validIdUrl;

      if (registration.facePhotoPath != null &&
          registration.facePhotoPath!.isNotEmpty) {
        facePhotoUrl = await uploadFarmerDocument(
          userId: userId,
          filePath: registration.facePhotoPath!,
          documentType: 'face_photo',
        );
      }

      if (registration.validIdPath != null &&
          registration.validIdPath!.isNotEmpty) {
        validIdUrl = await uploadFarmerDocument(
          userId: userId,
          filePath: registration.validIdPath!,
          documentType: 'valid_id',
        );
      }

      // Build livestock list from comma-separated string
      final livestockTypes = registration.livestock.isNotEmpty
          ? registration.livestock
                .split(',')
                .map((l) => l.trim())
                .where((l) => l.isNotEmpty)
                .toList()
          : <String>[];

      // Submit registration with uploaded URLs
      await _client.rpc(
        'submit_farmer_registration',
        params: {
          'p_user_id': userId,
          'p_birth_date': registration.birthDate.isNotEmpty
              ? registration.birthDate
              : null,
          'p_years_of_experience':
              int.tryParse(registration.yearsOfExperience) ??
              int.tryParse(registration.yearsInFarming) ??
              0,
          'p_residential_address': registration.residentialAddress.isNotEmpty
              ? registration.residentialAddress
              : null,
          'p_face_photo_path':
              facePhotoUrl, // Now a cloud URL instead of local path
          'p_valid_id_path':
              validIdUrl, // Now a cloud URL instead of local path
          'p_farming_history': registration.farmingHistory.isNotEmpty
              ? registration.farmingHistory
              : null,
          'p_certification_accepted': registration.certificationAccepted,
          'p_crop_types': registration.cropTypes
              .where((c) => c.isNotEmpty)
              .toList(),
          'p_livestock_types': livestockTypes,
          'p_education_elementary': registration.elementary.isNotEmpty
              ? registration.elementary
              : null,
          'p_education_high_school': registration.highSchool.isNotEmpty
              ? registration.highSchool
              : null,
          'p_education_college': registration.college.isNotEmpty
              ? registration.college
              : null,
        },
      );

      debugPrint('Farmer registration submitted with files for $userId');
    } catch (e) {
      debugPrint('Error submitting farmer registration with files: $e');
      rethrow;
    }
  }
}
