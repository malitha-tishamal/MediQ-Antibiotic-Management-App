import 'package:flutter/material.dart';
import '../main.dart' as main_app;
import 'pharmacist_dashboard.dart';
import 'pharmacist_developer_about_screen.dart';

class PharmacistDrawer extends StatefulWidget {
  final String userName;
  final String userRole;
  final String? profileImageUrl;
  final Function(String) onNavTap;
  final VoidCallback onLogout;

  const PharmacistDrawer({
    super.key,
    required this.userName,
    required this.userRole,
    this.profileImageUrl,
    required this.onNavTap,
    required this.onLogout,
  });

  @override
  State<PharmacistDrawer> createState() => _PharmacistDrawerState();
}

class _PharmacistDrawerState extends State<PharmacistDrawer> {
  final Color _primaryBlue = main_app.AppColors.primaryPurple;
  final Color _darkText = main_app.AppColors.darkestText;

  String get _firstName {
    if (widget.userName.isEmpty) return 'User';
    return widget.userName.split(' ').first;
  }

  String get _firstLetter {
    if (widget.userName.isEmpty) return 'U';
    return widget.userName[0].toUpperCase();
  }

  Widget _buildProfileImage() {
    if (widget.profileImageUrl != null && widget.profileImageUrl!.isNotEmpty) {
      return Container(
        width: 65,
        height: 65,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _primaryBlue, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: _primaryBlue.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.network(
            widget.profileImageUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return _buildLetterAvatar();
            },
          ),
        ),
      );
    } else {
      return _buildLetterAvatar();
    }
  }

  Widget _buildLetterAvatar() {
    return Container(
      width: 65,
      height: 65,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [
            main_app.AppColors.buttonGradientStart,
            main_app.AppColors.buttonGradientEnd,
          ],
        ),
        border: Border.all(color: _primaryBlue, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _firstLetter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.65,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 50),

          // Logo Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  child: Image.asset(
                    'assets/logo2.png',
                    width: 60,
                    height: 60,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.medical_services_rounded,
                      color: Color(0xFF2764E7),
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "MEDI-Q",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2764E7),
                        letterSpacing: -0.8,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Antibiotics Management",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF666482),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Profile Section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.white, Color(0xFFF8FAFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _primaryBlue.withOpacity(0.08),
                  blurRadius: 25,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.5),
            ),
            child: Row(
              children: [
                _buildProfileImage(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_firstName! 👋',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2C2A3A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _primaryBlue.withOpacity(0.3)),
                        ),
                        child: Text(
                          widget.userRole.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2764E7),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          _buildSectionDivider(),
          const SizedBox(height: 8),

          // ----- Pharmacist Menu Items -----
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              physics: const BouncingScrollPhysics(),
              children: [
                // Dashboard
                _buildModernDrawerItem(
                  icon: Icons.dashboard_rounded,
                  label: "Dashboard",
                  description: "Overview & Analytics",
                  isActive: true,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => PharmacistDashboard(
                          userName: widget.userName,
                          userRole: widget.userRole,
                        ),
                      ),
                    );
                  },
                ),
                // Antibiotics Release
                _buildModernDrawerItem(
                  icon: Icons.receipt_long_rounded,
                  label: "Antibiotics Release",
                  description: "Today's releases",
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onNavTap('Antibiotics Release');
                  },
                ),
                // Antibiotics Returns
                _buildModernDrawerItem(
                  icon: Icons.archive_rounded,
                  label: "Antibiotics Returns",
                  description: "Today's returns",
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onNavTap('Antibiotics Returns');
                  },
                ),
                // Wards
                _buildModernDrawerItem(
                  icon: Icons.local_hospital_rounded,
                  label: "Wards",
                  description: "Hospital wards & departments",
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onNavTap('Wards');
                  },
                ),
                // Usage Details
                _buildModernDrawerItem(
                  icon: Icons.receipt_long_rounded,
                  label: "Usage Details",
                  description: "Medication usage records",
                  onTap: () => widget.onNavTap('Usage Details'),
                ),
                // Record Books
                _buildModernDrawerItem(
                  icon: Icons.menu_book_rounded,
                  label: "Record Books",
                  description: "Medical record books",
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onNavTap('Book Numbers');
                  },
                ),
                const SizedBox(height: 10),
                _buildSectionDivider(),
                const SizedBox(height: 10),
                // My Profile
                _buildModernDrawerItem(
                  icon: Icons.person_rounded,
                  label: "My Profile",
                  description: "Personal settings & profile",
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onNavTap('Profile');
                  },
                ),
                // About & Help
                _buildModernDrawerItem(
                  icon: Icons.info_rounded,
                  label: "About & Help",
                  description: "App information & support",
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const PharmacistDeveloperAboutScreen()),
                    );
                  },
                ),
              ],
            ),
          ),

          // Logout Button
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade50, Colors.red.shade100.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
              border: Border.all(color: Colors.red.withOpacity(0.2), width: 1.5),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showLogoutConfirmation(context),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Logout",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.red,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Secure sign out",
                              style: TextStyle(fontSize: 11, color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.red.withOpacity(0.7),
                          size: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  "v1.0.0",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _darkText.withOpacity(0.4),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "MEDI-Q © 2026 • Developed by Malitha Tishamal",
                  style: TextStyle(
                    fontSize: 10,
                    color: _darkText.withOpacity(0.3),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Modern Drawer Item
  Widget _buildModernDrawerItem({
    required IconData icon,
    required String label,
    required String description,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: isActive
                  ? const LinearGradient(
                      colors: [Color(0xFF2764E7), Color(0xFF457AED)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.7),
                        Colors.white.withOpacity(0.4),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: _primaryBlue.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
              border: Border.all(
                color: isActive ? _primaryBlue.withOpacity(0.3) : Colors.white.withOpacity(0.8),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isActive ? Colors.white : _primaryBlue,
                  size: 18,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : _darkText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 11,
                          color: isActive ? Colors.white.withOpacity(0.8) : _darkText.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isActive ? Colors.white.withOpacity(0.7) : _primaryBlue.withOpacity(0.4),
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: Divider(color: _primaryBlue.withOpacity(0.2), height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              "MENU",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _primaryBlue.withOpacity(0.5),
                letterSpacing: 1.5,
              ),
            ),
          ),
          Expanded(child: Divider(color: _primaryBlue.withOpacity(0.2), height: 1)),
        ],
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
                  child: const Icon(
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
                          side: BorderSide(color: _primaryBlue),
                        ),
                        child: Text('Cancel', style: TextStyle(color: _primaryBlue)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onLogout();
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