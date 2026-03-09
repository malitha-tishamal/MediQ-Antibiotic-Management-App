// return_store_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AppColors {
  static const Color primaryPurple = Color(0xFF9F7AEA);
  static const Color lightBackground = Color(0xFFF8F9FF);
  static const Color darkText = Color(0xFF2D3748);
  static const Color successGreen = Color(0xFF48BB78);
  static const Color warningOrange = Color(0xFFED8936);
  static const Color disabledColor = Color(0xFFF56565);
  static const Color headerGradientStart = Color.fromARGB(255, 235, 151, 225);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
  static const Color headerTextDark = Color(0xFF2D3748);
  static const Color chipBackground = Color(0xFFEDF2F7);
}

class ReturnStoreScreen extends StatefulWidget {
  const ReturnStoreScreen({super.key});

  @override
  State<ReturnStoreScreen> createState() => _ReturnStoreScreenState();
}

class _ReturnStoreScreenState extends State<ReturnStoreScreen> {
  final CollectionReference _antibioticsCollection =
      FirebaseFirestore.instance.collection('antibiotics');
  final CollectionReference _stockCollection =
      FirebaseFirestore.instance.collection('return_stock');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // User details for header
  String _currentUserName = 'Loading...';
  String? _profileImageUrl;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Map to hold quantity controllers for each item (key: antibioticId_dosageIndex)
  final Map<String, TextEditingController> _quantityControllers = {};

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserDetails();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (var controller in _quantityControllers.values) {
      controller.dispose();
    }
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

  // Helper to generate a unique key for each antibiotic+dosage
  String _itemKey(String antibioticId, int dosageIndex) {
    return '${antibioticId}_$dosageIndex';
  }

  // Get or create quantity controller for an item (now empty by default)
  TextEditingController _getController(String key) {
    if (!_quantityControllers.containsKey(key)) {
      _quantityControllers[key] = TextEditingController(); // No default value
    }
    return _quantityControllers[key]!;
  }

