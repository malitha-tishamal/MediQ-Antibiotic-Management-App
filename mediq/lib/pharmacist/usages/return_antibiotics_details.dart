// return_antibiotics_details.dart
// Improved UI with modern design, better visual hierarchy, and timezone support
// Edit/Delete buttons visible only to the creator

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../pharmacist_drawer.dart';
import '../../auth/login_page.dart';

class AppColors {
  static const Color primaryPurple = Color(0xFF9F7AEA);
  static const Color lightBackground = Color(0xFFF3F0FF);
  static const Color darkText = Color(0xFF333333);
  static const Color successGreen = Color(0xFF48BB78);
  static const Color warningOrange = Color(0xFFED8936);
  static const Color disabledColor = Color(0xFFF56565);
  static const Color headerGradientStart = Color.fromARGB(255, 235, 151, 225);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
  static const Color headerTextDark = Color(0xFF333333);
  static const Color inputBorder = Color(0xFFE0E0E0);
  static const Color cardShadow = Color(0x1A000000);
  static const Color chipBackground = Color(0xFFF5F5F5);
}

class ReturnAntibioticsDetails extends StatefulWidget {
  const ReturnAntibioticsDetails({super.key});

  @override
  State<ReturnAntibioticsDetails> createState() => _ReturnAntibioticsDetailsState();
}

