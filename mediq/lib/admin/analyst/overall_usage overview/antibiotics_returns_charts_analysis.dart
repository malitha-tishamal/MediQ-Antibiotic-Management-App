// antibiotics_returns_analysis.dart
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

// AppColors (match other admin screens)
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

  // Current month returns count (Sri Lanka time)
  int _currentMonthReturnsCount = 0;

  @override
  void initState() {
    super.initState();

    // Initialize timezone database and set local to Asia/Colombo
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Colombo'));

    _tabController = TabController(length: 2, vsync: this);

    // Default date range to current month in Sri Lanka
    final now = tz.TZDateTime.now(tz.local);
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = now;

    _fetchCurrentUserDetails();
    _loadDropdownData();
    _fetchData(); // initial load with default date range
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
          'concentrationMgPerMl': data['concentrationMgPerMl'] ?? null,
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

  double? _convertToUnits(
      double value, String unit, Map<String, dynamic>? antibioticData) {
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
        debugPrint('mg/kg unit requires patient weight, treating as raw');
        return null;
      case 'IV':
        return null;
      default:
        debugPrint('Unknown unit "$unit", treating as raw');
        return null;
    }
  }

  // ----------------------------------------------------------------------
  // DATA FETCHING (with corrected conversion and timezone‑aware filters)
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

      // Process each return
      for (var doc in returnSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        final itemCount = (data['itemCount'] ?? 0).toDouble();
        if (itemCount == 0) continue;

        final dosageStr = data['dosage'] ?? '';
        final parseResult = _parseDosage(dosageStr);
        final dosageValue = parseResult['value'] as double;
        final unit = parseResult['unit'] as String;

        if (dosageValue == 0) continue;

        final totalValue = itemCount * dosageValue;

        final drugName = data['antibioticName'] ?? 'Unknown';
        final antibioticId = data['antibioticId'] ?? '';
        final antibioticData = _antibioticDataMap[antibioticId];
        final category = antibioticData?['category'] ?? 'Other';

        final units = _convertToUnits(totalValue, unit, antibioticData);

        if (units != null) {
          usagePerDrug[drugName] = (usagePerDrug[drugName] ?? 0) + units;
          usagePerCategory[category] = (usagePerCategory[category] ?? 0) + units;
        } else {
          rawUsagePerDrug[drugName] = (rawUsagePerDrug[drugName] ?? 0) + totalValue;
          rawUsagePerCategory[category] = (rawUsagePerCategory[category] ?? 0) + totalValue;
        }
      }

      // After loading data, also fetch the current month count
      await _fetchCurrentMonthCount();
    } catch (e) {
      debugPrint('Error fetching data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Fetch current month returns count (based on Sri Lanka time)
  Future<void> _fetchCurrentMonthCount() async {
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
      debugPrint('Error fetching current month count: $e');
      setState(() {
        _currentMonthReturnsCount = 0;
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

  // ---------- Enhanced Filter Panel Bottom Sheet ----------
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
                      // Header with gradient
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
                            // Ward dropdown
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
                            const SizedBox(height: 20),
                            // Date range picker (improved with Cupertino style)
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
                        if (isStart) {
                          setState(() => _startDate = tempDate);
                        } else {
                          setState(() => _endDate = tempDate);
                        }
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

  // ---------- Custom Header with Filter Button (unchanged) ----------
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

  // ---------- Chart Helper Widgets (Improved) ----------
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

  // ----------------------------------------------------------------------
  // Current month indicator (improved)
  // ----------------------------------------------------------------------
  Widget _buildCurrentMonthIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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

  // ---------- Pie Charts (with empty state handling) ----------
  Widget _buildPieCharts() {
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
          _buildCurrentMonthIndicator(),
          if (totalDrug == 0 && totalCategory == 0)
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
            _buildChartCard(
              title: 'Returns by Antibiotic (Convertible to Units)',
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
              title: 'Returns by Category (Convertible to Units)',
              total: totalCategory,
              totalSuffix: 'units',
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
            _buildRawUsageTable(),
          ],
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(
      Map<String, double> data, double total,
      {int limit = 8}) {
    if (total == 0) {
      return [
        PieChartSectionData(
          value: 1,
          title: 'No Data',
          color: Colors.grey,
          radius: 100,
          titleStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
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
          titleStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
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
          titleStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
    }

    return sections;
  }

  List<Widget> _buildPieLegend(Map<String, double> data, double total,
      {int limit = 8, String suffix = 'units'}) {
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

  // ---------- Bar Charts with improved tooltips ----------
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
          _buildCurrentMonthIndicator(),
          if (totalDrug == 0 && totalCategory == 0)
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
            _buildChartCard(
              title: 'Returns by Antibiotic (Convertible to Units)',
              total: totalDrug,
              totalSuffix: 'units',
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
                          final touchedBarGroupIndex =
                              barTouchResponse!.spot!.touchedBarGroupIndex;
                          if (touchedBarGroupIndex < drugEntries.length) {
                            final entry = drugEntries[touchedBarGroupIndex];
                            final percentage = (entry.value / totalDrug * 100).toStringAsFixed(1);
                            _showItemDetails(
                              entry.key,
                              'Quantity: ${entry.value.toStringAsFixed(1)} units\nPercentage: $percentage%',
                              _getColorForIndex(touchedBarGroupIndex),
                            );
                          } else if (touchedBarGroupIndex == drugEntries.length &&
                              drugEntries.length > 7) {
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
              title: 'Returns by Category (Convertible to Units)',
              total: totalCategory,
              totalSuffix: 'units',
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
                          final touchedBarGroupIndex =
                              barTouchResponse!.spot!.touchedBarGroupIndex;
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
            _buildRawUsageTable(),
          ],
        ],
      ),
    );
  }

  // ---------- Raw Usage Table (Improved) ----------
  Widget _buildRawUsageTable() {
    final totalRaw = rawUsagePerDrug.values.fold(0.0, (a, b) => a + b);
    if (totalRaw == 0) {
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

    final entries = rawUsagePerDrug.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
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
                    '${totalRaw.toStringAsFixed(1)}',
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

  List<BarChartGroupData> _buildBarGroups(
      Map<String, double> data, double total,
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
              width: 20,
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

    if (otherSum > 0) {
      groups.add(
        BarChartGroupData(
          x: mainEntries.length,
          barRods: [
            BarChartRodData(
              toY: otherSum,
              color: Colors.grey,
              width: 20,
              borderRadius: BorderRadius.circular(6),
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

  List<Widget> _buildBarLegend(Map<String, double> data, double total,
      {int limit = 8, String suffix = 'units'}) {
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
      Color(0xFFE57373), // red
      Color(0xFF64B5F6), // blue
      Color(0xFF81C784), // green
      Color(0xFFFFB74D), // orange
      Color(0xFFBA68C8), // purple
      Color(0xFF4DD0E1), // teal
      Color(0xFFF06292), // pink
      Color(0xFFFFD54F), // amber
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