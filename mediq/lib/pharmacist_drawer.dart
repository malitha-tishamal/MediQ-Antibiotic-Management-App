import 'package:flutter/material.dart';
import 'main.dart'; // Import AppColors

class PharmacistDrawer extends StatelessWidget {
  final String userName;
  final String userRole;
  final Function(String) onNavTap;
  final VoidCallback onLogout;

  const PharmacistDrawer({
    super.key,
    required this.userName,
    required this.userRole,
    required this.onNavTap,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    const Color textColor = AppColors.darkestText;

    // Menu items specific to the Pharmacist role
    List<Widget> drawerItems = [
      _drawerItem(context, Icons.home_rounded, 'Home', () => onNavTap('Home'),
          textColor: textColor, isActive: true),
      
      _drawerItem(context, Icons.medical_services_rounded, 'Antibiotics',
          () => onNavTap('Antibiotics'), textColor: textColor),
      _drawerItem(context, Icons.local_hospital_rounded, 'Wards',
          () => onNavTap('Wards'), textColor: textColor),

      _drawerItem(context, Icons.receipt_long_rounded, 'Usage Details',
          () => onNavTap('Usage Details'), textColor: textColor),
            
      _drawerItem(context, Icons.menu_book_rounded, 'Book Numbers',
          () => onNavTap('Book Numbers'), textColor: textColor),
      
      // Pharmacist uses 'Profile' (not 'Profile Manage')
      _drawerItem(context, Icons.person, 'Profile',
          () => onNavTap('Profile'), textColor: textColor),
    ];


    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.drawerBackground,
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
              decoration: const BoxDecoration(color: AppColors.drawerBackground),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo + App Name
                  Row(
                    children: [
                      // Placeholder for actual logo asset
                      const CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primaryPurple,
                        child: Icon(Icons.add, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'MEDI-Q',
                        style: TextStyle(
                          color: AppColors.darkestText,
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
                        child: Icon(Icons.person, color: AppColors.primaryPurple, size: 32),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome $userName',
                            style: const TextStyle(
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
                  ...drawerItems,
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
    final displayTitle = title; 
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 2),
      horizontalTitleGap: 10,
      minLeadingWidth: 28,
      leading: Icon(
        icon,
        color: isLogout
            ? Colors.red
            : (isActive ? AppColors.primaryPurple : textColor.withOpacity(0.85)),
        size: 25,
      ),
      title: Text(
        displayTitle,
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
