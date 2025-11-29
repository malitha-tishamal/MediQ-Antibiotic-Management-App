import 'package:flutter/material.dart';
import '../main.dart' as main_app;
import 'admin_dashboard.dart';
import 'admin_profile_screen.dart';
import 'admin_developer_about_screen.dart';

class AdminDrawer extends StatelessWidget {
  final String userName;
  final String userRole;
  final String? profileImageUrl; // Changed from profileImageBase64
  final Function(String) onNavTap;
  final VoidCallback onLogout;

  const AdminDrawer({
    super.key,
    required this.userName,
    required this.userRole,
    this.profileImageUrl, // Updated parameter
    required this.onNavTap,
    required this.onLogout,
  });

  String get _firstName {
    if (userName.isEmpty) return 'User';
    return userName.split(' ').first;
  }

  // -------------------- PROFILE IMAGE (Network URL) --------------------
  Widget _buildProfileImage() {
    if (profileImageUrl != null && profileImageUrl!.isNotEmpty) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.6),
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: main_app.AppColors.primaryPurple.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.network(
            profileImageUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                  color: main_app.AppColors.primaryPurple,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return _buildDefaultProfileIcon();
            },
          ),
        ),
      );
    }
    return _buildDefaultProfileIcon();
  }

  // -------------------- FALLBACK DEFAULT ICON --------------------
  Widget _buildDefaultProfileIcon() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [
            main_app.AppColors.buttonGradientStart,
            main_app.AppColors.buttonGradientEnd,
          ],
        ),
        border: Border.all(
          color: Colors.white,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: main_app.AppColors.primaryPurple.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
  borderRadius: BorderRadius.circular(75), // 50% circular shape
  child: Image.asset(
    'assets/admin-default.jpg',
    height: 150,
    width: 150,            // important for perfect circle
    fit: BoxFit.cover,     // fills circle nicely
  ),
),

    );
  }

  @override
  Widget build(BuildContext context) {
    final Color textColor = main_app.AppColors.darkestText;

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
              main_app.AppColors.drawerBackground,
              main_app.AppColors.drawerBackground.withOpacity(0.9),
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
            // -------------------- HEADER --------------------
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    main_app.AppColors.primaryPurple.withOpacity(0.15),
                    main_app.AppColors.primaryPurple.withOpacity(0.05),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          image: const DecorationImage(
                            image: AssetImage('assets/logo2.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'MEDI-Q',
                        style: TextStyle(
                          color: main_app.AppColors.darkestText,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _buildProfileImage(),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, $_firstName! 👋',
                              style: const TextStyle(
                                color: main_app.AppColors.darkestText,
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
                                color: main_app.AppColors.primaryPurple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: main_app.AppColors.primaryPurple.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                userRole.toUpperCase(),
                                style: TextStyle(
                                  color: main_app.AppColors.primaryPurple,
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

            // -------------------- NAVIGATION ITEMS --------------------
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                children: [
                  _buildNavItem(
                    context: context,
                    icon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminDashboard(
                            userName: userName,
                            userRole: userRole,
                          ),
                        ),
                      );
                    },
                    isActive: true,
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.people_alt_rounded,
                    title: 'Accounts Management',
                    onTap: () => onNavTap('Accounts Manage'),
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
                    icon: Icons.inventory_2_rounded,
                    title: 'Stock Inventory',
                    onTap: () => onNavTap('Stocks'),
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.receipt_long_rounded,
                    title: 'Usage Details',
                    onTap: () => onNavTap('Usage Details'),
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.analytics_rounded,
                    title: 'Usage Analytics',
                    onTap: () => onNavTap('Usage Analyst'),
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
                  _buildNavItem(
                    context: context,
                    icon: Icons.person_rounded,
                    title: 'My Profile',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminProfileScreen(),
                        ),
                      );
                    },
                  ),

                  _buildNavItem(
                    context: context,
                    icon: Icons.info_rounded,
                    title: 'About & Help',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminDeveloperAboutScreen(
                            userName: userName,
                            userRole: userRole,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(height: 1, thickness: 1),
                  ),
                  const SizedBox(height: 10),
                  _buildLogoutItem(context),
                ],
              ),
            ),

            // -------------------- FOOTER --------------------
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    main_app.AppColors.primaryPurple.withOpacity(0.08),
                    main_app.AppColors.primaryPurple.withOpacity(0.03),
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
                      color: main_app.AppColors.darkestText.withOpacity(0.7),
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
                        color: main_app.AppColors.primaryPurple.withOpacity(0.6),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'v1.0.0 • Developed by Malitha Tishamal',
                        style: TextStyle(
                          color: main_app.AppColors.darkestText.withOpacity(0.5),
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

  // -------------------- NAV ITEM --------------------
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
                  main_app.AppColors.buttonGradientStart,
                  main_app.AppColors.buttonGradientEnd,
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(15),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: main_app.AppColors.primaryPurple.withOpacity(0.3),
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
          color: isActive ? Colors.white : main_app.AppColors.darkestText.withOpacity(0.7),
          size: 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : main_app.AppColors.darkestText,
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

  // -------------------- LOGOUT ITEM --------------------
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
                const Text(
                  'Confirm Logout',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Are you sure you want to logout from your account?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 25),
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
                          side: BorderSide(color: main_app.AppColors.primaryPurple),
                        ),
                        child: Text('Cancel', style: TextStyle(color: main_app.AppColors.primaryPurple)),
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
                        child: const Text('Logout', style: TextStyle(color: Colors.white)),
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