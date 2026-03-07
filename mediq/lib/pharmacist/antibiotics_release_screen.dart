// lib/release_antibiotics_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

import '../auth/login_page.dart';
import 'pharmacist_drawer.dart';

class AppColors {
  static const Color primaryPurple = Color(0xFF9F7AEA);
  static const Color lightBackground = Color(0xFFF3F0FF);
  static const Color darkText = Color(0xFF333333);
  static const Color successGreen = Color(0xFF00C853);
  static const Color disabledColor = Color(0xFFE53935);
  static const Color headerGradientStart = Color.fromARGB(255, 235, 151, 225);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
  static const Color headerTextDark = Color(0xFF333333);
}

class ReleaseAntibioticsScreen extends StatefulWidget {
  const ReleaseAntibioticsScreen({super.key});

  @override
  State<ReleaseAntibioticsScreen> createState() =>
      _ReleaseAntibioticsScreenState();
}

class _ReleaseAntibioticsScreenState extends State<ReleaseAntibioticsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  // User data
  String _userName = '';
  String _userRole = '';
  String? _profileImageUrl;
  bool _isLoading = true;

  // Form fields
  String? _selectedAntibioticKey; // key like "antibioticId|dosageIndex"
  String _selectedAntibioticId = '';
  int? _selectedDosageIndex;
  String _dosage = '';
  String? _selectedWardId; // ward ID
  final _pageNumberController = TextEditingController();
  final _itemCountController = TextEditingController();

  // Radio options
  String _datetimeOption = 'current';
  DateTime? _manualDateTime;
  String _stockType = 'msd';

  // Book numbers list (active only)
  List<Map<String, dynamic>> _activeBooks = [];
  String? _selectedBookNumber;

  // ---------- Antibiotic search data ----------
  final List<Map<String, String>> _antibioticSearchList = [];
  final Map<String, Map<String, String>> _antibioticMap = {};

  // ---------- Ward search data ----------
  final List<Map<String, String>> _wardSearchList = [];
  final Map<String, String> _wardMap = {}; // id -> name

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchActiveBooks();
    _fetchAntibiotics();
    _fetchWards();
  }

  @override
  void dispose() {
    _pageNumberController.dispose();
    _itemCountController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      _redirectToLogin();
      return;
    }
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _userName = data['fullName'] ?? user.email?.split('@').first ?? 'User';
          _userRole = data['role'] ?? 'Pharmacist';
          _profileImageUrl = data['profileImageUrl']; // Drawer එකට අවශ්‍යයි
          _isLoading = false;
        });
      } else {
        setState(() {
          _userName = user.email?.split('@').first ?? 'User';
          _userRole = 'Pharmacist';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchActiveBooks() async {
    try {
      final snapshot = await _firestore
          .collection('book_numbers')
          .where('status', isEqualTo: 'active')
          .get();

      final books = snapshot.docs.map((doc) {
        final data = doc.data();
        final bookNumber = (data['bookNumber'] ?? '').toString().trim();
        final status = (data['status'] ?? '').toString().toLowerCase().trim();

        if (bookNumber.isEmpty || status != 'active') return null;

        return {
          'id': doc.id,
          'bookNumber': bookNumber,
        };
      }).where((book) => book != null).cast<Map<String, dynamic>>().toList();

      books.sort((a, b) => b['bookNumber'].compareTo(a['bookNumber']));

      setState(() {
        _activeBooks = books;
      });

      if (_activeBooks.isEmpty) {
        _showSnackBar('No active book numbers found.', false);
      }
    } catch (e) {
      debugPrint('Error fetching books: $e');
      _showSnackBar('Failed to load book numbers.', false);
    }
  }

  Future<void> _fetchAntibiotics() async {
    try {
      final snapshot = await _firestore.collection('antibiotics').get();
      final List<Map<String, dynamic>> tempList = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final name = data['name'] ?? 'Unknown';
        final dosages = data['dosages'] as List<dynamic>? ?? [];

        if (dosages.isEmpty) {
          final key = '${doc.id}|';
          tempList.add({
            'key': key,
            'antibioticId': doc.id,
            'antibioticName': name,
            'display': name,
            'dosage': '',
            'dosageIndex': -1,
          });
        } else {
          for (int i = 0; i < dosages.length; i++) {
            final dosageData = dosages[i] as Map<String, dynamic>;
            final dosage = dosageData['dosage'] ?? '';
            final key = '${doc.id}|$i';
            tempList.add({
              'key': key,
              'antibioticId': doc.id,
              'antibioticName': name,
              'display': '$name – $dosage',
              'dosage': dosage,
              'dosageIndex': i,
            });
          }
        }
      }

      tempList.sort((a, b) =>
          a['display'].toLowerCase().compareTo(b['display'].toLowerCase()));

      _antibioticMap.clear();
      _antibioticSearchList.clear();

      for (var entry in tempList) {
        final key = entry['key'];
        _antibioticMap[key] = {
          'antibioticId': entry['antibioticId'],
          'antibioticName': entry['antibioticName'],
          'dosage': entry['dosage'],
          'dosageIndex': entry['dosageIndex'].toString(),
        };
        _antibioticSearchList.add({
          'key': key,
          'display': entry['display'],
        });
      }

      setState(() {});
    } catch (e) {
      debugPrint('Error fetching antibiotics: $e');
    }
  }

  Future<void> _fetchWards() async {
    try {
      final snapshot = await _firestore.collection('wards').get();
      final List<Map<String, dynamic>> tempList = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final wardName = data['wardName'] ?? 'Unknown';
        tempList.add({
          'id': doc.id,
          'name': wardName,
        });
      }

      tempList.sort((a, b) =>
          a['name'].toLowerCase().compareTo(b['name'].toLowerCase()));

      _wardMap.clear();
      _wardSearchList.clear();

      for (var entry in tempList) {
        final id = entry['id'];
        final name = entry['name'];
        _wardMap[id] = name;
        _wardSearchList.add({
          'id': id,
          'display': name,
        });
      }

      setState(() {});
    } catch (e) {
      debugPrint('Error fetching wards: $e');
    }
  }

  void _redirectToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate antibiotic selection
    if (_selectedAntibioticKey == null) {
      _showSnackBar('Please select an antibiotic', false);
      return;
    }
    final selectedData = _antibioticMap[_selectedAntibioticKey!];
    if (selectedData == null) {
      _showSnackBar('Selected antibiotic data not found', false);
      return;
    }
    final antibioticId = selectedData['antibioticId'];
    final antibioticName = selectedData['antibioticName'];
    final dosageIndexStr = selectedData['dosageIndex'];
    if (antibioticId == null || antibioticName == null || dosageIndexStr == null) {
      _showSnackBar('Incomplete antibiotic data', false);
      return;
    }
    final dosageIndex = int.tryParse(dosageIndexStr);
    if (dosageIndex == null || dosageIndex < 0) {
      _showSnackBar('Invalid dosage selected', false);
      return;
    }

    // Validate ward selection
    if (_selectedWardId == null) {
      _showSnackBar('Please select a ward', false);
      return;
    }
    final wardName = _wardMap[_selectedWardId] ?? 'Unknown';

    // Determine date/time
    DateTime releaseDateTime;
    if (_datetimeOption == 'current') {
      releaseDateTime = DateTime.now();
    } else {
      if (_manualDateTime == null) {
        _showSnackBar('Please select manual date and time', false);
        return;
      }
      releaseDateTime = _manualDateTime!;
    }

    // Validate item count
    final itemCount = int.tryParse(_itemCountController.text);
    if (itemCount == null || itemCount <= 0) {
      _showSnackBar('Item count must be a positive number', false);
      return;
    }

    // Query main_stock for this antibiotic and dosage
    final stockQuery = await _firestore
        .collection('main_stock')
        .where('antibioticId', isEqualTo: antibioticId)
        .where('dosageIndex', isEqualTo: dosageIndex)
        .limit(1)
        .get();

    if (stockQuery.docs.isEmpty) {
      _showSnackBar('No stock entry found for this antibiotic and dosage', false);
      return;
    }

    final stockDoc = stockQuery.docs.first;
    final stockData = stockDoc.data() as Map<String, dynamic>;
    final currentQuantity = stockData['quantity'] as int? ?? 0;

    if (currentQuantity < itemCount) {
      _showSnackBar('Insufficient stock. Available: $currentQuantity', false);
      return;
    }

    // Use transaction to update stock and add release record
    try {
      await _firestore.runTransaction((transaction) async {
        // Re‑read the stock document inside transaction to ensure consistency
        final freshStockDoc = await transaction.get(stockDoc.reference);
        if (!freshStockDoc.exists) {
          throw Exception('Stock document no longer exists');
        }
        final freshData = freshStockDoc.data() as Map<String, dynamic>;
        final freshQuantity = freshData['quantity'] as int? ?? 0;
        if (freshQuantity < itemCount) {
          throw Exception('Insufficient stock (concurrent update)');
        }

        // Update stock quantity
        transaction.update(stockDoc.reference, {
          'quantity': freshQuantity - itemCount,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // Add release record
        final releaseRef = _firestore.collection('releases').doc();
        transaction.set(releaseRef, {
          'antibioticId': antibioticId,
          'antibioticName': antibioticName,
          'dosage': _dosage,
          'wardId': _selectedWardId,
          'wardName': wardName,
          'releaseDateTime': releaseDateTime,
          'pageNumber': _pageNumberController.text.trim(),
          'bookNumber': _selectedBookNumber ?? '',
          'itemCount': itemCount,
          'stockType': _stockType,
          'createdBy': _auth.currentUser?.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      _showSnackBar('Release recorded successfully!', true);
      _clearForm();
    } catch (e) {
      _showSnackBar('Failed to save release: $e', false);
    }
  }

  void _clearForm() {
    setState(() {
      _selectedAntibioticKey = null;
      _selectedAntibioticId = '';
      _selectedDosageIndex = null;
      _dosage = '';
      _selectedWardId = null;
      _pageNumberController.clear();
      _itemCountController.clear();
      _datetimeOption = 'current';
      _manualDateTime = null;
      _stockType = 'msd';
      _selectedBookNumber = null;
    });
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
        backgroundColor: isSuccess ? AppColors.successGreen : AppColors.disabledColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ----- Header (profile picture නැතිව, නම සහ role පමණක්) -----
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
                icon: const Icon(Icons.menu,
                    color: AppColors.headerTextDark, size: 24),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Center(
            child: Column(
              children: [
                Text(
                  _userName,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.headerTextDark),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Logged in as: Pharmacist',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.headerTextDark),
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

  void _handleNavTap(String title) {
    debugPrint('Drawer tapped: $title');
  }

  Future<void> _handleLogout() async {
    try {
      await _auth.signOut();
      _redirectToLogin();
    } catch (e) {
      _showSnackBar('Logout failed: $e', false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.lightBackground,
      drawer: PharmacistDrawer(
        userName: _userName,
        userRole: _userRole,
        profileImageUrl: _profileImageUrl,
        onNavTap: _handleNavTap,
        onLogout: _handleLogout,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
          : Stack(
              children: [
                SafeArea(
                  child: Column(
                    children: [
                      _buildHeader(context),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Select Antibiotic & Dosage',
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),

                                TypeAheadFormField<String>(
                                  textFieldConfiguration: TextFieldConfiguration(
                                    controller: TextEditingController(
                                      text: _selectedAntibioticKey != null
                                          ? _antibioticMap[_selectedAntibioticKey]!['antibioticName']! +
                                              ' – ' +
                                              _antibioticMap[_selectedAntibioticKey]!['dosage']!
                                          : '',
                                    ),
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(Icons.medication, color: AppColors.primaryPurple),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      filled: true,
                                      fillColor: Colors.white,
                                      hintText: '-- Type to search Antibiotic --',
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    ),
                                  ),
                                  suggestionsCallback: (pattern) {
                                    return _antibioticSearchList
                                        .where((item) => item['display']!
                                            .toLowerCase()
                                            .contains(pattern.toLowerCase()))
                                        .map((item) => item['display']!)
                                        .toList();
                                  },
                                  itemBuilder: (context, suggestion) {
                                    return ListTile(
                                      title: Text(suggestion),
                                    );
                                  },
                                  onSuggestionSelected: (suggestion) {
                                    final selectedItem = _antibioticSearchList.firstWhere(
                                        (item) => item['display'] == suggestion);
                                    setState(() {
                                      _selectedAntibioticKey = selectedItem['key'];
                                      final data = _antibioticMap[selectedItem['key']]!;
                                      _selectedAntibioticId = data['antibioticId']!;
                                      _dosage = data['dosage']!;
                                    });
                                  },
                                  validator: (value) {
                                    if (_selectedAntibioticKey == null) {
                                      return 'Please select an antibiotic';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 12),

                                const Text('Dosage', style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: TextEditingController(text: _dosage),
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.medical_information, color: AppColors.primaryPurple),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    filled: true,
                                    fillColor: Colors.grey.shade100,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                const Text('Release Ward', style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),

                                TypeAheadFormField<String>(
                                  textFieldConfiguration: TextFieldConfiguration(
                                    controller: TextEditingController(
                                      text: _selectedWardId != null
                                          ? _wardMap[_selectedWardId] ?? ''
                                          : '',
                                    ),
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(Icons.local_hospital, color: AppColors.primaryPurple),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      filled: true,
                                      fillColor: Colors.white,
                                      hintText: '-- Type to search Ward --',
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    ),
                                  ),
                                  suggestionsCallback: (pattern) {
                                    return _wardSearchList
                                        .where((item) => item['display']!
                                            .toLowerCase()
                                            .contains(pattern.toLowerCase()))
                                        .map((item) => item['display']!)
                                        .toList();
                                  },
                                  itemBuilder: (context, suggestion) {
                                    return ListTile(
                                      title: Text(suggestion),
                                    );
                                  },
                                  onSuggestionSelected: (suggestion) {
                                    final selectedItem = _wardSearchList.firstWhere(
                                        (item) => item['display'] == suggestion);
                                    setState(() {
                                      _selectedWardId = selectedItem['id'];
                                    });
                                  },
                                  validator: (value) {
                                    if (_selectedWardId == null) {
                                      return 'Please select a ward';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 10),

                                const Text('Select Date & Time', style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),

                                // Compact radio buttons with minimal spacing
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Radio<String>(
                                          value: 'current',
                                          groupValue: _datetimeOption,
                                          onChanged: (val) => setState(() => _datetimeOption = val!),
                                        ),
                                        const Text('Use current system date & time'),
                                      ],
                                    ),
                                    const SizedBox(height: 0),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Radio<String>(
                                          value: 'manual',
                                          groupValue: _datetimeOption,
                                          onChanged: (val) => setState(() => _datetimeOption = val!),
                                        ),
                                        const Text('Enter manually'),
                                      ],
                                    ),
                                  ],
                                ),

                                if (_datetimeOption == 'manual') ...[
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2030),
                                      );
                                      if (picked != null) {
                                        final time = await showTimePicker(
                                          context: context,
                                          initialTime: TimeOfDay.now(),
                                        );
                                        if (time != null) {
                                          setState(() {
                                            _manualDateTime = DateTime(
                                              picked.year, picked.month, picked.day,
                                              time.hour, time.minute,
                                            );
                                          });
                                        }
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_today, color: AppColors.primaryPurple),
                                          const SizedBox(width: 8),
                                          Text(
                                            _manualDateTime == null
                                                ? 'Pick date & time'
                                                : DateFormat('yyyy-MM-dd – HH:mm').format(_manualDateTime!),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),

                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Select Book Number',
                                              style: TextStyle(fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 6),
                                          DropdownButtonFormField<String>(
                                            value: _selectedBookNumber,
                                            items: _activeBooks.isEmpty
                                                ? [
                                                    DropdownMenuItem<String>(
                                                      value: null,
                                                      enabled: false,
                                                      child: Text(
                                                        'No active books',
                                                        style: TextStyle(color: Colors.grey[600]),
                                                      ),
                                                    )
                                                  ]
                                                : _activeBooks.map((book) {
                                                    return DropdownMenuItem<String>(
                                                      value: book['bookNumber'],
                                                      child: Text(book['bookNumber']),
                                                    );
                                                  }).toList(),
                                            onChanged: _activeBooks.isEmpty
                                                ? null
                                                : (val) => setState(() => _selectedBookNumber = val),
                                            decoration: InputDecoration(
                                              prefixIcon: const Icon(Icons.menu_book, color: AppColors.primaryPurple),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            ),
                                            hint: const Text('-- Select --'),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Enter Page Number', style: TextStyle(fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 6),
                                          TextFormField(
                                            controller: _pageNumberController,
                                            keyboardType: TextInputType.text,
                                            decoration: InputDecoration(
                                              hintText: 'Page number',
                                              prefixIcon: const Icon(Icons.numbers, color: AppColors.primaryPurple),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                const Text('Item Count', style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _itemCountController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'Enter item count',
                                    prefixIcon: const Icon(Icons.production_quantity_limits, color: AppColors.primaryPurple),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Item count is required';
                                    }
                                    final number = int.tryParse(value);
                                    if (number == null || number <= 0) {
                                      return 'Enter a valid positive number';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 10),

                                const Text('Stock of Antibiotic', style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Radio<String>(
                                      value: 'msd',
                                      groupValue: _stockType,
                                      onChanged: (val) => setState(() => _stockType = val!),
                                    ),
                                    const Text('MSD'),
                                    const SizedBox(width: 16),
                                    Radio<String>(
                                      value: 'lp',
                                      groupValue: _stockType,
                                      onChanged: (val) => setState(() => _stockType = val!),
                                    ),
                                    const Text('LP'),
                                  ],
                                ),
                                const SizedBox(height: 4),

                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _submitForm,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.successGreen,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: const Text('Update Database'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _clearForm,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(color: Colors.red),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: const Text('Clear'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
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