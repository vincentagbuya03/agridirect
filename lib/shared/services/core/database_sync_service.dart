import 'dart:async';
import 'package:flutter/foundation.dart';
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

  // Sync configuration
  final Duration _profileSyncInterval = const Duration(minutes: 5);
  final Duration _imageSyncInterval = const Duration(minutes: 10);
  final Duration _registrationSyncInterval = const Duration(minutes: 3);

  // Sync state
  bool _isSyncing = false;
  String? _lastSyncError;
  DateTime? _lastProfileSync;
  DateTime? _lastImageSync;
  DateTime? _lastRegistrationSync;

  bool get isSyncing => _isSyncing;
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

    if (syncProfiles) {
      _profileSyncTimer?.cancel();
      _profileSyncTimer = Timer.periodic(_profileSyncInterval, (_) {
        this.syncProfiles();
      });
      // Sync immediately on start
      this.syncProfiles();
    }

    if (syncImages) {
      _imageSyncTimer?.cancel();
      _imageSyncTimer = Timer.periodic(_imageSyncInterval, (_) {
        this.syncImages();
      });
    }

    if (syncRegistrations) {
      _registrationSyncTimer?.cancel();
      _registrationSyncTimer = Timer.periodic(_registrationSyncInterval, (_) {
        this.syncRegistrations();
      });
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
  }

  /// Sync user profiles (name, email, phone, avatar)
  Future<void> syncProfiles() async {
    if (_isSyncing) return;

    try {
      _isSyncing = true;
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
      _isSyncing = false;
      notifyListeners();
    } catch (e) {
      _lastSyncError = 'Profile sync error: $e';
      debugPrint(_lastSyncError);
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Sync image URLs (farmer images, product images, etc)
  Future<void> syncImages() async {
    if (_isSyncing) return;

    try {
      _isSyncing = true;
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
      _isSyncing = false;
      notifyListeners();
    } catch (e) {
      _lastSyncError = 'Image sync error: $e';
      debugPrint(_lastSyncError);
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Sync farmer registration status and documents
  Future<void> syncRegistrations() async {
    if (_isSyncing) return;

    try {
      _isSyncing = true;
      _lastSyncError = null;
      notifyListeners();

      debugPrint('[DatabaseSyncService] Syncing registrations...');

      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      // Fetch farmer registration
      final registration = await _client
          .from('farmer_registrations')
          .select('''
            registration_id, status, 
            farmers(farmer_id, face_photo_path, valid_id_path, farm_name),
            created_at, updated_at
          ''')
          .eq('farmer_id', userId)
          .maybeSingle();

      if (registration != null) {
        debugPrint('[DatabaseSyncService] Registration synced');
      }

      _lastRegistrationSync = DateTime.now();
      _isSyncing = false;
      notifyListeners();
    } catch (e) {
      _lastSyncError = 'Registration sync error: $e';
      debugPrint(_lastSyncError);
      _isSyncing = false;
      notifyListeners();
    }
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
      final products = await _client
          .from('products')
          .select('product_id, main_image_url, gallery_image_urls')
          .eq('created_by', userId)
          .limit(20);

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
    await Future.wait([syncProfiles(), syncImages(), syncRegistrations()]);
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
