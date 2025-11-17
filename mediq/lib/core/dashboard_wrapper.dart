// dashboard_wrapper.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../admin/admin_dashboard.dart';
import '../pharmacist/pharmacist_dashboard.dart';
import '../auth/login_page.dart';

class DashboardWrapper extends StatelessWidget {
  const DashboardWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const LoginPage();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Error loading user data. Check Firestore Rules.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;

          final userRole = userData?['role'] ?? 'User';
          final fullName = userData?['fullName'] ?? 'User';

          // ✅ Extract first name only
          final firstName = fullName.split(' ')[0];

          if (userRole == 'Admin') {
            return AdminDashboard(userName: firstName, userRole: userRole);
          } else if (userRole == 'Pharmacist') {
            return PharmacistDashboard(userName: firstName, userRole: userRole);
          }
        }

        return const Scaffold(
          body: Center(
            child: Text('Error: User role not found or invalid.'),
          ),
        );
      },
    );
  }
}
