// return_store_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// ✅ Local AppColors definition – ensure this is present
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
  final CollectionReference _stockCollection =
      FirebaseFirestore.instance.collection('return_stock'); // 👈 different collection
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _exportToCSV() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: const [
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
        final data = doc.data() as Map<String, dynamic>;
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

  Future<void> _updateQuantity(String docId, int newQuantity) async {
    try {
      await _stockCollection.doc(docId).update({
        'quantity': newQuantity,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      _showSnackBar('Quantity updated', true);
    } catch (e) {
      _showSnackBar('Update failed: $e', false);
    }
  }

  Widget _buildSummaryCard(AsyncSnapshot<QuerySnapshot> snapshot) {
    int total = 0;
    int inStock = 0;
    int lowStock = 0;
    int outOfStock = 0;

    if (snapshot.hasData) {
      final docs = snapshot.data!.docs;
      total = docs.length;
      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final qty = data['quantity'] ?? 0;
        if (qty == 0) {
          outOfStock++;
        } else if (qty < 50) {
          lowStock++;
        } else {
          inStock++;
        }
      }
    }

    return Container(
      margin: const EdgeInsets.all(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Return Store Overview',
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
                  child: Row(
                    children: const [
                      Icon(Icons.download, size: 16, color: AppColors.primaryPurple),
                      SizedBox(width: 4),
                      Text('Export CSV', style: TextStyle(color: AppColors.primaryPurple)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildStatCard('Total Items', total, AppColors.primaryPurple)),
              Expanded(child: _buildStatCard('In Stock', inStock, AppColors.successGreen)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildStatCard('Low Stock', lowStock, AppColors.warningOrange)),
              Expanded(child: _buildStatCard('Out of Stock', outOfStock, AppColors.disabledColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int value, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          Text(label, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Return Store'),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _stockCollection.orderBy('lastUpdated', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];
          return Column(
            children: [
              _buildSummaryCard(snapshot),
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
                child: docs.isEmpty
                    ? const Center(child: Text('No stock items found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final srNumber = data['srNumber'] ?? 'N/A';
                          final drugName = data['drugName'] ?? 'Unknown';
                          final dosage = data['dosage'] ?? '-';
                          final quantity = data['quantity'] ?? 0;
                          final lastUpdated = data['lastUpdated'] != null
                              ? DateFormat('MMM d, yyyy').format((data['lastUpdated'] as Timestamp).toDate())
                              : '-';

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

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          drugName,
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          statusText,
                                          style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text('SR: $srNumber', style: const TextStyle(color: Colors.grey)),
                                      const SizedBox(width: 16),
                                      Text('Dosage: $dosage', style: const TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Quantity: $quantity', style: const TextStyle(fontSize: 16)),
                                      Text('Updated: $lastUpdated', style: const TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: quantity.toString(),
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: 'New Quantity',
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          onFieldSubmitted: (value) {
                                            final newQty = int.tryParse(value);
                                            if (newQty != null && newQty >= 0) {
                                              _updateQuantity(doc.id, newQty);
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () {},
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primaryPurple,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: const Text('Update'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}