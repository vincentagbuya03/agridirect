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
import '../../models/product/crop_milestone_model.dart';
import '../logging/system_activity_logger.dart';
import '../social/follow_service.dart';
import '../community/notification_service.dart';
import 'dart:async';

class ProductService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SystemActivityLogger _activityLogger = SystemActivityLogger();

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
          farmName: farmName?.isNotEmpty == true
              ? farmName!
              : 'A farm you follow',
        );
      } catch (e) {
        debugPrint('⚠️ Error notifying followers: $e');
      }

      await _activityLogger.log(
        action: 'product_created',
        details:
            'Product added: ${product.name} (${isPreorder ? 'pre-order' : 'regular'})',
        entityType: 'product',
        entityId: product.productId,
        metadata: {
          'product_id': product.productId,
          'product_name': product.name,
          'farmer_id': farmerId,
          'farm_name': farmName,
          'price': price,
          'category_id': categoryId,
          'unit_id': unitId,
          'available_quantity': availableQuantity,
          'is_preorder': isPreorder,
        },
      );

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

      await _activityLogger.log(
        action: 'product_updated',
        details: 'Product edited: ${product.name}',
        entityType: 'product',
        entityId: product.productId,
        metadata: {
          'product_id': product.productId,
          'product_name': product.name,
          'farmer_id': product.farmerId,
          'price': product.price,
          'changed_fields': updateData.keys.toList(),
        },
      );

      return product;
    } catch (e) {
      throw Exception('Failed to update product: $e');
    }
  }

  /// Delete product
  Future<void> deleteProduct(String productId) async {
    try {
      final existing = await _supabase
          .from('products')
          .select('product_id, name, farmer_id')
          .eq('product_id', productId)
          .maybeSingle();

      await _supabase.from('products').delete().eq('product_id', productId);

      await _activityLogger.log(
        action: 'product_archived',
        details: 'Product archived: ${existing?['name'] ?? productId}',
        entityType: 'product',
        entityId: productId,
        severity: 'warning',
        metadata: {
          'product_id': productId,
          'product_name': existing?['name'],
          'farmer_id': existing?['farmer_id'],
        },
      );
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
          .select('*, customers(users(name, avatar_url))')
          .eq('product_id', productId)
          .limit(limit)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => _reviewFromDatabase(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch reviews: $e');
    }
  }

  /// Finds a completed order that qualifies the current customer to review.
  Future<String?> getCompletedOrderIdForReview(String productId) async {
    try {
      final customerId = await _getCurrentCustomerId();
      return _getCompletedOrderIdForCustomerProduct(
        customerId: customerId,
        productId: productId,
      );
    } catch (e) {
      debugPrint('Failed to check review eligibility: $e');
      return null;
    }
  }

  /// Create product review
  Future<ProductReview> createReview({
    required String productId,
    required double rating,
    String? reviewText,
  }) async {
    try {
      if (rating < 1 || rating > 5) {
        throw Exception('Rating must be between 1 and 5');
      }

      final customerId = await _getCurrentCustomerId();
      final orderId = await _getCompletedOrderIdForCustomerProduct(
        customerId: customerId,
        productId: productId,
      );

      if (orderId == null) {
        throw Exception(
          'You can only review this product after completing an order for it.',
        );
      }

      final response = await _supabase
          .from('product_reviews')
          .insert({
            'product_id': productId,
            'customer_id': customerId,
            'order_id': orderId,
            'rating': rating,
            'review_text': reviewText?.trim().isEmpty == true
                ? null
                : reviewText?.trim(),
            'is_verified_purchase': true,
          })
          .select('*, customers(users(name, avatar_url))')
          .single();

      final review = _reviewFromDatabase(response);

      // Trigger push notification to farmer
      unawaited(NotificationService().notifyFarmerNewProductReview(
        productId: productId,
        rating: rating,
      ));

      return review;
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
          .update({'rating': ?rating, 'review_text': ?reviewText})
          .eq('review_id', reviewId)
          .select()
          .single();

      return _reviewFromDatabase(response);
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

  Future<String> _getCurrentCustomerId() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final response = await _supabase
        .from('customers')
        .select('customer_id')
        .eq('user_id', userId)
        .maybeSingle();

    final customerId = response?['customer_id']?.toString();
    if (customerId == null || customerId.isEmpty) {
      throw Exception('Customer profile not found');
    }
    return customerId;
  }

  Future<String?> _getCompletedOrderIdForCustomerProduct({
    required String customerId,
    required String productId,
  }) async {
    final response = await _supabase
        .from('orders')
        .select(
          'order_id, order_items!inner(product_id), order_statuses!inner(code)',
        )
        .eq('customer_id', customerId)
        .eq('order_items.product_id', productId)
        .eq('order_statuses.code', 'completed')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return response?['order_id']?.toString();
  }

  ProductReview _reviewFromDatabase(Map<String, dynamic> json) {
    final customer = json['customers'] as Map<String, dynamic>?;
    final user = customer?['users'] as Map<String, dynamic>?;

    return ProductReview(
      reviewId: json['review_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      userId:
          json['customer_id']?.toString() ?? json['user_id']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewText: json['review_text']?.toString(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      userName: user?['name']?.toString(),
      userAvatar: user?['avatar_url']?.toString(),
    );
  }

  /// Fetch milestones for a specific pre-order crop product
  Future<List<CropMilestone>> getCropMilestones(String productId) async {
    try {
      final response = await _supabase
          .from('crop_milestones')
          .select()
          .eq('product_id', productId)
          .order('created_at', ascending: true);

      return (response as List<dynamic>)
          .map((json) => CropMilestone.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching crop milestones: $e');
      return [];
    }
  }

  /// Add a growth update/milestone for a crop
  Future<CropMilestone> addCropMilestone({
    required String productId,
    required String title,
    required String description,
    String? imageUrl,
  }) async {
    try {
      final response = await _supabase
          .from('crop_milestones')
          .insert({
            'product_id': productId,
            'title': title,
            'description': description,
            'image_url': imageUrl,
          })
          .select()
          .single();

      final milestone = CropMilestone.fromJson(response);

      await _activityLogger.log(
        action: 'crop_milestone_added',
        details: 'Added milestone "${milestone.title}" for product $productId',
        entityType: 'product',
        entityId: productId,
        metadata: {
          'milestone_id': milestone.milestoneId,
          'product_id': productId,
          'title': title,
        },
      );

      // 1. Fetch product name to personalize the notification
      String cropName = 'Crop';
      try {
        final prodResponse = await _supabase
            .from('products')
            .select('name')
            .eq('product_id', productId)
            .maybeSingle();
        if (prodResponse != null) {
          cropName = prodResponse['name']?.toString() ?? 'Crop';
        }
      } catch (_) {}

      // 2. Find and notify all reserving customers
      try {
        final reservations = await _supabase
            .from('orders')
            .select('order_id, customer_id')
            .inFilter('status_code', ['PENDING', 'CONFIRMED'])
            .eq('order_items.product_id', productId);

        final reservationList = List<Map<String, dynamic>>.from(reservations as List);

        // 3. Send push notification + DB entry to each reserving customer
        for (final reservation in reservationList) {
          final customerId = reservation['customer_id']?.toString();
          final orderId = reservation['order_id']?.toString();
          if (customerId == null || orderId == null) continue;

          await NotificationService().insertNotification(
            userId: customerId,
            title: '🌱 Pre-order Update: $cropName',
            content: 'A new growth update was posted: "$title". Check your orders for details!',
            type: 'system',
            linkType: 'orders',
            linkId: orderId,
          );
        }
      } catch (notifErr) {
        debugPrint('Error notifying pre-order customers: $notifErr');
      }

      return milestone;
    } catch (e) {
      throw Exception('Failed to add crop milestone: $e');
    }
  }
}
