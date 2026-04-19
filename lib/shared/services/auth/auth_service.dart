import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../community/analytics_service.dart';

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
  String _userAvatarUrl = '';
  bool _isLoading = false;
  String? _errorMessage;
  String? _registrationStatus; // 'pending', 'approved', 'rejected', or null
  StreamSubscription<String?>? _regStatusSubscription;

  // Standard temporary password for initial account creation
  static const String temporaryPassword = 'AgriDirect_Temp_Auth_123!';

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
  String get userAvatarUrl => _userAvatarUrl;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get needsProfileCompletion => _needsProfileCompletion;
  String get pendingGoogleEmail => _pendingGoogleEmail;
  String get pendingGoogleName => _pendingGoogleName;
  String? get registrationStatus => _registrationStatus;
  SupabaseClient get client => _client;

  static String _sellerKey(String userId) => 'auth.isSeller.$userId';
  static String _adminKey(String userId) => 'auth.isAdmin.$userId';
  static String _nameKey(String userId) => 'auth.userName.$userId';
  static String _avatarKey(String userId) => 'auth.userAvatarUrl.$userId';
  static String _viewModeKey(String userId) => 'auth.isViewingAsFarmer.$userId';
  static String _regStatusKey(String userId) =>
      'auth.registrationStatus.$userId';

  Future<void> _restoreCachedUserState(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isSeller = prefs.getBool(_sellerKey(userId)) ?? _isSeller;
      _isAdmin = prefs.getBool(_adminKey(userId)) ?? _isAdmin;
      _userName = prefs.getString(_nameKey(userId)) ?? _userName;
      _userAvatarUrl = prefs.getString(_avatarKey(userId)) ?? _userAvatarUrl;
      _isViewingAsFarmer =
          prefs.getBool(_viewModeKey(userId)) ?? _isViewingAsFarmer;
      _registrationStatus = prefs.getString(_regStatusKey(userId));
    } catch (e) {
      debugPrint('Failed to restore cached auth state: $e');
    }
  }

  Future<void> _persistCachedUserState() async {
    if (_userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_sellerKey(_userId), _isSeller);
      await prefs.setBool(_adminKey(_userId), _isAdmin);
      await prefs.setString(_nameKey(_userId), _userName);
      await prefs.setString(_avatarKey(_userId), _userAvatarUrl);
      await prefs.setBool(_viewModeKey(_userId), _isViewingAsFarmer);
      if (_registrationStatus != null) {
        await prefs.setString(_regStatusKey(_userId), _registrationStatus!);
      } else {
        await prefs.remove(_regStatusKey(_userId));
      }
    } catch (e) {
      debugPrint('Failed to persist cached auth state: $e');
    }
  }

  void _clearPendingGoogleProfileState() {
    _needsProfileCompletion = false;
    _pendingGoogleUserId = '';
    _pendingGoogleEmail = '';
    _pendingGoogleName = '';
  }

  /// Extract clean error message from exception
  String _extractErrorMessage(dynamic exception) {
    final errString = exception.toString();
    // Check for common error patterns
    if (errString.contains('429') ||
        errString.toLowerCase().contains('too many requests') ||
        errString.toLowerCase().contains('rate limit')) {
      return 'Too many attempts. Please wait a minute and try again.';
    }
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
    // Prevent stale route/UI state after app relaunch.
    _clearPendingGoogleProfileState();

    final user = _client.auth.currentUser;

    // Only proceed if user exists AND email is confirmed
    if (user != null && user.emailConfirmedAt != null) {
      _userId = user.id;
      _userEmail = user.email ?? '';
      _isLoggedIn = true;

      // Use cached state first so offline startup still recognizes seller/admin.
      await _restoreCachedUserState(user.id);

      final connectivity = Connectivity();
      final connectivityResult = await connectivity.checkConnectivity();
      final isOnline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;

      if (!isOnline) {
        final cachedName = _userName.trim();
        _isLoggedIn = true;
        _userEmail = user.email ?? '';
        _userName = cachedName.isNotEmpty
            ? cachedName
            : (user.userMetadata?['name'] as String?) ?? '';
        _isSeller = _isSeller;
        _isAdmin = _isAdmin;
        _isViewingAsFarmer = _isSeller ? _isViewingAsFarmer : false;
        await _persistCachedUserState();
        notifyListeners();
        return;
      }

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
            emailVerified: true,
          );
          profile = await SupabaseDB.getUserProfile(user.id);
        } catch (e) {
          debugPrint('Error creating user profile on initialize: $e');
        }
      }

      // Check if profile is incomplete (missing required fields like phone)
      if (profile != null) {
        final phone = profile['phone'] as String?;
        final isIncompleteProfile = phone == null || phone.isEmpty;

        if (isIncompleteProfile) {
          // User needs to complete their profile
          _needsProfileCompletion = true;
          _pendingGoogleUserId = user.id;
          _pendingGoogleEmail = user.email ?? '';
          _pendingGoogleName = (profile['name'] as String?) ?? '';
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
      _userAvatarUrl = (profile?['avatar_url'] as String?) ?? '';

      // Ensure admin profile exists for known admin emails
      try {
        await SupabaseDB.ensureAdminProfileExists(
          userId: user.id,
          email: user.email ?? '',
        );
      } catch (e) {
        debugPrint('Warning: Could not ensure admin profile: $e');
      }

      // Fetch roles and registration status from database
      try {
        final roles = await SupabaseDB.getUserRoles(user.id);
        _isSeller = roles.contains('seller') || roles.contains('farmer');
        _isAdmin = roles.contains('admin');
        if (!_isSeller) {
          _isViewingAsFarmer = false;
        }

        // Fetch registration status and start watching
        final reg = await SupabaseDB.getFarmerRegistration(user.id);
        _registrationStatus = reg?['status'] as String?;
        _startWatchingRegistrationStatus(user.id);
      } catch (e) {
        debugPrint(
          'Error fetching roles/status on initialize, using cache: $e',
        );
      }

      // If seller status exists locally but sync may have failed, retry
      if (_isSeller) {
        try {
          // Check if farmer record exists in database
          final exists = await SupabaseDB.hasRole(
            userId: user.id,
            roleName: 'seller',
          );
          if (!exists) {
            debugPrint(
              'Seller marked locally but missing in DB, retrying sync...',
            );
            await SupabaseDB.addUserRole(userId: user.id, roleName: 'seller');
          }
        } catch (e) {
          debugPrint('Retry seller sync failed (offline?): $e');
          // Keep isSeller=true locally even if sync fails
        }
      }

      await _persistCachedUserState();
      await AnalyticsService().startSession(userId: user.id);
      notifyListeners();
    } else if (user != null && user.emailConfirmedAt == null) {
      // User exists but email not confirmed - sign them out
      try {
        await _client.auth.signOut();
      } catch (_) {}
    }
  }

  /// Register with email & password - Returns userId if successful
  Future<String?> register({
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
        data: {'name': name, 'phone_number': phoneNumber},
      );

      if (response.user == null) {
        _errorMessage = 'Registration failed';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      final String newUserId = response.user!.id;

      // 🔵 IMPORTANT: Create user profile in DB BEFORE returning
      // This ensures verification codes can be generated (handles foreign key constraint)
      try {
        await SupabaseDB.createUserIfNotExists(
          userId: newUserId,
          email: email,
          name: name,
          phoneNumber: phoneNumber,
          emailVerified: false,
        );
        debugPrint('✅ User profile ensured in DB for registration');
      } catch (e) {
        debugPrint(
          '⚠️ Warning: Failed to create user profile in DB, registration may fail later: $e',
        );
      }

      // Note: With email confirmation enabled, there's no active session here.
      // Sign out so user is not auto-logged in before email confirmation
      try {
        await _client.auth.signOut();
      } catch (_) {}

      // Keep name for profile completion
      _userName = name;
      _userEmail = email;

      _isLoading = false;
      notifyListeners();
      return newUserId;
    } catch (e) {
      debugPrint('Registration error: $e');
      _errorMessage = _extractErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Login with email & password
  Future<bool> login({required String email, required String password}) async {
    if (_isLoading) return false;
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
            emailVerified: true,
          );
          profile = await SupabaseDB.getUserProfile(_userId);
        } catch (e) {
          debugPrint('Error creating user profile on login: $e');
        }
      }
      // If profile name is empty, fall back to auth metadata name and fix DB
      String resolvedName = (profile?['name'] as String?) ?? '';
      if (resolvedName.isEmpty) {
        final metaName =
            (response.user!.userMetadata?['name'] as String?) ?? '';
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

      // Ensure admin profile exists for known admin emails
      try {
        await SupabaseDB.ensureAdminProfileExists(
          userId: _userId,
          email: email,
        );
      } catch (e) {
        debugPrint('Warning: Could not ensure admin profile: $e');
      }

      // Fetch roles from user_roles table
      final roles = await SupabaseDB.getUserRoles(_userId);
      _isSeller = roles.contains('seller') || roles.contains('farmer');
      _isAdmin = roles.contains('admin');
      if (!_isSeller) {
        _isViewingAsFarmer = false;
      }

      await _refreshRegistrationStatusFromServer();
      _startWatchingRegistrationStatus(_userId);

      await _persistCachedUserState();
      await AnalyticsService().startSession(userId: _userId);

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

  /// Finalize registration by updating password and phone number
  Future<bool> updateUserPasswordAndPhone({
    required String phoneNumber,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        _errorMessage = 'No active session. Please try again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 1. Update password in Supabase Auth
      await _client.auth.updateUser(UserAttributes(password: password));

      // 2. Update name and phone in database
      await SupabaseDB.createUserIfNotExists(
        userId: user.id,
        email: user.email ?? '',
        name: _userName,
        phoneNumber: phoneNumber,
      );

      // 3. Re-fetch user to verify state
      await initialize();

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
    _isSeller = true;
    _isViewingAsFarmer = true;
    await _persistCachedUserState();
    notifyListeners();

    try {
      await SupabaseDB.addUserRole(userId: _userId, roleName: 'seller');
    } catch (e) {
      debugPrint('Failed to sync seller role: $e');
    }
  }

  void switchToFarmerMode() {
    if (_isSeller) {
      _isViewingAsFarmer = true;
      _persistCachedUserState();
      notifyListeners();
    }
  }

  void switchToCustomerMode() {
    _isViewingAsFarmer = false;
    _persistCachedUserState();
    notifyListeners();
  }

  /// Manually refresh the farmer registration status
  Future<void> refreshRegistrationStatus() async {
    if (_userId.isEmpty) return;
    try {
      final reg = await SupabaseDB.getFarmerRegistration(_userId);
      _registrationStatus = reg?['status'] as String?;
      await _persistCachedUserState();
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing registration status: $e');
    }
  }

  Future<void> _refreshRegistrationStatusFromServer() async {
    if (_userId.isEmpty) return;
    try {
      final reg = await SupabaseDB.getFarmerRegistration(_userId);
      _registrationStatus = reg?['status'] as String?;
      await _persistCachedUserState();
    } catch (e) {
      debugPrint('Error fetching registration status: $e');
    }
  }

  void _startWatchingRegistrationStatus(String userId) {
    _regStatusSubscription?.cancel();
    _regStatusSubscription = SupabaseDB.watchFarmerRegistrationStatus(userId)
        .listen((status) {
          if (status != _registrationStatus) {
            _registrationStatus = status;
            _persistCachedUserState();
            notifyListeners();
          }
        });
  }

  /// Check if a user's email has been confirmed by attempting sign-in.
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
        final userId = response.user!.id;
        try {
          await SupabaseDB.createUserIfNotExists(
            userId: userId,
            email: email,
            name: name,
            phoneNumber: phoneNumber,
          );
        } catch (e) {
          debugPrint('ERROR ensuring user profile: $e');
        }
        await _client.auth.signOut();
        return true;
      }

      if (response.user != null) {
        await _client.auth.signOut();
      }
      return false;
    } catch (e) {
      debugPrint('Email confirmation check: $e');
      return false;
    }
  }

  /// Sign in / sign up with Google
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (kIsWeb) {
        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: kDebugMode
              ? 'http://localhost:3000/auth/callback'
              : 'https://agridirect.vercel.app/auth/callback',
        );
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        return await _signInWithGoogleMobile();
      }
    } catch (e) {
      _errorMessage = 'Google Sign-In failed: ${_extractErrorMessage(e)}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> _signInWithGoogleMobile() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        _errorMessage = 'Sign-in cancelled';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      if (googleAuth.idToken == null) {
        _errorMessage = 'Failed to get authentication token from Google';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      if (response.user == null) {
        _errorMessage = 'Authentication with Supabase failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final user = response.user!;
      var profile = await SupabaseDB.getUserProfile(user.id);
      final isIncompleteProfile =
          profile == null ||
          profile['phone'] == null ||
          (profile['phone'] as String).isEmpty;

      if (isIncompleteProfile) {
        _needsProfileCompletion = true;
        _pendingGoogleUserId = user.id;
        _pendingGoogleEmail = user.email ?? '';
        _pendingGoogleName =
            user.userMetadata?['full_name'] ?? googleUser.displayName ?? '';
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _userId = user.id;
      _userEmail = user.email ?? '';
      _userName = (profile['name'] as String?) ?? '';

      _userAvatarUrl = (profile['avatar_url'] as String?) ?? '';
      _isLoggedIn = true;

      final roles = await SupabaseDB.getUserRoles(_userId);
      _isSeller = roles.contains('seller') || roles.contains('farmer');
      _isAdmin = roles.contains('admin');

      await _refreshRegistrationStatusFromServer();
      _startWatchingRegistrationStatus(_userId);

      await _persistCachedUserState();
      await AnalyticsService().startSession(userId: _userId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _extractGoogleError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String _extractGoogleError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('12501') ||
        msg.contains('canceled') ||
        msg.contains('cancelled')) {
      return 'Sign-in cancelled by user';
    }
    if (msg.contains('10') || msg.contains('developer_error')) {
      return 'Configuration error. Check SHA-1.';
    }
    if (msg.contains('7') || msg.contains('network_error')) {
      return 'Network error.';
    }
    return 'Google Sign-In failed.';
  }

  Future<bool> completeGoogleProfile({
    required String phoneNumber,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (password.trim().isEmpty) {
        _errorMessage = 'Please create a password';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await SupabaseDB.createUserIfNotExists(
        userId: _pendingGoogleUserId,
        email: _pendingGoogleEmail,
        name: _pendingGoogleName,
        phoneNumber: phoneNumber,
        emailVerified: true,
      );

      await _client.auth.updateUser(UserAttributes(password: password));

      final roles = await SupabaseDB.getUserRoles(_pendingGoogleUserId);
      _userId = _pendingGoogleUserId;
      _userEmail = _pendingGoogleEmail;
      _userName = _pendingGoogleName;
      _needsProfileCompletion = false;
      _isSeller = roles.contains('seller') || roles.contains('farmer');
      _isAdmin = roles.contains('admin');
      _isLoggedIn = true;

      await _refreshRegistrationStatusFromServer();
      _startWatchingRegistrationStatus(_userId);

      await _persistCachedUserState();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to save profile: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> resetPassword({required String email}) async {
    try {
      final redirectUrl = kIsWeb
          ? '${Uri.base.origin}/reset-password'
          : 'com.agridirect://reset-password';
      await _client.auth.resetPasswordForEmail(email, redirectTo: redirectUrl);
    } catch (e) {
      _errorMessage = _extractErrorMessage(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      if (_userId.isNotEmpty) {
        await AnalyticsService().endSession(userId: _userId);
      }

      try {
        await GoogleSignIn().signOut();
      } catch (_) {}

      _regStatusSubscription?.cancel();
      _regStatusSubscription = null;
      await _client.auth.signOut();
      _isLoggedIn = false;
      _userId = '';
      _userName = '';
      _userEmail = '';
      _isSeller = false;
      _isViewingAsFarmer = false;
      _isAdmin = false;
      _registrationStatus = null;
      _clearPendingGoogleProfileState();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Logout failed: $e';
      notifyListeners();
    }
  }
}
