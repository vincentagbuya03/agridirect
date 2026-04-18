import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../core/supabase_config.dart';
import '../commerce/product_service.dart';
import '../offline/offline_queue_service.dart';
import '../../models/offline_product_queue.dart';
import '../../models/cached_product.dart';
import '../offline/offline_cache_service.dart';
import '../core/bootstrap_cache_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';

class OfflineProductService {
  final OfflineQueueService _queueService;
  final ProductService _productService;
  final Connectivity _connectivity;
  final OfflineCacheService _cacheService = OfflineCacheService();

  // Stream to notify UI about sync status changes
  final ValueNotifier<int> pendingProductsCount = ValueNotifier(0);
  final ValueNotifier<bool> isSyncing = ValueNotifier(false);

  static OfflineProductService? _instance;
  
  factory OfflineProductService({
    OfflineQueueService? queueService,
    ProductService? productService,
    Connectivity? connectivity,
  }) {
    _instance ??= OfflineProductService._internal(
      queueService: queueService ?? OfflineQueueService(),
      productService: productService ?? ProductService(),
      connectivity: connectivity ?? Connectivity(),
    );
    return _instance!;
  }

  OfflineProductService._internal({
    required OfflineQueueService queueService,
    required ProductService productService,
    required Connectivity connectivity,
  }) : _queueService = queueService,
       _productService = productService,
       _connectivity = connectivity;

  Future<void> init() async {
    await _queueService.init();
    try {
      await _cacheService.init();
    } catch (e) {
      debugPrint(
        '⚠️ Offline cache init skipped in offline product service: $e',
      );
    }
    await _mirrorPendingQueueToCache();
    _updatePendingCount();
    _listenToConnectivity();
    await _triggerInitialSyncIfNeeded();
    _listenToQueueChanges();
  }

  void _listenToQueueChanges() {
    Hive.box<OfflineProductQueue>(OfflineQueueService.boxName).watch().listen((event) async {
      final online = await isOnline();
      if (online && !isSyncing.value) {
        final pending = _queueService.getPendingProducts();
        if (pending.isNotEmpty) {
          debugPrint('📥 Queue change detected, triggering sync...');
          syncPendingProducts();
        }
      }
    });
  }

  Future<void> _triggerInitialSyncIfNeeded() async {
    final online = await isOnline();
    if (online && pendingProductsCount.value > 0) {
      await syncPendingProducts();
    }
  }

  Future<void> _mirrorPendingQueueToCache() async {
    final pending = _queueService.getPendingProducts();
    for (final product in pending) {
      try {
        await _cacheQueuedProduct(
          id: product.id,
          farmerId: product.farmerId,
          name: product.name,
          price: product.price,
          description: product.description,
          availableQuantity: product.availableQuantity,
          isPreorder: product.isPreorder,
          harvestDays: product.harvestDays,
          localImagePaths: product.localImagePaths,
          uploadedImageUrl: product.imageUrl,
        );
      } catch (e) {
        debugPrint('⚠️ Failed to mirror pending product ${product.id}: $e');
      }
    }
  }

  Future<void> _cacheQueuedProduct({
    required String id,
    required String farmerId,
    required String name,
    required double price,
    required String description,
    required int availableQuantity,
    required bool isPreorder,
    required int harvestDays,
    required List<String> localImagePaths,
    String? uploadedImageUrl,
  }) async {
    final localPreview = localImagePaths.isNotEmpty
        ? localImagePaths.first
        : null;

    await _cacheService.manualSaveProduct(
      CachedProduct(
        id: id,
        farmerId: farmerId,
        name: name,
        price: price,
        description: description,
        imageUrl: uploadedImageUrl ?? localPreview,
        availableQuantity: availableQuantity,
        isPreorder: isPreorder,
        harvestDays: harvestDays,
        farmName: 'Pending Sync',
      ),
    );
  }

  void _updatePendingCount() {
    final pending = _queueService.getPendingProducts();
    pendingProductsCount.value = pending.length;
  }

