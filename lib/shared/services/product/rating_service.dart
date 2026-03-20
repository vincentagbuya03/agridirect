import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/farmer/farmer_rating_model.dart';
import '../../models/farmer/farmer_statistics_model.dart';

class RatingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get ratings for a specific farmer
  Future<List<FarmerRating>> getFarmerRatings(String farmerId,
      {int limit = 20, int offset = 0}) async {
    try {
      final response = await _supabase
          .from('v_farmer_ratings')
          .select()
          .eq('farmer_id', farmerId)
          .range(offset, offset + limit - 1)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => FarmerRating.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch farmer ratings: $e');
    }
  }

  /// Get a single rating by ID
  Future<FarmerRating?> getRatingById(String ratingId) async {
    try {
      final response = await _supabase
          .from('v_farmer_ratings')
          .select()
          .eq('rating_id', ratingId)
          .single();

      return FarmerRating.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Create a farmer rating
  Future<FarmerRating> createRating({
    required String farmerId,
    required double rating,
    String? orderId,
    String? reviewText,
    Map<String, dynamic>? categories,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase.from('farmer_ratings').insert({
        'farmer_id': farmerId,
        'customer_id': userId,
        'order_id': orderId,
        'rating': rating,
        'review_text': reviewText,
        'categories': categories,
      }).select().single();

      return FarmerRating.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create rating: $e');
    }
  }

  /// Update a rating
  Future<FarmerRating> updateRating(
    String ratingId, {
    double? rating,
    String? reviewText,
    Map<String, dynamic>? categories,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (rating != null) data['rating'] = rating;
      if (reviewText != null) data['review_text'] = reviewText;
      if (categories != null) data['categories'] = categories;

      final response = await _supabase
          .from('farmer_ratings')
          .update(data)
          .eq('rating_id', ratingId)
          .select()
          .single();

      return FarmerRating.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update rating: $e');
    }
  }

  /// Delete a rating
  Future<void> deleteRating(String ratingId) async {
    try {
      await _supabase
          .from('farmer_ratings')
          .delete()
          .eq('rating_id', ratingId);
    } catch (e) {
      throw Exception('Failed to delete rating: $e');
    }
  }

  /// Get farmer statistics
  Future<FarmerStatistics?> getFarmerStatistics(String farmerId) async {
    try {
      final response = await _supabase
          .from('farmer_statistics')
          .select()
          .eq('farmer_id', farmerId)
          .single();

      return FarmerStatistics.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Check if current user has rated a farmer for a specific order
  Future<bool> hasRatedFarmerForOrder(String farmerId, String orderId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('farmer_ratings')
          .select('rating_id')
          .eq('farmer_id', farmerId)
          .eq('customer_id', userId)
          .eq('order_id', orderId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }
}
