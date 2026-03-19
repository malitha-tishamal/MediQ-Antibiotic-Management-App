// add_ward_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppColors {
  static const Color primaryPurple = Color(0xFF9F7AEA);
  static const Color lightBackground = Color(0xFFF3F0FF);
  static const Color successGreen = Color(0xFF00C853);
  static const Color headerGradientStart = Color.fromARGB(255, 235, 151, 225);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
  static const Color headerTextDark = Color(0xFF333333);
  static const Color inputBorder = Color(0xFFE0E0E0); // Added for consistency
  static const Color darkText = Color(0xFF333333);
}

class AddWardScreen extends StatefulWidget {
  final String? wardId; // for editing (optional)
  const AddWardScreen({super.key, this.wardId});

  @override
  State<AddWardScreen> createState() => _AddWardScreenState();
}

class _AddWardScreenState extends State<AddWardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _wardNameController = TextEditingController();
  final _teamController = TextEditingController();
  final _managedByController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;

  final CollectionReference _wardsCollection = FirebaseFirestore.instance.collection('wards');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _currentUserName = 'Loading...';
  String? _profileImageUrl;

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

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserDetails();
    if (widget.wardId != null) {
      _loadWardForEdit(widget.wardId!);
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

  Future<void> _loadWardForEdit(String id) async {
    final doc = await _wardsCollection.doc(id).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      _wardNameController.text = data['wardName'] ?? '';
      _teamController.text = data['team'] ?? '';
      _managedByController.text = data['managedBy'] ?? '';
      _selectedCategory = data['category'];
      _descriptionController.text = data['description'] ?? '';
      setState(() {});
    }
  }

  Future<void> _saveWard() async {
    if (_formKey.currentState!.validate()) {
      try {
        if (widget.wardId != null) {
          // Update existing
          await _wardsCollection.doc(widget.wardId).update({
            'wardName': _wardNameController.text.trim(),
            'team': _teamController.text.trim(),
            'managedBy': _managedByController.text.trim(),
            'category': _selectedCategory,
            'description': _descriptionController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          _showSnackBar('Ward updated successfully', true);
          // Stay on same screen, keep the updated data
        } else {
          // Add new
          await _wardsCollection.add({
            'wardName': _wardNameController.text.trim(),
            'team': _teamController.text.trim(),
            'managedBy': _managedByController.text.trim(),
            'category': _selectedCategory,
            'description': _descriptionController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
          });
          _showSnackBar('Ward added successfully', true);
          // Clear form to allow adding another ward
          _clearForm();
        }
        // No navigation - stay on this screen
      } catch (e) {
        _showSnackBar('Failed to save ward: $e', false);
      }
    }
  }

  void _clearForm() {
    _wardNameController.clear();
    _teamController.clear();
    _managedByController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedCategory = null;
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
        boxShadow: [BoxShadow(color: Color(0x10000000), blurRadius: 15, offset: Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.headerTextDark, size: 28),
                onPressed: () => Navigator.of(context).pop(),
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
                  boxShadow: [BoxShadow(color: AppColors.primaryPurple.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 3))],
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
            widget.wardId != null ? 'Edit Ward' : 'Add New Ward',
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
      body: SafeArea(
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
                      // Ward Name with modern styling
                      TextFormField(
                        controller: _wardNameController,
                        decoration: _inputDecoration(
                          label: 'Ward Name',
                          hintText: 'e.g., 3 & 5 (Surgical prof.)',
                          prefixIcon: Icons.place,
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Ward name is required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Team (Managed By Team)
                      TextFormField(
                        controller: _teamController,
                        decoration: _inputDecoration(
                          label: 'Managed By (Team)',
                          hintText: 'Team',
                          prefixIcon: Icons.group,
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Team is required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Managed By (Doctor's Name)
                      TextFormField(
                        controller: _managedByController,
                        decoration: _inputDecoration(
                          label: 'Managed By (Doctor\'s Name)',
                          hintText: 'Dr. Name',
                          prefixIcon: Icons.person,
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Doctor name is required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Category Dropdown with container border
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Category',
                            style: TextStyle(
                              color: AppColors.darkText,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.inputBorder, width: 1.5),
                              color: Colors.white,
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              ),
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primaryPurple),
                              style: const TextStyle(color: AppColors.darkText, fontSize: 15, fontWeight: FontWeight.w500),
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              items: [
                                'Pediatrics',
                                'Medicine',
                                'ICU',
                                'Surgery',
                                'Medicine Subspecialty',
                                'Surgery Subspecialty',
                              ].map((category) {
                                return DropdownMenuItem(
                                  value: category,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.category, color: AppColors.primaryPurple, size: 18),
                                      const SizedBox(width: 10),
                                      Text(category),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) => setState(() => _selectedCategory = value),
                              validator: (value) => value == null ? 'Please select a category' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: _inputDecoration(
                          label: 'Description',
                          hintText: 'Any Notice Details',
                          prefixIcon: Icons.description,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _saveWard,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryPurple,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                widget.wardId != null ? 'Update Ward' : 'Add Ward',
                                style: const TextStyle(fontSize: 16, color: Colors.white),
                              ),
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
    );
  }

  @override
  void dispose() {
    _wardNameController.dispose();
    _teamController.dispose();
    _managedByController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}