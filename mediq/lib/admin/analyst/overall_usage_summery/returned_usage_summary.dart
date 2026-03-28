// returned_usage_ward_wise_summary.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppColors {
  static const Color primaryPurple = Color(0xFF9F7AEA);
  static const Color lightBackground = Color(0xFFF3F0FF);
  static const Color darkText = Color(0xFF333333);
  static const Color headerGradientStart = Color.fromARGB(255, 235, 151, 225);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
  static const Color headerTextDark = Color(0xFF333333);
  static const Color successGreen = Color(0xFF48BB78);
}

class ReturnedUsageSummaryScreen extends StatefulWidget {
  const ReturnedUsageSummaryScreen({super.key});

  @override
  State<ReturnedUsageSummaryScreen> createState() =>
      _ReturnedUsageSummaryScreenState();
}

class _ReturnedUsageSummaryScreenState
    extends State<ReturnedUsageSummaryScreen> {
  final CollectionReference _returnsCollection =
      FirebaseFirestore.instance.collection('returns');
  final CollectionReference _wardsCollection =
      FirebaseFirestore.instance.collection('wards');
  final CollectionReference _antibioticsCollection =
      FirebaseFirestore.instance.collection('antibiotics');

  bool _isLoading = true;
  List<WardReturnSummary> _wardSummaries = [];

  Map<String, Map<String, dynamic>> _antibioticDataMap = {};

  @override
  void initState() {
    super.initState();
    _loadAntibiotics();
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

  Map<String, dynamic> _parseDosage(String dosage) {
    if (dosage.isEmpty) return {'value': 0.0, 'unit': ''};
    final normalized = dosage.toLowerCase().trim();
    final regex = RegExp(r'(\d+(?:\.\d+)?)\s*([a-z/%-]+(?:\s+[a-z/%-]+)?)');
    final match = regex.firstMatch(normalized);
    if (match == null) return {'value': 0.0, 'unit': ''};

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
        if (conc is double && conc > 0) return (value * conc) / 1000;
        return null;
      default:
        return null;
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      // Fetch all wards
      final wardSnapshot = await _wardsCollection.get();
      final Map<String, String> wardNames = {};
      for (var doc in wardSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        wardNames[doc.id] = data['wardName'] ?? 'Unknown';
      }

      // Fetch all returns
      final returnSnapshot = await _returnsCollection.get();

      // Aggregate per ward: drug -> total units
      Map<String, Map<String, double>> wardDrugUnits = {};

      for (var doc in returnSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final wardId = data['wardId'] ?? '';
        if (!wardNames.containsKey(wardId)) continue;

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
        final units = _convertToUnits(totalValue, unit, antibioticData);
        if (units == null) continue;

        wardDrugUnits.putIfAbsent(wardId, () => {});
        wardDrugUnits[wardId]![drugName] =
            (wardDrugUnits[wardId]![drugName] ?? 0) + units;
      }

      // Build list of WardReturnSummary objects
      List<WardReturnSummary> summaries = [];
      for (var entry in wardDrugUnits.entries) {
        final wardName = wardNames[entry.key] ?? 'Unknown';
        final drugs = entry.value.entries
            .map((e) => DrugReturnUsage(drugName: e.key, totalUnits: e.value))
            .toList()
          ..sort((a, b) => b.totalUnits.compareTo(a.totalUnits));
        summaries.add(WardReturnSummary(wardName: wardName, drugs: drugs));
      }
      summaries.sort((a, b) => b.totalWardUnits.compareTo(a.totalWardUnits));

      setState(() {
        _wardSummaries = summaries;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching return data: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Ward‑wise Returns Summary'),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _wardSummaries.isEmpty
              ? const Center(child: Text('No return data found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _wardSummaries.length,
                  itemBuilder: (context, index) {
                    final ward = _wardSummaries[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryPurple,
                          child: Text('${index + 1}'),
                        ),
                        title: Text(
                          ward.wardName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Total: ${ward.totalWardUnits.toStringAsFixed(1)} units',
                          style: const TextStyle(color: AppColors.successGreen),
                        ),
                        children: [
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: ward.drugs.map((drug) {
                                return ListTile(
                                  leading: const Icon(Icons.medication, color: AppColors.primaryPurple),
                                  title: Text(drug.drugName),
                                  trailing: Text(
                                    '${drug.totalUnits.toStringAsFixed(1)} units',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class DrugReturnUsage {
  final String drugName;
  final double totalUnits;
  DrugReturnUsage({required this.drugName, required this.totalUnits});
}

class WardReturnSummary {
  final String wardName;
  final List<DrugReturnUsage> drugs;
  double get totalWardUnits => drugs.fold(0, (sum, d) => sum + d.totalUnits);
  WardReturnSummary({required this.wardName, required this.drugs});
}