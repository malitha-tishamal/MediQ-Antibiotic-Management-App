// admin_dashboard.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart'; // Import AppColors
import 'login_page.dart'; // For sign out navigation

class AdminDashboard extends StatelessWidget {
  final String userName;
  const AdminDashboard({super.key, required this.userName});

  // Helper for the custom icons
  Widget _buildHomeIcon({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 30, color: AppColors.primaryPurple),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      // ------------------- Body -------------------
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- User Profile Card ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryPurple.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_circle, size: 50, color: AppColors.primaryPurple),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome Back, $userName',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                        ),
                      ),
                      const Text(
                        'Administrator',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
            
            const Text(
              'Home',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
              ),
            ),
            
            const SizedBox(height: 15),

            // --- Grid of Management Icons ---
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(), // Important for SingleChildScrollView
              childAspectRatio: 1.2, // Adjust card height
              children: [
                _buildHomeIcon(icon: Icons.people_outline, label: 'Accounts Manage'),
                _buildHomeIcon(icon: Icons.local_pharmacy_outlined, label: 'Antibiotics'),
                _buildHomeIcon(icon: Icons.location_city_outlined, label: 'Wards'),
                _buildHomeIcon(icon: Icons.inventory_2_outlined, label: 'Stock'),
              ],
            ),
          ],
        ),
      ),
      
      // ------------------- Bottom Navigation Bar -------------------
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  // Common Bottom Nav Bar
  Widget _buildBottomNavBar(BuildContext context) {
    return BottomAppBar(
      color: Colors.white,
      shape: const CircularNotchedRectangle(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          IconButton(icon: const Icon(Icons.home_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.person_outline), onPressed: () {}),
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () async {
              // Log out functionality
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (Route<dynamic> route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}