  void _listenToConnectivity() {
    _connectivity.onConnectivityChanged.listen((result) {
      final isConnected =
          result.isNotEmpty && result.first != ConnectivityResult.none;
      if (isConnected && pendingProductsCount.value > 0) {
        syncPendingProducts();
      }
    });
  }

  Future<bool> isOnline() async {
    try {
      final result = await _connectivity.checkConnectivity();
      if (result.isEmpty || result.first == ConnectivityResult.none) return false;
      
      // Actual internet check (DNS lookup)
      final ping = await InternetAddress.lookup('google.com').timeout(
        const Duration(seconds: 3),
      );
      return ping.isNotEmpty && ping[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Save product - offline first approach
  /// Returns the product ID if successful, or null if queued for sync
  Future<String?> createProduct({
    required String farmerId,
    required String name,
    required double price,
    required String description,
    required String categoryId,
    required String unitId,
    required int harvestDays,
    required bool isPreorder,
    required int availableQuantity,
    required List<String> localImagePaths, // File paths
    String? uploadedImageUrl, // URLs from online upload (optional)
  }) async {
    final online = await isOnline();

    if (online) {
      // Try to upload to Supabase immediately
      try {
        return await _uploadProductToSupabase(
          name: name,
          price: price,
          description: description,
          categoryId: categoryId,
          unitId: unitId,
          harvestDays: harvestDays,
          isPreorder: isPreorder,
          availableQuantity: availableQuantity.toDouble(),
          localImagePaths: localImagePaths,
        );
      } catch (e) {
        // If online fails, fall back to offline queue
        debugPrint('Failed to upload to Supabase: $e, saving offline');
        final queuedProduct = await _queueService.addProductToQueue(
          farmerId: farmerId,
          name: name,
          price: price,
          description: description,
          categoryId: categoryId,
          unitId: unitId,
          imageUrl: uploadedImageUrl,
          harvestDays: harvestDays,
          isPreorder: isPreorder,
          availableQuantity: availableQuantity,
          localImagePaths: localImagePaths,
        );
        await _cacheQueuedProduct(
          id: queuedProduct.id,
          farmerId: farmerId,
          name: name,
          price: price,
          description: description,
          availableQuantity: availableQuantity,
          isPreorder: isPreorder,
          harvestDays: harvestDays,
          localImagePaths: localImagePaths,
          uploadedImageUrl: uploadedImageUrl,
        );
        _updatePendingCount();
        return null;
      }
    } else {
      // Offline: Save to local queue
      final queuedProduct = await _queueService.addProductToQueue(
        farmerId: farmerId,
        name: name,
        price: price,
        description: description,
        categoryId: categoryId,
        unitId: unitId,
        imageUrl: uploadedImageUrl,
        harvestDays: harvestDays,
        isPreorder: isPreorder,
        availableQuantity: availableQuantity,
        localImagePaths: localImagePaths,
      );
      await _cacheQueuedProduct(
        id: queuedProduct.id,
        farmerId: farmerId,
        name: name,
        price: price,
        description: description,
        availableQuantity: availableQuantity,
        isPreorder: isPreorder,
        harvestDays: harvestDays,
        localImagePaths: localImagePaths,
        uploadedImageUrl: uploadedImageUrl,
      );
      _updatePendingCount();
      return null;
    }
  }

  Future<String> _uploadProductToSupabase({
    required String name,
    required double price,
    required String description,
    required String categoryId,
    required String unitId,
    required int harvestDays,
    required bool isPreorder,
    required double availableQuantity,
    required List<String> localImagePaths,
  }) async {
    // Upload local images to Supabase Storage
    List<String> uploadedUrls = [];
    for (final imagePath in localImagePaths) {
      final file = File(imagePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final fileName =
            'product_${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
        final path = 'products/$fileName';

        try {
          await SupabaseConfig.client.storage
              .from('products')
              .uploadBinary(path, bytes);

          final url = SupabaseConfig.client.storage
              .from('products')
              .getPublicUrl(path);
          uploadedUrls.add(url);
        } catch (e) {
          debugPrint('Error uploading image $imagePath: $e');
          // Continue with other images
        }
      }
    }

    // Create product in Supabase
    final imageUrl = uploadedUrls.isNotEmpty ? uploadedUrls.join(',') : null;
    final product = await _productService.createProduct(
      name: name,
      price: price,
      description: description,
      categoryId: categoryId,
      unitId: unitId,
      imageUrl: imageUrl,
      harvestDays: harvestDays,
      isPreorder: isPreorder,
      availableQuantity: availableQuantity,
    );

    return product.productId;
  }

  Future<String> _resolveCategoryId(OfflineProductQueue product) async {
    final raw = (product.categoryIdRef ?? product.categoryId.toString()).trim();
    return BootstrapCacheService.resolveCategoryIdForSync(raw);
  }

  Future<String> _resolveUnitId(OfflineProductQueue product) async {
    final raw = (product.unitIdRef ?? product.unitId.toString()).trim();
    return BootstrapCacheService.resolveUnitIdForSync(raw);
  }

  Future<void> syncPendingProducts() async {
    if (isSyncing.value) return;

    isSyncing.value = true;
    final pending = _queueService.getPendingProducts();

    for (final product in pending) {
      try {
        final online = await isOnline();
        if (!online) {
          debugPrint('📡 Sync interrupted: Connection lost');
          break; 
        }

        debugPrint('🚀 Syncing product: ${product.name} (${product.id})');

        final resolvedCategoryId = await _resolveCategoryId(product);
        final resolvedUnitId = await _resolveUnitId(product);

        // Verify resolved IDs are UUIDs (required by Supabase)
        if (resolvedCategoryId.length < 30 || resolvedUnitId.length < 30) {
          throw Exception('Could not resolve valid UUIDs for category or unit. Category: $resolvedCategoryId, Unit: $resolvedUnitId');
        }

        await _uploadProductToSupabase(
          name: product.name,
          price: product.price,
          description: product.description,
          categoryId: resolvedCategoryId,
          unitId: resolvedUnitId,
          harvestDays: product.harvestDays,
          isPreorder: product.isPreorder,
          availableQuantity: product.availableQuantity.toDouble(),
          localImagePaths: product.localImagePaths,
        );

        // Mark as synced and clear local error
        await _queueService.markAsSynced(product.id);
        await _queueService.setSyncError(product.id, null);
        await _cacheService.removeCachedProduct(product.id);
        
        debugPrint('✅ Sync successful for: ${product.name}');
      } catch (e) {
        // Record error but continue with next product
        await _queueService.setSyncError(product.id, e.toString());
        debugPrint('❌ Sync failed for ${product.name}: $e');
      }
    }

    _updatePendingCount();
    isSyncing.value = false;
  }

  List<OfflineProductQueue> getPendingProducts() {
    return _queueService.getPendingProducts();
  }

  List<OfflineProductQueue> getAllLocalProducts() {
    return _queueService.getAllProducts();
  }

  Future<void> clearSyncedProducts() async {
    await _queueService.clearAllSyncedProducts();
    _updatePendingCount();
  }

  Future<void> retryFailedProduct(String productId) async {
    final pending = _queueService.getPendingProducts();
    final product = pending.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw Exception('Product not found'),
    );

    try {
      final resolvedCategoryId = await _resolveCategoryId(product);
      final resolvedUnitId = await _resolveUnitId(product);

      await _uploadProductToSupabase(
        name: product.name,
        price: product.price,
        description: product.description,
        categoryId: resolvedCategoryId,
        unitId: resolvedUnitId,
        harvestDays: product.harvestDays,
        isPreorder: product.isPreorder,
        availableQuantity: product.availableQuantity.toDouble(),
        localImagePaths: product.localImagePaths,
      );

      await _queueService.markAsSynced(productId);
      await _cacheService.removeCachedProduct(productId);
      _updatePendingCount();
    } catch (e) {
      await _queueService.setSyncError(productId, e.toString());
      rethrow;
    }
  }
}
