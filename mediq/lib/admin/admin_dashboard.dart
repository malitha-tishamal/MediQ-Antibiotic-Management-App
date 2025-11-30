import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/login_page.dart';
import 'admin_drawer.dart';
import 'admin_profile_screen.dart';
import 'accounts-manage-details.dart';
import 'admin_developer_about_screen.dart';

// ---------------- App Colors ----------------
class AppColors {
  static const Color primaryPurple = Color(0xFF9F7AEA);
  static const Color lightBackground = Color(0xFFF3F0FF);
  static const Color darkText = Color(0xFF333333);
  static const Color adminsCountColor = Color(0xFFE53935);
  static const Color pharmacistCountColor = Color(0xFF43A047);
  static const Color totalFoundColor = Color(0xFF1E88E5);
  static const Color releasesCountColor = Color(0xFFE53935);
  static const Color returnsCountColor = Color(0xFF43A047);
  
  // Header gradient colors matching Factory Owner Dashboard
  static const Color headerGradientStart = Color.fromARGB(255, 235, 151, 225);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);  
  static const Color headerTextDark = Color(0xFF333333);
}

// ---------------- Dashboard ----------------
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
  final int antibioticsCount = 40;
  final int wardsCount = 32;
  final int stockTypesCount = 2;
  final int todayReleases = 32;
  final int todayReturns = 16;

  final CollectionReference _userCollection =
      FirebaseFirestore.instance.collection('users');

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchProfileImage();
  }

  void _fetchProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          setState(() {
            _profileImageUrl = userDoc.data()?['profileImageUrl'];
          });
        }
      } catch (e) {
        debugPrint("Error fetching profile image: $e");
      }
    }
  }

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

  void _onNavTap(String title) {
    switch (title) {
      case 'Accounts Manage':
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => AccountManageDetails()));
        break;

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
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        widget.userName.isNotEmpty ? widget.userName : 'Admin';
    final displayRole =
        widget.userRole.isNotEmpty ? widget.userRole : 'Administrator';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.lightBackground,
      drawer: AdminDrawer(
        userName: displayName,
        userRole: displayRole,
        onNavTap: _onNavTap,
        onLogout: _handleLogout,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // 🌟 NEW HEADER - Factory Owner Dashboard Style
                _buildDashboardHeader(context, displayName, displayRole),
                
                // Main Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Home', Icons.home_rounded),
                        const SizedBox(height: 10),
                        _buildTilesGrid(),
                        
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Fixed Footer Text
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Developed By Malitha Tishamal',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.darkText.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🌟 NEW HEADER - Factory Owner Dashboard Style
  Widget _buildDashboardHeader(BuildContext context, String name, String role) {
    return Container(
      padding: const EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.headerGradientStart, AppColors.headerGradientEnd],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.menu, color: AppColors.headerTextDark, size: 28),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          Row(
            children: [
              // Profile Picture
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _profileImageUrl == null 
                    ? const LinearGradient(
                        colors: [AppColors.primaryPurple, Color(0xFFB08FEB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPurple.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  image: _profileImageUrl != null 
                    ? DecorationImage(
                        image: NetworkImage(_profileImageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                ),
                child: _profileImageUrl == null
                    ? const Icon(Icons.person, size: 40, color: Colors.white)
                    : null,
              ),
              
              const SizedBox(width: 15),
              
              // User Info
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Admin Name
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.headerTextDark,
                    ),
                  ),
                  // Role
                  Text(
                    'Logged in as: $name \n($role)',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.headerTextDark.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 25),
          
          // Dashboard Title with Admin ID
          Text(
            'Administrative Dashboard',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.headerTextDark,
            ),
          ),
        ],
      ),
    );
  }

  // Section Title Widget
  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryPurple, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.darkText,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Tiles Grid ----------------
  Widget _buildTilesGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.50,
      children: [
        _tileAccountsManage(),
        _tileAntibiotics(),
        _tileSimple(
            icon: Icons.apartment,
            title: 'Wards',
            subtitle: 'Total Wards',
            value: '$wardsCount'),
        _tileSimple(
            icon: Icons.inventory_2_outlined,
            title: 'Stocks',
            subtitle: 'Stock Types',
            value: '$stockTypesCount'),
        _tileUsageDetails(),
        _buildSmallTile(icon: Icons.analytics_outlined, title: 'Usage Analyst'),
        _buildSmallTile(icon: Icons.menu_book, title: 'Book Numbers'),
        _buildSmallTile(icon: Icons.person_outline, title: 'Profile Manage'),
        _buildSmallTile(
            icon: Icons.developer_board, title: 'Developer About'),
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
          BoxShadow(
              color: AppColors.primaryPurple.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: child,
    );
  }

  Widget _miniStat(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12, color: AppColors.darkText.withOpacity(0.7))),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  // ---------------- Live Accounts Manage (Firestore Stream) ----------------
  Widget _tileAccountsManage() {
    return StreamBuilder<QuerySnapshot>(
      stream: _userCollection.snapshots(),
      builder: (context, snapshot) {
        int adminsCount = 0;
        int pharmacistsCount = 0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final role = data['role'];
            if (role == 'Admin') adminsCount++;
            if (role == 'Pharmacist') pharmacistsCount++;
          }
        }

        Widget content;

        if (snapshot.connectionState == ConnectionState.waiting) {
          content = const LinearProgressIndicator(
            color: AppColors.primaryPurple,
          );
        } else {
          content = Row(
            children: [
              Expanded(
                child: _miniStat('Admins', adminsCount.toString().padLeft(2, '0'),
                    AppColors.adminsCountColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniStat('Pharmacist',
                    pharmacistsCount.toString().padLeft(2, '0'),
                    AppColors.pharmacistCountColor),
              ),
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
                  children: const [
                    Icon(Icons.group_outlined,
                        color: AppColors.primaryPurple, size: 28),
                    Spacer(),
                    Text("Accounts\nManage",
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkText,
                            fontSize: 14)),
                  ],
                ),
                const Spacer(),
                content,
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------- Antibiotics Tile ----------------
  Widget _tileAntibiotics() {
    return InkWell(
      onTap: () => _onNavTap('Antibiotics'),
      child: _smallCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(
                  Icons.medication_liquid,
                  color: AppColors.primaryPurple,
                  size: 28,
                ),
                Spacer(),
                Text('Antibiotics',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText,
                        fontSize: 14)),
              ],
            ),
            const Spacer(),
            _miniStat('Total Found', antibioticsCount.toString(),
                AppColors.totalFoundColor),
          ],
        ),
      ),
    );
  }

  // ---------------- Simple Tiles ----------------
  Widget _tileSimple(
      {required IconData icon,
      required String title,
      required String subtitle,
      required String value}) {
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
                Text(title,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText,
                        fontSize: 14)),
              ],
            ),
            const Spacer(),
            _miniStat(subtitle, value, AppColors.primaryPurple),
          ],
        ),
      ),
    );
  }

  // ---------------- Usage Details ----------------
  Widget _tileUsageDetails() {
    return InkWell(
      onTap: () => _onNavTap('Usage Details'),
      child: _smallCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.receipt_long,
                    color: AppColors.primaryPurple, size: 28),
                Spacer(),
                Text('Usage Details',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText,
                        fontSize: 14)),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: _miniStat('Today\nReleases', todayReleases.toString(),
                      AppColors.releasesCountColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniStat('Today\nReturns', todayReturns.toString(),
                      AppColors.returnsCountColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Small Tile ----------------
  Widget _buildSmallTile({required IconData icon, required String title}) {
    return InkWell(
      onTap: () => _onNavTap(title),
      child: _smallCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primaryPurple, size: 26),
            const SizedBox(height: 8),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // ---------------- Logout Tile ----------------
  Widget _buildLogoutTile() {
    return InkWell(
      onTap: _handleLogout,
      child: _smallCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.logout, color: Colors.red, size: 34),
            SizedBox(height: 6),
            Text('Logout',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }
}