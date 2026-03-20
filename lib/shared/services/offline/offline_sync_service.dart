// ============================================================================
// lib/shared/services/offline/offline_sync_service.dart
// Handles synchronization of offline products when internet is available
// ============================================================================

import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/product/offline_product_model.dart';
import 'local_database_service.dart';

class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  final _connectivity = Connectivity();
  final _localDb = LocalDatabaseService();
  final _supabase = Supabase.instance.client;

  factory OfflineSyncService() {
    return _instance;
  }

  OfflineSyncService._internal();

  /// Check if device has internet connection
  Future<bool> hasInternetConnection() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  /// Listen to connectivity changes and auto-sync when online
  Stream<bool> get connectivityStream {
    return _connectivity.onConnectivityChanged.map((result) {
      final isOnline = !result.contains(ConnectivityResult.none);
      if (isOnline) {
        syncPendingProducts(); // Auto-sync when connection returns
      }
      return isOnline;
    });
  }

  /// Sync all pending products to Supabase
  Future<void> syncPendingProducts() async {
    final isOnline = await hasInternetConnection();
    if (!isOnline) return;

    final pendingProducts = await _localDb.getPendingProducts();

    for (final product in pendingProducts) {
      await _syncProduct(product);
    }
  }

  /// Sync a single product
  Future<void> _syncProduct(OfflineProduct product) async {
    try {
      // Mark as syncing
      await _localDb.updateSyncStatus(
        product.localId,
        status: SyncStatus.syncing,
      );

      // Step 1: Upload image if available
      String? imageUrl = product.imageUrl;
      if (product.imageBase64 != null && product.imageBase64!.isNotEmpty) {
        try {
          imageUrl = await _uploadProductImage(
            product.farmerId,
            product.localId,
            product.imageBase64!,
          );
          print('📸 Image uploaded: $imageUrl');
        } catch (e) {
          print('⚠️  Image upload failed: $e');
          // Continue anyway - product can be created without image
        }
      }

      // Step 2: Create product with image URL
      String productId;

      if (product.productId == null) {
        // Create new product via SECURITY DEFINER RPC (bypasses RLS, auto-creates farmer row)
        final response = await _supabase.rpc(
          'insert_product_sync',
          params: {
            'p_farmer_id': product.farmerId,
            'p_name': product.name,
            'p_price': product.price,
            'p_category_id': product.categoryId,
            'p_unit_id': product.unitId,
            'p_quantity': product.quantity,
            'p_description': product.description,
            'p_image_url': imageUrl,
            'p_harvest_days': product.harvestDays,
            'p_is_preorder': product.isPreorder,
          },
        );

        productId = response as String;
      } else {
        // Update existing product (still use direct update)
        productId = product.productId!;
        await _supabase
            .from('products')
            .update({
              'name': product.name,
              'price': product.price,
              'description': product.description,
              'image_url': imageUrl,
              'harvest_days': product.harvestDays,
              'is_preorder': product.isPreorder,
              'quantity': product.quantity,
              'category_id': product.categoryId,
              'unit_id': product.unitId,
            })
            .eq('product_id', productId);
      }

      // Mark as synced successfully
      await _localDb.updateSyncStatus(
        product.localId,
        status: SyncStatus.synced,
        productId: productId,
      );

      // Log successful sync
      print('✅ Product synced: $productId');
    } catch (e) {
      // Mark as failed with error message
      final errorMsg = e.toString();
      print('❌ Sync failed for product ${product.name}: $errorMsg');

      await _localDb.updateSyncStatus(
        product.localId,
        status: SyncStatus.failed,
        error: errorMsg,
      );

      rethrow;
    }
  }

  /// Upload product image from base64 to Supabase Storage
  Future<String> _uploadProductImage(
    String farmerId,
    String productLocalId,
    String imageBase64,
  ) async {
    try {
      // Decode base64 to bytes
      final imageBytes = base64Decode(imageBase64);

      // Create unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '$farmerId/product_${productLocalId}_$timestamp.jpg';

      // Upload to Supabase Storage
      await _supabase.storage
          .from('product-images')
          .uploadBinary(
            fileName,
            imageBytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      // Get public URL
      final publicUrl = _supabase.storage
          .from('product-images')
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      print('❌ Image upload error: $e');
      rethrow;
    }
  }

  /// Retry failed syncs
  Future<void> retryFailedSyncs() async {
    final isOnline = await hasInternetConnection();
    if (!isOnline) return;

    final failedProducts = await _localDb.getPendingProducts();
    final failed = failedProducts.where(
      (p) => p.syncStatus == SyncStatus.failed,
    );

    for (final product in failed) {
      if (product.syncAttempts < 3) {
        // Only retry up to 3 times
        await _syncProduct(product);
      }
    }
  }

  /// Get offline product count
  Future<int> getPendingProductCount() async {
    final pending = await _localDb.getPendingProducts();
    return pending.length;
  }

  /// Get sync statistics
  Future<Map<String, int>> getSyncStats() async {
    return _localDb.getSyncStats();
  }

  /// Clear synced products from local storage
  Future<void> clearSyncedProducts() async {
    await _localDb.deleteSyncedProducts();
  }
}
