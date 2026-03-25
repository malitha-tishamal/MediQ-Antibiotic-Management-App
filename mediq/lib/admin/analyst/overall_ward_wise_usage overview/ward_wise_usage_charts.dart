// ward_wise_usage_charts.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// AppColors (reused from other admin screens)
class AppColors {
  static const Color primaryPurple = Color(0xFF9F7AEA);
  static const Color lightBackground = Color(0xFFF3F0FF);
  static const Color darkText = Color(0xFF333333);
  static const Color headerGradientStart = Color.fromARGB(255, 235, 151, 225);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
  static const Color headerTextDark = Color(0xFF333333);
  static const Color inputBorder = Color(0xFFE0E0E0);
}

class WardWiseUsageChartsScreen extends StatefulWidget {
  const WardWiseUsageChartsScreen({super.key});

  @override
  State<WardWiseUsageChartsScreen> createState() =>
      _WardWiseUsageChartsScreenState();
}

class _WardWiseUsageChartsScreenState extends State<WardWiseUsageChartsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final CollectionReference _releasesCollection =
      FirebaseFirestore.instance.collection('releases');
  final CollectionReference _wardsCollection =
      FirebaseFirestore.instance.collection('wards');
  final CollectionReference _antibioticsCollection =
      FirebaseFirestore.instance.collection('antibiotics');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // User details for header
  String _currentUserName = 'Loading...';
  String? _profileImageUrl;

  // Filter state
  String? _selectedAntibioticId;
  DateTime? _startDate;
  DateTime? _endDate;

  // Lists for dropdowns
  List<Map<String, dynamic>> _antibiotics = [];

  // Data maps: wardName -> total units
  Map<String, double> usagePerWard = {};

  bool _isLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchCurrentUserDetails();
    _loadDropdownData();
    _fetchData(); // initial load with no filters
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

  // Load antibiotics for dropdowns
  Future<void> _loadDropdownData() async {
    try {
      final antibioticSnapshot = await _antibioticsCollection.get();
      _antibiotics = antibioticSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, 'name': data['name'] ?? 'Unknown'};
      }).toList();
    } catch (e) {
      debugPrint('Error loading dropdown data: $e');
    }
  }

  // Main data fetcher: reads releases with applied filters and calculates units per ward
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      // Clear previous data
      usagePerWard.clear();

      // Build Firestore query with filters
      Query query = _releasesCollection;

      if (_selectedAntibioticId != null) {
        query = query.where('antibioticId', isEqualTo: _selectedAntibioticId);
      }
      if (_startDate != null && _endDate != null) {
        final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        query = query
            .where('releaseDateTime', isGreaterThanOrEqualTo: start)
            .where('releaseDateTime', isLessThanOrEqualTo: end);
      } else if (_startDate != null) {
        final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        query = query.where('releaseDateTime', isGreaterThanOrEqualTo: start);
      } else if (_endDate != null) {
        final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        query = query.where('releaseDateTime', isLessThanOrEqualTo: end);
      }

      // Fetch filtered releases
      final releaseSnapshot = await query.get();

      // Fetch all wards to map wardId to wardName
      final wardSnapshot = await _wardsCollection.get();
      final Map<String, String> wardNames = {};
      for (var doc in wardSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        wardNames[doc.id] = data['wardName'] ?? 'Unknown';
      }

      for (var doc in releaseSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        final itemCount = (data['itemCount'] ?? 0).toDouble();
        if (itemCount == 0) continue;

        final dosageStr = data['dosage'] ?? '';
        final dosageMg = _parseDosageToMg(dosageStr);
        if (dosageMg == 0) {
          debugPrint('Warning: could not parse dosage "$dosageStr" for release ${doc.id} – skipping');
          continue;
        }

        final totalMg = itemCount * dosageMg;
        final units = totalMg / 1000;

        final wardId = data['wardId'] ?? '';
        final wardName = wardNames[wardId] ?? 'Unknown';

        usagePerWard[wardName] = (usagePerWard[wardName] ?? 0) + units;
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Parse dosage string to milligrams (supports g, mg, mcg, mL, cc)
  double _parseDosageToMg(String dosage) {
    if (dosage.isEmpty) return 0;
    final normalized = dosage.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    final RegExp regex = RegExp(r'^([0-9]*\.?[0-9]+)\s*([a-z%]+)?$');
    final match = regex.firstMatch(normalized);
    if (match == null) return 0;

    final numberStr = match.group(1) ?? '0';
    final unit = match.group(2) ?? '';
    double value = double.tryParse(numberStr) ?? 0;

    if (unit.isEmpty) {
      debugPrint('Warning: no unit in dosage "$dosage", skipping');
      return 0;
    }

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
        return value * 1000; // assuming 1 mL = 1 g = 1000 mg
      default:
        debugPrint('Warning: unknown unit "$unit" in dosage "$dosage", skipping');
        return 0;
    }
  }

  // ---------- Input Decoration Helper (for filter panel) ----------
  InputDecoration _inputDecoration({
    required String label,
    IconData? prefixIcon,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: const TextStyle(color: AppColors.primaryPurple, fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2.0),
      ),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, color: AppColors.primaryPurple, size: 20),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    );
  }

  // ---------- Filter Panel Bottom Sheet ----------
  void _showFilterPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Filter Releases',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const Divider(),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          children: [
                            // Antibiotic dropdown
                            DropdownButtonFormField<String>(
                              value: _selectedAntibioticId,
                              decoration: _inputDecoration(
                                label: 'Antibiotic',
                                prefixIcon: Icons.medication,
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('All Antibiotics')),
                                ..._antibiotics.map((a) => DropdownMenuItem(
                                      value: a['id'],
                                      child: Text(a['name']),
                                    )),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedAntibioticId = value);
                                setModalState(() {});
                              },
                            ),
                            const SizedBox(height: 16),

                            // Date range
                            const Text('Range Filter (Year: Month: Date)', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: _startDate ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now(),
                                      );
                                      if (date != null) {
                                        setState(() => _startDate = date);
                                        setModalState(() {});
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: _inputDecoration(label: 'From'),
                                      child: Text(_startDate != null
                                          ? DateFormat('yyyy-MM-dd').format(_startDate!)
                                          : 'Select'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: _endDate ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now(),
                                      );
                                      if (date != null) {
                                        setState(() => _endDate = date);
                                        setModalState(() {});
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: _inputDecoration(label: 'To'),
                                      child: Text(_endDate != null
                                          ? DateFormat('yyyy-MM-dd').format(_endDate!)
                                          : 'Select'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Action buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedAntibioticId = null;
                                        _startDate = null;
                                        _endDate = null;
                                      });
                                      setModalState(() {});
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primaryPurple,
                                      side: const BorderSide(color: AppColors.primaryPurple),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Clear All'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _fetchData(); // Apply filters and reload
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryPurple,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Apply'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ---------- Custom Header with Filter Button ----------
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
              // Filter button
              IconButton(
                icon: const Icon(Icons.tune, color: AppColors.headerTextDark),
                onPressed: _showFilterPanel,
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
            'Ward-wise Usage Analysis',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.headerTextDark),
          ),
        ],
      ),
    );
  }

  // ---------- Enhanced modern dialog ----------
  void _showItemDetails(String title, String details, Color accentColor) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 8,
        backgroundColor: Colors.white,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gradient header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentColor, accentColor.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Details
              Text(
                details,
                style: const TextStyle(fontSize: 16, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Action button
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('OK', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Chart Helper Widgets ----------
  Widget _buildLegendItem(Color color, String label, double value, double total,
      {bool showValue = true}) {
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
    final totalWard = usagePerWard.values.fold(0.0, (a, b) => a + b);
    final wardEntries = usagePerWard.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildChartCard(
            title: 'Usage by Ward',
            total: totalWard,
            chart: PieChart(
              PieChartData(
                sections: _buildPieSections(usagePerWard, totalWard, limit: 8),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    if (event is FlTapUpEvent && pieTouchResponse?.touchedSection != null) {
                      final touchedIndex = pieTouchResponse!.touchedSection!.touchedSectionIndex;
                      final sections = _buildPieSections(usagePerWard, totalWard, limit: 8);
                      if (touchedIndex < sections.length) {
                        if (touchedIndex < wardEntries.length) {
                          final entry = wardEntries[touchedIndex];
                          final percentage = (entry.value / totalWard * 100).toStringAsFixed(1);
                          _showItemDetails(
                            entry.key,
                            'Quantity: ${entry.value.toStringAsFixed(1)} units\nPercentage: $percentage%',
                            _getColorForIndex(touchedIndex),
                          );
                        } else if (sections.length > wardEntries.length) {
                          // "Others" section
                          final otherSum = wardEntries.skip(7).fold(0.0, (sum, e) => sum + e.value);
                          if (otherSum > 0) {
                            final percentage = (otherSum / totalWard * 100).toStringAsFixed(1);
                            _showItemDetails(
                              'Others',
                              'Quantity: ${otherSum.toStringAsFixed(1)} units\nPercentage: $percentage%',
                              Colors.grey,
                            );
                          }
                        }
                      }
                    }
                  },
                ),
              ),
            ),
            legendItems: _buildPieLegend(usagePerWard, totalWard, limit: 8),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(Map<String, double> data, double total,
      {int limit = 8}) {
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
    final totalWard = usagePerWard.values.fold(0.0, (a, b) => a + b);
    final wardEntries = usagePerWard.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildChartCard(
            title: 'Usage by Ward',
            total: totalWard,
            chart: SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _getMaxY(usagePerWard),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchCallback: (FlTouchEvent event, barTouchResponse) {
                      if (event is FlTapUpEvent && barTouchResponse?.spot != null) {
                        final touchedBarGroupIndex = barTouchResponse!.spot!.touchedBarGroupIndex;
                        if (touchedBarGroupIndex < wardEntries.length) {
                          final entry = wardEntries[touchedBarGroupIndex];
                          final percentage = (entry.value / totalWard * 100).toStringAsFixed(1);
                          _showItemDetails(
                            entry.key,
                            'Quantity: ${entry.value.toStringAsFixed(1)} units\nPercentage: $percentage%',
                            _getColorForIndex(touchedBarGroupIndex),
                          );
                        } else if (touchedBarGroupIndex == wardEntries.length && wardEntries.length > 7) {
                          // "Others" bar
                          final otherSum = wardEntries.skip(7).fold(0.0, (sum, e) => sum + e.value);
                          if (otherSum > 0) {
                            final percentage = (otherSum / totalWard * 100).toStringAsFixed(1);
                            _showItemDetails(
                              'Others',
                              'Quantity: ${otherSum.toStringAsFixed(1)} units\nPercentage: $percentage%',
                              Colors.grey,
                            );
                          }
                        }
                      }
                    },
                  ),
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
                          if (value.toInt() >= 0 && value.toInt() < wardEntries.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _shortenName(wardEntries[value.toInt()].key),
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
                  barGroups: _buildBarGroups(usagePerWard, totalWard, limit: 8),
                ),
              ),
            ),
            legendItems: _buildBarLegend(usagePerWard, totalWard, limit: 8),
          ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups(Map<String, double> data, double total,
      {int limit = 8}) {
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