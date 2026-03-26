// antibiotics_returns_analysis.dart (with corrected unit conversion)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// AppColors (reused)
class AppColors {
  static const Color primaryPurple = Color(0xFF9F7AEA);
  static const Color lightBackground = Color(0xFFF3F0FF);
  static const Color darkText = Color(0xFF333333);
  static const Color headerGradientStart = Color.fromARGB(255, 235, 151, 225);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
  static const Color headerTextDark = Color(0xFF333333);
  static const Color inputBorder = Color(0xFFE0E0E0);
}

class AntibioticsReturnsAnalysisScreen extends StatefulWidget {
  const AntibioticsReturnsAnalysisScreen({super.key});

  @override
  State<AntibioticsReturnsAnalysisScreen> createState() =>
      _AntibioticsReturnsAnalysisScreenState();
}

class _AntibioticsReturnsAnalysisScreenState
    extends State<AntibioticsReturnsAnalysisScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final CollectionReference _returnsCollection =
      FirebaseFirestore.instance.collection('returns');
  final CollectionReference _antibioticsCollection =
      FirebaseFirestore.instance.collection('antibiotics');
  final CollectionReference _wardsCollection =
      FirebaseFirestore.instance.collection('wards');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // User details for header
  String _currentUserName = 'Loading...';
  String? _profileImageUrl;

  // Filter state
  String? _selectedWardId;
  String? _selectedAntibioticId;
  DateTime? _startDate;
  DateTime? _endDate;

  // Lists for dropdowns
  List<Map<String, dynamic>> _wards = [];
  List<Map<String, dynamic>> _antibiotics = [];

  // Data maps for CONVERTIBLE usage (units)
  Map<String, double> usagePerDrug = {};        // drugName -> total units
  Map<String, double> usagePerCategory = {
    'Access': 0,
    'Watch': 0,
    'Reserve': 0,
    'Other': 0,
  };

  // Data maps for RAW (non‑convertible) usage
  Map<String, double> rawUsagePerDrug = {};      // drugName -> total raw count
  Map<String, double> rawUsagePerCategory = {
    'Access': 0,
    'Watch': 0,
    'Reserve': 0,
    'Other': 0,
  };

  // Antibiotics data cache (category, concentration, etc.)
  Map<String, Map<String, dynamic>> _antibioticDataMap = {};

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

  // Load wards, antibiotics, and antibiotic details (including concentration)
  Future<void> _loadDropdownData() async {
    try {
      final wardSnapshot = await _wardsCollection.get();
      _wards = wardSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, 'name': data['wardName'] ?? 'Unknown'};
      }).toList();

      final antibioticSnapshot = await _antibioticsCollection.get();
      _antibiotics = antibioticSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, 'name': data['name'] ?? 'Unknown'};
      }).toList();

      // Build antibiotic data map (category, concentration, etc.)
      for (var doc in antibioticSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        _antibioticDataMap[doc.id] = {
          'category': data['category'] ?? 'Other',
          'concentrationMgPerMl': data['concentrationMgPerMl'] ?? null, // optional
        };
      }
    } catch (e) {
      debugPrint('Error loading dropdown data: $e');
    }
  }

  // ----------------------------------------------------------------------
  // UNIT CONVERSION LOGIC (based on provided formulas)
  // ----------------------------------------------------------------------

  /// Parses a dosage string (e.g., "500 mg - Milligram") into a numeric value
  /// and a unit abbreviation.
  ///
  /// Returns a map: {'value': double, 'unit': String}.
  Map<String, dynamic> _parseDosage(String dosage) {
    if (dosage.isEmpty) return {'value': 0.0, 'unit': ''};

    final normalized = dosage.toLowerCase().trim();

    // Regex to capture number and unit (allow spaces, dashes, slashes)
    final regex = RegExp(r'(\d+(?:\.\d+)?)\s*([a-z/%-]+(?:\s+[a-z/%-]+)?)');
    final match = regex.firstMatch(normalized);
    if (match == null) {
      debugPrint('Warning: no number-unit pair found in "$dosage"');
      return {'value': 0.0, 'unit': ''};
    }

    final numberStr = match.group(1)!;
    double value = double.tryParse(numberStr) ?? 0;
    String rawUnit = match.group(2)!.trim();

    // Extract core unit (e.g., "mg" from "mg - Milligram")
    final lowerUnit = rawUnit.toLowerCase();

    // Patterns to identify core unit
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

    if (coreUnit.isEmpty) {
      debugPrint('Warning: unknown unit "$rawUnit" in dosage "$dosage"');
      coreUnit = rawUnit; // fallback
    }

    return {'value': value, 'unit': coreUnit};
  }

  /// Converts a quantity with a given unit to "units" according to the rules.
  /// Returns null if the unit is not convertible (raw count).
  ///
  /// Parameters:
  /// - value: numeric quantity
  /// - unit: core unit string (e.g., 'mg', 'g', 'ml', 'U', etc.)
  /// - antibioticData: map containing optional fields like 'concentrationMgPerMl'
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
        // Need concentration (mg/mL) from antibiotic data
        final conc = antibioticData?['concentrationMgPerMl'];
        if (conc is double && conc > 0) {
          // units = (value * concentration) / 1000
          return (value * conc) / 1000;
        } else {
          debugPrint('Missing concentration for mL/cc, treating as raw');
          return null;
        }
      case 'mg/kg':
        // Weight not available, treat as raw
        debugPrint('mg/kg unit requires patient weight, treating as raw');
        return null;
      case 'IV':
        // No conversion, treat as raw
        return null;
      default:
        // Unknown unit: treat as raw
        debugPrint('Unknown unit "$unit", treating as raw');
        return null;
    }
  }

  // ----------------------------------------------------------------------
  // DATA FETCHING (with corrected conversion)
  // ----------------------------------------------------------------------

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      // Clear previous data
      usagePerDrug.clear();
      usagePerCategory.forEach((key, value) => usagePerCategory[key] = 0);
      rawUsagePerDrug.clear();
      rawUsagePerCategory.forEach((key, value) => rawUsagePerCategory[key] = 0);

      // Build Firestore query with filters
      Query query = _returnsCollection;

      if (_selectedWardId != null) {
        query = query.where('wardId', isEqualTo: _selectedWardId);
      }

      if (_selectedAntibioticId != null) {
        query = query.where('antibioticId', isEqualTo: _selectedAntibioticId);
      }

      // Use returnDateTime field for date range filtering
      if (_startDate != null && _endDate != null) {
        final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        query = query
            .where('returnDateTime', isGreaterThanOrEqualTo: start)
            .where('returnDateTime', isLessThanOrEqualTo: end);
      } else if (_startDate != null) {
        final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        query = query.where('returnDateTime', isGreaterThanOrEqualTo: start);
      } else if (_endDate != null) {
        final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        query = query.where('returnDateTime', isLessThanOrEqualTo: end);
      }

      final returnSnapshot = await query.get();

      // Process each return
      for (var doc in returnSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        final itemCount = (data['itemCount'] ?? 0).toDouble();
        if (itemCount == 0) continue;

        final dosageStr = data['dosage'] ?? '';
        final parseResult = _parseDosage(dosageStr);
        final dosageValue = parseResult['value'] as double;
        final unit = parseResult['unit'] as String;

        if (dosageValue == 0) continue; // skip invalid

        final totalValue = itemCount * dosageValue; // total quantity in the given unit

        final drugName = data['antibioticName'] ?? 'Unknown';
        final antibioticId = data['antibioticId'] ?? '';
        final antibioticData = _antibioticDataMap[antibioticId];
        final category = antibioticData?['category'] ?? 'Other';

        // Attempt conversion
        final units = _convertToUnits(totalValue, unit, antibioticData);

        if (units != null) {
          // Convertible: add to unit-based totals
          usagePerDrug[drugName] = (usagePerDrug[drugName] ?? 0) + units;
          usagePerCategory[category] = (usagePerCategory[category] ?? 0) + units;
        } else {
          // Not convertible: add to raw totals (raw count)
          rawUsagePerDrug[drugName] = (rawUsagePerDrug[drugName] ?? 0) + totalValue;
          rawUsagePerCategory[category] = (rawUsagePerCategory[category] ?? 0) + totalValue;
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
                            'Filter Returns',
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
                            DropdownButtonFormField<String>(
                              value: _selectedWardId,
                              decoration: _inputDecoration(
                                label: 'Ward',
                                prefixIcon: Icons.place,
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('All Wards')),
                                ..._wards.map((w) => DropdownMenuItem(
                                      value: w['id'],
                                      child: Text(w['name']),
                                    )),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedWardId = value);
                                setModalState(() {});
                              },
                            ),
                            const SizedBox(height: 16),

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
                                        _selectedWardId = null;
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
            'Antibiotics Returns Analysis',
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
  Widget _buildLegendItem(Color color, String label, double value, double total, {bool showValue = true, String suffix = 'units'}) {
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
              '${value.toStringAsFixed(1)} $suffix',
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
    String? totalSuffix,
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
                  'Total: ${total.toStringAsFixed(1)} ${totalSuffix ?? 'units'}',
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

  // ---------- Pie Charts with tooltip ----------
  Widget _buildPieCharts() {
    final totalDrug = usagePerDrug.values.fold(0.0, (a, b) => a + b);
    final totalCategory = usagePerCategory.values.fold(0.0, (a, b) => a + b);

    // Prepare data for tooltips
    final drugEntries = usagePerDrug.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final categoryEntries = usagePerCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildChartCard(
            title: 'Returns by Antibiotic (Convertable to Units)',
            total: totalDrug,
            totalSuffix: 'units',
            chart: PieChart(
              PieChartData(
                sections: _buildPieSections(usagePerDrug, totalDrug, limit: 8),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    if (event is FlTapUpEvent && pieTouchResponse?.touchedSection != null) {
                      final touchedIndex = pieTouchResponse!.touchedSection!.touchedSectionIndex;
                      final sections = _buildPieSections(usagePerDrug, totalDrug, limit: 8);
                      if (touchedIndex < sections.length) {
                        if (touchedIndex < drugEntries.length) {
                          final entry = drugEntries[touchedIndex];
                          final percentage = (entry.value / totalDrug * 100).toStringAsFixed(1);
                          _showItemDetails(
                            entry.key,
                            'Quantity: ${entry.value.toStringAsFixed(1)} units\nPercentage: $percentage%',
                            _getColorForIndex(touchedIndex),
                          );
                        } else if (sections.length > drugEntries.length) {
                          final otherSum = drugEntries.skip(7).fold(0.0, (sum, e) => sum + e.value);
                          if (otherSum > 0) {
                            final percentage = (otherSum / totalDrug * 100).toStringAsFixed(1);
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
            legendItems: _buildPieLegend(usagePerDrug, totalDrug, limit: 8),
          ),
          _buildChartCard(
            title: 'Returns by Category (Convertable to Units)',
            total: totalCategory,
            totalSuffix: 'units (1000 mg)',
            chart: PieChart(
              PieChartData(
                sections: _buildPieSections(usagePerCategory, totalCategory, limit: 4),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    if (event is FlTapUpEvent && pieTouchResponse?.touchedSection != null) {
                      final touchedIndex = pieTouchResponse!.touchedSection!.touchedSectionIndex;
                      final sections = _buildPieSections(usagePerCategory, totalCategory, limit: 4);
                      if (touchedIndex < sections.length) {
                        if (touchedIndex < categoryEntries.length) {
                          final entry = categoryEntries[touchedIndex];
                          final percentage = (entry.value / totalCategory * 100).toStringAsFixed(1);
                          _showItemDetails(
                            entry.key,
                            'Quantity: ${entry.value.toStringAsFixed(1)} units\nPercentage: $percentage%',
                            _getColorForIndex(touchedIndex),
                          );
                        } else if (sections.length > categoryEntries.length) {
                          final otherSum = categoryEntries.skip(3).fold(0.0, (sum, e) => sum + e.value);
                          if (otherSum > 0) {
                            final percentage = (otherSum / totalCategory * 100).toStringAsFixed(1);
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
            legendItems: _buildPieLegend(usagePerCategory, totalCategory, limit: 4),
          ),

          // Raw (non‑convertible) data as a table
          _buildRawUsageTable(),
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

  List<Widget> _buildPieLegend(Map<String, double> data, double total, {int limit = 8, String suffix = 'units'}) {
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
          suffix: suffix,
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
          suffix: suffix,
        ),
      );
    }

    return items;
  }

  // ---------- Bar Charts with tooltip ----------
  Widget _buildBarCharts() {
    final totalDrug = usagePerDrug.values.fold(0.0, (a, b) => a + b);
    final totalCategory = usagePerCategory.values.fold(0.0, (a, b) => a + b);

    final drugEntries = usagePerDrug.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final categoryEntries = usagePerCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildChartCard(
            title: 'Returns by Antibiotic (Convertable to Units)',
            total: totalDrug,
            totalSuffix: 'units (1000 mg)',
            chart: SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _getMaxY(usagePerDrug),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchCallback: (FlTouchEvent event, barTouchResponse) {
                      if (event is FlTapUpEvent && barTouchResponse?.spot != null) {
                        final touchedBarGroupIndex = barTouchResponse!.spot!.touchedBarGroupIndex;
                        if (touchedBarGroupIndex < drugEntries.length) {
                          final entry = drugEntries[touchedBarGroupIndex];
                          final percentage = (entry.value / totalDrug * 100).toStringAsFixed(1);
                          _showItemDetails(
                            entry.key,
                            'Quantity: ${entry.value.toStringAsFixed(1)} units\nPercentage: $percentage%',
                            _getColorForIndex(touchedBarGroupIndex),
                          );
                        } else if (touchedBarGroupIndex == drugEntries.length && drugEntries.length > 7) {
                          final otherSum = drugEntries.skip(7).fold(0.0, (sum, e) => sum + e.value);
                          if (otherSum > 0) {
                            final percentage = (otherSum / totalDrug * 100).toStringAsFixed(1);
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
                          if (value.toInt() >= 0 && value.toInt() < drugEntries.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _shortenName(drugEntries[value.toInt()].key),
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
            title: 'Returns by Category (Convertable to Units)',
            total: totalCategory,
            totalSuffix: 'units (1000 mg)',
            chart: SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _getMaxY(usagePerCategory),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchCallback: (FlTouchEvent event, barTouchResponse) {
                      if (event is FlTapUpEvent && barTouchResponse?.spot != null) {
                        final touchedBarGroupIndex = barTouchResponse!.spot!.touchedBarGroupIndex;
                        if (touchedBarGroupIndex < categoryEntries.length) {
                          final entry = categoryEntries[touchedBarGroupIndex];
                          final percentage = (entry.value / totalCategory * 100).toStringAsFixed(1);
                          _showItemDetails(
                            entry.key,
                            'Quantity: ${entry.value.toStringAsFixed(1)} units\nPercentage: $percentage%',
                            _getColorForIndex(touchedBarGroupIndex),
                          );
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

          // Raw (non‑convertible) data as a table
          _buildRawUsageTable(),
        ],
      ),
    );
  }

  // ---------- Raw Usage Table (no charts) ----------
  Widget _buildRawUsageTable() {
    final totalRaw = rawUsagePerDrug.values.fold(0.0, (a, b) => a + b);
    if (totalRaw == 0) {
      return const Card(
        margin: EdgeInsets.only(top: 16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text('No non‑convertible returns data.'),
          ),
        ),
      );
    }

    // Sort by raw count descending
    final entries = rawUsagePerDrug.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      margin: const EdgeInsets.only(top: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Non‑convertible Returns (Raw Counts)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'These items are not expressed in mg and are shown as raw counts.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Divider(),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        color: _getColorForIndex(index),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        '${entry.value.toStringAsFixed(1)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
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

  List<Widget> _buildBarLegend(Map<String, double> data, double total, {int limit = 8, String suffix = 'units'}) {
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
          suffix: suffix,
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
          suffix: suffix,
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