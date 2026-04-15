import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Note: These imports must exist in your project for AuthWrapper to function.
import 'firebase_load_check_screen.dart'; // Your loading/splash screen
import 'login_page.dart'; 
import '../core/dashboard_wrapper.dart'; // Checks the user's role and redirects

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to the Firebase authentication state stream
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Show a loading screen while waiting for the stream data
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const FirebaseLoadCheckScreen(); 
        }

        // 2. If there is a user (snapshot.hasData and snapshot.data is not null),
        // they are signed in. Send them to the Dashboard Wrapper to check their role.
        if (snapshot.hasData && snapshot.data != null) {
          return const DashboardWrapper(); 
        }

        // 3. Otherwise (no user signed in), go to the Login Page
        return const LoginPage(); 
      },
    );
  }
}