class _ReturnAntibioticsDetailsState extends State<ReturnAntibioticsDetails>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _userCollection = FirebaseFirestore.instance.collection('users');
  final CollectionReference _returnsCollection = FirebaseFirestore.instance.collection('returns');
  final CollectionReference _wardsCollection = FirebaseFirestore.instance.collection('wards');
  final CollectionReference _antibioticsCollection = FirebaseFirestore.instance.collection('antibiotics');

  String _currentUserName = 'Loading...';
  String _currentUserRole = 'Pharmacist';
  String? _profileImageUrl;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Search & category filter
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All'; // 'All', 'Access', 'Watch', 'Reserve', 'Other'

  // Advanced filters (from bottom sheet)
  String? _selectedWardId;
  String? _selectedAntibioticId;
  DateTime? _startDate;
  DateTime? _endDate;

  // Data for dropdowns
  List<Map<String, dynamic>> _wards = [];
  List<Map<String, dynamic>> _antibiotics = [];
  Map<String, String> _antibioticCategoryMap = {}; // id -> category

  // Cache for user names
  final Map<String, String> _userNameCache = {};

  // Animation controller for fade-in effects
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    // Initialize timezone
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Colombo'));

    // Set default date range to current month
    final now = tz.TZDateTime.now(tz.local);
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = now;

    // Initialize animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animationController.forward();

    _fetchCurrentUserDetails();
    _fetchFilterData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentUserDetails() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _userCollection.doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            _currentUserName = data['fullName'] ?? user.email?.split('@').first ?? 'User';
            _currentUserRole = data['role'] ?? 'Pharmacist';
            _profileImageUrl = data['profileImageUrl'];
          });
        }
      } catch (e) {
        debugPrint('Error fetching user: $e');
      }
    }
  }

  Future<void> _fetchFilterData() async {
    try {
      final wardsSnapshot = await _wardsCollection.get();
      _wards = wardsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, 'name': data['wardName'] ?? 'Unknown'};
      }).toList();

      final antibioticsSnapshot = await _antibioticsCollection.get();
      _antibiotics = antibioticsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final category = data['category'] ?? 'Other';
        _antibioticCategoryMap[doc.id] = category;
        return {'id': doc.id, 'name': data['name'] ?? 'Unknown'};
      }).toList();

      setState(() {});
    } catch (e) {
      debugPrint('Error fetching filter data: $e');
    }
  }

  void _handleNavTap(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title tapped')),
    );
  }

  Future<void> _handleLogout() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Logout Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    IconData? prefixIcon,
    String? hintText,
    bool enabled = true,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: TextStyle(
        color: enabled ? AppColors.primaryPurple : Colors.grey.shade600,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      filled: true,
      fillColor: enabled ? Colors.white : Colors.grey.shade100,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2.0),
      ),
      prefixIcon: prefixIcon == null
          ? null
          : Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Colors.grey.shade300, width: 1.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Icon(prefixIcon, color: AppColors.primaryPurple, size: 20),
              ),
            ),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
    );
  }

  void _showFilterPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                            DropdownButtonFormField<String>(
                              value: _selectedWardId,
                              decoration: _inputDecoration(label: 'Ward', prefixIcon: Icons.place),
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
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _selectedAntibioticId,
                              decoration: _inputDecoration(label: 'Antibiotic', prefixIcon: Icons.medication),
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
                            const SizedBox(height: 16),
                            const Text('Date Range', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: _startDate ?? tz.TZDateTime.now(tz.local),
                                        firstDate: DateTime(2020),
                                        lastDate: tz.TZDateTime.now(tz.local),
                                      );
                                      if (date != null) {
                                        setState(() => _startDate = date);
                                        setModalState(() {});
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: _inputDecoration(label: 'From'),
                                      child: Text(_startDate != null
                                          ? DateFormat('yyyy-MM-dd').format(_startDate!)
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
                                        initialDate: _endDate ?? tz.TZDateTime.now(tz.local),
                                        firstDate: DateTime(2020),
                                        lastDate: tz.TZDateTime.now(tz.local),
                                      );
                                      if (date != null) {
                                        setState(() => _endDate = date);
                                        setModalState(() {});
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: _inputDecoration(label: 'To'),
                                      child: Text(_endDate != null
                                          ? DateFormat('yyyy-MM-dd').format(_endDate!)
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
                                    onPressed: () => Navigator.pop(context),
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
          },
        );
      },
    );
  }

  Widget _buildFilterChip(String label, int count, Color color, String filterValue) {
    final isSelected = _selectedCategory == filterValue;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = filterValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : AppColors.chipBackground,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? Colors.transparent : color.withOpacity(0.3),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_circle, size: 14, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              '$label $count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilterRow(List<DocumentSnapshot> docs) {
    int all = docs.length;
    int access = 0, watch = 0, reserve = 0, other = 0;
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final antibioticId = data['antibioticId'] ?? '';
      final category = _antibioticCategoryMap[antibioticId] ?? 'Other';
      if (category == 'Access') access++;
      else if (category == 'Watch') watch++;
      else if (category == 'Reserve') reserve++;
      else other++;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('All', all, AppColors.primaryPurple, 'All'),
          _buildFilterChip('Access', access, AppColors.primaryPurple, 'Access'),
          _buildFilterChip('Watch', watch, AppColors.successGreen, 'Watch'),
          _buildFilterChip('Reserve', reserve, AppColors.warningOrange, 'Reserve'),
          _buildFilterChip('Other', other, Colors.grey, 'Other'),
        ],
      ),
    );
  }

  bool _filterReturn(Map<String, dynamic> data) {
    if (_searchQuery.isNotEmpty) {
      final antibiotic = (data['antibioticName'] ?? '').toLowerCase();
      final ward = (data['wardName'] ?? '').toLowerCase();
      if (!antibiotic.contains(_searchQuery) && !ward.contains(_searchQuery)) {
        return false;
      }
    }

    if (_selectedCategory != 'All') {
      final antibioticId = data['antibioticId'] ?? '';
      final category = _antibioticCategoryMap[antibioticId] ?? 'Other';
      if (_selectedCategory == 'Other') {
        if (category == 'Access' || category == 'Watch' || category == 'Reserve') return false;
      } else {
        if (category != _selectedCategory) return false;
      }
    }

    if (_selectedWardId != null && data['wardId'] != _selectedWardId) {
      return false;
    }

    if (_selectedAntibioticId != null && data['antibioticId'] != _selectedAntibioticId) {
      return false;
    }

    if (_startDate != null || _endDate != null) {
      final returnDate = (data['returnDateTime'] as Timestamp?)?.toDate();
      if (returnDate == null) return false;
      final returnLocal = tz.TZDateTime.from(returnDate, tz.local);
      final startLocal = _startDate != null ? tz.TZDateTime.from(_startDate!, tz.local) : null;
      final endLocal = _endDate != null ? tz.TZDateTime.from(_endDate!, tz.local) : null;
      if (startLocal != null && returnLocal.isBefore(startLocal)) return false;
      if (endLocal != null && returnLocal.isAfter(endLocal.add(const Duration(days: 1)))) return false;
    }
    return true;
  }

  // Pure helper to compute current month returns count (no setState)
  int _computeCurrentMonthCount(List<DocumentSnapshot> docs) {
    final now = tz.TZDateTime.now(tz.local);
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final startLocal = tz.TZDateTime.from(startOfMonth, tz.local);
    final endLocal = tz.TZDateTime.from(endOfMonth, tz.local);

    int count = 0;
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final returnDate = (data['returnDateTime'] as Timestamp?)?.toDate();
      if (returnDate != null) {
        final returnLocal = tz.TZDateTime.from(returnDate, tz.local);
        if (returnLocal.isAfter(startLocal.subtract(const Duration(days: 1))) &&
            returnLocal.isBefore(endLocal.add(const Duration(days: 1)))) {
          count++;
        }
      }
    }
    return count;
  }

  Future<String> _getUserName(String userId) async {
    if (_userNameCache.containsKey(userId)) return _userNameCache[userId]!;
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final name = (doc.data() as Map<String, dynamic>)['fullName'] ?? 'Unknown User';
        _userNameCache[userId] = name;
        return name;
      } else {
        _userNameCache[userId] = 'Unknown User';
        return 'Unknown User';
      }
    } catch (e) {
      debugPrint('Error fetching user name: $e');
      return 'Unknown User';
    }
  }

  Future<void> _editReturn(String docId, int currentQuantity) async {
    final TextEditingController qtyController = TextEditingController(text: currentQuantity.toString());
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Quantity'),
        content: TextField(
          controller: qtyController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'New Quantity'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newQty = int.tryParse(qtyController.text);
              if (newQty == null || newQty < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid positive number')),
                );
                return;
              }
              try {
                await _returnsCollection.doc(docId).update({'itemCount': newQty});
                if (context.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Update failed: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == true) {
      _showSnackBar('Quantity updated', true);
    }
  }

  Future<void> _confirmDelete(String docId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Return Record'),
        content: Text('Are you sure you want to delete return for "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
        await _returnsCollection.doc(docId).delete();
        _showSnackBar('Deleted successfully', true);
      } catch (e) {
        _showSnackBar('Delete failed: $e', false);
      }
    }
  }

  void _showDetailsModal(Map<String, dynamic> data, String docId) {
    final antibioticName = data['antibioticName'] ?? 'Unknown';
    final dosage = data['dosage'] ?? '';
    final quantity = data['itemCount'] ?? 0;
    final wardName = data['wardName'] ?? 'Unknown';
    final returnDateTime = (data['returnDateTime'] as Timestamp?)?.toDate();
    final formattedDate = returnDateTime != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(returnDateTime)
        : 'N/A';
    final bookNumber = data['bookNumber'] ?? '';
    final pageNumber = data['pageNumber'] ?? '';
    final createdBy = data['createdBy'] ?? '';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final formattedCreated = createdAt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt) : 'N/A';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFF9F7FF)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: FutureBuilder<String>(
            future: _getUserName(createdBy),
            builder: (context, snapshot) {
              final returnedByName = snapshot.data ?? 'Loading...';
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        antibioticName,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.darkText),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text(
                          'Return Store',
                          style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _detailRow(Icons.medical_services, 'Dosage', dosage),
                  _detailRow(Icons.inventory, 'Quantity', quantity.toString()),
                  _detailRow(Icons.place, 'Ward', wardName),
                  _detailRow(Icons.menu_book, 'Book Number', bookNumber),
                  _detailRow(Icons.pages, 'Page Number', pageNumber),
                  _detailRow(Icons.access_time, 'Return Time', formattedDate),
                  _detailRow(Icons.person, 'Returned by', returnedByName),
                  _detailRow(Icons.calendar_today, 'Created At', formattedCreated),
                  _detailRow(Icons.fingerprint, 'Document ID', docId),
                  const SizedBox(height: 24),
                  // Action buttons: Close always visible, Edit/Delete only for creator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                      if (createdBy == _auth.currentUser?.uid) ...[
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _editReturn(docId, quantity);
                          },
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Edit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _confirmDelete(docId, antibioticName);
                          },
                          icon: const Icon(Icons.delete, size: 18),
                          label: const Text('Delete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryPurple),
          const SizedBox(width: 16),
          SizedBox(
            width: 110,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.darkText)),
          ),
          Expanded(child: Text(value, style: const TextStyle(color: AppColors.darkText))),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isSuccess ? Icons.check_circle : Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isSuccess ? AppColors.successGreen : AppColors.disabledColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildReturnCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final antibioticName = data['antibioticName'] ?? 'Unknown';
    final dosage = data['dosage'] ?? '';
    final quantity = data['itemCount'] ?? 0;
    final wardName = data['wardName'] ?? 'Unknown';
    final returnDateTime = (data['returnDateTime'] as Timestamp?)?.toDate();
    final formattedDate = returnDateTime != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(returnDateTime)
        : 'N/A';
    final bookNumber = data['bookNumber'] ?? '';
    final pageNumber = data['pageNumber'] ?? '';
    final antibioticId = data['antibioticId'] ?? '';
    final category = _antibioticCategoryMap[antibioticId] ?? 'Other';
    final Color categoryColor = _getCategoryColor(category);
    final createdBy = data['createdBy'] ?? '';

    return FadeTransition(
      opacity: _animationController,
      child: GestureDetector(
        onTap: () => _showDetailsModal(data, doc.id),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: categoryColor, width: 6),
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            antibioticName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkText,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Return',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        // Edit/Delete icons only visible to the creator
                        if (createdBy == _auth.currentUser?.uid)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.orange, size: 18),
                                onPressed: () => _editReturn(doc.id, quantity),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Edit',
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                onPressed: () => _confirmDelete(doc.id, antibioticName),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Delete',
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(color: categoryColor, fontWeight: FontWeight.w600, fontSize: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _infoChip(Icons.medical_services, 'Dosage: $dosage'),
                        _infoChip(Icons.inventory, 'Qty: $quantity'),
                        _infoChip(Icons.place, wardName),
                        _infoChip(Icons.menu_book, 'Book: $bookNumber'),
                        _infoChip(Icons.pages, 'Page: $pageNumber'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, thickness: 0.5),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.fingerprint, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('ID: ${doc.id.substring(0, 4)}...', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    FutureBuilder<String>(
                      future: _getUserName(createdBy),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Row(
                            children: [
                              Icon(Icons.person, size: 12, color: Colors.grey),
                              SizedBox(width: 4),
                              Text('Returned by: Loading...', style: TextStyle(color: Colors.grey, fontSize: 10)),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            const Icon(Icons.person, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Returned by: ${snapshot.data ?? 'Unknown'}',
                                style: const TextStyle(color: Colors.grey, fontSize: 10),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.chipBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primaryPurple),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.darkText)),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Access':
        return AppColors.primaryPurple;
      case 'Watch':
        return AppColors.successGreen;
      case 'Reserve':
        return AppColors.warningOrange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildCurrentMonthIndicator(int count) {
    final monthName = DateFormat('MMMM').format(_getSriLankaNow());
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryPurple.withOpacity(0.1), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryPurple.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 18, color: AppColors.primaryPurple),
              const SizedBox(width: 8),
              Text(
                '$monthName Returns:',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: count > 0 ? AppColors.primaryPurple : Colors.red,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  DateTime _getSriLankaNow() => tz.TZDateTime.now(tz.local);

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 8, left: 20, right: 20, bottom: 16),
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
            color: Color(0x10000000),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Single row: left icons, center user info, right profile picture
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left side: back button + filter icon
              Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.arrow_back,
                        color: AppColors.headerTextDark, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.tune,
                        color: AppColors.headerTextDark, size: 24),
                    onPressed: _showFilterPanel,
                  ),
                ],
              ),
              const Spacer(),
              // Center: user info
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentUserName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.headerTextDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Logged in as: Pharmacist',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.headerTextDark,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Right side: profile picture (80x80)
              _buildProfileAvatar(),
            ],
          ),
          const SizedBox(height: 16),
          // Title
          const Text(
            'Return Antibiotics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.headerTextDark,
            ),
          ),
        ],
      ),
    );
  }

  // Helper for profile avatar (80x80, radius 40)
  Widget _buildProfileAvatar() {
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 40,
        backgroundImage: NetworkImage(_profileImageUrl!),
        backgroundColor: Colors.grey.shade200,
        onBackgroundImageError: (_, __) {
          if (mounted) setState(() => _profileImageUrl = null);
        },
      );
    } else {
      return CircleAvatar(
        radius: 40,
        backgroundColor: AppColors.primaryPurple.withOpacity(0.2),
        child: const Icon(Icons.person, color: AppColors.primaryPurple, size: 48),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.lightBackground,
      drawer: PharmacistDrawer(
        userName: _currentUserName,
        userRole: _currentUserRole,
        profileImageUrl: _profileImageUrl,
        onNavTap: _handleNavTap,
        onLogout: _handleLogout,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Container(
                  margin: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 4),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by antibiotic or ward...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.primaryPurple),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _returnsCollection.orderBy('returnDateTime', descending: true).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      final docs = snapshot.data?.docs ?? [];
                      // Compute current month count directly (no setState)
                      final currentMonthCount = _computeCurrentMonthCount(docs);
                      final categoryFilterRow = _buildCategoryFilterRow(docs);
                      final filteredDocs = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return _filterReturn(data);
                      }).toList();

                      return Column(
                        children: [
                          _buildCurrentMonthIndicator(currentMonthCount),
                          categoryFilterRow,
                          Expanded(
                            child: filteredDocs.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.inbox, size: 64, color: Colors.grey[300]),
                                        const SizedBox(height: 16),
                                        const Text('No return records found.', style: TextStyle(color: Colors.grey)),
                                        if (docs.isNotEmpty)
                                          TextButton(
                                            onPressed: () {
                                              setState(() {
                                                _searchController.clear();
                                                _selectedCategory = 'All';
                                                _selectedWardId = null;
                                                _selectedAntibioticId = null;
                                                _startDate = null;
                                                _endDate = null;
                                              });
                                            },
                                            child: const Text('Clear Filters'),
                                          ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    itemCount: filteredDocs.length,
                                    itemBuilder: (context, index) {
                                      return _buildReturnCard(filteredDocs[index]);
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