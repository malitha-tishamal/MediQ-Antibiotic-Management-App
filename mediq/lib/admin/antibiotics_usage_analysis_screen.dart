// lib/antibiotics_usage_analysis_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_drawer.dart';
import '../auth/login_page.dart';
import 'analyst/antibiotics_analysis_screen.dart';
import 'analyst/ward_wise_usage_screen.dart';
import 'analyst/overall_summery.dart'; 

class AppColors {
  static const Color primaryPurple = Color(0xFF9F7AEA);
  static const Color lightBackground = Color(0xFFF3F0FF);
  static const Color darkText = Color(0xFF333333);
  static const Color headerGradientStart = Color.fromARGB(255, 235, 151, 225);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
  static const Color headerTextDark = Color(0xFF333333);
}

class AntibioticsUsageAnalysisScreen extends StatefulWidget {
  const AntibioticsUsageAnalysisScreen({super.key});

  @override
  State<AntibioticsUsageAnalysisScreen> createState() =>
      _AntibioticsUsageAnalysisScreenState();
}

class _AntibioticsUsageAnalysisScreenState
    extends State<AntibioticsUsageAnalysisScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference _userCollection =
      FirebaseFirestore.instance.collection('users');

  String _currentUserName = 'Loading...';
  String _currentUserRole = 'Administrator';
  String? _profileImageUrl;
  bool _isUserLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserDetails();
  }

  Future<void> _fetchCurrentUserDetails() async {
    setState(() => _isUserLoading = true);
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _userCollection.doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            _currentUserName =
                data['fullName'] ?? user.email?.split('@').first ?? 'User';
            _currentUserRole = data['role'] ?? 'Administrator';
            _profileImageUrl = data['profileImageUrl'];
          });
        } else {
          setState(() {
            _currentUserName = user.email?.split('@').first ?? 'User';
          });
        }
      } catch (e) {
        debugPrint('Error fetching user: $e');
      }
    }
    setState(() => _isUserLoading = false);
  }

  void _handleNavTap(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title tapped')),
    );
  }

  Future<void> _handleLogout() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Logout Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    }
  }

 Widget _buildHeader(BuildContext context) {
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
      mainAxisSize: MainAxisSize.min,
      children: [
        // Single row: menu (left), user info (center), profile picture (right)
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Menu button (left)
            IconButton(
              icon: const Icon(Icons.menu,
                  color: AppColors.headerTextDark, size: 28),
              onPressed: () {
                _scaffoldKey.currentState?.openDrawer();
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const Spacer(),
            // User info (centered)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentUserName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.headerTextDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Logged in as: Administrator',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.headerTextDark,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Profile picture (right) - 80x80 (radius 40)
            _buildProfileAvatar(),
          ],
        ),
        const SizedBox(height: 20),
        // Page title
        const Text(
          'Antibiotics Usage Analysis',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.headerTextDark,
          ),
        ),
      ],
    ),
  );
}

// Helper for profile avatar (80x80, radius 40)
Widget _buildProfileAvatar() {
  if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
    return CircleAvatar(
      radius: 40,
      backgroundImage: NetworkImage(_profileImageUrl!),
      backgroundColor: Colors.grey.shade200,
      onBackgroundImageError: (_, __) {
        if (mounted) setState(() => _profileImageUrl = null);
      },
    );
  } else {
    return CircleAvatar(
      radius: 40,
      backgroundColor: AppColors.primaryPurple.withOpacity(0.2),
      child: const Icon(Icons.person, color: AppColors.primaryPurple, size: 48),
    );
  }
}

  // Common card builder for consistent and compact size
  Widget _buildCard({
    required String imageAsset,
    required String title,
    required String description,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 250,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF9F7FF)],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryPurple.withOpacity(0.2),
              blurRadius: 18,
              offset: const Offset(0, 8),
              spreadRadius: -5,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: borderColor, width: 8),
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Image.asset(
                    imageAsset,
                    width: 120,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.image_not_supported,
                          size: 50, color: borderColor);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverallUsageButton() {
    return _buildCard(
      imageAsset: 'assets/analyst/antibiotic-usage.jpg',
      title: 'Overall Usage Overview',
      description:
          'Analyze antibiotic Release & Returns by each Antibiotic.',
      borderColor: const Color.fromARGB(255, 2, 21, 234),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AntibioticsAnalysisScreen()),
        );
      },
    );
  }

  Widget _buildWardWiseUsageButton() {
    return _buildCard(
      imageAsset: 'assets/analyst/ward-usage.jpg',
      title: 'Ward-wise Usage',
      description:
          'Analyze Antibiotic Release & Returns by each ward.',
      borderColor: const Color.fromARGB(255, 1, 107, 228),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WardWiseUsageScreen()),
        );
      },
    );
  }

  Widget _buildAdvancedAnalysisButton() {
    return _buildCard(
      imageAsset: 'assets/analyst/all-usage.jpg',
      title: 'Advanced Analysis',
      description:
          'Filter by Antibiotic, Ward, and View Complete Detailed Insights.',
      borderColor: const Color.fromARGB(255, 100, 170, 231),
      onTap: () {
        // Navigation enabled
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const OverallSummaryScreen()),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.lightBackground,
      drawer: AdminDrawer(
        userName: _currentUserName,
        userRole: _currentUserRole,
        profileImageUrl: _profileImageUrl,
        onNavTap: _handleNavTap,
        onLogout: _handleLogout,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildOverallUsageButton(),
                          const SizedBox(height: 20),
                          _buildWardWiseUsageButton(),
                          const SizedBox(height: 20),
                          _buildAdvancedAnalysisButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Footer
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(8.0),
              child: const Text(
                'Developed By Malitha Tishamal',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ),
        ],
      ),
    );
  }
}