// ============================================================================
// lib/shared/services/farmer/farmer_service.dart
// Farmer profile and registration operations
// ============================================================================

import 'package:flutter/foundation.dart' show debugPrint;
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
      final response = await _supabase
          .from('v_farmer_profiles')
          .select()
          .eq('is_verified', true)
          .limit(limit)
          .order('created_at', ascending: false);

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
          .from('v_farmer_profiles')
          .select()
          .eq('user_id', userId)
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

      final response = await _supabase
          .from('farmer_profiles')
          .insert({
            'user_id': userId,
            'farm_name': farmName,
            'specialty': specialty,
            'location': location,
            'image_url': imageUrl,
            'is_verified': false,
          })
          .select()
          .single();

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
          .from('farmer_profiles')
          .update({
            if (farmName != null) 'farm_name': farmName,
            if (specialty != null) 'specialty': specialty,
            if (location != null) 'location': location,
            if (imageUrl != null) 'image_url': imageUrl,
            if (badge != null) 'badge': badge,
          })
          .eq('user_id', userId)
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

      final farmer = await _supabase
          .from('farmers')
          .select('''
            farmer_id, user_id, birth_date, years_of_experience,
            residential_address, face_photo_path, valid_id_path,
            farming_history, is_active, created_at, updated_at
          ''')
          .eq('user_id', userId)
          .maybeSingle();

      if (farmer == null) return null;

      String status = 'pending';

      // Get status from farmer_registrations table
      final registration = await _supabase
          .from('farmer_registrations')
          .select('status')
          .eq('farmer_id', farmer['farmer_id'])
          .order('created_at', ascending: false)
          .maybeSingle();

      if (registration != null) {
        final dbStatus =
            (registration['status'] as String?)?.toLowerCase() ?? 'pending';
        if (dbStatus == 'approved' || dbStatus == 'rejected') {
          status = dbStatus;
        }
      }
      if (farmer['is_active'] == false) {
        status = 'rejected';
      }

      return FarmerRegistration.fromJson({
        'registrationId': farmer['farmer_id'],
        'userId': farmer['user_id'],
        'birthDate': farmer['birth_date']?.toString(),
        'yearsOfExperience': farmer['years_of_experience'],
        'residentialAddress': farmer['residential_address'],
        'facePhotoPath': farmer['face_photo_path'],
        'validIdPath': farmer['valid_id_path'],
        'farmingHistory': farmer['farming_history'],
        'certificationAccepted': true,
        'status': status,
        'createdAt': farmer['created_at'],
        'updatedAt': farmer['updated_at'],
      });
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

      // Create farmer record
      final farmerResponse = await _supabase
          .from('farmers')
          .upsert({
            'user_id': userId,
            'farm_name': 'My Farm',
            'birth_date': birthDate,
            'years_of_experience': yearsOfExperience,
            'residential_address': residentialAddress,
            'face_photo_path': facePhotoPath,
            'valid_id_path': validIdPath,
            'farming_history': farmingHistory,
            'is_active': true,
            'is_verified': false,
          })
          .select('''
            farmer_id, user_id, birth_date, years_of_experience,
            residential_address, face_photo_path, valid_id_path,
            farming_history, created_at, updated_at
          ''')
          .single();

      // Create registration record
      await _supabase.from('farmer_registrations').upsert({
        'farmer_id': farmerResponse['farmer_id'],
        'status': 'pending',
      });

      return FarmerRegistration.fromJson({
        'registrationId': farmerResponse['farmer_id'],
        'userId': farmerResponse['user_id'],
        'birthDate': farmerResponse['birth_date']?.toString(),
        'yearsOfExperience': farmerResponse['years_of_experience'],
        'residentialAddress': farmerResponse['residential_address'],
        'facePhotoPath': farmerResponse['face_photo_path'],
        'validIdPath': farmerResponse['valid_id_path'],
        'farmingHistory': farmerResponse['farming_history'],
        'certificationAccepted': certificationAccepted,
        'status': 'pending',
        'createdAt': farmerResponse['created_at'],
        'updatedAt': farmerResponse['updated_at'],
      });
    } catch (e) {
      throw Exception('Failed to create registration: $e');
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
        'farmer_id': registrationId,
        'degree': level,
        'institution': schoolName,
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
        'farmer_id': registrationId,
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
        'farmer_id': registrationId,
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
          .from('v_farmer_profiles')
          .select()
          .ilike('farm_name', '%\$query%')
          .eq('is_verified', true)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => FarmerProfile.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to search farmers: $e');
    }
  }

  /// Get summary stats for the farmer dashboard
  Future<Map<String, dynamic>> getFarmerStats() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final farmer = await _supabase
          .from('farmers')
          .select('farmer_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (farmer == null) {
        return {
          'totalRevenue': 0.0,
          'activeListings': 0,
          'yearlySales': 0.0,
          'revenueTrend': '0%',
          'listingsTrend': '0%',
        };
      }

      final farmerId = farmer['farmer_id'] as String;

      // 1. Get Active Listings count
      final productsResponse = await _supabase
          .from('products')
          .select('product_id')
          .eq('farmer_id', farmerId);
      final activeListings = (productsResponse as List).length;

      // 2. Get Total Revenue
      // We'll sum total_amount from orders. 
      // Status 'completed' or status that implies payment received.
      final ordersResponse = await _supabase
          .from('orders')
          .select('total_amount')
          .eq('farmer_id', farmerId)
          .not('order_status_id', 'eq', 5); // Assuming 5 is cancelled, let's be more specific if possible.
      
      // Actually, let's use the view v_orders if it exists and has status text
      double totalRevenue = 0;
      final orders = ordersResponse as List<dynamic>;
      for (var order in orders) {
        totalRevenue += (order['total_amount'] as num?)?.toDouble() ?? 0;
      }

      // 3. Get Yearly Sales (sales in the current year)
      final now = DateTime.now();
      final startOfYear = DateTime(now.year, 1, 1).toIso8601String();
      final yearlyOrdersResponse = await _supabase
          .from('orders')
          .select('total_amount')
          .eq('farmer_id', farmerId)
          .gte('created_at', startOfYear);
      
      double yearlySales = 0;
      final yearlyOrders = yearlyOrdersResponse as List<dynamic>;
      for (var order in yearlyOrders) {
        yearlySales += (order['total_amount'] as num?)?.toDouble() ?? 0;
      }

      return {
        'totalRevenue': totalRevenue,
        'activeListings': activeListings,
        'yearlySales': yearlySales,
        'revenueTrend': '+0%', // Trends would require historical data comparison
        'listingsTrend': '0%',
      };
    } catch (e) {
      debugPrint('Error fetching farmer stats: $e');
      return {
        'totalRevenue': 0.0,
        'activeListings': 0,
        'yearlySales': 0.0,
        'revenueTrend': '0%',
        'listingsTrend': '0%',
      };
    }
  }
}
