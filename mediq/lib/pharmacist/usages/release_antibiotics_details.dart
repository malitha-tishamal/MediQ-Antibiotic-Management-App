// release_antibiotics_details.dart (modern bottom sheet modal)
// Improved UI with modern design, timezone support, and edit/delete buttons visible only to creator

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

class ReleaseAntibioticsDetails extends StatefulWidget {
  const ReleaseAntibioticsDetails({super.key});

  @override
  State<ReleaseAntibioticsDetails> createState() => _ReleaseAntibioticsDetailsState();
}

class _ReleaseAntibioticsDetailsState extends State<ReleaseAntibioticsDetails>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _userCollection = FirebaseFirestore.instance.collection('users');
  final CollectionReference _releasesCollection = FirebaseFirestore.instance.collection('releases');
  final CollectionReference _wardsCollection = FirebaseFirestore.instance.collection('wards');
  final CollectionReference _antibioticsCollection = FirebaseFirestore.instance.collection('antibiotics');

  String _currentUserName = 'Loading...';
  String _currentUserRole = 'Pharmacist';
  String? _profileImageUrl;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  String? _selectedWardId;
  String? _selectedAntibioticId;
  DateTime? _startDate;
  DateTime? _endDate;

  List<Map<String, dynamic>> _wards = [];
  List<Map<String, dynamic>> _antibiotics = [];
  Map<String, String> _antibioticCategoryMap = {};
  final Map<String, String> _userNameCache = {};

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Colombo'));

    final now = tz.TZDateTime.now(tz.local);
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = now;

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
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12),
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
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(prefixIcon, color: AppColors.primaryPurple, size: 18),
              ),
            ),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
                            DropdownButtonFormField<String>(
                              value: _selectedWardId,
                              decoration: _inputDecoration(label: 'Ward', prefixIcon: Icons.place),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('All Wards')),
                                ..._wards.map((w) => DropdownMenuItem(value: w['id'], child: Text(w['name']))),
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
                                ..._antibiotics.map((a) => DropdownMenuItem(value: a['id'], child: Text(a['name']))),
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

  // Ultra‑compact filter chip
  Widget _buildFilterChip(String label, int count, Color color, String filterValue) {
    final isSelected = _selectedCategory == filterValue;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = filterValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: isSelected ? color : AppColors.chipBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? Colors.transparent : color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_circle, size: 10, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              '$label $count',
              style: TextStyle(
                fontSize: 10,
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      height: 38,
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

  bool _filterRelease(Map<String, dynamic> data) {
    if (_searchQuery.isNotEmpty) {
      final antibiotic = (data['antibioticName'] ?? '').toLowerCase();
      final ward = (data['wardName'] ?? '').toLowerCase();
      if (!antibiotic.contains(_searchQuery) && !ward.contains(_searchQuery)) return false;
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
    if (_selectedWardId != null && data['wardId'] != _selectedWardId) return false;
    if (_selectedAntibioticId != null && data['antibioticId'] != _selectedAntibioticId) return false;
    if (_startDate != null || _endDate != null) {
      final releaseDate = (data['releaseDateTime'] as Timestamp?)?.toDate();
      if (releaseDate == null) return false;
      final releaseLocal = tz.TZDateTime.from(releaseDate, tz.local);
      final startLocal = _startDate != null ? tz.TZDateTime.from(_startDate!, tz.local) : null;
      final endLocal = _endDate != null ? tz.TZDateTime.from(_endDate!, tz.local) : null;
      if (startLocal != null && releaseLocal.isBefore(startLocal)) return false;
      if (endLocal != null && releaseLocal.isAfter(endLocal.add(const Duration(days: 1)))) return false;
    }
    return true;
  }

  int _computeCurrentMonthCount(List<DocumentSnapshot> docs) {
    final now = tz.TZDateTime.now(tz.local);
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final startLocal = tz.TZDateTime.from(startOfMonth, tz.local);
    final endLocal = tz.TZDateTime.from(endOfMonth, tz.local);
    int count = 0;
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final releaseDate = (data['releaseDateTime'] as Timestamp?)?.toDate();
      if (releaseDate != null) {
        final releaseLocal = tz.TZDateTime.from(releaseDate, tz.local);
        if (releaseLocal.isAfter(startLocal.subtract(const Duration(days: 1))) &&
            releaseLocal.isBefore(endLocal.add(const Duration(days: 1)))) {
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

  Future<void> _editRelease(String docId, int currentQuantity) async {
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
                await _releasesCollection.doc(docId).update({'itemCount': newQty});
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
        title: const Text('Delete Release'),
        content: Text('Are you sure you want to delete release for "$name"?'),
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
        await _releasesCollection.doc(docId).delete();
        _showSnackBar('Deleted successfully', true);
      } catch (e) {
        _showSnackBar('Delete failed: $e', false);
      }
    }
  }

  // ========== MODERN BOTTOM SHEET MODAL (Replaces old Dialog) ==========
  void _showDetailsModal(Map<String, dynamic> data, String docId) {
    final antibioticName = data['antibioticName'] ?? 'Unknown';
    final dosage = data['dosage'] ?? '';
    final quantity = data['itemCount'] ?? 0;
    final wardName = data['wardName'] ?? 'Unknown';
    final releaseDateTime = (data['releaseDateTime'] as Timestamp?)?.toDate();
    final formattedDate = releaseDateTime != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(releaseDateTime)
        : 'N/A';
    final bookNumber = data['bookNumber'] ?? '';
    final pageNumber = data['pageNumber'] ?? '';
    final stockType = data['stockType'] == 'msd' ? 'Main Store' : 'Return Store';
    final createdBy = data['createdBy'] ?? '';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final formattedCreated = createdAt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt) : 'N/A';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, -2))],
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: FutureBuilder<String>(
                    future: _getUserName(createdBy),
                    builder: (context, snapshot) {
                      final releasedByName = snapshot.data ?? 'Loading...';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: title + stock type badge
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  antibioticName,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.darkText,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: stockType == 'Main Store' ? Colors.green.shade50 : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: stockType == 'Main Store' ? Colors.green.shade200 : Colors.orange.shade200),
                                ),
                                child: Text(
                                  stockType,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: stockType == 'Main Store' ? Colors.green.shade700 : Colors.orange.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Highlighted quantity card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primaryPurple, Color(0xFFB794F4)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryPurple.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Released Quantity',
                                  style: TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$quantity',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Details with modern row style
                          _modernDetailRow(Icons.medical_services, 'Dosage', dosage),
                          _modernDetailRow(Icons.place, 'Ward', wardName),
                          _modernDetailRow(Icons.menu_book, 'Book Number', bookNumber),
                          _modernDetailRow(Icons.pages, 'Page Number', pageNumber),
                          _modernDetailRow(Icons.access_time, 'Release Time', formattedDate),
                          _modernDetailRow(Icons.person, 'Released by', releasedByName),
                          _modernDetailRow(Icons.calendar_today, 'Created At', formattedCreated),
                          _modernDetailRow(Icons.fingerprint, 'Document ID', docId),

                          const SizedBox(height: 24),

                          // Action buttons (Close always, Edit/Delete only for creator)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close, size: 18),
                                  label: const Text('Close'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.grey.shade700,
                                    side: BorderSide(color: Colors.grey.shade300),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                              if (createdBy == _auth.currentUser?.uid) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _editRelease(docId, quantity);
                                    },
                                    icon: const Icon(Icons.edit, size: 18),
                                    label: const Text('Edit'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _confirmDelete(docId, antibioticName);
                                    },
                                    icon: const Icon(Icons.delete, size: 18),
                                    label: const Text('Delete'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Modern detail row used inside the bottom sheet
  Widget _modernDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: AppColors.primaryPurple),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isSuccess ? Icons.check_circle : Icons.error, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: isSuccess ? AppColors.successGreen : AppColors.disabledColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Ultra‑compact release card (unchanged – already modern and compact)
  Widget _buildReleaseCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final antibioticName = data['antibioticName'] ?? 'Unknown';
    final dosage = data['dosage'] ?? '';
    final quantity = data['itemCount'] ?? 0;
    final wardName = data['wardName'] ?? 'Unknown';
    final releaseDateTime = (data['releaseDateTime'] as Timestamp?)?.toDate();
    final formattedDate = releaseDateTime != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(releaseDateTime)
        : 'N/A';
    final bookNumber = data['bookNumber'] ?? '';
    final pageNumber = data['pageNumber'] ?? '';
    final stockType = data['stockType'] == 'msd' ? 'MSD' : 'LP';
    final antibioticId = data['antibioticId'] ?? '';
    final category = _antibioticCategoryMap[antibioticId] ?? 'Other';
    final Color categoryColor = _getCategoryColor(category);
    final createdBy = data['createdBy'] ?? '';

    return FadeTransition(
      opacity: _animationController,
      child: GestureDetector(
        onTap: () => _showDetailsModal(data, doc.id),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: categoryColor, width: 3)),
                ),
                padding: const EdgeInsets.all(8),
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
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkText,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: stockType == 'MSD' ? Colors.green.shade50 : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            stockType,
                            style: TextStyle(
                              fontSize: 9,
                              color: stockType == 'MSD' ? Colors.green.shade700 : Colors.orange.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (createdBy == _auth.currentUser?.uid)
                          Row(
                            children: [
                              InkWell(
                                onTap: () => _editRelease(doc.id, quantity),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(Icons.edit, color: Colors.orange, size: 12),
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => _confirmDelete(doc.id, antibioticName),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(Icons.delete, color: Colors.red, size: 12),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(color: categoryColor, fontWeight: FontWeight.w600, fontSize: 9),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 3,
                      children: [
                        _infoChipCompact(Icons.medical_services, 'Dosage: $dosage'),
                        _infoChipCompact(Icons.inventory, 'Qty: $quantity'),
                        _infoChipCompact(Icons.place, wardName),
                        _infoChipCompact(Icons.menu_book, 'Book: $bookNumber'),
                        _infoChipCompact(Icons.pages, 'Page: $pageNumber'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Divider(height: 0.8, thickness: 0.5),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 9, color: Colors.grey),
                            const SizedBox(width: 2),
                            Text(formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 8)),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.fingerprint, size: 9, color: Colors.grey),
                            const SizedBox(width: 2),
                            Text('ID: ${doc.id.substring(0, 4)}...', style: const TextStyle(color: Colors.grey, fontSize: 8)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    FutureBuilder<String>(
                      future: _getUserName(createdBy),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Row(
                            children: [
                              Icon(Icons.person, size: 9, color: Colors.grey),
                              SizedBox(width: 2),
                              Text('Released by: Loading...', style: TextStyle(color: Colors.grey, fontSize: 8)),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            const Icon(Icons.person, size: 9, color: Colors.grey),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                'Released by: ${snapshot.data ?? 'Unknown'}',
                                style: const TextStyle(color: Colors.grey, fontSize: 8),
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

  Widget _infoChipCompact(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.chipBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: AppColors.primaryPurple),
          const SizedBox(width: 2),
          Text(label, style: const TextStyle(fontSize: 9, color: AppColors.darkText)),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Access': return AppColors.primaryPurple;
      case 'Watch': return AppColors.successGreen;
      case 'Reserve': return AppColors.warningOrange;
      default: return Colors.grey;
    }
  }

  Widget _buildCurrentMonthIndicator(int count) {
    final monthName = DateFormat('MMMM').format(_getSriLankaNow());
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryPurple.withOpacity(0.1), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryPurple.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: AppColors.primaryPurple),
              const SizedBox(width: 6),
              Text(
                '$monthName Releases:',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: count > 0 ? AppColors.primaryPurple : Colors.red,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  DateTime _getSriLankaNow() => tz.TZDateTime.now(tz.local);

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 8, left: 20, right: 20, bottom: 12),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.arrow_back, color: AppColors.headerTextDark, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.tune, color: AppColors.headerTextDark, size: 24),
                    onPressed: _showFilterPanel,
                  ),
                ],
              ),
              const Spacer(),
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
              _buildProfileAvatar(),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Release Antibiotics Details',
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
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by antibiotic or ward...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.primaryPurple, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _releasesCollection.orderBy('releaseDateTime', descending: true).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      final docs = snapshot.data?.docs ?? [];
                      final currentMonthCount = _computeCurrentMonthCount(docs);
                      final categoryFilterRow = _buildCategoryFilterRow(docs);
                      final filteredDocs = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return _filterRelease(data);
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
                                        Icon(Icons.inbox, size: 56, color: Colors.grey[300]),
                                        const SizedBox(height: 12),
                                        const Text('No release records found.', style: TextStyle(color: Colors.grey, fontSize: 14)),
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
                                            child: const Text('Clear Filters', style: TextStyle(fontSize: 12)),
                                          ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    itemCount: filteredDocs.length,
                                    itemBuilder: (context, index) => _buildReleaseCard(filteredDocs[index]),
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