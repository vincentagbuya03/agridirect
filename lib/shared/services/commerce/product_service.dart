// ============================================================================
// lib/shared/services/commerce/product_service.dart
// Product CRUD operations with Supabase
// ============================================================================

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/product/product_model.dart';
import '../../models/product/category_model.dart';
import '../../models/product/unit_model.dart';
import '../../models/product/product_review_model.dart';
import '../social/follow_service.dart';

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
      throw Exception('Failed to fetch products: $e');
    }
  }

  /// Get products by category
  Future<List<Product>> getProductsByCategory(
    String categoryId, {
    int limit = 20,
  }) async {
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
      throw Exception('Failed to fetch products by category: $e');
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
      throw Exception('Failed to fetch farmer products: $e');
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
    double? availableQuantity,
  }) async {
    try {
      // Get current user ID from auth
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // First, check if farmer record exists for this user
      final farmerExists = await _supabase
          .from('farmers')
          .select('farmer_id')
          .eq('user_id', userId)
          .maybeSingle();

      // If farmer doesn't exist, create one
      if (farmerExists == null) {
        try {
          await _supabase.from('farmers').insert({
            'user_id': userId,
            'farm_name': 'My Farm',
          });

          // Create registration record with pending status
          final newFarmer = await _supabase
              .from('farmers')
              .select('farmer_id')
              .eq('user_id', userId)
              .maybeSingle();

          if (newFarmer != null) {
            await _supabase.from('farmer_registrations').insert({
              'farmer_id': newFarmer['farmer_id'],
              'status': 'pending',
            });
          }
        } catch (e) {
          debugPrint('Error creating farmer: $e');
        }
      }

      // Get the farmer_id for this user
      final farmerResponse = await _supabase
          .from('farmers')
          .select('farmer_id, farm_name, location, residential_address')
          .eq('user_id', userId)
          .single();

      final farmerId = farmerResponse['farmer_id'] as String;
      final farmName = (farmerResponse['farm_name'] as String?)?.trim();
      final farmLocation =
          ((farmerResponse['location'] as String?) ??
                  (farmerResponse['residential_address'] as String?) ??
                  '')
              .trim();

      final response = await _supabase
          .from('products')
          .insert({
            'name': name,
            'price': price,
            'description': description,
            'harvest_days': harvestDays,
            'is_preorder': isPreorder,
            'farmer_id': farmerId,
            'category_id': categoryId,
            'unit_id': unitId,
          })
          .select()
          .single();

      // Convert snake_case database response to camelCase for Product model
      final product = Product.fromJson({
        'productId': response['product_id'],
        'name': response['name'],
        'price': response['price'],
        'description': response['description'],
        'imageUrl': response['image_url'],
        'harvestDays': response['harvest_days'],
        'isPreorder': response['is_preorder'] ?? false,
        'farmerId': response['farmer_id'],
        'categoryId': response['category_id'],
        'unitId': response['unit_id'],
        'createdAt': response['created_at'],
        'updatedAt': response['updated_at'],
      });

      // Create inventory record if quantity is provided
      if (availableQuantity != null && availableQuantity > 0) {
        try {
          await _supabase.from('product_inventory').insert({
            'product_id': product.productId,
            'available_quantity': availableQuantity,
            'reserved_quantity': 0,
            'low_stock_threshold':
                availableQuantity * 0.1, // 10% of available quantity
          });
          debugPrint(
            '✅ Successfully created inventory with quantity: $availableQuantity',
          );
        } catch (e) {
          debugPrint('⚠️ Error creating inventory: $e');
        }
      }

      // If we have image URLs (comma separated), insert them into product_images table
      if (imageUrl != null && imageUrl.isNotEmpty) {
        final urls = imageUrl
            .split(',')
            .map((url) => url.trim())
            .where((url) => url.isNotEmpty)
            .toList();

        if (urls.isNotEmpty) {
          final imageInserts = urls.asMap().entries.map((entry) {
            return {
              'product_id': product.productId,
              'image_url': entry.value,
              'sort_order': entry.key,
            };
          }).toList();

          try {
            await _supabase.from('product_images').insert(imageInserts);
            debugPrint(
              '✅ Successfully inserted ${imageInserts.length} product images',
            );
          } catch (e) {
            debugPrint('⚠️ Error inserting product images: $e');
          }
        }
      }

      try {
        await _notifyNearbyCustomers(
          productId: product.productId,
          productName: product.name,
          farmName: farmName,
          farmLocation: farmLocation,
        );
      } catch (e) {
        debugPrint('⚠️ Error notifying nearby customers: $e');
      }

      try {
        await FollowService().notifyFollowersAboutNewProduct(
          farmerId: farmerId,
          productId: product.productId,
          productName: product.name,
          farmName: farmName?.isNotEmpty == true ? farmName! : 'A farm you follow',
        );
      } catch (e) {
        debugPrint('⚠️ Error notifying followers: $e');
      }

      return product;
    } catch (e) {
      throw Exception('Failed to create product: $e');
    }
  }

  Future<void> _notifyNearbyCustomers({
    required String productId,
    required String productName,
    String? farmName,
    String? farmLocation,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'notify-nearby-customers',
        body: {
          'productId': productId,
          'productName': productName,
          'farmName': farmName ?? '',
          'farmLocation': farmLocation ?? '',
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic> && data['error'] != null) {
        throw Exception(data['error']);
      }
    } catch (e) {
      debugPrint('Nearby customer notification request failed: $e');
      rethrow;
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
      final updateData = <String, dynamic>{
        'name': ?name,
        'price': ?price,
        'description': ?description,
        'harvest_days': ?harvestDays,
        'is_preorder': ?isPreorder,
      };

      final response = await _supabase
          .from('products')
          .update(updateData)
          .eq('product_id', productId)
          .select()
          .single();

      // Convert snake_case database response to camelCase for Product model
      return Product.fromJson({
        'productId': response['product_id'],
        'name': response['name'],
        'price': response['price'],
        'description': response['description'],
        'imageUrl': response['image_url'],
        'harvestDays': response['harvest_days'],
        'isPreorder': response['is_preorder'] ?? false,
        'farmerId': response['farmer_id'],
        'categoryId': response['category_id'],
        'unitId': response['unit_id'],
        'createdAt': response['created_at'],
        'updatedAt': response['updated_at'],
      });
    } catch (e) {
      throw Exception('Failed to update product: $e');
    }
  }

  /// Delete product
  Future<void> deleteProduct(String productId) async {
    try {
      await _supabase.from('products').delete().eq('product_id', productId);
    } catch (e) {
      throw Exception('Failed to delete product: $e');
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

      return (response as List<dynamic>).map((json) {
        final data = json as Map<String, dynamic>;
        // Map database field names to model field names
        return Category.fromJson({
          'categoryId': data['id'] ?? data['category_id'],
          'name': data['name'],
          'description': data['description'],
          'icon': data['icon'],
          'createdAt': data['created_at'] ?? DateTime.now().toIso8601String(),
        });
      }).toList();
    } catch (e) {
      debugPrint('❌ Error in getCategories: $e');
      throw Exception('Failed to fetch categories: $e');
    }
  }

  // ============================================================================
  // UNITS OPERATIONS
  // ============================================================================

  /// Get all units
  Future<List<Unit>> getUnits() async {
    try {
      final response = await _supabase
          .from('units')
          .select()
          .order('name', ascending: true);

      return (response as List<dynamic>).map((json) {
        final data = json as Map<String, dynamic>;
        // Map database field names to model field names
        return Unit.fromJson({
          'unitId': data['id'] ?? data['unit_id'],
          'name': data['name'],
          'abbreviation': data['abbreviation'] ?? data['abbr'] ?? '',
          'createdAt': data['created_at'] ?? DateTime.now().toIso8601String(),
        });
      }).toList();
    } catch (e) {
      debugPrint('❌ Error in getUnits: $e');
      throw Exception('Failed to fetch units: $e');
    }
  }

  // ============================================================================
  // REVIEWS OPERATIONS
  // ============================================================================

  /// Get product reviews
  Future<List<ProductReview>> getProductReviews(
    String productId, {
    int limit = 10,
  }) async {
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
      throw Exception('Failed to fetch reviews: $e');
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

      final response = await _supabase
          .from('product_reviews')
          .insert({
            'product_id': productId,
            'user_id': userId,
            'rating': rating,
            'review_text': reviewText,
          })
          .select()
          .single();

      return ProductReview.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create review: $e');
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
            'rating': ?rating,
            'review_text': ?reviewText,
          })
          .eq('review_id', reviewId)
          .select()
          .single();

      return ProductReview.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update review: $e');
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
      throw Exception('Failed to delete review: $e');
    }
  }

  /// Search products
  Future<List<Product>> searchProducts(String query) async {
    try {
      final response = await _supabase
          .from('v_products')
          .select()
          .ilike('name', '%$query%')
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to search products: $e');
    }
  }
}
