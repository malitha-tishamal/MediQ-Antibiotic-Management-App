// overall_summery.dart – cards styled like stocks_management_screen
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../auth/login_page.dart';
import 'overall_usage_summery/released_usage_summary.dart';
import 'overall_usage_summery/returned_usage_summary.dart';

class AppColors {
  static const Color primaryPurple = Color(0xFF9F7AEA);
  static const Color lightBackground = Color(0xFFF3F0FF);
  static const Color darkText = Color(0xFF333333);
  static const Color headerGradientStart = Color.fromARGB(255, 235, 151, 225);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
  static const Color headerTextDark = Color(0xFF333333);
  static const Color successGreen = Color(0xFF48BB78);
}

class OverallSummaryScreen extends StatefulWidget {
  const OverallSummaryScreen({super.key});

  @override
  State<OverallSummaryScreen> createState() => _OverallSummaryScreenState();
}

class _OverallSummaryScreenState extends State<OverallSummaryScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference _releasesCollection =
      FirebaseFirestore.instance.collection('releases');
  final CollectionReference _returnsCollection =
      FirebaseFirestore.instance.collection('returns');
  final CollectionReference _wardsCollection =
      FirebaseFirestore.instance.collection('wards');
  final CollectionReference _antibioticsCollection =
      FirebaseFirestore.instance.collection('antibiotics');

  String _currentUserName = 'Loading...';
  String _currentUserRole = 'Administrator';
  String? _profileImageUrl;
  bool _isLoading = true;

  // Summary data for cards (still fetched but not shown in description)
  double _totalReleaseUnits = 0;
  int _releaseWardsCount = 0;
  String _topReleaseWard = 'N/A';
  double _topReleaseValue = 0;

  double _totalReturnUnits = 0;
  int _returnWardsCount = 0;
  String _topReturnWard = 'N/A';
  double _topReturnValue = 0;

  // Antibiotics data cache (for concentration)
  Map<String, Map<String, dynamic>> _antibioticDataMap = {};

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserDetails();
    _loadAntibiotics();
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

  Future<void> _loadAntibiotics() async {
    try {
      final snapshot = await _antibioticsCollection.get();
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        _antibioticDataMap[doc.id] = {
          'category': data['category'] ?? 'Other',
          'concentrationMgPerMl': data['concentrationMgPerMl'] ?? null,
        };
      }
      _fetchData();
    } catch (e) {
      debugPrint('Error loading antibiotics: $e');
      setState(() => _isLoading = false);
    }
  }

  // ----------------------------------------------------------------------
  // UNIT CONVERSION LOGIC (same as in other corrected files)
  // ----------------------------------------------------------------------

  Map<String, dynamic> _parseDosage(String dosage) {
    if (dosage.isEmpty) return {'value': 0.0, 'unit': ''};

    final normalized = dosage.toLowerCase().trim();
    final regex = RegExp(r'(\d+(?:\.\d+)?)\s*([a-z/%-]+(?:\s+[a-z/%-]+)?)');
    final match = regex.firstMatch(normalized);
    if (match == null) {
      return {'value': 0.0, 'unit': ''};
    }

    final numberStr = match.group(1)!;
    double value = double.tryParse(numberStr) ?? 0;
    String rawUnit = match.group(2)!.trim();

    final lowerUnit = rawUnit.toLowerCase();
    final patterns = {
      r'\bmg\b': 'mg',
      r'\bmilligram\b': 'mg',
      r'\bg\b': 'g',
      r'\bgram\b': 'g',
      r'\bmcg\b': 'mcg',
      r'\bmicrogram\b': 'mcg',
      r'µg': 'mcg',
      r'\bml\b': 'ml',
      r'\bmilliliter\b': 'ml',
      r'\bcc\b': 'cc',
      r'\bcubic\s*centimeter\b': 'cc',
      r'\bu\b': 'U',
      r'\bunit\b': 'U',
      r'\biu\b': 'IU',
      r'\binternational\s*unit\b': 'IU',
      r'\biv\b': 'IV',
      r'\bintravenous\b': 'IV',
      r'\bmg/kg\b': 'mg/kg',
    };

    String coreUnit = '';
    for (final entry in patterns.entries) {
      if (RegExp(entry.key).hasMatch(lowerUnit)) {
        coreUnit = entry.value;
        break;
      }
    }
    if (coreUnit.isEmpty) coreUnit = rawUnit;

    return {'value': value, 'unit': coreUnit};
  }

  double? _convertToUnits(double value, String unit, Map<String, dynamic>? antibioticData) {
    switch (unit) {
      case 'mg':
        return value / 1000;
      case 'g':
        return value;
      case 'mcg':
        return value / 1000000;
      case 'U':
        return value;
      case 'IU':
        return value / 1000;
      case 'ml':
      case 'cc':
        final conc = antibioticData?['concentrationMgPerMl'];
        if (conc is double && conc > 0) {
          return (value * conc) / 1000;
        }
        return null;
      default:
        return null;
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

      // Process releases
      final releaseSnapshot = await _releasesCollection.get();
      final Map<String, double> releaseWardUnits = {};
      for (var doc in releaseSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final wardId = data['wardId'] ?? '';
        final itemCount = (data['itemCount'] ?? 0).toDouble();
        if (itemCount == 0) continue;

        final dosageStr = data['dosage'] ?? '';
        final parseResult = _parseDosage(dosageStr);
        final dosageValue = parseResult['value'] as double;
        final unit = parseResult['unit'] as String;
        if (dosageValue == 0) continue;

        final totalValue = itemCount * dosageValue;
        final antibioticId = data['antibioticId'] ?? '';
        final antibioticData = _antibioticDataMap[antibioticId];

        final units = _convertToUnits(totalValue, unit, antibioticData);
        if (units != null) {
          releaseWardUnits[wardId] = (releaseWardUnits[wardId] ?? 0) + units;
        }
      }

      // Process returns
      final returnSnapshot = await _returnsCollection.get();
      final Map<String, double> returnWardUnits = {};
      for (var doc in returnSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final wardId = data['wardId'] ?? '';
        final itemCount = (data['itemCount'] ?? 0).toDouble();
        if (itemCount == 0) continue;

        final dosageStr = data['dosage'] ?? '';
        final parseResult = _parseDosage(dosageStr);
        final dosageValue = parseResult['value'] as double;
        final unit = parseResult['unit'] as String;
        if (dosageValue == 0) continue;

        final totalValue = itemCount * dosageValue;
        final antibioticId = data['antibioticId'] ?? '';
        final antibioticData = _antibioticDataMap[antibioticId];

        final units = _convertToUnits(totalValue, unit, antibioticData);
        if (units != null) {
          returnWardUnits[wardId] = (returnWardUnits[wardId] ?? 0) + units;
        }
      }

      // Aggregate totals and find top wards
      double totalRelease = 0;
      double totalReturn = 0;
      String topReleaseWard = '';
      double topReleaseValue = 0;
      String topReturnWard = '';
      double topReturnValue = 0;
      int releaseWards = 0;
      int returnWards = 0;

      for (var entry in wardNames.entries) {
        final rel = releaseWardUnits[entry.key] ?? 0;
        final ret = returnWardUnits[entry.key] ?? 0;
        totalRelease += rel;
        totalReturn += ret;
        if (rel > 0) releaseWards++;
        if (ret > 0) returnWards++;
        if (rel > topReleaseValue) {
          topReleaseValue = rel;
          topReleaseWard = entry.value;
        }
        if (ret > topReturnValue) {
          topReturnValue = ret;
          topReturnWard = entry.value;
        }
      }

      setState(() {
        _totalReleaseUnits = totalRelease;
        _releaseWardsCount = releaseWards;
        _topReleaseWard = topReleaseWard;
        _topReleaseValue = topReleaseValue;

        _totalReturnUnits = totalReturn;
        _returnWardsCount = returnWards;
        _topReturnWard = topReturnWard;
        _topReturnValue = topReturnValue;

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching summary data: $e');
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

  // ---------- UI Components ----------
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
                    'Logged in as: $_currentUserRole',
                    style: TextStyle(fontSize: 14, color: AppColors.headerTextDark.withOpacity(0.7)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 25),
          const Text(
            'Overall Summary Analyst',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.headerTextDark),
          ),
        ],
      ),
    );
  }

  // Card with title and short paragraph description
  Widget _buildSummaryCard({
    required String imageAsset,
    required String title,
    required String description,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF9F7FF)],
          ),
          boxShadow: [
            BoxShadow(
              color: borderColor.withOpacity(0.2),
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
                  left: BorderSide(
                    color: borderColor,
                    width: 8,
                  ),
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Image.asset(
                    imageAsset,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.analytics, size: 60, color: borderColor.withOpacity(0.5));
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkText),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Short paragraph descriptions (no stats)
    final releaseDescription =
        'Comprehensive summary of antibiotic releases across all wards, including total units, active wards, and the top-performing ward.';
    final returnDescription =
        'Detailed analysis of antibiotic returns from all wards, showing total returned units, active wards, and the ward with highest returns.';

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
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
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildSummaryCard(
                              imageAsset: 'assets/analyst/cards/overviews-summery/release-summery.png',
                              title: 'Released Overall Summary Analyst',
                              description: releaseDescription,
                              borderColor: const Color.fromARGB(255, 19, 2, 206),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ReleasedUsageSummaryScreen()),
                                );
                              },
                            ),
                            const SizedBox(height: 30),
                            _buildSummaryCard(
                              imageAsset: 'assets/analyst/cards/overviews-summery/return-summery.png',
                              title: 'Returns Overall Summary Analyst',
                              description: returnDescription,
                              borderColor: const Color.fromARGB(255, 44, 128, 232),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ReturnedUsageSummaryScreen()),
                                );
                              },
                            ),
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