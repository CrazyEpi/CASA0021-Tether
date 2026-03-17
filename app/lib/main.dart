import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // [NEW] Added Firebase core
import 'firebase_options.dart';                  // [NEW] Added generated options
import 'models/user.dart';
import 'screens/login_screen.dart';
import 'screens/main_nav_screen.dart';

// [REVISED] main function must be async to initialize Firebase
void main() async {
  // [NEW] Required to allow platform-specific code (Firebase) to run before the UI
  WidgetsFlutterBinding.ensureInitialized();

  // [NEW] Connect to your Firebase project
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const GPPFitnessApp());
}

class GPPFitnessApp extends StatelessWidget {
  const GPPFitnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPP Cycling',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const LoginScreen(),
    );
  }
}

// ============================================================
// FLAT DESIGN THEME — Black / White / Lime Green
// ============================================================
class AppTheme {
  static const Color green      = Color(0xFFA8D84A);
  static const Color greenDark  = Color(0xFF7BAF1E);
  static const Color greenLight = Color(0xFFE8F5C8);
  static const Color black      = Color(0xFF1A1A1A);
  static const Color white      = Color(0xFFFFFFFF);
  static const Color offWhite   = Color(0xFFF6F8F1);
  static const Color grey       = Color(0xFF8A8A8A);
  static const Color greyLight  = Color(0xFFEEEEEE);
  static const Color red        = Color(0xFFE05252);

  // Legacy alias so existing screens still compile
  static const Color primaryOrange = green;

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: green,
          onPrimary: black,
          secondary: black,
          onSecondary: white,
          error: red,
          onError: white,
          surface: white,
          onSurface: black,
        ),
        scaffoldBackgroundColor: offWhite,
        appBarTheme: const AppBarTheme(
          backgroundColor: white,
          foregroundColor: black,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: black,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          iconTheme: IconThemeData(color: black),
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          color: white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: black,
            foregroundColor: white,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            elevation: 0,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: greyLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: green, width: 2),
          ),
          hintStyle: const TextStyle(color: grey, fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );
}