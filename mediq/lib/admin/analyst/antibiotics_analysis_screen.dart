// antibiotics_analysis_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_drawer.dart';
import '../auth/login_page.dart';

class AppColors {
  static const Color primaryPurple = Color(0xFF9F7AEA);
  static const Color lightBackground = Color(0xFFF3F0FF);
  static const Color darkText = Color(0xFF333333);
  static const Color headerGradientStart = Color.fromARGB(255, 235, 151, 225);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
  static const Color headerTextDark = Color(0xFF333333);
}

class AntibioticsAnalysisScreen extends StatefulWidget {
  const AntibioticsAnalysisScreen({super.key});

  @override
  State<AntibioticsAnalysisScreen> createState() => _AntibioticsAnalysisScreenState();
}

class _AntibioticsAnalysisScreenState extends State<AntibioticsAnalysisScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference _userCollection = FirebaseFirestore.instance.collection('users');
  final CollectionReference _releasesCollection = FirebaseFirestore.instance.collection('releases');
  final CollectionReference _returnsCollection = FirebaseFirestore.instance.collection('returns');
  final CollectionReference _wardsCollection = FirebaseFirestore.instance.collection('wards');

  String _currentUserName = 'Loading...';
  String _currentUserRole = 'Administrator';
  String? _profileImageUrl;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserDetails();
  }

  Future<void> _fetchCurrentUserDetails() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _userCollection.doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            _currentUserName = data['fullName'] ?? user.email?.split('@').first ?? 'User';
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
        boxShadow: [BoxShadow(color: Color(0x10000000), blurRadius: 15, offset: Offset(0, 5))],
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
                      ? DecorationImage(image: NetworkImage(_profileImageUrl!), fit: BoxFit.cover)
                      : null,
                ),
                child: _profileImageUrl == null
                    ? const Icon(Icons.person, size: 40, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentUserName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.headerTextDark),
                  ),
                  Text(
                    'Logged in as: Administrator',
                    style: TextStyle(fontSize: 14, color: AppColors.headerTextDark.withOpacity(0.7)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 25),
          const Text(
            'Antibiotics Analysis',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.headerTextDark),
          ),
        ],
      ),
    );
  }

  /// Card with image, title, description, and dynamic content
  Widget _buildAnalysisCard({
    required String title,
    required String description,
    required String imageAsset,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: 300,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF9F7FF)],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
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
                left: BorderSide(color: color, width: 8),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Image with fallback
                Image.asset(
                  imageAsset,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(Icons.image_not_supported, size: 40, color: color);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Releases Card
  Widget _buildReleasesCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _releasesCollection.snapshots(),
      builder: (context, snapshot) {
        int totalReleases = 0;
        if (snapshot.hasData) {
          totalReleases = snapshot.data!.docs.length;
        }
        return _buildAnalysisCard(
          title: 'Releases Overview',
          description: 'Total antibiotic releases across all wards.',
          imageAsset: 'assets/releases.png', // Replace with your asset path
          color: Colors.green,
          child: Column(
            
          ),
        );
      },
    );
  }

  /// Returns Card
  Widget _buildReturnsCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _returnsCollection.snapshots(),
      builder: (context, snapshot) {
        int totalReturns = 0;
        if (snapshot.hasData) {
          totalReturns = snapshot.data!.docs.length;
        }
        return _buildAnalysisCard(
          title: 'Returns Overview',
          description: 'Total antibiotic returns from all wards.',
          imageAsset: 'assets/returns.png', // Replace with your asset path
          color: Colors.orange,
          child: Column(
            
          ),
        );
      },
    );
  }

  /// Releases by Ward Card
  Widget _buildReleasesByWardCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _releasesCollection.snapshots(),
      builder: (context, snapshot) {
        Map<String, int> wardCounts = {};
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final ward = data['wardName'] ?? 'Unknown';
            wardCounts[ward] = (wardCounts[ward] ?? 0) + 1;
          }
        }
        return _buildAnalysisCard(
          title: 'Releases by Ward',
          description: 'Breakdown of releases per ward.',
          imageAsset: 'assets/releases_ward.png',
          color: Colors.blue,
          child: wardCounts.isEmpty
              ? const Text('No data', style: TextStyle(color: Colors.grey))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: wardCounts.entries.map((entry) {
                    return _buildCountChip(entry.key, entry.value, Colors.blue);
                  }).toList(),
                ),
        );
      },
    );
  }

  /// Returns by Ward Card
  Widget _buildReturnsByWardCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _returnsCollection.snapshots(),
      builder: (context, snapshot) {
        Map<String, int> wardCounts = {};
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final ward = data['wardName'] ?? 'Unknown';
            wardCounts[ward] = (wardCounts[ward] ?? 0) + 1;
          }
        }
        return _buildAnalysisCard(
          title: 'Returns by Ward',
          description: 'Breakdown of returns per ward.',
          imageAsset: 'assets/returns_ward.png', // Replace with your asset path
          color: Colors.purple,
          child: wardCounts.isEmpty
              ? const Text('No data', style: TextStyle(color: Colors.grey))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: wardCounts.entries.map((entry) {
                    return _buildCountChip(entry.key, entry.value, Colors.purple);
                  }).toList(),
                ),
        );
      },
    );
  }

  /// Count chip widget
  Widget _buildCountChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildReleasesCard(),
                          const SizedBox(height: 20),
                          _buildReturnsCard(),
                          const SizedBox(height: 20),
                          _buildReleasesByWardCard(),
                          const SizedBox(height: 20),
                          _buildReturnsByWardCard(),
                          const SizedBox(height: 20), // Extra space at bottom
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