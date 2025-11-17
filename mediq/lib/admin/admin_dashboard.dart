import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login_page.dart'; // For logout navigation
import 'admin_drawer.dart'; // Import the reusable drawer widget
import 'admin_profile_screen.dart'; // <--- NEW: Import the Admin Profile Screen

// --- Placeholder for AppColors (assuming it's in main.dart or a utility file) ---
// Since the full code wasn't provided, I'm defining the necessary colors here
// so this file can run independently.
class AppColors {
  static const Color primaryPurple = Color(0xFF9F7AEA); 
  static const Color lightBackground = Color(0xFFF3F0FF); // Matches profile screen background
  static const Color darkText = Color(0xFF333333);
  static const Color adminsCountColor = Color(0xFFE53935); // Red
  static const Color pharmacistCountColor = Color(0xFF43A047); // Green
  static const Color totalFoundColor = Color(0xFF1E88E5); // Blue
  static const Color releasesCountColor = Color(0xFFE53935); // Red
  static const Color returnsCountColor = Color(0xFF43A047); // Green
}

class AdminDashboard extends StatefulWidget {
  final String userName;
  final String userRole;

  const AdminDashboard({
    super.key,
    required this.userName,
    required this.userRole,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // Static demo values (matches the numbers and padding in the screenshot)
  final int adminsCount = 10;
  final int pharmacistsCount = 05;
  final int antibioticsCount = 40;
  final int wardsCount = 32;
  final int stockTypesCount = 2;
  final int todayReleases = 32;
  final int todayReturns = 16;

  // --- Core Functions ---

  /// Handles the Firebase sign-out process and navigates to the LoginPage.
  Future<void> _handleLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        // Navigate to login and remove all previous routes from the stack
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      debugPrint('Logout Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: ${e.toString()}')),
        );
      }
    }
  }

  /// Handles navigation tap events from the drawer or tiles.
  void _onNavTap(String title) {
    if (title == 'Profile Manage' || title == 'Profile') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const AdminProfileScreen()),
      );
    } else {
      // In a real app, this would route to the appropriate screen.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title tapped')),
      );
    }
  }

  // --- Build Method ---

  @override
  Widget build(BuildContext context) {
    final displayName = widget.userName.isNotEmpty ? widget.userName : 'Malitha';
    final displayRole = widget.userRole.isNotEmpty ? widget.userRole : 'Administrator';

    // Placeholder for AdminDrawer (assuming it exists)
    Widget drawerWidget = AdminDrawer(
      userName: displayName,
      userRole: displayRole,
      onNavTap: _onNavTap,
      onLogout: _handleLogout,
    );
    
    // Fallback if AdminDrawer is not available
    // if (drawerWidget == null) {
    //   drawerWidget = Drawer(child: Center(child: Text('Drawer Placeholder')));
    // }

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: _buildAppBar(),
      // Using the reusable MediQDrawer component
      drawer: drawerWidget,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(displayName, displayRole),
              const SizedBox(height: 18),
              const Padding(
                padding: EdgeInsets.only(left: 6.0, bottom: 6),
                child: Text('Home', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText)),
              ),
              const SizedBox(height: 8),
              _buildTilesGrid(),
              const SizedBox(height: 18),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Text('Developed By Malitha Tishamal', style: TextStyle(color: AppColors.darkText.withOpacity(0.6), fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- App Bar ---

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.lightBackground,
      elevation: 0,
      leading: Builder(
        builder: (context) {
          return IconButton(
            icon: const Icon(Icons.menu, color: AppColors.darkText, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          );
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none, color: AppColors.darkText, size: 28),
          onPressed: () => _onNavTap('Notifications'),
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  // --- Header Card ---

  Widget _buildHeaderCard(String name, String role) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Gradient matches screenshot
        gradient: const LinearGradient(
          colors: [Color(0xFFE6D6F7), Color(0xFFE9D7FD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: AppColors.primaryPurple.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          // Circular avatar
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.6),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.person, size: 48, color: AppColors.primaryPurple),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome Back, $name', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText)),
                const SizedBox(height: 4),
                Text(role, style: TextStyle(fontSize: 13.5, color: AppColors.darkText.withOpacity(0.7))),
              ],
            ),
          ),
          // Bell icon on the card
          const Icon(Icons.notifications_none, color: AppColors.darkText, size: 24),
        ],
      ),
    );
  }

  // --- Grid Layout and Tiles ---

  Widget _buildTilesGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.50, // Aspect ratio matches the screenshot tiles
      children: [
        _tileAccountsManage(),
        _tileAntibiotics(),
        _tileSimple(icon: Icons.apartment, title: 'Wards', subtitle: 'Total Wards', value: '$wardsCount'),
        _tileSimple(icon: Icons.inventory_2_outlined, title: 'Stocks', subtitle: 'Stock Types', value: '$stockTypesCount'),
        _tileUsageDetails(),
        _buildSmallTile(icon: Icons.analytics_outlined, title: 'Usage Analyst'),
        _buildSmallTile(icon: Icons.menu_book, title: 'Book Numbers'),
        _buildSmallTile(icon: Icons.person_outline, title: 'Profile Manage'), // Profile Manage Tile
        _buildSmallTile(icon: Icons.developer_board, title: 'Developer About'),
        _buildLogoutTile(),
      ],
    );
  }

  Widget _smallCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: AppColors.primaryPurple.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))
        ]
      ),
      child: child,
    );
  }

  Widget _miniStat(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.darkText.withOpacity(0.7))),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  Widget _tileAccountsManage() {
    return InkWell(
      onTap: () => _onNavTap('Accounts Manage'),
      child: _smallCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.group_outlined, color: AppColors.primaryPurple, size: 28),
                const Spacer(),
                const Text('Accounts\nManage', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.darkText, fontSize: 14))
              ]
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(child: _miniStat('Admins', adminsCount.toString(), AppColors.adminsCountColor)),
                const SizedBox(width: 8),
                Expanded(child: _miniStat('Pharmacist', pharmacistsCount.toString().padLeft(2, '0'), AppColors.pharmacistCountColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tileAntibiotics() {
    return InkWell(
      onTap: () => _onNavTap('Antibiotics'),
      child: _smallCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.circle, color: AppColors.primaryPurple, size: 28), // Icon matches screenshot
                const Spacer(),
                const Text('Antibiotics', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.darkText, fontSize: 14))
              ]
            ),
            const Spacer(),
            _miniStat('Total Found', antibioticsCount.toString(), AppColors.totalFoundColor),
          ],
        ),
      ),
    );
  }

  Widget _tileSimple({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
  }) {
    return InkWell(
      onTap: () => _onNavTap(title),
      child: _smallCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primaryPurple, size: 28),
                const Spacer(),
                Text(title, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.darkText, fontSize: 14))
              ]
            ),
            const Spacer(),
            _miniStat(subtitle, value, AppColors.primaryPurple),
          ],
        ),
      ),
    );
  }

  Widget _tileUsageDetails() {
    return InkWell(
      onTap: () => _onNavTap('Usage Details'),
      child: _smallCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, color: AppColors.primaryPurple, size: 28),
                const Spacer(),
                const Text('Usage Details', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.darkText, fontSize: 14))
              ]
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(child: _miniStat('Today\nReleases', todayReleases.toString(), AppColors.releasesCountColor)),
                const SizedBox(width: 8),
                Expanded(child: _miniStat('Today\nReturns', todayReturns.toString(), AppColors.returnsCountColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // UPDATED: Handles navigation to AdminProfileScreen specifically for 'Profile Manage'
  Widget _buildSmallTile({required IconData icon, required String title}) {
    return InkWell(
      onTap: () => _onNavTap(title), // Calls the updated _onNavTap
      child: _smallCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primaryPurple, size: 26),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.darkText, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutTile() {
    return InkWell(
      onTap: _handleLogout,
      child: _smallCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.logout, color: Colors.red, size: 34),
            SizedBox(height: 6),
            Text('Logout', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}