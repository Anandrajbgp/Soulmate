import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_config.dart';
import 'services/auth_service.dart';
import 'screens/splash_screen.dart';

/// Global theme controller (drawer se Light/Dark toggle karne ke liye).
final ValueNotifier<ThemeMode> themeNotifier =
    ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase: Google login (JWT session) + secure Gemini edge function.
  // Values --dart-define se aati hain (SETUP.md dekhein). Agar configured
  // nahi hai toh app local/Google-only mode me chalta rehta hai.
  if (AppConfig.isSupabaseConfigured) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseAnonKey,
      );
      AuthService.supabaseReady = true;
    } catch (_) {
      // Galat/missing config par app crash nahi hoga — fallback mode.
      AuthService.supabaseReady = false;
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF075E54);

    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: const Color(0xFF25D366),
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: const Color(0xFF00A884),
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1F2C34),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Soulmate',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: mode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
