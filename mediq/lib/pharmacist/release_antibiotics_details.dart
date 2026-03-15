// release_antibiotics_details.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'pharmacist_drawer.dart';
import '../auth/login_page.dart';

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
}

class ReleaseAntibioticsDetails extends StatefulWidget {
  const ReleaseAntibioticsDetails({super.key});

  @override
  State<ReleaseAntibioticsDetails> createState() => _ReleaseAntibioticsDetailsState();
}

class _ReleaseAntibioticsDetailsState extends State<ReleaseAntibioticsDetails> {
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

  @override
  void initState() {
    super.initState();
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
      // Fetch wards
      final wardsSnapshot = await _wardsCollection.get();
      _wards = wardsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, 'name': data['wardName'] ?? 'Unknown'};
      }).toList();

      // Fetch antibiotics and build category map
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

  // ---------- Helper for consistent input decoration ----------
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

  // Show advanced filter bottom sheet
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
                            // Ward dropdown
                            DropdownButtonFormField<String>(
                              value: _selectedWardId,
                              decoration: _inputDecoration(
                                label: 'Ward',
                                prefixIcon: Icons.place,
                              ),
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

                            // Antibiotic dropdown
                            DropdownButtonFormField<String>(
                              value: _selectedAntibioticId,
                              decoration: _inputDecoration(
                                label: 'Antibiotic',
                                prefixIcon: Icons.medication,
                              ),
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

                            // Date range
                            const Text('Date Range', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: _startDate ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now(),
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
                                        initialDate: _endDate ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now(),
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

                            // Action buttons
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

  // ---- Category Filter Chips ----
  Widget _buildFilterChip(String label, int count, Color color, String filterValue) {
    final isSelected = _selectedCategory == filterValue;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = filterValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.transparent : color.withOpacity(0.3)),
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
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All', all, AppColors.primaryPurple, 'All'),
            _buildFilterChip('Access', access, AppColors.primaryPurple, 'Access'),
            _buildFilterChip('Watch', watch, AppColors.successGreen, 'Watch'),
            _buildFilterChip('Reserve', reserve, AppColors.warningOrange, 'Reserve'),
            _buildFilterChip('Other', other, Colors.grey, 'Other'),
          ],
        ),
      ),
    );
  }

  // Filter function (combines all filters)
  bool _filterRelease(Map<String, dynamic> data) {
    // Search
    if (_searchQuery.isNotEmpty) {
      final antibiotic = (data['antibioticName'] ?? '').toLowerCase();
      final ward = (data['wardName'] ?? '').toLowerCase();
      if (!antibiotic.contains(_searchQuery) && !ward.contains(_searchQuery)) {
        return false;
      }
    }

    // Category filter
    if (_selectedCategory != 'All') {
      final antibioticId = data['antibioticId'] ?? '';
      final category = _antibioticCategoryMap[antibioticId] ?? 'Other';
      if (_selectedCategory == 'Other') {
        if (category == 'Access' || category == 'Watch' || category == 'Reserve') return false;
      } else {
        if (category != _selectedCategory) return false;
      }
    }

    // Ward filter
    if (_selectedWardId != null && data['wardId'] != _selectedWardId) {
      return false;
    }

    // Antibiotic filter
    if (_selectedAntibioticId != null && data['antibioticId'] != _selectedAntibioticId) {
      return false;
    }

    // Date range
    if (_startDate != null || _endDate != null) {
      final releaseDate = (data['releaseDateTime'] as Timestamp?)?.toDate();
      if (releaseDate == null) return false;
      if (_startDate != null && releaseDate.isBefore(_startDate!)) return false;
      if (_endDate != null && releaseDate.isAfter(_endDate!.add(const Duration(days: 1)))) return false;
    }

    return true;
  }

  // Fetch user name by ID with caching
  Future<String> _getUserName(String userId) async {
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId]!;
    }
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final name = data['fullName'] ?? 'Unknown User';
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

  // ---- Edit Quantity Dialog ----
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

  // ---- Delete Confirmation ----
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

  // ---- Show Details Modal ----
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

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFF9F7FF)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: FutureBuilder<String>(
            future: _getUserName(createdBy),
            builder: (context, snapshot) {
              final releasedByName = snapshot.data ?? 'Loading...';
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
                          color: stockType == 'Main Store' ? Colors.green.shade50 : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          stockType,
                          style: TextStyle(
                            fontSize: 12,
                            color: stockType == 'Main Store' ? Colors.green.shade700 : Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _detailRow(Icons.medical_services, 'Dosage', dosage),
                  _detailRow(Icons.inventory, 'Quantity', quantity.toString()),
                  _detailRow(Icons.place, 'Ward', wardName),
                  _detailRow(Icons.menu_book, 'Book Number', bookNumber),
                  _detailRow(Icons.pages, 'Page Number', pageNumber),
                  _detailRow(Icons.access_time, 'Release Time', formattedDate),
                  _detailRow(Icons.person, 'Released by', releasedByName),
                  _detailRow(Icons.calendar_today, 'Created At', formattedCreated),
                  _detailRow(Icons.fingerprint, 'Document ID', docId),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _editRelease(docId, quantity);
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
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
                        ),
                      ),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primaryPurple),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
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

  // ---- Modern Compact Release Card (with edit/delete buttons) ----
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
    final stockType = data['stockType'] == 'msd' ? 'Main Store' : 'Return Store';
    final antibioticId = data['antibioticId'] ?? '';
    final category = _antibioticCategoryMap[antibioticId] ?? 'Other';
    final Color categoryColor = _getCategoryColor(category);
    final createdBy = data['createdBy'] ?? '';

    return GestureDetector(
      onTap: () => _showDetailsModal(data, doc.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF9F7FF)],
          ),
          boxShadow: [
            BoxShadow(
              color: categoryColor.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 3),
              spreadRadius: -2,
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
                  left: BorderSide(color: categoryColor, width: 5),
                ),
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: name + stock type + edit/delete
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
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: stockType == 'Main Store' ? Colors.green.shade50 : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          stockType == 'Main Store' ? 'MSD' : 'LP',
                          style: TextStyle(
                            fontSize: 10,
                            color: stockType == 'Main Store' ? Colors.green.shade700 : Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.orange, size: 16),
                              onPressed: () => _editRelease(doc.id, quantity),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                              onPressed: () => _confirmDelete(doc.id, antibioticName),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Category chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: categoryColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(color: categoryColor, fontWeight: FontWeight.w600, fontSize: 10),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Info row: dosage, quantity, ward
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      _infoChipCompact(Icons.medical_services, 'Dosage: $dosage'),
                      _infoChipCompact(Icons.inventory, 'Qty: $quantity'),
                      _infoChipCompact(Icons.place, wardName),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Book and page
                  Wrap(
                    spacing: 10,
                    children: [
                      _infoChipCompact(Icons.menu_book, 'Book: $bookNumber'),
                      _infoChipCompact(Icons.pages, 'Page: $pageNumber'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, thickness: 0.5),
                  const SizedBox(height: 6),
                  // Footer: date, ID, and released by
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 12, color: Colors.grey),
                          const SizedBox(width: 2),
                          Text(formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.fingerprint, size: 12, color: Colors.grey),
                          const SizedBox(width: 2),
                          Text('ID: ${doc.id.substring(0, 4)}...', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Released by
                  FutureBuilder<String>(
                    future: _getUserName(createdBy),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Row(
                          children: [
                            Icon(Icons.person, size: 12, color: Colors.grey),
                            SizedBox(width: 2),
                            Text('Released by: Loading...', style: TextStyle(color: Colors.grey, fontSize: 10)),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          const Icon(Icons.person, size: 12, color: Colors.grey),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              'Released by: ${snapshot.data ?? 'Unknown'}',
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
    );
  }

  // Compact info chip helper
  Widget _infoChipCompact(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.primaryPurple),
        const SizedBox(width: 2),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
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
          BoxShadow(color: Color(0x10000000), blurRadius: 15, offset: Offset(0, 5))
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
                icon: const Icon(Icons.arrow_back, color: AppColors.headerTextDark, size: 24),
                onPressed: () => Navigator.of(context).pop(),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.tune, color: AppColors.headerTextDark, size: 24),
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
                  'Logged in as: Pharmacist',
                  style: TextStyle(fontSize: 12, color: AppColors.headerTextDark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Release Antibiotics',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.headerTextDark),
          ),
        ],
      ),
    );
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
                // Persistent search bar
                Container(
                  margin: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 4),
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
                      hintText: 'Search by antibiotic or ward...',
                      prefixIcon: Icon(Icons.search, color: AppColors.primaryPurple),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 15),
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

                      // Category filter row (requires docs to compute counts)
                      final categoryFilterRow = _buildCategoryFilterRow(docs);

                      final filteredDocs = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return _filterRelease(data);
                      }).toList();

                      return Column(
                        children: [
                          categoryFilterRow,
                          Expanded(
                            child: filteredDocs.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.inbox, size: 64, color: Colors.grey[300]),
                                        const SizedBox(height: 16),
                                        const Text('No release records found.', style: TextStyle(color: Colors.grey)),
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
                                    key: const PageStorageKey('release_list'),
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    itemCount: filteredDocs.length,
                                    itemBuilder: (context, index) {
                                      return _buildReleaseCard(filteredDocs[index]);
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
          // Footer
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