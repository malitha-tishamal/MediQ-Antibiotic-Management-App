import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// NOTE: You must create 'login_page.dart' and 'admin_drawer.dart', 
// and 'admin_profile_screen.dart' in the '../auth' and '.' directories respectively.
import '../auth/login_page.dart'; // For logout navigation
import 'admin_drawer.dart'; // Drawer widget
import 'admin_profile_screen.dart'; // Profile Screen

import 'accounts-manage-details.dart'; // Target for 'Accounts Manage'
import 'admin_developer_about_screen.dart'; // Target for 'Developer About'


// --- AppColors Class ---
class AppColors {
static const Color primaryPurple = Color(0xFF9F7AEA);
static const Color lightBackground = Color(0xFFF3F0FF);
static const Color darkText = Color(0xFF333333);
static const Color adminsCountColor = Color(0xFFE53935);
static const Color pharmacistCountColor = Color(0xFF43A047);
static const Color totalFoundColor = Color(0xFF1E88E5);
static const Color releasesCountColor = Color(0xFFE53935);
static const Color returnsCountColor = Color(0xFF43A047);
}

// --- AdminDashboard Widget ---
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
// Demo values for non-live data
final int antibioticsCount = 40;
final int wardsCount = 32;
final int stockTypesCount = 2;
final int todayReleases = 32;
final int todayReturns = 16;

// Firestore Collection Reference for real-time user data
final CollectionReference _userCollection =
 FirebaseFirestore.instance.collection('users');

/// Logout function
Future<void> _handleLogout() async {
 try {
 await FirebaseAuth.instance.signOut();
 if (mounted) {
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

/// Handle navigation from tiles or drawer
void _onNavTap(String title) {
  switch (title) {
    
    // FIX 1: Removed 'const' from AccountManageDetails constructor invocation
    case 'Accounts Manage':
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AccountManageDetails()), 
      );
      break;
    
    // FIX 2: Passed required 'userName' and 'userRole' parameters
    case 'Developer About':
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AdminDeveloperAboutScreen(
            userName: widget.userName,
            userRole: widget.userRole,
          ),
        ),
      );
      break;

    case 'Profile Manage':
    case 'Profile':
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
      );
      break;
      
    default:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title tapped')),
      );
      break;
  }
}
    

@override
Widget build(BuildContext context) {
 final displayName = widget.userName.isNotEmpty ? widget.userName : 'Malitha';
 final displayRole = widget.userRole.isNotEmpty ? widget.userRole : 'Administrator';

 return Scaffold(
 backgroundColor: AppColors.lightBackground,
 appBar: _buildAppBar(),
 drawer: AdminDrawer(
  userName: displayName,
  userRole: displayRole,
  onNavTap: _onNavTap,
  onLogout: _handleLogout,
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
    child: Text(
    'Home',
    style: TextStyle(
     fontSize: 18,
     fontWeight: FontWeight.bold,
     color: AppColors.darkText,
    ),
    ),
   ),
   const SizedBox(height: 8),
   _buildTilesGrid(),
   const SizedBox(height: 18),
   Center(
    child: Padding(
    padding: const EdgeInsets.only(bottom: 10.0),
    child: Text(
     'Developed By Malitha Tishamal',
     style: TextStyle(
     color: AppColors.darkText.withOpacity(0.6),
     fontSize: 12,
     ),
    ),
   ),
  )],
  ),
  ),
 ),
 );
}

// --- AppBar ---
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

 );
}

// --- Header Card ---
Widget _buildHeaderCard(String name, String role) {
 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
  gradient: const LinearGradient(
  colors: [Color(0xFFE6D6F7), Color(0xFFE9D7FD)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  ),
  borderRadius: BorderRadius.circular(18),
  boxShadow: [
  BoxShadow(
   color: AppColors.primaryPurple.withOpacity(0.08),
   blurRadius: 10,
   offset: const Offset(0, 4),
  ),
  ],
 ),
 child: Row(
  children: [
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
  ],
 ),
 );
}

// --- Tiles Grid ---
Widget _buildTilesGrid() {
 return GridView.count(
 crossAxisCount: 2,
 crossAxisSpacing: 12,
 mainAxisSpacing: 10,
 shrinkWrap: true,
 physics: const NeverScrollableScrollPhysics(),
 childAspectRatio: 1.50,
 children: [
  _tileAccountsManage(), // LIVE COUNT TILE (Taps to AccountManageDetails)
  _tileAntibiotics(),
  _tileSimple(icon: Icons.apartment, title: 'Wards', subtitle: 'Total Wards', value: '$wardsCount'),
  _tileSimple(icon: Icons.inventory_2_outlined, title: 'Stocks', subtitle: 'Stock Types', value: '$stockTypesCount'),
  _tileUsageDetails(),
  _buildSmallTile(icon: Icons.analytics_outlined, title: 'Usage Analyst'),
  _buildSmallTile(icon: Icons.menu_book, title: 'Book Numbers'),
  _buildSmallTile(icon: Icons.person_outline, title: 'Profile Manage'),
  _buildSmallTile(icon: Icons.developer_board, title: 'Developer About'), // Taps to AdminDeveloperAboutScreen
  _buildLogoutTile(),
 ],
 );
}

// --- Small Card Helper ---
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

// --- LIVE ACCOUNTS MANAGE TILE using StreamBuilder ---
Widget _tileAccountsManage() {
 return StreamBuilder<QuerySnapshot>(
 stream: _userCollection.snapshots(),
 builder: (context, snapshot) {
  int adminsCount = 0;
  int pharmacistsCount = 0;

  if (snapshot.hasData && snapshot.data != null) {
  // Iterate through the documents and count based on role
  for (var doc in snapshot.data!.docs) {
   final data = doc.data() as Map<String, dynamic>;
   final role = data['role'];
   if (role == 'Admin') {
   adminsCount++;
   } else if (role == 'Pharmacist') {
   pharmacistsCount++;
   }
  }
  }

  Widget content;

  if (snapshot.connectionState == ConnectionState.waiting) {
  content = const Center(child: LinearProgressIndicator(color: AppColors.primaryPurple));
  } else if (snapshot.hasError) {
  content = Text('Error: ${snapshot.error}', style: const TextStyle(fontSize: 10, color: Colors.red));
  } else {
  content = Row(
   children: [
   Expanded(child: _miniStat('Admins', adminsCount.toString(), AppColors.adminsCountColor)),
   const SizedBox(width: 8),
   Expanded(child: _miniStat('Pharmacist', pharmacistsCount.toString().padLeft(2, '0'), AppColors.pharmacistCountColor)),
   ],
  );
  }

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
    content, // Display the dynamic content (counts or loading)
   ],
   ),
  ),
  );
 },
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
    const Icon(Icons.circle, color: AppColors.primaryPurple, size: 28),
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

// --- Small Tiles ---
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

// --- Logout Tile ---
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