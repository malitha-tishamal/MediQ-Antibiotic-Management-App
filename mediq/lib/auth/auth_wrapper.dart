import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_load_check_screen.dart';
import 'login_page.dart';
import '../core/dashboard_wrapper.dart';
import 'start_page.dart';

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
          return const DashboardWrapper();
        }

        // User logged out → Start Page
        return const StartPage();
      },
    );
  }
}