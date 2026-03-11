// ============================================================================
// lib/shared/services/product_service.dart
// Product CRUD operations with Supabase
// ============================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product/product_model.dart';
import '../models/product/category_model.dart';
import '../models/product/unit_model.dart';
import '../models/product/product_review_model.dart';

class ProductService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================================
  // PRODUCTS OPERATIONS
  // ============================================================================

  /// Get all products with view data (ratings, farm info, etc)
  Future<List<Product>> getProducts({int limit = 20, int offset = 0}) async {
    try {
      final response = await _supabase
          .from('v_products')
          .select()
          .range(offset, offset + limit - 1)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch products: \$e');
    }
  }

  /// Get products by category
  Future<List<Product>> getProductsByCategory(String categoryId,
      {int limit = 20}) async {
    try {
      final response = await _supabase
          .from('v_products')
          .select()
          .eq('category_id', categoryId)
          .limit(limit)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch products by category: \$e');
    }
  }

  /// Get farmer's products
  Future<List<Product>> getFarmerProducts(String farmerId) async {
    try {
      final response = await _supabase
          .from('v_products')
          .select()
          .eq('farmer_id', farmerId)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch farmer products: \$e');
    }
  }

  /// Get single product by ID
  Future<Product?> getProductById(String productId) async {
    try {
      final response = await _supabase
          .from('v_products')
          .select()
          .eq('product_id', productId)
          .single();

      return Product.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Create new product
  Future<Product> createProduct({
    required String name,
    required double price,
    required String categoryId,
    required String unitId,
    String? description,
    String? imageUrl,
    int? harvestDays,
    bool isPreorder = false,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase.from('products').insert({
        'name': name,
        'price': price,
        'description': description,
        'image_url': imageUrl,
        'harvest_days': harvestDays,
        'is_preorder': isPreorder,
        'farmer_id': userId,
        'category_id': categoryId,
        'unit_id': unitId,
      }).select().single();

      return Product.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create product: \$e');
    }
  }

  /// Update product
  Future<Product> updateProduct(
    String productId, {
    String? name,
    double? price,
    String? description,
    String? imageUrl,
    int? harvestDays,
    bool? isPreorder,
  }) async {
    try {
      final response = await _supabase
          .from('products')
          .update({
            if (name != null) 'name': name,
            if (price != null) 'price': price,
            if (description != null) 'description': description,
            if (imageUrl != null) 'image_url': imageUrl,
            if (harvestDays != null) 'harvest_days': harvestDays,
            if (isPreorder != null) 'is_preorder': isPreorder,
          })
          .eq('product_id', productId)
          .select()
          .single();

      return Product.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update product: \$e');
    }
  }

  /// Delete product
  Future<void> deleteProduct(String productId) async {
    try {
      await _supabase.from('products').delete().eq('product_id', productId);
    } catch (e) {
      throw Exception('Failed to delete product: \$e');
    }
  }

  // ============================================================================
  // CATEGORIES OPERATIONS
  // ============================================================================

  /// Get all categories
  Future<List<Category>> getCategories() async {
    try {
      final response = await _supabase
          .from('categories')
          .select()
          .order('name', ascending: true);

      return (response as List<dynamic>)
          .map((json) => Category.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch categories: \$e');
    }
  }

  // ============================================================================
  // UNITS OPERATIONS
  // ============================================================================

  /// Get all units
  Future<List<Unit>> getUnits() async {
    try {
      final response =
          await _supabase.from('units').select().order('name', ascending: true);

      return (response as List<dynamic>)
          .map((json) => Unit.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch units: \$e');
    }
  }

  // ============================================================================
  // REVIEWS OPERATIONS
  // ============================================================================

  /// Get product reviews
  Future<List<ProductReview>> getProductReviews(String productId,
      {int limit = 10}) async {
    try {
      final response = await _supabase
          .from('product_reviews')
          .select()
          .eq('product_id', productId)
          .limit(limit)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => ProductReview.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch reviews: \$e');
    }
  }

  /// Create product review
  Future<ProductReview> createReview({
    required String productId,
    required double rating,
    String? reviewText,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase.from('product_reviews').insert({
        'product_id': productId,
        'user_id': userId,
        'rating': rating,
        'review_text': reviewText,
      }).select().single();

      return ProductReview.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create review: \$e');
    }
  }

  /// Update review
  Future<ProductReview> updateReview(
    String reviewId, {
    double? rating,
    String? reviewText,
  }) async {
    try {
      final response = await _supabase
          .from('product_reviews')
          .update({
            if (rating != null) 'rating': rating,
            if (reviewText != null) 'review_text': reviewText,
          })
          .eq('review_id', reviewId)
          .select()
          .single();

      return ProductReview.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update review: \$e');
    }
  }

  /// Delete review
  Future<void> deleteReview(String reviewId) async {
    try {
      await _supabase
          .from('product_reviews')
          .delete()
          .eq('review_id', reviewId);
    } catch (e) {
      throw Exception('Failed to delete review: \$e');
    }
  }

  /// Search products
  Future<List<Product>> searchProducts(String query) async {
    try {
      final response = await _supabase
          .from('v_products')
          .select()
          .ilike('name', '%\$query%')
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to search products: \$e');
    }
  }
}
