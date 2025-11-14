// lib/admin_profile_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // for formatting createdAt
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'main.dart'; // AppColors
import 'admin_drawer.dart'; // your reusable drawer
import 'login_page.dart'; // for fallback logout

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nicController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _profileImageUrl;
  DateTime? _createdAt;
  String _role = '';

  // Local picked image file
  File? _pickedImageFile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _nicController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _error = 'No authenticated user found.';
        _loading = false;
      });
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        setState(() {
          _error = 'User profile not found in Firestore.';
          _loading = false;
        });
        return;
      }

      final data = doc.data()!;
      _fullNameController.text = (data['fullName'] ?? '') as String;
      _emailController.text = (data['email'] ?? user.email ?? '') as String;
      _nicController.text = (data['nic'] ?? '') as String;
      _mobileController.text = (data['mobileNumber'] ?? '') as String;
      _profileImageUrl = (data['profileImage'] ?? '') as String?;
      _role = (data['role'] ?? '') as String;

      final ts = data['createdAt'];
      if (ts is Timestamp) {
        _createdAt = ts.toDate();
      } else if (ts is DateTime) {
        _createdAt = ts;
      } else {
        _createdAt = null;
      }
    } catch (e) {
      _error = 'Failed to load profile: ${e.toString()}';
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (picked == null) return;

      setState(() {
        _pickedImageFile = File(picked.path);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image pick failed: ${e.toString()}')),
      );
    }
  }

  Future<String?> _uploadProfileImage(String uid, File file) async {
    try {
      final ref = _storage.ref().child('profile_images').child('$uid.jpg');
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _error = 'No authenticated user found.';
      });
      return;
    }

    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final nic = _nicController.text.trim();
    final mobile = _mobileController.text.trim();

    if (fullName.isEmpty || email.isEmpty) {
      setState(() {
        _error = 'Full name and email are required.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      String? uploadedUrl = _profileImageUrl;
      if (_pickedImageFile != null) {
        final url = await _uploadProfileImage(user.uid, _pickedImageFile!);
        if (url != null) uploadedUrl = url;
      }

      // Update Firestore document
      final updateData = <String, dynamic>{
        'fullName': fullName,
        'email': email,
        'nic': nic,
        'mobileNumber': mobile,
        // keep role/status/createdAt untouched
      };

      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        updateData['profileImage'] = uploadedUrl;
      }

      await _firestore.collection('users').doc(user.uid).update(updateData);

      // Also update FirebaseAuth email if changed
      if (email != user.email) {
        try {
          await user.updateEmail(email);
        } catch (e) {
          // Updating user's Firebase Auth email may require re-authentication.
          debugPrint('Auth email update failed: $e');
          // Notify user but don't stop saving profile fields.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Profile updated but email not changed (re-login may be required): ${e.toString()}',
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }

      // Reload profile to reflect saved data (and createdAt formatting)
      await _loadUserProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to save profile: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: ${e.toString()}')),
        );
      }
    }
  }

  void _openImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Remove Current Photo'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _removeProfileImage();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _removeProfileImage() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      // delete from storage if exists
      final ref = _storage.ref().child('profile_images').child('${user.uid}.jpg');
      await ref.delete().catchError((_) {}); // ignore if no file

      // remove field from Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'profileImage': FieldValue.delete(),
      });

      setState(() {
        _profileImageUrl = null;
        _pickedImageFile = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo removed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove photo: ${e.toString()}')),
      );
    }
  }

  // small helper to format createdAt
  String _formatCreatedAt() {
    if (_createdAt == null) return '-';
    return DateFormat('yyyy-MM-dd • hh:mm a').format(_createdAt!);
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final displayName = _fullNameController.text.isNotEmpty
        ? _fullNameController.text
        : (user?.displayName ?? 'Administrator');

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        leading: Builder(builder: (context) {
          return IconButton(
            icon: const Icon(Icons.menu, color: AppColors.darkText, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          );
        }),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.darkText),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
          const SizedBox(width: 6),
        ],
      ),
      drawer: AdminDrawer(
        userName: displayName,
        userRole: _role.isNotEmpty ? _role : 'Administrator',
        onNavTap: (title) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title tapped')));
        },
        onLogout: _handleLogout,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header card (mirrors dashboard header)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE6D6F7), Color(0xFFE9D7FD)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryPurple.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _openImageOptions,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 36,
                                  backgroundColor: Colors.white,
                                  backgroundImage: _pickedImageFile != null
                                      ? FileImage(_pickedImageFile!) as ImageProvider
                                      : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                                          ? NetworkImage(_profileImageUrl!)
                                          : null,
                                  child: (_pickedImageFile == null && (_profileImageUrl == null || _profileImageUrl!.isEmpty))
                                      ? const Icon(Icons.person, size: 40, color: AppColors.primaryPurple)
                                      : null,
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(Icons.camera_alt, size: 18, color: AppColors.primaryPurple),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Welcome Back, ${displayName.isNotEmpty ? displayName : 'Admin'}',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText)),
                                const SizedBox(height: 4),
                                Text(_role.isNotEmpty ? _role : 'Administrator', style: TextStyle(fontSize: 13.5, color: AppColors.darkText.withOpacity(0.7))),
                              ],
                            ),
                          ),
                          const Icon(Icons.notifications_none, color: AppColors.darkText, size: 24),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),
                    const Text('Manage  Profile Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 18),

                    // Profile form
                    const Text('Profile Picture', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.blue)),
                    const SizedBox(height: 8),

                    GestureDetector(
                      onTap: _openImageOptions,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Center(
                          child: Text(
                            _pickedImageFile != null ? 'Image Selected' : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty ? 'Change Image' : 'Click To Choose Image..'),
                            style: const TextStyle(fontSize: 14, color: Colors.black54),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),
                    const Text('Full Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    _buildTextField(controller: _fullNameController, hint: 'Full Name'),

                    const SizedBox(height: 12),
                    const Text('Email', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    _buildTextField(controller: _emailController, hint: 'Email', keyboardType: TextInputType.emailAddress),

                    const SizedBox(height: 12),
                    const Text('NIC', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    _buildTextField(controller: _nicController, hint: 'NIC'),

                    const SizedBox(height: 12),
                    const Text('Mobile Number', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    _buildTextField(controller: _mobileController, hint: 'Mobile Number', keyboardType: TextInputType.phone),

                    const SizedBox(height: 18),
                    Center(
                      child: SizedBox(
                        width: 140,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                          ),
                          onPressed: _saving ? null : _saveProfile,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              gradient: const LinearGradient(colors: [Color(0xffb388ff), Color(0xff7c4dff)]),
                            ),
                            child: Center(
                              child: _saving
                                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Update', style: TextStyle(color: Colors.white, fontSize: 16)),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.only(left: 6.0),
                      child: Text('Account CreatedAt : ${_formatCreatedAt()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),

                    const SizedBox(height: 30),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),

                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Text('Developed By Malitha Tishamal', style: TextStyle(color: AppColors.darkText.withOpacity(0.6), fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String hint, TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.inputBorder.withOpacity(0.8)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2)),
      ),
    );
  }
}
