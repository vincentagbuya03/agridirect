import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

/// Manages automatic database synchronization
class DatabaseSyncService extends ChangeNotifier {
  static final DatabaseSyncService _instance = DatabaseSyncService._internal();

  factory DatabaseSyncService() => _instance;

  DatabaseSyncService._internal();

  final _client = SupabaseConfig.client;

  // Sync intervals and timers
  Timer? _profileSyncTimer;
  Timer? _imageSyncTimer;
  Timer? _registrationSyncTimer;
  Timer? _realtimeDebounceTimer;

  // Realtime channels
  RealtimeChannel? _userChannel;
  RealtimeChannel? _farmerChannel;
  RealtimeChannel? _registrationChannel;
  RealtimeChannel? _productChannel;

  String? _activeUserId;
  String? _activeFarmerId;

  // Sync configuration
  final Duration _profileSyncInterval = const Duration(minutes: 5);
  final Duration _imageSyncInterval = const Duration(minutes: 10);
  final Duration _registrationSyncInterval = const Duration(minutes: 3);

  // Sync state
  bool _isProfileSyncing = false;
  bool _isImageSyncing = false;
  bool _isRegistrationSyncing = false;
  String? _lastSyncError;
  DateTime? _lastProfileSync;
  DateTime? _lastImageSync;
  DateTime? _lastRegistrationSync;

  bool get isSyncing =>
      _isProfileSyncing || _isImageSyncing || _isRegistrationSyncing;
  String? get lastSyncError => _lastSyncError;
  DateTime? get lastProfileSync => _lastProfileSync;
  DateTime? get lastImageSync => _lastImageSync;
  DateTime? get lastRegistrationSync => _lastRegistrationSync;

  /// Start automatic syncing (call this on app initialization)
  void startAutoSync({
    bool syncProfiles = true,
    bool syncImages = true,
    bool syncRegistrations = true,
  }) {
    debugPrint('[DatabaseSyncService] Starting auto sync...');

    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      debugPrint(
        '[DatabaseSyncService] No logged in user. Skipping auto sync.',
      );
      return;
    }

    _activeUserId = userId;
    unawaited(
      _configureRealtimeSync(
        userId: userId,
        syncProfiles: syncProfiles,
        syncImages: syncImages,
        syncRegistrations: syncRegistrations,
      ),
    );

    if (syncProfiles) {
      _profileSyncTimer?.cancel();
      _profileSyncTimer = Timer.periodic(_profileSyncInterval, (_) {
        this.syncProfiles();
      });
      // Sync immediately on start
      unawaited(this.syncProfiles());
    }

    if (syncImages) {
      _imageSyncTimer?.cancel();
      _imageSyncTimer = Timer.periodic(_imageSyncInterval, (_) {
        this.syncImages();
      });
      // Sync immediately on start
      unawaited(this.syncImages());
    }

