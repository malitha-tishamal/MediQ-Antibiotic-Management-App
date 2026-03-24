// ward_wise_usage_screen.dart – Complete updated version
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../admin_drawer.dart';
import '../../auth/login_page.dart';

class AppColors {
  static const Color primaryPurple = Color(0xFF9F7AEA);
  static const Color lightBackground = Color(0xFFF3F0FF);
  static const Color darkText = Color(0xFF333333);
  static const Color headerGradientStart = Color.fromARGB(255, 235, 151, 225);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
  static const Color headerTextDark = Color(0xFF333333);
  static const Color successGreen = Color(0xFF48BB78);
}

class WardWiseUsageScreen extends StatefulWidget {
  const WardWiseUsageScreen({super.key});

  @override
  State<WardWiseUsageScreen> createState() => _WardWiseUsageScreenState();
}

class _WardWiseUsageScreenState extends State<WardWiseUsageScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference _releasesCollection =
      FirebaseFirestore.instance.collection('releases');
  final CollectionReference _returnsCollection =
      FirebaseFirestore.instance.collection('returns');
  final CollectionReference _wardsCollection =
      FirebaseFirestore.instance.collection('wards');

  String _currentUserName = 'Loading...';
  String _currentUserRole = 'Administrator';
  String? _profileImageUrl;
  bool _isLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Ward data aggregated for the cards
  List<WardData> _wardsData = [];
  double _totalReleases = 0;
  double _totalReturns = 0;
  double _netUsage = 0;
  int _totalWards = 0;
  String _topWardName = 'N/A';
  double _topWardNet = 0;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserDetails();
    _fetchData();
  }

  Future<void> _fetchCurrentUserDetails() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
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
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      // Fetch wards
      final wardSnapshot = await _wardsCollection.get();
      final Map<String, String> wardNames = {};
      for (var doc in wardSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        wardNames[doc.id] = data['wardName'] ?? 'Unknown';
      }
      _totalWards = wardNames.length;

      // Fetch releases
      final releaseSnapshot = await _releasesCollection.get();
      final Map<String, double> releaseUnits = {};
      for (var doc in releaseSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final wardId = data['wardId'] ?? '';
        final dosageStr = data['dosage'] ?? '';
        final itemCount = (data['itemCount'] ?? 0).toDouble();
        final units = _calculateUnits(dosageStr, itemCount);
        if (units > 0) {
          releaseUnits[wardId] = (releaseUnits[wardId] ?? 0) + units;
        }
      }

      // Fetch returns
      final returnSnapshot = await _returnsCollection.get();
      final Map<String, double> returnUnits = {};
      for (var doc in returnSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final wardId = data['wardId'] ?? '';
        final dosageStr = data['dosage'] ?? '';
        final itemCount = (data['itemCount'] ?? 0).toDouble();
        final units = _calculateUnits(dosageStr, itemCount);
        if (units > 0) {
          returnUnits[wardId] = (returnUnits[wardId] ?? 0) + units;
        }
      }

      // Combine into list
      final List<WardData> wards = [];
      double totalRel = 0;
      double totalRet = 0;
      for (var entry in wardNames.entries) {
        final wardId = entry.key;
        final wardName = entry.value;
        final rel = releaseUnits[wardId] ?? 0;
        final ret = returnUnits[wardId] ?? 0;
        totalRel += rel;
        totalRet += ret;
        wards.add(WardData(
          wardId: wardId,
          wardName: wardName,
          totalReleases: rel,
          totalReturns: ret,
          netUsage: rel - ret,
        ));
      }

      // Sort by net usage descending to find top ward
      wards.sort((a, b) => b.netUsage.compareTo(a.netUsage));

      setState(() {
        _wardsData = wards;
        _totalReleases = totalRel;
        _totalReturns = totalRet;
        _netUsage = totalRel - totalRet;
        if (wards.isNotEmpty) {
          _topWardName = wards.first.wardName;
          _topWardNet = wards.first.netUsage;
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching ward data: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  double _calculateUnits(String dosageStr, double itemCount) {
    if (itemCount == 0 || dosageStr.isEmpty) return 0;
    final dosageMg = _parseDosageToMg(dosageStr);
    if (dosageMg == 0) return 0;
    return (itemCount * dosageMg) / 1000; // convert to units
  }

  double _parseDosageToMg(String dosage) {
    if (dosage.isEmpty) return 0;
    final normalized = dosage.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    final RegExp regex = RegExp(r'^([0-9]*\.?[0-9]+)\s*([a-z%]+)?$');
    final match = regex.firstMatch(normalized);
    if (match == null) return 0;

    final numberStr = match.group(1) ?? '0';
    final unit = match.group(2) ?? '';
    double value = double.tryParse(numberStr) ?? 0;

    if (unit.isEmpty) return 0;

    switch (unit) {
      case 'g':
        return value * 1000;
      case 'mg':
        return value;
      case 'mcg':
      case 'µg':
        return value / 1000;
      case 'ml':
      case 'cc':
        return value * 1000;
      default:
        return 0;
    }
  }

  Widget _buildHeader() {
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
            'Ward-wise Usage Analysis',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.headerTextDark),
          ),
        ],
      ),
    );
  }

  /// Reusable card widget (same style as the first screen)
  Widget _buildAnalysisCard({
    required String title,
    required String description,
    required String imageAsset,
    required Color color,
    required Widget child,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
      ),
    );
  }

  // Card 1: Ward-wise Releases – empty child replaced with SizedBox.shrink()
  Widget _buildWardReleasesCard() {
    return _buildAnalysisCard(
      title: 'Wards Releases Overview Chats',
      description: 'Graphical Overview of Antibiotics release Each Ward.',
      imageAsset: 'assets/analyst/cards/ward-wise-overviews/releases.jpg',
      color: Colors.green,
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Navigate to Ward Releases Detail')),
        );
      },
      child: const SizedBox.shrink(), // removed empty text
    );
  }

  // Card 2: Ward-wise Returns – empty child replaced with SizedBox.shrink()
  Widget _buildWardReturnsCard() {
    return _buildAnalysisCard(
      title: 'Wards Returns Overview Chats',
      description: 'Graphical Overview of Antibiotics Returns Each Ward.',
      imageAsset: 'assets/analyst/cards/ward-wise-overviews/returns.jpg',
      color: Colors.orange,
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Navigate to Ward Returns Detail')),
        );
      },
      child: const SizedBox.shrink(), 
    );
  }

  // Card 3: Net Usage by Ward
  Widget _buildNetUsageCard() {
    return _buildAnalysisCard(
      title: 'Releases Details Analyst',
      description: 'Full A–Z breakdown Antibiotics releases Each Ward Detailes.',
      imageAsset: 'assets/analyst/cards/ward-wise-overviews/releases-all.jpg',
      color: AppColors.primaryPurple,
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Navigate to Net Usage Detail')),
        );
      },
      child: Column(
        children: [
          // empty, can be filled later
        ],
      ),
    );
  }

  // Card 4: Ward Comparison / Overview
  Widget _buildWardOverviewCard() {
    return _buildAnalysisCard(
      title: 'Returns Details Analyst',
      description: 'Full A–Z breakdown Antibiotics Returns Each Ward Detailes',
      imageAsset: 'assets/analyst/cards/ward-wise-overviews/returns-all.jpg',
      color: Colors.blue,
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Navigate to Ward Overview')),
        );
      },
      child: Column(
        children: [
          // empty, can be filled later
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = [
      _buildWardReleasesCard(),
      _buildWardReturnsCard(),
      _buildNetUsageCard(),
      _buildWardOverviewCard(),
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.lightBackground,
      drawer: AdminDrawer(
        userName: _currentUserName,
        userRole: _currentUserRole,
        profileImageUrl: _profileImageUrl,
        onNavTap: (title) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title tapped')),
        ),
        onLogout: _handleLogout,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                if (_isLoading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
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
}

// Data model for a ward
class WardData {
  final String wardId;
  final String wardName;
  final double totalReleases;
  final double totalReturns;
  final double netUsage;

  WardData({
    required this.wardId,
    required this.wardName,
    required this.totalReleases,
    required this.totalReturns,
    required this.netUsage,
  });
}