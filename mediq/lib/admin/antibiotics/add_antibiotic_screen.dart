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
  static const Color inputBorder = Color(0xFFE0E0E0);
}

class AddAntibioticScreen extends StatefulWidget {
  final String? antibioticId;

  const AddAntibioticScreen({super.key, this.antibioticId});

  @override
  State<AddAntibioticScreen> createState() => _AddAntibioticScreenState();
}

class _AddAntibioticScreenState extends State<AddAntibioticScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedCategory;

  final List<String> _unitOptions = [
    'mg - Milligram',
    'g - Gram',
    'mcg - Microgram',
    'U - Unit',
    'IU - International Unit',
    'mL - Milliliter',
    'cc - Cubic Centimeter',
    'IV - Intravenous',
    'mg/kg - Milligram per Kilogram',
  ];

  final List<Map<String, dynamic>> _dosageRows = [];
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

    if (widget.antibioticId != null) {
      _loadAntibioticForEdit(widget.antibioticId!);
    }
  }

  // ---------- Helper: map any unit string to a valid option ----------
  String _mapUnitToOption(String unit) {
    final lowerUnit = unit.toLowerCase().trim();
    for (final option in _unitOptions) {
      final optionLower = option.toLowerCase();
      if (optionLower.contains(lowerUnit) || lowerUnit.contains(optionLower)) {
        return option;
      }
    }
    if (lowerUnit == 'mg') return 'mg - Milligram';
    if (lowerUnit == 'milligram') return 'mg - Milligram';
    if (lowerUnit == 'g') return 'g - Gram';
    if (lowerUnit == 'gram') return 'g - Gram';
    if (lowerUnit == 'mcg' || lowerUnit == 'microgram') return 'mcg - Microgram';
    if (lowerUnit == 'ml' || lowerUnit == 'milliliter') return 'mL - Milliliter';
    if (lowerUnit == 'cc') return 'cc - Cubic Centimeter';
    if (lowerUnit == 'u' || lowerUnit == 'unit') return 'U - Unit';
    if (lowerUnit == 'iu' || lowerUnit == 'international unit') return 'IU - International Unit';
    return _unitOptions.first;
  }

  Map<String, String> _parseDosage(String dosageStr) {
    if (dosageStr.isEmpty) return {'value': '', 'unit': ''};
    final regex = RegExp(r'(\d+(?:\.\d+)?)\s*([a-zA-Z/%]+)');
    final match = regex.firstMatch(dosageStr);
    if (match != null) {
      final value = match.group(1)!;
      final unit = match.group(2)!;
      final fullUnit = _mapUnitToOption(unit);
      return {'value': value, 'unit': fullUnit};
    }
    final lastSpace = dosageStr.lastIndexOf(' ');
    if (lastSpace != -1) {
      final value = dosageStr.substring(0, lastSpace).trim();
      final unit = dosageStr.substring(lastSpace + 1).trim();
      return {'value': value, 'unit': _mapUnitToOption(unit)};
    }
    return {'value': dosageStr, 'unit': _unitOptions.first};
  }

  // ---------- New: Text Field builder matching LoginPage style ----------
  Widget _buildTextField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.darkText,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPurple.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.inputBorder.withOpacity(0.8), fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
              prefixIcon: Container(
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: Colors.grey.shade300, width: 1.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(icon, color: AppColors.primaryPurple, size: 20),
                ),
              ),
              border: InputBorder.none,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primaryPurple.withOpacity(0.1), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  // ---------- New: Dropdown Field builder matching LoginPage style ----------
  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.darkText,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPurple.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              hintText: 'Select $label',
              hintStyle: TextStyle(color: AppColors.inputBorder.withOpacity(0.8), fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
              prefixIcon: Container(
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: Colors.grey.shade300, width: 1.5)),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(Icons.category, color: AppColors.primaryPurple, size: 20),
                ),
              ),
              border: InputBorder.none,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primaryPurple.withOpacity(0.1), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
            ),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primaryPurple),
            style: const TextStyle(color: AppColors.darkText, fontSize: 15, fontWeight: FontWeight.w500),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(12),
            items: items.map((item) {
              return DropdownMenuItem(value: item, child: Text(item));
            }).toList(),
            onChanged: onChanged,
            validator: validator,
          ),
        ),
      ],
    );
  }

  // ---------- User details ----------
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

  // ---------- Load antibiotic for editing ----------
  Future<void> _loadAntibioticForEdit(String id) async {
    final doc = await _antibioticsCollection.doc(id).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      _nameController.text = data['name'] ?? '';
      _selectedCategory = data['category'];
      _dosageRows.clear();
      final dosages = data['dosages'] as List<dynamic>? ?? [];
      if (dosages.isEmpty) {
        _addDosageField();
      } else {
        for (var d in dosages) {
          final dosageStr = d['dosage'] ?? '';
          final srNumber = d['srNumber'] ?? '';
          final parsed = _parseDosage(dosageStr);
          final value = parsed['value']!;
          final unit = parsed['unit']!;
          _dosageRows.add({
            'valueCtrl': TextEditingController(text: value),
            'unit': unit,
            'srCtrl': TextEditingController(text: srNumber),
          });
        }
      }
      setState(() {});
    }
  }

  void _addDosageField() {
    setState(() {
      _dosageRows.add({
        'valueCtrl': TextEditingController(),
        'unit': _unitOptions.first,
        'srCtrl': TextEditingController(),
      });
    });
  }

  void _removeDosageField(int index) {
    setState(() {
      _dosageRows[index]['valueCtrl'].dispose();
      _dosageRows[index]['srCtrl'].dispose();
      _dosageRows.removeAt(index);
    });
  }

  Future<void> _saveAntibiotic() async {
    if (_formKey.currentState!.validate()) {
      bool hasDosage = _dosageRows.any(
          (row) => row['valueCtrl'].text.isNotEmpty && row['srCtrl'].text.isNotEmpty);
      if (!hasDosage) {
        _showSnackBar('Please add at least one dosage and SR number', false);
        return;
      }

      List<Map<String, String>> dosages = [];
      for (var row in _dosageRows) {
        String value = row['valueCtrl'].text.trim();
        String unit = row['unit'];
        String sr = row['srCtrl'].text.trim();
        if (value.isNotEmpty && sr.isNotEmpty) {
          dosages.add({
            'dosage': '$value $unit',
            'srNumber': sr,
          });
        }
      }

      try {
        if (widget.antibioticId != null) {
          await _antibioticsCollection.doc(widget.antibioticId).update({
            'name': _nameController.text.trim(),
            'category': _selectedCategory,
            'dosages': dosages,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          _showSnackBar('Antibiotic updated successfully', true);
        } else {
          await _antibioticsCollection.add({
            'name': _nameController.text.trim(),
            'category': _selectedCategory,
            'dosages': dosages,
            'createdAt': FieldValue.serverTimestamp(),
          });
          _showSnackBar('Antibiotic added successfully', true);
          _clearForm();
        }
      } catch (e) {
        _showSnackBar('Failed to save antibiotic: $e', false);
      }
    }
  }

  void _clearForm() {
    _nameController.clear();
    setState(() {
      _selectedCategory = null;
      for (var row in _dosageRows) {
        row['valueCtrl'].dispose();
        row['srCtrl'].dispose();
      }
      _dosageRows.clear();
      _addDosageField();
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
              IconButton(
                icon: const Icon(Icons.arrow_back,
                    color: AppColors.headerTextDark, size: 28),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
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
                    'Logged in as: Administrator',
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
          const SizedBox(height: 20),
          Text(
            widget.antibioticId != null ? 'Edit Antibiotic' : 'Add New Antibiotic',
            style: const TextStyle(
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
                          // Antibiotic Name (New style)
                          _buildTextField(
                            label: 'Antibiotic Name',
                            hint: 'eg: Amoxicillin',
                            icon: Icons.medication,
                            controller: _nameController,
                            validator: (value) => value == null || value.isEmpty ? 'Name is required' : null,
                          ),
                          const SizedBox(height: 16),

                          // Category Dropdown (New style)
                          _buildDropdownField(
                            label: 'Category',
                            value: _selectedCategory,
                            items: ['Access', 'Watch', 'Reserve', 'Other'],
                            onChanged: (value) => setState(() => _selectedCategory = value),
                            validator: (value) => value == null ? 'Please select a category' : null,
                          ),
                          const SizedBox(height: 16),

                          const Text('Dosage & SR Number', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),

                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _dosageRows.length,
                            itemBuilder: (context, index) {
                              final row = _dosageRows[index];
                              final valueCtrl = row['valueCtrl'] as TextEditingController;
                              final srCtrl = row['srCtrl'] as TextEditingController;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row 1: Dosage and SR Number
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: _buildTextField(
                                            label: 'Dosage',
                                            hint: 'e.g., 10',
                                            icon: Icons.numbers,
                                            controller: valueCtrl,
                                            keyboardType: TextInputType.number,
                                            validator: (value) {
                                              if (index == 0 && (value == null || value.isEmpty))
                                                return 'Dosage is required';
                                              return null;
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 2,
                                          child: _buildTextField(
                                            label: 'SR Number',
                                            hint: 'e.g., 12345',
                                            icon: Icons.qr_code,
                                            controller: srCtrl,
                                            validator: (value) {
                                              if (index == 0 && (value == null || value.isEmpty))
                                                return 'SR Number is required';
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
                                    const SizedBox(height: 12),
                                    // Row 2: Unit dropdown
                                    _buildDropdownField(
                                      label: 'Unit',
                                      value: row['unit'],
                                      items: _unitOptions,
                                      onChanged: (newUnit) {
                                        setState(() {
                                          row['unit'] = newUnit!;
                                        });
                                      },
                                      validator: (value) {
                                        if (index == 0 && value == null) return 'Unit is required';
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          Center(
                            child: TextButton.icon(
                              onPressed: _addDosageField,
                              icon: const Icon(Icons.add_circle, color: AppColors.primaryPurple),
                              label: const Text('Add Another Dosage'),
                              style: TextButton.styleFrom(foregroundColor: AppColors.primaryPurple),
                            ),
                          ),
                          const SizedBox(height: 24),

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
    for (var row in _dosageRows) {
      row['valueCtrl'].dispose();
      row['srCtrl'].dispose();
    }
    super.dispose();
  }
}