  Future<void> _exportToCSV() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Generating CSV...'),
          ],
        ),
      ),
    );

    try {
      final snapshot = await _stockCollection.orderBy('lastUpdated', descending: true).get();
      final docs = snapshot.docs;

      if (docs.isEmpty) {
        Navigator.pop(context);
        _showSnackBar('No data to export', false);
        return;
      }

      List<List<dynamic>> rows = [];
      rows.add([
        'SR Number',
        'Drug Name',
        'Dosage',
        'Quantity',
        'Last Updated',
        'Document ID',
      ]);

      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        rows.add([
          data['srNumber'] ?? '',
          data['drugName'] ?? '',
          data['dosage'] ?? '',
          data['quantity'] ?? 0,
          data['lastUpdated'] != null
              ? DateFormat('yyyy-MM-dd HH:mm').format((data['lastUpdated'] as Timestamp).toDate())
              : '',
          doc.id,
        ]);
      }

      String csv = const ListToCsvConverter().convert(rows);
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/return_store_export_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csv);
      Navigator.pop(context);
      await Share.shareXFiles([XFile(file.path)], text: 'Return Store Stock Export');
      file.delete();
    } catch (e) {
      Navigator.pop(context);
      _showSnackBar('Export failed: $e', false);
    }
  }

  void _showSnackBar(String msg, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isSuccess ? Icons.check_circle : Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isSuccess ? AppColors.successGreen : AppColors.disabledColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _updateQuantity(String stockId, int newQuantity) async {
    try {
      await _stockCollection.doc(stockId).update({
        'quantity': newQuantity,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      _showSnackBar('Quantity updated', true);
    } catch (e) {
      _showSnackBar('Update failed: $e', false);
    }
  }

  Future<void> _addQuantity(String stockId, int currentQuantity, int addAmount) async {
    try {
      await _stockCollection.doc(stockId).update({
        'quantity': currentQuantity + addAmount,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      _showSnackBar('Quantity increased by $addAmount', true);
    } catch (e) {
      _showSnackBar('Add failed: $e', false);
    }
  }

  Future<void> _createStockEntry({
    required String antibioticId,
    required int dosageIndex,
    required String srNumber,
    required String drugName,
    required String dosage,
    required int initialQuantity,
  }) async {
    try {
      await _stockCollection.add({
        'antibioticId': antibioticId,
        'dosageIndex': dosageIndex,
        'srNumber': srNumber,
        'drugName': drugName,
        'dosage': dosage,
        'quantity': initialQuantity,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      _showSnackBar('Stock entry created', true);
    } catch (e) {
      _showSnackBar('Creation failed: $e', false);
    }
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
            'Return Store',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.headerTextDark),
          ),
        ],
      ),
    );
  }

  // Summary card with counts (compact cards)
  Widget _buildSummaryCard(List<Map<String, dynamic>> allItems) {
    int total = allItems.length;
    int inStock = 0;
    int lowStock = 0;
    int outOfStock = 0;

    for (var item in allItems) {
      final qty = item['quantity'] ?? 0;
      if (qty == 0) {
        outOfStock++;
      } else if (qty < 50) {
        lowStock++;
      } else {
        inStock++;
      }
    }

    return Container(
      margin: const EdgeInsets.all(16),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Overview',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText),
              ),
              GestureDetector(
                onTap: _exportToCSV,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.download, size: 16, color: AppColors.primaryPurple),
                      SizedBox(width: 4),
                      Text('CSV', style: TextStyle(color: AppColors.primaryPurple)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildCompactStatCard(total.toString(), 'Total Items', AppColors.primaryPurple)),
              Expanded(child: _buildCompactStatCard(inStock.toString(), 'In Stock', AppColors.successGreen)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildCompactStatCard(lowStock.toString(), 'Low Stock', AppColors.warningOrange)),
              Expanded(child: _buildCompactStatCard(outOfStock.toString(), 'Out of Stock', AppColors.disabledColor)),
            ],
          ),
        ],
      ),
    );
  }

  // Compact stat card with smaller size
  Widget _buildCompactStatCard(String value, String label, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // නවීන stock item card එක
  Widget _buildStockItemCard({
    required Map<String, dynamic> item,
    required String srNumber,
    required String drugName,
    required String dosage,
    required int quantity,
    required String? stockId,
    required String key,
    required Color statusColor,
    required String statusText,
    required Timestamp? lastUpdated,
  }) {
    final controller = _getController(key);
    final formattedDate = lastUpdated != null
        ? DateFormat('dd MMM yyyy').format(lastUpdated.toDate())
        : 'Not updated';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF9F7FF)],
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.2),
            blurRadius: 18,
            offset: const Offset(0, 8),
            spreadRadius: -5,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: statusColor,
                  width: 8,
                ),
              ),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with drug name and status chip
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        drugName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // SR and Dosage info with icons
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.qr_code, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('SR: $srNumber', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.medical_services_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('Dosage: $dosage', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Current quantity with icon
                Row(
                  children: [
                    const Icon(Icons.inventory, size: 18, color: AppColors.primaryPurple),
                    const SizedBox(width: 6),
                    Text(
                      'Current Quantity: $quantity',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Quantity input and buttons
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Enter quantity',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (stockId == null) ...[
                      // No stock entry yet: show Add button to create
                      ElevatedButton(
                        onPressed: () {
                          final newQty = int.tryParse(controller.text);
                          if (newQty != null && newQty >= 0) {
                            _createStockEntry(
                              antibioticId: item['antibioticId'],
                              dosageIndex: item['dosageIndex'],
                              srNumber: srNumber,
                              drugName: drugName,
                              dosage: dosage,
                              initialQuantity: newQty,
                            );
                          } else {
                            _showSnackBar('Please enter a valid quantity', false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: const Text('Add'),
                      ),
                    ] else ...[
                      // Stock exists: show Add and Update buttons
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              final addQty = int.tryParse(controller.text);
                              if (addQty != null && addQty > 0) {
                                _addQuantity(stockId, quantity, addQty);
                              } else {
                                _showSnackBar('Please enter a positive number', false);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.successGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            child: const Text('Add'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              final newQty = int.tryParse(controller.text);
                              if (newQty != null && newQty >= 0) {
                                _updateQuantity(stockId, newQty);
                              } else {
                                _showSnackBar('Please enter a valid quantity', false);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryPurple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            child: const Text('Update'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 18),
                const Divider(height: 1, thickness: 1),
                const SizedBox(height: 10),

                // Footer with ID and last updated
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.fingerprint, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          stockId != null ? 'ID: ${stockId.substring(0, 6)}...' : 'ID: Not created',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.update, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          stockId != null ? formattedDate : 'Not updated',
                          style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _antibioticsCollection.snapshots(),
                builder: (context, antibioticSnapshot) {
                  if (antibioticSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (antibioticSnapshot.hasError) {
                    return Center(child: Text('Error: ${antibioticSnapshot.error}'));
                  }

                  final antibioticDocs = antibioticSnapshot.data?.docs ?? [];

                  return StreamBuilder<QuerySnapshot>(
                    stream: _stockCollection.snapshots(),
                    builder: (context, stockSnapshot) {
                      if (stockSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // Build a map of stock entries keyed by antibioticId_dosageIndex
                      final Map<String, Map<String, dynamic>> stockMap = {};
                      if (stockSnapshot.hasData) {
                        for (var doc in stockSnapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>?;
                          if (data == null) continue;
                          final key = _itemKey(data['antibioticId'] ?? '', data['dosageIndex'] ?? 0);
                          stockMap[key] = {
                            ...data,
                            'stockId': doc.id,
                          };
                        }
                      }

                      // Build list of all items: each antibiotic and each dosage
                      List<Map<String, dynamic>> allItems = [];
                      for (var antibioticDoc in antibioticDocs) {
                        final antibioticData = antibioticDoc.data() as Map<String, dynamic>?;
                        if (antibioticData == null) continue;
                        final antibioticId = antibioticDoc.id;
                        final drugName = antibioticData['name'] ?? 'Unknown';
                        final dosages = antibioticData['dosages'] as List<dynamic>? ?? [];

                        for (int i = 0; i < dosages.length; i++) {
                          final dosageMap = dosages[i] as Map<String, dynamic>?;
                          if (dosageMap == null) continue;
                          final srNumber = dosageMap['srNumber'] ?? '';
                          final dosage = dosageMap['dosage'] ?? '';

                          final key = _itemKey(antibioticId, i);
                          final stockEntry = stockMap[key];
                          final quantity = stockEntry?['quantity'] ?? 0;
                          final stockId = stockEntry?['stockId'];
                          final lastUpdated = stockEntry?['lastUpdated'] as Timestamp?;

                          allItems.add({
                            'antibioticId': antibioticId,
                            'dosageIndex': i,
                            'srNumber': srNumber,
                            'drugName': drugName,
                            'dosage': dosage,
                            'quantity': quantity,
                            'stockId': stockId,
                            'key': key,
                            'lastUpdated': lastUpdated,
                          });
                        }
                      }

                      // Apply search filter
                      final filteredItems = allItems.where((item) {
                        if (_searchQuery.isEmpty) return true;
                        return (item['drugName'] as String).toLowerCase().contains(_searchQuery) ||
                               (item['srNumber'] as String).toLowerCase().contains(_searchQuery);
                      }).toList();

                      return Column(
                        children: [
                          _buildSummaryCard(allItems),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search by drug name, SR number...',
                                prefixIcon: const Icon(Icons.search, color: AppColors.primaryPurple),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: filteredItems.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.inventory, size: 64, color: Colors.grey[300]),
                                        const SizedBox(height: 16),
                                        const Text('No items found.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(20),
                                    itemCount: filteredItems.length,
                                    itemBuilder: (context, index) {
                                      final item = filteredItems[index];
                                      final srNumber = item['srNumber'];
                                      final drugName = item['drugName'];
                                      final dosage = item['dosage'];
                                      final quantity = item['quantity'];
                                      final stockId = item['stockId'];
                                      final key = item['key'];
                                      final lastUpdated = item['lastUpdated'] as Timestamp?;

                                      Color statusColor;
                                      String statusText;
                                      if (quantity == 0) {
                                        statusColor = AppColors.disabledColor;
                                        statusText = 'Out of Stock';
                                      } else if (quantity < 50) {
                                        statusColor = AppColors.warningOrange;
                                        statusText = 'Low Stock';
                                      } else {
                                        statusColor = AppColors.successGreen;
                                        statusText = 'In Stock';
                                      }

                                      return _buildStockItemCard(
                                        item: item,
                                        srNumber: srNumber,
                                        drugName: drugName,
                                        dosage: dosage,
                                        quantity: quantity,
                                        stockId: stockId,
                                        key: key,
                                        statusColor: statusColor,
                                        statusText: statusText,
                                        lastUpdated: lastUpdated,
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}