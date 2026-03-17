// lib/antibiotics_analysis_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'admin_drawer.dart';
import '../auth/login_page.dart';

class AppColors {
  static const Color primaryPurple = Color(0xFF9F7AEA);
  static const Color lightBackground = Color(0xFFF3F0FF);
  static const Color darkText = Color(0xFF333333);
  static const Color headerGradientStart = Color.fromARGB(255, 235, 151, 225);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
  static const Color headerTextDark = Color(0xFF333333);
  static const Color releaseColor = Colors.green;
  static const Color returnColor = Colors.orange;
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
  final CollectionReference _antibioticsCollection = FirebaseFirestore.instance.collection('antibiotics');

  String _currentUserName = 'Loading...';
  String _currentUserRole = 'Administrator';
  String? _profileImageUrl;
  bool _isUserLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Data for charts
  int _totalReleases = 0;
  int _totalReturns = 0;
  Map<String, double> _categoryReleases = {}; // category -> total itemCount from releases
  Map<String, double> _categoryReturns = {};  // category -> total itemCount from returns
  Map<String, Map<String, int>> _monthlyData = {}; // monthYear -> {releases, returns}

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserDetails();
    _loadData();
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
    setState(() => _isUserLoading = false);
  }

  Future<void> _loadData() async {
    // Fetch antibiotics first to get category mapping
    final antibioticsSnapshot = await _antibioticsCollection.get();
    final Map<String, String> antibioticCategory = {};
    for (var doc in antibioticsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      antibioticCategory[doc.id] = data['category'] ?? 'Other';
    }

    // Fetch releases
    final releasesSnapshot = await _releasesCollection.get();
    _totalReleases = releasesSnapshot.docs.length;

    // Fetch returns
    final returnsSnapshot = await _returnsCollection.get();
    _totalReturns = returnsSnapshot.docs.length;

    // Category usage for releases
    Map<String, double> catReleases = {};
    for (var doc in releasesSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final antibioticId = data['antibioticId'] ?? '';
      final category = antibioticCategory[antibioticId] ?? 'Other';
      final itemCount = (data['itemCount'] as num?)?.toDouble() ?? 0;
      catReleases[category] = (catReleases[category] ?? 0) + itemCount;
    }
    _categoryReleases = catReleases;

    // Category usage for returns
    Map<String, double> catReturns = {};
    for (var doc in returnsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final antibioticId = data['antibioticId'] ?? '';
      final category = antibioticCategory[antibioticId] ?? 'Other';
      final itemCount = (data['itemCount'] as num?)?.toDouble() ?? 0;
      catReturns[category] = (catReturns[category] ?? 0) + itemCount;
    }
    _categoryReturns = catReturns;

    // Monthly data
    Map<String, Map<String, int>> monthly = {};

    void addToMonthly(Timestamp? ts, String type) {
      if (ts == null) return;
      final date = ts.toDate();
      final monthYear = DateFormat('MMM yyyy').format(date);
      if (!monthly.containsKey(monthYear)) {
        monthly[monthYear] = {'releases': 0, 'returns': 0};
      }
      monthly[monthYear]![type] = monthly[monthYear]![type]! + 1;
    }

    for (var doc in releasesSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      addToMonthly(data['releaseDateTime'] as Timestamp?, 'releases');
    }
    for (var doc in returnsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      addToMonthly(data['returnDateTime'] as Timestamp?, 'returns');
    }

    // Sort months chronologically
    final sortedKeys = monthly.keys.toList()..sort((a, b) {
      final aDate = DateFormat('MMM yyyy').parse(a);
      final bDate = DateFormat('MMM yyyy').parse(b);
      return aDate.compareTo(bDate);
    });
    final sortedMonthly = <String, Map<String, int>>{};
    for (var key in sortedKeys) {
      sortedMonthly[key] = monthly[key]!;
    }
    _monthlyData = sortedMonthly;

    setState(() {});
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
                icon: const Icon(Icons.arrow_back, color: AppColors.headerTextDark, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
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
            'Overall Antibiotic Analysis',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.headerTextDark),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
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
                  Container(
                    color: Colors.white,
                    child: const TabBar(
                      labelColor: AppColors.primaryPurple,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: AppColors.primaryPurple,
                      tabs: [
                        Tab(icon: Icon(Icons.pie_chart), text: 'Pie Charts'),
                        Tab(icon: Icon(Icons.bar_chart), text: 'Bar Charts'),
                        Tab(icon: Icon(Icons.table_chart), text: 'Tables'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildPieChartsTab(),
                        _buildBarChartsTab(),
                        _buildTablesTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
      ),
    );
  }

  Widget _buildPieChartsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Releases vs Returns',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: _totalReleases.toDouble(),
                    title: 'Releases\n$_totalReleases',
                    color: AppColors.releaseColor,
                    radius: 80,
                  ),
                  PieChartSectionData(
                    value: _totalReturns.toDouble(),
                    title: 'Returns\n$_totalReturns',
                    color: AppColors.returnColor,
                    radius: 80,
                  ),
                ],
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            'Releases by Category',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            child: _categoryReleases.isEmpty
                ? const Center(child: Text('No release category data'))
                : PieChart(
                    PieChartData(
                      sections: _categoryReleases.entries.map((entry) {
                        return PieChartSectionData(
                          value: entry.value,
                          title: '${entry.key}\n${entry.value.toInt()}',
                          color: Colors.primaries[entry.key.hashCode % Colors.primaries.length],
                          radius: 80,
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                    ),
                  ),
          ),
          const SizedBox(height: 30),
          const Text(
            'Returns by Category',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            child: _categoryReturns.isEmpty
                ? const Center(child: Text('No return category data'))
                : PieChart(
                    PieChartData(
                      sections: _categoryReturns.entries.map((entry) {
                        return PieChartSectionData(
                          value: entry.value,
                          title: '${entry.key}\n${entry.value.toInt()}',
                          color: Colors.primaries[entry.key.hashCode % Colors.primaries.length],
                          radius: 80,
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChartsTab() {
    if (_monthlyData.isEmpty) {
      return const Center(child: Text('No monthly data'));
    }
    final months = _monthlyData.keys.toList();
    final releasesBars = months.map((m) => _monthlyData[m]!['releases']!.toDouble()).toList();
    final returnsBars = months.map((m) => _monthlyData[m]!['returns']!.toDouble()).toList();
    final double maxY = (releasesBars + returnsBars).reduce((a, b) => a > b ? a : b) + 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Releases & Returns',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < months.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(months[value.toInt()], style: const TextStyle(fontSize: 10)),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, interval: 1),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(months.length, (index) {
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: releasesBars[index],
                        color: AppColors.releaseColor,
                        width: 12,
                      ),
                      BarChartRodData(
                        toY: returnsBars[index],
                        color: AppColors.returnColor,
                        width: 12,
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Legend: Green = Releases, Orange = Returns',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTablesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Releases',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: _releasesCollection.orderBy('releaseDateTime', descending: true).limit(10).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No release records'),
                  ),
                );
              }
              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(data['antibioticName'] ?? 'Unknown'),
                      subtitle: Text('Ward: ${data['wardName'] ?? 'Unknown'} • Qty: ${data['itemCount'] ?? 0}'),
                      trailing: Text(DateFormat('dd MMM yyyy').format((data['releaseDateTime'] as Timestamp).toDate())),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Recent Returns',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: _returnsCollection.orderBy('returnDateTime', descending: true).limit(10).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No return records'),
                  ),
                );
              }
              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(data['antibioticName'] ?? 'Unknown'),
                      subtitle: Text('Ward: ${data['wardName'] ?? 'Unknown'} • Qty: ${data['itemCount'] ?? 0}'),
                      trailing: Text(DateFormat('dd MMM yyyy').format((data['returnDateTime'] as Timestamp).toDate())),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}