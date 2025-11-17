import 'package:flutter/material.dart';
import 'package:mediq/main.dart' as main_app; // Prefixed import to avoid AppColors conflict
import 'admin_profile_screen.dart'; // Profile screen

class AdminDrawer extends StatelessWidget {
  final String userName;
  final String userRole;
  final Function(String) onNavTap;
  final VoidCallback onLogout;

  const AdminDrawer({
    super.key,
    required this.userName,
    required this.userRole,
    required this.onNavTap,
    required this.onLogout,
  });

  // Method to get only the first part of the name
  String get _firstName {
    if (userName.isEmpty) return 'User';
    // Split by space and take only the first part
    return userName.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    final Color textColor = main_app.AppColors.darkestText; // Fixed

    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: main_app.AppColors.drawerBackground,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // ---------- Drawer Header ----------
            DrawerHeader(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              margin: EdgeInsets.zero,
              decoration: BoxDecoration(color: main_app.AppColors.drawerBackground),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo + App Name
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 22,
                        backgroundColor: main_app.AppColors.primaryPurple,
                        child: Icon(Icons.add, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'MEDI-Q',
                        style: TextStyle(
                          color: main_app.AppColors.darkestText,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // User Icon or Avatar
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, color: main_app.AppColors.primaryPurple, size: 32),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome $_firstName', // Use _firstName instead of userName
                            style: TextStyle(
                              color: textColor,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            userRole,
                            style: TextStyle(
                              color: textColor.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ---------- Drawer Body ----------
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _drawerItem(context, Icons.home_rounded, 'Home',
                      () => onNavTap('Home'), textColor: textColor, isActive: true),
                  _drawerItem(context, Icons.people_alt_rounded, 'Accounts Manage',
                      () => onNavTap('Accounts Manage'), textColor: textColor),
                  _drawerItem(context, Icons.medical_services_rounded, 'Antibiotics',
                      () => onNavTap('Antibiotics'), textColor: textColor),
                  _drawerItem(context, Icons.local_hospital_rounded, 'Wards',
                      () => onNavTap('Wards'), textColor: textColor),
                  _drawerItem(context, Icons.inventory_2_rounded, 'Stocks',
                      () => onNavTap('Stocks'), textColor: textColor),
                  _drawerItem(context, Icons.receipt_long_rounded, 'Usage Details',
                      () => onNavTap('Usage Details'), textColor: textColor),
                  _drawerItem(context, Icons.analytics_rounded, 'Usage Analyst',
                      () => onNavTap('Usage Analyst'), textColor: textColor),
                  _drawerItem(context, Icons.menu_book_rounded, 'Book Numbers',
                      () => onNavTap('Book Numbers'), textColor: textColor),

                  // ---------- Profile tab ----------
                  _drawerItem(
                    context,
                    Icons.person,
                    'Profile',
                    () {
                      Navigator.of(context).pop(); // Close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminProfileScreen(),
                        ),
                      );
                    },
                    textColor: textColor,
                  ),
                  const Divider(thickness: 0.6),

                  _drawerItem(context, Icons.developer_mode_rounded, 'Developer About',
                      () => onNavTap('Developer About'), textColor: textColor),
                  const Divider(thickness: 0.6),
                  _drawerItem(context, Icons.logout_rounded, 'Logout', onLogout,
                      textColor: textColor, isLogout: true),
                ],
              ),
            ),

            // ---------- Footer ----------
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Developed by Malitha Tishamal',
                style: TextStyle(
                  color: textColor.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Drawer Item Widget ----------
  Widget _drawerItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    required Color textColor,
    bool isActive = false,
    bool isLogout = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 2),
      horizontalTitleGap: 10,
      minLeadingWidth: 28,
      leading: Icon(
        icon,
        color: isLogout
            ? Colors.red
            : (isActive ? main_app.AppColors.primaryPurple : textColor.withOpacity(0.85)),
        size: 25,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isLogout ? Colors.red : textColor,
          fontWeight: FontWeight.w500,
          fontSize: 16,
          letterSpacing: 0.3,
        ),
      ),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
    );
  }
}