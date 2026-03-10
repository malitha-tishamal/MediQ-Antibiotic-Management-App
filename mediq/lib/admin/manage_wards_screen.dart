// manage_wards_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'add_ward_screen.dart';

class AppColors {
  static const Color primaryPurple = Color(0xFF9F7AEA);
  static const Color lightBackground = Color(0xFFF8F9FF);
  static const Color darkText = Color(0xFF2D3748);
  static const Color successGreen = Color(0xFF48BB78);
  static const Color disabledColor = Color(0xFFF56565);
  static const Color warningOrange = Color(0xFFED8936);
  static const Color headerGradientStart = Color.fromARGB(255, 235, 151, 225);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
  static const Color headerTextDark = Color(0xFF2D3748);
  static const Color cardBackground = Colors.white;
  static const Color chipBackground = Color(0xFFEDF2F7);
}

class ManageWardsScreen extends StatefulWidget {
  const ManageWardsScreen({super.key});

  @override
  State<ManageWardsScreen> createState() => _ManageWardsScreenState();
}

class _ManageWardsScreenState extends State<ManageWardsScreen> {
  final CollectionReference _wardsCollection =
      FirebaseFirestore.instance.collection('wards');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _currentUserName = 'Loading...';
  String? _profileImageUrl;

  // Filter state
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
            'Manage Wards',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.headerTextDark),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(String docId, String wardName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Ward'),
        content: Text('Are you sure you want to delete "$wardName"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _wardsCollection.doc(docId).delete();
        _showSnackBar('Deleted successfully', true);
      } catch (e) {
        _showSnackBar('Delete failed: $e', false);
      }
    }
  }

  void _showSnackBar(String msg, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isSuccess ? Icons.check_circle : Icons.error,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor:
            isSuccess ? AppColors.successGreen : AppColors.disabledColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          hintText: 'Search wards by name...',
          prefixIcon: Icon(Icons.search, color: AppColors.primaryPurple),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  // Compact modern filter chip without dot
  Widget _buildFilterChip(String label, int count, Color color, String filterValue) {
    final isSelected = _selectedFilter == filterValue;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filterValue;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : color.withOpacity(0.3),
          ),
        ),
        child: Text(
          '$label $count',
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(AsyncSnapshot<QuerySnapshot> snapshot) {
    int total = 0;
    int pediatrics = 0, medicine = 0, icu = 0, surgery = 0, medSub = 0, surgSub = 0, other = 0;

    if (snapshot.hasData) {
      final docs = snapshot.data!.docs;
      total = docs.length;
      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final category = data['category'] ?? '';
        switch (category) {
          case 'Pediatrics':
            pediatrics++;
            break;
          case 'Medicine':
            medicine++;
            break;
          case 'ICU':
            icu++;
            break;
          case 'Surgery':
            surgery++;
            break;
          case 'Medicine Subspecialty':
            medSub++;
            break;
          case 'Surgery Subspecialty':
            surgSub++;
            break;
          default:
            other++;
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, top: 4, bottom: 20),
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
            'Wards Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _buildFilterChip('All', total, AppColors.primaryPurple, 'All'),
              _buildFilterChip('Pediatrics', pediatrics, Colors.blue, 'Pediatrics'),
              _buildFilterChip('Medicine', medicine, Colors.green, 'Medicine'),
              _buildFilterChip('ICU', icu, Colors.orange, 'ICU'),
              _buildFilterChip('Surgery', surgery, Colors.purple, 'Surgery'),
              _buildFilterChip('Med Sub', medSub, Colors.teal, 'Medicine Subspecialty'),
              _buildFilterChip('Surg Sub', surgSub, Colors.brown, 'Surgery Subspecialty'),
              if (other > 0) _buildFilterChip('Other', other, Colors.grey, 'Other'),
            ],
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Pediatrics':
        return Colors.blue;
      case 'Medicine':
        return Colors.green;
      case 'ICU':
        return Colors.orange;
      case 'Surgery':
        return Colors.purple;
      case 'Medicine Subspecialty':
        return Colors.teal;
      case 'Surgery Subspecialty':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                _buildSearchBar(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _wardsCollection.orderBy('createdAt', descending: true).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      final docs = snapshot.data?.docs ?? [];
                      final filteredDocs = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        
                        // Apply category filter
                        if (_selectedFilter != 'All') {
                          final category = data['category'] ?? '';
                          if (_selectedFilter == 'Other') {
                            // Other includes anything not in the main list
                            if (category == 'Pediatrics' || 
                                category == 'Medicine' || 
                                category == 'ICU' || 
                                category == 'Surgery' || 
                                category == 'Medicine Subspecialty' || 
                                category == 'Surgery Subspecialty') {
                              return false;
                            }
                          } else {
                            if (category != _selectedFilter) return false;
                          }
                        }
                        
                        // Apply search filter
                        if (_searchQuery.isNotEmpty) {
                          final name = (data['wardName'] ?? '').toLowerCase();
                          if (!name.contains(_searchQuery)) return false;
                        }
                        
                        return true;
                      }).toList();

                      return Column(
                        children: [
                          _buildSummaryCard(snapshot),
                          Expanded(
                            child: filteredDocs.isEmpty
                                ? _buildEmptyState()
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 8),
                                    itemCount: filteredDocs.length,
                                    itemBuilder: (context, index) {
                                      final doc = filteredDocs[index];
                                      final data = doc.data() as Map<String, dynamic>;

                                      final wardName = data['wardName'] ?? 'Unnamed';
                                      final team = data['team'] ?? '-';
                                      final managedBy = data['managedBy'] ?? '-';
                                      final category = data['category'] ?? '-';
                                      final description = data['description'] ?? '';
                                      final Timestamp? createdAt = data['createdAt'] as Timestamp?;
                                      String createdDate = '';
                                      if (createdAt != null) {
                                        createdDate = DateFormat('dd MMM yyyy').format(createdAt.toDate());
                                      }

                                      // ----- Modern Card with edit/delete buttons -----
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
                                              color: _getCategoryColor(category).withOpacity(0.2),
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
                                                    color: _getCategoryColor(category),
                                                    width: 8,
                                                  ),
                                                ),
                                              ),
                                              padding: const EdgeInsets.all(18),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          wardName,
                                                          style: const TextStyle(
                                                            fontSize: 20,
                                                            fontWeight: FontWeight.bold,
                                                            color: AppColors.darkText,
                                                            letterSpacing: 0.5,
                                                          ),
                                                        ),
                                                      ),
                                                      Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Container(
                                                            decoration: BoxDecoration(
                                                              color: Colors.orange.withOpacity(0.1),
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                                            child: IconButton(
                                                              icon: const Icon(Icons.edit,
                                                                  color: Colors.orange, size: 22),
                                                              onPressed: () {
                                                                Navigator.push(
                                                                  context,
                                                                  MaterialPageRoute(
                                                                    builder: (_) =>
                                                                        AddWardScreen(wardId: doc.id),
                                                                  ),
                                                                );
                                                              },
                                                              padding: EdgeInsets.zero,
                                                              constraints: const BoxConstraints(),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Container(
                                                            decoration: BoxDecoration(
                                                              color: Colors.red.withOpacity(0.1),
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                                            child: IconButton(
                                                              icon: const Icon(Icons.delete,
                                                                  color: Colors.red, size: 22),
                                                              onPressed: () => _confirmDelete(doc.id, wardName),
                                                              padding: EdgeInsets.zero,
                                                              constraints: const BoxConstraints(),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Wrap(
                                                    spacing: 8,
                                                    runSpacing: 8,
                                                    children: [
                                                      _buildInfoChip(icon: Icons.group, label: team),
                                                      _buildInfoChip(icon: Icons.person, label: managedBy),
                                                      _buildInfoChip(
                                                        icon: Icons.category,
                                                        label: category,
                                                        color: _getCategoryColor(category),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 12),
                                                  if (description.isNotEmpty)
                                                    Container(
                                                      padding: const EdgeInsets.all(12),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.chipBackground,
                                                        borderRadius: BorderRadius.circular(16),
                                                      ),
                                                      child: Row(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          const Icon(Icons.description,
                                                              size: 16, color: Colors.grey),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              description,
                                                              style: const TextStyle(fontSize: 13),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    )
                                                  else
                                                    Container(
                                                      padding: const EdgeInsets.all(12),
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey.shade50,
                                                        borderRadius: BorderRadius.circular(16),
                                                      ),
                                                      child: const Row(
                                                        children: [
                                                          Icon(Icons.info_outline,
                                                              size: 16, color: Colors.grey),
                                                          SizedBox(width: 8),
                                                          Text(
                                                            'No description provided',
                                                            style: TextStyle(color: Colors.grey),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  const SizedBox(height: 18),
                                                  const Divider(height: 1, thickness: 1),
                                                  const SizedBox(height: 10),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.fingerprint,
                                                              size: 14, color: Colors.grey),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            'ID: ${doc.id.substring(0, 6)}...',
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              color: Colors.grey,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.calendar_today,
                                                              size: 12, color: Colors.grey),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            createdDate,
                                                            style: const TextStyle(
                                                              fontSize: 12,
                                                              color: Colors.grey,
                                                              fontWeight: FontWeight.w500,
                                                            ),
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
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: const Color.fromARGB(255, 255, 255, 255),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_hospital, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No wards match "$_searchQuery"'
                : 'No ${_selectedFilter == 'All' ? '' : _selectedFilter} wards found.',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
          if (_selectedFilter != 'All' || _searchQuery.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedFilter = 'All';
                  _searchController.clear();
                });
              },
              child: const Text('Clear filters'),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label, Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: (color ?? Colors.grey).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? Colors.grey),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color ?? Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}