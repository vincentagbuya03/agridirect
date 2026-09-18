import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'farmer_strings.dart';

/// Lightweight, reactive localization controller for Farmer-First UI.
/// Persists the selected language ('en' | 'fil') in SharedPreferences.
class FarmerLocaleService extends ChangeNotifier {
  static final FarmerLocaleService _instance = FarmerLocaleService._internal();
  factory FarmerLocaleService() => _instance;
  static FarmerLocaleService get instance => _instance;

  FarmerLocaleService._internal();

  static const String _prefKey = 'farmer_app_language';
  String _currentLanguage = 'en';
  bool _initialized = false;

  String get currentLanguage => _currentLanguage;
  bool get isFilipino => _currentLanguage == 'fil';
  bool get isEnglish => _currentLanguage == 'en';

  /// Initialize and load saved language preference
  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentLanguage = prefs.getString(_prefKey) ?? 'en';
      _initialized = true;
      notifyListeners();
    } catch (_) {
      _currentLanguage = 'en';
      _initialized = true;
    }
  }

  /// Explicitly set the language ('en' or 'fil')
  Future<void> setLanguage(String lang) async {
    if (_currentLanguage == lang) return;
    _currentLanguage = lang;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, lang);
    } catch (_) {}
  }

  /// Toggle between English ('en') and Filipino ('fil')
  Future<void> toggleLanguage() async {
    final next = _currentLanguage == 'en' ? 'fil' : 'en';
    await setLanguage(next);
  }

  /// Alias for toggleLanguage
  Future<void> toggleLocale() => toggleLanguage();

  /// Helper to get translated string for current language
  String t(String key) => FarmerStrings.get(key, lang: _currentLanguage);

  /// Helper to return Filipino or English based on active language
  String s(String en, String fil) => isFilipino ? fil : en;

  /// Shorthand static helpers
  static String tr(String key) => _instance.t(key);
  static String str(String en, String fil) => _instance.s(en, fil);
}
