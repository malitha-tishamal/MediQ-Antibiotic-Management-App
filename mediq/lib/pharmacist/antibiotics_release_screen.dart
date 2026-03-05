// lib/release_antibiotics_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:intl/intl.dart';

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
  final _antibioticController = TextEditingController();
  final _dosageController = TextEditingController();
  final _wardController = TextEditingController();
  final _pageNumberController = TextEditingController();
  final _itemCountController = TextEditingController();

  // Focus nodes
  final FocusNode _antibioticFocusNode = FocusNode();
  final FocusNode _wardFocusNode = FocusNode();

  // Hidden IDs
  String? _selectedAntibioticId;
  String? _selectedWardId;

  // Radio options
  String _datetimeOption = 'current'; // 'current' or 'manual'
  DateTime? _manualDateTime;
  String _stockType = 'msd'; // 'msd' or 'lp'

  // Book numbers list
  List<Map<String, dynamic>> _activeBooks = [];
  String? _selectedBookNumber;

  // Autocomplete suggestions
  List<Map<String, dynamic>> _antibioticSuggestions = [];
  List<Map<String, dynamic>> _wardSuggestions = [];
  Timer? _antibioticDebounce;
  Timer? _wardDebounce;

  // Suggestion visibility
  bool _showAntibioticSuggestions = false;
  bool _showWardSuggestions = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchActiveBooks();
    _antibioticController.addListener(_onAntibioticChanged);
    _wardController.addListener(_onWardChanged);
    _antibioticFocusNode.addListener(_onAntibioticFocusChanged);
    _wardFocusNode.addListener(_onWardFocusChanged);
  }

  @override
  void dispose() {
    _antibioticController.removeListener(_onAntibioticChanged);
    _wardController.removeListener(_onWardChanged);
    _antibioticFocusNode.removeListener(_onAntibioticFocusChanged);
    _wardFocusNode.removeListener(_onWardFocusChanged);
    _antibioticController.dispose();
    _dosageController.dispose();
    _wardController.dispose();
    _pageNumberController.dispose();
    _itemCountController.dispose();
    _antibioticFocusNode.dispose();
    _wardFocusNode.dispose();
    _antibioticDebounce?.cancel();
    _wardDebounce?.cancel();
    super.dispose();
  }

  void _onAntibioticFocusChanged() {
    if (!_antibioticFocusNode.hasFocus) {
      // Hide suggestions after a short delay to allow tap on suggestion
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_antibioticFocusNode.hasFocus) {
          setState(() => _showAntibioticSuggestions = false);
        }
      });
    } else {
      if (_antibioticController.text.isNotEmpty && _antibioticSuggestions.isNotEmpty) {
        setState(() => _showAntibioticSuggestions = true);
      }
    }
  }

  void _onWardFocusChanged() {
    if (!_wardFocusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_wardFocusNode.hasFocus) {
          setState(() => _showWardSuggestions = false);
        }
      });
    } else {
      if (_wardController.text.isNotEmpty && _wardSuggestions.isNotEmpty) {
        setState(() => _showWardSuggestions = true);
      }
    }
  }

  void _onAntibioticChanged() {
    _antibioticDebounce?.cancel();
    final query = _antibioticController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _antibioticSuggestions = [];
        _showAntibioticSuggestions = false;
      });
      return;
    }
    _antibioticDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final snapshot = await _firestore
            .collection('antibiotics')
            .where('name', isGreaterThanOrEqualTo: query)
            .where('name', isLessThanOrEqualTo: query + '\uf8ff')
            .limit(10)
            .get();
        final suggestions = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final dosages = data['dosages'] as List<dynamic>? ?? [];
          String firstDosage = '';
          if (dosages.isNotEmpty) {
            final first = dosages.first as Map<String, dynamic>;
            firstDosage = first['dosage'] ?? '';
          }
          return {
            'id': doc.id,
            'name': data['name'] ?? '',
            'dosage': firstDosage,
          };
        }).toList();
        setState(() {
          _antibioticSuggestions = suggestions;
          _showAntibioticSuggestions = suggestions.isNotEmpty && _antibioticFocusNode.hasFocus;
        });
      } catch (e) {
        debugPrint('Search antibiotic error: $e');
      }
    });
  }

  void _onWardChanged() {
    _wardDebounce?.cancel();
    final query = _wardController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _wardSuggestions = [];
        _showWardSuggestions = false;
      });
      return;
    }
    _wardDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final snapshot = await _firestore
            .collection('wards')
            .where('wardName', isGreaterThanOrEqualTo: query)
            .where('wardName', isLessThanOrEqualTo: query + '\uf8ff')
            .limit(10)
            .get();
        final suggestions = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'wardName': data['wardName'] ?? '',
          };
        }).toList();
        setState(() {
          _wardSuggestions = suggestions;
          _showWardSuggestions = suggestions.isNotEmpty && _wardFocusNode.hasFocus;
        });
      } catch (e) {
        debugPrint('Search ward error: $e');
      }
    });
  }

  void _selectAntibiotic(Map<String, dynamic> antibiotic) {
    setState(() {
      _selectedAntibioticId = antibiotic['id'];
      _antibioticController.text = antibiotic['name'];
      _dosageController.text = antibiotic['dosage'] ?? '';
      _antibioticSuggestions = [];
      _showAntibioticSuggestions = false;
    });
    _antibioticFocusNode.unfocus();
  }

  void _selectWard(Map<String, dynamic> ward) {
    setState(() {
      _selectedWardId = ward['id'];
      _wardController.text = ward['wardName'];
      _wardSuggestions = [];
      _showWardSuggestions = false;
    });
    _wardFocusNode.unfocus();
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
          _profileImageUrl = data['profileImageUrl'];
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
          .orderBy('bookNumber')
          .get();
      setState(() {
        _activeBooks = snapshot.docs.map((doc) {
          return {'id': doc.id, 'bookNumber': doc['bookNumber']};
        }).toList();
      });
    } catch (e) {
      debugPrint('Error fetching books: $e');
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
    if (_selectedAntibioticId == null) {
      _showSnackBar('Please select a valid antibiotic from suggestions', false);
      return;
    }
    if (_selectedWardId == null) {
      _showSnackBar('Please select a valid ward from suggestions', false);
      return;
    }

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

    final itemCount = int.tryParse(_itemCountController.text);
    if (itemCount == null || itemCount <= 0) {
      _showSnackBar('Item count must be a positive number', false);
      return;
    }

    try {
      await _firestore.collection('releases').add({
        'antibioticId': _selectedAntibioticId,
        'antibioticName': _antibioticController.text,
        'dosage': _dosageController.text,
        'wardId': _selectedWardId,
        'wardName': _wardController.text,
        'releaseDateTime': releaseDateTime,
        'pageNumber': _pageNumberController.text.trim(),
        'bookNumber': _selectedBookNumber ?? '',
        'itemCount': itemCount,
        'stockType': _stockType,
        'createdBy': _auth.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showSnackBar('Release recorded successfully!', true);
      _clearForm();
    } catch (e) {
      _showSnackBar('Failed to save release: $e', false);
    }
  }

  void _clearForm() {
    setState(() {
      _antibioticController.clear();
      _dosageController.clear();
      _wardController.clear();
      _pageNumberController.clear();
      _itemCountController.clear();
      _selectedAntibioticId = null;
      _selectedWardId = null;
      _datetimeOption = 'current';
      _manualDateTime = null;
      _stockType = 'msd';
      _selectedBookNumber = null;
      _antibioticSuggestions = [];
      _wardSuggestions = [];
      _showAntibioticSuggestions = false;
      _showWardSuggestions = false;
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 20),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.menu, color: AppColors.headerTextDark, size: 28),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _profileImageUrl == null
                      ? const LinearGradient(colors: [AppColors.primaryPurple, Color(0xFFB08FEB)])
                      : null,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPurple.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    )
                  ],
                  image: _profileImageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(_profileImageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _profileImageUrl == null
                    ? const Icon(Icons.person, size: 40, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userName,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.headerTextDark),
                  ),
                  Text(
                    'Logged in as: Pharmacist',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.headerTextDark),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 25),
          const Text(
            'Release Antibiotics',
            style: TextStyle(
                fontSize: 16,
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
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Antibiotic field with autocomplete
                                const Text('Select Antibiotic',
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                Stack(
                                  clipBehavior: Clip.none, // allows dropdown to overflow
                                  children: [
                                    TextFormField(
                                      controller: _antibioticController,
                                      focusNode: _antibioticFocusNode,
                                      decoration: InputDecoration(
                                        hintText: 'Type antibiotic name...',
                                        prefixIcon: const Icon(Icons.medication, color: AppColors.primaryPurple),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        filled: true,
                                        fillColor: Colors.white,
                                        suffixIcon: _antibioticController.text.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.clear, size: 18),
                                                onPressed: () {
                                                  _antibioticController.clear();
                                                  setState(() {
                                                    _selectedAntibioticId = null;
                                                    _dosageController.clear();
                                                    _antibioticSuggestions = [];
                                                  });
                                                },
                                              )
                                            : null,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please select an antibiotic';
                                        }
                                        return null;
                                      },
                                    ),
                                    // Suggestion list
                                    if (_showAntibioticSuggestions && _antibioticSuggestions.isNotEmpty)
                                      Positioned(
                                        top: 60,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          constraints: const BoxConstraints(maxHeight: 250),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.grey.withOpacity(0.3),
                                                blurRadius: 5,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                            border: Border.all(color: Colors.grey.shade300),
                                          ),
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            padding: EdgeInsets.zero,
                                            itemCount: _antibioticSuggestions.length,
                                            itemBuilder: (context, index) {
                                              final item = _antibioticSuggestions[index];
                                              return InkWell(
                                                onTap: () => _selectAntibiotic(item),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                  decoration: BoxDecoration(
                                                    border: Border(
                                                      bottom: BorderSide(color: Colors.grey.shade200),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              item['name'],
                                                              style: const TextStyle(
                                                                fontWeight: FontWeight.w600,
                                                                fontSize: 15,
                                                              ),
                                                            ),
                                                            if (item['dosage']?.isNotEmpty == true)
                                                              const SizedBox(height: 4),
                                                            if (item['dosage']?.isNotEmpty == true)
                                                              Text(
                                                                'Dosage: ${item['dosage']}',
                                                                style: TextStyle(
                                                                  color: AppColors.primaryPurple,
                                                                  fontSize: 13,
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                      const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Dosage (readonly)
                                const Text('Dosage', style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _dosageController,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.medical_information, color: AppColors.primaryPurple),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    filled: true,
                                    fillColor: Colors.grey.shade100,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Ward field with autocomplete
                                const Text('Release Ward', style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    TextFormField(
                                      controller: _wardController,
                                      focusNode: _wardFocusNode,
                                      decoration: InputDecoration(
                                        hintText: 'Type ward name...',
                                        prefixIcon: const Icon(Icons.local_hospital, color: AppColors.primaryPurple),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        filled: true,
                                        fillColor: Colors.white,
                                        suffixIcon: _wardController.text.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.clear, size: 18),
                                                onPressed: () {
                                                  _wardController.clear();
                                                  setState(() => _selectedWardId = null);
                                                },
                                              )
                                            : null,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please select a ward';
                                        }
                                        return null;
                                      },
                                    ),
                                    if (_showWardSuggestions && _wardSuggestions.isNotEmpty)
                                      Positioned(
                                        top: 60,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          constraints: const BoxConstraints(maxHeight: 250),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.grey.withOpacity(0.3),
                                                blurRadius: 5,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                            border: Border.all(color: Colors.grey.shade300),
                                          ),
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            padding: EdgeInsets.zero,
                                            itemCount: _wardSuggestions.length,
                                            itemBuilder: (context, index) {
                                              final item = _wardSuggestions[index];
                                              return InkWell(
                                                onTap: () => _selectWard(item),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                  decoration: BoxDecoration(
                                                    border: Border(
                                                      bottom: BorderSide(color: Colors.grey.shade200),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          item['wardName'],
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.w600,
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                      ),
                                                      const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Date & Time options
                                const Text('Select Date & Time', style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Radio<String>(
                                      value: 'current',
                                      groupValue: _datetimeOption,
                                      onChanged: (val) => setState(() => _datetimeOption = val!),
                                    ),
                                    const Text('Use current system date & time'),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Radio<String>(
                                      value: 'manual',
                                      groupValue: _datetimeOption,
                                      onChanged: (val) => setState(() => _datetimeOption = val!),
                                    ),
                                    const Text('Enter manually'),
                                  ],
                                ),
                                if (_datetimeOption == 'manual') ...[
                                  const SizedBox(height: 8),
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
                                      padding: const EdgeInsets.all(12),
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
                                const SizedBox(height: 16),

                                // Book number dropdown
                                const Text('Select Book Number (Active Only)',
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: _selectedBookNumber,
                                  items: _activeBooks.map((book) {
                                    return DropdownMenuItem<String>(
                                      value: book['bookNumber'],
                                      child: Text(book['bookNumber']),
                                    );
                                  }).toList(),
                                  onChanged: (val) => setState(() => _selectedBookNumber = val),
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.menu_book, color: AppColors.primaryPurple),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  hint: const Text('-- Select Book Number --'),
                                ),
                                const SizedBox(height: 16),

                                // Page number
                                const Text('Enter Page Number', style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _pageNumberController,
                                  keyboardType: TextInputType.text,
                                  decoration: InputDecoration(
                                    hintText: 'Enter page number',
                                    prefixIcon: const Icon(Icons.numbers, color: AppColors.primaryPurple),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Item count
                                const Text('Item Count', style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _itemCountController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'Enter item count',
                                    prefixIcon: const Icon(Icons.production_quantity_limits, color: AppColors.primaryPurple),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                                const SizedBox(height: 16),

                                // Stock type (MSD / LP)
                                const Text('Stock of Antibiotic', style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Radio<String>(
                                      value: 'msd',
                                      groupValue: _stockType,
                                      onChanged: (val) => setState(() => _stockType = val!),
                                    ),
                                    const Text('MSD'),
                                    const SizedBox(width: 24),
                                    Radio<String>(
                                      value: 'lp',
                                      groupValue: _stockType,
                                      onChanged: (val) => setState(() => _stockType = val!),
                                    ),
                                    const Text('LP'),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Submit & Clear buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _submitForm,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.successGreen,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: const Text('Update Database'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _clearForm,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(color: Colors.red),
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: const Text('Clear'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 30),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Static footer
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