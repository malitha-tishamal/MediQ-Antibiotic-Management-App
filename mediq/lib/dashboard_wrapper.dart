// dashboard_wrapper.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_dashboard.dart'; // We'll create this next
import 'pharmacist_dashboard.dart'; // We'll create this next
import 'login_page.dart'; // To handle sign-out

class DashboardWrapper extends StatelessWidget {
  const DashboardWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Should not happen if coming from a successful login, but good practice
      return const LoginPage();
    }

    // StreamBuilder listens for the user document in Firestore
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show a simple loading indicator while fetching the role
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error loading user data: ${snapshot.error}')));
        }

        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          final userRole = userData?['role'];
          final userName = userData?['name'] ?? 'User';

          // Route to the appropriate dashboard based on the 'role' field
          if (userRole == 'Admin') {
            return AdminDashboard(userName: userName);
          } else if (userRole == 'Pharmacist') {
            return PharmacistDashboard(userName: userName);
          }
        }

        // Default to showing an error if data is missing or role is unknown
        return const Scaffold(
          body: Center(child: Text('Error: User role not found or invalid.')),
        );
      },
    );
  }
}