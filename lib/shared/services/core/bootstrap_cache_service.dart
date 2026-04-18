import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../commerce/product_service.dart';

/// Seeds and refreshes app metadata cache used by first-run/offline flows.
class BootstrapCacheService {
  static const String cachedCategoriesKey = 'cached_product_categories_v1';
  static const String cachedUnitsKey = 'cached_product_units_v1';

  static const List<Map<String, dynamic>> _defaultCategories = [
    {'id': '1', 'name': 'Vegetables'},
    {'id': '2', 'name': 'Fruits'},
    {'id': '3', 'name': 'Dairy'},
    {'id': '4', 'name': 'Grains'},
    {'id': '5', 'name': 'Poultry'},
    {'id': '6', 'name': 'Seafood'},
  ];

  static const List<Map<String, dynamic>> _defaultUnits = [
    {'id': '1', 'name': 'Kilogram (kg)'},
    {'id': '2', 'name': 'Gram (g)'},
    {'id': '3', 'name': 'Piece (pc)'},
    {'id': '4', 'name': 'Bundle'},
    {'id': '5', 'name': 'Liter (L)'},
    {'id': '6', 'name': 'Dozen'},
  ];

  static const Map<String, String> _legacyCategoryIdToName = {
    '1': 'Vegetables',
    '2': 'Fruits',
    '3': 'Dairy',
    '4': 'Grains',
    '5': 'Poultry',
    '6': 'Seafood',
  };

  static const Map<String, String> _legacyUnitIdToName = {
    '1': 'Kilogram (kg)',
    '2': 'Gram (g)',
    '3': 'Piece (pc)',
    '4': 'Bundle',
    '5': 'Liter (L)',
    '6': 'Dozen',
  };

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  static bool _isUuid(String value) => _uuidPattern.hasMatch(value);

  static Future<String> resolveCategoryIdForSync(String rawId) async {
    final normalized = rawId.trim();
    if (normalized.isEmpty) return normalized;
    if (_isUuid(normalized)) return normalized;

    final prefs = await SharedPreferences.getInstance();
    var options = _decodeOptionsStatic(prefs.getString(cachedCategoriesKey));
    final legacyName = _legacyCategoryIdToName[normalized];

    if (legacyName != null) {
      for (final option in options) {
        final name = (option['name']?.toString() ?? '').trim().toLowerCase();
        final id = (option['id']?.toString() ?? '').trim();
        if (name == legacyName.toLowerCase() && _isUuid(id)) {
          return id;
        }
      }
    }

    for (final option in options) {
      final id = (option['id']?.toString() ?? '').trim();
      if (_isUuid(id)) return id;
    }

    // If cache still contains legacy defaults, fetch fresh metadata from server.
    options = await _refreshCategoryOptionsFromServer(prefs);

    if (legacyName != null) {
      for (final option in options) {
        final name = (option['name']?.toString() ?? '').trim().toLowerCase();
        final id = (option['id']?.toString() ?? '').trim();
        if (name == legacyName.toLowerCase() && _isUuid(id)) {
          return id;
        }
      }
    }

    for (final option in options) {
      final id = (option['id']?.toString() ?? '').trim();
      if (_isUuid(id)) return id;
    }

    return normalized;
  }

