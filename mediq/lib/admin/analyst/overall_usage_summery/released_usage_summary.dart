// released_usage_ward_wise_summary.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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

class ReleasedUsageSummaryScreen extends StatefulWidget {
  const ReleasedUsageSummaryScreen({super.key});

  @override
  State<ReleasedUsageSummaryScreen> createState() =>
      _ReleasedUsageSummaryScreenState();
}

class _ReleasedUsageSummaryScreenState
    extends State<ReleasedUsageSummaryScreen> {
  final CollectionReference _releasesCollection =
      FirebaseFirestore.instance.collection('releases');
  final CollectionReference _wardsCollection =
      FirebaseFirestore.instance.collection('wards');
  final CollectionReference _antibioticsCollection =
      FirebaseFirestore.instance.collection('antibiotics');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _currentUserName = 'Loading...';
  String? _profileImageUrl;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Filter state
  String? _selectedAntibioticId;
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedCategory = 'All';          // Access/Watch/Reserve/Other
  String _selectedStockType = 'All';         // LP/MSD
  String _searchWardQuery = '';              // search by ward name
  String _searchAntibioticQuery = '';        // search by antibiotic name
  String _selectedWardCategory = 'All';      // Pediatrics, Medicine, etc.
  final TextEditingController _searchWardController = TextEditingController();
  final TextEditingController _searchAntibioticController = TextEditingController();

  // Lists for dropdowns
  List<Map<String, dynamic>> _antibiotics = [];
  Map<String, Map<String, dynamic>> _antibioticDataMap = {}; // id -> {category, concentrationMgPerMl}
  Map<String, String> _wardNames = {}; // wardId -> wardName
  Map<String, String> _wardCategories = {}; // wardId -> category (from keyword matching)

  // Data structures
  List<WardSummary> _wardSummaries = [];
  double _totalConvertibleUnits = 0;
  double _totalRawUnits = 0;
  bool _isLoading = true;

  // Ward categories for colouring and filter dropdown
  final List<Map<String, dynamic>> _wardCategoryList = [
    {'name': 'Pediatrics', 'color': Colors.pink.shade300},
    {'name': 'Medicine', 'color': Colors.blue.shade400},
    {'name': 'ICU', 'color': Colors.red.shade400},
    {'name': 'Surgery', 'color': Colors.green.shade600},
    {'name': 'Medicine Subspecialty', 'color': Colors.orange.shade300},
    {'name': 'Surgery Subspecialty', 'color': Colors.purple.shade300},
    {'name': 'Other', 'color': Colors.grey},
  ];

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserDetails();
    _loadDropdownData();
    _searchWardController.addListener(() {
      setState(() {
        _searchWardQuery = _searchWardController.text.toLowerCase();
      });
    });
    _searchAntibioticController.addListener(() {
      setState(() {
        _searchAntibioticQuery = _searchAntibioticController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchWardController.dispose();
    _searchAntibioticController.dispose();
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

      for (var doc in antibioticSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        _antibioticDataMap[doc.id] = {
          'category': data['category'] ?? 'Other',
          'concentrationMgPerMl': data['concentrationMgPerMl'] ?? null,
        };
      }

      final wardSnapshot = await _wardsCollection.get();
      for (var doc in wardSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final wardName = data['wardName'] ?? 'Unknown';
        _wardNames[doc.id] = wardName;
        _wardCategories[doc.id] = _getWardCategory(wardName);
      }

      _fetchData();
    } catch (e) {
      debugPrint('Error loading dropdown data: $e');
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

  Color _getWardColor(String category) {
    for (var cat in _wardCategoryList) {
      if (cat['name'] == category) return cat['color'] as Color;
    }
    return Colors.grey;
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
  // DATA FETCHING WITH FILTERS
  // ----------------------------------------------------------------------

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
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

      final releaseSnapshot = await query.get();

      // Filter releases based on all filters
      final filteredDocs = releaseSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final antibioticId = data['antibioticId'] ?? '';
        final category = _antibioticDataMap[antibioticId]?['category'] ?? 'Other';
        final stockType = (data['stockType'] ?? '').toUpperCase();
        final wardId = data['wardId'] ?? '';
        final wardName = _wardNames[wardId] ?? 'Unknown';
        final wardCategory = _wardCategories[wardId] ?? 'Other';
        final drugName = (data['antibioticName'] ?? '').toLowerCase();

        if (_selectedCategory != 'All' && category != _selectedCategory) return false;
        if (_selectedStockType != 'All' && stockType != _selectedStockType.toUpperCase()) return false;
        if (_selectedWardCategory != 'All' && wardCategory != _selectedWardCategory) return false;
        if (_searchWardQuery.isNotEmpty && !wardName.toLowerCase().contains(_searchWardQuery)) return false;
        if (_searchAntibioticQuery.isNotEmpty && !drugName.contains(_searchAntibioticQuery)) return false;
        return true;
      }).toList();

      // Aggregate per ward: drug -> { units, raw, category }
      Map<String, Map<String, Map<String, dynamic>>> wardDrugs = {}; // wardId -> drugName -> {units, raw, drugCategory}
      Map<String, double> wardTotalConvertible = {};
      Map<String, double> wardTotalRaw = {};

      for (var doc in filteredDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final wardId = data['wardId'] ?? '';
        if (!_wardNames.containsKey(wardId)) continue;

        final drugName = data['antibioticName'] ?? 'Unknown';
        final dosageStr = data['dosage'] ?? '';
        final itemCount = (data['itemCount'] ?? 0).toDouble();
        if (itemCount == 0) continue;

        final parseResult = _parseDosage(dosageStr);
        final dosageValue = parseResult['value'] as double;
        final unit = parseResult['unit'] as String;
        if (dosageValue == 0) continue;

        final totalValue = itemCount * dosageValue;
        final antibioticId = data['antibioticId'] ?? '';
        final antibioticData = _antibioticDataMap[antibioticId];
        final drugCategory = antibioticData?['category'] ?? 'Other';
        final units = _convertToUnits(totalValue, unit, antibioticData);

        wardDrugs.putIfAbsent(wardId, () => {});
        final drugMap = wardDrugs[wardId]!;
        drugMap.putIfAbsent(drugName, () => {'units': 0.0, 'raw': 0.0, 'category': drugCategory});

        if (units != null) {
          drugMap[drugName]!['units'] += units;
          wardTotalConvertible[wardId] = (wardTotalConvertible[wardId] ?? 0) + units;
          _totalConvertibleUnits += units;
        } else {
          drugMap[drugName]!['raw'] += totalValue;
          wardTotalRaw[wardId] = (wardTotalRaw[wardId] ?? 0) + totalValue;
          _totalRawUnits += totalValue;
        }
      }

      // Build WardSummary list
      List<WardSummary> summaries = [];
      for (var entry in wardDrugs.entries) {
        final wardId = entry.key;
        final wardName = _wardNames[wardId] ?? 'Unknown';
        final drugs = entry.value;
        final totalConvertible = wardTotalConvertible[wardId] ?? 0;
        final totalRaw = wardTotalRaw[wardId] ?? 0;

        // Create DrugUsage list with percentages
        List<DrugUsage> drugList = [];
        for (var drugEntry in drugs.entries) {
          final drugName = drugEntry.key;
          final drugData = drugEntry.value;
          final convertibleUnits = drugData['units'] as double;
          final rawCount = drugData['raw'] as double;
          final category = drugData['category'] as String;
          drugList.add(DrugUsage(
            drugName: drugName,
            convertibleUnits: convertibleUnits,
            rawCount: rawCount,
            category: category,
            percentage: totalConvertible > 0 ? (convertibleUnits / totalConvertible * 100) : 0,
          ));
        }
        // Sort drugs by convertible units descending
        drugList.sort((a, b) => b.convertibleUnits.compareTo(a.convertibleUnits));

        // Determine ward category for colour
        final wardCategory = _wardCategories[wardId] ?? 'Other';
        final wardColor = _getWardColor(wardCategory);

        summaries.add(WardSummary(
          wardName: wardName,
          drugs: drugList,
          totalConvertibleUnits: totalConvertible,
          totalRawUnits: totalRaw,
          category: wardCategory,
          color: wardColor,
        ));
      }
      // Sort wards by total convertible units descending
      summaries.sort((a, b) => b.totalConvertibleUnits.compareTo(a.totalConvertibleUnits));

      setState(() {
        _wardSummaries = summaries;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching data: $e');
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

  Color _getDrugCategoryColor(String category) {
    switch (category) {
      case 'Access':
        return AppColors.accessColor;
      case 'Watch':
        return AppColors.watchColor;
      case 'Reserve':
        return AppColors.reserveColor;
      default:
        return AppColors.otherColor;
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

  // ---------- Filter Panel ----------
  void _showFilterPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _WardFilterPanel(
          antibiotics: _antibiotics,
          antibioticDataMap: _antibioticDataMap,
          wardCategories: _wardCategoryList.map((e) => e['name'] as String).toList(),
          initialCategory: _selectedCategory,
          initialStockType: _selectedStockType,
          initialAntibioticId: _selectedAntibioticId,
          initialStartDate: _startDate,
          initialEndDate: _endDate,
          initialWardSearch: _searchWardQuery,
          initialAntibioticSearch: _searchAntibioticQuery,
          initialWardCategory: _selectedWardCategory,
          onApply: (
            String category,
            String stockType,
            String? antibioticId,
            DateTime? startDate,
            DateTime? endDate,
            String wardSearch,
            String antibioticSearch,
            String wardCategory,
          ) {
            setState(() {
              _selectedCategory = category;
              _selectedStockType = stockType;
              _selectedAntibioticId = antibioticId;
              _startDate = startDate;
              _endDate = endDate;
              _searchWardQuery = wardSearch;
              _searchWardController.text = wardSearch;
              _searchAntibioticQuery = antibioticSearch;
              _searchAntibioticController.text = antibioticSearch;
              _selectedWardCategory = wardCategory;
            });
            _fetchData();
          },
        );
      },
    );
  }

  // ---------- Header ----------
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
            'Ward‑wise Released Usage',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.headerTextDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final wardCount = _wardSummaries.length;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('Wards', wardCount.toString(), AppColors.primaryPurple),
          _buildStatItem('Convertible Total', '${_totalConvertibleUnits.toStringAsFixed(1)} units', AppColors.successGreen),
          _buildStatItem('Raw Total', '${_totalRawUnits.toStringAsFixed(1)}', AppColors.successGreen),
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

  Widget _buildDrugRow(DrugUsage drug) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        border: Border(
          left: BorderSide(
            color: _getDrugCategoryColor(drug.category),
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
                drug.drugName,
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
                '${drug.convertibleUnits.toStringAsFixed(1)} units',
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
                '${drug.percentage.toStringAsFixed(1)}%',
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

  Widget _buildRawDrugRow(DrugUsage drug) {
    if (drug.rawCount == 0) return const SizedBox.shrink();
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
                drug.drugName,
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
                drug.rawCount.toStringAsFixed(1),
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
            _buildSummaryCard(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _wardSummaries.isEmpty
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
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _wardSummaries.length,
                          itemBuilder: (context, index) {
                            final ward = _wardSummaries[index];
                            final hasRaw = ward.drugs.any((d) => d.rawCount > 0);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: ExpansionTile(
                                leading: Container(
                                  width: 6,
                                  height: 40,
                                  color: ward.color,
                                ),
                                title: Text(
                                  ward.wardName,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  'Total: ${ward.totalConvertibleUnits.toStringAsFixed(1)} units${hasRaw ? ' + ${ward.totalRawUnits.toStringAsFixed(1)} raw' : ''}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Convertible drugs
                                        if (ward.drugs.isNotEmpty) ...[
                                          const Text(
                                            'Convertible Usage (1 unit = 1000 mg)',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryPurple),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryPurple.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              children: const [
                                                Expanded(flex: 3, child: Text('Antibiotic', style: TextStyle(fontWeight: FontWeight.bold))),
                                                Expanded(flex: 2, child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
                                                Expanded(flex: 1, child: Text('Percentage', style: TextStyle(fontWeight: FontWeight.bold))),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ...ward.drugs.map((drug) => _buildDrugRow(drug)),
                                          const SizedBox(height: 16),
                                        ],
                                        // Raw drugs
                                        if (hasRaw) ...[
                                          const Text(
                                            'Raw Usage (Non‑convertible)',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              children: const [
                                                Expanded(flex: 3, child: Text('Antibiotic', style: TextStyle(fontWeight: FontWeight.bold))),
                                                Expanded(flex: 2, child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ...ward.drugs.map((drug) => _buildRawDrugRow(drug)).where((widget) => widget.key != null),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            );
                          },
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

// ---------- Data Models ----------
class DrugUsage {
  final String drugName;
  final double convertibleUnits;
  final double rawCount;
  final String category;
  final double percentage;

  DrugUsage({
    required this.drugName,
    required this.convertibleUnits,
    required this.rawCount,
    required this.category,
    required this.percentage,
  });
}

class WardSummary {
  final String wardName;
  final List<DrugUsage> drugs;
  final double totalConvertibleUnits;
  final double totalRawUnits;
  final String category;
  final Color color;

  WardSummary({
    required this.wardName,
    required this.drugs,
    required this.totalConvertibleUnits,
    required this.totalRawUnits,
    required this.category,
    required this.color,
  });
}

// ---------- Filter Panel ----------
class _WardFilterPanel extends StatefulWidget {
  final List<Map<String, dynamic>> antibiotics;
  final Map<String, Map<String, dynamic>> antibioticDataMap;
  final List<String> wardCategories;
  final String initialCategory;
  final String initialStockType;
  final String? initialAntibioticId;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final String initialWardSearch;
  final String initialAntibioticSearch;
  final String initialWardCategory;
  final Function(
    String category,
    String stockType,
    String? antibioticId,
    DateTime? startDate,
    DateTime? endDate,
    String wardSearch,
    String antibioticSearch,
    String wardCategory,
  ) onApply;

  const _WardFilterPanel({
    required this.antibiotics,
    required this.antibioticDataMap,
    required this.wardCategories,
    required this.initialCategory,
    required this.initialStockType,
    required this.initialAntibioticId,
    required this.initialStartDate,
    required this.initialEndDate,
    required this.initialWardSearch,
    required this.initialAntibioticSearch,
    required this.initialWardCategory,
    required this.onApply,
  });

  @override
  State<_WardFilterPanel> createState() => _WardFilterPanelState();
}

class _WardFilterPanelState extends State<_WardFilterPanel> {
  late String _tempCategory;
  late String _tempStockType;
  late String? _tempAntibioticId;
  late DateTime? _tempStartDate;
  late DateTime? _tempEndDate;
  late String _tempWardSearch;
  late String _tempAntibioticSearch;
  late String _tempWardCategory;
  final TextEditingController _wardSearchController = TextEditingController();
  final TextEditingController _antibioticSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tempCategory = widget.initialCategory;
    _tempStockType = widget.initialStockType;
    _tempAntibioticId = widget.initialAntibioticId;
    _tempStartDate = widget.initialStartDate;
    _tempEndDate = widget.initialEndDate;
    _tempWardSearch = widget.initialWardSearch;
    _tempAntibioticSearch = widget.initialAntibioticSearch;
    _tempWardCategory = widget.initialWardCategory;
    _wardSearchController.text = _tempWardSearch;
    _antibioticSearchController.text = _tempAntibioticSearch;
    _wardSearchController.addListener(_onWardSearchChanged);
    _antibioticSearchController.addListener(_onAntibioticSearchChanged);
  }

  void _onWardSearchChanged() {
    setState(() {
      _tempWardSearch = _wardSearchController.text.toLowerCase();
      _updateAntibioticIfNeeded();
    });
  }

  void _onAntibioticSearchChanged() {
    setState(() {
      _tempAntibioticSearch = _antibioticSearchController.text.toLowerCase();
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
    if (_tempAntibioticSearch.isNotEmpty) {
      list = list.where((a) =>
          a['name'].toLowerCase().contains(_tempAntibioticSearch)).toList();
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
      _tempWardSearch = '';
      _tempAntibioticSearch = '';
      _tempWardCategory = 'All';
      _wardSearchController.text = '';
      _antibioticSearchController.text = '';
    });
  }

  void _apply() {
    widget.onApply(
      _tempCategory,
      _tempStockType,
      _tempAntibioticId,
      _tempStartDate,
      _tempEndDate,
      _tempWardSearch,
      _tempAntibioticSearch,
      _tempWardCategory,
    );
    Navigator.pop(context);
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
                    // Search by Ward Name
                    TextField(
                      controller: _wardSearchController,
                      decoration: const InputDecoration(
                        labelText: 'Ward Name',
                        hintText: 'Search ward name',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Search by Antibiotic Name
                    TextField(
                      controller: _antibioticSearchController,
                      decoration: const InputDecoration(
                        labelText: 'Antibiotic Name',
                        hintText: 'Search antibiotic name',
                        prefixIcon: Icon(Icons.medication),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Ward Category Dropdown
                    DropdownButtonFormField<String>(
                      value: _tempWardCategory,
                      decoration: _inputDecoration(label: 'Ward Category', prefixIcon: Icons.category),
                      items: [
                        const DropdownMenuItem(value: 'All', child: Text('All Ward Categories')),
                        ...widget.wardCategories.map((cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(cat),
                            )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _tempWardCategory = value!;
                          _updateAntibioticIfNeeded();
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Antibiotic Category (Access/Watch/Reserve/Other)
                    DropdownButtonFormField<String>(
                      value: _tempCategory,
                      decoration: _inputDecoration(label: 'Antibiotic Category', prefixIcon: Icons.category),
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

                    // Antibiotic Dropdown
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

                    // Stock Type
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

                    // Date Range
                    const Text('Range Filter (Year: Month: Date)', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _tempStartDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() {
                                  _tempStartDate = date;
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: _inputDecoration(label: 'From'),
                              child: Text(_tempStartDate != null
                                  ? DateFormat('yyyy-MM-dd').format(_tempStartDate!)
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
                                initialDate: _tempEndDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() {
                                  _tempEndDate = date;
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: _inputDecoration(label: 'To'),
                              child: Text(_tempEndDate != null
                                  ? DateFormat('yyyy-MM-dd').format(_tempEndDate!)
                                  : 'Select'),
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
  }

  @override
  void dispose() {
    _wardSearchController.dispose();
    _antibioticSearchController.dispose();
    super.dispose();
  }
}