// returned_usage_ward_wise_summary.dart
// With timezone (Asia/Colombo) and current month indicator
// UI improvements applied (header and footer unchanged)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter/cupertino.dart';

// ---------- App Colors ----------
class AppColors {
  static const Color primaryPurple = Color(0xFF9F7AEA);
  static const Color lightBackground = Color(0xFFF3F0FF);
  static const Color darkText = Color(0xFF333333);
  static const Color headerGradientStart = Color.fromARGB(255, 235, 151, 225);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
  static const Color headerTextDark = Color(0xFF333333);
  static const Color inputBorder = Color(0xFFE0E0E0);
  static const Color successGreen = Color(0xFF48BB78);
  static const Color accessColor = Color(0xFF2E7D32);
  static const Color watchColor = Color(0xFFF57C00);
  static const Color reserveColor = Color(0xFFC62828);
  static const Color otherColor = Color(0xFF757575);
}

class ReturnedUsageWardWiseSummaryScreen extends StatefulWidget {
  const ReturnedUsageWardWiseSummaryScreen({super.key});

  @override
  State<ReturnedUsageWardWiseSummaryScreen> createState() =>
      _ReturnedUsageWardWiseSummaryScreenState();
}

class _ReturnedUsageWardWiseSummaryScreenState
    extends State<ReturnedUsageWardWiseSummaryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference _returnsCollection =
      FirebaseFirestore.instance.collection('returns');
  final CollectionReference _antibioticsCollection =
      FirebaseFirestore.instance.collection('antibiotics');
  final CollectionReference _wardsCollection =
      FirebaseFirestore.instance.collection('wards');

  String _currentUserName = 'Loading...';
  String? _profileImageUrl;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Ward tab filters (only affect ward tab)
  String? _selectedAntibioticId;
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedCategory = 'All';         // category filter (Access/Watch/...)
  String _selectedStockType = 'All';        // LP/MSD filter
  String _searchQuery = '';                 // search for ward name
  String _sortOption = 'most';              // sort by name/most/least
  final TextEditingController _searchController = TextEditingController();

  // Category tab sort (only affects category tab)
  String _categorySortOption = 'most';

  // Lists for dropdowns
  List<Map<String, dynamic>> _antibiotics = [];
  Map<String, Map<String, dynamic>> _antibioticDataMap = {}; // id -> {category, concentrationMgPerMl}
  List<Map<String, dynamic>> _wards = [];   // for filter search (ward names)

  // ----- Data for Ward tab (filtered) -----
  List<Map<String, dynamic>> _wardSummaryData = [];       // convertible (ward -> units)
  List<Map<String, dynamic>> _rawWardSummaryData = [];   // raw (ward -> raw count)
  Map<String, double> _wardCategoryTotals = {
    'Pediatrics': 0,
    'Medicine': 0,
    'ICU': 0,
    'Surgery': 0,
    'Medicine Subspecialty': 0,
    'Surgery Subspecialty': 0,
    'Other': 0,
  };
  double _wardTotalQuantity = 0;
  bool _isLoadingWard = true;

  // Raw totals for the ward tab (for display)
  Map<String, double> _rawWardCategoryTotals = {
    'Pediatrics': 0,
    'Medicine': 0,
    'ICU': 0,
    'Surgery': 0,
    'Medicine Subspecialty': 0,
    'Surgery Subspecialty': 0,
    'Other': 0,
  };
  double _rawTotalQuantity = 0;

  // ----- Data for Category tab (unfiltered, all returns) -----
  Map<String, double> _categoryTotals = {
    'Pediatrics': 0,
    'Medicine': 0,
    'ICU': 0,
    'Surgery': 0,
    'Medicine Subspecialty': 0,
    'Surgery Subspecialty': 0,
    'Other': 0,
  };
  double _categoryTotalQuantity = 0;

  // Raw data for Category tab
  Map<String, double> _rawCategoryTotalsGlobal = {
    'Pediatrics': 0,
    'Medicine': 0,
    'ICU': 0,
    'Surgery': 0,
    'Medicine Subspecialty': 0,
    'Surgery Subspecialty': 0,
    'Other': 0,
  };
  double _rawTotalQuantityGlobal = 0;

  bool _isLoadingCategory = true;

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
    _tabController.addListener(() {
      setState(() {});
    });

    // Set default date range to current month in Sri Lanka
    final now = tz.TZDateTime.now(tz.local);
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = now;

    _fetchCurrentUserDetails();
    _loadInitialData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _loadDropdownData();
    await Future.wait([
      _fetchWardData(),
      _fetchCategoryData(),
      _fetchCurrentMonthReturnsCount(),
    ]);
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

      // Build antibiotic data map with category and concentration
      for (var doc in antibioticSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        _antibioticDataMap[doc.id] = {
          'category': data['category'] ?? 'Other',
          'concentrationMgPerMl': data['concentrationMgPerMl'] ?? null,
        };
      }

      final wardSnapshot = await _wardsCollection.get();
      _wards = wardSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, 'name': data['wardName'] ?? 'Unknown'};
      }).toList();
    } catch (e) {
      debugPrint('Error loading dropdown data: $e');
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

  // Helper for category colour for the left border
  Color _getWardCategoryColor(String category) {
    switch (category) {
      case 'Pediatrics':
        return Colors.pink.shade300;
      case 'Medicine':
        return Colors.blue.shade400;
      case 'ICU':
        return Colors.red.shade400;
      case 'Surgery':
        return Colors.green.shade600;
      case 'Medicine Subspecialty':
        return Colors.orange.shade300;
      case 'Surgery Subspecialty':
        return Colors.purple.shade300;
      default:
        return Colors.grey;
    }
  }

  // ----------------------------------------------------------------------
  // UNIT CONVERSION LOGIC
  // ----------------------------------------------------------------------

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

  // Fetches data for the Ward tab – respects all filters
  Future<void> _fetchWardData() async {
    setState(() {
      _isLoadingWard = true;
      _wardSummaryData = [];
      _rawWardSummaryData = [];
      _wardCategoryTotals = {
        'Pediatrics': 0,
        'Medicine': 0,
        'ICU': 0,
        'Surgery': 0,
        'Medicine Subspecialty': 0,
        'Surgery Subspecialty': 0,
        'Other': 0,
      };
      _rawWardCategoryTotals = {
        'Pediatrics': 0,
        'Medicine': 0,
        'ICU': 0,
        'Surgery': 0,
        'Medicine Subspecialty': 0,
        'Surgery Subspecialty': 0,
        'Other': 0,
      };
      _wardTotalQuantity = 0;
      _rawTotalQuantity = 0;
    });

    try {
      Query query = _returnsCollection;

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

      // Load ward names
      final wardSnapshot = await _wardsCollection.get();
      final Map<String, String> wardNames = {};
      for (var doc in wardSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        wardNames[doc.id] = data['wardName'] ?? 'Unknown';
      }

      // Filter returns based on search, stock type, category
      final filteredDocs = returnSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final antibioticId = data['antibioticId'] ?? '';
        final category = _antibioticDataMap[antibioticId]?['category'] ?? 'Other';
        final stockType = (data['stockType'] ?? '').toUpperCase();
        final wardId = data['wardId'] ?? '';
        final wardName = wardNames[wardId] ?? 'Unknown';
        final wardLower = wardName.toLowerCase();

        if (_selectedCategory != 'All' && category != _selectedCategory) return false;
        if (_selectedStockType != 'All' && stockType != _selectedStockType.toUpperCase()) return false;
        if (_searchQuery.isNotEmpty && !wardLower.contains(_searchQuery)) return false;
        return true;
      }).toList();

      // Aggregators
      Map<String, double> convertibleWardTotals = {};
      Map<String, double> convertibleCategoryTotals = {
        'Pediatrics': 0,
        'Medicine': 0,
        'ICU': 0,
        'Surgery': 0,
        'Medicine Subspecialty': 0,
        'Surgery Subspecialty': 0,
        'Other': 0,
      };
      double totalConvertibleUnits = 0;

      // Store the category for each ward (for the left border)
      Map<String, String> wardCategoryMap = {};

      Map<String, double> rawWardTotals = {};
      Map<String, double> rawCategoryTotals = {
        'Pediatrics': 0,
        'Medicine': 0,
        'ICU': 0,
        'Surgery': 0,
        'Medicine Subspecialty': 0,
        'Surgery Subspecialty': 0,
        'Other': 0,
      };
      double totalRawUnits = 0;

      for (var doc in filteredDocs) {
        final data = doc.data() as Map<String, dynamic>;
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

        final wardId = data['wardId'] ?? '';
        final wardName = wardNames[wardId] ?? 'Unknown';
        final wardCategory = _getWardCategory(wardName);

        final units = _convertToUnits(totalValue, unit, antibioticData);

        if (units != null) {
          // Convertible
          convertibleWardTotals[wardName] = (convertibleWardTotals[wardName] ?? 0) + units;
          convertibleCategoryTotals[wardCategory] = (convertibleCategoryTotals[wardCategory] ?? 0) + units;
          totalConvertibleUnits += units;
          wardCategoryMap[wardName] = wardCategory; // store category for this ward
        } else {
          // Raw
          rawWardTotals[wardName] = (rawWardTotals[wardName] ?? 0) + totalValue;
          rawCategoryTotals[wardCategory] = (rawCategoryTotals[wardCategory] ?? 0) + totalValue;
          totalRawUnits += totalValue;
        }
      }

      // Build convertible list with category
      List<Map<String, dynamic>> convertibleList = [];
      for (final entry in convertibleWardTotals.entries) {
        convertibleList.add({
          'wardName': entry.key,
          'quantity': entry.value,
          'category': wardCategoryMap[entry.key] ?? 'Other', // store category for border
        });
      }
      // Calculate percentages for convertible list
      for (var item in convertibleList) {
        final qty = item['quantity'] as double;
        item['percentage'] = totalConvertibleUnits > 0 ? (qty / totalConvertibleUnits * 100) : 0;
      }
      _applyWardSorting(convertibleList);

      // Build raw list (no percentages)
      List<Map<String, dynamic>> rawList = [];
      for (final entry in rawWardTotals.entries) {
        rawList.add({
          'wardName': entry.key,
          'quantity': entry.value,
        });
      }
      _applyWardSorting(rawList);

      setState(() {
        _wardSummaryData = convertibleList;
        _rawWardSummaryData = rawList;
        _wardCategoryTotals = convertibleCategoryTotals;
        _rawWardCategoryTotals = rawCategoryTotals;
        _wardTotalQuantity = totalConvertibleUnits;
        _rawTotalQuantity = totalRawUnits;
        _isLoadingWard = false;
      });
    } catch (e) {
      debugPrint('Error fetching ward data: $e');
      setState(() => _isLoadingWard = false);
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

  void _applyWardSorting(List<Map<String, dynamic>> data) {
    switch (_sortOption) {
      case 'most':
        data.sort((a, b) => (b['quantity'] as double).compareTo(a['quantity'] as double));
        break;
      case 'lowest':
        data.sort((a, b) => (a['quantity'] as double).compareTo(b['quantity'] as double));
        break;
      case 'name':
      default:
        data.sort((a, b) => (a['wardName'] as String).compareTo(b['wardName'] as String));
        break;
    }
  }

  // Fetches data for the Category tab – ignores all filters (global view)
  Future<void> _fetchCategoryData() async {
    setState(() {
      _isLoadingCategory = true;
      _categoryTotals = {
        'Pediatrics': 0,
        'Medicine': 0,
        'ICU': 0,
        'Surgery': 0,
        'Medicine Subspecialty': 0,
        'Surgery Subspecialty': 0,
        'Other': 0,
      };
      _rawCategoryTotalsGlobal = {
        'Pediatrics': 0,
        'Medicine': 0,
        'ICU': 0,
        'Surgery': 0,
        'Medicine Subspecialty': 0,
        'Surgery Subspecialty': 0,
        'Other': 0,
      };
      _categoryTotalQuantity = 0;
      _rawTotalQuantityGlobal = 0;
    });

    try {
      final returnSnapshot = await _returnsCollection.get();

      // Load ward names
      final wardSnapshot = await _wardsCollection.get();
      final Map<String, String> wardNames = {};
      for (var doc in wardSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        wardNames[doc.id] = data['wardName'] ?? 'Unknown';
      }

      Map<String, double> convertibleTotals = {
        'Pediatrics': 0,
        'Medicine': 0,
        'ICU': 0,
        'Surgery': 0,
        'Medicine Subspecialty': 0,
        'Surgery Subspecialty': 0,
        'Other': 0,
      };
      Map<String, double> rawTotals = {
        'Pediatrics': 0,
        'Medicine': 0,
        'ICU': 0,
        'Surgery': 0,
        'Medicine Subspecialty': 0,
        'Surgery Subspecialty': 0,
        'Other': 0,
      };
      double totalConvertibleUnits = 0;
      double totalRawUnits = 0;

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

        final antibioticId = data['antibioticId'] ?? '';
        final antibioticData = _antibioticDataMap[antibioticId];

        final wardId = data['wardId'] ?? '';
        final wardName = wardNames[wardId] ?? 'Unknown';
        final wardCategory = _getWardCategory(wardName);

        final units = _convertToUnits(totalValue, unit, antibioticData);

        if (units != null) {
          convertibleTotals[wardCategory] = (convertibleTotals[wardCategory] ?? 0) + units;
          totalConvertibleUnits += units;
        } else {
          rawTotals[wardCategory] = (rawTotals[wardCategory] ?? 0) + totalValue;
          totalRawUnits += totalValue;
        }
      }

      setState(() {
        _categoryTotals = convertibleTotals;
        _rawCategoryTotalsGlobal = rawTotals;
        _categoryTotalQuantity = totalConvertibleUnits;
        _rawTotalQuantityGlobal = totalRawUnits;
        _isLoadingCategory = false;
      });
    } catch (e) {
      debugPrint('Error fetching category data: $e');
      setState(() => _isLoadingCategory = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load category data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  // ---------- Enhanced Filter Panel ----------
  void _showFilterPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _ReturnWardFilterPanel(
          antibiotics: _antibiotics,
          antibioticDataMap: _antibioticDataMap,
          initialCategory: _selectedCategory,
          initialStockType: _selectedStockType,
          initialAntibioticId: _selectedAntibioticId,
          initialStartDate: _startDate,
          initialEndDate: _endDate,
          initialSearch: _searchQuery,
          initialSortOption: _sortOption,
          onApply: (
            String category,
            String stockType,
            String? antibioticId,
            DateTime? startDate,
            DateTime? endDate,
            String search,
            String sortOption,
          ) {
            setState(() {
              _selectedCategory = category;
              _selectedStockType = stockType;
              _selectedAntibioticId = antibioticId;
              _startDate = startDate;
              _endDate = endDate;
              _searchQuery = search;
              _searchController.text = search;
              _sortOption = sortOption;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fetchWardData();
            });
          },
        );
      },
    );
  }

  // ---------- Header (unchanged) ----------
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
              const SizedBox(width: 48),
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
            'Returned Usage - Ward Wise Summary',
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

  // ---------- Summary Cards (Improved) ----------
  Widget _buildWardSummaryCard() {
    final totalRecords = _wardSummaryData.length;
    final totalRawRecords = _rawWardSummaryData.length;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, const Color(0xFFF0F4FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('Convertible\nRecords', totalRecords.toString(), AppColors.primaryPurple),
          _buildStatItem('Convertible\nQuantity', '${_wardTotalQuantity.toStringAsFixed(1)} units', AppColors.successGreen),
          _buildStatItem('Raw\nRecords', totalRawRecords.toString(), AppColors.primaryPurple),
          _buildStatItem('Raw\nQuantity', '${_rawTotalQuantity.toStringAsFixed(1)}', AppColors.successGreen),
        ],
      ),
    );
  }

  Widget _buildCategorySummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, const Color(0xFFF0F4FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('Categories', '7', AppColors.primaryPurple),
          _buildStatItem('Convertible Total', '${_categoryTotalQuantity.toStringAsFixed(1)} units', AppColors.successGreen),
          _buildStatItem('Raw Total', '${_rawTotalQuantityGlobal.toStringAsFixed(1)}', AppColors.successGreen),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  // ---------- Ward Usage Tab (Improved) ----------
  Widget _buildWardUsageTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ward Returns',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText),
              ),
              IconButton(
                icon: const Icon(Icons.tune, color: AppColors.primaryPurple),
                onPressed: _showFilterPanel,
                tooltip: 'Filter',
              ),
            ],
          ),
        ),
        _buildCurrentMonthIndicator(),
        _buildWardSummaryCard(),
        Expanded(
          child: _isLoadingWard
              ? const Center(child: CircularProgressIndicator())
              : (_wardSummaryData.isEmpty && _rawWardSummaryData.isEmpty)
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No data found', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView(
                      children: [
                        // Convertible data table
                        if (_wardSummaryData.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Convertible Returns (1 unit = 1000 mg)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryPurple),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildWardTableHeader(),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _wardSummaryData.length,
                            itemBuilder: (context, index) {
                              return _buildWardRow(_wardSummaryData[index]);
                            },
                          ),
                        ],
                        // Raw data table
                        if (_rawWardSummaryData.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Raw Returns (Non‑convertible)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildRawWardTableHeader(),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _rawWardSummaryData.length,
                            itemBuilder: (context, index) {
                              return _buildRawWardRow(_rawWardSummaryData[index]);
                            },
                          ),
                        ],
                        const SizedBox(height: 20),
                      ],
                    ),
        ),
      ],
    );
  }

  // ---------- Category Usage Tab (Improved) ----------
  Widget _buildCategoryUsageTab() {
    final List<Map<String, dynamic>> categories = [
      {'name': 'Pediatrics', 'color': Colors.pink.shade300},
      {'name': 'Medicine', 'color': Colors.blue.shade400},
      {'name': 'ICU', 'color': Colors.red.shade400},
      {'name': 'Surgery', 'color': Colors.green.shade600},
      {'name': 'Medicine Subspecialty', 'color': Colors.orange.shade300},
      {'name': 'Surgery Subspecialty', 'color': Colors.purple.shade300},
      {'name': 'Other', 'color': Colors.grey},
    ];

    List<Map<String, dynamic>> sortedCategories = List.from(categories);
    if (_categorySortOption == 'most') {
      sortedCategories.sort((a, b) =>
          (_categoryTotals[b['name']] ?? 0).compareTo(_categoryTotals[a['name']] ?? 0));
    } else {
      sortedCategories.sort((a, b) =>
          (_categoryTotals[a['name']] ?? 0).compareTo(_categoryTotals[b['name']] ?? 0));
    }

    return Column(
      children: [
        _buildCurrentMonthIndicator(),
        _buildCategorySummaryCard(),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.sort, color: AppColors.primaryPurple, size: 20),
              const SizedBox(width: 8),
              const Text('Sort by:', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: _categorySortOption,
                  isExpanded: true,
                  underline: Container(),
                  items: const [
                    DropdownMenuItem(value: 'most', child: Text('Most Returns')),
                    DropdownMenuItem(value: 'lowest', child: Text('Lowest Returns')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _categorySortOption = value!;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingCategory
              ? const Center(child: CircularProgressIndicator())
              : (_categoryTotals.values.fold(0.0, (sum, v) => sum + v) == 0 &&
                    _rawCategoryTotalsGlobal.values.fold(0.0, (sum, v) => sum + v) == 0)
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.pie_chart, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No category data found', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Convertible categories
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.white, Color(0xFFF0F4FF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryPurple.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Convertible Returns (1 unit = 1000 mg)',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryPurple.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: const [
                                      Expanded(flex: 2, child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                                      Expanded(flex: 2, child: Text('Quantity (units)', style: TextStyle(fontWeight: FontWeight.bold))),
                                      Expanded(flex: 1, child: Text('Percentage', style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Column(
                                  children: sortedCategories.map((cat) {
                                    final name = cat['name'] as String;
                                    final color = cat['color'] as Color;
                                    final quantity = _categoryTotals[name] ?? 0;
                                    final percentage = _categoryTotalQuantity > 0 ? (quantity / _categoryTotalQuantity * 100) : 0;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.02),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 12,
                                                  height: 12,
                                                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color)),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              quantity.toStringAsFixed(1),
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              '${percentage.toStringAsFixed(1)}%',
                                              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Raw categories
                          if (_rawTotalQuantityGlobal > 0)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.white, Color(0xFFF0F4FF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryPurple.withOpacity(0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Raw Returns (Non‑convertible)',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: const [
                                        Expanded(flex: 2, child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                                        Expanded(flex: 1, child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Column(
                                    children: sortedCategories.map((cat) {
                                      final name = cat['name'] as String;
                                      final quantity = _rawCategoryTotalsGlobal[name] ?? 0;
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.02),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                quantity.toStringAsFixed(1),
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  // ---------- Table Widgets for Ward Tab (Improved) ----------
  Widget _buildWardTableHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: const [
          Expanded(flex: 3, child: Text('Ward', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 1, child: Text('Percentage', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildWardRow(Map<String, dynamic> item) {
    final wardName = item['wardName'] as String;
    final quantity = item['quantity'] as double;
    final percentage = item['percentage'] as double;
    final category = item['category'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        border: Border(
          left: BorderSide(
            color: _getWardCategoryColor(category),
            width: 6,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                wardName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.darkText,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${quantity.toStringAsFixed(1)} units',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryPurple,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRawWardTableHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: const [
          Expanded(flex: 3, child: Text('Ward', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildRawWardRow(Map<String, dynamic> item) {
    final wardName = item['wardName'] as String;
    final quantity = item['quantity'] as double;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                wardName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.darkText,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                quantity.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.place), text: 'Ward Returns'),
                  Tab(icon: Icon(Icons.category), text: 'Category Returns'),
                ],
                labelColor: AppColors.primaryPurple,
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppColors.primaryPurple,
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildWardUsageTab(),
                  _buildCategoryUsageTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.all(8.0),
        child: const Text(
          'Developed By Malitha Tishamal',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ),
    );
  }
}

// ---------- Enhanced Filter Panel (with CupertinoDatePicker) ----------
class _ReturnWardFilterPanel extends StatefulWidget {
  final List<Map<String, dynamic>> antibiotics;
  final Map<String, Map<String, dynamic>> antibioticDataMap;
  final String initialCategory;
  final String initialStockType;
  final String? initialAntibioticId;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final String initialSearch;
  final String initialSortOption;
  final Function(
    String category,
    String stockType,
    String? antibioticId,
    DateTime? startDate,
    DateTime? endDate,
    String search,
    String sortOption,
  ) onApply;

  const _ReturnWardFilterPanel({
    required this.antibiotics,
    required this.antibioticDataMap,
    required this.initialCategory,
    required this.initialStockType,
    required this.initialAntibioticId,
    required this.initialStartDate,
    required this.initialEndDate,
    required this.initialSearch,
    required this.initialSortOption,
    required this.onApply,
  });

  @override
  State<_ReturnWardFilterPanel> createState() => _ReturnWardFilterPanelState();
}

class _ReturnWardFilterPanelState extends State<_ReturnWardFilterPanel> {
  late String _tempCategory;
  late String _tempStockType;
  late String? _tempAntibioticId;
  late DateTime? _tempStartDate;
  late DateTime? _tempEndDate;
  late String _tempSearch;
  late String _tempSortOption;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tempCategory = widget.initialCategory;
    _tempStockType = widget.initialStockType;
    _tempAntibioticId = widget.initialAntibioticId;
    _tempStartDate = widget.initialStartDate;
    _tempEndDate = widget.initialEndDate;
    _tempSearch = widget.initialSearch;
    _tempSortOption = widget.initialSortOption;
    _searchController.text = _tempSearch;
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _tempSearch = _searchController.text.toLowerCase();
      _updateAntibioticIfNeeded();
    });
  }

  void _updateAntibioticIfNeeded() {
    final filtered = _getFilteredAntibiotics();
    if (_tempAntibioticId != null && !filtered.any((a) => a['id'] == _tempAntibioticId)) {
      _tempAntibioticId = null;
    }
  }

  List<Map<String, dynamic>> _getFilteredAntibiotics() {
    var list = widget.antibiotics;
    if (_tempCategory != 'All') {
      list = list.where((a) {
        final cat = widget.antibioticDataMap[a['id']]?['category'] ?? 'Other';
        return cat == _tempCategory;
      }).toList();
    }
    if (_tempSearch.isNotEmpty) {
      list = list.where((a) =>
          a['name'].toLowerCase().contains(_tempSearch)).toList();
    }
    return list;
  }

  void _clearAll() {
    setState(() {
      _tempCategory = 'All';
      _tempStockType = 'All';
      _tempAntibioticId = null;
      _tempStartDate = null;
      _tempEndDate = null;
      _tempSearch = '';
      _tempSortOption = 'most';
      _searchController.text = '';
    });
  }

  void _apply() {
    widget.onApply(
      _tempCategory,
      _tempStockType,
      _tempAntibioticId,
      _tempStartDate,
      _tempEndDate,
      _tempSearch,
      _tempSortOption,
    );
    Navigator.pop(context);
  }

  void _showDatePicker(BuildContext context, bool isStart) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        DateTime tempDate = isStart ? (_tempStartDate ?? tz.TZDateTime.now(tz.local)) : (_tempEndDate ?? tz.TZDateTime.now(tz.local));
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
                            _tempStartDate = tempDate;
                          } else {
                            _tempEndDate = tempDate;
                          }
                        });
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

  @override
  Widget build(BuildContext context) {
    final filteredAntibiotics = _getFilteredAntibiotics();

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
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search',
                        hintText: 'Ward name',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _tempCategory,
                      decoration: _inputDecoration(label: 'Category', prefixIcon: Icons.category),
                      items: ['All', 'Access', 'Watch', 'Reserve', 'Other']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _tempCategory = value!;
                          _updateAntibioticIfNeeded();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      value: _tempAntibioticId,
                      decoration: _inputDecoration(label: 'Antibiotic', prefixIcon: Icons.medication),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Antibiotics')),
                        ...filteredAntibiotics.map((a) => DropdownMenuItem(
                              value: a['id'],
                              child: Text(a['name']),
                            )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _tempAntibioticId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _tempStockType,
                      decoration: _inputDecoration(label: 'Stock Type', prefixIcon: Icons.inventory),
                      items: ['All', 'LP', 'MSD']
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _tempStockType = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _tempSortOption,
                      decoration: _inputDecoration(label: 'Order by', prefixIcon: Icons.sort),
                      items: const [
                        DropdownMenuItem(value: 'name', child: Text('Ward Name')),
                        DropdownMenuItem(value: 'most', child: Text('Most Returns')),
                        DropdownMenuItem(value: 'lowest', child: Text('Lowest Returns')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _tempSortOption = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Date Range (Sri Lanka time)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showDatePicker(context, true),
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
                                    _tempStartDate != null
                                        ? DateFormat('yyyy-MM-dd').format(_tempStartDate!)
                                        : 'From',
                                    style: TextStyle(
                                      color: _tempStartDate != null ? Colors.black : Colors.grey,
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
                            onTap: () => _showDatePicker(context, false),
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
                                    _tempEndDate != null
                                        ? DateFormat('yyyy-MM-dd').format(_tempEndDate!)
                                        : 'To',
                                    style: TextStyle(
                                      color: _tempEndDate != null ? Colors.black : Colors.grey,
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
                            onPressed: _clearAll,
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
                            onPressed: _apply,
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
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}