import 'package:flutter/material.dart';
import '../main.dart';

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

  String get _firstName {
    if (userName.isEmpty) return 'User';
    return userName.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 300,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.drawerBackground,
              AppColors.drawerBackground.withOpacity(0.9),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(2, 0),
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // ---------- Enhanced Drawer Header ----------
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryPurple.withOpacity(0.15),
                    AppColors.primaryPurple.withOpacity(0.05),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Logo and Name
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.buttonGradientStart,
                              AppColors.buttonGradientEnd,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(Icons.medication_outlined, 
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'MEDI-Q',
                        style: TextStyle(
                          color: AppColors.darkestText,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // User Info Section
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.buttonGradientStart,
                              AppColors.buttonGradientEnd,
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryPurple.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person_rounded, 
                            color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, $_firstName! 👋',
                              style: const TextStyle(
                                color: AppColors.darkestText,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryPurple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primaryPurple.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                userRole.toUpperCase(),
                                style: TextStyle(
                                  color: AppColors.primaryPurple,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ---------- Navigation Items ----------
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                children: [
                  _buildNavItem(
                    context: context,
                    icon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    onTap: () => onNavTap('Home'),
                    isActive: true,
                  ),
                  
                  _buildNavItem(
                    context: context,
                    icon: Icons.medical_services_rounded,
                    title: 'Antibiotics Management',
                    onTap: () => onNavTap('Antibiotics'),
                  ),
                  
                  _buildNavItem(
                    context: context,
                    icon: Icons.local_hospital_rounded,
                    title: 'Wards Management',
                    onTap: () => onNavTap('Wards'),
                  ),
                  
                  _buildNavItem(
                    context: context,
                    icon: Icons.receipt_long_rounded,
                    title: 'Usage Details',
                    onTap: () => onNavTap('Usage Details'),
                  ),
                  
                  _buildNavItem(
                    context: context,
                    icon: Icons.menu_book_rounded,
                    title: 'Record Books',
                    onTap: () => onNavTap('Book Numbers'),
                  ),

                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(height: 1, thickness: 1),
                  ),
                  const SizedBox(height: 10),

                  // Profile and About Section
                  _buildNavItem(
                    context: context,
                    icon: Icons.person_rounded,
                    title: 'My Profile',
                    onTap: () => onNavTap('Profile'),
                  ),
                  
                  _buildNavItem(
                    context: context,
                    icon: Icons.info_rounded,
                    title: 'About & Help',
                    onTap: () => onNavTap('Developer About'),
                  ),

                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(height: 1, thickness: 1),
                  ),
                  const SizedBox(height: 10),

                  // Logout Item
                  _buildLogoutItem(context),
                ],
              ),
            ),

            // ---------- Enhanced Footer ----------
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryPurple.withOpacity(0.08),
                    AppColors.primaryPurple.withOpacity(0.03),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Antibiotics Management System',
                    style: TextStyle(
                      color: AppColors.darkestText.withOpacity(0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.code_rounded,
                        color: AppColors.primaryPurple.withOpacity(0.6),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'v1.0.0 • Developed by Malitha Tishamal',
                        style: TextStyle(
                          color: AppColors.darkestText.withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(
                colors: [
                  AppColors.buttonGradientStart,
                  AppColors.buttonGradientEnd,
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(15),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.primaryPurple.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        horizontalTitleGap: 15,
        minLeadingWidth: 35,
        leading: Icon(
          icon,
          color: isActive ? Colors.white : AppColors.darkestText.withOpacity(0.7),
          size: 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.darkestText,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
        ),
        trailing: isActive
            ? const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16)
            : null,
        onTap: () {
          Navigator.of(context).pop();
          onTap();
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  Widget _buildLogoutItem(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        horizontalTitleGap: 15,
        minLeadingWidth: 35,
        leading: Icon(
          Icons.logout_rounded,
          color: Colors.red.withOpacity(0.9),
          size: 24,
        ),
        title: Text(
          'Logout',
          style: TextStyle(
            color: Colors.red.withOpacity(0.9),
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
        ),
        onTap: () {
          Navigator.of(context).pop();
          _showLogoutConfirmation(context);
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Title
                const Text(
                  'Confirm Logout',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                
                // Message
                const Text(
                  'Are you sure you want to logout from your account?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 25),
                
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: AppColors.primaryPurple),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: AppColors.primaryPurple),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onLogout();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Logout',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}