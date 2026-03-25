// return_usage_summary.dart
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

class ReturnUsageSummaryScreen extends StatefulWidget {
  const ReturnUsageSummaryScreen({super.key});

  @override
  State<ReturnUsageSummaryScreen> createState() =>
      _ReturnUsageSummaryScreenState();
}

class _ReturnUsageSummaryScreenState extends State<ReturnUsageSummaryScreen>
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

  // Antibiotic tab filters (only affect antibiotic tab)
  String? _selectedAntibioticId;
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedCategory = 'All';
  String _selectedStockType = 'All';
  String _searchQuery = '';
  String _sortOption = 'most';
  final TextEditingController _searchController = TextEditingController();

  // Category tab sort (only affects category tab)
  String _categorySortOption = 'most';

  // Lists for dropdowns
  List<Map<String, dynamic>> _antibiotics = [];
  Map<String, String> _antibioticCategory = {};

  // ----- Data for Antibiotic tab (filtered) -----
  List<Map<String, dynamic>> _antibioticSummaryData = [];       // convertible
  List<Map<String, dynamic>> _rawAntibioticSummaryData = [];   // raw
  Map<String, double> _antibioticCategoryTotals = {
    'Access': 0,
    'Watch': 0,
    'Reserve': 0,
    'Other': 0,
  };
  double _antibioticTotalQuantity = 0;
  bool _isLoadingAntibiotic = true;

  // Raw totals for the antibiotic tab (for display)
  Map<String, double> _rawCategoryTotals = {
    'Access': 0,
    'Watch': 0,
    'Reserve': 0,
    'Other': 0,
  };
  double _rawTotalQuantity = 0;

  // ----- Data for Category tab (unfiltered, all returns) -----
  Map<String, double> _categoryTotals = {
    'Access': 0,
    'Watch': 0,
    'Reserve': 0,
    'Other': 0,
  };
  double _categoryTotalQuantity = 0;

  // Raw data for Category tab
  Map<String, double> _rawCategoryTotalsGlobal = {
    'Access': 0,
    'Watch': 0,
    'Reserve': 0,
    'Other': 0,
  };
  double _rawTotalQuantityGlobal = 0;

  bool _isLoadingCategory = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
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
      _fetchAntibioticData(),
      _fetchCategoryData(),
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

      for (var doc in antibioticSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        _antibioticCategory[doc.id] = data['category'] ?? 'Other';
      }
    } catch (e) {
      debugPrint('Error loading dropdown data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load antibiotics: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ---------- Enhanced Dosage Parser ----------
  Map<String, dynamic> _parseDosageToMgWithRaw(String dosage) {
    if (dosage.isEmpty) return {'value': 0.0, 'unit': '', 'convertible': false};

    final normalized = dosage.toLowerCase().trim();

    // Regex to capture the first number and the following unit (may include spaces)
    final regex = RegExp(r'(\d+(?:\.\d+)?)\s*([a-z/%-]+(?:\s+[a-z/%-]+)?)');
    final match = regex.firstMatch(normalized);
    if (match == null) {
      debugPrint('Warning: no number-unit pair found in "$dosage"');
      return {'value': 0.0, 'unit': '', 'convertible': false};
    }

    final numberStr = match.group(1)!;
    double value = double.tryParse(numberStr) ?? 0;
    String rawUnit = match.group(2)!.trim();

    final lowerUnit = rawUnit.toLowerCase();

    // Define conversion factors to mg (only for convertible units)
    final Map<String, double> conversion = {
      'g': 1000,
      'mg': 1,
      'mcg': 0.001,
      'µg': 0.001,
      'ml': 1000,   // assuming 1 mL = 1 g = 1000 mg
      'cc': 1000,
      'l': 1000000, // 1 L = 1000 g = 1,000,000 mg
    };

    String extractCoreUnit(String unit) {
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
        r'\bl\b': 'l',
        r'\bliter\b': 'l',
      };
      for (final entry in patterns.entries) {
        if (RegExp(entry.key).hasMatch(unit)) {
          return entry.value;
        }
      }
      return unit;
    }

    final coreUnit = extractCoreUnit(lowerUnit);
    if (conversion.containsKey(coreUnit)) {
      return {
        'value': value * conversion[coreUnit]!,
        'unit': coreUnit,
        'convertible': true,
      };
    } else {
      debugPrint('Note: unit "$rawUnit" is not convertible – treating as raw count');
      return {
        'value': value, // raw numeric value
        'unit': rawUnit,
        'convertible': false,
      };
    }
  }

  // Fetches data for the Antibiotic tab – respects all filters
  Future<void> _fetchAntibioticData() async {
    setState(() {
      _isLoadingAntibiotic = true;
      _antibioticSummaryData = [];
      _rawAntibioticSummaryData = [];
      _antibioticCategoryTotals = {
        'Access': 0,
        'Watch': 0,
        'Reserve': 0,
        'Other': 0,
      };
      _rawCategoryTotals = {
        'Access': 0,
        'Watch': 0,
        'Reserve': 0,
        'Other': 0,
      };
      _antibioticTotalQuantity = 0;
      _rawTotalQuantity = 0;
    });

    try {
      Query query = _returnsCollection;

      if (_selectedAntibioticId != null) {
        query = query.where('antibioticId', isEqualTo: _selectedAntibioticId);
      }
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

      final filteredDocs = returnSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final antibioticId = data['antibioticId'] ?? '';
        final category = _antibioticCategory[antibioticId] ?? 'Other';
        final stockType = (data['stockType'] ?? '').toUpperCase();
        final drugName = (data['antibioticName'] ?? '').toLowerCase();
        final wardName = (data['wardName'] ?? '').toLowerCase();

        if (_selectedCategory != 'All' && category != _selectedCategory) return false;
        if (_selectedStockType != 'All' && stockType != _selectedStockType.toUpperCase()) return false;
        if (_searchQuery.isNotEmpty &&
            !drugName.contains(_searchQuery) &&
            !wardName.contains(_searchQuery)) return false;
        return true;
      }).toList();

      Map<String, double> convertibleCategoryTotals = {
        'Access': 0,
        'Watch': 0,
        'Reserve': 0,
        'Other': 0,
      };
      double totalConvertibleUnits = 0;
      Map<String, Map<String, dynamic>> convertibleAggregated = {};

      Map<String, double> rawCategoryTotals = {
        'Access': 0,
        'Watch': 0,
        'Reserve': 0,
        'Other': 0,
      };
      double totalRawUnits = 0;
      Map<String, Map<String, dynamic>> rawAggregated = {};

      for (var doc in filteredDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final drugName = data['antibioticName'] ?? 'Unknown';
        final dosage = data['dosage'] ?? '';
        final itemCount = (data['itemCount'] ?? 0).toDouble();
        if (itemCount == 0) continue;

        final parseResult = _parseDosageToMgWithRaw(dosage);
        final dosageValue = parseResult['value']!;
        final isConvertible = parseResult['convertible']!;

        final totalValue = itemCount * dosageValue;

        final antibioticId = data['antibioticId'] ?? '';
        final category = _antibioticCategory[antibioticId] ?? 'Other';

        if (isConvertible) {
          final units = totalValue / 1000; // mg -> units
          convertibleCategoryTotals[category] = (convertibleCategoryTotals[category] ?? 0) + units;
          totalConvertibleUnits += units;

          final key = '$drugName|$dosage';
          if (!convertibleAggregated.containsKey(key)) {
            convertibleAggregated[key] = {
              'drugName': drugName,
              'dosage': dosage,
              'quantity': 0.0,
            };
          }
          convertibleAggregated[key]!['quantity'] += units;
        } else {
          // raw count
          rawCategoryTotals[category] = (rawCategoryTotals[category] ?? 0) + totalValue;
          totalRawUnits += totalValue;

          final key = '$drugName|$dosage';
          if (!rawAggregated.containsKey(key)) {
            rawAggregated[key] = {
              'drugName': drugName,
              'dosage': dosage,
              'quantity': 0.0,
            };
          }
          rawAggregated[key]!['quantity'] += totalValue;
        }
      }

      // Build convertible list
      List<Map<String, dynamic>> convertibleList = convertibleAggregated.values.toList();
      Map<String, double> drugTotal = {};
      for (var item in convertibleList) {
        final drug = item['drugName'] as String;
        final qty = item['quantity'] as double;
        drugTotal[drug] = (drugTotal[drug] ?? 0) + qty;
      }
      for (var item in convertibleList) {
        final drug = item['drugName'] as String;
        final total = drugTotal[drug] ?? 0;
        item['percentage'] = total > 0 ? (item['quantity'] / total * 100) : 0;
      }
      _applySorting(convertibleList);

      // Build raw list – no percentages
      List<Map<String, dynamic>> rawList = rawAggregated.values.toList();
      _applySorting(rawList);

      setState(() {
        _antibioticSummaryData = convertibleList;
        _rawAntibioticSummaryData = rawList;
        _antibioticCategoryTotals = convertibleCategoryTotals;
        _rawCategoryTotals = rawCategoryTotals;
        _antibioticTotalQuantity = totalConvertibleUnits;
        _rawTotalQuantity = totalRawUnits;
        _isLoadingAntibiotic = false;
      });
    } catch (e) {
      debugPrint('Error fetching antibiotic data: $e');
      setState(() => _isLoadingAntibiotic = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load antibiotic data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Fetches data for the Category tab – ignores all filters (global view)
  Future<void> _fetchCategoryData() async {
    setState(() {
      _isLoadingCategory = true;
      _categoryTotals = {
        'Access': 0,
        'Watch': 0,
        'Reserve': 0,
        'Other': 0,
      };
      _rawCategoryTotalsGlobal = {
        'Access': 0,
        'Watch': 0,
        'Reserve': 0,
        'Other': 0,
      };
      _categoryTotalQuantity = 0;
      _rawTotalQuantityGlobal = 0;
    });

    try {
      final returnSnapshot = await _returnsCollection.get();

      Map<String, double> convertibleTotals = {
        'Access': 0,
        'Watch': 0,
        'Reserve': 0,
        'Other': 0,
      };
      Map<String, double> rawTotals = {
        'Access': 0,
        'Watch': 0,
        'Reserve': 0,
        'Other': 0,
      };
      double totalConvertibleUnits = 0;
      double totalRawUnits = 0;

      for (var doc in returnSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final antibioticId = data['antibioticId'] ?? '';
        final dosageStr = data['dosage'] ?? '';
        final itemCount = (data['itemCount'] ?? 0).toDouble();
        if (itemCount == 0) continue;

        final parseResult = _parseDosageToMgWithRaw(dosageStr);
        final dosageValue = parseResult['value']!;
        final isConvertible = parseResult['convertible']!;

        final totalValue = itemCount * dosageValue;

        final category = _antibioticCategory[antibioticId] ?? 'Other';

        if (isConvertible) {
          final units = totalValue / 1000;
          convertibleTotals[category] = (convertibleTotals[category] ?? 0) + units;
          totalConvertibleUnits += units;
        } else {
          rawTotals[category] = (rawTotals[category] ?? 0) + totalValue;
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

  void _applySorting(List<Map<String, dynamic>> data) {
    switch (_sortOption) {
      case 'most':
        data.sort((a, b) => (b['quantity'] as double).compareTo(a['quantity'] as double));
        break;
      case 'lowest':
        data.sort((a, b) => (a['quantity'] as double).compareTo(b['quantity'] as double));
        break;
      case 'name':
      default:
        data.sort((a, b) => (a['drugName'] as String).compareTo(b['drugName'] as String));
        break;
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

  // ---------- Filter Panel (only affects antibiotic data) ----------
  void _showFilterPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _FilterPanel(
          antibiotics: _antibiotics,
          antibioticCategory: _antibioticCategory,
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
              _fetchAntibioticData();
            });
          },
        );
      },
    );
  }

  // ---------- Header (no filter button) ----------
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
            'Returned Usage Summary',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.headerTextDark),
          ),
        ],
      ),
    );
  }

  // ---------- Summary Card for Antibiotic tab (filtered data) ----------
  Widget _buildAntibioticSummaryCard() {
    final totalRecords = _antibioticSummaryData.length;
    final totalRawRecords = _rawAntibioticSummaryData.length;
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
          _buildStatItem('Convertible\n Records', totalRecords.toString(), AppColors.primaryPurple),
          _buildStatItem('\n Quantity', '${_antibioticTotalQuantity.toStringAsFixed(1)} units', AppColors.successGreen),
          _buildStatItem('Raw\n Records', totalRawRecords.toString(), AppColors.primaryPurple),
          _buildStatItem('Raw \n', '${_rawTotalQuantity.toStringAsFixed(1)}', AppColors.successGreen),
        ],
      ),
    );
  }

  // ---------- Summary Card for Category tab (unfiltered data) ----------
  Widget _buildCategorySummaryCard() {
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
          _buildStatItem('Categories', '4', AppColors.primaryPurple),
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

  // ---------- Antibiotic Usage Tab (with filter button) ----------
  Widget _buildAntibioticUsageTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Antibiotic Return Summary',
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
        _buildAntibioticSummaryCard(),
        Expanded(
          child: _isLoadingAntibiotic
              ? const Center(child: CircularProgressIndicator())
              : (_antibioticSummaryData.isEmpty && _rawAntibioticSummaryData.isEmpty)
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
                        if (_antibioticSummaryData.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Convertible Returns (1unit = 1000 mg)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryPurple),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildTableHeader(),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _antibioticSummaryData.length,
                            itemBuilder: (context, index) {
                              return _buildSummaryRow(_antibioticSummaryData[index]);
                            },
                          ),
                        ],
                        // Raw data table (no percentages)
                        if (_rawAntibioticSummaryData.isNotEmpty) ...[
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
                            child: _buildRawTableHeader(),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _rawAntibioticSummaryData.length,
                            itemBuilder: (context, index) {
                              return _buildRawSummaryRow(_rawAntibioticSummaryData[index]);
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

  // ---------- Category Usage Tab (unfiltered) ----------
  Widget _buildCategoryUsageTab() {
    final List<Map<String, dynamic>> categories = [
      {'name': 'Access', 'color': AppColors.accessColor},
      {'name': 'Watch', 'color': AppColors.watchColor},
      {'name': 'Reserve', 'color': AppColors.reserveColor},
      {'name': 'Other', 'color': AppColors.otherColor},
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
                    DropdownMenuItem(value: 'most', child: Text('Most Usage')),
                    DropdownMenuItem(value: 'lowest', child: Text('Lowest Usage')),
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
                          // Convertible categories (with percentages)
                          Container(
                            padding: const EdgeInsets.all(16),
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
                                  'Convertible Returns (units = 1000 mg)',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
                          // Raw categories (without percentages)
                          if (_rawTotalQuantityGlobal > 0)
                            Container(
                              padding: const EdgeInsets.all(16),
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
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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

  // ---------- Table headers and rows ----------
  Widget _buildTableHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: const [
          Expanded(flex: 3, child: Text('Antibiotic', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Dosage', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 1, child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 1, child: Text('Percentage', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(Map<String, dynamic> item) {
    final drugName = item['drugName'] as String;
    final dosage = item['dosage'] as String;
    final quantity = item['quantity'] as double;
    final percentage = item['percentage'] as double;

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
                drugName,
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
                dosage,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
            Expanded(
              flex: 1,
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

  Widget _buildRawTableHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: const [
          Expanded(flex: 3, child: Text('Antibiotic', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Dosage', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 1, child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildRawSummaryRow(Map<String, dynamic> item) {
    final drugName = item['drugName'] as String;
    final dosage = item['dosage'] as String;
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
                drugName,
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
                dosage,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
            Expanded(
              flex: 1,
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
                  Tab(icon: Icon(Icons.medication), text: 'Antibiotic Returns'),
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
                  _buildAntibioticUsageTab(),
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

// ---------- Filter Panel (unchanged) ----------
class _FilterPanel extends StatefulWidget {
  final List<Map<String, dynamic>> antibiotics;
  final Map<String, String> antibioticCategory;
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

  const _FilterPanel({
    required this.antibiotics,
    required this.antibioticCategory,
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
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
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
        final cat = widget.antibioticCategory[a['id']] ?? 'Other';
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
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search',
                        hintText: 'Drug name or ward name',
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
                        DropdownMenuItem(value: 'name', child: Text('Antibiotic Name')),
                        DropdownMenuItem(value: 'most', child: Text('Most Usage')),
                        DropdownMenuItem(value: 'lowest', child: Text('Lowest Usage')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _tempSortOption = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

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
    _searchController.dispose();
    super.dispose();
  }
}