// ============================================================================
// lib/shared/services/farmer/farmer_service.dart
// Farmer profile and registration operations
// ============================================================================

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:intl/intl.dart';
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

  /// Get farmer profile by farmer ID
  Future<FarmerProfile?> getFarmerProfileByFarmerId(String farmerId) async {
    try {
      final response = await _supabase
          .from('v_farmer_profiles')
          .select()
          .eq('farmer_id', farmerId)
          .single();

      return FarmerProfile.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Get multiple farmer profiles by farmer IDs
  Future<List<FarmerProfile>> getFarmerProfilesByIds(List<String> farmerIds) async {
    if (farmerIds.isEmpty) return [];
    try {
      final response = await _supabase
          .from('v_farmer_profiles')
          .select()
          .inFilter('farmer_id', farmerIds);

      return (response as List<dynamic>)
          .map((json) => FarmerProfile.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting farmer profiles by ids: $e');
      return [];
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
            'farm_name': farmName,
            'specialty': specialty,
            'location': location,
            'image_url': imageUrl,
            'badge': badge,
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
          'followers': 0,
          'communityPosts': 0,
          'yearlySales': 0.0,
          'revenueTrend': '0%',
          'listingsTrend': '0%',
          'weeklyData': List.filled(7, 0.0),
        };
      }

      final farmerId = farmer['farmer_id'] as String;

      // 1. Get Active Listings count
      final productsResponse = await _supabase
          .from('products')
          .select('product_id')
          .eq('farmer_id', farmerId)
          .eq('is_active', true);
      final activeListings = (productsResponse as List).length;

      final followersResponse = await _supabase
          .from('farmer_follows')
          .select('follow_id')
          .eq('farmer_id', farmerId);
      final followers = (followersResponse as List).length;

      final postsResponse = await _supabase
          .from('forum_posts')
          .select('post_id')
          .eq('user_id', userId);
      final communityPosts = (postsResponse as List).length;

      // 2. Fetch Orders for the last 365 days (and previous period for trend)
      final now = DateTime.now();
      final oneYearAgo = DateTime(now.year - 1, now.month, now.day).toIso8601String();

      final ordersResponse = await _supabase
          .from('orders')
          .select('total_amount, created_at')
          .eq('farmer_id', farmerId)
          .gte('created_at', oneYearAgo)
          .not('order_status_id', 'in', '(5, 6)'); // Exclude cancelled/failed

      final orders = (ordersResponse as List<dynamic>?) ?? [];

      // =======================================================================
      // A. 7-DAY ANALYTICS
      // =======================================================================
      final sevenDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      final fourteenDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 13));

      List<double> data7D = List.filled(7, 0.0);
      List<int> orders7D = List.filled(7, 0);
      List<String> labels7D = [];
      List<String> dates7D = [];
      double rev7D = 0;
      double prevRev7D = 0;

      for (int i = 0; i < 7; i++) {
        final d = sevenDaysAgo.add(Duration(days: i));
        labels7D.add(DateFormat('E').format(d)); // 'Mon', 'Tue', etc.
        dates7D.add(DateFormat('MMM d').format(d)); // 'Aug 21'
      }

      // =======================================================================
      // B. 30-DAY ANALYTICS (5 x 6-day intervals)
      // =======================================================================
      final thirtyDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
      final sixtyDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 59));

      List<double> data30D = List.filled(5, 0.0);
      List<int> orders30D = List.filled(5, 0);
      List<String> labels30D = ['W1', 'W2', 'W3', 'W4', 'W5'];
      List<String> dates30D = [];
      double rev30D = 0;
      double prevRev30D = 0;

      for (int i = 0; i < 5; i++) {
        final startD = thirtyDaysAgo.add(Duration(days: i * 6));
        final endD = startD.add(const Duration(days: 5));
        dates30D.add('${DateFormat('MMM d').format(startD)} - ${DateFormat('d').format(endD)}');
      }

      // =======================================================================
      // C. 1-YEAR ANALYTICS (12 Months)
      // =======================================================================
      List<double> data1Y = List.filled(12, 0.0);
      List<int> orders1Y = List.filled(12, 0);
      List<String> labels1Y = [];
      List<String> dates1Y = [];
      double rev1Y = 0;

      for (int i = 11; i >= 0; i--) {
        final mDate = DateTime(now.year, now.month - i, 1);
        labels1Y.add(DateFormat('MMM').format(mDate)); // 'Jan', 'Feb', etc.
        dates1Y.add(DateFormat('MMMM yyyy').format(mDate));
      }

      // Populate buckets from orders
      for (final order in orders) {
        final createdAt = DateTime.tryParse(order['created_at']?.toString() ?? '');
        if (createdAt == null) continue;

        final amount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;

        // 7D logic
        if (!createdAt.isBefore(sevenDaysAgo)) {
          final dayIdx = createdAt.difference(sevenDaysAgo).inDays;
          if (dayIdx >= 0 && dayIdx < 7) {
            data7D[dayIdx] += amount;
            orders7D[dayIdx] += 1;
            rev7D += amount;
          }
        } else if (!createdAt.isBefore(fourteenDaysAgo)) {
          prevRev7D += amount;
        }

        // 30D logic
        if (!createdAt.isBefore(thirtyDaysAgo)) {
          final dayIdx = createdAt.difference(thirtyDaysAgo).inDays;
          final bucketIdx = (dayIdx / 6).floor().clamp(0, 4);
          data30D[bucketIdx] += amount;
          orders30D[bucketIdx] += 1;
          rev30D += amount;
        } else if (!createdAt.isBefore(sixtyDaysAgo)) {
          prevRev30D += amount;
        }

        // 1Y logic
        final monthsDiff = (now.year - createdAt.year) * 12 + (now.month - createdAt.month);
        if (monthsDiff >= 0 && monthsDiff < 12) {
          final bucketIdx = 11 - monthsDiff;
          if (bucketIdx >= 0 && bucketIdx < 12) {
            data1Y[bucketIdx] += amount;
            orders1Y[bucketIdx] += 1;
            rev1Y += amount;
          }
        }
      }

      // 3. Get Total Lifetime Revenue
      final lifetimeResponse = await _supabase
          .from('orders')
          .select('total_amount')
          .eq('farmer_id', farmerId)
          .not('order_status_id', 'in', '(5, 6)');

      double totalRevenue = 0;
      for (var order in (lifetimeResponse as List? ?? [])) {
        totalRevenue += (order['total_amount'] as num?)?.toDouble() ?? 0;
      }

      // Trend calculations
      String trend7D = '+0%';
      if (prevRev7D > 0) {
        final p = ((rev7D - prevRev7D) / prevRev7D * 100);
        trend7D = '${p >= 0 ? '+' : ''}${p.toStringAsFixed(1)}%';
      } else if (rev7D > 0) {
        trend7D = '+100%';
      }

      String trend30D = '+0%';
      if (prevRev30D > 0) {
        final p = ((rev30D - prevRev30D) / prevRev30D * 100);
        trend30D = '${p >= 0 ? '+' : ''}${p.toStringAsFixed(1)}%';
      } else if (rev30D > 0) {
        trend30D = '+100%';
      }

      return {
        'totalRevenue': totalRevenue,
        'activeListings': activeListings,
        'followers': followers,
        'communityPosts': communityPosts,
        'yearlySales': rev1Y,
        'revenueTrend': trend7D,
        'listingsTrend': '0%',
        'weeklyData': data7D,
        'analytics': {
          '7D': {
            'revenue': rev7D,
            'trend': trend7D,
            'data': data7D,
            'labels': labels7D,
            'dates': dates7D,
            'orderCounts': orders7D,
          },
          '30D': {
            'revenue': rev30D,
            'trend': trend30D,
            'data': data30D,
            'labels': labels30D,
            'dates': dates30D,
            'orderCounts': orders30D,
          },
          '1Y': {
            'revenue': rev1Y,
            'trend': '+0%',
            'data': data1Y,
            'labels': labels1Y,
            'dates': dates1Y,
            'orderCounts': orders1Y,
          },
        },
      };
    } catch (e) {
      debugPrint('Error fetching farmer stats: $e');
      return {
        'totalRevenue': 0.0,
        'activeListings': 0,
        'followers': 0,
        'communityPosts': 0,
        'yearlySales': 0.0,
        'revenueTrend': '0%',
        'listingsTrend': '0%',
        'weeklyData': List.filled(7, 0.0),
        'analytics': {
          '7D': {
            'revenue': 0.0,
            'trend': '0%',
            'data': List.filled(7, 0.0),
            'labels': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
            'dates': List.filled(7, ''),
            'orderCounts': List.filled(7, 0),
          },
          '30D': {
            'revenue': 0.0,
            'trend': '0%',
            'data': List.filled(5, 0.0),
            'labels': ['W1', 'W2', 'W3', 'W4', 'W5'],
            'dates': List.filled(5, ''),
            'orderCounts': List.filled(5, 0),
          },
          '1Y': {
            'revenue': 0.0,
            'trend': '0%',
            'data': List.filled(12, 0.0),
            'labels': ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
            'dates': List.filled(12, ''),
            'orderCounts': List.filled(12, 0),
          },
        },
      };
    }
  }
}
