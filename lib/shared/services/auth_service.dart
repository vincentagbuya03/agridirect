import 'package:flutter/material.dart';
import 'supabase_config.dart';

/// Auth Service using Supabase
/// Handles user registration, login, logout, and seller mode
class AuthService extends ChangeNotifier {
  // Singleton
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _client = SupabaseConfig.client;
  bool _isLoggedIn = false;
  bool _isSeller = false;
  bool _isViewingAsFarmer = false;
  String _userName = '';
  String _userEmail = '';
  String _userId = '';
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoggedIn => _isLoggedIn;
  bool get isSeller => _isSeller;
  bool get isViewingAsFarmer => _isViewingAsFarmer;
  String get userName => _userName;
  String get userEmail => _userEmail;
  String get userId => _userId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  get client => _client;

  /// Extract clean error message from exception
  String _extractErrorMessage(dynamic exception) {
    final errString = exception.toString();
    // Check for common error patterns
    if (errString.contains('Invalid login credentials')) {
      return 'Invalid email or password';
    }
    if (errString.contains('email rate limit')) {
      return 'Too many signup attempts. Please wait a few minutes.';
    }
    if (errString.contains('already registered')) {
      return 'This email is already registered';
    }
    if (errString.contains('invalid_credentials')) {
      return 'Invalid email or password';
    }
    if (errString.contains('Email not confirmed')) {
      return 'Please confirm your email before logging in. Check your inbox.';
    }
    // Default: extract message between quotes if possible
    final match = RegExp(r"message:'([^']*)").firstMatch(errString);
    if (match != null) {
      return match.group(1) ?? 'An error occurred';
    }
    return 'An error occurred. Please try again.';
  }

  /// Initialize auth on app startup
  /// Only logs in if user exists AND email is confirmed
  Future<void> initialize() async {
    final user = _client.auth.currentUser;

    // Only proceed if user exists AND email is confirmed
    if (user != null && user.emailConfirmedAt != null) {
      _userId = user.id;
      _userEmail = user.email ?? '';
      _isLoggedIn = true;

      // Fetch user profile from database
      final profile = await SupabaseDB.getUserProfile(user.id);
      if (profile != null) {
        _userName = profile['name'] ?? '';
        _isSeller = profile['is_seller'] ?? false;
      }
      notifyListeners();
    } else if (user != null && user.emailConfirmedAt == null) {
      // User exists but email not confirmed - sign them out
      try {
        await _client.auth.signOut();
      } catch (_) {}
    }
  }

  /// Register with email & password
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Sign up with Supabase Auth (pass name in metadata so the DB trigger can use it)
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );

      if (response.user == null) {
        _errorMessage = 'Registration failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Save user profile in database but do NOT log them in yet
      // They must confirm their email first
      final userId = response.user!.id;

      // Ensure user profile exists in database (fallback if trigger didn't fire)
      try {
        await SupabaseDB.createUserIfNotExists(
          userId: userId,
          email: email,
          name: name,
        );
      } catch (dbError) {
        debugPrint('DB fallback error (non-fatal): $dbError');
        // Non-fatal: the DB trigger should handle user creation
      }

      // Sign out so user is not auto-logged in before email confirmation
      try {
        await _client.auth.signOut();
      } catch (_) {}

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Registration error: $e');
      _errorMessage = _extractErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Login with email & password
  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        _errorMessage = 'Login failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Check if email is confirmed
      if (response.user!.emailConfirmedAt == null) {
        _errorMessage =
            'Please confirm your email before logging in. Check your inbox.';
        await _client.auth.signOut();
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _userId = response.user!.id;
      _userEmail = email;
      _isLoggedIn = true;

      // Fetch user profile
      final profile = await SupabaseDB.getUserProfile(_userId);
      if (profile != null) {
        _userName = profile['name'] ?? '';
        _isSeller = profile['is_seller'] ?? false;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _extractErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Register as a seller (one-time activation)
  Future<void> startSelling() async {
    try {
      await SupabaseDB.updateSellerStatus(userId: _userId, isSeller: true);
      _isSeller = true;
      _isViewingAsFarmer = true;
      notifyListeners();
    } catch (e) {
      _errorMessage =
          'Failed to activate seller mode: ${_extractErrorMessage(e)}';
      notifyListeners();
    }
  }

  /// Switch to farmer view (no DB change, just UI mode)
  void switchToFarmerMode() {
    if (_isSeller) {
      _isViewingAsFarmer = true;
      notifyListeners();
    }
  }

  /// Switch to customer view (no DB change, just UI mode)
  void switchToCustomerMode() {
    _isViewingAsFarmer = false;
    notifyListeners();
  }

  /// Reset password - sends reset link to email
  Future<void> resetPassword({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'com.agridirect://reset-password',
      );
    } catch (e) {
      _errorMessage = _extractErrorMessage(e);
      notifyListeners();
      rethrow;
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      await _client.auth.signOut();
      _isLoggedIn = false;
      _isSeller = false;
      _isViewingAsFarmer = false;
      _userName = '';
      _userEmail = '';
      _userId = '';
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Logout failed: $e';
      notifyListeners();
    }
  }
}
