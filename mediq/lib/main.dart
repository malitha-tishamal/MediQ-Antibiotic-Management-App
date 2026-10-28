import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import './core/firebase_options.dart';

// Import screens
import './views/auth/firebase_load_check_screen.dart';

import './views/auth/simple_preload_screen.dart';
import './views/auth/start_page.dart';   // 👈 ADD THIS


// ------------------- App Colors -------------------
class AppColors {
  static const Color primaryPurple = Color(0xFF865AD9);
  static const Color lightBackground = Color(0xFFF3F3FA);
  static const Color drawerBackground = Color(0xFFE2E7F3);
  static const Color darkestText = Color(0xFF1C1B1F);
  static const Color darkText = darkestText;
  static const Color buttonGradientStart = Color(0xFF9C27B0);
  static const Color buttonGradientEnd = Color(0xFF673AB7);
  static const Color inputBorder = Color(0xFFCAC4D0);
  static const Color adminsCountColor = Color(0xFFE53935);
  static const Color pharmacistCountColor = Color(0xFFE53935);
  static const Color totalFoundColor = Color(0xFF865AD9);
  static const Color totalWardsColor = Color(0xFF865AD9);
  static const Color stockTypesColor = Color(0xFF865AD9);
  static const Color releasesCountColor = Color(0xFFE53935);
  static const Color returnsCountColor = Color(0xFF865AD9);
  static const Color cardBg1 = Colors.white;
  static const Color cardBg2 = Color(0xFFF3E5F5);
  static const Color cardBg3 = Color(0xFFE0F7FA);
}

// ------------------- Main Entry Point -------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Note: .env file not loaded ($e), using AppConfig defaults.");
  }

  tz_data.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Colombo'));

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

// ------------------- Main App Widget -------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medi-Q App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.lightBackground,
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

// ------------------- Auth Wrapper -------------------
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const FirebaseLoadCheckScreen();
        }

        // User logged in
        if (snapshot.hasData && snapshot.data != null) {
          return const SimplePreloadScreen();
        }

        // No user → Start Page
        return const StartPage();
      },
    );
  }
}