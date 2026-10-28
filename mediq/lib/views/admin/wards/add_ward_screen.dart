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
  static const Color inputBorder = Color(0xFFE0E0E0);
  static const Color darkText = Color(0xFF333333);
}

class AddWardScreen extends StatefulWidget {
  final String? wardId;
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

  final CollectionReference _wardsCollection =
      FirebaseFirestore.instance.collection('wards');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _currentUserName = 'Loading...';
  String? _profileImageUrl;

  // ---------- New: Text Field builder matching LoginPage style ----------
  Widget _buildTextField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
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
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                  color: AppColors.inputBorder.withOpacity(0.8), fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 16.0, horizontal: 20.0),
              prefixIcon: Container(
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  border: Border(
                      right: BorderSide(color: Colors.grey.shade300, width: 1.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(icon, color: AppColors.primaryPurple, size: 20),
                ),
              ),
              border: InputBorder.none,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: AppColors.primaryPurple.withOpacity(0.1), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primaryPurple, width: 2),
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
              hintStyle: TextStyle(
                  color: AppColors.inputBorder.withOpacity(0.8), fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 16.0, horizontal: 20.0),
              prefixIcon: Container(
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  border: Border(
                      right: BorderSide(color: Colors.grey.shade300, width: 1.5)),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(Icons.category,
                      color: AppColors.primaryPurple, size: 20),
                ),
              ),
              border: InputBorder.none,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: AppColors.primaryPurple.withOpacity(0.1), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primaryPurple, width: 2),
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
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.primaryPurple),
            style: const TextStyle(
                color: AppColors.darkText,
                fontSize: 15,
                fontWeight: FontWeight.w500),
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
        final doc =
            await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
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
          await _wardsCollection.doc(widget.wardId).update({
            'wardName': _wardNameController.text.trim(),
            'team': _teamController.text.trim(),
            'managedBy': _managedByController.text.trim(),
            'category': _selectedCategory,
            'description': _descriptionController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          _showSnackBar('Ward updated successfully', true);
        } else {
          await _wardsCollection.add({
            'wardName': _wardNameController.text.trim(),
            'team': _teamController.text.trim(),
            'managedBy': _managedByController.text.trim(),
            'category': _selectedCategory,
            'description': _descriptionController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
          });
          _showSnackBar('Ward added successfully', true);
          _clearForm();
        }
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
            Icon(isSuccess ? Icons.check_circle : Icons.error,
                color: Colors.white, size: 20),
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
            widget.wardId != null ? 'Edit Ward' : 'Add New Ward',
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
        child:
            const Icon(Icons.person, color: AppColors.primaryPurple, size: 48),
      );
    }
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
                      // Ward Name
                      _buildTextField(
                        label: 'Ward Name',
                        hint: 'e.g., 3 & 5 (Surgical prof.)',
                        icon: Icons.place,
                        controller: _wardNameController,
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Ward name is required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Team
                      _buildTextField(
                        label: 'Managed By (Team)',
                        hint: 'Team',
                        icon: Icons.group,
                        controller: _teamController,
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Team is required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Managed By (Doctor)
                      _buildTextField(
                        label: 'Managed By (Doctor\'s Name)',
                        hint: 'Dr. Name',
                        icon: Icons.person,
                        controller: _managedByController,
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Doctor name is required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Category Dropdown
                      _buildDropdownField(
                        label: 'Category',
                        value: _selectedCategory,
                        items: [
                          'Pediatrics',
                          'Medicine',
                          'ICU',
                          'Surgery',
                          'Medicine Subspecialty',
                          'Surgery Subspecialty',
                        ],
                        onChanged: (value) => setState(() => _selectedCategory = value),
                        validator: (value) =>
                            value == null ? 'Please select a category' : null,
                      ),
                      const SizedBox(height: 16),

                      // Description
                      _buildTextField(
                        label: 'Description',
                        hint: 'Any Notice Details',
                        icon: Icons.description,
                        controller: _descriptionController,
                        maxLines: 3,
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
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                widget.wardId != null ? 'Update Ward' : 'Add Ward',
                                style:
                                    const TextStyle(fontSize: 16, color: Colors.white),
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
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
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