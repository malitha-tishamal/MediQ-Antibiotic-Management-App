// ward_wise_return_charts.dart
// With timezone (Asia/Colombo) and current month indicator
// UI improvements applied (header and footer unchanged)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter/cupertino.dart';

class AppColors {
  static const Color primaryPurple = Color(0xFF9F7AEA);
  static const Color lightBackground = Color(0xFFF3F0FF);
  static const Color darkText = Color(0xFF333333);
  static const Color headerGradientStart = Color.fromARGB(255, 235, 151, 225);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
  static const Color headerTextDark = Color(0xFF333333);
  static const Color inputBorder = Color(0xFFE0E0E0);
  static const Color successGreen = Color(0xFF48BB78);
}

class WardWiseReturnChartsScreen extends StatefulWidget {
  const WardWiseReturnChartsScreen({super.key});

  @override
  State<WardWiseReturnChartsScreen> createState() =>
      _WardWiseReturnChartsScreenState();
}

class _WardWiseReturnChartsScreenState
    extends State<WardWiseReturnChartsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final CollectionReference _returnsCollection =
      FirebaseFirestore.instance.collection('returns');
  final CollectionReference _wardsCollection =
      FirebaseFirestore.instance.collection('wards');
  final CollectionReference _antibioticsCollection =
      FirebaseFirestore.instance.collection('antibiotics');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _currentUserName = 'Loading...';
  String? _profileImageUrl;

  // Filter state
  String? _selectedAntibioticId;
  DateTime? _startDate;
  DateTime? _endDate;

  List<Map<String, dynamic>> _antibiotics = [];

  // Antibiotic data cache (category, concentration)
  Map<String, Map<String, dynamic>> _antibioticDataMap = {};

  // Convertible data (mg‑based, shown in units)
  Map<String, double> usagePerWard = {};
  Map<String, double> usagePerCategory = {
    'Pediatrics': 0,
    'Medicine': 0,
    'ICU': 0,
    'Surgery': 0,
    'Medicine Subspecialty': 0,
    'Surgery Subspecialty': 0,
    'Other': 0,
  };

  // Raw data (non‑convertible, shown as counts)
  Map<String, double> rawUsagePerWard = {};
  Map<String, double> rawUsagePerCategory = {
    'Pediatrics': 0,
    'Medicine': 0,
    'ICU': 0,
    'Surgery': 0,
    'Medicine Subspecialty': 0,
    'Surgery Subspecialty': 0,
    'Other': 0,
  };

  bool _isLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ----------------------------------------------------------------------
  // NEW: Current month returns count (Sri Lanka time)
  // ----------------------------------------------------------------------
  int _currentMonthReturnsCount = 0;

  @override
  void initState() {
    super.initState();

    // Initialize timezone database and set local to Asia/Colombo
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Colombo'));

    _tabController = TabController(length: 2, vsync: this);

    // Set default date range to current month in Sri Lanka
    final now = tz.TZDateTime.now(tz.local);
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = now;

    _fetchCurrentUserDetails();
    _loadDropdownData();
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
            _profileImageUrl = data['profileImageUrl'];
          });
        }
      } catch (e) {
        debugPrint('Error fetching user: $e');
      }
    }
  }

  Future<void> _loadDropdownData() async {
    try {
      final antibioticSnapshot = await _antibioticsCollection.get();
      _antibiotics = antibioticSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, 'name': data['name'] ?? 'Unknown'};
      }).toList();

      // Build antibiotic data map (category, concentration)
      for (var doc in antibioticSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        _antibioticDataMap[doc.id] = {
          'category': data['category'] ?? 'Other',
          'concentrationMgPerMl': data['concentrationMgPerMl'] ?? null,
        };
      }
    } catch (e) {
      debugPrint('Error loading dropdown data: $e');
    }
  }

  // Map ward name to category using keyword matching
  String _getWardCategory(String wardName) {
    final lower = wardName.toLowerCase();
    if (lower.contains('pediatric') || lower.contains('pedia')) return 'Pediatrics';
    if (lower.contains('medicine')) return 'Medicine';
    if (lower.contains('icu') || lower.contains('intensive')) return 'ICU';
    if (lower.contains('surgery')) return 'Surgery';
    if (lower.contains('med sub') || lower.contains('medicine sub')) return 'Medicine Subspecialty';
    if (lower.contains('surg sub') || lower.contains('surgery sub')) return 'Surgery Subspecialty';
    return 'Other';
  }

  // ----------------------------------------------------------------------
  // UNIT CONVERSION LOGIC
  // ----------------------------------------------------------------------

  /// Parses a dosage string (e.g., "500 mg - Milligram") into a numeric value
  /// and a unit abbreviation.
  Map<String, dynamic> _parseDosage(String dosage) {
    if (dosage.isEmpty) return {'value': 0.0, 'unit': ''};

    final normalized = dosage.toLowerCase().trim();

    final regex = RegExp(r'(\d+(?:\.\d+)?)\s*([a-z/%-]+(?:\s+[a-z/%-]+)?)');
    final match = regex.firstMatch(normalized);
    if (match == null) {
      debugPrint('Warning: no number-unit pair found in "$dosage"');
      return {'value': 0.0, 'unit': ''};
    }

    final numberStr = match.group(1)!;
    double value = double.tryParse(numberStr) ?? 0;
    String rawUnit = match.group(2)!.trim();

    // Extract core unit
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

    if (coreUnit.isEmpty) {
      debugPrint('Warning: unknown unit "$rawUnit" in dosage "$dosage"');
      coreUnit = rawUnit;
    }

    return {'value': value, 'unit': coreUnit};
  }

  /// Converts a quantity with a given unit to "units" according to the rules.
  /// Returns null if the unit is not convertible.
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
        } else {
          debugPrint('Missing concentration for mL/cc, treating as raw');
          return null;
        }
      case 'mg/kg':
      case 'IV':
      default:
        debugPrint('Unit "$unit" not convertible, treating as raw');
        return null;
    }
  }

  // ----------------------------------------------------------------------
  // DATA FETCHING (with timezone‑aware date filtering)
  // ----------------------------------------------------------------------

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      // Clear convertible data
      usagePerWard.clear();
      for (final key in usagePerCategory.keys) {
        usagePerCategory[key] = 0;
      }
      // Clear raw data
      rawUsagePerWard.clear();
      for (final key in rawUsagePerCategory.keys) {
        rawUsagePerCategory[key] = 0;
      }

      Query query = _returnsCollection;  // returns collection

      if (_selectedAntibioticId != null) {
        query = query.where('antibioticId', isEqualTo: _selectedAntibioticId);
      }

      // Date range: convert selected local dates to UTC day boundaries
      if (_startDate != null && _endDate != null) {
        final startLocal = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        final endLocal = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);

        final startUtc = tz.TZDateTime.from(startLocal, tz.local).toUtc();
        final endUtc = tz.TZDateTime.from(endLocal, tz.local).toUtc();

        query = query
            .where('returnDateTime', isGreaterThanOrEqualTo: startUtc)
            .where('returnDateTime', isLessThanOrEqualTo: endUtc);
      } else if (_startDate != null) {
        final startLocal = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        final startUtc = tz.TZDateTime.from(startLocal, tz.local).toUtc();
        query = query.where('returnDateTime', isGreaterThanOrEqualTo: startUtc);
      } else if (_endDate != null) {
        final endLocal = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        final endUtc = tz.TZDateTime.from(endLocal, tz.local).toUtc();
        query = query.where('returnDateTime', isLessThanOrEqualTo: endUtc);
      }

      final returnSnapshot = await query.get();

      final wardSnapshot = await _wardsCollection.get();
      final Map<String, String> wardNames = {};
      for (var doc in wardSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        wardNames[doc.id] = data['wardName'] ?? 'Unknown';
      }

      for (var doc in returnSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        final itemCount = (data['itemCount'] ?? 0).toDouble();
        if (itemCount == 0) continue;

        final dosageStr = data['dosage'] ?? '';
        final parseResult = _parseDosage(dosageStr);
        final dosageValue = parseResult['value'] as double;
        final unit = parseResult['unit'] as String;

        if (dosageValue == 0) continue;

        final totalValue = itemCount * dosageValue; // total quantity in the given unit

        final wardId = data['wardId'] ?? '';
        final wardName = wardNames[wardId] ?? 'Unknown';
        final category = _getWardCategory(wardName);

        // Get antibiotic data for concentration (if needed)
        final antibioticId = data['antibioticId'] ?? '';
        final antibioticData = _antibioticDataMap[antibioticId];

        // Attempt conversion
        final units = _convertToUnits(totalValue, unit, antibioticData);

        if (units != null) {
          // Convertible: add to unit-based totals
          usagePerWard[wardName] = (usagePerWard[wardName] ?? 0) + units;
          usagePerCategory[category] = (usagePerCategory[category] ?? 0) + units;
        } else {
          // Not convertible: add to raw totals (raw count)
          rawUsagePerWard[wardName] = (rawUsagePerWard[wardName] ?? 0) + totalValue;
          rawUsagePerCategory[category] = (rawUsagePerCategory[category] ?? 0) + totalValue;
        }
      }

      // After data fetch, also fetch current month count
      await _fetchCurrentMonthReturnsCount();
    } catch (e) {
      debugPrint('Error fetching data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ----------------------------------------------------------------------
  // NEW: Fetch current month returns count (Sri Lanka time)
  // ----------------------------------------------------------------------
  Future<void> _fetchCurrentMonthReturnsCount() async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final startUtc = tz.TZDateTime.from(startOfMonth, tz.local).toUtc();
      final endUtc = tz.TZDateTime.from(endOfMonth, tz.local).toUtc();

      final snapshot = await _returnsCollection
          .where('returnDateTime', isGreaterThanOrEqualTo: startUtc)
          .where('returnDateTime', isLessThanOrEqualTo: endUtc)
          .get();

      setState(() {
        _currentMonthReturnsCount = snapshot.docs.length;
      });
    } catch (e) {
      debugPrint('Error fetching current month returns count: $e');
      setState(() {
        _currentMonthReturnsCount = 0;
      });
    }
  }

  // ---------- UI Helpers ----------
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

  // ---------- Enhanced Filter Panel (with CupertinoDatePicker) ----------
  void _showFilterPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.transparent,
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
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      // Handle bar
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Filter Returns',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryPurple,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          children: [
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
                            const SizedBox(height: 20),
                            const Text(
                              'Date Range (Sri Lanka time)',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _showDatePicker(context, true, setModalState),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: AppColors.inputBorder),
                                        borderRadius: BorderRadius.circular(12),
                                        color: Colors.white,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 18, color: AppColors.primaryPurple),
                                          const SizedBox(width: 8),
                                          Text(
                                            _startDate != null
                                                ? DateFormat('yyyy-MM-dd').format(_startDate!)
                                                : 'From',
                                            style: TextStyle(
                                              color: _startDate != null ? Colors.black : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _showDatePicker(context, false, setModalState),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: AppColors.inputBorder),
                                        borderRadius: BorderRadius.circular(12),
                                        color: Colors.white,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 18, color: AppColors.primaryPurple),
                                          const SizedBox(width: 8),
                                          Text(
                                            _endDate != null
                                                ? DateFormat('yyyy-MM-dd').format(_endDate!)
                                                : 'To',
                                            style: TextStyle(
                                              color: _endDate != null ? Colors.black : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
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
                                      _fetchData();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryPurple,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Apply Filters'),
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

  // Helper to show Cupertino date picker
  void _showDatePicker(BuildContext context, bool isStart, StateSetter setModalState) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        DateTime tempDate = isStart ? (_startDate ?? tz.TZDateTime.now(tz.local)) : (_endDate ?? tz.TZDateTime.now(tz.local));
        return SizedBox(
          height: 280,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (isStart) {
                            _startDate = tempDate;
                          } else {
                            _endDate = tempDate;
                          }
                        });
                        setModalState(() {});
                        Navigator.pop(ctx);
                      },
                      child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  initialDateTime: tempDate,
                  mode: CupertinoDatePickerMode.date,
                  onDateTimeChanged: (DateTime newDate) {
                    tempDate = newDate;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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
            'Ward-wise Returns Analysis',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.headerTextDark),
          ),
        ],
      ),
    );
  }

  // ---------- Current Month Indicator (Improved) ----------
  Widget _buildCurrentMonthIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryPurple.withOpacity(0.1),
            AppColors.primaryPurple.withOpacity(0.05),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryPurple.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.calendar_today,
              color: AppColors.primaryPurple,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Returns This Month',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sri Lanka time (Asia/Colombo)',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _currentMonthReturnsCount > 0
                  ? '$_currentMonthReturnsCount'
                  : '0',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
              Text(
                details,
                style: const TextStyle(fontSize: 16, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
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

  // ---------- Chart Helpers (Improved) ----------
  Widget _buildLegendItem(Color color, String label, double value, double total,
      {bool showValue = true, String suffix = 'units'}) {
    final percentage = total > 0 ? (value / total * 100) : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
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
      elevation: 4,
      shadowColor: Colors.grey.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.white],
            stops: const [0, 1],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                ),
              ),
              if (total != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Total: ${total.toStringAsFixed(1)} ${totalSuffix ?? 'units'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(height: 260, child: chart),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: legendItems,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Pie Charts (Improved) ----------
  Widget _buildPieCharts() {
    final totalWard = usagePerWard.values.fold(0.0, (a, b) => a + b);
    final totalCategory = usagePerCategory.values.fold(0.0, (a, b) => a + b);

    final wardEntries = usagePerWard.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final categoryEntries = usagePerCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildCurrentMonthIndicator(),
          if (totalWard == 0 && totalCategory == 0)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  'No data available for the selected filters.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            )
          else ...[
            // Ward chart
            _buildChartCard(
              title: 'Returns by Ward (Convertible to Units)',
              total: totalWard,
              chart: PieChart(
                PieChartData(
                  sections: _buildPieSections(usagePerWard, totalWard),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      if (event is FlTapUpEvent && pieTouchResponse?.touchedSection != null) {
                        final touchedIndex = pieTouchResponse!.touchedSection!.touchedSectionIndex;
                        final sections = _buildPieSections(usagePerWard, totalWard);
                        if (touchedIndex < sections.length && touchedIndex < wardEntries.length) {
                          final entry = wardEntries[touchedIndex];
                          final percentage = (entry.value / totalWard * 100).toStringAsFixed(1);
                          _showItemDetails(
                            entry.key,
                            'Quantity: ${entry.value.toStringAsFixed(1)} units\nPercentage: $percentage%',
                            _getColorForIndex(touchedIndex),
                          );
                        }
                      }
                    },
                  ),
                ),
              ),
              legendItems: _buildPieLegend(usagePerWard, totalWard),
            ),
            // Category chart
            _buildChartCard(
              title: 'Returns by Category (Convertible to Units)',
              total: totalCategory,
              chart: PieChart(
                PieChartData(
                  sections: _buildPieSections(usagePerCategory, totalCategory),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      if (event is FlTapUpEvent && pieTouchResponse?.touchedSection != null) {
                        final touchedIndex = pieTouchResponse!.touchedSection!.touchedSectionIndex;
                        final sections = _buildPieSections(usagePerCategory, totalCategory);
                        if (touchedIndex < sections.length && touchedIndex < categoryEntries.length) {
                          final entry = categoryEntries[touchedIndex];
                          final percentage = (entry.value / totalCategory * 100).toStringAsFixed(1);
                          _showItemDetails(
                            entry.key,
                            'Quantity: ${entry.value.toStringAsFixed(1)} units\nPercentage: $percentage%',
                            _getCategoryColor(entry.key),
                          );
                        }
                      }
                    },
                  ),
                ),
              ),
              legendItems: _buildPieLegend(usagePerCategory, totalCategory, suffix: 'units'),
            ),
            // Raw data table
            _buildRawUsageTable(),
          ],
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(Map<String, double> data, double total) {
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

    final sections = <PieChartSectionData>[];
    for (var entry in entries) {
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
    return sections;
  }

  List<Widget> _buildPieLegend(Map<String, double> data, double total, {String suffix = 'units'}) {
    var entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final items = <Widget>[];
    for (int i = 0; i < entries.length; i++) {
      items.add(
        _buildLegendItem(
          _getColorForIndex(i),
          entries[i].key,
          entries[i].value,
          total,
          suffix: suffix,
        ),
      );
    }
    return items;
  }

  // ---------- Bar Charts (scrollable, improved) ----------
  Widget _buildBarCharts() {
    final totalWard = usagePerWard.values.fold(0.0, (a, b) => a + b);
    final totalCategory = usagePerCategory.values.fold(0.0, (a, b) => a + b);

    final wardEntries = usagePerWard.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final categoryEntries = usagePerCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    const double barWidth = 40;
    const double barSpacing = 12;
    final int wardCount = wardEntries.length;
    final int categoryCount = categoryEntries.length;
    final double wardChartWidth = wardCount * (barWidth + barSpacing) + 50;
    final double categoryChartWidth = categoryCount * (barWidth + barSpacing) + 50;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildCurrentMonthIndicator(),
          if (totalWard == 0 && totalCategory == 0)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  'No data available for the selected filters.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            )
          else ...[
            // Ward bar chart
            _buildChartCard(
              title: 'Returns by Ward (Convertible to Units)',
              total: totalWard,
              chart: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: wardChartWidth,
                  height: 300,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceBetween,
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
                            }
                          }
                        },
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) => Text(value.toInt().toString()),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 && value.toInt() < wardEntries.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Transform.rotate(
                                    angle: -0.5,
                                    child: Text(
                                      _shortenName(wardEntries[value.toInt()].key, maxLength: 12),
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                            reservedSize: 60,
                          ),
                        ),
                      ),
                      gridData: FlGridData(show: true),
                      borderData: FlBorderData(show: false),
                      barGroups: _buildBarGroups(usagePerWard, totalWard, barWidth: barWidth),
                    ),
                  ),
                ),
              ),
              legendItems: _buildBarLegend(usagePerWard, totalWard),
            ),
            // Category bar chart
            _buildChartCard(
              title: 'Returns by Category (Convertible to Units)',
              total: totalCategory,
              chart: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: categoryChartWidth,
                  height: 300,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceBetween,
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
                                _getCategoryColor(entry.key),
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
                            getTitlesWidget: (value, meta) => Text(value.toInt().toString()),
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
                                  child: Transform.rotate(
                                    angle: -90 * 3.14159 / 180,
                                    child: Text(
                                      categories[value.toInt()],
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                            reservedSize: 80,
                          ),
                        ),
                      ),
                      gridData: FlGridData(show: true),
                      borderData: FlBorderData(show: false),
                      barGroups: _buildBarGroups(usagePerCategory, totalCategory, barWidth: barWidth),
                    ),
                  ),
                ),
              ),
              legendItems: _buildBarLegend(usagePerCategory, totalCategory, suffix: 'units'),
            ),
            // Raw data table
            _buildRawUsageTable(),
          ],
        ],
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups(Map<String, double> data, double total, {required double barWidth}) {
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final groups = <BarChartGroupData>[];
    for (int i = 0; i < entries.length; i++) {
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: entries[i].value,
              color: _getColorForIndex(i),
              width: barWidth,
              borderRadius: BorderRadius.circular(6),
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
    return groups;
  }

  List<Widget> _buildBarLegend(Map<String, double> data, double total, {String suffix = 'units'}) {
    var entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final items = <Widget>[];
    for (int i = 0; i < entries.length; i++) {
      items.add(
        _buildLegendItem(
          _getColorForIndex(i),
          entries[i].key,
          entries[i].value,
          total,
          suffix: suffix,
        ),
      );
    }
    return items;
  }

  // ---------- Raw Usage Table (Improved) ----------
  Widget _buildRawUsageTable() {
    final totalRawWard = rawUsagePerWard.values.fold(0.0, (a, b) => a + b);
    if (totalRawWard == 0) {
      return const Card(
        margin: EdgeInsets.only(top: 16),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text(
              'No non‑convertible returns data.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    // Sort raw ward entries
    final wardEntries = rawUsagePerWard.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Raw category entries (only those with non-zero values)
    final categoryEntries = rawUsagePerCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))
      ..where((e) => e.value > 0).toList();

    return Card(
      margin: const EdgeInsets.only(top: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Non‑convertible Returns',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'These items are not expressed in mg and are shown as raw counts.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Divider(),
            // Raw by Ward
            const Text('By Ward', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: wardEntries.length,
              itemBuilder: (context, index) {
                final entry = wardEntries[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getColorForIndex(index),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${entry.value.toStringAsFixed(1)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            const Divider(),
            // Raw by Category
            const Text('By Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categoryEntries.length,
              itemBuilder: (context, index) {
                final entry = categoryEntries[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getCategoryColor(entry.key),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${entry.value.toStringAsFixed(1)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Raw Count:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${totalRawWard.toStringAsFixed(1)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
      Color(0xFFE57373), Color(0xFF64B5F6), Color(0xFF81C784), Color(0xFFFFB74D),
      Color(0xFFBA68C8), Color(0xFF4DD0E1), Color(0xFFF06292), Color(0xFFFFD54F),
      Color(0xFF7986CB), Color(0xFF4FC3F7), Color(0xFFAED581), Color(0xFFFF8A65),
      Color(0xFF9575CD), Color(0xFF4DB6AC), Color(0xFFE57373),
    ];
    return colors[index % colors.length];
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Pediatrics': return Colors.pink.shade300;
      case 'Medicine': return Colors.blue.shade400;
      case 'ICU': return Colors.red.shade400;
      case 'Surgery': return Colors.green.shade600;
      case 'Medicine Subspecialty': return Colors.orange.shade300;
      case 'Surgery Subspecialty': return Colors.purple.shade300;
      default: return Colors.grey;
    }
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