  static Future<String> resolveUnitIdForSync(String rawId) async {
    final normalized = rawId.trim();
    if (normalized.isEmpty) return normalized;
    if (_isUuid(normalized)) return normalized;

    final prefs = await SharedPreferences.getInstance();
    var options = _decodeOptionsStatic(prefs.getString(cachedUnitsKey));
    final legacyName = _legacyUnitIdToName[normalized];

    if (legacyName != null) {
      for (final option in options) {
        final name = (option['name']?.toString() ?? '').trim().toLowerCase();
        final id = (option['id']?.toString() ?? '').trim();
        if (name == legacyName.toLowerCase() && _isUuid(id)) {
          return id;
        }
      }
    }

    for (final option in options) {
      final id = (option['id']?.toString() ?? '').trim();
      if (_isUuid(id)) return id;
    }

    // If cache still contains legacy defaults, fetch fresh metadata from server.
    options = await _refreshUnitOptionsFromServer(prefs);

    if (legacyName != null) {
      for (final option in options) {
        final name = (option['name']?.toString() ?? '').trim().toLowerCase();
        final id = (option['id']?.toString() ?? '').trim();
        if (name == legacyName.toLowerCase() && _isUuid(id)) {
          return id;
        }
      }
    }

    for (final option in options) {
      final id = (option['id']?.toString() ?? '').trim();
      if (_isUuid(id)) return id;
    }

    return normalized;
  }

  static Future<List<Map<String, dynamic>>> _refreshCategoryOptionsFromServer(
    SharedPreferences prefs,
  ) async {
    try {
      final categories = await ProductService().getCategories();
      final payload = categories
          .map((c) => {'id': c.categoryId, 'name': c.name})
          .toList();
      if (payload.isNotEmpty) {
        await prefs.setString(cachedCategoriesKey, jsonEncode(payload));
      }
      return payload;
    } catch (_) {
      return const [];
    }
  }

  static Future<List<Map<String, dynamic>>> _refreshUnitOptionsFromServer(
    SharedPreferences prefs,
  ) async {
    try {
      final units = await ProductService().getUnits();
      final payload = units
          .map((u) => {'id': u.unitId, 'name': u.name})
          .toList();
      if (payload.isNotEmpty) {
        await prefs.setString(cachedUnitsKey, jsonEncode(payload));
      }
      return payload;
    } catch (_) {
      return const [];
    }
  }

  Future<void> primeProductMetadataCache() async {
    final prefs = await SharedPreferences.getInstance();

    await _seedDefaultsIfMissing(prefs: prefs);
    await _refreshFromServerIfAvailable(prefs: prefs);
  }

  Future<void> _seedDefaultsIfMissing({
    required SharedPreferences prefs,
  }) async {
    final currentCategories = _decodeOptions(
      prefs.getString(cachedCategoriesKey),
    );
    final currentUnits = _decodeOptions(prefs.getString(cachedUnitsKey));

    if (currentCategories.isEmpty) {
      await prefs.setString(
        cachedCategoriesKey,
        jsonEncode(_defaultCategories),
      );
      debugPrint('✅ Seeded default categories cache');
    }

    if (currentUnits.isEmpty) {
      await prefs.setString(cachedUnitsKey, jsonEncode(_defaultUnits));
      debugPrint('✅ Seeded default units cache');
    }
  }

  Future<void> _refreshFromServerIfAvailable({
    required SharedPreferences prefs,
  }) async {
    try {
      final service = ProductService();
      final categories = await service.getCategories();
      final units = await service.getUnits();

      if (categories.isNotEmpty) {
        final categoryPayload = categories
            .map((c) => {'id': c.categoryId, 'name': c.name})
            .toList();
        await prefs.setString(cachedCategoriesKey, jsonEncode(categoryPayload));
      }

      if (units.isNotEmpty) {
        final unitPayload = units
            .map((u) => {'id': u.unitId, 'name': u.name})
            .toList();
        await prefs.setString(cachedUnitsKey, jsonEncode(unitPayload));
      }

      if (categories.isNotEmpty || units.isNotEmpty) {
        debugPrint('✅ Refreshed metadata cache from Supabase');
      }
    } catch (e) {
      // Keep seeded defaults/cached values if server refresh fails.
      debugPrint('⚠️ Metadata cache refresh skipped: $e');
    }
  }

  List<Map<String, dynamic>> _decodeOptions(String? rawJson) {
    if (rawJson == null || rawJson.isEmpty) return const [];

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static List<Map<String, dynamic>> _decodeOptionsStatic(String? rawJson) {
    if (rawJson == null || rawJson.isEmpty) return const [];

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
