import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/supabase_config.dart';

// Firebase for mobile Google sign-in
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Auth Service using Supabase
/// Handles user registration, login, logout, and seller mode
class AuthService extends ChangeNotifier {
  // Singleton
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _client = SupabaseConfig.client;
  bool _googleInitialized = false;
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

  // ── Local Storage for Offline Profile Completion ──────────────────────────
  static const _keyProfileComplete = 'google_profile_complete';
  static const _keyUserId = 'cached_user_id';

  /// Save profile completion status to local storage (offline-first)
  Future<void> _saveProfileCompletionStatus(
    String userId,
    bool isComplete,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserId, userId);
      await prefs.setBool(_keyProfileComplete, isComplete);
      debugPrint(
        'Cached profile completion: userId=$userId, complete=$isComplete',
      );
    } catch (e) {
      debugPrint('Error saving profile completion to cache: $e');
    }
  }

  /// Check if profile is complete from local cache (used when offline)
  Future<bool> _isProfileCompleteFromCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedUserId = prefs.getString(_keyUserId);
      final isComplete = prefs.getBool(_keyProfileComplete) ?? false;

      // Only trust cache if it's for the same user
      if (cachedUserId == userId && isComplete) {
        debugPrint('Profile completion found in cache for user $userId');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error reading profile completion from cache: $e');
      return false;
    }
  }

  /// Clear cached profile completion status (on logout)
  Future<void> _clearProfileCompletionCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyProfileComplete);
      debugPrint('Cleared profile completion cache');
    } catch (e) {
      debugPrint('Error clearing profile completion cache: $e');
    }
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
    final user = _client.auth.currentUser;

    if (user == null) return;

    // Google OAuth users are auto-confirmed — allow them even if emailConfirmedAt is null
    final provider = user.appMetadata['provider'] as String? ?? '';
    final isOAuthUser =
        provider == 'google' ||
        (user.appMetadata['providers'] as List?)?.contains('google') == true;
    final emailConfirmed = user.emailConfirmedAt != null;

    debugPrint(
      'initialize: provider=$provider emailConfirmed=$emailConfirmed isOAuth=$isOAuthUser',
    );

    if (emailConfirmed || isOAuthUser) {
      _userId = user.id;
      _userEmail = user.email ?? '';

      // Try to fetch user profile from server
      Map<String, dynamic>? profile;
      bool serverReachable = true;

      try {
        profile = await SupabaseDB.getUserProfile(user.id);
      } catch (e) {
        debugPrint(
          'Could not fetch profile from server (possibly offline): $e',
        );
        serverReachable = false;
        profile = null;
      }

      final hasPhone =
          profile != null && (profile['phone'] as String?)?.isNotEmpty == true;

      if (isOAuthUser && !hasPhone) {
        // Google user without phone from server — check local cache
        if (!serverReachable) {
          // Offline: check if profile was previously completed
          final cachedComplete = await _isProfileCompleteFromCache(user.id);
          if (cachedComplete) {
            // Profile was completed before — log them in with cached data
            debugPrint('Profile complete from cache — logging in offline');
            _isLoggedIn = true;
            _needsProfileCompletion = false;
            _userName =
                user.userMetadata?['full_name'] as String? ??
                user.userMetadata?['name'] as String? ??
                user.email?.split('@')[0] ??
                '';
            notifyListeners();
            return;
          }
        }

        // Still needs to complete profile (either online with no phone, or offline with no cache)
        _pendingGoogleUserId = user.id;
        _pendingGoogleEmail = user.email ?? '';
        _pendingGoogleName =
            (user.userMetadata?['full_name'] as String?) ??
            (user.userMetadata?['name'] as String?) ??
            (user.email?.split('@')[0] ?? '');
        _needsProfileCompletion = true;
        _isLoggedIn = false;
        notifyListeners();
        return; // Don't log in yet — wait for profile completion
      }

      if (profile == null) {
        // Non-Google user with missing profile — create it from metadata
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

      _isLoggedIn = true;

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
    } else if (!isOAuthUser && !emailConfirmed) {
      // Email-password user with unconfirmed email — sign them out
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
      // Sign up with Supabase Auth (pass name in metadata as fallback)
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          if (phoneNumber != null && phoneNumber.isNotEmpty)
            'phone_number': phoneNumber,
        },
      );

      if (response.user == null) {
        _errorMessage = 'Registration failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Detect if Supabase silently returned an EXISTING user instead of creating a new one
      // (happens when autoconfirm is ON and the email is already registered)
      final createdAt = DateTime.parse(response.user!.createdAt);
      final isNewUser = DateTime.now().difference(createdAt).inSeconds < 30;
      if (!isNewUser) {
        _errorMessage =
            'This email is already registered. Please log in instead.';
        _isLoading = false;
        try {
          await _client.auth.signOut();
        } catch (_) {}
        notifyListeners();
        return false;
      }

      // Create user profile in public.users while session is still active
      try {
        await SupabaseDB.createUserIfNotExists(
          userId: response.user!.id,
          email: email,
          name: name,
          phoneNumber: phoneNumber,
        );
        // Also create the customers row (needed for placing orders)
        await SupabaseDB.createCustomerIfNotExists(response.user!.id);
        debugPrint('User profile created for ${response.user!.id}');
      } catch (e) {
        debugPrint(
          'Warning: Could not create user profile during register: $e',
        );
        // Non-fatal — login() will retry profile creation on first login
      }

      // Sign out so user is not auto-logged in before OTP is verified
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
      // Ensure customers row exists (needed for placing orders)
      try {
        await SupabaseDB.createCustomerIfNotExists(_userId);
      } catch (e) {
        debugPrint('Warning: Could not create customer row on login: $e');
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

      // Fetch roles from  rfdc   nvrfnuu76yjhyuuuu66m]k]i/]-l=
      // .lle
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

  /// Sign in / sign up with Google.
  /// Web → Supabase OAuth redirect (browser popup/redirect flow).
  /// Mobile → Firebase Auth + Supabase signInWithIdToken (consistent Supabase UUID).
  Future<bool> signInWithGoogle() async {
    if (kIsWeb) {
      return _signInWithGoogleWeb();
    }
    return _signInWithGoogleMobile();
  }

  /// Web: Supabase OAuth redirect.
  /// Redirects to Google login, then back to the app.
  /// On return, initialize() picks up the Supabase session automatically.
  Future<bool> _signInWithGoogleWeb() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Use current origin so it works on localhost AND on Vercel
      final redirectTo = Uri.base.origin;
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
      );
      // Browser redirects away — session is picked up by initialize() on reload.
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Google OAuth (web) error: $e');
      _errorMessage = 'Google sign-in failed: ${_extractErrorMessage(e)}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Mobile: google_sign_in → Firebase Auth → Supabase signInWithIdToken.
  /// Firebase handles the Google session on-device; Supabase provides the
  /// database identity (UUID stays consistent across platforms).
  Future<bool> _signInWithGoogleMobile() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Initialize google_sign_in once
      if (!_googleInitialized) {
        await GoogleSignIn.instance.initialize(
          serverClientId:
              '971354937445-5d6hvlnbj8dco93mtnogeul8jnhd5f1l.apps.googleusercontent.com',
        );
        _googleInitialized = true;
      }

      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        _errorMessage = 'Google Sign-In is not supported on this device';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 2. Interactive Google sign-in (v7 API)
      // authenticate() throws on cancellation — no null check needed
      final googleUser = await GoogleSignIn.instance.authenticate();

      final idToken = googleUser.authentication.idToken;
      final authScopes = await googleUser.authorizationClient
          .authorizationForScopes(['email', 'profile']);
      final accessToken = authScopes?.accessToken;

      if (idToken == null) {
        _errorMessage =
            'Failed to get Google ID token. Check serverClientId and SHA-1 fingerprint.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 3. Firebase Auth sign-in with Google credential
      final firebaseCredential = fb.GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );
      await fb.FirebaseAuth.instance.signInWithCredential(firebaseCredential);
      debugPrint(
        'Firebase Auth: signed in as ${fb.FirebaseAuth.instance.currentUser?.email}',
      );

      // 4. Supabase Auth sign-in with the same Google ID token
      //    This gives a Supabase session + consistent UUID for all DB operations.
      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user == null) {
        _errorMessage = 'Supabase sign-in failed after Firebase auth';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final user = response.user!;
      _userId = user.id;
      _userEmail = user.email ?? googleUser.email;

      final displayName =
          googleUser.displayName ?? googleUser.email.split('@')[0];

      // 5. Check if this is a returning user (has phone) or new user (needs profile completion)
      Map<String, dynamic>? existingProfile;
      try {
        existingProfile = await SupabaseDB.getUserProfile(_userId);
      } catch (e) {
        debugPrint('Could not read user profile: $e');
        existingProfile = null;
      }

      final hasPhone =
          existingProfile != null &&
          (existingProfile['phone'] as String?)?.isNotEmpty == true;

      if (hasPhone) {
        // EXISTING USER with complete profile — log them in directly
        _userName = (existingProfile['name'] as String?)?.isNotEmpty == true
            ? existingProfile['name'] as String
            : displayName;

        final roles = await SupabaseDB.getUserRoles(_userId);
        _isSeller = roles.contains('seller');
        _isAdmin = roles.contains('admin');

        _isLoggedIn = true;
        _needsProfileCompletion = false;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      // NEW USER or incomplete profile — collect phone + password
      _pendingGoogleUserId = _userId;
      _pendingGoogleEmail = _userEmail;
      _pendingGoogleName = displayName;
      _needsProfileCompletion = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Google sign-in (mobile) error: $e');
      _errorMessage = _extractGoogleError(e);
      _isLoggedIn = false;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Complete profile for a new Google sign-in user.
  /// Called from GoogleCompleteProfileScreen after collecting phone + optional password.
  /// ONLY creates account if ALL validations pass.
  Future<bool> completeGoogleProfile({
    required String phoneNumber,
    String? password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // STEP 1: VALIDATE phone number is not already used
      debugPrint('Validating phone number: $phoneNumber');
      final phoneInUse = await SupabaseDB.isPhoneAlreadyRegistered(phoneNumber);
      if (phoneInUse) {
        _errorMessage = 'The number is already used';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      debugPrint('Phone number validation passed');

      // STEP 2: UPDATE user profile with phone number (REQUIRED)
      // This is the critical step that marks profile as complete
      debugPrint('Creating user profile with phone number...');
      await SupabaseDB.createUserIfNotExists(
        userId: _pendingGoogleUserId,
        email: _pendingGoogleEmail,
        name: _pendingGoogleName,
        phoneNumber: phoneNumber,
      );
      debugPrint('User profile created successfully with phone: $phoneNumber');

      // STEP 3: Create customer row (REQUIRED for using the app)
      debugPrint('Creating customer row...');
      await SupabaseDB.createCustomerIfNotExists(_pendingGoogleUserId);
      debugPrint('Customer row created successfully');

      // STEP 4: Optionally set password
      if (password != null && password.isNotEmpty) {
        try {
          await _client.auth.updateUser(UserAttributes(password: password));
          debugPrint('Password set successfully');
        } catch (e) {
          debugPrint('Warning: Password set failed (non-fatal): $e');
          // Non-fatal — Google sign-in still works
        }
      }

      // STEP 5: Fetch roles and complete login ONLY if all above succeeded
      _userId = _pendingGoogleUserId;
      _userEmail = _pendingGoogleEmail;
      _userName = _pendingGoogleName;

      debugPrint('Fetching user roles...');
      final roles = await SupabaseDB.getUserRoles(_userId);
      _isSeller = roles.contains('seller');
      _isAdmin = roles.contains('admin');
      debugPrint('User roles: $roles');

      // Mark profile completion as done
      _isLoggedIn = true;
      _needsProfileCompletion = false;

      // STEP 6: Cache profile completion status for offline access
      await _saveProfileCompletionStatus(_userId, true);

      _pendingGoogleUserId = '';
      _pendingGoogleEmail = '';
      _pendingGoogleName = '';

      _isLoading = false;
      notifyListeners();
      debugPrint('Profile completion successful! User logged in.');
      return true;
    } catch (e) {
      debugPrint('completeGoogleProfile error: $e');
      _errorMessage = 'Failed to save profile: ${_extractErrorMessage(e)}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Cancel Google profile completion — sign out and DELETE incomplete profile.
  /// Called when user presses back on the profile completion screen.
  /// This prevents "ghost accounts" from being created.
  Future<void> cancelGoogleProfileCompletion() async {
    debugPrint('Cancelling profile completion for user: $_pendingGoogleUserId');

    // DELETE the incomplete profile if it was auto-created by the trigger
    // Uses SECURITY DEFINER RPC to bypass RLS
    try {
      if (_pendingGoogleUserId.isNotEmpty) {
        await _client.rpc(
          'delete_user_profile',
          params: {'p_user_id': _pendingGoogleUserId},
        );
        debugPrint('Deleted incomplete user profile: $_pendingGoogleUserId');
      }
    } catch (e) {
      debugPrint('Warning: Could not delete incomplete profile: $e');
      // Continue with sign out even if delete fails
    }

    // Sign out from all auth providers
    try {
      if (!kIsWeb) {
        await GoogleSignIn.instance.signOut();
        await fb.FirebaseAuth.instance.signOut();
      }
      await _client.auth.signOut();
      debugPrint('Successfully signed out from all providers');
    } catch (e) {
      debugPrint('Error during cancel sign out: $e');
    }

    // Reset pending state
    _needsProfileCompletion = false;
    _pendingGoogleUserId = '';
    _pendingGoogleEmail = '';
    _pendingGoogleName = '';
    _isLoggedIn = false;
    _isLoading = false;
    _errorMessage = null;

    // Clear any cached profile completion status
    await _clearProfileCompletionCache();

    notifyListeners();

    debugPrint('Profile completion cancelled and profile deleted');
  }

  /// Extract meaningful error from Google Sign-In exceptions
  String _extractGoogleError(dynamic e) {
    final msg = e.toString();
    debugPrint('RAW Google Sign-In error: $msg');
    if (msg.contains('10') || msg.contains('DEVELOPER_ERROR')) {
      return 'Config error (10): Check SHA-1 in Firebase Console and google-services.json.';
    }
    if (msg.contains('12500')) {
      return 'Google Sign-In failed (12500). Try again.';
    }
    if (msg.contains('12501') ||
        msg.contains('canceled') ||
        msg.contains('cancelled')) {
      return 'Sign-in cancelled (12501). Check OAuth consent screen — add your Google account as a test user at console.cloud.google.com → OAuth consent screen.';
    }
    if (msg.contains('7') || msg.contains('NETWORK_ERROR')) {
      return 'Network error. Check your connection.';
    }
    if (msg.contains('UnsupportedError')) {
      return 'Google Sign-In not supported on this device.';
    }
    return 'Google Sign-In error: $msg';
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
      if (!kIsWeb) {
        // Mobile: sign out from Google Sign-In + Firebase
        await GoogleSignIn.instance.signOut();
        await fb.FirebaseAuth.instance.signOut();
      }
      // Both platforms: sign out from Supabase
      await _client.auth.signOut();

      // Clear cached profile completion status
      await _clearProfileCompletionCache();

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
