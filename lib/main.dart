import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'shared/services/auth_service.dart';
import 'shared/services/onboarding_service.dart';
import 'shared/services/supabase_config.dart';
import 'mobile/mobile_navigation.dart';
import 'mobile/screens/auth/login_screen.dart';
import 'mobile/screens/common/onboarding_screen.dart';
import 'web/web_navigation.dart';
import 'web/screens/web_login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseConfig.initialize();

  await AuthService().initialize();

  runApp(const AgriDirectApp());
}

class AgriDirectApp extends StatefulWidget {
  const AgriDirectApp({super.key});

  @override
  State<AgriDirectApp> createState() => _AgriDirectAppState();
}

class _AgriDirectAppState extends State<AgriDirectApp> {
  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriDirect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF6F8F6),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF13EC5B),
          primary: const Color(0xFF13EC5B),
          surface: Colors.white,
        ),
      ),
      home: const AdaptiveLayout(),
    );
  }
}

/// Adaptive layout that chooses between mobile and web navigation.
/// Shows login screen if user is not logged in.
class AdaptiveLayout extends StatefulWidget {
  const AdaptiveLayout({super.key});

  @override
  State<AdaptiveLayout> createState() => _AdaptiveLayoutState();
}

class _AdaptiveLayoutState extends State<AdaptiveLayout> {
  final _auth = AuthService();
  bool _onboardingComplete = true; // assume true until checked
  bool _onboardingChecked = false;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuthChanged);
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final complete = await OnboardingService.isOnboardingComplete();
    if (mounted) {
      setState(() {
        _onboardingComplete = complete;
        _onboardingChecked = true;
      });
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    setState(() {});
  }

  void _handleOnboardingComplete() {
    setState(() => _onboardingComplete = true);
  }

  void _handleLoginSuccess() {
    setState(() {});
  }

  void _handleLogout() {
    _auth.logout();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Wait until onboarding status is loaded
    if (!_onboardingChecked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWeb = constraints.maxWidth > 800;

        // Show onboarding for first-time mobile users
        if (!isWeb && !_onboardingComplete) {
          return OnboardingScreen(
            onOnboardingComplete: _handleOnboardingComplete,
          );
        }

        if (!_auth.isLoggedIn) {
          if (isWeb) {
            return WebLoginScreen(onLoginSuccess: _handleLoginSuccess);
          } else {
            return MobileLoginScreen(onLoginSuccess: _handleLoginSuccess);
          }
        }

        if (isWeb) {
          return WebNavigation(onLogout: _handleLogout);
        } else {
          return MobileNavigation(onLogout: _handleLogout);
        }
      },
    );
  }
}
