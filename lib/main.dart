import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens/start_page.dart';
import 'screens/login_page.dart';
import 'screens/admin_dashboard.dart';
import 'screens/pharmacist_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Widget _getInitialPage() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return FutureBuilder(
        future: FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .get(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.done &&
              snap.hasData &&
              snap.data!.exists) {
            final role = snap.data!['role'];
            if (role == "admin") return const AdminDashboard();
            return const PharmacistDashboard();
          }
          return const StartPage();
        },
      );
    }
    return const StartPage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Medi-Q',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF0EDFD),
        primaryColor: const Color(0xFF8D78F9),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8D78F9),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ),
      home: _getInitialPage(),
    );
  }
}
