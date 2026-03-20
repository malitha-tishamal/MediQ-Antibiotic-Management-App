// antibiotics_usage_charts_analysis.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

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

  // Data maps (values in units: 1 unit = 1000 mg)
  Map<String, double> usagePerDrug = {}; // drugName -> total units
  Map<String, double> usagePerCategory = {
    'Access': 0,
    'Watch': 0,
    'Reserve': 0,
    'Other': 0,
  };

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      // Fetch all antibiotics to map drugId to name and category
      final antibioticSnapshot = await _antibioticsCollection.get();
      Map<String, Map<String, dynamic>> antibioticMap = {};
      for (var doc in antibioticSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        antibioticMap[doc.id] = {
          'name': data['name'] ?? 'Unknown',
          'category': data['category'] ?? 'Other',
        };
      }

      // Fetch all releases
      final releaseSnapshot = await _releasesCollection.get();
      for (var doc in releaseSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final antibioticId = data['antibioticId'] ?? '';
        // Convert quantity from mg to units (1 unit = 1000 mg)
        final quantityMg = (data['quantity'] ?? 1).toDouble();
        final quantityUnits = quantityMg / 1000;

        final antibioticInfo = antibioticMap[antibioticId];
        if (antibioticInfo != null) {
          final drugName = antibioticInfo['name'];
          final category = antibioticInfo['category'];

          // Update per drug
          usagePerDrug[drugName] = (usagePerDrug[drugName] ?? 0) + quantityUnits;

          // Update per category
          if (usagePerCategory.containsKey(category)) {
            usagePerCategory[category] = (usagePerCategory[category] ?? 0) + quantityUnits;
          } else {
            usagePerCategory['Other'] = (usagePerCategory['Other'] ?? 0) + quantityUnits;
          }
        } else {
          // If antibiotic not found, treat as "Unknown" drug and "Other" category
          usagePerDrug['Unknown'] = (usagePerDrug['Unknown'] ?? 0) + quantityUnits;
          usagePerCategory['Other'] = (usagePerCategory['Other'] ?? 0) + quantityUnits;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Antibiotics Usage Analysis'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.pie_chart), text: 'Pie Charts'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Bar Charts'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPieCharts(),
                _buildBarCharts(),
              ],
            ),
    );
  }

  /// Builds a legend row for a chart item
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

  /// Builds a card with chart and legend
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

  /// Pie Charts Tab
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

  /// Build pie sections with percentage labels
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

  /// Build legend for pie charts
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

  /// Bar Charts Tab
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

  /// Build bar groups with value labels
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

  /// Build legend for bar charts (shows value and percentage)
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
    return maxEntry.value * 1.2; // leave some headroom
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
}