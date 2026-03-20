import 'package:supabase_flutter/supabase_flutter.dart';

class FollowerService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Follow a farmer
  Future<void> followFarmer(String farmerId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase.from('farmer_followers').insert({
        'farmer_id': farmerId,
        'user_id': userId,
      });
    } catch (e) {
      throw Exception('Failed to follow farmer: $e');
    }
  }

  /// Unfollow a farmer
  Future<void> unfollowFarmer(String farmerId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('farmer_followers')
          .delete()
          .eq('farmer_id', farmerId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to unfollow farmer: $e');
    }
  }

  /// Check if current user follows a farmer
  Future<bool> isFollowing(String farmerId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('farmer_followers')
          .select('follower_id')
          .eq('farmer_id', farmerId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Get followers of a farmer
  Future<List<Map<String, dynamic>>> getFarmerFollowers(String farmerId,
      {int limit = 50}) async {
    try {
      final response = await _supabase
          .from('farmer_followers')
          .select('follower_id, user_id, created_at, users(name, avatar_url)')
          .eq('farmer_id', farmerId)
          .limit(limit)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((item) => item as Map<String, dynamic>)
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch farmer followers: $e');
    }
  }

  /// Get farmers that current user follows
  Future<List<Map<String, dynamic>>> getFollowedFarmers(
      {int limit = 50}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('farmer_followers')
          .select(
              'follower_id, farmer_id, created_at, farmers(farm_name, image_url, is_verified)')
          .eq('user_id', userId)
          .limit(limit)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((item) => item as Map<String, dynamic>)
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch followed farmers: $e');
    }
  }

  /// Get follower count for a farmer
  Future<int> getFollowerCount(String farmerId) async {
    try {
      final response = await _supabase
          .from('farmer_followers')
          .select('follower_id')
          .eq('farmer_id', farmerId);

      return (response as List<dynamic>).length;
    } catch (e) {
      return 0;
    }
  }
}
