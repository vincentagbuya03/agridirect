import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'shared/services/auth_service.dart';
import 'shared/services/supabase_config.dart';
import 'shared/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseConfig.initialize();

  await AuthService().initialize();

  runApp(AgriDirectApp());
}

class AgriDirectApp extends StatelessWidget {
  AgriDirectApp({super.key});

  late final _router = createAppRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
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
      routerConfig: _router,
    );
  }
}
