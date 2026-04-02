import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import your screens
import 'firebase_load_check_screen.dart'; // Loading screen while checking auth
import 'login_page.dart';
import 'loading_start.dart';               // New loading animation for logged-in users
// Note: DashboardWrapper is now reached via LoadingPage, so we don't need it directly here.

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Still determining the auth state → show a minimal loading screen
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const FirebaseLoadCheckScreen();
        }

        // 2. User is signed in → show the loading animation, which then goes to DashboardWrapper
        if (snapshot.hasData && snapshot.data != null) {
          return const LoadingPage();
        }

        // 3. No user → go to login page
        return const LoginPage();
      },
    );
  }
}