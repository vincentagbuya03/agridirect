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
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: RealtimeLogLevel.info,
      ),
    );

    // Listen for auth state changes to handle password reset
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        debugPrint('🔐 Password recovery event detected');
      }
    });
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
      debugPrint('🔵 createUserIfNotExists called');
      debugPrint('🔵 userId: $userId');
      debugPrint('🔵 email: $email');
      debugPrint('🔵 name: $name');
      debugPrint('🔵 phone: $phoneNumber');

      // Check if user already exists
      debugPrint('🔵 Checking if user exists...');
      final existing = await _client
          .from('users')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (existing == null) {
        debugPrint('🔵 User does not exist, inserting...');
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
        debugPrint('✅ User inserted successfully');

        // Auto-create customer profile
        debugPrint('🔵 Creating customer profile...');
        await _client.from('customers').insert({'user_id': userId});
        debugPrint('✅ Customer profile created');

        // Auto-create admin if this is an admin email
        if (email == 'noreplyagridirect@gmail.com' ||
            email == 'vincentagbuya3@gmail.com') {
          debugPrint('🔵 Creating admin profile for admin email...');
          await _client.from('admins').insert({
            'user_id': userId,
            'role_level': 3,
            'is_active': true,
          });
          debugPrint('✅ Admin profile created');
        }
      } else {
        debugPrint('🔵 User exists, updating name/phone...');
        // User exists but name/phone might be empty, update it
        final updateData = <String, String>{};
        if (name.isNotEmpty) {
          updateData['name'] = name;
        }
        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          updateData['phone'] = phoneNumber;
        }
        if (updateData.isNotEmpty) {
          debugPrint('🔵 Updating with data: $updateData');
          await _client.from('users').update(updateData).eq('user_id', userId);
          debugPrint('✅ User updated successfully');
        } else {
          debugPrint('✅ No updates needed');
        }
      }
    } catch (e, stack) {
      debugPrint('❌ Error creating/updating user: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('❌ Stack trace: $stack');
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

  /// Get user profile by userId
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

  /// Get user profile by email
  static Future<Map<String, dynamic>?> getUserProfileByEmail(
    String email,
  ) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();
      return response;
    } catch (e) {
      print('Error fetching user by email: $e');
      return null;
    }
  }

  /// Add role to user ('seller' = create farmer profile, 'admin' = create admin profile)
  static Future<void> addUserRole({
    required String userId,
    required String roleName,
  }) async {
    try {
      if (roleName == 'seller') {
        // Create farmer record for this user (farm_name is required)
        await _client.from('farmers').insert({
          'user_id': userId,
          'farm_name': 'My Farm', // Default farm name
        });
      } else if (roleName == 'admin') {
        // Create admin record for this user
        await _client.from('admins').insert({
          'user_id': userId,
          'role_level': 1, // Default moderator level
        });
      }
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
      if (roleName == 'seller') {
        // Delete farmer record for this user
        await _client.from('farmers').delete().eq('user_id', userId);
      } else if (roleName == 'admin') {
        // Delete admin record for this user
        await _client.from('admins').delete().eq('user_id', userId);
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
            .eq('user_id', userId)
            .maybeSingle();
        return response != null;
      } else if (roleName == 'admin') {
        final response = await _client
            .from('admins')
            .select('admin_id')
            .eq('user_id', userId)
            .maybeSingle();
        return response != null;
      }
      return false;
    } catch (e) {
      print('Error checking user role: $e');
      return false;
    }
  }

  /// Ensure admin profile exists for known admin emails
  /// Call this when a user logs in if they have an admin email
  static Future<void> ensureAdminProfileExists({
    required String userId,
    required String email,
  }) async {
    try {
      // Check if this email is a known admin email
      if (email != 'noreplyagridirect@gmail.com' &&
          email != 'vincentagbuya3@gmail.com') {
        return; // Not an admin email, skip
      }

      // Check if admin profile already exists
      final existing = await _client
          .from('admins')
          .select('admin_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (existing == null) {
        // Admin profile doesn't exist, create it
        debugPrint('🔵 Creating admin profile for known admin email: $email');
        await _client.from('admins').insert({
          'user_id': userId,
          'role_level': 3,
          'is_active': true,
        });
        debugPrint('✅ Admin profile created successfully');
      } else {
        debugPrint('✅ Admin profile already exists for: $email');
      }
    } catch (e) {
      debugPrint('❌ Error ensuring admin profile: $e');
      // Don't fail the login — admin will be fetched from DB regardless
    }
  }

  /// Get all roles for a user using secure stored function (bypasses RLS)
  static Future<List<String>> getUserRoles(String userId) async {
    try {
      debugPrint('🔵 getUserRoles called for userId: $userId');

      // Use stored function that bypasses RLS
      final response = await _client.rpc(
        'get_user_roles',
        params: {'checked_user_id': userId},
      ) as List<dynamic>;

      final roles = response
          .map((item) => (item as Map<String, dynamic>)['role_name'] as String)
          .toList();

      debugPrint('✅ getUserRoles returning: $roles');
      return roles;
    } catch (e, stackTrace) {
      debugPrint('❌ Error in getUserRoles: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      debugPrint('');
      debugPrint('🔧 TROUBLESHOOTING:');
      debugPrint('   1. Make sure get_user_roles() function exists in database');
      debugPrint('   2. Run GET_USER_ROLES_FUNCTION.sql from lib/shared/data/');
      debugPrint('   3. Check function definition: SELECT * FROM information_schema.routines WHERE routine_name=\'get_user_roles\'');
      return ['consumer']; // Default to consumer role if any error
    }
  }

  /// Submit farmer registration (inserts into farmer_registrations + decomposed tables)
  static Future<void> submitFarmerRegistration({
    required String userId,
    required FarmerRegistration registration,
  }) async {
    try {
      // Get farmer_id for this user
      final farmerRecord = await _client
          .from('farmers')
          .select('farmer_id')
          .eq('user_id', userId)
          .single();

      final farmerId = farmerRecord['farmer_id'];

      final data = registration.toJson();
      data['farmer_id'] = farmerId;
      final response = await _client
          .from('farmer_registrations')
          .insert(data)
          .select('registration_id')
          .single();
      final registrationId = response['registration_id'];

      // Insert education rows
      final educationRows = registration.toEducationRows();
      if (educationRows.isNotEmpty) {
        await _client
            .from('farmer_education')
            .insert(
              educationRows
                  .map((e) => {...e, 'registration_id': registrationId})
                  .toList(),
            );
      }

      // Insert crop type rows
      final cropRows = registration.toCropTypeRows();
      if (cropRows.isNotEmpty) {
        await _client
            .from('farmer_crop_types')
            .insert(
              cropRows
                  .map((c) => {...c, 'registration_id': registrationId})
                  .toList(),
            );
      }

      // Insert livestock rows
      final livestockRows = registration.toLivestockRows();
      if (livestockRows.isNotEmpty) {
        await _client
            .from('farmer_livestock')
            .insert(
              livestockRows
                  .map((l) => {...l, 'registration_id': registrationId})
                  .toList(),
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
      // First get farmer_id for this user
      final farmerRecord = await _client
          .from('farmers')
          .select('farmer_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (farmerRecord == null) return null;

      final farmerId = farmerRecord['farmer_id'];

      // Now get the registration
      final response = await _client
          .from('farmer_registrations')
          .select()
          .eq('farmer_id', farmerId)
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
