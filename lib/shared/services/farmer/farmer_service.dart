// ============================================================================
// lib/shared/services/farmer/farmer_service.dart
// Farmer profile and registration operations
// ============================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/farmer/farmer_profile_model.dart';
import '../../models/farmer/farmer_registration_model.dart';

class FarmerService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================================
  // FARMER PROFILES OPERATIONS
  // ============================================================================

  /// Get all verified farmer profiles
  Future<List<FarmerProfile>> getVerifiedFarmers({int limit = 20}) async {
    try {
      final response = await _supabase.rpc(
        'get_verified_farmers',
        params: {'p_limit': limit},
      );

      return (response as List<dynamic>)
          .map((json) => FarmerProfile.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch farmers: \$e');
    }
  }

  /// Get farmer profile by user ID
  Future<FarmerProfile?> getFarmerProfile(String userId) async {
    try {
      final response = await _supabase
          .from('farmers')
          .select()
          .eq('farmer_id', userId)
          .single();

      return FarmerProfile.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Create farmer profile
  Future<FarmerProfile> createFarmerProfile({
    required String farmName,
    String? specialty,
    String? location,
    String? imageUrl,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase.from('farmers').insert({
        'farmer_id': userId,
        'farm_name': farmName,
        'specialty': specialty,
        'location': location,
        'image_url': imageUrl,
        'is_verified': false,
      }).select().single();

      return FarmerProfile.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create farmer profile: \$e');
    }
  }

  /// Update farmer profile
  Future<FarmerProfile> updateFarmerProfile({
    String? farmName,
    String? specialty,
    String? location,
    String? imageUrl,
    String? badge,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('farmers')
          .update({
            'farm_name': ?farmName,
            'specialty': ?specialty,
            'location': ?location,
            'image_url': ?imageUrl,
            'badge': ?badge,
          })
          .eq('farmer_id', userId)
          .select()
          .single();

      return FarmerProfile.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update farmer profile: \$e');
    }
  }

  // ============================================================================
  // FARMER REGISTRATIONS OPERATIONS
  // ============================================================================

  /// Get farmer registration
  Future<FarmerRegistration?> getFarmerRegistration() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('farmer_registrations')
          .select()
          .eq('user_id', userId)
          .single();

      return FarmerRegistration.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Create farmer registration
  Future<FarmerRegistration> createRegistration({
    required String birthDate,
    required int yearsOfExperience,
    required String residentialAddress,
    String? facePhotoPath,
    String? validIdPath,
    String? farmingHistory,
    required bool certificationAccepted,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase.from('farmer_registrations').insert({
        'user_id': userId,
        'birth_date': birthDate,
        'years_of_experience': yearsOfExperience,
        'residential_address': residentialAddress,
        'face_photo_path': facePhotoPath,
        'valid_id_path': validIdPath,
        'farming_history': farmingHistory,
        'certification_accepted': certificationAccepted,
        'status': 'pending',
      }).select().single();

      return FarmerRegistration.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create registration: \$e');
    }
  }

  /// Add education to registration
  Future<void> addEducation({
    required String registrationId,
    required String level,
    required String schoolName,
  }) async {
    try {
      await _supabase.from('farmer_education').insert({
        'registration_id': registrationId,
        'level': level,
        'school_name': schoolName,
      });
    } catch (e) {
      throw Exception('Failed to add education: \$e');
    }
  }

  /// Add crop type to registration
  Future<void> addCropType({
    required String registrationId,
    required String cropType,
  }) async {
    try {
      await _supabase.from('farmer_crop_types').insert({
        'registration_id': registrationId,
        'crop_type': cropType,
      });
    } catch (e) {
      throw Exception('Failed to add crop type: \$e');
    }
  }

  /// Add livestock to registration
  Future<void> addLivestock({
    required String registrationId,
    required String livestockType,
  }) async {
    try {
      await _supabase.from('farmer_livestock').insert({
        'registration_id': registrationId,
        'livestock_type': livestockType,
      });
    } catch (e) {
      throw Exception('Failed to add livestock: \$e');
    }
  }

  /// Search farmers
  Future<List<FarmerProfile>> searchFarmers(String query) async {
    try {
      final response = await _supabase
          .from('farmers')
          .select()
          .ilike('farm_name', '%\$query%')
          .eq('is_verified', true)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => FarmerProfile.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to search farmers: \$e');
    }
  }
}
