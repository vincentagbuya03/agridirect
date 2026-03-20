import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/product/wishlist_item_model.dart';

class WishlistService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get current user's wishlist
  Future<List<WishlistItem>> getWishlist({int limit = 50}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('v_customer_wishlist')
          .select()
          .eq('customer_id', userId)
          .limit(limit)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => WishlistItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch wishlist: $e');
    }
  }

  /// Add product to wishlist
  Future<void> addToWishlist(String productId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase.from('customer_wishlist').insert({
        'customer_id': userId,
        'product_id': productId,
      });
    } catch (e) {
      throw Exception('Failed to add to wishlist: $e');
    }
  }

  /// Remove product from wishlist
  Future<void> removeFromWishlist(String productId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('customer_wishlist')
          .delete()
          .eq('customer_id', userId)
          .eq('product_id', productId);
    } catch (e) {
      throw Exception('Failed to remove from wishlist: $e');
    }
  }

  /// Check if product is in wishlist
  Future<bool> isInWishlist(String productId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('customer_wishlist')
          .select('wishlist_id')
          .eq('customer_id', userId)
          .eq('product_id', productId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Get wishlist product IDs (for quick UI checks)
  Future<Set<String>> getWishlistProductIds() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return {};

      final response = await _supabase
          .from('customer_wishlist')
          .select('product_id')
          .eq('customer_id', userId);

      return (response as List<dynamic>)
          .map((item) => item['product_id'] as String)
          .toSet();
    } catch (e) {
      return {};
    }
  }

  /// Get wishlist count
  Future<int> getWishlistCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      final response = await _supabase
          .from('customer_wishlist')
          .select('wishlist_id')
          .eq('customer_id', userId);

      return (response as List<dynamic>).length;
    } catch (e) {
      return 0;
    }
  }
}
