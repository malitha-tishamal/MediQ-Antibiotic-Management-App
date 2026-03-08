// lib/pharmacist_dashboard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../auth/login_page.dart';
import 'pharmacist_drawer.dart';
import 'pharmacist_developer_about_screen.dart';
import 'antibiotics_release_screen.dart';
import 'return_antibiotics_screen.dart';

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

  static const Color headerGradientStart = Color.fromARGB(255, 235, 151, 225);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
  static const Color headerTextDark = Color(0xFF333333);
}

// ---------------- Dashboard ----------------
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
  final CollectionReference _antibioticsCollection =
      FirebaseFirestore.instance.collection('antibiotics');
  final CollectionReference _wardsCollection =
      FirebaseFirestore.instance.collection('wards');
  final CollectionReference _releasesCollection =
      FirebaseFirestore.instance.collection('releases');
  final CollectionReference _returnsCollection =
      FirebaseFirestore.instance.collection('returns'); // adjust if needed

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Live user data (updates in real‑time)
  String _currentUserName = '';
  String _currentUserRole = '';
  String? _profileImageUrl;

  StreamSubscription<DocumentSnapshot>? _userSubscription;

  @override
  void initState() {
    super.initState();
    _currentUserName = widget.userName;
    _currentUserRole = widget.userRole;
    _listenToUserChanges();
  }

  void _listenToUserChanges() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          setState(() {
            _profileImageUrl = data['profileImageUrl'];
            _currentUserName =
                data['fullName'] ?? user.email?.split('@').first ?? 'User';
            _currentUserRole = data['role'] ?? 'Pharmacist';
          });
        }
      }, onError: (error) {
        debugPrint("Error listening to user: $error");
      });
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  // ---------- Sri Lanka time helpers ----------
  DateTime _getSriLankaNow() {
    return DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  }

  DateTime _getStartOfToday() {
    final now = _getSriLankaNow();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _getEndOfToday() {
    final start = _getStartOfToday();
    return start.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));
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
      case 'Antibiotics Release':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ReleaseAntibioticsScreen()),
        );
        break;
      
      case 'Antibiotics Returns':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ReturnAntibioticsScreen()),
        );
        break;

      case 'Developer About':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PharmacistDeveloperAboutScreen()),
        );
        break;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title tapped')),
        );
    }
  }

  Widget _buildDashboardHeader(BuildContext context) {
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
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
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
                  Text(
                    _currentUserName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.headerTextDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Logged in as: Pharmacist',
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
          const Text(
            'Pharmacist Dashboard',
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
        _tileAntibioticsRelease(),
        _tileAntibioticsReturns(),
        _tileAntibiotics(),
        _tileWards(),
        _tileUsageDetails(),
        _buildSmallTile(icon: Icons.menu_book, title: 'Book Numbers'),
        _buildSmallTile(icon: Icons.person_outline, title: 'Profile Manage'),
        _buildSmallTile(icon: Icons.developer_board, title: 'Developer About'),
        const SizedBox.shrink(),
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

  // ---------- Antibiotics Release Tile (live count) ----------
  Widget _tileAntibioticsRelease() {
    return InkWell(
      onTap: () => _onNavTap('Antibiotics Release'),
      child: _smallCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.receipt_long,
                    color: AppColors.primaryPurple, size: 28),
                Spacer(),
                Text('Antibiotics\nRelease',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText,
                        fontSize: 14)),
              ],
            ),
            const Spacer(),
            StreamBuilder<QuerySnapshot>(
              stream: _releasesCollection
                  .where('releaseDateTime', isGreaterThanOrEqualTo: _getStartOfToday())
                  .where('releaseDateTime', isLessThanOrEqualTo: _getEndOfToday())
                  .snapshots(),
              builder: (context, snapshot) {
                int count = 0;
                if (snapshot.hasData) {
                  count = snapshot.data!.docs.length;
                } else if (snapshot.hasError) {
                  debugPrint('Error fetching releases: ${snapshot.error}');
                }
                return _miniStat('Today Releases', count.toString().padLeft(2, '0'),
                    AppColors.releasesCountColor);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Antibiotics Returns Tile (live count) ----------
  Widget _tileAntibioticsReturns() {
    return InkWell(
      onTap: () => _onNavTap('Antibiotics Returns'),
      child: _smallCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.archive,
                    color: AppColors.primaryPurple, size: 28),
                Spacer(),
                Text('Antibiotics\nReturns',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText,
                        fontSize: 14)),
              ],
            ),
            const Spacer(),
            StreamBuilder<QuerySnapshot>(
              stream: _returnsCollection
                  .where('returnDateTime', isGreaterThanOrEqualTo: _getStartOfToday())
                  .where('returnDateTime', isLessThanOrEqualTo: _getEndOfToday())
                  .snapshots(),
              builder: (context, snapshot) {
                int count = 0;
                if (snapshot.hasData) {
                  count = snapshot.data!.docs.length;
                } else if (snapshot.hasError) {
                  debugPrint('Error fetching returns: ${snapshot.error}');
                }
                return _miniStat('Today Returns', count.toString().padLeft(2, '0'),
                    AppColors.returnsCountColor);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Antibiotics Tile (live count) ----------------
  Widget _tileAntibiotics() {
    return InkWell(
      onTap: () => _onNavTap('Antibiotics'),
      child: _smallCard(
        child: StreamBuilder<QuerySnapshot>(
          stream: _antibioticsCollection.snapshots(),
          builder: (context, snapshot) {
            int count = 0;
            if (snapshot.hasData) {
              count = snapshot.data!.docs.length;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
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
                _miniStat('Total Found', count.toString().padLeft(2, '0'),
                    AppColors.totalFoundColor),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------- Wards Tile (live count) ----------------
  Widget _tileWards() {
    return InkWell(
      onTap: () => _onNavTap('Wards'),
      child: _smallCard(
        child: StreamBuilder<QuerySnapshot>(
          stream: _wardsCollection.snapshots(),
          builder: (context, snapshot) {
            int count = 0;
            if (snapshot.hasData) {
              count = snapshot.data!.docs.length;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.local_hospital_rounded,
                      color: AppColors.primaryPurple,
                      size: 28,
                    ),
                    Spacer(),
                    Text('Wards',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkText,
                            fontSize: 14)),
                  ],
                ),
                const Spacer(),
                _miniStat('Total Wards', count.toString().padLeft(2, '0'),
                    AppColors.totalFoundColor),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------- Usage Details Tile (live counts) ----------------
  Widget _tileUsageDetails() {
    return InkWell(
      onTap: () => _onNavTap('Usage Details'),
      child: _smallCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
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
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _releasesCollection
                        .where('releaseDateTime', isGreaterThanOrEqualTo: _getStartOfToday())
                        .where('releaseDateTime', isLessThanOrEqualTo: _getEndOfToday())
                        .snapshots(),
                    builder: (context, snapshot) {
                      int count = 0;
                      if (snapshot.hasData) {
                        count = snapshot.data!.docs.length;
                      }
                      return _miniStat('Today\nReleases', count.toString(),
                          AppColors.releasesCountColor);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _returnsCollection
                        .where('returnDateTime', isGreaterThanOrEqualTo: _getStartOfToday())
                        .where('returnDateTime', isLessThanOrEqualTo: _getEndOfToday())
                        .snapshots(),
                    builder: (context, snapshot) {
                      int count = 0;
                      if (snapshot.hasData) {
                        count = snapshot.data!.docs.length;
                      }
                      return _miniStat('Today\nReturns', count.toString(),
                          AppColors.returnsCountColor);
                    },
                  ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.lightBackground,
      drawer: PharmacistDrawer(
        userName: _currentUserName,
        userRole: _currentUserRole,
        profileImageUrl: _profileImageUrl,
        onNavTap: _onNavTap,
        onLogout: _handleLogout,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildDashboardHeader(context),
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
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: const Color.fromARGB(255, 255, 255, 255),
              padding: const EdgeInsets.all(8.0),
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
}