import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/farmer_registration.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase Configuration & Initialization
class SupabaseConfig {
  // Constants for baked-in environment variables (via --dart-define)
  static const String _urlEnv = String.fromEnvironment('SUPABASE_URL');
  static const String _keyEnv = String.fromEnvironment('SUPABASE_ANON_KEY');

  // Hardcoded fallbacks to ensure production stability
  static const String _fallbackUrl = 'https://ywfppgarzyksacgbesme.supabase.co';
  static const String _fallbackKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3ZnBwZ2Fyenlrc2FjZ2Jlc21lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3NzEzMjcsImV4cCI6MjA4NzM0NzMyN30.aX1HIacJsHV8gU-9tGONnDpucE9vePWOrJbgMR4fSzs';

  static String _sanitizeEnvValue(String raw) {
    var value = raw.trim();
    if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
      value = value.substring(1, value.length - 1);
    }
    value = value.replaceAll(r'\r', '').replaceAll(r'\n', '').trim();
    return value;
  }

  static bool _looksLikeValidUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        (uri.host.isNotEmpty);
  }

  static bool _looksLikeJwt(String value) {
    final parts = value.split('.');
    return parts.length == 3 && parts.every((part) => part.isNotEmpty);
  }

  static String _safeGetEnv(String key) {
    try {
      return dotenv.env[key] ?? '';
    } catch (_) {
      return '';
    }
  }

  static String get supabaseUrl {
    final url = _sanitizeEnvValue(_urlEnv);
    if (url.isNotEmpty && !url.contains(r'$') && _looksLikeValidUrl(url)) {
      return url;
    }

    final envValue = _sanitizeEnvValue(_safeGetEnv('SUPABASE_URL'));
    if (envValue.isNotEmpty &&
        !envValue.contains(r'$') &&
        _looksLikeValidUrl(envValue)) {
      return envValue;
    }

    return _fallbackUrl;
  }

  static String get supabaseAnonKey {
    final key = _sanitizeEnvValue(_keyEnv);
    if (key.isNotEmpty && !key.contains(r'$') && _looksLikeJwt(key)) {
      return key;
    }

    final envValue = _sanitizeEnvValue(_safeGetEnv('SUPABASE_ANON_KEY'));
    if (envValue.isNotEmpty &&
        !envValue.contains(r'$') &&
        _looksLikeJwt(envValue)) {
      return envValue;
    }

    return _fallbackKey;
  }

  static bool _initialized = false;

  /// Initialize Supabase - call this in main() before runApp()
  static Future<void> initialize() async {
    if (_initialized) {
      debugPrint('✅ Supabase already initialized (flag)');
      return;
    }

    try {
      final instance = Supabase.instance;
      // ignore: unnecessary_null_comparison
      final client = instance.client;
      if (client.rest.url.isNotEmpty) {
        _initialized = true;
        debugPrint('✅ Supabase already initialized (instance check)');
        return;
      }
    } catch (_) {
      // Proceed to initialize
    }

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
        realtimeClientOptions: RealtimeClientOptions(
          logLevel: kReleaseMode
              ? RealtimeLogLevel.error
              : RealtimeLogLevel.info,
        ),
      );
      _initialized = true;
      debugPrint('✅ Supabase initialized successfully');
    } catch (e) {
      if (e.toString().contains('already initialized') || e.toString().contains('has already been initialized')) {
        _initialized = true;
        debugPrint('✅ Supabase already initialized (caught exception)');
      } else {
        debugPrint('❌ Supabase initialization failed: $e');
        rethrow;
      }
    }

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
class SupabaseDatabase {
  static final _client = SupabaseConfig.client;

  /// Users table operations - creates user only if not already exists (safe for trigger + client)
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

      // 🔵 Always use upsert to avoid "duplicate key" errors in race conditions
      final userData = {
        'user_id': userId,
        'email': email,
        'name': name,
        'email_verified': emailVerified,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        userData['phone'] = phoneNumber;
      }

      debugPrint('🔵 Upserting user profile for $userId');
      await _client.from('users').upsert(userData, onConflict: 'user_id');

      // Ensure customer profile exists using upsert
      await _client.from('customers').upsert({
        'user_id': userId,
        'is_active': true,
      }, onConflict: 'user_id');

      // Auto-assign customer role
      try {
        await addUserRole(userId: userId, roleName: 'customer');
      } catch (e) {
        debugPrint('⚠️ Warning: Failed to assign customer role: $e');
      }

