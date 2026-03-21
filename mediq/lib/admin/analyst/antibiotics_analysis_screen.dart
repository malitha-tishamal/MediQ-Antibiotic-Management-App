import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../admin_drawer.dart';
import '../../auth/login_page.dart';

import 'pages/antibiotics_usage_charts_analysis.dart';
import 'pages/antibiotics_returns_charts_analysis.dart'; // new import

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
                icon: const Icon(Icons.arrow_back, color: AppColors.headerTextDark, size: 24),
                onPressed: () => Navigator.pop(context),
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
            'Antibiotics Usage Analysis',
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  imageAsset,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(Icons.image_not_supported, size: 40, color: color);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkText),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Releases Card (navigates to releases charts)
  Widget _buildReleasesCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AntibioticsUsageChartsAnalysisScreen()),
        );
      },
      child: StreamBuilder<QuerySnapshot>(
        stream: _releasesCollection.snapshots(),
        builder: (context, snapshot) {
          int totalReleases = 0;
          if (snapshot.hasData) {
            totalReleases = snapshot.data!.docs.length;
          }
          return _buildAnalysisCard(
            title: 'Releases Overview',
            description: 'Graphical overview of releases by category, ward, and trends.',
            imageAsset: 'assets/analyst/cards/releases.jpg',
            color: Colors.green,
            child: const SizedBox(), // can be extended later
          );
        },
      ),
    );
  }

  /// Returns Card (navigates to returns charts)
  Widget _buildReturnsCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AntibioticsReturnsAnalysisScreen()),
        );
      },
      child: StreamBuilder<QuerySnapshot>(
        stream: _returnsCollection.snapshots(),
        builder: (context, snapshot) {
          int totalReturns = 0;
          if (snapshot.hasData) {
            totalReturns = snapshot.data!.docs.length;
          }
          return _buildAnalysisCard(
            title: 'Returns Overview',
            description: 'Graphical overview returns by category, ward, and trends.',
            imageAsset: 'assets/analyst/cards/returns.png',
            color: Colors.orange,
            child: const SizedBox(),
          );
        },
      ),
    );
  }

  /// Releases by Ward Card
  Widget _buildReleasesByWardCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _releasesCollection.snapshots(),
      builder: (context, releaseSnapshot) {
        if (!releaseSnapshot.hasData) return const SizedBox();
        final releases = releaseSnapshot.data!.docs;

        return FutureBuilder<QuerySnapshot>(
          future: _wardsCollection.get(),
          builder: (context, wardSnapshot) {
            Map<String, String> wardNames = {};
            if (wardSnapshot.hasData) {
              for (var doc in wardSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                wardNames[doc.id] = data['wardName'] ?? 'Unknown';
              }
            }

            Map<String, int> wardCounts = {};
            for (var doc in releases) {
              final data = doc.data() as Map<String, dynamic>;
              final wardId = data['wardId'] ?? '';
              final wardName = wardNames[wardId] ?? 'Unknown';
              wardCounts[wardName] = (wardCounts[wardName] ?? 0) + 1;
            }

            var sortedEntries = wardCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            var topEntries = sortedEntries.take(5).toList();

            return _buildAnalysisCard(
              title: 'Releases by Ward',
              description: 'Full A–Z breakdown of ward releases with detailed table view.',
              imageAsset: 'assets/analyst/cards/releases-all.jpg',
              color: Colors.blue,
              child: topEntries.isEmpty
                  ? const Text('No data', style: TextStyle(color: Colors.grey))
                  : Column(
                      
                    ),
            );
          },
        );
      },
    );
  }

  /// Returns by Ward Card
  Widget _buildReturnsByWardCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _returnsCollection.snapshots(),
      builder: (context, returnSnapshot) {
        if (!returnSnapshot.hasData) return const SizedBox();
        final returns = returnSnapshot.data!.docs;

        return FutureBuilder<QuerySnapshot>(
          future: _wardsCollection.get(),
          builder: (context, wardSnapshot) {
            Map<String, String> wardNames = {};
            if (wardSnapshot.hasData) {
              for (var doc in wardSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                wardNames[doc.id] = data['wardName'] ?? 'Unknown';
              }
            }

            Map<String, int> wardCounts = {};
            for (var doc in returns) {
              final data = doc.data() as Map<String, dynamic>;
              final wardId = data['wardId'] ?? '';
              final wardName = wardNames[wardId] ?? 'Unknown';
              wardCounts[wardName] = (wardCounts[wardName] ?? 0) + 1;
            }

            var sortedEntries = wardCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            var topEntries = sortedEntries.take(5).toList();

            return _buildAnalysisCard(
              title: 'Returns by Ward',
              description: 'Full A–Z breakdown of ward returns with detailed table view.',
              imageAsset: 'assets/analyst/cards/returns-all.jpg',
              color: Colors.purple,
              child: topEntries.isEmpty
                  ? const Text('No data', style: TextStyle(color: Colors.grey))
                  : Column(
                      
                    ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = [
      _buildReleasesCard(),
      _buildReturnsCard(),
      _buildReleasesByWardCard(),
      _buildReturnsByWardCard(),
    ];

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
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: cards.length,
                          itemBuilder: (context, index) => cards[index],
                        ),
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