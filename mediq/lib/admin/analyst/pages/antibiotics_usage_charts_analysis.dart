// antibiotics_usage_charts_analysis.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';

// AppColors (match other admin screens)
class AppColors {
  static const Color primaryPurple = Color(0xFF9F7AEA);
  static const Color lightBackground = Color(0xFFF3F0FF);
  static const Color darkText = Color(0xFF333333);
  static const Color headerGradientStart = Color.fromARGB(255, 235, 151, 225);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
  static const Color headerTextDark = Color(0xFF333333);
}

class AntibioticsUsageChartsAnalysisScreen extends StatefulWidget {
  const AntibioticsUsageChartsAnalysisScreen({super.key});

  @override
  State<AntibioticsUsageChartsAnalysisScreen> createState() =>
      _AntibioticsUsageChartsAnalysisScreenState();
}

class _AntibioticsUsageChartsAnalysisScreenState
    extends State<AntibioticsUsageChartsAnalysisScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final CollectionReference _releasesCollection =
      FirebaseFirestore.instance.collection('releases');
  final CollectionReference _antibioticsCollection =
      FirebaseFirestore.instance.collection('antibiotics');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // User details for header
  String _currentUserName = 'Loading...';
  String? _profileImageUrl;

  // Data maps (values in units: 1 unit = 1000 mg)
  Map<String, double> usagePerDrug = {}; // drugName -> total units
  Map<String, double> usagePerCategory = {
    'Access': 0,
    'Watch': 0,
    'Reserve': 0,
    'Other': 0,
  };

  bool _isLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchCurrentUserDetails();
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Fetch current user's name and profile image
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
            _profileImageUrl = data['profileImageUrl'];
          });
        }
      } catch (e) {
        debugPrint('Error fetching user: $e');
      }
    }
  }

  // Main data fetcher: reads releases and calculates units
  Future<void> _fetchData() async {
    try {
      // 1. Fetch all antibiotics to map antibioticId to category
      final antibioticSnapshot = await _antibioticsCollection.get();
      Map<String, String> antibioticCategory = {};
      for (var doc in antibioticSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        antibioticCategory[doc.id] = data['category'] ?? 'Other';
      }

      // 2. Fetch all releases
      final releaseSnapshot = await _releasesCollection.get();
      for (var doc in releaseSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // itemCount (number of items released)
        final itemCount = (data['itemCount'] ?? 0).toDouble();
        if (itemCount == 0) continue; // skip if no items

        // Parse dosage string to milligrams
        final dosageStr = data['dosage'] ?? '';
        final dosageMg = _parseDosageToMg(dosageStr);
        if (dosageMg == 0) {
          debugPrint('Warning: could not parse dosage "$dosageStr" for release ${doc.id}');
          continue; // skip if dosage invalid
        }

        // Total mg = itemCount * dosageMg, then convert to units (1 unit = 1000 mg)
        final totalMg = itemCount * dosageMg;
        final units = totalMg / 1000;

        // Drug name is directly available in the release document
        final drugName = data['antibioticName'] ?? 'Unknown';

        // Category from the antibioticId
        final antibioticId = data['antibioticId'] ?? '';
        final category = antibioticCategory[antibioticId] ?? 'Other';

        // Update per‑drug map
        usagePerDrug[drugName] = (usagePerDrug[drugName] ?? 0) + units;

        // Update per‑category map
        if (usagePerCategory.containsKey(category)) {
          usagePerCategory[category] = (usagePerCategory[category] ?? 0) + units;
        } else {
          usagePerCategory['Other'] = (usagePerCategory['Other'] ?? 0) + units;
        }
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Parses a dosage string like "1 g", "500 mg", "1.5 g" to milligrams.
  /// Returns 0 if parsing fails.
  double _parseDosageToMg(String dosage) {
    if (dosage.isEmpty) return 0;
    // Normalize: remove extra spaces and convert to lowercase
    final normalized = dosage.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    // Match pattern: number (decimal allowed) followed by optional unit
    final RegExp regex = RegExp(r'^([0-9]*\.?[0-9]+)\s*(g|mg|ml|mcg|µg)?$');
    final match = regex.firstMatch(normalized);
    if (match == null) return 0;

    final numberStr = match.group(1) ?? '0';
    final unit = match.group(2) ?? 'mg'; // default to mg if no unit? We'll handle.
    double value = double.tryParse(numberStr) ?? 0;

    switch (unit) {
      case 'g':
        return value * 1000;
      case 'mg':
        return value;
      case 'mcg':
      case 'µg':
        return value / 1000; // micrograms to mg
      case 'ml':
        // For liquids, we assume 1 ml = 1000 mg (water density) – adjust if needed.
        // In this context, likely only g and mg are used.
        return value * 1000; // treat ml as grams? Actually 1 ml of water = 1 g = 1000 mg.
        // If you want to ignore, return 0.
      default:
        return 0;
    }
  }

  // ---------- Custom Header ----------
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 4, left: 20, right: 20, bottom: 8),
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
              color: Color(0x10000000), blurRadius: 15, offset: Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.arrow_back,
                    color: AppColors.headerTextDark, size: 24),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Center(
            child: Column(
              children: [
                Text(
                  _currentUserName,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.headerTextDark),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Logged in as: Administrator',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.headerTextDark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Antibiotics Usage Analysis',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.headerTextDark),
          ),
        ],
      ),
    );
  }

  // ---------- Chart Helper Widgets ----------
  Widget _buildLegendItem(Color color, String label, double value, double total, {bool showValue = true}) {
    final percentage = total > 0 ? (value / total * 100) : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(width: 16, height: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showValue) ...[
            Text(
              '${value.toStringAsFixed(1)} units',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            '(${percentage.toStringAsFixed(1)}%)',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required Widget chart,
    required List<Widget> legendItems,
    double? total,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (total != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: Text(
                  'Total: ${total.toStringAsFixed(1)} units',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ),
            SizedBox(height: 250, child: chart),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),
            ...legendItems,
          ],
        ),
      ),
    );
  }

  // ---------- Pie Charts ----------
  Widget _buildPieCharts() {
    final totalDrug = usagePerDrug.values.fold(0.0, (a, b) => a + b);
    final totalCategory = usagePerCategory.values.fold(0.0, (a, b) => a + b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildChartCard(
            title: 'Usage by Antibiotic',
            total: totalDrug,
            chart: PieChart(
              PieChartData(
                sections: _buildPieSections(usagePerDrug, totalDrug, limit: 8),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
            legendItems: _buildPieLegend(usagePerDrug, totalDrug, limit: 8),
          ),
          _buildChartCard(
            title: 'Usage by Category',
            total: totalCategory,
            chart: PieChart(
              PieChartData(
                sections: _buildPieSections(usagePerCategory, totalCategory, limit: 4),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
            legendItems: _buildPieLegend(usagePerCategory, totalCategory, limit: 4),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(Map<String, double> data, double total, {int limit = 8}) {
    if (total == 0) {
      return [
        PieChartSectionData(
          value: 1,
          title: 'No Data',
          color: Colors.grey,
          radius: 100,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        )
      ];
    }

    var entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    List<MapEntry<String, double>> mainEntries;
    double otherSum = 0;

    if (entries.length > limit) {
      mainEntries = entries.take(limit - 1).toList();
      otherSum = entries.skip(limit - 1).fold(0.0, (sum, e) => sum + e.value);
    } else {
      mainEntries = entries;
    }

    final sections = <PieChartSectionData>[];

    for (var entry in mainEntries) {
      final percentage = (entry.value / total * 100).toStringAsFixed(1);
      sections.add(
        PieChartSectionData(
          value: entry.value,
          title: '$percentage%',
          color: _getColorForIndex(sections.length),
          radius: 100,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
    }

    if (otherSum > 0) {
      final percentage = (otherSum / total * 100).toStringAsFixed(1);
      sections.add(
        PieChartSectionData(
          value: otherSum,
          title: '$percentage%',
          color: Colors.grey,
          radius: 100,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
    }

    return sections;
  }

  List<Widget> _buildPieLegend(Map<String, double> data, double total, {int limit = 8}) {
    var entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    List<MapEntry<String, double>> mainEntries;
    double otherSum = 0;

    if (entries.length > limit) {
      mainEntries = entries.take(limit - 1).toList();
      otherSum = entries.skip(limit - 1).fold(0.0, (sum, e) => sum + e.value);
    } else {
      mainEntries = entries;
    }

    final items = <Widget>[];

    for (int i = 0; i < mainEntries.length; i++) {
      items.add(
        _buildLegendItem(
          _getColorForIndex(i),
          mainEntries[i].key,
          mainEntries[i].value,
          total,
        ),
      );
    }

    if (otherSum > 0) {
      items.add(
        _buildLegendItem(
          Colors.grey,
          'Others',
          otherSum,
          total,
        ),
      );
    }

    return items;
  }

  // ---------- Bar Charts ----------
  Widget _buildBarCharts() {
    final totalDrug = usagePerDrug.values.fold(0.0, (a, b) => a + b);
    final totalCategory = usagePerCategory.values.fold(0.0, (a, b) => a + b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildChartCard(
            title: 'Usage by Antibiotic',
            total: totalDrug,
            chart: SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _getMaxY(usagePerDrug),
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(value.toInt().toString());
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final entries = usagePerDrug.entries.toList()
                            ..sort((a, b) => b.value.compareTo(a.value));
                          if (value.toInt() >= 0 && value.toInt() < entries.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _shortenName(entries[value.toInt()].key),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  barGroups: _buildBarGroups(usagePerDrug, totalDrug, limit: 8),
                ),
              ),
            ),
            legendItems: _buildBarLegend(usagePerDrug, totalDrug, limit: 8),
          ),
          _buildChartCard(
            title: 'Usage by Category',
            total: totalCategory,
            chart: SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _getMaxY(usagePerCategory),
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(value.toInt().toString());
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final categories = usagePerCategory.keys.toList();
                          if (value.toInt() >= 0 && value.toInt() < categories.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                categories[value.toInt()],
                                style: const TextStyle(fontSize: 11),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  barGroups: _buildBarGroups(usagePerCategory, totalCategory, limit: 4),
                ),
              ),
            ),
            legendItems: _buildBarLegend(usagePerCategory, totalCategory, limit: 4),
          ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups(Map<String, double> data, double total, {int limit = 8}) {
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    List<MapEntry<String, double>> mainEntries;
    double otherSum = 0;

    if (entries.length > limit) {
      mainEntries = entries.take(limit - 1).toList();
      otherSum = entries.skip(limit - 1).fold(0.0, (sum, e) => sum + e.value);
    } else {
      mainEntries = entries;
    }

    final groups = <BarChartGroupData>[];

    for (int i = 0; i < mainEntries.length; i++) {
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: mainEntries[i].value,
              color: _getColorForIndex(i),
              width: 16,
              borderRadius: BorderRadius.circular(4),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: _getMaxY(data),
                color: Colors.grey.shade200,
              ),
            ),
          ],
          showingTooltipIndicators: [0],
        ),
      );
    }

    if (otherSum > 0) {
      groups.add(
        BarChartGroupData(
          x: mainEntries.length,
          barRods: [
            BarChartRodData(
              toY: otherSum,
              color: Colors.grey,
              width: 16,
              borderRadius: BorderRadius.circular(4),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: _getMaxY(data),
                color: Colors.grey.shade200,
              ),
            ),
          ],
        ),
      );
    }

    return groups;
  }

  List<Widget> _buildBarLegend(Map<String, double> data, double total, {int limit = 8}) {
    var entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    List<MapEntry<String, double>> mainEntries;
    double otherSum = 0;

    if (entries.length > limit) {
      mainEntries = entries.take(limit - 1).toList();
      otherSum = entries.skip(limit - 1).fold(0.0, (sum, e) => sum + e.value);
    } else {
      mainEntries = entries;
    }

    final items = <Widget>[];

    for (int i = 0; i < mainEntries.length; i++) {
      items.add(
        _buildLegendItem(
          _getColorForIndex(i),
          mainEntries[i].key,
          mainEntries[i].value,
          total,
        ),
      );
    }

    if (otherSum > 0) {
      items.add(
        _buildLegendItem(
          Colors.grey,
          'Others',
          otherSum,
          total,
        ),
      );
    }

    return items;
  }

  double _getMaxY(Map<String, double> data) {
    if (data.isEmpty) return 10;
    final maxEntry = data.entries.reduce((a, b) => a.value > b.value ? a : b);
    return maxEntry.value * 1.2;
  }

  String _shortenName(String name, {int maxLength = 8}) {
    if (name.length <= maxLength) return name;
    return '${name.substring(0, maxLength)}…';
  }

  Color _getColorForIndex(int index) {
    const colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.lightBackground,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                // TabBar
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(icon: Icon(Icons.pie_chart), text: 'Pie Charts'),
                      Tab(icon: Icon(Icons.bar_chart), text: 'Bar Charts'),
                    ],
                    labelColor: AppColors.primaryPurple,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: AppColors.primaryPurple,
                  ),
                ),
                // Tab content
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildPieCharts(),
                            _buildBarCharts(),
                          ],
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