    if (syncRegistrations) {
      _registrationSyncTimer?.cancel();
      _registrationSyncTimer = Timer.periodic(_registrationSyncInterval, (_) {
        this.syncRegistrations();
      });
      // Sync immediately on start
      unawaited(this.syncRegistrations());
    }
  }

  /// Stop all automatic syncing
  void stopAutoSync() {
    debugPrint('[DatabaseSyncService] Stopping auto sync...');
    _profileSyncTimer?.cancel();
    _imageSyncTimer?.cancel();
    _registrationSyncTimer?.cancel();
    _profileSyncTimer = null;
    _imageSyncTimer = null;
    _registrationSyncTimer = null;
    _realtimeDebounceTimer?.cancel();
    _realtimeDebounceTimer = null;

    _userChannel?.unsubscribe();
    _farmerChannel?.unsubscribe();
    _registrationChannel?.unsubscribe();
    _productChannel?.unsubscribe();

    _userChannel = null;
    _farmerChannel = null;
    _registrationChannel = null;
    _productChannel = null;

    _activeUserId = null;
    _activeFarmerId = null;
  }

  /// Sync user profiles (name, email, phone, avatar)
  Future<void> syncProfiles() async {
    if (_isProfileSyncing) return;

    try {
      _isProfileSyncing = true;
      _lastSyncError = null;
      notifyListeners();

      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint(
          '[DatabaseSyncService] No user logged in, skipping profile sync',
        );
        return;
      }

      debugPrint('[DatabaseSyncService] Syncing profiles...');

      // Fetch user profile
      final userProfile = await _client
          .from('users')
          .select('user_id, name, email, phone, avatar_url, updated_at')
          .eq('user_id', userId)
          .maybeSingle();

      if (userProfile != null) {
        debugPrint(
          '[DatabaseSyncService] Profile synced: ${userProfile['name']}',
        );
      }

      _lastProfileSync = DateTime.now();
      _isProfileSyncing = false;
      notifyListeners();
    } catch (e) {
      _lastSyncError = 'Profile sync error: $e';
      debugPrint(_lastSyncError);
      _isProfileSyncing = false;
      notifyListeners();
    }
  }

  /// Sync image URLs (farmer images, product images, etc)
  Future<void> syncImages() async {
    if (_isImageSyncing) return;

    try {
      _isImageSyncing = true;
      _lastSyncError = null;
      notifyListeners();

      debugPrint('[DatabaseSyncService] Syncing images...');

      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      // Sync farmer images
      await _syncFarmerImages(userId);

      // Sync product images
      await _syncProductImages(userId);

      _lastImageSync = DateTime.now();
      _isImageSyncing = false;
      notifyListeners();
    } catch (e) {
      _lastSyncError = 'Image sync error: $e';
      debugPrint(_lastSyncError);
      _isImageSyncing = false;
      notifyListeners();
    }
  }

  /// Sync farmer registration status and documents
  Future<void> syncRegistrations() async {
    if (_isRegistrationSyncing) return;

    try {
      _isRegistrationSyncing = true;
      _lastSyncError = null;
      notifyListeners();

      debugPrint('[DatabaseSyncService] Syncing registrations...');

      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      final farmerId = await _resolveCurrentFarmerId(userId);
      if (farmerId == null) {
        _lastRegistrationSync = DateTime.now();
        _isRegistrationSyncing = false;
        notifyListeners();
        return;
      }

      // Fetch farmer registration
      final registration = await _client
          .from('farmer_registrations')
          .select('''
            registration_id, status, 
            farmers(farmer_id, face_photo_path, valid_id_path, farm_name),
            created_at, updated_at
          ''')
          .eq('farmer_id', farmerId)
          .maybeSingle();

      if (registration != null) {
        debugPrint('[DatabaseSyncService] Registration synced');
      }

      _lastRegistrationSync = DateTime.now();
      _isRegistrationSyncing = false;
      notifyListeners();
    } catch (e) {
      _lastSyncError = 'Registration sync error: $e';
      debugPrint(_lastSyncError);
      _isRegistrationSyncing = false;
      notifyListeners();
    }
  }

  Future<String?> _resolveCurrentFarmerId(String userId) async {
    final farmer = await _client
        .from('farmers')
        .select('farmer_id')
        .eq('user_id', userId)
        .maybeSingle();
    final farmerId = farmer?['farmer_id']?.toString();
    if (farmerId != null && farmerId.isNotEmpty) {
      _activeFarmerId = farmerId;
    }
    return farmerId;
  }

  Future<void> _configureRealtimeSync({
    required String userId,
    required bool syncProfiles,
    required bool syncImages,
    required bool syncRegistrations,
  }) async {
    _userChannel?.unsubscribe();
    _farmerChannel?.unsubscribe();
    _registrationChannel?.unsubscribe();
    _productChannel?.unsubscribe();

    _activeFarmerId = await _resolveCurrentFarmerId(userId);

    _userChannel = _client
        .channel('db-sync-users-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users',
          callback: (payload) {
            final newId = payload.newRecord['user_id']?.toString();
            final oldId = payload.oldRecord['user_id']?.toString();
            if (newId == userId || oldId == userId) {
              _scheduleRealtimeSync(
                syncProfiles: syncProfiles,
                syncImages: syncImages,
                syncRegistrations: false,
              );
            }
          },
        )
        .subscribe();

    _farmerChannel = _client
        .channel('db-sync-farmers-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'farmers',
          callback: (payload) {
            final newUserId = payload.newRecord['user_id']?.toString();
            final oldUserId = payload.oldRecord['user_id']?.toString();
            final newFarmerId = payload.newRecord['farmer_id']?.toString();

            if (newFarmerId != null && newFarmerId.isNotEmpty) {
              _activeFarmerId = newFarmerId;
            }

            if (newUserId == userId || oldUserId == userId) {
              _scheduleRealtimeSync(
                syncProfiles: false,
                syncImages: syncImages,
                syncRegistrations: syncRegistrations,
              );
            }
          },
        )
        .subscribe();

    _registrationChannel = _client
        .channel('db-sync-registrations-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'farmer_registrations',
          callback: (payload) {
            if (!syncRegistrations) return;

            final registrationFarmerId =
                payload.newRecord['farmer_id']?.toString() ??
                payload.oldRecord['farmer_id']?.toString();

            if (registrationFarmerId != null &&
                registrationFarmerId.isNotEmpty &&
                registrationFarmerId == _activeFarmerId) {
              _scheduleRealtimeSync(
                syncProfiles: false,
                syncImages: false,
                syncRegistrations: true,
              );
            }
          },
        )
        .subscribe();

    _productChannel = _client
        .channel('db-sync-products-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'products',
          callback: (payload) {
            if (!syncImages) return;

            final productFarmerId =
                payload.newRecord['farmer_id']?.toString() ??
                payload.oldRecord['farmer_id']?.toString();

            if (productFarmerId != null &&
                productFarmerId.isNotEmpty &&
                productFarmerId == _activeFarmerId) {
              _scheduleRealtimeSync(
                syncProfiles: false,
                syncImages: true,
                syncRegistrations: false,
              );
            }
          },
        )
        .subscribe();

    debugPrint('[DatabaseSyncService] Realtime sync subscriptions active');
  }

  void _scheduleRealtimeSync({
    required bool syncProfiles,
    required bool syncImages,
    required bool syncRegistrations,
  }) {
    _realtimeDebounceTimer?.cancel();
    _realtimeDebounceTimer = Timer(const Duration(milliseconds: 700), () async {
      if (syncProfiles) {
        await this.syncProfiles();
      }
      if (syncImages) {
        await this.syncImages();
      }
      if (syncRegistrations) {
        await this.syncRegistrations();
      }
    });
  }

  /// Internal: Sync farmer-specific images
  Future<void> _syncFarmerImages(String userId) async {
    try {
      final farmers = await _client
          .from('farmers')
          .select('farmer_id, user_id, image_url, farm_name')
          .eq('user_id', userId)
          .limit(1);

      if (farmers.isNotEmpty) {
        debugPrint('[DatabaseSyncService] Farmer image synced');
      }
    } catch (e) {
      debugPrint('[DatabaseSyncService] Farmer image sync failed: $e');
    }
  }

  /// Internal: Sync product images
  Future<void> _syncProductImages(String userId) async {
    try {
      final farmerId = _activeFarmerId ?? await _resolveCurrentFarmerId(userId);
      if (farmerId == null || farmerId.isEmpty) {
        return;
      }

      final products = await _client
          .from('products')
          .select('product_id, farmer_id, updated_at')
          .eq('farmer_id', farmerId)
          .limit(20);

      final productIds = products
          .map((p) => p['product_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      if (productIds.isNotEmpty) {
        await _client
            .from('product_images')
            .select('image_id, product_id, image_url, sort_order')
            .inFilter('product_id', productIds)
            .limit(200);
      }

      if (products.isNotEmpty) {
        debugPrint(
          '[DatabaseSyncService] Synced ${products.length} product images',
        );
      }
    } catch (e) {
      debugPrint('[DatabaseSyncService] Product image sync failed: $e');
    }
  }

  /// Manually trigger a full sync
  Future<void> syncAll() async {
    await syncProfiles();
    await syncImages();
    await syncRegistrations();
  }

  /// Clear sync state
  void clearSyncState() {
    _lastProfileSync = null;
    _lastImageSync = null;
    _lastRegistrationSync = null;
    _lastSyncError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopAutoSync();
    super.dispose();
  }
}
