// admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:timezone/timezone.dart' as tz;

import '../auth/login_page.dart';
import 'admin_drawer.dart';
import 'admin_profile_screen.dart';
import 'accounts-manage-details.dart';
import 'admin_developer_about_screen.dart';
import 'antibiotics_management_screen.dart';
import 'wards_management_screen.dart';
import 'stocks_management_screen.dart';
import 'book_numbers_screen.dart';
import 'antibiotic_usage_screen.dart';
import 'antibiotics_usage_analysis_screen.dart';

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
  final String stockTypesCount = '02';

  final CollectionReference _userCollection =
      FirebaseFirestore.instance.collection('users');
  final CollectionReference _antibioticsCollection =
      FirebaseFirestore.instance.collection('antibiotics');
  final CollectionReference _wardsCollection =
      FirebaseFirestore.instance.collection('wards');

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Live user data
  String _currentUserName = '';
  String _currentUserRole = '';
  String? _profileImageUrl;

  StreamSubscription<DocumentSnapshot>? _userSubscription;

  // ---------- Sri Lanka time helpers (using timezone package) ----------
  DateTime _getSriLankaNow() => tz.TZDateTime.now(tz.local);

  // Start of today in Sri Lanka (00:00:00) as UTC
  DateTime _getUtcStartOfToday() {
    final now = _getSriLankaNow();
    final localStart = DateTime(now.year, now.month, now.day);
    return tz.TZDateTime.from(localStart, tz.local).toUtc();
  }

  // End of today in Sri Lanka (23:59:59.999) as UTC
  DateTime _getUtcEndOfToday() {
    final startUtc = _getUtcStartOfToday();
    return startUtc.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));
  }

  // Start of current month in Sri Lanka (first day, 00:00:00) as UTC
  DateTime _getUtcStartOfCurrentMonth() {
    final now = _getSriLankaNow();
    final localStart = DateTime(now.year, now.month, 1);
    return tz.TZDateTime.from(localStart, tz.local).toUtc();
  }

  // End of current month in Sri Lanka (last day, 23:59:59.999) as UTC
  DateTime _getUtcEndOfCurrentMonth() {
    final startUtc = _getUtcStartOfCurrentMonth();
    // Get the first day of next month in local time, then convert to UTC
    final startLocal = tz.TZDateTime.from(startUtc, tz.local);
    final nextMonth = DateTime(startLocal.year, startLocal.month + 1, 1);
    final utcNextMonthStart = tz.TZDateTime.from(nextMonth, tz.local).toUtc();
    return utcNextMonthStart.subtract(const Duration(microseconds: 1));
  }

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
            _currentUserRole = data['role'] ?? 'Administrator';
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
            .push(MaterialPageRoute(builder: (_) => const AccountManageDetails()));
        break;
      case 'Antibiotics':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AntibioticsManagementScreen()),
        );
        break;
      case 'Wards':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const WardsManagementScreen()),
        );
        break;
      case 'Stocks':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const StocksManagementScreen()),
        );
        break;
      case 'Book Numbers':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BookNumbersScreen()),
        );
        break;
      case 'Usage Details':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AntibioticUsageScreen()),
        );
        break;
      case 'Usage Analyst':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AntibioticsUsageAnalysisScreen()),
        );
        break;
      case 'Developer About':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminDeveloperAboutScreen()),
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
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.lightBackground,
      drawer: AdminDrawer(
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
                    'Logged in as: Administrator',
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
            'Administrative Dashboard',
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
        _tileWards(),
        _tileSimple(
            icon: Icons.inventory_2_outlined,
            title: 'Stocks',
            subtitle: 'Stock Types',
            value: stockTypesCount),
        _tileUsageDetails(),
        _buildSmallTile(
            icon: Icons.analytics_outlined,
            title: 'Usage Analyst',
            subtitle: 'Usage Analyze Graphs and More'),
        _buildSmallTile(
            icon: Icons.menu_book,
            title: 'Book Numbers',
            subtitle: 'For Connecting Manual System'),
        _buildSmallTile(
            icon: Icons.person_outline,
            title: 'Profile Manage',
            subtitle: 'Manage Profile Details'),
        _buildSmallTile(
            icon: Icons.developer_board,
            title: 'Developer About',
            subtitle: 'Contact Developers'),
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

  // Accounts Manage Tile (live counts)
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
                const Row(
                  children: [
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

  // Antibiotics Tile
  Widget _tileAntibiotics() {
    return InkWell(
      onTap: () => _onNavTap('Antibiotics'),
      child: _smallCard(
        child: StreamBuilder<QuerySnapshot>(
          stream: _antibioticsCollection.snapshots(),
          builder: (context, snapshot) {
            int total = 0;
            Set<String> categories = {};

            if (snapshot.hasData) {
              final docs = snapshot.data!.docs;
              total = docs.length;
              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final category = data['category'] ?? '';
                if (category.isNotEmpty) {
                  categories.add(category);
                }
              }
            }

            int categoryCount = categories.length;

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
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
                Row(
                  children: [
                    Expanded(
                      child: _miniStat('Total Found', total.toString().padLeft(2, '0'),
                          AppColors.totalFoundColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _miniStat('Categories', categoryCount.toString().padLeft(2, '0'),
                          AppColors.primaryPurple),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Wards Tile
  Widget _tileWards() {
    return InkWell(
      onTap: () => _onNavTap('Wards'),
      child: _smallCard(
        child: StreamBuilder<QuerySnapshot>(
          stream: _wardsCollection.snapshots(),
          builder: (context, snapshot) {
            int total = 0;
            Set<String> categories = {};

            if (snapshot.hasData) {
              final docs = snapshot.data!.docs;
              total = docs.length;
              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final category = data['category'] ?? '';
                if (category.isNotEmpty) {
                  categories.add(category);
                }
              }
            }

            int categoryCount = categories.length;

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
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
                Row(
                  children: [
                    Expanded(
                      child: _miniStat('Total Wards', total.toString().padLeft(2, '0'),
                          AppColors.totalFoundColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _miniStat('Categories', categoryCount.toString().padLeft(2, '0'),
                          AppColors.primaryPurple),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Simple Tile (Stocks)
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

  // Usage Details Tile (using timezone-aware UTC boundaries)
  Widget _tileUsageDetails() {
    final currentMonthName = DateFormat('MMMM').format(_getSriLankaNow());

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
                // Releases count for current month (UTC range)
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('releases')
                        .where('createdAt',
                            isGreaterThanOrEqualTo: _getUtcStartOfCurrentMonth())
                        .where('createdAt',
                            isLessThanOrEqualTo: _getUtcEndOfCurrentMonth())
                        .snapshots(),
                    builder: (context, snapshot) {
                      int count = 0;
                      if (snapshot.hasData) {
                        count = snapshot.data!.docs.length;
                      } else if (snapshot.hasError) {
                        debugPrint('Error fetching releases: ${snapshot.error}');
                      }
                      return _miniStat('$currentMonthName Releases',
                          count.toString().padLeft(2, '0'),
                          AppColors.releasesCountColor);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Returns count for current month (UTC range)
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('returns')
                        .where('createdAt',
                            isGreaterThanOrEqualTo: _getUtcStartOfCurrentMonth())
                        .where('createdAt',
                            isLessThanOrEqualTo: _getUtcEndOfCurrentMonth())
                        .snapshots(),
                    builder: (context, snapshot) {
                      int count = 0;
                      if (snapshot.hasData) {
                        count = snapshot.data!.docs.length;
                      } else if (snapshot.hasError) {
                        debugPrint('Error fetching returns: ${snapshot.error}');
                      }
                      return _miniStat('$currentMonthName Returns',
                          count.toString().padLeft(2, '0'),
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

  // Small Tile (used for other options)
  Widget _buildSmallTile({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return InkWell(
      onTap: () => _onNavTap(title),
      child: _smallCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primaryPurple, size: 26),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}