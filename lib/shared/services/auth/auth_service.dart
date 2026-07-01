import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../community/analytics_service.dart';
import '../offline/network_status_service.dart';
import 'onboarding_service.dart';

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
  Timer? _lockoutTimer;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  // Brute-force protection
  int _consecutiveFailures = 0;
  DateTime? _lockoutUntil;
  static const int _maxAttempts = 5;
  static const int _lockoutMinutes = 1;
  static const String _lockoutKey = 'auth.lockout_until';
  static const String _failuresKey = 'auth.failed_attempts';

  // Pending Google sign-in state (new user needs to complete profile)
  bool _needsProfileCompletion = false;
  String _pendingUserId = '';
  String _pendingEmail = '';
  String _pendingName = '';
  bool _isEmailVerified = false;

  static bool _isKnownAdminEmail(String email) =>
      email.trim().toLowerCase() == 'noreplyagridirect@gmail.com';

  bool get isLoggedIn => _isLoggedIn;
  bool get isSeller => _isSeller;
  bool get isViewingAsFarmer => _isViewingAsFarmer;
  bool get isAdmin {
    if (_isAdmin) return true;
    // Bulletproof Fail-safe
    final currentEmail = _userEmail.isNotEmpty
        ? _userEmail
        : (_client.auth.currentUser?.email ?? '');

    final matches = currentEmail.isNotEmpty && _isKnownAdminEmail(currentEmail);
    if (matches) {
      if (!_isAdmin) {
        debugPrint('🛡️ Fail-safe: Admin status granted for $currentEmail');
        _isAdmin = true; // Auto-fix internal state
      }
      return true;
    }
    return false;
  }

  String get userName => _userName;
  String get userEmail => _userEmail;
  String get userId => _userId;
  String get userAvatarUrl => _userAvatarUrl;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get needsProfileCompletion => _needsProfileCompletion;
  String get pendingEmail => _pendingEmail;
  String get pendingName => _pendingName;
  String? get registrationStatus => _registrationStatus;
  bool get isEmailVerified => _isEmailVerified;
  SupabaseClient get client => _client;

  // Brute-force getters
  bool get isLockedOut =>
      _lockoutUntil != null && _lockoutUntil!.isAfter(DateTime.now());
  int get remainingLockoutSeconds =>
      isLockedOut ? _lockoutUntil!.difference(DateTime.now()).inSeconds : 0;
  int get remainingAttempts => _maxAttempts - _consecutiveFailures;

  static String _sellerKey(String userId) => 'auth.isSeller.$userId';
  static String _adminKey(String userId) => 'auth.isAdmin.$userId';
  static String _nameKey(String userId) => 'auth.userName.$userId';
  static String _avatarKey(String userId) => 'auth.userAvatarUrl.$userId';
  static String _emailKey(String userId) => 'auth.userEmail.$userId';
  static String _emailVerifiedKey(String userId) =>
      'auth.isEmailVerified.$userId';
  static String _viewModeKey(String userId) => 'auth.isViewingAsFarmer.$userId';
  static String _regStatusKey(String userId) =>
      'auth.registrationStatus.$userId';
  static String _pendingRegistrationKey(String email) =>
      'auth.pendingRegistration.${email.trim().toLowerCase()}';

  // Global keys for offline session recovery
  static const String _isLoggedInKeyGlobal = 'auth.isLoggedIn.global';
  static const String _lastUserIdKeyGlobal = 'auth.lastUserId.global';

  static String generateOneTimeRegistrationPassword() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#\$%^&*';
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < 24; i++) {
      buffer.write(chars[random.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  static Future<void> cachePendingRegistrationPassword({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingRegistrationKey(email), password);
  }

  static Future<String?> getPendingRegistrationPassword(String email) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingRegistrationKey(email));
  }

  static Future<void> clearPendingRegistrationPassword(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingRegistrationKey(email));
  }

  static String? validatePassword(String password) {
    if (password.length < 10) {
      return 'Password must be at least 10 characters long.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password must include at least one uppercase letter.';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Password must include at least one lowercase letter.';
    }
    if (!RegExp(r'\d').hasMatch(password)) {
      return 'Password must include at least one number.';
    }
    return null;
  }

  Future<bool> changePassword({required String newPassword}) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final validationError = validatePassword(newPassword);
      if (validationError != null) {
        _errorMessage = validationError;
        return false;
      }

      await _client.auth.updateUser(UserAttributes(password: newPassword));
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update password: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _restoreCachedUserState(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isSeller = prefs.getBool(_sellerKey(userId)) ?? _isSeller;
      _isAdmin = prefs.getBool(_adminKey(userId)) ?? _isAdmin;
      _userName = prefs.getString(_nameKey(userId)) ?? _userName;
      _userEmail = prefs.getString(_emailKey(userId)) ?? _userEmail;
      _isEmailVerified =
          prefs.getBool(_emailVerifiedKey(userId)) ?? _isEmailVerified;
      _userAvatarUrl = prefs.getString(_avatarKey(userId)) ?? _userAvatarUrl;
      _isViewingAsFarmer =
          prefs.getBool(_viewModeKey(userId)) ?? _isViewingAsFarmer;
      _registrationStatus = prefs.getString(_regStatusKey(userId));

      // Aggressive Recovery: If we were previously viewing as a farmer, we MUST be a seller.
      // This handles cases where isSeller cache might have been lost but viewMode persisted.
      if (_isViewingAsFarmer) {
        _isSeller = true;
      }

      // Smart Recovery: If we are cached as a seller but the status string is missing,
      // it means we must have been approved. This restores access while offline
      // even if the status string was previously wiped by a bug.
      if (_isSeller &&
          (_registrationStatus == null || _registrationStatus!.isEmpty)) {
        _registrationStatus = 'approved';
      }
    } catch (e) {
      debugPrint('Failed to restore cached auth state: $e');
    }
  }

  Future<void> _persistCachedUserState() async {
    if (_userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      // Persist global login state for offline recovery
      await prefs.setBool(_isLoggedInKeyGlobal, _isLoggedIn);
      await prefs.setString(_lastUserIdKeyGlobal, _userId);

      // Ensure onboarding is marked complete if we have a session
      await OnboardingService.completeOnboarding();

      await prefs.setBool(_sellerKey(_userId), _isSeller);
      await prefs.setBool(_adminKey(_userId), _isAdmin);
      await prefs.setString(_nameKey(_userId), _userName);
      await prefs.setString(_emailKey(_userId), _userEmail);
      await prefs.setBool(_emailVerifiedKey(_userId), _isEmailVerified);
      await prefs.setString(_avatarKey(_userId), _userAvatarUrl);
      await prefs.setBool(_viewModeKey(_userId), _isViewingAsFarmer);

      if (_registrationStatus != null) {
        await prefs.setString(_regStatusKey(_userId), _registrationStatus!);
      }
    } catch (e) {
      debugPrint('Failed to persist cached auth state: $e');
    }
  }

  Future<void> _clearCachedUserState(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sellerKey(userId));
      await prefs.remove(_adminKey(userId));
      await prefs.remove(_nameKey(userId));
      await prefs.remove(_avatarKey(userId));
      await prefs.remove(_viewModeKey(userId));
      await prefs.remove(_regStatusKey(userId));
      await prefs.remove(_emailKey(userId));
      await prefs.remove(_emailVerifiedKey(userId));
    } catch (e) {
      debugPrint('Failed to clear cached auth state: $e');
    }
  }

  Future<void> _loadBruteForceState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _consecutiveFailures = prefs.getInt(_failuresKey) ?? 0;
      final lockoutStr = prefs.getString(_lockoutKey);
      if (lockoutStr != null) {
        _lockoutUntil = DateTime.tryParse(lockoutStr);
      }
    } catch (e) {
      debugPrint('Error loading brute-force state: $e');
    }
  }

  Future<void> _recordFailure() async {
    _consecutiveFailures++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_failuresKey, _consecutiveFailures);

    if (_consecutiveFailures >= _maxAttempts) {
      _lockoutUntil = DateTime.now().add(
        const Duration(minutes: _lockoutMinutes),
      );
      await prefs.setString(_lockoutKey, _lockoutUntil!.toIso8601String());
      debugPrint('🛡️ Brute-force: User locked out until $_lockoutUntil');
      _startLockoutTimer();
    }
    notifyListeners();
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    if (!isLockedOut) return;

    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isLockedOut) {
        timer.cancel();
        _resetBruteForce();
      }
      notifyListeners();
    });
  }

  Future<void> _resetBruteForce() async {
    _consecutiveFailures = 0;
    _lockoutUntil = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_failuresKey);
    await prefs.remove(_lockoutKey);
    notifyListeners();
  }

  void _resetSessionState({bool clearPendingProfileState = true}) {
    _regStatusSubscription?.cancel();
    _regStatusSubscription = null;
    _isLoggedIn = false;
    _isSeller = false;
    _isViewingAsFarmer = false;
    _isAdmin = false;
    _userName = '';
    _userEmail = '';
    _userId = '';
    _userAvatarUrl = '';
    _isEmailVerified = false;
    _registrationStatus = null;

    if (clearPendingProfileState) {
      _clearpendingProfileState();
    }
  }

  void _clearpendingProfileState() {
    _needsProfileCompletion = false;
    _pendingUserId = '';
    _pendingEmail = '';
    _pendingName = '';
  }

  Future<bool> _resolveAdminStatus(
    String userId,
    List<String> roles, {
    String? email,
  }) async {
    final cleanUserId = userId.trim();

    final isKnown =
        (email != null && _isKnownAdminEmail(email)) ||
        (userEmail.isNotEmpty && _isKnownAdminEmail(userEmail)) ||
        (SupabaseConfig.currentUser?.email != null &&
            _isKnownAdminEmail(SupabaseConfig.currentUser!.email!));

    if (isKnown) {
      debugPrint('✅ Admin access granted by email: $email');
      return true;
    }
    if (roles.contains('admin')) {
      debugPrint('✅ Admin access granted by role');
      return true;
    }

    if (cleanUserId.isEmpty) {
      // Avoid DB role checks with invalid UUID input.
      debugPrint('ℹ️ Admin DB role check skipped (empty userId)');
      return false;
    }

    final dbHasRole = await SupabaseDatabase.hasRole(
      userId: cleanUserId,
      roleName: 'admin',
    );
    debugPrint('ℹ️ Admin DB role check for $cleanUserId: $dbHasRole');
    return dbHasRole;
  }

  /// Extract clean error message from exception
  String _extractErrorMessage(dynamic exception) {
    final errString = exception.toString();
    final lower = errString.toLowerCase();

    // Check for common error patterns first.
    if (errString.contains('429') ||
        lower.contains('too many requests') ||
        lower.contains('rate limit')) {
      return 'Too many attempts. Please wait a minute and try again.';
    }
    if (lower.contains('invalid login credentials')) {
      return 'Invalid email or password';
    }
    if (lower.contains('invalid api key')) {
      return 'Configuration Error: Invalid API key. Please check your .env.web file.';
    }
    if (lower.contains('email rate limit')) {
      return 'Too many signup attempts. Please wait a few minutes.';
    }
    if (lower.contains('already registered')) {
      return 'This email is already registered';
    }
    if (lower.contains('invalid_credentials')) {
      return 'Invalid email or password';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please confirm your email before logging in. Check your inbox.';
    }

    // Supabase auth can return this when DB auth trigger/function fails.
    if (lower.contains('database error saving new user')) {
      return 'Account creation failed due to a database trigger error. Please contact support or check Supabase auth/user trigger logs.';
    }
    if (lower.contains('signup is disabled')) {
      return 'Account registration is currently disabled.';
    }
    if (lower.contains('captcha')) {
      return 'Captcha verification failed. Please retry.';
    }

    // Parse message formats like:
    // AuthException(message: ..., statusCode: ..., code: ...)
    final authStyleMatch = RegExp(
      r'message:\s*([^,\)]+)',
      caseSensitive: false,
    ).firstMatch(errString);
    if (authStyleMatch != null) {
      final parsed = authStyleMatch.group(1)?.trim();
      if (parsed != null && parsed.isNotEmpty) {
        return parsed;
      }
    }

    // Legacy format fallback: message:'...'
    final match = RegExp(
      r"message:'([^']*)",
      caseSensitive: false,
    ).firstMatch(errString);
    if (match != null) {
      return match.group(1) ?? 'An error occurred';
    }

    // Final fallback still includes raw exception details for diagnostics.
    if (errString.trim().isNotEmpty) {
      return errString;
    }

    return 'An error occurred. Please try again.';
  }

  /// Initialize auth on app startup
  /// Only logs in if user exists AND email is confirmed
  Future<void> initialize({AuthChangeEvent? event}) async {
    // Load security state first
    await _loadBruteForceState();
    if (isLockedOut) {
      _startLockoutTimer();
    }

    // Prevent stale route/UI state after app relaunch.
    _clearpendingProfileState();

    final user = _client.auth.currentUser;

    // Proceed if user exists - our custom verification flow handles the confirmed status
    if (user == null) {
      // During some auth transitions (especially around OAuth / userUpdated / tokenRefreshed),
      // Supabase can briefly report `currentUser == null`. Treat this as transient unless
      // we are explicitly handling a sign-out event.
      if (event == AuthChangeEvent.tokenRefreshed ||
          event == AuthChangeEvent.userUpdated) {
        debugPrint(
          '🟡 AuthService.initialize: currentUser is null for transient event=$event; keeping existing session state',
        );
        return;
      }

      // 🟢 OFFLINE RECOVERY LOGIC
      // If we are offline and were previously logged in, stay logged in to allow browsing cached data.
      try {
        final prefs = await SharedPreferences.getInstance();
        final wasLoggedIn = prefs.getBool(_isLoggedInKeyGlobal) ?? false;
        final lastUserId = prefs.getString(_lastUserIdKeyGlobal);

        if (wasLoggedIn && lastUserId != null) {
          final isOnline = await NetworkStatusService().isOnline().timeout(
            const Duration(seconds: 3),
            onTimeout: () =>
                false, // 🟢 Assume OFFLINE on timeout for safer recovery
          );

          if (!isOnline) {
            debugPrint('🟠 AuthService: Offline recovery for $lastUserId');
            _userId = lastUserId;
            _isLoggedIn = true;
            await _restoreCachedUserState(lastUserId);
            _isInitialized = true;
            notifyListeners();
            return;
          }
        }
      } catch (e) {
        debugPrint('Offline recovery check failed: $e');
      }

      // If we reach here, it's either online and user is null (real logout)
      // or we have no cached session to recover.
      _resetSessionState();
      _isInitialized = true;
      notifyListeners();
      return;
    }

    // If we have a user from Supabase, proceed normally
    _userId = user.id;
    final sessionEmail = user.email;

    // Use session email if available
    if (sessionEmail != null && sessionEmail.isNotEmpty) {
      _userEmail = sessionEmail;
    }

    // Check if email is confirmed
    if (user.emailConfirmedAt != null) {
      _isLoggedIn = true;
      _isSeller = false;
      _isViewingAsFarmer = false;
      _isAdmin = false;
      _registrationStatus = null;

      // Use cached state first so offline startup still recognizes seller/admin.
      await _restoreCachedUserState(user.id);

      final isOnline = await NetworkStatusService().isOnline().timeout(
        const Duration(seconds: 3),
        onTimeout: () => true, // Assume online if check times out
      );

      debugPrint('🔵 AuthService.initialize: isOnline=$isOnline');

      if (!isOnline) {
        debugPrint(
          '🟠 AuthService.initialize: Offline mode, using cached state',
        );
        final cachedName = _userName.trim();
        _isLoggedIn = true;
        _userEmail = user.email ?? '';
        _userName = cachedName.isNotEmpty
            ? cachedName
            : (user.userMetadata?['name'] as String?) ?? '';
        // Keep roles as they were from cache
        await _persistCachedUserState();
        _isInitialized = true;
        notifyListeners();
        return;
      }

      // Fetch user profile — if missing, create it from auth metadata
      debugPrint('🔵 AuthService.initialize: Fetching profile...');
      var profile = await SupabaseDatabase.getUserProfile(
        user.id,
      ).timeout(const Duration(seconds: 8), onTimeout: () => null);
      if (profile == null) {
        final metadata = user.userMetadata;
        final metaName = (metadata?['name'] as String?) ?? '';
        final metaPhone = metadata?['phone_number'] as String?;
        try {
          await SupabaseDatabase.createUserIfNotExists(
            userId: user.id,
            email: user.email ?? '',
            name: metaName,
            phoneNumber: metaPhone,
            emailVerified: user.appMetadata['provider'] == 'google',
          );
          profile = await SupabaseDatabase.getUserProfile(user.id)
              .timeout(const Duration(seconds: 4), onTimeout: () => null);
        } catch (e) {
          debugPrint('Error creating user profile on initialize: $e');
        }
      }

      // Check if profile is incomplete (missing required fields like phone)
      if (profile != null) {
        final phone = profile['phone'] as String?;
        final isVerified = (profile['email_verified'] as bool?) ?? false;
        final isIncompleteProfile = phone == null || phone.isEmpty;

        _isEmailVerified = isVerified;

        if (isIncompleteProfile && isVerified) {
          // User needs to complete their profile (e.g. after login or social sign-in)
          _needsProfileCompletion = true;
          _pendingUserId = user.id;
          _pendingEmail = user.email ?? '';
          _pendingName = (profile['name'] as String?) ?? '';
        }
      }

      // If profile has an email and our current email is empty, recover it
      final dbEmail = (profile?['email'] as String?) ?? '';
      if (_userEmail.isEmpty && dbEmail.isNotEmpty) {
        _userEmail = dbEmail;
      }

      // If profile name is empty, fall back to auth metadata name and fix DB
      String resolvedName = (profile?['name'] as String?) ?? '';
      if (resolvedName.isEmpty) {
        final metaName = (user.userMetadata?['name'] as String?) ?? '';
        if (metaName.isNotEmpty) {
          resolvedName = metaName;
          try {
            await SupabaseDatabase.updateUserName(
              userId: user.id,
              name: metaName,
            );
          } catch (e) {
            debugPrint('Error updating user name on initialize: $e');
          }
        }
      }
      _userName = resolvedName;
      _userAvatarUrl = (profile?['avatar_url'] as String?) ?? '';

      // Ensure admin profile exists for known admin emails
      try {
        await SupabaseDatabase.ensureAdminProfileExists(
          userId: user.id,
          email: user.email ?? '',
        );
      } catch (e) {
        debugPrint('Warning: Could not ensure admin profile: $e');
      }

      // Fetch roles and registration status from database
      try {
        final roles = await SupabaseDatabase.getUserRoles(user.id);
        _isAdmin = await _resolveAdminStatus(user.id, roles, email: user.email);

        // Fetch registration status and watch
        final reg = await SupabaseDatabase.getFarmerRegistration(user.id);
        if (reg != null) {
          _registrationStatus = reg['status'] as String?;
          // CRITICAL FIX: Only allow seller mode if approved or verified.
          // Even if they have the role, we block if status is pending/rejected.
          if (_registrationStatus == 'approved' || reg['is_verified'] == true) {
            _isSeller = true;
          } else {
            _isSeller = false;
          }
        } else {
          // If no registration record, default to role-based check
          _isSeller = roles.contains('seller') || roles.contains('farmer');
        }

        if (!_isSeller) {
          _isViewingAsFarmer = false;
        }
        _startWatchingRegistrationStatus(user.id);
      } catch (e) {
        debugPrint('Error fetching roles/status on initialize: $e');
      }

      // Sync seller role if missing
      if (_isSeller) {
        try {
          final exists = await SupabaseDatabase.hasRole(
            userId: user.id,
            roleName: 'seller',
          );
          if (!exists) {
            await SupabaseDatabase.addUserRole(
              userId: user.id,
              roleName: 'seller',
            );
          }
        } catch (e) {
          debugPrint('Retry seller sync failed: $e');
        }
      }

      await _persistCachedUserState();
      await AnalyticsService().startSession(userId: user.id);
      _isInitialized = true;
      notifyListeners();
    } else {
      // User exists but email not confirmed - sign them out
      try {
        await _client.auth.signOut();
      } catch (_) {}
      _resetSessionState();
      _isInitialized = true;
      notifyListeners();
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

    // 🛡️ Brute-force protection check
    if (isLockedOut) {
      _errorMessage =
          'Too many attempts. Try again in $remainingLockoutSeconds seconds.';
      _isLoading = false;
      notifyListeners();
      return null;
    }

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
        await SupabaseDatabase.createUserIfNotExists(
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
      _resetSessionState();

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
    _clearpendingProfileState();
    notifyListeners();

    // 🛡️ Brute-force protection check
    if (isLockedOut) {
      _errorMessage =
          'Too many failed attempts. Try again in $remainingLockoutSeconds seconds.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      debugPrint(
        '🔵 AuthService.login: Attempting signInWithPassword for $email',
      );
      final response = await _client.auth
          .signInWithPassword(email: email, password: password)
          .timeout(const Duration(seconds: 20));

      debugPrint(
        '✅ AuthService.login: Auth response received. User ID: ${response.user?.id}',
      );

      if (response.user == null) {
        debugPrint('❌ AuthService.login: User is null in response');
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

      debugPrint('🔵 AuthService.login: Fetching DB profile for $_userId');
      // Fetch user profile — if missing, create it from auth metadata
      var profile = await SupabaseDatabase.getUserProfile(_userId).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⚠️ AuthService.login: Profile fetch timed out');
          return null;
        },
      );

      if (profile == null) {
        debugPrint('🟠 AuthService.login: Profile not found, creating one...');
        // Profile doesn't exist yet (trigger missing or checkEmailConfirmed failed)
        final metadata = response.user!.userMetadata;
        final metaName = (metadata?['name'] as String?) ?? '';
        final metaPhone = metadata?['phone_number'] as String?;
        try {
          await SupabaseDatabase.createUserIfNotExists(
            userId: _userId,
            email: email,
            name: metaName,
            phoneNumber: metaPhone,
            emailVerified:
                response.user!.appMetadata['provider'] == 'google' ||
                response.user!.emailConfirmedAt != null,
          ).timeout(const Duration(seconds: 10));

          profile = await SupabaseDatabase.getUserProfile(
            _userId,
          ).timeout(const Duration(seconds: 5), onTimeout: () => null);
          debugPrint('✅ AuthService.login: Profile created and re-fetched');
        } catch (e) {
          debugPrint('❌ AuthService.login: Error creating user profile: $e');
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
            await SupabaseDatabase.updateUserName(
              userId: _userId,
              name: metaName,
            );
          } catch (e) {
            debugPrint('Error updating user name on login: $e');
          }
        }
      }
      _userName = resolvedName;

      // Check if profile is incomplete (missing phone)
      final phone = profile?['phone'] as String?;
      final isVerified = (profile?['email_verified'] as bool?) ?? false;
      _isEmailVerified = isVerified;

      if ((phone == null || phone.isEmpty) && isVerified) {
        debugPrint(
          '🟠 AuthService.login: Profile incomplete and verified, setting flag',
        );
        _needsProfileCompletion = true;
        _pendingUserId = _userId;
        _pendingEmail = _userEmail;
        _pendingName = _userName;
      } else {
        _clearpendingProfileState();
      }

      // Ensure admin profile exists for known admin emails
      try {
        await SupabaseDatabase.ensureAdminProfileExists(
          userId: _userId,
          email: email,
        );
      } catch (e) {
        debugPrint('Warning: Could not ensure admin profile: $e');
      }

      debugPrint('🔵 AuthService.login: Fetching roles...');
      // Fetch roles from user_roles table
      final roles = await SupabaseDatabase.getUserRoles(_userId).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⚠️ AuthService.login: Roles fetch timed out');
          return <String>[];
        },
      );

      debugPrint('🔵 AuthService.login: Finalizing session...');
      final reg = await SupabaseDatabase.getFarmerRegistration(
        _userId,
      ).timeout(const Duration(seconds: 10), onTimeout: () => null);

      if (reg != null) {
        _registrationStatus = reg['status'] as String?;
        // CRITICAL FIX: Only allow seller mode if approved or verified.
        if (_registrationStatus == 'approved' || reg['is_verified'] == true) {
          _isSeller = true;
        } else {
          _isSeller = false;
        }
      } else {
        // Fallback to role-based check if no registration found
        _isSeller = roles.contains('seller') || roles.contains('farmer');
      }

      if (!_isSeller) {
        _isViewingAsFarmer = false;
      }

      _startWatchingRegistrationStatus(_userId);

      await _persistCachedUserState();
      await AnalyticsService()
          .startSession(userId: _userId)
          .timeout(const Duration(seconds: 5))
          .catchError((_) => null);

      debugPrint('✅ AuthService.login: SUCCESS');
      await _resetBruteForce();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _extractErrorMessage(e);

      // 🛡️ Increment failure count on wrong credentials
      if (_errorMessage!.toLowerCase().contains('invalid') ||
          _errorMessage!.toLowerCase().contains('credential')) {
        await _recordFailure();
      }

      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Finalize registration by updating password and phone number
  Future<bool> updateUserPasswordAndPhone({
    required String phoneNumber,
    required String password,
    String? email,
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
      await SupabaseDatabase.createUserIfNotExists(
        userId: user.id,
        email: email ?? user.email ?? _userEmail,
        name: _userName,
        phoneNumber: phoneNumber,
      );

      if ((user.email ?? '').isNotEmpty) {
        await clearPendingRegistrationPassword(user.email!);
      }

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
      await SupabaseDatabase.addUserRole(userId: _userId, roleName: 'seller');
    } catch (e) {
      debugPrint('Failed to sync seller role: $e');
    }
  }

  void switchToFarmerMode() {
    if (_isSeller && !_isViewingAsFarmer) {
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
      final reg = await SupabaseDatabase.getFarmerRegistration(_userId);
      if (reg != null) {
        final regStatus = reg['status'] as String?;
        final isVerified = reg['is_verified'] == true;
        _registrationStatus = isVerified ? 'approved' : regStatus;
        // Sync seller state with status
        if (_registrationStatus == 'approved' || isVerified) {
          _isSeller = true;
        } else {
          _isSeller = false;
        }
        await _persistCachedUserState();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error refreshing registration status: $e');
    }
  }

  void _startWatchingRegistrationStatus(String userId) {
    _regStatusSubscription?.cancel();
    _regStatusSubscription =
        SupabaseDatabase.watchFarmerRegistrationStatus(userId).listen((
          status,
        ) async {
          if (status != _registrationStatus) {
            _registrationStatus = status;

            // Re-fetch registration details to see if verified or approved
            final reg = await SupabaseDatabase.getFarmerRegistration(userId);
            if (reg != null) {
              if (reg['status'] == 'approved' || reg['is_verified'] == true) {
                _isSeller = true;
                _registrationStatus = 'approved';
              } else {
                _isSeller = false;
              }
            } else {
              _isSeller = false;
            }

            await _persistCachedUserState();
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
          await SupabaseDatabase.createUserIfNotExists(
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
          redirectTo: '${Uri.base.origin}/auth/callback',
          queryParams: const {'prompt': 'select_account'},
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
      var profile = await SupabaseDatabase.getUserProfile(user.id);
      final isIncompleteProfile =
          profile == null ||
          profile['phone'] == null ||
          (profile['phone'] as String).isEmpty;

      if (isIncompleteProfile) {
        _needsProfileCompletion = true;
        _pendingUserId = user.id;
        _pendingEmail = user.email ?? '';
        _pendingName =
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

      final roles = await SupabaseDatabase.getUserRoles(_userId);
      _isAdmin = await _resolveAdminStatus(_userId, roles, email: _userEmail);

      // Fetch registration status to determine _isSeller
      final reg = await SupabaseDatabase.getFarmerRegistration(_userId);
      if (reg != null) {
        _registrationStatus = reg['status'] as String?;
        if (_registrationStatus == 'approved' || reg['is_verified'] == true) {
          _isSeller = true;
        } else {
          _isSeller = false;
        }
      } else {
        _isSeller = roles.contains('seller') || roles.contains('farmer');
      }

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

  Future<bool> completeProfile({
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

      await SupabaseDatabase.createUserIfNotExists(
        userId: _pendingUserId,
        email: _pendingEmail,
        name: _pendingName,
        phoneNumber: phoneNumber,
        emailVerified:
            true, // If we reach here, they must be verified or have a session
      );

      await _client.auth.updateUser(UserAttributes(password: password));

      final roles = await SupabaseDatabase.getUserRoles(_pendingUserId);
      _userId = _pendingUserId;
      _userEmail = _pendingEmail;
      _userName = _pendingName;
      _needsProfileCompletion = false;
      _isAdmin = await _resolveAdminStatus(
        _pendingUserId,
        roles,
        email: _pendingEmail,
      );
      _isLoggedIn = true;

      // Fetch registration status to determine _isSeller
      final reg = await SupabaseDatabase.getFarmerRegistration(_userId);
      if (reg != null) {
        _registrationStatus = reg['status'] as String?;
        if (_registrationStatus == 'approved' || reg['is_verified'] == true) {
          _isSeller = true;
        } else {
          _isSeller = false;
        }
      } else {
        _isSeller = roles.contains('seller') || roles.contains('farmer');
      }

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
      final previousUserId = _userId;
      if (_userId.isNotEmpty) {
        await AnalyticsService().endSession(userId: _userId);
      }

      try {
        await GoogleSignIn().signOut();
      } catch (_) {}

      // Clear global login state
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_isLoggedInKeyGlobal);
      await prefs.remove(_lastUserIdKeyGlobal);

      await _client.auth.signOut();
      _resetSessionState();
      if (previousUserId.isNotEmpty) {
        await _clearCachedUserState(previousUserId);
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Logout failed: $e';
      notifyListeners();
    }
  }
}
