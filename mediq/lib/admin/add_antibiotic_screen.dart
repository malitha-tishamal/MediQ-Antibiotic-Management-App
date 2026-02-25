// add_antibiotic_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppColors {
  static const Color primaryPurple = Color(0xFF9F7AEA);
  static const Color lightBackground = Color(0xFFF3F0FF);
  static const Color darkText = Color(0xFF333333);
  static const Color successGreen = Color(0xFF00C853);
  static const Color headerGradientStart = Color.fromARGB(255, 235, 151, 225);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
  static const Color headerTextDark = Color(0xFF333333);
}

class AddAntibioticScreen extends StatefulWidget {
  final String? antibioticId; // for editing

  const AddAntibioticScreen({super.key, this.antibioticId});

  @override
  State<AddAntibioticScreen> createState() => _AddAntibioticScreenState();
}

class _AddAntibioticScreenState extends State<AddAntibioticScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedCategory;

  final List<Map<String, TextEditingController>> _dosageControllers = [];
  final CollectionReference _antibioticsCollection =
      FirebaseFirestore.instance.collection('antibiotics');

  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _currentUserName = 'Loading...';
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserDetails();
    _addDosageField();

    // If editing, load existing antibiotic
    if (widget.antibioticId != null) {
      _loadAntibioticForEdit(widget.antibioticId!);
    }
  }

  Future<void> _fetchCurrentUserDetails() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            _currentUserName = data['fullName'] ?? user.email?.split('@').first ?? 'User';
            _profileImageUrl = data['profileImageUrl'];
          });
        }
      } catch (e) {
        debugPrint('Error fetching user: $e');
      }
    }
  }

  Future<void> _loadAntibioticForEdit(String id) async {
    final doc = await _antibioticsCollection.doc(id).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      _nameController.text = data['name'] ?? '';
      _selectedCategory = data['category'];
      _dosageControllers.clear();
      final dosages = data['dosages'] as List<dynamic>? ?? [];
      if (dosages.isEmpty) {
        _addDosageField();
      } else {
        for (var d in dosages) {
          _dosageControllers.add({
            'dosage': TextEditingController(text: d['dosage']),
            'srNumber': TextEditingController(text: d['srNumber']),
          });
        }
      }
      setState(() {});
    }
  }

  void _addDosageField() {
    setState(() {
      _dosageControllers.add({
        'dosage': TextEditingController(),
        'srNumber': TextEditingController(),
      });
    });
  }

  void _removeDosageField(int index) {
    setState(() {
      _dosageControllers.removeAt(index);
    });
  }

  Future<void> _saveAntibiotic() async {
    if (_formKey.currentState!.validate()) {
      bool hasDosage = _dosageControllers.any(
          (pair) => pair['dosage']!.text.isNotEmpty && pair['srNumber']!.text.isNotEmpty);
      if (!hasDosage) {
        _showSnackBar('Please add at least one dosage and SR number', false);
        return;
      }

      List<Map<String, String>> dosages = [];
      for (var pair in _dosageControllers) {
        if (pair['dosage']!.text.isNotEmpty && pair['srNumber']!.text.isNotEmpty) {
          dosages.add({
            'dosage': pair['dosage']!.text.trim(),
            'srNumber': pair['srNumber']!.text.trim(),
          });
        }
      }

      try {
        if (widget.antibioticId != null) {
          // Update existing
          await _antibioticsCollection.doc(widget.antibioticId).update({
            'name': _nameController.text.trim(),
            'category': _selectedCategory,
            'dosages': dosages,
            'createdAt': FieldValue.serverTimestamp(),
          });
          _showSnackBar('Antibiotic updated successfully', true);
          // Stay on same screen, keep the updated data
        } else {
          // Add new
          await _antibioticsCollection.add({
            'name': _nameController.text.trim(),
            'category': _selectedCategory,
            'dosages': dosages,
            'createdAt': FieldValue.serverTimestamp(),
          });
          _showSnackBar('Antibiotic added successfully', true);
          // Clear form to allow adding another antibiotic
          _clearForm();
        }
        // Removed Navigator.pop() to prevent auto-back
      } catch (e) {
        _showSnackBar('Failed to save antibiotic: $e', false);
      }
    }
  }

  void _clearForm() {
    _nameController.clear();
    setState(() {
      _selectedCategory = null;
      _dosageControllers.clear();
      _addDosageField(); // add one empty field
    });
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
        backgroundColor: isSuccess ? AppColors.successGreen : Colors.red,
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
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Color(0x10000000), blurRadius: 15, offset: Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.headerTextDark, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ]),
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
                  boxShadow: [BoxShadow(color: AppColors.primaryPurple.withOpacity(0.4), blurRadius: 10, offset: Offset(0, 3))],
                  image: _profileImageUrl != null ? DecorationImage(image: NetworkImage(_profileImageUrl!), fit: BoxFit.cover) : null,
                ),
                child: _profileImageUrl == null ? const Icon(Icons.person, size: 40, color: Colors.white) : null,
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_currentUserName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.headerTextDark)),
                  const Text('Logged in as: Administrator', style: TextStyle(fontSize: 14, color: AppColors.headerTextDark)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 25),
          Text(
            widget.antibioticId != null ? 'Edit Antibiotic' : 'Add New Antibiotic',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.headerTextDark),
          ),
        ],
      ),
    );
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
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Antibiotic Name
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Antibiotic Name',
                              hintText: 'eg: Amoxicillin',
                              prefixIcon: Icon(Icons.medication, color: AppColors.primaryPurple),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (value) => value == null || value.isEmpty ? 'Name is required' : null,
                          ),
                          const SizedBox(height: 16),

                          // Category Dropdown
                          DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            decoration: InputDecoration(
                              labelText: 'Category',
                              prefixIcon: Icon(Icons.category, color: AppColors.primaryPurple),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: ['Access', 'Watch', 'Reserve', 'Other'].map((category) {
                              return DropdownMenuItem(value: category, child: Text(category));
                            }).toList(),
                            onChanged: (value) => setState(() => _selectedCategory = value),
                            validator: (value) => value == null ? 'Please select a category' : null,
                          ),
                          const SizedBox(height: 16),

                          // Dynamic Dosage & SR fields
                          const Text('Dosage & SR Number', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _dosageControllers.length,
                            itemBuilder: (context, index) {
                              final dosageCtrl = _dosageControllers[index]['dosage']!;
                              final srCtrl = _dosageControllers[index]['srNumber']!;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: dosageCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'Dosage',
                                          hintText: 'eg: 10mg',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        validator: (value) {
                                          if (index == 0 && (value == null || value.isEmpty)) return 'Dosage is required';
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: srCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'SR Number',
                                          hintText: 'eg: 12345',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        validator: (value) {
                                          if (index == 0 && (value == null || value.isEmpty)) return 'SR Number is required';
                                          return null;
                                        },
                                      ),
                                    ),
                                    if (index > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8.0),
                                        child: IconButton(
                                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                                          onPressed: () => _removeDosageField(index),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                          Center(
                            child: TextButton.icon(
                              onPressed: _addDosageField,
                              icon: Icon(Icons.add_circle, color: AppColors.primaryPurple),
                              label: const Text('Add Another Dosage'),
                              style: TextButton.styleFrom(foregroundColor: AppColors.primaryPurple),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Submit & Clear
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _saveAntibiotic,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryPurple,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Submit', style: TextStyle(fontSize: 16, color: Colors.white)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _clearForm,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primaryPurple,
                                    side: const BorderSide(color: AppColors.primaryPurple),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Clear', style: TextStyle(fontSize: 16)),
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

  @override
  void dispose() {
    _nameController.dispose();
    for (var pair in _dosageControllers) {
      pair['dosage']!.dispose();
      pair['srNumber']!.dispose();
    }
    super.dispose();
  }
}