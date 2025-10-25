import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Auth
import 'firebase_options.dart'; 

import 'firebase_load_check_screen.dart'; 
import 'login_page.dart'; 
import 'dashboard_wrapper.dart';
import 'auth_wrapper.dart'; // Must be imported for AuthWrapper class
import 'start_up_check_screen.dart'; // <-- New: The first widget to run

void main() async {
  // Ensure the Flutter binding is initialized before using plugins like Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase Core
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

// ------------------- Custom Colors -------------------
class AppColors {
  static const Color primaryPurple = Color(0xFF673AB7);
  static const Color lightBackground = Color(0xFFF3EDF7);
  static const Color darkText = Color(0xFF1C1B1F);
  static const Color buttonGradientStart = Color(0xFF9C27B0);
  static const Color buttonGradientEnd = Color(0xFF673AB7);
  static const Color inputBorder = Color(0xFFCAC4D0);
}

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
      // --- FIXED: Start here to check if the onboarding page is needed ---
      // This screen checks SharedPreferences and redirects to StartPage or AuthWrapper
      home: const StartUpCheckScreen(), 
    );
  }
}

// ------------------- Auth State Wrapper (Relied upon by StartUpCheckScreen) -------------------

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Listen to the authentication state stream
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 2. Show a loading screen while waiting for the stream data
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const FirebaseLoadCheckScreen(); 
        }

        // 3. If there is a user (signed in), go to the Dashboard Wrapper
        if (snapshot.hasData && snapshot.data != null) {
          // User is signed in
          return const DashboardWrapper(); 
        }

        // 4. Otherwise (no user), go to Login
        return const LoginPage(); 
      },
    );
  }
}
