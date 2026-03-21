import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import '../utils/google_signin_debug_helper.dart';

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

  static String _sellerKey(String userId) => 'auth.isSeller.$userId';
  static String _adminKey(String userId) => 'auth.isAdmin.$userId';
  static String _nameKey(String userId) => 'auth.userName.$userId';

  Future<void> _restoreCachedUserState(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isSeller = prefs.getBool(_sellerKey(userId)) ?? _isSeller;
      _isAdmin = prefs.getBool(_adminKey(userId)) ?? _isAdmin;
      _userName = prefs.getString(_nameKey(userId)) ?? _userName;
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
    } catch (e) {
      debugPrint('Failed to persist cached auth state: $e');
    }
  }

  Future<void> _clearCachedUserState(String userId) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sellerKey(userId));
      await prefs.remove(_adminKey(userId));
      await prefs.remove(_nameKey(userId));
    } catch (e) {
      debugPrint('Failed to clear cached auth state: $e');
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

      // Ensure admin profile exists for known admin emails
      try {
        await SupabaseDB.ensureAdminProfileExists(
          userId: user.id,
          email: user.email ?? '',
        );
      } catch (e) {
        debugPrint('Warning: Could not ensure admin profile: $e');
      }

      // Fetch roles from user_roles table
      try {
        final roles = await SupabaseDB.getUserRoles(user.id);
        _isSeller = roles.contains('seller');
        _isAdmin = roles.contains('admin');
      } catch (e) {
        debugPrint('Error fetching roles on initialize, using cache: $e');
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
      _isSeller = roles.contains('seller');
      _isAdmin = roles.contains('admin');

      debugPrint('🔴 === LOGIN DEBUG === 🔴');
      debugPrint('User Email: $email');
      debugPrint('User ID: $_userId');
      debugPrint('Roles fetched: $roles');
      debugPrint('Is Seller: $_isSeller');
      debugPrint('Is Admin: $_isAdmin');
      debugPrint('🔴 ==================== 🔴');

      await _persistCachedUserState();

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
  /// Sets seller status locally immediately, then tries to sync to database.
  /// This ensures offline users can use seller features and sync when online.
  Future<void> startSelling() async {
    // Mark as seller locally immediately — this won't be lost even if DB write fails
    _isSeller = true;
    _isViewingAsFarmer = true;
    await _persistCachedUserState();
    notifyListeners();

    // Try to sync the seller role to the database
    try {
      await SupabaseDB.addUserRole(userId: _userId, roleName: 'seller');
      debugPrint('Seller role synced to database');
    } catch (e) {
      debugPrint('Failed to sync seller role to database (offline?): $e');
      // Don't fail — local state is set, will retry when online
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
          debugPrint(
            'ERROR ensuring user profile after email confirmation: $e',
          );
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
    GoogleSignInDebugHelper.logDebugInfo(
      stage: 'Starting Google Sign-In',
      additionalInfo: {'platform': kIsWeb ? 'web' : 'mobile'},
    );

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (kIsWeb) {
        // WEB: Use Supabase OAuth (opens Google login in same tab)
        GoogleSignInDebugHelper.logDebugInfo(
          stage: 'Web OAuth Flow',
          message: 'Redirecting to Google OAuth',
        );

        try {
          await _client.auth.signInWithOAuth(
            OAuthProvider.google,
            redirectTo: kDebugMode
                ? 'http://localhost:3000/auth/callback'
                : 'https://agridirect.vercel.app/auth/callback',
          );
        } catch (e) {
          // OAuth will redirect if successful, so if we catch an error, it's real
          GoogleSignInDebugHelper.logDebugInfo(
            stage: 'Web OAuth Error',
            error: e,
          );
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
        GoogleSignInDebugHelper.logDebugInfo(
          stage: 'Mobile Native Flow',
          message: 'Using native Google Sign-In',
        );
        return await _signInWithGoogleMobile();
      }
    } catch (e) {
      GoogleSignInDebugHelper.logDebugInfo(
        stage: 'General Sign-In Error',
        error: e,
      );
      debugPrint('Google sign-in error: $e');
      _errorMessage = 'Google Sign-In failed: ${_extractErrorMessage(e)}';
      _isLoggedIn = false;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign in with Google on Mobile using native GoogleSignIn
  /// Now working with google_sign_in v6.2.1 (compatible API)
  Future<bool> _signInWithGoogleMobile() async {
    try {
      GoogleSignInDebugHelper.logDebugInfo(
        stage: 'Mobile Google Sign-In Start',
        message: 'Initializing native Google Sign-In with v6.2.1',
      );

      // Initialize GoogleSignIn with the stable v6.2.1 API
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      // Clear any existing sign-in state
      await googleSignIn.signOut();

      GoogleSignInDebugHelper.logDebugInfo(
        stage: 'Starting Sign-In Flow',
        message: 'Triggering Google account selection',
      );

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        GoogleSignInDebugHelper.logDebugInfo(
          stage: 'Sign-In Cancelled',
          message: 'User cancelled the sign-in process',
        );
        _errorMessage = 'Sign-in cancelled';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      GoogleSignInDebugHelper.logDebugInfo(
        stage: 'Google Account Selected',
        additionalInfo: {
          'email': googleUser.email,
          'displayName': googleUser.displayName,
          'id': googleUser.id,
        },
      );

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      GoogleSignInDebugHelper.logDebugInfo(
        stage: 'Authentication Tokens Retrieved',
        additionalInfo: {
          'hasIdToken': googleAuth.idToken != null,
          'hasAccessToken': googleAuth.accessToken != null,
        },
      );

      if (googleAuth.idToken == null) {
        GoogleSignInDebugHelper.logDebugInfo(
          stage: 'Authentication Error',
          message: 'Failed to get ID token from Google',
        );
        _errorMessage = 'Failed to get authentication token from Google';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      GoogleSignInDebugHelper.logDebugInfo(
        stage: 'Supabase Authentication',
        message: 'Signing in to Supabase with Google ID token',
      );

      // Sign in to Supabase using the Google ID token
      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      if (response.user == null) {
        GoogleSignInDebugHelper.logDebugInfo(
          stage: 'Supabase Authentication Failed',
          message: 'No user returned from Supabase authentication',
        );
        _errorMessage = 'Authentication with Supabase failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final user = response.user!;

      GoogleSignInDebugHelper.logDebugInfo(
        stage: 'Supabase Authentication Success',
        additionalInfo: {'userId': user.id, 'email': user.email},
      );

      // Check if this is a new user (no profile exists or incomplete profile)
      var profile = await SupabaseDB.getUserProfile(user.id);
      final isIncompleteProfile =
          profile == null ||
          profile['phone'] == null ||
          (profile['phone'] as String).isEmpty;

      if (isIncompleteProfile) {
        // Check if an existing user already has this email (from email/password signup)
        GoogleSignInDebugHelper.logDebugInfo(
          stage: 'Checking for existing email',
          additionalInfo: {'email': user.email},
        );

        try {
          final existingProfile = await SupabaseDB.getUserProfileByEmail(
            user.email ?? '',
          );
          if (existingProfile != null) {
            // Check if the existing profile has a phone number (is complete)
            final existingPhone = existingProfile['phone'] as String?;
            final existingProfileIsComplete =
                existingPhone != null && existingPhone.isNotEmpty;

            if (existingProfileIsComplete) {
              // Email already registered with complete profile - just log them in
              GoogleSignInDebugHelper.logDebugInfo(
                stage: 'Existing Complete Profile Found',
                message:
                    'User already has complete account with this email, logging in...',
              );

              _userId = user.id;
              _userEmail = user.email ?? '';
              _userName = (existingProfile['name'] as String?) ?? '';
              _isLoggedIn = true;

              // Ensure admin profile exists for known admin emails
              try {
                await SupabaseDB.ensureAdminProfileExists(
                  userId: _userId,
                  email: _userEmail,
                );
              } catch (e) {
                debugPrint('Warning: Could not ensure admin profile: $e');
              }

              // Fetch user roles from database
              final roles = await SupabaseDB.getUserRoles(_userId);
              _isSeller = roles.contains('seller');
              _isAdmin = roles.contains('admin');

              GoogleSignInDebugHelper.logDebugInfo(
                stage: 'User Roles Retrieved',
                additionalInfo: {
                  'isSeller': _isSeller,
                  'isAdmin': _isAdmin,
                  'roles': roles,
                },
              );

              // Cache the user state for offline access
              await _persistCachedUserState();

              GoogleSignInDebugHelper.logDebugInfo(
                stage: 'Mobile Google Sign-In Complete',
                message: 'Successfully signed in existing user with Google',
              );

              _isLoading = false;
              notifyListeners();
              return true;
            }
            // Profile exists but incomplete (no phone) - continue to profile completion
            GoogleSignInDebugHelper.logDebugInfo(
              stage: 'Existing Incomplete Profile',
              message: 'Profile exists but phone is missing, needs completion',
            );
          }
        } catch (e) {
          debugPrint('Error checking for existing email: $e');
          // Continue with profile completion flow if check fails
        }

        // Truly new user - set up profile completion flow
        GoogleSignInDebugHelper.logDebugInfo(
          stage: 'New User Profile Setup',
          message: 'User profile not found, setting up completion flow',
        );

        _needsProfileCompletion = true;
        _pendingGoogleUserId = user.id;
        _pendingGoogleEmail = user.email ?? '';
        _pendingGoogleName =
            user.userMetadata?['full_name'] ??
            user.userMetadata?['name'] ??
            googleUser.displayName ??
            '';

        GoogleSignInDebugHelper.logDebugInfo(
          stage: 'Profile Completion Required',
          additionalInfo: {
            'pendingUserId': _pendingGoogleUserId,
            'pendingEmail': _pendingGoogleEmail,
            'pendingName': _pendingGoogleName,
          },
        );

        _isLoading = false;
        notifyListeners();
        return true; // Success, but needs profile completion
      }

      // Existing user - complete login process
      GoogleSignInDebugHelper.logDebugInfo(
        stage: 'Existing User Login',
        message: 'Completing login for existing user',
      );

      _userId = user.id;
      _userEmail = user.email ?? '';
      _userName = (profile['name'] as String?) ?? '';
      _isLoggedIn = true;

      // Ensure admin profile exists for known admin emails
      try {
        await SupabaseDB.ensureAdminProfileExists(
          userId: _userId,
          email: _userEmail,
        );
      } catch (e) {
        debugPrint('Warning: Could not ensure admin profile: $e');
      }

      // Fetch user roles from database
      final roles = await SupabaseDB.getUserRoles(_userId);
      _isSeller = roles.contains('seller');
      _isAdmin = roles.contains('admin');

      GoogleSignInDebugHelper.logDebugInfo(
        stage: 'User Roles Retrieved',
        additionalInfo: {
          'isSeller': _isSeller,
          'isAdmin': _isAdmin,
          'roles': roles,
        },
      );

      // Cache the user state for offline access
      await _persistCachedUserState();

      GoogleSignInDebugHelper.logDebugInfo(
        stage: 'Mobile Google Sign-In Complete',
        message: 'Successfully signed in user',
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      GoogleSignInDebugHelper.logDebugInfo(
        stage: 'Mobile Sign-In Error',
        error: e,
      );

      debugPrint('Mobile Google sign-in error: $e');
      _errorMessage = _extractGoogleError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Extract meaningful error from Google Sign-In exceptions
  String _extractGoogleError(dynamic e) {
    final msg = e.toString().toLowerCase();

    // Common Google Sign-In error codes
    if (msg.contains('12501') ||
        msg.contains('canceled') ||
        msg.contains('cancelled')) {
      return 'Sign-in cancelled by user';
    }
    if (msg.contains('10') || msg.contains('developer_error')) {
      return 'Google Sign-In configuration error. Please check SHA-1 fingerprint in Firebase Console.';
    }
    if (msg.contains('7') || msg.contains('network_error')) {
      return 'Network error. Please check your internet connection.';
    }
    if (msg.contains('unsupportederror')) {
      return 'Google Sign-In is not supported on this device.';
    }
    if (msg.contains('account_exists_with_different_credential')) {
      return 'An account already exists with this email using a different sign-in method.';
    }
    if (msg.contains('invalid_credential')) {
      return 'Invalid Google credentials. Please try again.';
    }
    if (msg.contains('user_disabled')) {
      return 'Your account has been disabled. Please contact support.';
    }
    if (msg.contains('operation_not_allowed')) {
      return 'Google Sign-In is not enabled. Please contact support.';
    }

    // Return a generic error for unknown cases
    return 'Google Sign-In failed. Please try again or use email/password login.';
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
      debugPrint('🔵 Step 1: Creating/updating user in database...');
      debugPrint('🔵 User ID: $_pendingGoogleUserId');
      debugPrint('🔵 Email: $_pendingGoogleEmail');
      debugPrint('🔵 Name: $_pendingGoogleName');
      debugPrint('🔵 Phone: $phoneNumber');

      // Create user in the database now
      await SupabaseDB.createUserIfNotExists(
        userId: _pendingGoogleUserId,
        email: _pendingGoogleEmail,
        name: _pendingGoogleName,
        phoneNumber: phoneNumber,
      );
      debugPrint('✅ Step 1 completed: User created/updated successfully');

      // If user wants a password for email/password login, update it
      if (password != null && password.isNotEmpty) {
        debugPrint('🔵 Step 2: Updating password...');
        await _client.auth.updateUser(UserAttributes(password: password));
        debugPrint('✅ Step 2 completed: Password updated');
      }

      // Ensure admin profile exists for known admin emails
      debugPrint(
        '🔵 Step 2.5: Checking if admin profile needs to be created...',
      );
      try {
        await SupabaseDB.ensureAdminProfileExists(
          userId: _pendingGoogleUserId,
          email: _pendingGoogleEmail,
        );
      } catch (e) {
        debugPrint('Warning: Could not ensure admin profile: $e');
      }

      debugPrint('🔵 Step 3: Getting user roles...');
      final roles = await SupabaseDB.getUserRoles(_pendingGoogleUserId);
      debugPrint('✅ Step 3 completed: User roles = $roles');

      // Finalize auth state
      _userId = _pendingGoogleUserId;
      _userEmail = _pendingGoogleEmail;
      _userName = _pendingGoogleName;
      _needsProfileCompletion = false;
      _pendingGoogleUserId = '';
      _pendingGoogleEmail = '';
      _pendingGoogleName = '';

      _isSeller = roles.contains('seller');
      _isAdmin = roles.contains('admin');
      debugPrint('🔵 Is Seller: $_isSeller, Is Admin: $_isAdmin');

      _isLoggedIn = true;
      await _persistCachedUserState();
      _isLoading = false;
      notifyListeners();
      debugPrint('✅ Profile completion successful!');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Complete Google profile error: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      _errorMessage = 'Failed to save profile: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Reset password - sends reset link to email
  Future<void> resetPassword({required String email}) async {
    try {
      // For web, use the web URL; for mobile, use deep link
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

  /// Logout
  Future<void> logout() async {
    try {
      // Sign out from mobile GoogleSignIn if not web
      if (!kIsWeb) {
        try {
          final GoogleSignIn googleSignIn = GoogleSignIn();
          await googleSignIn.signOut();
          GoogleSignInDebugHelper.logDebugInfo(
            stage: 'Mobile Google Sign-Out',
            message: 'Successfully signed out from Google on mobile',
          );
        } catch (e) {
          GoogleSignInDebugHelper.logDebugInfo(
            stage: 'Mobile Google Sign-Out Error',
            error: e,
          );
          // Don't fail the entire logout process if Google sign-out fails
          debugPrint('Google sign-out error (non-fatal): $e');
        }
      }

      // Sign out from Supabase (handles both web OAuth and email/password)
      await _client.auth.signOut();

      // Clear all user state
      _isLoggedIn = false;
      final previousUserId = _userId;
      _isSeller = false;
      _isAdmin = false;
      _isViewingAsFarmer = false;
      _userName = '';
      _userEmail = '';
      _userId = '';
      _clearPendingGoogleProfileState();
      await _clearCachedUserState(previousUserId);
      _errorMessage = null;

      GoogleSignInDebugHelper.logDebugInfo(
        stage: 'Complete Logout',
        message: 'User successfully logged out',
      );

      notifyListeners();
    } catch (e) {
      GoogleSignInDebugHelper.logDebugInfo(stage: 'Logout Error', error: e);
      _errorMessage = 'Logout failed: $e';
      notifyListeners();
    }
  }
}
