import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/farmer_registration.dart';

/// Supabase Configuration & Initialization
///
/// To use this, you need to:
/// 1. Create a Supabase account at https://supabase.com
/// 2. Create a new project
/// 3. Get your API URL and Anon Key from Project Settings
/// 4. Replace SUPABASE_URL and SUPABASE_ANON_KEY below
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String _requiredEnv(String key) {
    final value = dotenv.env[key]?.trim();
    if (value == null || value.isEmpty) {
      throw StateError('Missing required environment variable: $key');
    }
    return value;
  }

  static String get supabaseUrl => _requiredEnv('SUPABASE_URL');

  static String get supabaseAnonKey => _requiredEnv('SUPABASE_ANON_KEY');
  // ========================================================================

  /// Initialize Supabase - call this in main() before runApp()
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      realtimeClientOptions: RealtimeClientOptions(
        logLevel: kReleaseMode ? RealtimeLogLevel.error : RealtimeLogLevel.info,
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
    bool emailVerified = false,
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
          'email_verified': emailVerified,
          'created_at': DateTime.now().toIso8601String(),
        };
        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          userData['phone'] = phoneNumber;
        }
        await _client.from('users').insert(userData);
        debugPrint('✅ User inserted successfully');

        // Auto-create customer profile
        debugPrint('🔵 Creating customer profile...');
        await _client.from('customers').insert({
          'user_id': userId,
          'is_active': true,
        });
        debugPrint('✅ Customer profile created');

        // Auto-assign customer role in user_roles table
        try {
          await addUserRole(userId: userId, roleName: 'customer');
          debugPrint('✅ Customer role assigned in user_roles');
        } catch (e) {
          debugPrint('⚠️ Warning: Failed to assign customer role: $e');
        }

        // Auto-create admin if this is an admin email
        if (email == 'noreplyagridirect@gmail.com') {
          debugPrint('🔵 Creating admin profile for admin email...');
          await _client.from('admins').insert({
            'user_id': userId,
            'role_level': 3,
            'is_active': true,
          });
          debugPrint('✅ Admin profile created');

          // Auto-assign admin role in user_roles table
          try {
            await addUserRole(userId: userId, roleName: 'admin');
            debugPrint('✅ Admin role assigned in user_roles');
          } catch (e) {
            debugPrint('⚠️ Warning: Failed to assign admin role: $e');
          }
        }
      } else if (emailVerified) {
        await _client
            .from('users')
            .update({'email_verified': true})
            .eq('user_id', userId);
        debugPrint('✅ Existing user marked as email verified');
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
      debugPrint('Error creating user: $e');
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
      debugPrint('Error updating user name: $e');
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
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Error fetching user: $e');
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
      debugPrint('Error fetching user by email: $e');
      return null;
    }
  }

  /// Add role to user ('seller' = create farmer profile, 'admin' = create admin profile)
  static Future<void> addUserRole({
    required String userId,
    required String roleName,
  }) async {
    try {
      // 1. Get the role_id from the roles table first
      final roleData = await _client
          .from('roles')
          .select('role_id')
          .eq('name', roleName)
          .maybeSingle();

      if (roleData != null) {
        final roleId = roleData['role_id'];
        // 2. Insert into user_roles table (using ON CONFLICT DO NOTHING just in case)
        await _client.from('user_roles').upsert({
          'user_id': userId,
          'role_id': roleId,
        });
      }

      // 3. Profile-specific table creation (Legacy/Profile support)
      if (roleName == 'seller' || roleName == 'farmer') {
        // Create farmer record for this user (farm_name is required)
        final exists = await _client
            .from('farmers')
            .select('farmer_id')
            .eq('user_id', userId)
            .maybeSingle();
        if (exists == null) {
          final farmerResponse = await _client
              .from('farmers')
              .insert({
                'user_id': userId,
                'farm_name': 'My Farm', // Default farm name
              })
              .select('farmer_id')
              .single();

          // Create registration record with pending status
          await _client.from('farmer_registrations').insert({
            'farmer_id': farmerResponse['farmer_id'],
            'status': 'pending',
          });
        }
      } else if (roleName == 'admin') {
        // Create admin record for this user
        final exists = await _client
            .from('admins')
            .select('admin_id')
            .eq('user_id', userId)
            .maybeSingle();
        if (exists == null) {
          await _client.from('admins').insert({
            'user_id': userId,
            'role_level': 1, // Default moderator level
          });
        }
      }
    } catch (e) {
      debugPrint('Error adding user role: $e');
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
      debugPrint('Error removing user role: $e');
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
      debugPrint('Error checking user role: $e');
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
      if (email != 'noreplyagridirect@gmail.com') {
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

        // Also ensure role is in user_roles
        try {
          await addUserRole(userId: userId, roleName: 'admin');
          debugPrint('✅ Admin role assigned in user_roles');
        } catch (e) {
          debugPrint('⚠️ Warning: Failed to assign admin role: $e');
        }
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
      final response =
          await _client.rpc(
                'get_user_roles',
                params: {'checked_user_id': userId},
              )
              as List<dynamic>;

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
      debugPrint(
        '   1. Make sure get_user_roles() function exists in database',
      );
      debugPrint('   2. Run GET_USER_ROLES_FUNCTION.sql from lib/shared/data/');
      debugPrint(
        '   3. Check function definition: SELECT * FROM information_schema.routines WHERE routine_name=\'get_user_roles\'',
      );
      return ['consumer']; // Default to consumer role if any error
    }
  }

  /// Submit farmer registration using comprehensive RPC function
  /// Includes registration, education, crops, and livestock in single atomic transaction
  static Future<void> submitFarmerRegistration({
    required String userId,
    required FarmerRegistration registration,
    Uint8List? faceImageBytes, // For Web
    Uint8List? idImageBytes, // For Web
    Uint8List? idBackImageBytes, // For Web
  }) async {
    try {
      final yearsOfExp = int.tryParse(registration.yearsOfExperience) ?? 0;

      // 1. Upload Images to Storage (if present)
      String? faceUrl = registration.facePhotoPath;
      String? idUrl = registration.validIdPath;

      if (registration.facePhotoPath != null || faceImageBytes != null) {
        faceUrl = await _uploadImage(
          bucket: 'registrations',
          path:
              'face_scans/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
          localPath: registration.facePhotoPath,
          bytes: faceImageBytes,
        );
      }

      if (registration.validIdPath != null || idImageBytes != null) {
        idUrl = await _uploadImage(
          bucket: 'registrations',
          path:
              'valid_ids/${userId}_${DateTime.now().millisecondsSinceEpoch}_front.jpg',
          localPath: registration.validIdPath,
          bytes: idImageBytes,
        );
      }

      String? idBackUrl = registration.validIdBackPath;
      if (registration.validIdBackPath != null || idBackImageBytes != null) {
        idBackUrl = await _uploadImage(
          bucket: 'registrations',
          path:
              'valid_ids/${userId}_${DateTime.now().millisecondsSinceEpoch}_back.jpg',
          localPath: registration.validIdBackPath,
          bytes: idBackImageBytes,
        );
      }

      // Prepare education rows as JSONB
      final educationList = registration.toEducationRows();
      final educationJsonb = educationList.isEmpty
          ? <Map<String, dynamic>>[]
          : educationList.cast<Map<String, dynamic>>();

      // Prepare crop rows as JSONB
      final cropList = registration.toCropTypeRows();
      final cropJsonb = cropList.isEmpty
          ? <Map<String, dynamic>>[]
          : cropList.cast<Map<String, dynamic>>();

      // Prepare livestock rows as JSONB
      final livestockList = registration.toLivestockRows();
      final livestockJsonb = livestockList.isEmpty
          ? <Map<String, dynamic>>[]
          : livestockList.cast<Map<String, dynamic>>();

      // Call comprehensive RPC function
      // NOTE: We try to include identity fields in RPC, but if they fail (parameter mismatch),
      // we will handle it in the catch block and use the fallback updates.
      final Map<String, dynamic> rpcParams = {
        'p_user_id': userId,
        'p_birth_date': registration.birthDate,
        'p_years_of_experience': yearsOfExp,
        'p_residential_address': registration.residentialAddress,
        'p_farm_name': registration.farmName,
        'p_specialty': registration.specialty,
        'p_farm_latitude': registration.farmLatitude,
        'p_farm_longitude': registration.farmLongitude,
        'p_face_photo_path': faceUrl,
        'p_valid_id_path': idUrl,
        'p_valid_id_back_path': idBackUrl, // Added
        'p_farming_history': registration.farmingHistory,
        'p_education_rows': educationJsonb,
        'p_crop_rows': cropJsonb,
        'p_livestock_rows': livestockJsonb,
      };

      final rpcParamVariants = <Map<String, dynamic>>[
        rpcParams,
        // Backward-compat variant for deployments where the RPC does not
        // include p_valid_id_back_path yet.
        Map<String, dynamic>.from(rpcParams)..remove('p_valid_id_back_path'),
        // Legacy variant for deployments before farm pin coordinates were added.
        (Map<String, dynamic>.from(rpcParams)..remove('p_valid_id_back_path'))
          ..remove('p_farm_latitude')
          ..remove('p_farm_longitude'),
      ];

      dynamic response;
      PostgrestException? lastRpcSchemaError;

      for (final params in rpcParamVariants) {
        try {
          response = await _client.rpc(
            'submit_complete_farmer_registration',
            params: params,
          );
          lastRpcSchemaError = null;
          break;
        } on PostgrestException catch (e) {
          // PGRST202 means function signature couldn't be resolved in schema cache.
          if (e.code == 'PGRST202') {
            lastRpcSchemaError = e;
            continue;
          }
          rethrow;
        }
      }

      if (lastRpcSchemaError != null) {
        throw lastRpcSchemaError;
      }

      final result = response is List
          ? (response.isNotEmpty ? response[0] : {})
          : response;
      if (result is! Map<String, dynamic>) {
        throw Exception('Invalid response from RPC');
      }

      final success = result['success'] as bool? ?? false;
      if (!success) {
        throw Exception(result['message'] ?? 'Registration failed');
      }

      final registrationId = result['registration_id'];
      if (registrationId == null) {
        throw Exception('No registration ID returned');
      }

      // 2. Update identity fields (best-effort, schema-safe)
      // Keep this resilient to schema drift so valid fields still persist.
      try {
        final farmerIdentityVariants = <Map<String, dynamic>>[
          {
            'id_type': registration.idType,
            'sex': registration.sex,
            'place_of_birth': registration.placeOfBirth,
            'pcn': registration.pcn,
            'valid_id_path': idUrl,
            'valid_id_back_path': idBackUrl,
          },
          {
            'id_type': registration.idType,
            'sex': registration.sex,
            'place_of_birth': registration.placeOfBirth,
            'pcn': registration.pcn,
            'valid_id_path': idUrl,
          },
          {
            'id_type': registration.idType,
            'sex': registration.sex,
            'place_of_birth': registration.placeOfBirth,
            'pcn': registration.pcn,
          },
        ];

        Object? lastIdentityError;
        var farmerIdentitySynced = false;

        for (final payload in farmerIdentityVariants) {
          try {
            await _client.from('farmers').update(payload).eq('user_id', userId);
            farmerIdentitySynced = true;
            break;
          } catch (e) {
            lastIdentityError = e;
          }
        }

        if (!farmerIdentitySynced && lastIdentityError != null) {
          debugPrint('⚠️ Farmer identity sync warning: $lastIdentityError');
        }

        // Keep legal/display name in users table; farmers.full_name may not exist.
        final displayName = registration.fullName.trim();
        if (displayName.isNotEmpty) {
          try {
            await _client
                .from('farmer_registrations')
                .update({'full_name': displayName})
                .eq('registration_id', registrationId);
          } catch (e) {
            debugPrint('⚠️ Registration name sync warning: $e');
          }

          await _client
              .from('users')
              .update({'name': displayName})
              .eq('user_id', userId);
        }

        debugPrint('✅ Identity fields synced for $userId');
      } catch (e) {
        debugPrint('⚠️ Identity sync warning: $e');
      }

      debugPrint('✅ Registration submitted: $registrationId');
    } catch (e) {
      debugPrint('❌ Registration error: $e');
      rethrow;
    }
  }

  /// Normalize registration status text to known values.
  static String _normalizeRegistrationStatus(String? status) {
    final value = (status ?? '').trim().toLowerCase();
    if (value == 'approved' || value == 'rejected' || value == 'pending') {
      return value;
    }
    return 'pending';
  }

  /// Get farmer registration
  static Future<Map<String, dynamic>?> getFarmerRegistration(
    String userId,
  ) async {
    try {
      // First get the farmer_id from farmers table
      final farmer = await _client
          .from('farmers')
          .select(
            'farmer_id, user_id, is_verified, is_active, created_at, updated_at',
          )
          .eq('user_id', userId)
          .maybeSingle();

      if (farmer == null) return null;

      final farmerId = farmer['farmer_id'] as String;

      // Get the latest registration record
      final registration = await _client
          .from('farmer_registrations')
          .select('registration_id, status')
          .eq('farmer_id', farmerId)
          .order('created_at', ascending: false)
          .maybeSingle();

      String status = 'pending';
      String? registrationId = farmer['farmer_id'];

      if (registration != null) {
        registrationId = registration['registration_id'] as String?;
        status = _normalizeRegistrationStatus(
          registration['status']?.toString(),
        );
      }

      // Note: Do NOT override status based on is_active flag.
      // is_active is for account state, not approval state.
      // Use farmer_registrations.status to determine if approved/pending/rejected.

      return {
        'registration_id': registrationId,
        'farmer_id': farmer['farmer_id'],
        'user_id': farmer['user_id'],
        'status': status,
        'is_verified': farmer['is_verified'],
        'is_active': farmer['is_active'],
        'created_at': farmer['created_at'],
        'updated_at': farmer['updated_at'],
      };
    } catch (e) {
      debugPrint('Error fetching farmer registration: $e');
      return null;
    }
  }

  /// Watch the current farmer registration status and emit updates from Supabase realtime.
  static Stream<String?> watchFarmerRegistrationStatus(String userId) {
    if (userId.isEmpty) {
      return Stream<String?>.value(null);
    }

    return (() async* {
      final prefs = await SharedPreferences.getInstance();
      final cachedStatus = prefs.getString('registration_status_$userId');

      final connectivity = Connectivity();
      final connectivityResult = await connectivity.checkConnectivity();
      final isOnline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;

      if (!isOnline) {
        yield cachedStatus;
        return;
      }

      // Realtime subscriptions can time out on unstable networks. Polling keeps
      // status updates reliable for both mobile and web profile screens.
      String? lastStatus;
      var isFirstEmission = true;

      while (true) {
        try {
          final registration = await getFarmerRegistration(userId);
          final currentStatus = registration?['status'] as String?;

          if (isFirstEmission || currentStatus != lastStatus) {
            lastStatus = currentStatus;
            isFirstEmission = false;
            yield currentStatus;
          }
        } catch (e) {
          debugPrint('Registration status polling error: $e');
        }

        await Future<void>.delayed(const Duration(seconds: 8));
      }
    })();
  }

  /// Get farmer profile (from farmers table - approved farmers only)
  static Future<Map<String, dynamic>?> getFarmerProfile(String userId) async {
    try {
      // Get farmer profile directly from farmers table (approved farmers)
      final response = await _client
          .from('farmers')
          .select('''
            farmer_id, user_id, farm_name, specialty, location,
            face_photo_path, valid_id_path, valid_id_back_path, years_of_experience,
            residential_address, farming_history, birth_date,
            id_type, full_name, sex, place_of_birth, pcn,
            is_verified, is_active, created_at, updated_at
          ''')
          .eq('user_id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Error fetching farmer profile: $e');
      return null;
    }
  }

  /// Private helper for storage uploads (Handles Mobile & Web)
  static Future<String?> _uploadImage({
    required String bucket,
    required String path,
    String? localPath,
    Uint8List? bytes,
  }) async {
    try {
      if (kIsWeb) {
        if (bytes == null) return null;
        await _client.storage
            .from(bucket)
            .uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: true,
              ),
            );
      } else {
        if (localPath == null) return null;
        final file = File(localPath);
        if (!await file.exists()) return null;
        await _client.storage
            .from(bucket)
            .upload(
              path,
              file,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: true,
              ),
            );
      }

      // Get Public URL
      // 6. Return the bucket-prefixed path (required for getSignedUrl and _getPublicUrl)
      return '$bucket/$path';
    } catch (e) {
      debugPrint('🔴 Storage Upload Error: $e');
      return null;
    }
  }

  /// Get a safe URL for an image (handles signed URLs for potentially private buckets)
  static Future<String> getSafeUrl(
    String? path, {
    String? defaultBucket,
  }) async {
    if (path == null || path.isEmpty) return '';

    String bucket = defaultBucket ?? 'uploads';
    String fileName = path;

    // If it's already a full HTTP URL, check if it's a Supabase storage URL
    if (path.startsWith('http')) {
      if (!path.contains('supabase.co/storage/v1/object/')) {
        return path; // External URL, return as is
      }

      // Parse Supabase URL: https://.../storage/v1/object/public/bucket/path/to/file
      try {
        final uri = Uri.parse(path);
        final segments = uri.pathSegments;
        int objectIndex = segments.indexOf('object');
        if (objectIndex != -1 && segments.length > objectIndex + 2) {
          bucket = segments[objectIndex + 2];
          fileName = segments.sublist(objectIndex + 3).join('/');
        } else {
          return path; // Can't parse, return original
        }
      } catch (e) {
        return path;
      }
    } else {
      // It's a relative path, check if it contains the bucket
      final parts = path.split('/');
      if (parts.length >= 2) {
        if (defaultBucket == null || parts[0] == defaultBucket) {
          // Assume first part is bucket or strip redundant bucket
          bucket = parts[0];
          fileName = parts.sublist(1).join('/');
        }
      }
    }

    try {
      // Try to get a signed URL (valid for 1 hour)
      return await _client.storage.from(bucket).createSignedUrl(fileName, 3600);
    } catch (e) {
      // Fallback: If 'farmer-documents' failed, try 'registrations'
      if (bucket == 'farmer-documents') {
        try {
          return await _client.storage.from('registrations').createSignedUrl(fileName, 3600);
        } catch (_) {}
      }
      // Fallback: If 'registrations' failed, try 'farmer-documents'
      if (bucket == 'registrations') {
        try {
          return await _client.storage.from('farmer-documents').createSignedUrl(fileName, 3600);
        } catch (_) {}
      }
      
      debugPrint('Error generating signed URL for $path: $e');
      // Fallback to public URL if signed fails
      return _client.storage.from(bucket).getPublicUrl(fileName);
    }
  }
}
