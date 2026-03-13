import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase/src/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  bool _isAdmin = false;
  String _userName = '';
  String _userEmail = '';
  String _userId = '';
  bool _isLoading = false;
  String? _errorMessage;

  // Pending Google sign-in state (new user needs to complete profile)
  bool _needsProfileCompletion = false;
  String _pendingGoogleUserId = '';
  String _pendingGoogleEmail = '';
  String _pendingGoogleName = '';

  bool get isLoggedIn => _isLoggedIn;
  bool get isSeller => _isSeller;
  bool get isViewingAsFarmer => _isViewingAsFarmer;
  bool get isAdmin => _isAdmin;
  String get userName => _userName;
  String get userEmail => _userEmail;
  String get userId => _userId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get needsProfileCompletion => _needsProfileCompletion;
  String get pendingGoogleEmail => _pendingGoogleEmail;
  String get pendingGoogleName => _pendingGoogleName;
  SupabaseClient get client => _client;

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

      // Fetch user profile — if missing, create it from auth metadata
      var profile = await SupabaseDB.getUserProfile(user.id);
      if (profile == null) {
        final metadata = user.userMetadata;
        final metaName = (metadata?['name'] as String?) ?? '';
        final metaPhone = metadata?['phone_number'] as String?;
        try {
          await SupabaseDB.createUserIfNotExists(
            userId: user.id,
            email: user.email ?? '',
            name: metaName,
            phoneNumber: metaPhone,
          );
          profile = await SupabaseDB.getUserProfile(user.id);
        } catch (e) {
          debugPrint('Error creating user profile on initialize: $e');
        }
      }
      // If profile name is empty, fall back to auth metadata name and fix DB
      String resolvedName = (profile?['name'] as String?) ?? '';
      if (resolvedName.isEmpty) {
        final metaName = (user.userMetadata?['name'] as String?) ?? '';
        if (metaName.isNotEmpty) {
          resolvedName = metaName;
          try {
            await SupabaseDB.updateUserName(userId: user.id, name: metaName);
          } catch (e) {
            debugPrint('Error updating user name on initialize: $e');
          }
        }
      }
      _userName = resolvedName;

      // Fetch roles from user_roles table
      final roles = await SupabaseDB.getUserRoles(user.id);
      _isSeller = roles.contains('seller');
      _isAdmin = roles.contains('admin');
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
    String? phoneNumber,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Sign up with Supabase Auth (pass name in metadata so the DB trigger can use it)
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name, 'phone_number': ?phoneNumber},
      );

      if (response.user == null) {
        _errorMessage = 'Registration failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Note: With email confirmation enabled, there's no active session here.
      // The database trigger (handle_new_user) will create the user profile.
      // Client-side insert is skipped because RLS would block it without a session.

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

      // Fetch user profile — if missing, create it from auth metadata
      var profile = await SupabaseDB.getUserProfile(_userId);
      if (profile == null) {
        // Profile doesn't exist yet (trigger missing or checkEmailConfirmed failed)
        final metadata = response.user!.userMetadata;
        final metaName = (metadata?['name'] as String?) ?? '';
        final metaPhone = metadata?['phone_number'] as String?;
        try {
          await SupabaseDB.createUserIfNotExists(
            userId: _userId,
            email: email,
            name: metaName,
            phoneNumber: metaPhone,
          );
          profile = await SupabaseDB.getUserProfile(_userId);
        } catch (e) {
          debugPrint('Error creating user profile on login: $e');
        }
      }
      // If profile name is empty, fall back to auth metadata name and fix DB
      String resolvedName = (profile?['name'] as String?) ?? '';
      if (resolvedName.isEmpty) {
        final metaName = (response.user!.userMetadata?['name'] as String?) ?? '';
        if (metaName.isNotEmpty) {
          resolvedName = metaName;
          try {
            await SupabaseDB.updateUserName(userId: _userId, name: metaName);
          } catch (e) {
            debugPrint('Error updating user name on login: $e');
          }
        }
      }
      _userName = resolvedName;

      // Fetch roles from user_roles table
      final roles = await SupabaseDB.getUserRoles(_userId);
      _isSeller = roles.contains('seller');
      _isAdmin = roles.contains('admin');

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
      await SupabaseDB.addUserRole(userId: _userId, roleName: 'seller');
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

  /// Check if a user's email has been confirmed by attempting sign-in.
  /// If confirmed, ensures user profile exists in the users table, then signs out.
  /// Returns true if email is confirmed.
  Future<bool> checkEmailConfirmed({
    required String email,
    required String password,
    required String name,
    String? phoneNumber,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null && response.user!.emailConfirmedAt != null) {
        // Email is confirmed! Ensure user profile exists in DB
        final userId = response.user!.id;
        try {
          await SupabaseDB.createUserIfNotExists(
            userId: userId,
            email: email,
            name: name,
            phoneNumber: phoneNumber,
          );
          debugPrint('User profile ensured in users table for $email');
        } catch (e) {
          debugPrint('ERROR ensuring user profile after email confirmation: $e');
          // Don't return false — user is still confirmed, profile may exist from trigger
        }

        // Sign out so user can login manually from the login screen
        await _client.auth.signOut();
        return true;
      }

      // Email not confirmed yet - sign out
      if (response.user != null) {
        await _client.auth.signOut();
      }
      return false;
    } catch (e) {
      // Sign-in failed — likely "Email not confirmed" error
      debugPrint('Email confirmation check: $e');
      return false;
    }
  }

  /// Sign in / sign up with Google (uses Supabase OAuth for cross-platform support)
  ///
  /// IMPORTANT: Before using this, configure Supabase Google OAuth:
  /// 1. Go to Supabase Dashboard → Authentication → Providers → Google
  /// 2. Enable Google and add your Web Client ID from Google Cloud Console
  /// 3. Go to Authentication → URL Configuration
  /// 4. Add your redirect URL: https://yourdomain.com/auth/callback
  /// 5. Update the redirectTo URL below to match your deployment domain
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (kIsWeb) {
        // WEB: Use Supabase OAuth (opens Google login in same tab)
        try {
          await _client.auth.signInWithOAuth(
            OAuthProvider.google,
            redirectTo: 'https://argidirect.vercel.app/auth/callback',
          );
        } catch (e) {
          // OAuth will redirect if successful, so if we catch an error, it's real
          debugPrint('Web OAuth error: $e');
          _errorMessage = 'Google Sign-In failed: ${_extractErrorMessage(e)}';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        // Return true immediately — the page will redirect to Google
        // No error should show during this process
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        // MOBILE: Use native Google Sign-In
        return await _signInWithGoogleMobile();
      }
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      _errorMessage = 'Google Sign-In failed: ${_extractErrorMessage(e)}';
      _isLoggedIn = false;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign in with Google on Mobile using native GoogleSignIn
  Future<bool> _signInWithGoogleMobile() async {
    try {
      // Initialize once before first use
      await GoogleSignIn.instance.initialize(
        serverClientId:
            '971354937445-ism5m8bol1l18qqfndkbalj16tl73tiv.apps.googleusercontent.com',
      );

      // Trigger the interactive sign-in flow
      final googleUser = await GoogleSignIn.instance.authenticate();

      // Check if user cancelled sign-in
      if (googleUser == null) {
        _errorMessage = 'Sign-in cancelled';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Get tokens
      final idToken = googleUser.authentication.idToken;
      final auth = await googleUser.authorizationClient
          .authorizationForScopes(['email', 'profile']);
      final accessToken = auth?.accessToken;

      if (idToken == null) {
        _errorMessage = 'Failed to get Google ID token';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Sign in to Supabase with the Google ID token
      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user == null) {
        _errorMessage = 'Google sign-in failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final user = response.user!;
      _userId = user.id;
      _userEmail = user.email ?? googleUser.email;

      final displayName =
          googleUser.displayName ?? googleUser.email.split('@')[0];

      // Check if this is a new user
      final existingProfile = await SupabaseDB.getUserProfile(_userId);

      if (existingProfile == null) {
        // New user — store pending data and ask them to complete their profile
        _pendingGoogleUserId = _userId;
        _pendingGoogleEmail = _userEmail;
        _pendingGoogleName = displayName;
        _needsProfileCompletion = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      // Existing user — proceed normally
      _userName = (existingProfile['name'] as String?)?.isNotEmpty == true
          ? existingProfile['name'] as String
          : displayName;

      // Fetch roles
      final roles = await SupabaseDB.getUserRoles(_userId);
      _isSeller = roles.contains('seller');
      _isAdmin = roles.contains('admin');

      _isLoggedIn = true;
      _needsProfileCompletion = false;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Mobile Google sign-in error: $e');
      _errorMessage = _extractGoogleError(e);
      _isLoggedIn = false;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Extract meaningful error from Google Sign-In exceptions
  String _extractGoogleError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('12501') || msg.contains('canceled')) {
      return 'Sign-in cancelled';
    }
    if (msg.contains('10') || msg.contains('DEVELOPER_ERROR')) {
      return 'Google Sign-In not configured. Check SHA-1 fingerprint.';
    }
    if (msg.contains('7') || msg.contains('NETWORK_ERROR')) {
      return 'Network error. Please check your connection.';
    }
    if (msg.contains('UnsupportedError')) {
      return 'Google Sign-In is not supported on this device.';
    }
    return 'Google Sign-In error: $msg';
  }

  /// Complete profile for new Google sign-in users
  /// Called after they fill in phone number (and optional password)
  Future<bool> completeGoogleProfile({
    required String phoneNumber,
    String? password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Create user in the database now
      await SupabaseDB.createUserIfNotExists(
        userId: _pendingGoogleUserId,
        email: _pendingGoogleEmail,
        name: _pendingGoogleName,
        phoneNumber: phoneNumber,
      );

      // If user wants a password for email/password login, update it
      if (password != null && password.isNotEmpty) {
        await _client.auth.updateUser(UserAttributes(password: password));
      }

      // Finalize auth state
      _userId = _pendingGoogleUserId;
      _userEmail = _pendingGoogleEmail;
      _userName = _pendingGoogleName;
      _needsProfileCompletion = false;
      _pendingGoogleUserId = '';
      _pendingGoogleEmail = '';
      _pendingGoogleName = '';

      final roles = await SupabaseDB.getUserRoles(_userId);
      _isSeller = roles.contains('seller');
      _isAdmin = roles.contains('admin');

      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Complete Google profile error: $e');
      _errorMessage = 'Failed to save profile. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
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
      // Sign out from mobile GoogleSignIn if not web
      if (!kIsWeb) {
        await GoogleSignIn.instance.signOut();
      }

      await _client.auth.signOut();
      _isLoggedIn = false;
      _isSeller = false;
      _isAdmin = false;
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
