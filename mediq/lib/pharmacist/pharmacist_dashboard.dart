// lib/pharmacist_dashboard.dart - Dashboard for Pharmacist role (Matches Screenshot 2025-11-03 191858.png)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart'; // Assumes AppColors is defined here
import '../auth/login_page.dart'; // For logout navigation
import '../core/dashboard_screen.dart'; // Import the reusable drawer widget (The class name is PharmacistDrawer)

class PharmacistDashboard extends StatefulWidget {
  final String userName;
  final String userRole;

  const PharmacistDashboard({
    super.key,
    required this.userName,
    required this.userRole,
  });

  @override
  State<PharmacistDashboard> createState() => _PharmacistDashboardState();
}

class _PharmacistDashboardState extends State<PharmacistDashboard> {
  // Static demo values (matches the numbers in the screenshot)
  final int todayReleasesCount = 40;
  final int todayReturnsCount = 30;
  final int antibioticsTotal = 40;
  final int wardsTotal = 32;
  final int usageReleases = 32;
  final int usageReturns = 16;
  
  // --- Core Functions ---

  /// Handles the Firebase sign-out process and navigates to the LoginPage.
  Future<void> _handleLogout() async {
    try {
      // In a real app, you would handle Firebase initialization and authentication here.
      // For this demo, we assume FirebaseAuth is accessible.
      // await FirebaseAuth.instance.signOut(); 
      
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

  /// Handles navigation tap events from the drawer.
  void _onNavTap(String title) {
    // In a real app, this would route to the appropriate screen.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title tapped')),
    );
  }

  // --- Build Method ---

  @override
  Widget build(BuildContext context) {
    final displayName = widget.userName.isNotEmpty ? widget.userName : 'Malitha';
    final displayRole = widget.userRole.isNotEmpty ? widget.userRole : 'Pharmacist';

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: _buildAppBar(),
      // FIX: Changed 'PharmacDrawer' to 'PharmacistDrawer'
      drawer: PharmacistDrawer( 
        userName: displayName,
        userRole: displayRole,
        // The Pharmacist drawer has slightly fewer items (no Usage Analyst/Stocks)
        onNavTap: _onNavTap, 
        onLogout: _handleLogout, // Pass the complete logout handler here
      ),
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
      title: const Text('Pharmacist Dashboard', style: TextStyle(color: AppColors.darkestText)),
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

  // --- Header Card (Reused from Admin Dashboard) ---

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

  // --- Grid Layout and Tiles (Pharmacist Specific) ---

  Widget _buildTilesGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.50, // Aspect ratio matches the screenshot tiles
      children: [
        _tileAntibioticsRelease(), // New Pharmacist specific tile
        _tileAntibioticsReturns(), // New Pharmacist specific tile
        _tileAntibioticsFound(), // Simple Antibiotics count tile
        _tileSimple(icon: Icons.apartment, title: 'Wards', subtitle: 'Total Wards', value: '$wardsTotal'), // Reused
        _tileUsageDetails(), // Reused
        _buildSmallTile(icon: Icons.menu_book, title: 'Book Numbers'), // Reused
        // FIX: Changed 'Profile Manage' to 'Profile' to match Pharmacist role
        _buildSmallTile(icon: Icons.person_outline, title: 'Profile'),
        _buildSmallTile(icon: Icons.developer_board, title: 'Developer About'), // Reused
        _buildLogoutTile(), // Reused
        const SizedBox.shrink(), // Fills the final slot if needed
      ],
    );
  }

  // --- Generic Components (Reused) ---

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

  Widget _buildSmallTile({required IconData icon, required String title}) {
    return InkWell(
      onTap: () => _onNavTap(title),
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
  
  // --- Pharmacist Specific Tiles ---
  
  Widget _tileAntibioticsRelease() {
    return InkWell(
      onTap: () => _onNavTap('Antibiotics Release'),
      child: _smallCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, color: AppColors.primaryPurple, size: 28), 
                const Spacer(),
                const Text('Antibiotics\nRelease', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.darkText, fontSize: 14))
              ]
            ),
            const Spacer(),
            _miniStat('Today Releases', todayReleasesCount.toString(), AppColors.releasesCountColor),
          ],
        ),
      ),
    );
  }
  
  Widget _tileAntibioticsReturns() {
    return InkWell(
      onTap: () => _onNavTap('Antibiotics Returns'),
      child: _smallCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.archive, color: AppColors.primaryPurple, size: 28), 
                const Spacer(),
                const Text('Antibiotics\nReturns', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.darkText, fontSize: 14))
              ]
            ),
            const Spacer(),
            _miniStat('Today Returns', todayReturnsCount.toString(), AppColors.returnsCountColor),
          ],
        ),
      ),
    );
  }
  
  Widget _tileAntibioticsFound() {
    return InkWell(
      onTap: () => _onNavTap('Antibiotics'),
      child: _smallCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medication_liquid_outlined, color: AppColors.primaryPurple, size: 28), 
                const Spacer(),
                const Text('Antibiotics', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.darkText, fontSize: 14))
              ]
            ),
            const Spacer(),
            _miniStat('Total Found', antibioticsTotal.toString(), AppColors.totalFoundColor),
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
                Expanded(child: _miniStat('Today\nReleases', usageReleases.toString(), AppColors.releasesCountColor)),
                const SizedBox(width: 8),
                Expanded(child: _miniStat('Today\nReturns', usageReturns.toString(), AppColors.returnsCountColor)),
              ],
            ),
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