      // Auto-create admin if this is an admin email
      final cleanEmail = email.trim().toLowerCase();
      if (cleanEmail == 'noreplyagridirect@gmail.com') {
        await _client.from('admins').upsert({
          'user_id': userId,
          'role_level': 3,
          'is_active': true,
        }, onConflict: 'user_id');

        try {
          await addUserRole(userId: userId, roleName: 'admin');
        } catch (e) {
          debugPrint('⚠️ Warning: Failed to assign admin role: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Error creating/updating user: $e');
      rethrow;
    }
  }

  /// Legacy createUser
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

  static Future<bool> isEmailAlreadyRegistered(String email) async {
    try {
      final result = await _client
          .from('users')
          .select('user_id')
          .eq('email', email)
          .maybeSingle();
      return result != null;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> isPhoneAlreadyRegistered(String phone) async {
    try {
      final result = await _client
          .from('users')
          .select('user_id')
          .eq('phone', phone)
          .maybeSingle();
      return result != null;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) return null;
    try {
      return await _client
          .from('users')
          .select()
          .eq('user_id', cleanUserId)
          .maybeSingle();
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getUserProfileByEmail(
    String email,
  ) async {
    try {
      return await _client
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();
    } catch (e) {
      return null;
    }
  }

  static Future<void> addUserRole({
    required String userId,
    required String roleName,
  }) async {
    try {
      final roleData = await _client
          .from('roles')
          .select('role_id')
          .eq('name', roleName)
          .maybeSingle();
      if (roleData != null) {
        await _client.from('user_roles').upsert({
          'user_id': userId,
          'role_id': roleData['role_id'],
        });
      }

      if (roleName == 'seller' || roleName == 'farmer') {
        final exists = await _client
            .from('farmers')
            .select('farmer_id')
            .eq('user_id', userId)
            .maybeSingle();
        if (exists == null) {
          final farmerResponse = await _client
              .from('farmers')
              .insert({'user_id': userId, 'farm_name': 'My Farm'})
              .select('farmer_id')
              .single();

          await _client.from('farmer_registrations').insert({
            'farmer_id': farmerResponse['farmer_id'],
            'status': 'pending',
          });
        }
      } else if (roleName == 'admin') {
        final exists = await _client
            .from('admins')
            .select('admin_id')
            .eq('user_id', userId)
            .maybeSingle();
        if (exists == null) {
          await _client.from('admins').insert({
            'user_id': userId,
            'role_level': 1,
          });
        }
      }
    } catch (e) {
      debugPrint('Error adding user role: $e');
      rethrow;
    }
  }

  static Future<void> removeUserRole({
    required String userId,
    required String roleName,
  }) async {
    try {
      final cleanUserId = userId.trim();
      if (cleanUserId.isEmpty) return;
      if (roleName == 'seller') {
        await _client.from('farmers').delete().eq('user_id', cleanUserId);
      } else if (roleName == 'admin') {
        await _client.from('admins').delete().eq('user_id', cleanUserId);
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<bool> hasRole({
    required String userId,
    required String roleName,
  }) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) return false;
    try {
      if (roleName == 'seller') {
        final res = await _client
            .from('farmers')
            .select('farmer_id')
            .eq('user_id', cleanUserId)
            .maybeSingle();
        return res != null;
      } else if (roleName == 'admin') {
        final res = await _client
            .from('admins')
            .select('admin_id')
            .eq('user_id', cleanUserId)
            .maybeSingle();
        return res != null;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> ensureAdminProfileExists({
    required String userId,
    required String email,
  }) async {
    try {
      final cleanUserId = userId.trim();
      if (cleanUserId.isEmpty) return;
      final cleanEmail = email.trim().toLowerCase();
      if (cleanEmail != 'noreplyagridirect@gmail.com') return;

      final existing = await _client
          .from('admins')
          .select('admin_id')
          .eq('user_id', cleanUserId)
          .maybeSingle();
      if (existing == null) {
        await _client.from('admins').insert({
          'user_id': cleanUserId,
          'role_level': 3,
          'is_active': true,
        });
        await addUserRole(userId: cleanUserId, roleName: 'admin');
      }
    } catch (e) {
      debugPrint('Error ensuring admin profile: $e');
    }
  }

  static Future<List<String>> getUserRoles(String userId) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) return ['consumer'];
    try {
      final response =
          await _client.rpc(
                'get_user_roles',
                params: {'checked_user_id': cleanUserId},
              )
              as List<dynamic>;
      return response
          .map((item) => (item as Map<String, dynamic>)['role_name'] as String)
          .toList();
    } catch (e) {
      return ['consumer'];
    }
  }

  static Future<void> submitFarmerRegistration({
    required String userId,
    required FarmerRegistration registration,
    Uint8List? faceImageBytes,
    Uint8List? idImageBytes,
    Uint8List? idBackImageBytes,
    String? resolvedFarmLocation,
  }) async {
    try {
      final yearsOfExp = int.tryParse(registration.yearsOfExperience) ?? 0;
      String? faceUrl = registration.facePhotoPath;
      String? idUrl = registration.validIdPath;
      String? idBackUrl = registration.validIdBackPath;

      if (registration.facePhotoPath != null || faceImageBytes != null) {
        faceUrl = await uploadImage(
          bucket: 'registrations',
          path:
              'face_scans/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
          localPath: registration.facePhotoPath,
          bytes: faceImageBytes,
        );
      }

      if (registration.validIdPath != null || idImageBytes != null) {
        idUrl = await uploadImage(
          bucket: 'registrations',
          path:
              'valid_ids/${userId}_${DateTime.now().millisecondsSinceEpoch}_front.jpg',
          localPath: registration.validIdPath,
          bytes: idImageBytes,
        );
      }

      if (registration.validIdBackPath != null || idBackImageBytes != null) {
        idBackUrl = await uploadImage(
          bucket: 'registrations',
          path:
              'valid_ids/${userId}_${DateTime.now().millisecondsSinceEpoch}_back.jpg',
          localPath: registration.validIdBackPath,
          bytes: idBackImageBytes,
        );
      }

      final educationJsonb = registration
          .toEducationRows()
          .cast<Map<String, dynamic>>();
      final cropJsonb = registration
          .toCropTypeRows()
          .cast<Map<String, dynamic>>();
      final livestockJsonb = registration
          .toLivestockRows()
          .cast<Map<String, dynamic>>();

      final Map<String, dynamic> rpcParams = {
        'p_user_id': userId,
        'p_full_name': registration.fullName,
        'p_birth_date': registration.birthDate,
        'p_sex': registration.sex,
        'p_place_of_birth': registration.placeOfBirth,
        'p_pcn': registration.pcn,
        'p_id_type': registration.idType,
        'p_years_of_experience': yearsOfExp,
        'p_residential_address': registration.residentialAddress,
        'p_farm_name': registration.farmName,
        'p_specialty': registration.specialty,
        'p_farm_latitude': registration.farmLatitude,
        'p_farm_longitude': registration.farmLongitude,
        'p_face_photo_path': faceUrl,
        'p_valid_id_path': idUrl,
        'p_valid_id_back_path': idBackUrl,
        'p_farming_history': registration.farmingHistory,
        'p_education_rows': educationJsonb,
        'p_crop_rows': cropJsonb,
        'p_livestock_rows': livestockJsonb,
      };

      final response = await _client.rpc(
        'submit_complete_farmer_registration',
        params: rpcParams,
      );
      final result = response is List
          ? (response.isNotEmpty ? response[0] : {})
          : response;
      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'Registration failed');
      }

      final farmerProfileUpdates = <String, dynamic>{};
      final trimmedResolvedLocation = resolvedFarmLocation?.trim() ?? '';
      if (trimmedResolvedLocation.isNotEmpty) {
        farmerProfileUpdates['location'] = trimmedResolvedLocation;
      }
      if (faceUrl != null && faceUrl.trim().isNotEmpty) {
        farmerProfileUpdates['image_url'] = faceUrl.trim();
      }
      if (farmerProfileUpdates.isNotEmpty) {
        await _client
            .from('farmers')
            .update(farmerProfileUpdates)
            .eq('user_id', userId);
      }

      // Sync user display name if changed
      final displayName = registration.fullName.trim();
      if (displayName.isNotEmpty) {
        try {
          await _client
              .from('users')
              .update({'name': displayName})
              .eq('user_id', userId);
        } catch (e) {
          debugPrint('User name sync warning: $e');
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  static String _normalizeRegistrationStatus(String? status) {
    final value = (status ?? '').trim().toLowerCase();
    if (['approved', 'rejected', 'pending'].contains(value)) return value;
    return 'pending';
  }

  static Future<Map<String, dynamic>?> getFarmerRegistration(
    String userId,
  ) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) return null;
    try {
      final farmer = await _client
          .from('farmers')
          .select(
            'farmer_id, user_id, is_verified, is_active, created_at, updated_at',
          )
          .eq('user_id', cleanUserId)
          .maybeSingle();
      if (farmer == null) return null;

      final farmerId = farmer['farmer_id'] as String;
      final registration = await _client
          .from('farmer_registrations')
          .select('registration_id, status')
          .eq('farmer_id', farmerId)
          .order('created_at', ascending: false)
          .maybeSingle();

      String status = 'pending';
      String? registrationId = farmerId;
      if (registration != null) {
        registrationId = registration['registration_id'];
        status = _normalizeRegistrationStatus(registration['status']);
      }

      // If the farmer is already verified, treat the registration as approved
      // even if the latest farmer_registrations row is stale.
      if (farmer['is_verified'] == true) {
        status = 'approved';
      }

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
      return null;
    }
  }

  static Stream<String?> watchFarmerRegistrationStatus(String userId) {
    if (userId.isEmpty) return Stream.value(null);
    return (() async* {
      final prefs = await SharedPreferences.getInstance();
      String? lastStatus = prefs.getString('registration_status_$userId');
      var isFirst = true;

      while (true) {
        try {
          final registration = await getFarmerRegistration(userId);
          final currentStatus = registration?['status'] as String?;
          if (isFirst || currentStatus != lastStatus) {
            lastStatus = currentStatus;
            isFirst = false;
            if (currentStatus != null) {
              await prefs.setString(
                'registration_status_$userId',
                currentStatus,
              );
            }
            yield currentStatus;
          }
        } catch (_) {}
        await Future.delayed(const Duration(seconds: 8));
      }
    })();
  }

  static Future<Map<String, dynamic>?> getFarmerProfile(String userId) async {
    try {
      return await _client
          .from('farmers')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
    } catch (e) {
      return null;
    }
  }

  static Future<String?> uploadImage({
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
        final file = io.File(localPath);
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
      return '$bucket/$path';
    } catch (e) {
      return null;
    }
  }

  static Future<String> getSafeUrl(
    String? path, {
    String? defaultBucket,
  }) async {
    if (path == null || path.isEmpty) return '';
    String bucket = defaultBucket ?? 'uploads';
    String fileName = path;

    if (path.startsWith('http')) {
      if (!path.contains('supabase.co/storage/v1/object/')) return path;
      try {
        final uri = Uri.parse(path);
        final segments = uri.pathSegments;
        int objectIndex = segments.indexOf('object');
        if (objectIndex != -1 && segments.length > objectIndex + 2) {
          bucket = segments[objectIndex + 2];
          fileName = segments.sublist(objectIndex + 3).join('/');
        } else {
          return path;
        }
      } catch (_) {
        return path;
      }
    } else {
      final parts = path.split('/');
      if (parts.length >= 2) {
        bucket = parts[0];
        fileName = parts.sublist(1).join('/');
      }
    }

    try {
      return await _client.storage.from(bucket).createSignedUrl(fileName, 3600);
    } catch (e) {
      return _client.storage.from(bucket).getPublicUrl(fileName);
    }
  }

  /// Marketplace: Get all active categories
  static Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response = await _client
          .from('categories')
          .select('category_id, name, description')
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      return [];
    }
  }

  /// Marketplace: Get featured or all products
  static Future<List<Map<String, dynamic>>> getProducts({
    int limit = 10,
    String? categoryId,
    bool onlyFeatured = false,
  }) async {
    try {
      dynamic query = _client.from('v_products').select('''
        *,
        farmer:farmers (
          farmer_id,
          farm_name,
          user:users (name, avatar_url)
        )
      ''');

      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }

      query = query.limit(limit);

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching products: $e');
      return [];
    }
  }

  /// Marketplace: Get verified farmers for spotlight
  static Future<List<Map<String, dynamic>>> getFarmerSpotlight({
    int limit = 5,
  }) async {
    try {
      final response = await _client
          .from('farmers')
          .select('''
            farmer_id,
            farm_name,
            specialty,
            user:users (name, avatar_url)
          ''')
          .eq('is_verified', true)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching farmer spotlight: $e');
      return [];
    }
  }
}
